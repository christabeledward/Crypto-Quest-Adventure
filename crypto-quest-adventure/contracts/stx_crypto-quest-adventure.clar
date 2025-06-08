;; title: crypto-treasure-hunt
;; version: 1.0.0
;; summary: A blockchain-based treasure hunt game with crypto rewards
;; description: Players explore locations, solve puzzles, find treasures, and compete for STX rewards

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant GAME_NAME "Crypto Treasure Hunt")

;; Error codes
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_GAME_NOT_ACTIVE (err u101))
(define-constant ERR_PLAYER_NOT_REGISTERED (err u102))
(define-constant ERR_INSUFFICIENT_FUNDS (err u103))
(define-constant ERR_TREASURE_NOT_FOUND (err u104))
(define-constant ERR_TREASURE_ALREADY_CLAIMED (err u105))
(define-constant ERR_INVALID_LOCATION (err u106))
(define-constant ERR_PUZZLE_NOT_SOLVED (err u107))
(define-constant ERR_COOLDOWN_ACTIVE (err u108))
(define-constant ERR_INVALID_HINT (err u109))
(define-constant ERR_MAX_PLAYERS_REACHED (err u110))
(define-constant ERR_GAME_ENDED (err u111))
(define-constant ERR_INVALID_COORDINATES (err u112))

;; Game parameters
(define-constant REGISTRATION_FEE u1000000) ;; 1 STX
(define-constant TREASURE_REWARD u5000000) ;; 5 STX base reward
(define-constant PUZZLE_BONUS u2000000) ;; 2 STX bonus for puzzle solving
(define-constant HINT_COST u500000) ;; 0.5 STX per hint
(define-constant EXPLORATION_COOLDOWN u10) ;; 10 blocks between explorations
(define-constant MAX_PLAYERS u100)
(define-constant GAME_DURATION u1008) ;; ~1 week in blocks

;; Treasure types
(define-constant TREASURE_COMMON u1)
(define-constant TREASURE_RARE u2)
(define-constant TREASURE_LEGENDARY u3)
(define-constant TREASURE_MYTHICAL u4)

;; Location types
(define-constant LOCATION_FOREST u1)
(define-constant LOCATION_MOUNTAIN u2)
(define-constant LOCATION_CAVE u3)
(define-constant LOCATION_BEACH u4)
(define-constant LOCATION_RUINS u5)
(define-constant LOCATION_TEMPLE u6)

;; Data variables
(define-data-var game-active bool true)
(define-data-var game-start-block uint u0)
(define-data-var total-players uint u0)
(define-data-var total-treasures-found uint u0)
(define-data-var prize-pool uint u0)
(define-data-var next-treasure-id uint u1)
(define-data-var next-location-id uint u1)
(define-data-var game-seed uint u12345)

;; Player data structure
(define-map players principal {
    username: (string-ascii 32),
    level: uint,
    experience: uint,
    treasures-found: uint,
    puzzles-solved: uint,
    total-rewards: uint,
    last-exploration: uint,
    current-location: uint,
    energy: uint,
    inventory: (list 20 uint), ;; List of treasure IDs
    achievements: (list 10 (string-ascii 32)),
    registered-at: uint,
    is-active: bool
})

;; Treasure definitions
(define-map treasures uint {
    name: (string-ascii 64),
    description: (string-ascii 256),
    treasure-type: uint,
    location-id: uint,
    coordinates: { x: uint, y: uint },
    reward-amount: uint,
    puzzle-hash: (optional (buff 32)), ;; Hash of puzzle solution
    puzzle-clue: (optional (string-ascii 256)),
    discovered-by: (optional principal),
    discovered-at: (optional uint),
    is-claimed: bool,
    rarity-multiplier: uint,
    required-level: uint
})

;; Location definitions
(define-map locations uint {
    name: (string-ascii 64),
    description: (string-ascii 256),
    location-type: uint,
    coordinates: { x: uint, y: uint, radius: uint },
    treasure-count: uint,
    difficulty-level: uint,
    entry-requirement: uint, ;; Minimum level required
    discovery-bonus: uint,
    is-hidden: bool,
    discovered-by: (list 50 principal)
})

;; Puzzles and riddles
(define-map puzzles uint {
    question: (string-ascii 512),
    hint: (string-ascii 256),
    solution-hash: (buff 32),
    reward: uint,
    difficulty: uint,
    solved-by: (list 10 principal),
    created-at: uint
})

;; Leaderboard data
(define-map leaderboard uint {
    player: principal,
    score: uint,
    treasures: uint,
    rank: uint,
    last-updated: uint
})

;; Daily challenges
(define-map daily-challenges uint {
    challenge-date: uint,
    description: (string-ascii 256),
    target: uint,
    reward: uint,
    completed-by: (list 20 principal),
    is-active: bool
})

;; Player achievements
(define-map achievements (string-ascii 32) {
    name: (string-ascii 64),
    description: (string-ascii 256),
    reward: uint,
    rarity: uint,
    unlock-condition: (string-ascii 128)
})

;; Helper functions

;; Generate pseudo-random number
(define-private (pseudo-random (seed uint))
    (let ((hash-result (hash160 (concat 
            (unwrap-panic (to-consensus-buff? seed))
            (unwrap-panic (to-consensus-buff? stacks-block-height))))))
        (buff-to-uint-be (unwrap-panic (slice? hash-result u0 u4)))))

;; Calculate distance between two points
(define-private (calculate-distance (x1 uint) (y1 uint) (x2 uint) (y2 uint))
    (let ((dx (if (>= x1 x2) (- x1 x2) (- x2 x1)))
          (dy (if (>= y1 y2) (- y1 y2) (- y2 y1))))
        (+ (* dx dx) (* dy dy)))) ;; Simplified distance calculation

;; Check if player is within location radius
(define-private (is-within-location (player-x uint) (player-y uint) (location-id uint))
    (match (map-get? locations location-id)
        location-data 
            (let ((loc-coords (get coordinates location-data))
                  (distance (calculate-distance 
                            player-x player-y 
                            (get x loc-coords) (get y loc-coords))))
                (<= distance (* (get radius loc-coords) (get radius loc-coords))))
        false))

;; Calculate treasure reward based on type and rarity - FIXED VERSION
(define-private (calculate-treasure-reward (treasure-type uint) (rarity-multiplier uint))
    (let ((base-reward (if (is-eq treasure-type TREASURE_COMMON) 
                          u1000000
                          (if (is-eq treasure-type TREASURE_RARE)
                              u3000000
                              (if (is-eq treasure-type TREASURE_LEGENDARY)
                                  u7000000
                                  (if (is-eq treasure-type TREASURE_MYTHICAL)
                                      u15000000
                                      u1000000))))))
        (* base-reward rarity-multiplier)))

;; Update player experience and level
(define-private (update-player-experience (player principal) (exp-gained uint))
    (match (map-get? players player)
        player-data
            (let ((new-exp (+ (get experience player-data) exp-gained))
                  (new-level (+ (get level player-data) (/ new-exp u1000))))
                (map-set players player
                    (merge player-data {
                        experience: new-exp,
                        level: new-level
                    }))
                true)
        false))

;; Check and award achievements
(define-private (check-achievements (player principal))
    (let ((player-data (unwrap-panic (map-get? players player))))
        ;; Check for "First Treasure" achievement
        (if (and (is-eq (get treasures-found player-data) u1)
                 (is-none (index-of (get achievements player-data) "first-treasure")))
            (award-achievement player "first-treasure")
            true)
        
        ;; Check for "Puzzle Master" achievement
        (if (and (>= (get puzzles-solved player-data) u10)
                 (is-none (index-of (get achievements player-data) "puzzle-master")))
            (award-achievement player "puzzle-master")
            true)
        
        ;; Check for "Explorer" achievement
        (if (and (>= (get level player-data) u10)
                 (is-none (index-of (get achievements player-data) "explorer")))
            (award-achievement player "explorer")
            true)))

;; Award achievement to player
(define-private (award-achievement (player principal) (achievement-id (string-ascii 32)))
    (match (map-get? players player)
        player-data
            (let ((current-achievements (get achievements player-data)))
                (if (< (len current-achievements) u10)
                    (map-set players player
                        (merge player-data {
                            achievements: (unwrap-panic (as-max-len? 
                                (append current-achievements achievement-id) u10))
                        }))
                    false))
        false))

;; Public functions

;; Initialize the game with initial setup
(define-public (initialize-game)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (var-set game-start-block stacks-block-height)
        (var-set game-active true)
        
        ;; Create initial locations
        (try! (create-location 
            "Mystic Forest" 
            "A dense forest filled with ancient magic and hidden treasures"
            LOCATION_FOREST
            u50 u50 u20  ;; x, y, radius
            u5    ;; difficulty level
            u1    ;; entry requirement (level 1)
            u100000)) ;; discovery bonus
        
        (try! (create-location 
            "Dragon's Peak" 
            "A treacherous mountain where legendary treasures await the brave"
            LOCATION_MOUNTAIN
            u100 u150 u15
            u8    ;; difficulty level
            u5    ;; entry requirement (level 5)
            u500000)) ;; discovery bonus
        
        ;; Create initial treasures
        (try! (create-treasure
            "Ancient Coin"
            "A mysterious coin from a lost civilization"
            TREASURE_COMMON
            u1    ;; location 1 (Mystic Forest)
            u55 u55  ;; coordinates
            u1    ;; rarity multiplier
            u1    ;; required level
            none  ;; no puzzle
            none))
        
        (try! (create-treasure
            "Crystal of Power"
            "A glowing crystal that pulses with magical energy"
            TREASURE_LEGENDARY
            u2    ;; location 2 (Dragon's Peak)
            u95 u145
            u3    ;; rarity multiplier
            u5    ;; required level
            (some 0x1234567890abcdef1234567890abcdef12345678) ;; puzzle hash
            (some "I am not alive, but I grow; I don't have lungs, but I need air")))
        
        ;; Initialize achievements
        (map-set achievements "first-treasure" {
            name: "First Discovery",
            description: "Found your first treasure",
            reward: u500000,
            rarity: u1,
            unlock-condition: "Find 1 treasure"
        })
        
        (map-set achievements "puzzle-master" {
            name: "Puzzle Master",
            description: "Solved 10 puzzles",
            reward: u2000000,
            rarity: u3,
            unlock-condition: "Solve 10 puzzles"
        })
        
        (ok true)))

;; Register a new player
(define-public (register-player (username (string-ascii 32)))
    (let ((registration-fee REGISTRATION_FEE))
        (asserts! (var-get game-active) ERR_GAME_NOT_ACTIVE)
        (asserts! (< (var-get total-players) MAX_PLAYERS) ERR_MAX_PLAYERS_REACHED)
        (asserts! (is-none (map-get? players tx-sender)) ERR_PLAYER_NOT_REGISTERED)
        
        ;; Charge registration fee
        (try! (stx-transfer? registration-fee tx-sender (as-contract tx-sender)))
        
        ;; Add to prize pool
        (var-set prize-pool (+ (var-get prize-pool) registration-fee))
        
        ;; Create player profile
        (map-set players tx-sender {
            username: username,
            level: u1,
            experience: u0,
            treasures-found: u0,
            puzzles-solved: u0,
            total-rewards: u0,
            last-exploration: u0,
            current-location: u0,
            energy: u100, ;; Start with full energy
            inventory: (list),
            achievements: (list),
            registered-at: stacks-block-height,
            is-active: true
        })
        
        (var-set total-players (+ (var-get total-players) u1))
        (ok true)))

;; Explore a location
(define-public (explore-location (location-id uint) (player-x uint) (player-y uint))
    (let ((player-data (unwrap! (map-get? players tx-sender) ERR_PLAYER_NOT_REGISTERED))
          (location-data (unwrap! (map-get? locations location-id) ERR_INVALID_LOCATION)))
        
        (asserts! (var-get game-active) ERR_GAME_NOT_ACTIVE)
        (asserts! (get is-active player-data) ERR_PLAYER_NOT_REGISTERED)
        (asserts! (>= stacks-block-height (+ (get last-exploration player-data) EXPLORATION_COOLDOWN)) 
                  ERR_COOLDOWN_ACTIVE)
        (asserts! (>= (get level player-data) (get entry-requirement location-data)) 
                  ERR_NOT_AUTHORIZED)
        (asserts! (is-within-location player-x player-y location-id) ERR_INVALID_COORDINATES)
        
        ;; Update player location and exploration time
        (map-set players tx-sender
            (merge player-data {
                current-location: location-id,
                last-exploration: stacks-block-height,
                energy: (if (>= (get energy player-data) u10) 
                          (- (get energy player-data) u10)
                          u0)
            }))
        
        ;; Give exploration experience
        (update-player-experience tx-sender u50)
        
        ;; Random chance to discover treasure
        (let ((random-num (pseudo-random (+ (var-get game-seed) stacks-block-height))))
            (if (< (mod random-num u100) u25) ;; 25% chance
                (discover-random-treasure tx-sender location-id)
                (ok "Explored location, but found nothing this time.")))
        
        (ok "Location explored successfully!")))

;; Discover random treasure in location
(define-private (discover-random-treasure (player principal) (location-id uint))
    (let ((random-seed (pseudo-random (+ (var-get game-seed) stacks-block-height)))
          (treasure-type (+ (mod random-seed u4) u1)) ;; Random treasure type 1-4
          (treasure-id (var-get next-treasure-id)))
        
        ;; Create random treasure
        (map-set treasures treasure-id {
            name: "Mysterious Artifact",
            description: "A valuable item discovered during exploration",
            treasure-type: treasure-type,
            location-id: location-id,
            coordinates: { x: u0, y: u0 }, ;; Random location within area
            reward-amount: (calculate-treasure-reward treasure-type u1),
            puzzle-hash: none,
            puzzle-clue: none,
            discovered-by: (some player),
            discovered-at: (some stacks-block-height),
            is-claimed: false,
            rarity-multiplier: u1,
            required-level: u1
        })
        
        (var-set next-treasure-id (+ treasure-id u1))
        (ok treasure-id)))

;; Claim a discovered treasure
(define-public (claim-treasure (treasure-id uint))
    (let ((treasure-data (unwrap! (map-get? treasures treasure-id) ERR_TREASURE_NOT_FOUND))
          (player-data (unwrap! (map-get? players tx-sender) ERR_PLAYER_NOT_REGISTERED)))
        
        (asserts! (var-get game-active) ERR_GAME_NOT_ACTIVE)
        (asserts! (not (get is-claimed treasure-data)) ERR_TREASURE_ALREADY_CLAIMED)
        (asserts! (>= (get level player-data) (get required-level treasure-data)) ERR_NOT_AUTHORIZED)
        
        ;; Check if puzzle needs to be solved
        (match (get puzzle-hash treasure-data)
            puzzle-hash
                (asserts! false ERR_PUZZLE_NOT_SOLVED) ;; Would check puzzle solution
            true) ;; No puzzle required
        
        ;; Transfer reward
        (let ((reward-amount (get reward-amount treasure-data)))
            (try! (as-contract (stx-transfer? reward-amount tx-sender tx-sender)))
            
            ;; Update treasure status
            (map-set treasures treasure-id
                (merge treasure-data {
                    is-claimed: true,
                    discovered-by: (some tx-sender),
                    discovered-at: (some stacks-block-height)
                }))
            
            ;; Update player stats
            (map-set players tx-sender
                (merge player-data {
                    treasures-found: (+ (get treasures-found player-data) u1),
                    total-rewards: (+ (get total-rewards player-data) reward-amount),
                    inventory: (unwrap-panic (as-max-len? 
                        (append (get inventory player-data) treasure-id) u20))
                }))
            
            ;; Update experience
            (update-player-experience tx-sender u200)
            
            ;; Check achievements
            (check-achievements tx-sender)
            
            (var-set total-treasures-found (+ (var-get total-treasures-found) u1))
            (ok reward-amount))))

;; Solve a puzzle to unlock treasure
(define-public (solve-puzzle (treasure-id uint) (solution (string-ascii 128)))
    (let ((treasure-data (unwrap! (map-get? treasures treasure-id) ERR_TREASURE_NOT_FOUND))
          (player-data (unwrap! (map-get? players tx-sender) ERR_PLAYER_NOT_REGISTERED))
          (solution-hash (hash160 (unwrap-panic (to-consensus-buff? solution)))))
        
        (asserts! (var-get game-active) ERR_GAME_NOT_ACTIVE)
        (asserts! (is-some (get puzzle-hash treasure-data)) ERR_PUZZLE_NOT_SOLVED)
        (asserts! (is-eq solution-hash (unwrap-panic (get puzzle-hash treasure-data))) ERR_PUZZLE_NOT_SOLVED)
        
        ;; Award puzzle bonus
        (try! (as-contract (stx-transfer? PUZZLE_BONUS tx-sender tx-sender)))
        
        ;; Update player puzzle stats
        (map-set players tx-sender
            (merge player-data {
                puzzles-solved: (+ (get puzzles-solved player-data) u1),
                total-rewards: (+ (get total-rewards player-data) PUZZLE_BONUS)
            }))
        
        ;; Update experience for puzzle solving
        (update-player-experience tx-sender u300)
        
        ;; Now player can claim the treasure
        (claim-treasure treasure-id)))

;; Buy a hint for a puzzle
(define-public (buy-hint (treasure-id uint))
    (let ((treasure-data (unwrap! (map-get? treasures treasure-id) ERR_TREASURE_NOT_FOUND))
          (player-data (unwrap! (map-get? players tx-sender) ERR_PLAYER_NOT_REGISTERED)))
        
        (asserts! (var-get game-active) ERR_GAME_NOT_ACTIVE)
        (asserts! (is-some (get puzzle-clue treasure-data)) ERR_INVALID_HINT)
        
        ;; Charge hint fee
        (try! (stx-transfer? HINT_COST tx-sender CONTRACT_OWNER))
        
        (ok (get puzzle-clue treasure-data))))

;; Create a new location (admin only)
(define-public (create-location 
    (name (string-ascii 64))
    (description (string-ascii 256))
    (location-type uint)
    (x uint) (y uint) (radius uint)
    (difficulty uint)
    (entry-requirement uint)
    (discovery-bonus uint))
    (let ((location-id (var-get next-location-id)))
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        
        (map-set locations location-id {
            name: name,
            description: description,
            location-type: location-type,
            coordinates: { x: x, y: y, radius: radius },
            treasure-count: u0,
            difficulty-level: difficulty,
            entry-requirement: entry-requirement,
            discovery-bonus: discovery-bonus,
            is-hidden: false,
            discovered-by: (list)
        })
        
        (var-set next-location-id (+ location-id u1))
        (ok location-id)))

;; Create a new treasure (admin only)
(define-public (create-treasure
    (name (string-ascii 64))
    (description (string-ascii 256))
    (treasure-type uint)
    (location-id uint)
    (x uint) (y uint)
    (rarity-multiplier uint)
    (required-level uint)
    (puzzle-hash (optional (buff 32)))
    (puzzle-clue (optional (string-ascii 256))))
    (let ((treasure-id (var-get next-treasure-id))
          (reward-amount (calculate-treasure-reward treasure-type rarity-multiplier)))
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        
        (map-set treasures treasure-id {
            name: name,
            description: description,
            treasure-type: treasure-type,
            location-id: location-id,
            coordinates: { x: x, y: y },
            reward-amount: reward-amount,
            puzzle-hash: puzzle-hash,
            puzzle-clue: puzzle-clue,
            discovered-by: none,
            discovered-at: none,
            is-claimed: false,
            rarity-multiplier: rarity-multiplier,
            required-level: required-level
        })
        
        (var-set next-treasure-id (+ treasure-id u1))
        (ok treasure-id)))

;; End game and distribute final rewards (admin only)
(define-public (end-game)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (var-get game-active) ERR_GAME_ENDED)
        
        ;; Game ends after duration or manually
        (asserts! (or (>= stacks-block-height (+ (var-get game-start-block) GAME_DURATION))
                      (is-eq tx-sender CONTRACT_OWNER)) ERR_NOT_AUTHORIZED)
        
        (var-set game-active false)
        
        ;; Distribute remaining prize pool to top players
        ;; (Implementation would rank players and distribute rewards)
        
        (ok true)))

;; Read-only functions

;; Get player information
(define-read-only (get-player-info (player principal))
    (map-get? players player))

;; Get treasure information
(define-read-only (get-treasure-info (treasure-id uint))
    (map-get? treasures treasure-id))

;; Get location information
(define-read-only (get-location-info (location-id uint))
    (map-get? locations location-id))

;; Get game statistics
(define-read-only (get-game-stats)
    {
        total-players: (var-get total-players),
        total-treasures-found: (var-get total-treasures-found),
        prize-pool: (var-get prize-pool),
        game-active: (var-get game-active),
        blocks-remaining: (if (var-get game-active)
            (- (+ (var-get game-start-block) GAME_DURATION) stacks-block-height)
            u0)
    })

;; Get leaderboard
(define-read-only (get-leaderboard (limit uint))
    ;; Would implement proper leaderboard sorting
    (ok "Leaderboard data"))

;; Get player achievements
(define-read-only (get-player-achievements (player principal))
    (match (map-get? players player)
        player-data (ok (get achievements player-data))
        ERR_PLAYER_NOT_REGISTERED))

;; Get daily challenge
(define-read-only (get-daily-challenge)
    (map-get? daily-challenges stacks-block-height))

;; Check if coordinates are valid for treasure hunting
(define-read-only (check-coordinates (x uint) (y uint))
    (and (<= x u1000) (<= y u1000))) ;; Simple boundary check

;; Get nearby treasures (within range)
(define-read-only (get-nearby-treasures (player-x uint) (player-y uint) (range uint))
    ;; Would implement proximity search
    (ok "Nearby treasures list"))

;; Administrative functions

;; Pause/unpause game
(define-public (toggle-game-status)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (var-set game-active (not (var-get game-active)))
        (ok (var-get game-active))))

;; Withdraw contract balance (admin only)
(define-public (withdraw-funds (amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (try! (as-contract (stx-transfer? amount tx-sender CONTRACT_OWNER)))
        (ok amount)))

;; Update game parameters
(define-public (update-game-seed (new-seed uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (var-set game-seed new-seed)
        (ok true)))

;; Emergency functions
(define-public (emergency-pause)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (var-set game-active false)
        (ok true)))

;; Player utility functions

;; Rest to recover energy
(define-public (rest-and-recover)
    (let ((player-data (unwrap! (map-get? players tx-sender) ERR_PLAYER_NOT_REGISTERED)))
        (map-set players tx-sender
            (merge player-data {
                energy: u100, ;; Full energy recovery
                last-exploration: stacks-block-height
            }))
        (ok "Energy restored to 100%")))
        ;; Transfer treasure to another player (trading) - FIXED VERSION
(define-public (transfer-treasure (treasure-id uint) (recipient principal))
    (let ((player-data (unwrap! (map-get? players tx-sender) ERR_PLAYER_NOT_REGISTERED))
          (treasure-data (unwrap! (map-get? treasures treasure-id) ERR_TREASURE_NOT_FOUND)))
        
        (asserts! (get is-claimed treasure-data) ERR_TREASURE_NOT_FOUND)
        (asserts! (is-some (index-of (get inventory player-data) treasure-id)) ERR_TREASURE_NOT_FOUND)
        (asserts! (is-some (map-get? players recipient)) ERR_PLAYER_NOT_REGISTERED)
        
        ;; Remove from sender's inventory
        (let ((new-inventory (filter (lambda (item) (not (is-eq item treasure-id)))
                                   (get inventory player-data))))
            (map-set players tx-sender
                (merge player-data { inventory: new-inventory }))
            
            ;; Add to recipient's inventory
            (match (map-get? players recipient)
                recipient-data
                    (begin
                        (map-set players recipient
                            (merge recipient-data {
                                inventory: (unwrap-panic (as-max-len? 
                                    (append (get inventory recipient-data) treasure-id) u20))
                            }))
                        (ok true))
                ;; Handle the case when recipient is not found
                ERR_PLAYER_NOT_REGISTERED))))