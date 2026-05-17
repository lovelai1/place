--!strict

local ArenaConfig = {
	TeamSizes = { 2, 3, 5 }, MatchDuration = { BaseSeconds = 300, SuddenDeathAt = 270, TimeLimitExpiry = "DrawOrLowerHP" },
	Matchmaking = { StartingRating = 1500, PlacementMatches = 10, RatingFloor = 0, MaxRatingDifference = 300, KFactor = { [0] = 64, [1400] = 48, [1800] = 32, [2100] = 24, [2400] = 16 } },
	Seasons = { DurationWeeks = 20, EndOfSeasonDecay = 0.10, TitleThresholds = { { Title = "Combatant", MinRating = 1400 }, { Title = "Challenger", MinRating = 1600 }, { Title = "Rival", MinRating = 1800 }, { Title = "Duelist", MinRating = 2000 }, { Title = "Phantom Elite", MinRating = 2200 }, { Title = "Ghost Gladiator", TopPercent = 0.003 } } },
	RewardStructure = { PerWin = { ConquestPoints = 125, RatingGain = "dynamic" }, PerLoss = { ConquestPoints = 35, RatingGain = "dynamic" }, WeeklyCap = { ConquestPoints = 1750, BonusAtRating = { [1600] = 250, [1800] = 250, [2000] = 250, [2200] = 250 } } },
	Maps = { { Name = "Ashen Spire", SpecialRule = "Moving Pillars" }, { Name = "Moonwell Ring", SpecialRule = "None" }, { Name = "Crypt of Echoes", SpecialRule = "Fog of War Edges" }, { Name = "Sunken Sanctum", SpecialRule = "Waterfall Knockup" } },
	CombatRules = { ResurrectionAllowed = false, PotionCooldownShared = true, DrinkingAllowed = false, PetReviveAllowed = false },
}

return ArenaConfig
