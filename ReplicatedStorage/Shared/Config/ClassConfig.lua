--!strict

local ClassConfig = {}

ClassConfig.Warrior = {
	PrimaryStat = "Strength", ResourceType = "Rage", BaseHealth = 1200, BaseResource = 100, BaseArmor = 350, BaseAttackPower = 80, BaseSpellPower = 0,
	AvailableRoles = { "Tank", "DPS" },
	StatMultipliers = { AttackPowerPerStrength = 2.2, CritChancePerAgility = 0.04, HealthPerStamina = 14 },
	ResourceBehaviour = { GeneratesOnHit = true, GeneratesOnDamage = true, BaseRegen = 0, OutOfCombatDrain = 3 },
}

ClassConfig.Paladin = {
	PrimaryStat = "Strength", ResourceType = "Mana", BaseHealth = 1100, BaseResource = 100, BaseArmor = 300, BaseAttackPower = 70, BaseSpellPower = 40,
	AvailableRoles = { "Tank", "Healer", "DPS" },
	StatMultipliers = { AttackPowerPerStrength = 2.0, SpellPowerPerStrength = 0.5, SpellPowerPerIntellect = 1.0, HealthPerStamina = 14 },
	ResourceBehaviour = { GeneratesOnAbility = true, MaxCharges = 5, ChargeExpiry = false, BaseRegen = 0 },
}

ClassConfig.Mage = {
	PrimaryStat = "Intellect", ResourceType = "Mana", BaseHealth = 700, BaseResource = 2000, BaseArmor = 80, BaseAttackPower = 10, BaseSpellPower = 120,
	AvailableRoles = { "DPS" },
	StatMultipliers = { SpellPowerPerIntellect = 1.5, CritChancePerIntellect = 0.04, HealthPerStamina = 10, ManaPerIntellect = 18, ManaRegenPerSpirit = 4 },
	ResourceBehaviour = { BaseRegen = 0, OutOfCombatRegenMultiplier = 4.0 },
}

ClassConfig.Priest = {
	PrimaryStat = "Intellect", ResourceType = "Mana", BaseHealth = 750, BaseResource = 2200, BaseArmor = 90, BaseAttackPower = 15, BaseSpellPower = 110,
	AvailableRoles = { "Healer", "DPS" },
	StatMultipliers = { SpellPowerPerIntellect = 1.4, HealingPowerPerIntellect = 1.6, CritChancePerIntellect = 0.035, HealthPerStamina = 10, ManaPerIntellect = 20, ManaRegenPerSpirit = 5 },
	ResourceBehaviour = { BaseRegen = 0, OutOfCombatRegenMultiplier = 5.0 },
}

ClassConfig.Rogue = {
	PrimaryStat = "Agility", ResourceType = "Energy", BaseHealth = 900, BaseResource = 100, BaseArmor = 200, BaseAttackPower = 75, BaseSpellPower = 0,
	AvailableRoles = { "DPS" },
	StatMultipliers = { AttackPowerPerAgility = 2.0, AttackPowerPerStrength = 1.0, CritChancePerAgility = 0.05, ArmorPerAgility = 2.0, HealthPerStamina = 11 },
	ResourceBehaviour = { BaseRegen = 20, MaxResource = 100, CombatRegenRate = 20 },
}

ClassConfig.Hunter = {
	PrimaryStat = "Agility", ResourceType = "Focus", BaseHealth = 950, BaseResource = 100, BaseArmor = 180, BaseAttackPower = 72, BaseSpellPower = 0,
	AvailableRoles = { "DPS" },
	StatMultipliers = { AttackPowerPerAgility = 2.0, AttackPowerPerStrength = 0.5, CritChancePerAgility = 0.045, ArmorPerAgility = 1.5, HealthPerStamina = 11 },
	ResourceBehaviour = { BaseRegen = 6, CombatRegenRate = 6, MaxResource = 100 },
}

-- ── Phase 5: Merge Overlord undead classes ────────────────────────────────
-- OverlordClassConfig defines PhantomSoul, SkeletonWarrior, PhantomMage,
-- DeathKnight, Lich, TrueOverlord. ClassService reads ClassConfig[className]
-- so we merge here; ClassService requires no changes.
local OverlordClassConfig = require(script.Parent:WaitForChild("OverlordClassConfig"))
for className, classData in pairs(OverlordClassConfig) do
	if type(classData) == "table" and classData.Tier ~= nil then
		ClassConfig[className] = classData
	end
end

return ClassConfig
