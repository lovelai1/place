--!strict

local ProfessionConfig = {}

local function defaultXPFormula(level: number): number
	return math.floor(50 * (level ^ 1.6))
end

local tierNames = { [1] = "Novice", [21] = "Trailhand", [41] = "Stonecaller", [61] = "Deepdelver", [76] = "Veinmaster", [91] = "Ghostforged" }

ProfessionConfig.Mining = {
	MaxLevel = 100, ExperiencePerLevel = defaultXPFormula, TierNames = tierNames,
	Materials = {
		{ Name = "Copper Ore", MinLevel = 1, NodeColor = Color3.fromRGB(184, 115, 51) }, { Name = "Pale Tin", MinLevel = 15, NodeColor = Color3.fromRGB(145, 163, 176) },
		{ Name = "Grim Iron", MinLevel = 30, NodeColor = Color3.fromRGB(100, 100, 100) }, { Name = "Sun Gold", MinLevel = 40, NodeColor = Color3.fromRGB(255, 215, 0) },
		{ Name = "Moonsteel", MinLevel = 55, NodeColor = Color3.fromRGB(176, 196, 222) }, { Name = "Soulvein Ore", MinLevel = 75, NodeColor = Color3.fromRGB(80, 200, 80) },
		{ Name = "Phantomite", MinLevel = 95, NodeColor = Color3.fromRGB(210, 210, 255) },
	},
	PassiveBonus = { Stamina = 5, ExtraBagSlots = 2 },
}

ProfessionConfig.Alchemy = {
	MaxLevel = 100, ExperiencePerLevel = defaultXPFormula, TierNames = tierNames,
	Materials = { { Name = "Mistleaf", MinLevel = 1 }, { Name = "Silvercap", MinLevel = 1 }, { Name = "Graveroot", MinLevel = 15 }, { Name = "Briarshade", MinLevel = 25 }, { Name = "Tidekelp", MinLevel = 35 }, { Name = "Lifebloom", MinLevel = 45 }, { Name = "Kingsveil", MinLevel = 50 }, { Name = "Dream Ash", MinLevel = 60 }, { Name = "Frostcap", MinLevel = 75 }, { Name = "Ghost Lotus", MinLevel = 90 } },
	Recipes = {
		{ Name = "Minor Healing Potion", RequiredLevel = 1, Duration = 0, Ingredients = { { "Mistleaf", 2 }, { "Empty Vial", 1 } }, Effect = { HealHP = 75 } },
		{ Name = "Lesser Healing Potion", RequiredLevel = 12, Duration = 0, Ingredients = { { "Graveroot", 2 }, { "Mistleaf", 1 }, { "Empty Vial", 1 } }, Effect = { HealHP = 250 } },
		{ Name = "Mana Potion", RequiredLevel = 24, Duration = 0, Ingredients = { { "Tidekelp", 2 }, { "Lifebloom", 1 }, { "Empty Vial", 1 } }, Effect = { RestoreMana = 800 } },
		{ Name = "Flask of Focused Spirits", RequiredLevel = 60, Duration = 3600, Cooldown = 120, Ingredients = { { "Dream Ash", 5 }, { "Frostcap", 3 }, { "Flask Vial", 1 } }, Effect = { BonusIntellect = 40 }, PersistsThroughDeath = true },
	},
	PassiveBonus = { PotionDurationBonus = 0.25, DoubleBrewChance = 0.15 },
}

-- Normalized profession schema consumed by ProfessionValidator and ProfessionService.
-- The legacy display data above is preserved for UI/theme consumers.
ProfessionConfig.Professions = {
	Mining = {
		Name = "Mining",
		MaxLevel = 100,
		ExperiencePerLevel = 100,
		Materials = {
			copper_ore = { Level = 1, XPReward = 10, ItemId = "copper_ore", Amount = 1 },
		},
		Recipes = {},
	},
	Alchemy = {
		Name = "Alchemy",
		MaxLevel = 100,
		ExperiencePerLevel = 150,
		Materials = {
			mistleaf = { Level = 1, XPReward = 8, ItemId = "item_mistleaf", Amount = 1 },
		},
		Recipes = {
			health_potion = {
				Level = 1,
				XPReward = 20,
				Ingredients = {
					{ ItemId = "item_mistleaf", Amount = 2 },
					{ ItemId = "empty_vial", Amount = 1 },
				},
				Output = { ItemId = "item_health_potion", Amount = 1 },
			},
			mana_potion = {
				Level = 10,
				XPReward = 40,
				Ingredients = {
					{ ItemId = "item_mistleaf", Amount = 1 },
					{ ItemId = "empty_vial", Amount = 1 },
				},
				Output = { ItemId = "item_mana_potion", Amount = 1 },
			},
		},
	},
}

return ProfessionConfig
