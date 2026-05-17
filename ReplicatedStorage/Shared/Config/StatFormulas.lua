--!strict

local StatFormulas = {
	HealthPerStamina = 14, ManaPerIntellect = 15, AttackPowerPerStrength = 2.0, AttackPowerPerAgility = 1.0, RangedAPPerAgility = 2.0,
	SpellPowerPerIntellect = 1.0, HealingBonusPerSpirit = 0.25, CritChancePerAgility = 0.04, CritChancePerIntellect = 0.03, BaseCritChance = 5.0,
	PhysicalCritMultiplier = 2.0, SpellCritMultiplier = 1.5, HasteRatingPerPercent = 32.79, BaseGlobalCooldown = 1.5, MinimumGlobalCooldown = 0.75,
	HasteAffectsEnergyRegen = true, HasteAffectsManaRegen = false, DodgeChancePerAgility = 0.05, BaseDodgeChance = 5.0, BaseParryChance = 5.0, ParryChancePerStrength = 0.02,
	ArmorConstantPerLevel = 85, ArmorConstantBase = 400, ArmorDamageReductionCap = 0.75, ManaRegenSpiritMultiplier = 0.2, InCombatRegenMultiplier = 0.30, OutOfCombatRegenMultiplier = 1.00,
	StatBudgetPerItemLevel = 1.5, StatGrowthRate = 0.08, MaxLevel = 60, MaxMagicResistCap = 0.75, ResistancePerLevelFactor = 5,
	SlotBudgetMultiplier = { Head = 1.00, Chest = 1.00, Legs = 1.00, Shoulders = 0.75, Hands = 0.75, Feet = 0.75, Waist = 0.63, Wrist = 0.56, Back = 0.56, Necklace = 0.56, Ring1 = 0.56, Ring2 = 0.56, Trinket1 = 0.75, Trinket2 = 0.75, MainHand = 1.05, OffHand = 0.63, Ranged = 0.80 },
}

return StatFormulas
