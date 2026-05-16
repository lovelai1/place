--!strict

local RaidConfig = {
	RaidSizes = { 10, 25, 40 }, LockoutDuration = 604800,
	RequiredRoleComposition = { [10] = { Tank = 2, Healer = 2, DPS = 6 }, [25] = { Tank = 2, Healer = 5, DPS = 18 }, [40] = { Tank = 4, Healer = 8, DPS = 28 } },
	DifficultyTiers = { LFR = { Label = "Spirit Finder", EnemyHealthMultiplier = 0.75, EnemyDamageMultiplier = 0.60, ItemLevelBonus = -10, PersonalLoot = true, VotingRequired = false, MaxWipes = -1, LockoutDuration = 86400 }, Normal = { Label = "Normal", EnemyHealthMultiplier = 1.0, EnemyDamageMultiplier = 1.0, ItemLevelBonus = 0, PersonalLoot = false, VotingRequired = true, MaxWipes = -1, LockoutDuration = 604800 }, Heroic = { Label = "Heroic", EnemyHealthMultiplier = 2.0, EnemyDamageMultiplier = 1.6, ItemLevelBonus = 15, PersonalLoot = false, VotingRequired = true, MaxWipes = -1, LockoutDuration = 604800 }, Mythic = { Label = "Mythic", EnemyHealthMultiplier = 4.0, EnemyDamageMultiplier = 2.8, ItemLevelBonus = 30, PersonalLoot = false, VotingRequired = true, MaxWipes = -1, LockedRosterSize = 20, LockoutDuration = 604800 } },
	BonusRollCurrency = { Name = "Spectral Coins", MaxPerLockout = 3, AcquiredFrom = { "World Quests", "Daily Dungeons", "Weekly Cache" } },
}

return RaidConfig
