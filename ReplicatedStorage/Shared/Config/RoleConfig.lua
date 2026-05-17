--!strict

local RoleConfig = {}

RoleConfig.Tank = { ThreatMultiplier = 3.0, DamageTakenMultiplier = 0.70, HealingMultiplier = 1.0, DamageDoneMultiplier = 0.85, BaseStatBonuses = { Stamina = 20, Armor = 500, Strength = 5 }, TauntEnabled = true, MaxThreatTargets = 8, SelfHealBonus = 0.15 }
RoleConfig.Healer = { ThreatMultiplier = 0.5, DamageTakenMultiplier = 1.0, HealingMultiplier = 1.35, DamageDoneMultiplier = 0.75, BaseStatBonuses = { Spirit = 25, Intellect = 15, Stamina = 5 }, AreaHealBonus = 0.10, ManaRegenBonus = 0.20, ResurrectCooldown = 300 }
RoleConfig.DPS = { ThreatMultiplier = 1.0, DamageTakenMultiplier = 1.0, HealingMultiplier = 0.75, DamageDoneMultiplier = 1.15, BaseStatBonuses = {}, CritDamageBonus = 0.05 }

return RoleConfig
