# 🏴‍☠️ Crypto Treasure Hunt

A blockchain-based treasure hunt game built on the Stacks blockchain where players explore virtual locations, solve puzzles, discover treasures, and earn STX rewards.

## 🎮 Game Overview

Crypto Treasure Hunt is an immersive gaming experience that combines exploration, puzzle-solving, and cryptocurrency rewards. Players register with STX, explore various locations, discover treasures of different rarities, and compete on leaderboards for additional prizes.

### Key Features

- **🗺️ Location Exploration**: Discover forests, mountains, caves, beaches, ruins, and temples
- **💎 Treasure Discovery**: Find treasures ranging from common coins to mythical artifacts
- **🧩 Puzzle Solving**: Solve riddles and puzzles to unlock legendary treasures
- **⚡ Energy System**: Manage your energy for strategic exploration
- **🏆 Achievement System**: Unlock achievements and earn bonus rewards
- **🔄 Trading System**: Transfer treasures between players
- **📊 Leaderboards**: Compete with other players for top rankings
- **💰 STX Rewards**: Earn real cryptocurrency rewards for your discoveries

## 🎯 Game Mechanics

### Player Registration
- **Cost**: 1 STX registration fee
- **Benefits**: Access to all game features and starting energy of 100
- **Limit**: Maximum 100 players per game session

### Treasure Types & Rewards
- **Common** (🥉): Base reward of 1 STX
- **Rare** (🥈): Base reward of 3 STX  
- **Legendary** (🥇): Base reward of 7 STX
- **Mythical** (💎): Base reward of 15 STX

*Actual rewards are multiplied by rarity multipliers and can be enhanced through puzzle-solving bonuses.*

### Location System
- **6 Different Location Types**: Each with unique characteristics and difficulty levels
- **Level Requirements**: Higher-level locations require experienced players
- **Coordinate System**: Navigate using X,Y coordinates within location boundaries
- **Discovery Bonuses**: First-time location discoveries earn extra rewards

### Energy & Cooldowns
- **Starting Energy**: 100 points per player
- **Exploration Cost**: 10 energy per location visit
- **Cooldown Period**: 10 blocks between explorations
- **Recovery**: Use the rest function to restore energy to 100%

## 🛠️ Technical Specifications

### Smart Contract Details
- **Blockchain**: Stacks (STX)
- **Language**: Clarity
- **Contract Name**: `crypto-treasure-hunt`
- **Version**: 1.0.0

### Core Constants
```clarity
REGISTRATION_FEE: 1 STX
TREASURE_REWARD: 5 STX (base)
PUZZLE_BONUS: 2 STX
HINT_COST: 0.5 STX
EXPLORATION_COOLDOWN: 10 blocks
MAX_PLAYERS: 100
GAME_DURATION: 1008 blocks (~1 week)
```

### Error Codes
- `ERR_NOT_AUTHORIZED (100)`: Insufficient permissions
- `ERR_GAME_NOT_ACTIVE (101)`: Game is paused or ended
- `ERR_PLAYER_NOT_REGISTERED (102)`: Player not found
- `ERR_TREASURE_NOT_FOUND (104)`: Invalid treasure ID
- `ERR_TREASURE_ALREADY_CLAIMED (105)`: Treasure already taken
- `ERR_COOLDOWN_ACTIVE (108)`: Must wait before next action

## 🚀 Getting Started

### Prerequisites
- Stacks wallet (Hiro Wallet, Xverse, etc.)
- Minimum 1 STX for registration
- Additional STX for hints and transactions

### How to Play

1. **Register**: Call `register-player` with your chosen username
2. **Explore**: Use `explore-location` to visit different areas
3. **Discover**: Find treasures through exploration or puzzle-solving
4. **Claim**: Use `claim-treasure` to collect your rewards
5. **Trade**: Transfer treasures to other players using `transfer-treasure`
6. **Compete**: Check leaderboards and work towards achievements

### Available Functions

#### Player Functions
- `register-player(username)`: Register for the game
- `explore-location(location-id, x, y)`: Explore a specific location
- `claim-treasure(treasure-id)`: Claim a discovered treasure
- `solve-puzzle(treasure-id, solution)`: Solve puzzle to unlock treasure
- `buy-hint(treasure-id)`: Purchase a hint for puzzle solving
- `transfer-treasure(treasure-id, recipient)`: Trade treasure with another player
- `rest-and-recover()`: Restore energy to 100%

#### Read-Only Functions
- `get-player-info(player)`: View player statistics
- `get-treasure-info(treasure-id)`: View treasure details
- `get-location-info(location-id)`: View location information
- `get-game-stats()`: View overall game statistics
- `get-player-achievements(player)`: View player achievements

## 📊 Game Statistics

The contract tracks comprehensive statistics including:
- Total registered players
- Total treasures discovered
- Current prize pool
- Game duration remaining
- Individual player performance metrics

## 🏆 Achievement System

Unlock special achievements for bonus rewards:

- **First Discovery**: Find your first treasure (0.5 STX bonus)
- **Puzzle Master**: Solve 10 puzzles (2 STX bonus)
- **Explorer**: Reach level 10 (varies by achievement)

## 🔧 Development & Testing

### Running Tests
```bash
npm install
npm test
```

The project includes comprehensive test coverage using Vitest:
- Player registration and management
- Location exploration mechanics
- Treasure discovery and claiming
- Puzzle solving system
- Trading functionality
- Error handling and edge cases

### Contract Deployment
1. Compile the Clarity contract
2. Deploy to Stacks testnet/mainnet
3. Initialize with `initialize-game`
4. Create initial locations and treasures

## 🛡️ Security Features

- **Owner-only functions**: Critical game management restricted to contract owner
- **Input validation**: All coordinates and parameters validated
- **Cooldown mechanisms**: Prevent spam and ensure fair gameplay
- **Error handling**: Comprehensive error codes for all failure scenarios
- **Balance checks**: Ensure sufficient funds before transactions

## 🤝 Contributing

We welcome contributions to improve the Crypto Treasure Hunt experience:

1. Fork the repository
2. Create a feature branch
3. Add comprehensive tests
4. Submit a pull request

### Development Guidelines
- Follow Clarity best practices
- Maintain comprehensive test coverage
- Document all new features
- Ensure security considerations are addressed

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For questions, bug reports, or feature requests:
- Create an issue on GitHub
- Join our Discord community
- Check the documentation wiki

## 🔮 Roadmap

### Upcoming Features
- **Multiplayer Quests**: Collaborative treasure hunting missions
- **NFT Integration**: Unique treasure tokens as NFTs
- **Seasonal Events**: Special limited-time treasure hunts
- **Guild System**: Form teams and compete together
- **Mobile App**: Dedicated mobile interface
- **Cross-chain Support**: Expand to other blockchains

### Recent Updates
- ✅ Fixed treasure transfer function
- ✅ Added comprehensive test suite
- ✅ Improved error handling
- ✅ Enhanced security measures

---

*Happy treasure hunting! 🏴‍☠️💰*

**Contract Address**: [To be deployed]  
**Network**: Stacks Mainnet  
**Status**: Ready for deployment