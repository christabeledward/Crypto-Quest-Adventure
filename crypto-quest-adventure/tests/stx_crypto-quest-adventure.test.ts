import { describe, expect, it } from "vitest";

// Mock Clarity contract interaction functions
const mockContract = {
  players: new Map(),
  treasures: new Map(),
  locations: new Map(),
  gameActive: true,
  totalPlayers: 0,
  nextTreasureId: 1,
  nextLocationId: 1,
  prizePool: 0,

  // Mock player registration
  registerPlayer: (username, sender) => {
    if (mockContract.players.has(sender)) {
      return { type: "error", value: 102 }; // ERR_PLAYER_NOT_REGISTERED
    }
    
    mockContract.players.set(sender, {
      username,
      level: 1,
      experience: 0,
      treasuresFound: 0,
      puzzlesSolved: 0,
      totalRewards: 0,
      lastExploration: 0,
      currentLocation: 0,
      energy: 100,
      inventory: [],
      achievements: [],
      registeredAt: Date.now(),
      isActive: true
    });
    
    mockContract.totalPlayers++;
    mockContract.prizePool += 1000000; // Registration fee
    return { type: "ok", value: true };
  },

  // Mock treasure creation
  createTreasure: (name, description, treasureType, locationId, x, y, rarityMultiplier, requiredLevel) => {
    const treasureId = mockContract.nextTreasureId++;
    const baseReward = treasureType === 1 ? 1000000 : treasureType === 2 ? 3000000 : treasureType === 3 ? 7000000 : 15000000;
    
    mockContract.treasures.set(treasureId, {
      name,
      description,
      treasureType,
      locationId,
      coordinates: { x, y },
      rewardAmount: baseReward * rarityMultiplier,
      puzzleHash: null,
      puzzleClue: null,
      discoveredBy: null,
      discoveredAt: null,
      isClaimed: false,
      rarityMultiplier,
      requiredLevel
    });
    
    return { type: "ok", value: treasureId };
  },

  // Mock location creation
  createLocation: (name, description, locationType, x, y, radius, difficulty, entryRequirement, discoveryBonus) => {
    const locationId = mockContract.nextLocationId++;
    
    mockContract.locations.set(locationId, {
      name,
      description,
      locationType,
      coordinates: { x, y, radius },
      treasureCount: 0,
      difficultyLevel: difficulty,
      entryRequirement,
      discoveryBonus,
      isHidden: false,
      discoveredBy: []
    });
    
    return { type: "ok", value: locationId };
  },

  // Mock treasure claiming
  claimTreasure: (treasureId, sender) => {
    const treasure = mockContract.treasures.get(treasureId);
    const player = mockContract.players.get(sender);
    
    if (!treasure) return { type: "error", value: 104 }; // ERR_TREASURE_NOT_FOUND
    if (!player) return { type: "error", value: 102 }; // ERR_PLAYER_NOT_REGISTERED
    if (treasure.isClaimed) return { type: "error", value: 105 }; // ERR_TREASURE_ALREADY_CLAIMED
    if (player.level < treasure.requiredLevel) return { type: "error", value: 100 }; // ERR_NOT_AUTHORIZED
    
    // Update treasure
    treasure.isClaimed = true;
    treasure.discoveredBy = sender;
    treasure.discoveredAt = Date.now();
    
    // Update player
    player.treasuresFound++;
    player.totalRewards += treasure.rewardAmount;
    player.inventory.push(treasureId);
    player.experience += 200;
    player.level = Math.floor(player.experience / 1000) + 1;
    
    return { type: "ok", value: treasure.rewardAmount };
  },

  // Mock treasure transfer
  transferTreasure: (treasureId, recipient, sender) => {
    const senderData = mockContract.players.get(sender);
    const recipientData = mockContract.players.get(recipient);
    const treasure = mockContract.treasures.get(treasureId);
    
    if (!senderData) return { type: "error", value: 102 }; // ERR_PLAYER_NOT_REGISTERED
    if (!recipientData) return { type: "error", value: 102 }; // ERR_PLAYER_NOT_REGISTERED
    if (!treasure) return { type: "error", value: 104 }; // ERR_TREASURE_NOT_FOUND
    if (!treasure.isClaimed) return { type: "error", value: 104 }; // ERR_TREASURE_NOT_FOUND
    if (!senderData.inventory.includes(treasureId)) return { type: "error", value: 104 }; // ERR_TREASURE_NOT_FOUND
    
    // Remove from sender
    senderData.inventory = senderData.inventory.filter(id => id !== treasureId);
    
    // Add to recipient
    recipientData.inventory.push(treasureId);
    
    return { type: "ok", value: true };
  },

  // Mock location exploration
  exploreLocation: (locationId, playerX, playerY, sender) => {
    const player = mockContract.players.get(sender);
    const location = mockContract.locations.get(locationId);
    
    if (!player) return { type: "error", value: 102 }; // ERR_PLAYER_NOT_REGISTERED
    if (!location) return { type: "error", value: 106 }; // ERR_INVALID_LOCATION
    if (player.level < location.entryRequirement) return { type: "error", value: 100 }; // ERR_NOT_AUTHORIZED
    if (player.energy < 10) return { type: "error", value: 108 }; // ERR_COOLDOWN_ACTIVE
    
    // Update player
    player.currentLocation = locationId;
    player.lastExploration = Date.now();
    player.energy -= 10;
    player.experience += 50;
    player.level = Math.floor(player.experience / 1000) + 1;
    
    return { type: "ok", value: "Location explored successfully!" };
  },

  // Mock getters
  getPlayerInfo: (player) => mockContract.players.get(player) || null,
  getTreasureInfo: (treasureId) => mockContract.treasures.get(treasureId) || null,
  getLocationInfo: (locationId) => mockContract.locations.get(locationId) || null,
  getGameStats: () => ({
    totalPlayers: mockContract.totalPlayers,
    totalTreasuresFound: Array.from(mockContract.treasures.values()).filter(t => t.isClaimed).length,
    prizePool: mockContract.prizePool,
    gameActive: mockContract.gameActive
  })
};

describe("Crypto Treasure Hunt Contract", () => {
  
  describe("Player Registration", () => {
    it("should register a new player successfully", () => {
      const result = mockContract.registerPlayer("Alice", "alice123");
      expect(result.type).toBe("ok");
      expect(result.value).toBe(true);
      
      const playerInfo = mockContract.getPlayerInfo("alice123");
      expect(playerInfo).toBeTruthy();
      expect(playerInfo.username).toBe("Alice");
      expect(playerInfo.level).toBe(1);
      expect(playerInfo.energy).toBe(100);
    });

    it("should prevent duplicate player registration", () => {
      mockContract.registerPlayer("Bob", "bob456");
      const result = mockContract.registerPlayer("Bob2", "bob456");
      
      expect(result.type).toBe("error");
      expect(result.value).toBe(102); // ERR_PLAYER_NOT_REGISTERED
    });

    it("should increment total players count", () => {
      const initialStats = mockContract.getGameStats();
      const initialCount = initialStats.totalPlayers;
      
      mockContract.registerPlayer("Charlie", "charlie789");
      
      const updatedStats = mockContract.getGameStats();
      expect(updatedStats.totalPlayers).toBe(initialCount + 1);
    });
  });

  describe("Location Management", () => {
    it("should create a new location successfully", () => {
      const result = mockContract.createLocation(
        "Test Forest",
        "A mysterious forest",
        1, // LOCATION_FOREST
        50, 50, 20, // x, y, radius
        3, // difficulty
        1, // entry requirement
        100000 // discovery bonus
      );
      
      expect(result.type).toBe("ok");
      expect(typeof result.value).toBe("number");
      
      const locationInfo = mockContract.getLocationInfo(result.value);
      expect(locationInfo).toBeTruthy();
      expect(locationInfo.name).toBe("Test Forest");
      expect(locationInfo.difficultyLevel).toBe(3);
    });

    it("should allow location exploration by qualified players", () => {
      mockContract.registerPlayer("Explorer", "explorer123");
      const locationResult = mockContract.createLocation("Easy Woods", "Simple forest", 1, 25, 25, 15, 1, 1, 50000);
      
      const exploreResult = mockContract.exploreLocation(locationResult.value, 25, 25, "explorer123");
      
      expect(exploreResult.type).toBe("ok");
      expect(exploreResult.value).toBe("Location explored successfully!");
      
      const playerInfo = mockContract.getPlayerInfo("explorer123");
      expect(playerInfo.currentLocation).toBe(locationResult.value);
      expect(playerInfo.energy).toBe(90); // Started with 100, used 10
    });

    it("should prevent exploration by under-leveled players", () => {
      mockContract.registerPlayer("Newbie", "newbie123");
      const locationResult = mockContract.createLocation("Dragon Lair", "Dangerous cave", 3, 100, 100, 10, 10, 5, 200000);
      
      const exploreResult = mockContract.exploreLocation(locationResult.value, 100, 100, "newbie123");
      
      expect(exploreResult.type).toBe("error");
      expect(exploreResult.value).toBe(100); // ERR_NOT_AUTHORIZED
    });
  });

  describe("Treasure Management", () => {
    it("should create treasures with correct reward calculations", () => {
      const commonResult = mockContract.createTreasure("Common Coin", "Basic treasure", 1, 1, 10, 10, 1, 1);
      const rareResult = mockContract.createTreasure("Rare Gem", "Valuable gem", 2, 1, 20, 20, 2, 3);
      
      expect(commonResult.type).toBe("ok");
      expect(rareResult.type).toBe("ok");
      
      const commonTreasure = mockContract.getTreasureInfo(commonResult.value);
      const rareTreasure = mockContract.getTreasureInfo(rareResult.value);
      
      expect(commonTreasure.rewardAmount).toBe(1000000); // 1M * 1 multiplier
      expect(rareTreasure.rewardAmount).toBe(6000000);   // 3M * 2 multiplier
    });

    it("should allow treasure claiming by qualified players", () => {
      mockContract.registerPlayer("Hunter", "hunter123");
      const treasureResult = mockContract.createTreasure("Gold Coin", "Shiny coin", 1, 1, 15, 15, 1, 1);
      
      const claimResult = mockContract.claimTreasure(treasureResult.value, "hunter123");
      
      expect(claimResult.type).toBe("ok");
      expect(claimResult.value).toBe(1000000);
      
      const playerInfo = mockContract.getPlayerInfo("hunter123");
      expect(playerInfo.treasuresFound).toBe(1);
      expect(playerInfo.totalRewards).toBe(1000000);
      expect(playerInfo.inventory).toContain(treasureResult.value);
    });

    it("should prevent claiming already claimed treasures", () => {
      mockContract.registerPlayer("Player1", "player1");
      mockContract.registerPlayer("Player2", "player2");
      const treasureResult = mockContract.createTreasure("Unique Artifact", "One of a kind", 2, 1, 30, 30, 1, 1);
      
      // First player claims
      mockContract.claimTreasure(treasureResult.value, "player1");
      
      // Second player tries to claim
      const secondClaimResult = mockContract.claimTreasure(treasureResult.value, "player2");
      
      expect(secondClaimResult.type).toBe("error");
      expect(secondClaimResult.value).toBe(105); // ERR_TREASURE_ALREADY_CLAIMED
    });
  });

  describe("Treasure Transfer", () => {
    it("should allow treasure transfer between players", () => {
      mockContract.registerPlayer("Trader1", "trader1");
      mockContract.registerPlayer("Trader2", "trader2");
      
      const treasureResult = mockContract.createTreasure("Trade Item", "For trading", 1, 1, 40, 40, 1, 1);
      mockContract.claimTreasure(treasureResult.value, "trader1");
      
      const transferResult = mockContract.transferTreasure(treasureResult.value, "trader2", "trader1");
      
      expect(transferResult.type).toBe("ok");
      expect(transferResult.value).toBe(true);
      
      const trader1Info = mockContract.getPlayerInfo("trader1");
      const trader2Info = mockContract.getPlayerInfo("trader2");
      
      expect(trader1Info.inventory).not.toContain(treasureResult.value);
      expect(trader2Info.inventory).toContain(treasureResult.value);
    });

    it("should prevent transfer of non-owned treasures", () => {
      mockContract.registerPlayer("Owner", "owner123");
      mockContract.registerPlayer("Thief", "thief123");
      mockContract.registerPlayer("Victim", "victim123");
      
      const treasureResult = mockContract.createTreasure("Protected Item", "Not for stealing", 1, 1, 50, 50, 1, 1);
      mockContract.claimTreasure(treasureResult.value, "owner123");
      
      const transferResult = mockContract.transferTreasure(treasureResult.value, "victim123", "thief123");
      
      expect(transferResult.type).toBe("error");
      expect(transferResult.value).toBe(104); // ERR_TREASURE_NOT_FOUND
    });

    it("should prevent transfer to non-existent players", () => {
      mockContract.registerPlayer("Sender", "sender123");
      const treasureResult = mockContract.createTreasure("Lost Item", "Going nowhere", 1, 1, 60, 60, 1, 1);
      mockContract.claimTreasure(treasureResult.value, "sender123");
      
      const transferResult = mockContract.transferTreasure(treasureResult.value, "nonexistent", "sender123");
      
      expect(transferResult.type).toBe("error");
      expect(transferResult.value).toBe(102); // ERR_PLAYER_NOT_REGISTERED
    });
  });

  describe("Game Statistics", () => {
    it("should track game statistics correctly", () => {
      const initialStats = mockContract.getGameStats();
      
      mockContract.registerPlayer("StatPlayer", "statplayer");
      const treasureResult = mockContract.createTreasure("Stat Treasure", "For stats", 1, 1, 70, 70, 1, 1);
      mockContract.claimTreasure(treasureResult.value, "statplayer");
      
      const updatedStats = mockContract.getGameStats();
      
      expect(updatedStats.totalPlayers).toBe(initialStats.totalPlayers + 1);
      expect(updatedStats.totalTreasuresFound).toBe(initialStats.totalTreasuresFound + 1);
      expect(updatedStats.prizePool).toBe(initialStats.prizePool + 1000000);
      expect(updatedStats.gameActive).toBe(true);
    });
  });

  describe("Player Experience and Leveling", () => {
    it("should update player experience and level correctly", () => {
      mockContract.registerPlayer("Learner", "learner123");
      
      // Claim multiple treasures to gain experience
      for (let i = 0; i < 5; i++) {
        const treasureResult = mockContract.createTreasure(`Treasure${i}`, `Description${i}`, 1, 1, 80 + i, 80 + i, 1, 1);
        mockContract.claimTreasure(treasureResult.value, "learner123");
      }
      
      const playerInfo = mockContract.getPlayerInfo("learner123");
      expect(playerInfo.experience).toBe(1000); // 5 treasures * 200 exp each
      expect(playerInfo.level).toBe(2); // Level 1 + (1000 exp / 1000)
      expect(playerInfo.treasuresFound).toBe(5);
    });

    it("should track exploration experience", () => {
      mockContract.registerPlayer("Scout", "scout123");
      const locationResult = mockContract.createLocation("Scout Woods", "Easy exploration", 1, 90, 90, 10, 1, 1, 25000);
      
      const initialPlayerInfo = mockContract.getPlayerInfo("scout123");
      mockContract.exploreLocation(locationResult.value, 90, 90, "scout123");
      const updatedPlayerInfo = mockContract.getPlayerInfo("scout123");
      
      expect(updatedPlayerInfo.experience).toBe(initialPlayerInfo.experience + 50);
    });
  });

  describe("Energy System", () => {
    it("should consume energy during exploration", () => {
      mockContract.registerPlayer("Energetic", "energetic123");
      const locationResult = mockContract.createLocation("Energy Test", "Costs energy", 1, 95, 95, 5, 1, 1, 10000);
      
      // Explore 10 times to drain energy
      for (let i = 0; i < 10; i++) {
        mockContract.exploreLocation(locationResult.value, 95, 95, "energetic123");
      }
      
      const playerInfo = mockContract.getPlayerInfo("energetic123");
      expect(playerInfo.energy).toBe(0); // Started with 100, used 10 energy 10 times
      
      // Should fail on 11th exploration due to insufficient energy
      const failedExploration = mockContract.exploreLocation(locationResult.value, 95, 95, "energetic123");
      expect(failedExploration.type).toBe("error");
      expect(failedExploration.value).toBe(108); // ERR_COOLDOWN_ACTIVE
    });
  });

  describe("Error Handling", () => {
    it("should handle non-existent treasure queries gracefully", () => {
      const treasureInfo = mockContract.getTreasureInfo(999999);
      expect(treasureInfo).toBeNull();
    });

    it("should handle non-existent player queries gracefully", () => {
      const playerInfo = mockContract.getPlayerInfo("nonexistent");
      expect(playerInfo).toBeNull();
    });

    it("should handle non-existent location queries gracefully", () => {
      const locationInfo = mockContract.getLocationInfo(999999);
      expect(locationInfo).toBeNull();
    });
  });
});