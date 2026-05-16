--!strict
-- Central configuration for GhostyRPG dungeon definitions, difficulties, and entry requirements.
-- This module is pure data plus small lookup helpers; validators/services own rule execution.

local DungeonConfig = {}

DungeonConfig.Defaults = {
	MaxPlayers = 5,
	MinPlayers = 5,
	MinLevel = 1,
	MaxLevel = math.huge,
	TimeLimit = 1800,
	RewardTier = "common",
}

DungeonConfig.DefaultRoleComposition = {
	Tank = 1,
	Healer = 1,
	DPS = 0,
}

-- Dungeon queue composition uses minimum role requirements, then fills the
-- remaining slots FIFO while respecting these caps.
DungeonConfig.QueueRoleMaximums = {
	Tank = 2,
	Healer = 2,
	DPS = 5,
}

DungeonConfig.ValidDifficulties = { "Normal", "Hard", "Nightmare" }
DungeonConfig.ValidDifficultySet = {
	Normal = true,
	Hard = true,
	Nightmare = true,
}

DungeonConfig.DifficultyLevelOffsets = {
	Normal = 0,
	Hard = 5,
	Nightmare = 10,
}

-- Compatibility aliases for older systems that read the original config shape.
DungeonConfig.MaxPlayers = DungeonConfig.Defaults.MaxPlayers
DungeonConfig.BaseTimeLimit = DungeonConfig.Defaults.TimeLimit
DungeonConfig.RequiredRoleComposition = DungeonConfig.DefaultRoleComposition
DungeonConfig.DifficultyMultipliers = {
	Normal = { EnemyHealth = 1.0, EnemyDamage = 1.0, EnemyCount = 1.0, EliteMultiplier = 1.0 },
	Hard = { EnemyHealth = 1.8, EnemyDamage = 1.5, EnemyCount = 1.15, EliteMultiplier = 1.35 },
	Nightmare = { EnemyHealth = 3.0, EnemyDamage = 2.25, EnemyCount = 1.3, EliteMultiplier = 2.0, AddsAffixModifiers = true },
}
DungeonConfig.RewardMultipliers = {
	Normal = { ItemLevelBonus = 0, GoldMultiplier = 1.0, ExperienceBonus = 1.0, BonusChestChance = 0.0 },
	Hard = { ItemLevelBonus = 10, GoldMultiplier = 1.75, ExperienceBonus = 1.35, BonusChestChance = 0.2 },
	Nightmare = { ItemLevelBonus = 25, GoldMultiplier = 3.0, ExperienceBonus = 2.0, BonusChestChance = 0.45 },
}
DungeonConfig.LootTableWeights = {
	Normal = { Common = 50, Uncommon = 30, Rare = 15, Epic = 5, Legendary = 0 },
	Hard = { Common = 20, Uncommon = 35, Rare = 30, Epic = 14, Legendary = 1 },
	Nightmare = { Common = 0, Uncommon = 15, Rare = 40, Epic = 38, Legendary = 7 },
}
DungeonConfig.AffixPool = { "Stonebound", "Soulstorm", "Blood Echo", "Wraithfire", "Grave Bloom", "Void Surge" }

DungeonConfig.RewardTiers = { "common", "uncommon", "rare", "epic", "legendary" }

DungeonConfig.Dungeons = {
	dungeon_sealed_crypt = {
		id = "dungeon_sealed_crypt",
		name = "The Sealed Crypt",
		minLevel = 1,
		maxLevel = 20,
		maxPlayers = 5,
		requiredRoles = { Tank = 1, Healer = 1, DPS = 0 },
		difficulties = { "Normal", "Hard", "Nightmare" },
		timeLimit = 1800,
		rewardTier = "common",
		Objectives = { "seal_breach", "crypt_lord" },
		Rewards = {
			Normal = { { itemId = "item_health_potion", amount = 1 } },
			Hard = { { itemId = "item_health_potion", amount = 2 } },
			Nightmare = { { itemId = "item_mana_potion", amount = 1 } },
		},
		lore = "A long-forgotten burial chamber beneath the capital whose wards have finally failed.",
	},
	dungeon_mistwood_depths = {
		id = "dungeon_mistwood_depths",
		name = "Mistwood Depths",
		minLevel = 8,
		maxLevel = 30,
		maxPlayers = 5,
		requiredRoles = { Tank = 1, Healer = 1, DPS = 0 },
		difficulties = { "Normal", "Hard", "Nightmare" },
		timeLimit = 2400,
		rewardTier = "uncommon",
		Objectives = { "root_guardian", "heart_of_mistwood" },
		Rewards = {
			Normal = { { itemId = "item_health_potion", amount = 2 } },
			Hard = { { itemId = "item_mana_potion", amount = 2 } },
			Nightmare = { { itemId = "item_sturdy_helmet", amount = 1 } },
		},
		lore = "The ancient forest swallowed this dwarven mine centuries ago. Something in the roots has learned to hunger.",
	},
}

function DungeonConfig.GetDungeon(dungeonId: string): any?
	if type(dungeonId) ~= "string" then
		return nil
	end
	return DungeonConfig.Dungeons[dungeonId]
end

function DungeonConfig.GetEffectiveMinLevel(dungeonId: string, difficulty: string): number
	local dungeon = DungeonConfig.GetDungeon(dungeonId)
	local baseMin = if dungeon and type(dungeon.minLevel) == "number" then dungeon.minLevel else DungeonConfig.Defaults.MinLevel
	local offset = DungeonConfig.DifficultyLevelOffsets[difficulty] or 0
	return baseMin + offset
end

function DungeonConfig.GetRequiredRoles(dungeonId: string): { [string]: number }
	local dungeon = DungeonConfig.GetDungeon(dungeonId)
	if dungeon and type(dungeon.requiredRoles) == "table" then
		return dungeon.requiredRoles
	end
	return DungeonConfig.DefaultRoleComposition
end

function DungeonConfig.GetQueueRoleMinimums(dungeonId: string): { [string]: number }
	local dungeon = DungeonConfig.GetDungeon(dungeonId)
	if dungeon and type(dungeon.queueRoleMinimums) == "table" then
		return dungeon.queueRoleMinimums
	end
	return DungeonConfig.GetRequiredRoles(dungeonId)
end

function DungeonConfig.GetQueueRoleMaximums(dungeonId: string): { [string]: number }
	local dungeon = DungeonConfig.GetDungeon(dungeonId)
	if dungeon and type(dungeon.queueRoleMaximums) == "table" then
		return dungeon.queueRoleMaximums
	end
	return DungeonConfig.QueueRoleMaximums
end

return DungeonConfig