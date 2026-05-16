--!strict
-- Public ability definitions for GhostyRPG.
-- Pure replicated data only: no combat execution, no UI, no side effects.

local AbilityConfig = {}

export type AbilityDefinition = {
	id: string,
	name: string,
	description: string,
	className: string?,
	allowedRoles: { string },
	requiredLevel: number,
	resourceType: string?,
	resourceCost: number,
	cooldown: number,
	globalCooldown: number,
	range: number,
	targetType: string,
	effectType: string,
	power: number,
	threatModifier: number,
	tags: { string },
}

local Abilities: { [string]: AbilityDefinition } = {
	-- Warrior | Rage | Tank/DPS
	WARRIOR_TAUNT = { id = "WARRIOR_TAUNT", name = "Taunt", description = "Force a single enemy to attack you for 3 seconds. Does not deal damage.", className = "Warrior", allowedRoles = { "Tank" }, requiredLevel = 1, resourceType = "Rage", resourceCost = 0, cooldown = 8, globalCooldown = 0, range = 12, targetType = "Enemy", effectType = "Taunt", power = 0, threatModifier = 3.5, tags = { "Taunt", "Utility", "OffGCD" } },
	WARRIOR_SHIELD_SLAM = { id = "WARRIOR_SHIELD_SLAM", name = "Shield Slam", description = "Slam your shield into the enemy, dealing physical damage and generating high threat.", className = "Warrior", allowedRoles = { "Tank" }, requiredLevel = 1, resourceType = "Rage", resourceCost = 20, cooldown = 6, globalCooldown = 1.5, range = 5, targetType = "Enemy", effectType = "Damage", power = 1.2, threatModifier = 2.5, tags = { "Physical", "Melee", "Shield" } },
	WARRIOR_DEFENSIVE_STANCE = { id = "WARRIOR_DEFENSIVE_STANCE", name = "Defensive Stance", description = "Enter a protective stance, reducing incoming damage by 20% and boosting threat generation.", className = "Warrior", allowedRoles = { "Tank" }, requiredLevel = 2, resourceType = "Rage", resourceCost = 0, cooldown = 20, globalCooldown = 0, range = 0, targetType = "Self", effectType = "Shield", power = 0.20, threatModifier = 1.5, tags = { "Stance", "Defensive", "Self", "OffGCD" } },
	WARRIOR_BATTLE_SHOUT = { id = "WARRIOR_BATTLE_SHOUT", name = "Battle Shout", description = "A rallying war cry that raises the attack power of all nearby allies.", className = "Warrior", allowedRoles = { "Tank", "DPS" }, requiredLevel = 3, resourceType = "Rage", resourceCost = 10, cooldown = 30, globalCooldown = 1.5, range = 20, targetType = "AreaAlly", effectType = "Buff", power = 0.15, threatModifier = 1.0, tags = { "Buff", "AoE", "Physical" } },
	WARRIOR_HEROIC_STRIKE = { id = "WARRIOR_HEROIC_STRIKE", name = "Heroic Strike", description = "A powerful overhead swing dealing heavy physical damage.", className = "Warrior", allowedRoles = { "DPS", "Tank" }, requiredLevel = 1, resourceType = "Rage", resourceCost = 15, cooldown = 0, globalCooldown = 1.5, range = 5, targetType = "Enemy", effectType = "Damage", power = 1.5, threatModifier = 1.2, tags = { "Physical", "Melee" } },
	WARRIOR_WHIRLWIND = { id = "WARRIOR_WHIRLWIND", name = "Whirlwind", description = "Spin in a furious arc, striking all nearby enemies with your weapon.", className = "Warrior", allowedRoles = { "DPS" }, requiredLevel = 6, resourceType = "Rage", resourceCost = 25, cooldown = 10, globalCooldown = 1.5, range = 8, targetType = "AreaEnemy", effectType = "Damage", power = 1.1, threatModifier = 1.3, tags = { "Physical", "Melee", "AoE" } },

	-- Paladin | Mana | Tank/Healer/DPS
	PALADIN_HOLY_LIGHT = { id = "PALADIN_HOLY_LIGHT", name = "Holy Light", description = "Channel radiant divine energy to heal a friendly target.", className = "Paladin", allowedRoles = { "Healer" }, requiredLevel = 1, resourceType = "Mana", resourceCost = 30, cooldown = 0, globalCooldown = 1.5, range = 30, targetType = "Ally", effectType = "Heal", power = 1.4, threatModifier = 0.5, tags = { "Holy", "Heal", "Single" } },
	PALADIN_LAY_ON_HANDS = { id = "PALADIN_LAY_ON_HANDS", name = "Lay on Hands", description = "Pour your remaining holy energy into an ally, restoring a large amount of health. Long cooldown.", className = "Paladin", allowedRoles = { "Healer", "Tank" }, requiredLevel = 8, resourceType = "Mana", resourceCost = 80, cooldown = 300, globalCooldown = 1.5, range = 20, targetType = "Ally", effectType = "Heal", power = 5.0, threatModifier = 0.3, tags = { "Holy", "Heal", "Emergency", "Cooldown" } },
	PALADIN_DIVINE_SHIELD = { id = "PALADIN_DIVINE_SHIELD", name = "Divine Shield", description = "Surround yourself with a bubble of holy energy, absorbing significant incoming damage.", className = "Paladin", allowedRoles = { "Tank", "Healer" }, requiredLevel = 4, resourceType = "Mana", resourceCost = 25, cooldown = 60, globalCooldown = 0, range = 0, targetType = "Self", effectType = "Shield", power = 1.0, threatModifier = 0.5, tags = { "Holy", "Shield", "Defensive", "Self", "OffGCD" } },
	PALADIN_CONSECRATION = { id = "PALADIN_CONSECRATION", name = "Consecration", description = "Consecrate the ground beneath you, dealing Holy damage to all nearby enemies and generating steady threat.", className = "Paladin", allowedRoles = { "Tank", "DPS" }, requiredLevel = 5, resourceType = "Mana", resourceCost = 40, cooldown = 12, globalCooldown = 1.5, range = 8, targetType = "AreaEnemy", effectType = "Damage", power = 0.8, threatModifier = 1.8, tags = { "Holy", "AoE", "GroundEffect" } },
	PALADIN_HAMMER_OF_JUSTICE = { id = "PALADIN_HAMMER_OF_JUSTICE", name = "Hammer of Justice", description = "Strike an enemy with righteous force, dealing Holy damage and generating high threat.", className = "Paladin", allowedRoles = { "Tank", "DPS" }, requiredLevel = 1, resourceType = "Mana", resourceCost = 20, cooldown = 4, globalCooldown = 1.5, range = 5, targetType = "Enemy", effectType = "Damage", power = 1.1, threatModifier = 1.6, tags = { "Holy", "Melee" } },

	-- Mage | Mana | DPS
	MAGE_FIREBALL = { id = "MAGE_FIREBALL", name = "Fireball", description = "Hurl a blazing ball of fire at a distant enemy.", className = "Mage", allowedRoles = { "DPS" }, requiredLevel = 1, resourceType = "Mana", resourceCost = 25, cooldown = 0, globalCooldown = 1.5, range = 40, targetType = "Enemy", effectType = "Damage", power = 1.6, threatModifier = 1.0, tags = { "Fire", "Ranged", "Spell" } },
	MAGE_ARCANE_BLAST = { id = "MAGE_ARCANE_BLAST", name = "Arcane Blast", description = "Unleash a focused bolt of raw arcane energy.", className = "Mage", allowedRoles = { "DPS" }, requiredLevel = 1, resourceType = "Mana", resourceCost = 20, cooldown = 0, globalCooldown = 1.5, range = 40, targetType = "Enemy", effectType = "Damage", power = 1.4, threatModifier = 1.0, tags = { "Arcane", "Ranged", "Spell" } },
	MAGE_FROST_NOVA = { id = "MAGE_FROST_NOVA", name = "Frost Nova", description = "Burst with a shockwave of frost, dealing Frost damage to all nearby enemies.", className = "Mage", allowedRoles = { "DPS" }, requiredLevel = 3, resourceType = "Mana", resourceCost = 35, cooldown = 15, globalCooldown = 1.5, range = 10, targetType = "AreaEnemy", effectType = "Damage", power = 1.0, threatModifier = 1.2, tags = { "Frost", "AoE", "Spell" } },
	MAGE_MANA_SHIELD = { id = "MAGE_MANA_SHIELD", name = "Mana Shield", description = "Convert Mana into a protective barrier that absorbs incoming hits.", className = "Mage", allowedRoles = { "DPS" }, requiredLevel = 5, resourceType = "Mana", resourceCost = 30, cooldown = 30, globalCooldown = 0, range = 0, targetType = "Self", effectType = "Shield", power = 0.8, threatModifier = 0.5, tags = { "Arcane", "Shield", "Defensive", "Self", "OffGCD" } },
	MAGE_BLINK = { id = "MAGE_BLINK", name = "Blink", description = "Teleport forward in an instant, breaking movement-impairing effects.", className = "Mage", allowedRoles = { "DPS" }, requiredLevel = 6, resourceType = "Mana", resourceCost = 15, cooldown = 15, globalCooldown = 0, range = 20, targetType = "Self", effectType = "Buff", power = 0, threatModifier = 0.8, tags = { "Arcane", "Mobility", "Utility", "Self", "OffGCD" } },

	-- Priest | Mana | Healer/DPS
	PRIEST_FLASH_HEAL = { id = "PRIEST_FLASH_HEAL", name = "Flash Heal", description = "A quick but expensive heal on a single friendly target.", className = "Priest", allowedRoles = { "Healer" }, requiredLevel = 1, resourceType = "Mana", resourceCost = 25, cooldown = 0, globalCooldown = 1.5, range = 35, targetType = "Ally", effectType = "Heal", power = 1.2, threatModifier = 0.4, tags = { "Holy", "Heal", "Single", "Fast" } },
	PRIEST_RENEW = { id = "PRIEST_RENEW", name = "Renew", description = "Suffuse the target with holy energy, healing them gradually over time.", className = "Priest", allowedRoles = { "Healer" }, requiredLevel = 3, resourceType = "Mana", resourceCost = 20, cooldown = 0, globalCooldown = 1.5, range = 35, targetType = "Ally", effectType = "Heal", power = 0.9, threatModifier = 0.3, tags = { "Holy", "Heal", "HealOverTime" } },
	PRIEST_PRAYER_OF_HEALING = { id = "PRIEST_PRAYER_OF_HEALING", name = "Prayer of Healing", description = "A powerful group prayer that heals all nearby allies.", className = "Priest", allowedRoles = { "Healer" }, requiredLevel = 6, resourceType = "Mana", resourceCost = 55, cooldown = 10, globalCooldown = 1.5, range = 25, targetType = "AreaAlly", effectType = "Heal", power = 1.0, threatModifier = 0.6, tags = { "Holy", "Heal", "AoE" } },
	PRIEST_POWER_WORD_SHIELD = { id = "PRIEST_POWER_WORD_SHIELD", name = "Power Word: Shield", description = "Surround an ally with a defensive shield that absorbs the next instance of damage.", className = "Priest", allowedRoles = { "Healer", "DPS" }, requiredLevel = 2, resourceType = "Mana", resourceCost = 20, cooldown = 8, globalCooldown = 1.5, range = 35, targetType = "Ally", effectType = "Shield", power = 1.1, threatModifier = 0.5, tags = { "Holy", "Shield", "Absorb" } },
	PRIEST_SMITE = { id = "PRIEST_SMITE", name = "Smite", description = "Strike an enemy with a bolt of holy light.", className = "Priest", allowedRoles = { "DPS", "Healer" }, requiredLevel = 1, resourceType = "Mana", resourceCost = 15, cooldown = 0, globalCooldown = 1.5, range = 35, targetType = "Enemy", effectType = "Damage", power = 1.0, threatModifier = 1.0, tags = { "Holy", "Ranged", "Spell" } },

	-- Rogue | Energy | DPS
	ROGUE_SINISTER_STRIKE = { id = "ROGUE_SINISTER_STRIKE", name = "Sinister Strike", description = "A quick, vicious stab that generates a Combo Point on the target.", className = "Rogue", allowedRoles = { "DPS" }, requiredLevel = 1, resourceType = "Energy", resourceCost = 30, cooldown = 0, globalCooldown = 1.0, range = 5, targetType = "Enemy", effectType = "Damage", power = 1.1, threatModifier = 0.9, tags = { "Physical", "Melee", "ComboBuilder" } },
	ROGUE_BACKSTAB = { id = "ROGUE_BACKSTAB", name = "Backstab", description = "Drive your blade into an unguarded back, dealing devastating damage. Positional requirement.", className = "Rogue", allowedRoles = { "DPS" }, requiredLevel = 1, resourceType = "Energy", resourceCost = 40, cooldown = 0, globalCooldown = 1.0, range = 5, targetType = "Enemy", effectType = "Damage", power = 2.0, threatModifier = 0.8, tags = { "Physical", "Melee", "Positional", "HighDamage" } },
	ROGUE_EVISCERATE = { id = "ROGUE_EVISCERATE", name = "Eviscerate", description = "A brutal finishing move whose damage scales with active Combo Points.", className = "Rogue", allowedRoles = { "DPS" }, requiredLevel = 3, resourceType = "Energy", resourceCost = 25, cooldown = 0, globalCooldown = 1.0, range = 5, targetType = "Enemy", effectType = "Damage", power = 1.8, threatModifier = 0.9, tags = { "Physical", "Melee", "Finisher", "ComboSpender" } },
	ROGUE_KIDNEY_SHOT = { id = "ROGUE_KIDNEY_SHOT", name = "Kidney Shot", description = "A precise strike to the kidney that deals damage and briefly stuns the target.", className = "Rogue", allowedRoles = { "DPS" }, requiredLevel = 5, resourceType = "Energy", resourceCost = 35, cooldown = 20, globalCooldown = 1.0, range = 5, targetType = "Enemy", effectType = "Damage", power = 1.2, threatModifier = 1.0, tags = { "Physical", "Melee", "Stun", "Control", "Finisher" } },
	ROGUE_VANISH = { id = "ROGUE_VANISH", name = "Vanish", description = "Instantly enter stealth, dropping all threat. Long cooldown.", className = "Rogue", allowedRoles = { "DPS" }, requiredLevel = 4, resourceType = "Energy", resourceCost = 0, cooldown = 120, globalCooldown = 0, range = 0, targetType = "Self", effectType = "Buff", power = 0, threatModifier = 0.0, tags = { "Stealth", "Utility", "ThreatDrop", "Self", "Cooldown", "OffGCD" } },

	-- Hunter | Focus | DPS
	HUNTER_AIMED_SHOT = { id = "HUNTER_AIMED_SHOT", name = "Aimed Shot", description = "A carefully lined-up ranged shot that deals high physical damage.", className = "Hunter", allowedRoles = { "DPS" }, requiredLevel = 1, resourceType = "Focus", resourceCost = 30, cooldown = 0, globalCooldown = 1.5, range = 60, targetType = "Enemy", effectType = "Damage", power = 1.7, threatModifier = 1.0, tags = { "Physical", "Ranged", "Bow" } },
	HUNTER_SERPENT_STING = { id = "HUNTER_SERPENT_STING", name = "Serpent Sting", description = "Coat your arrow with venom, dealing Nature damage to the target over time.", className = "Hunter", allowedRoles = { "DPS" }, requiredLevel = 1, resourceType = "Focus", resourceCost = 20, cooldown = 0, globalCooldown = 1.5, range = 50, targetType = "Enemy", effectType = "Damage", power = 0.7, threatModifier = 0.8, tags = { "Nature", "Ranged", "DamageOverTime", "Poison" } },
	HUNTER_HUNTERS_MARK = { id = "HUNTER_HUNTERS_MARK", name = "Hunter's Mark", description = "Paint a target with a hunter's mark, increasing all damage the target takes.", className = "Hunter", allowedRoles = { "DPS" }, requiredLevel = 2, resourceType = "Focus", resourceCost = 10, cooldown = 0, globalCooldown = 1.5, range = 60, targetType = "Enemy", effectType = "Debuff", power = 0.1, threatModifier = 0.5, tags = { "Debuff", "Ranged", "Utility" } },
	HUNTER_MULTI_SHOT = { id = "HUNTER_MULTI_SHOT", name = "Multi-Shot", description = "Loose several arrows simultaneously, striking multiple enemies in a forward arc.", className = "Hunter", allowedRoles = { "DPS" }, requiredLevel = 3, resourceType = "Focus", resourceCost = 40, cooldown = 10, globalCooldown = 1.5, range = 40, targetType = "AreaEnemy", effectType = "Damage", power = 1.0, threatModifier = 1.1, tags = { "Physical", "Ranged", "AoE", "Bow" } },
	HUNTER_RAPID_FIRE = { id = "HUNTER_RAPID_FIRE", name = "Rapid Fire", description = "Enter a firing frenzy, temporarily increasing your ranged attack speed. Long cooldown.", className = "Hunter", allowedRoles = { "DPS" }, requiredLevel = 6, resourceType = "Focus", resourceCost = 15, cooldown = 120, globalCooldown = 0, range = 0, targetType = "Self", effectType = "Buff", power = 0.4, threatModifier = 1.0, tags = { "Physical", "Ranged", "Haste", "Buff", "Cooldown", "Self", "OffGCD" } },

	-- Shared | Any class/role
	SHARED_SECOND_WIND = { id = "SHARED_SECOND_WIND", name = "Second Wind", description = "Catch your breath, restoring a portion of your primary resource.", className = nil, allowedRoles = { "Tank", "DPS", "Healer" }, requiredLevel = 1, resourceType = nil, resourceCost = 0, cooldown = 60, globalCooldown = 0, range = 0, targetType = "Self", effectType = "ResourceGain", power = 0.15, threatModifier = 0.0, tags = { "Utility", "Self", "ResourceGain", "OffGCD" } },
}

function AbilityConfig.GetAbility(abilityId: string): AbilityDefinition?
	return Abilities[abilityId]
end

function AbilityConfig.IsValidAbility(abilityId: string): boolean
	return Abilities[abilityId] ~= nil
end

function AbilityConfig.GetClassAbilities(className: string): { AbilityDefinition }
	local result = {}
	for _, ability in pairs(Abilities) do
		if ability.className == className then
			table.insert(result, ability)
		end
	end
	return result
end

function AbilityConfig.CanClassUseAbility(className: string, abilityId: string): boolean
	local ability = Abilities[abilityId]
	if not ability then
		return false
	end
	return ability.className == nil or ability.className == className
end

function AbilityConfig.CanRoleUseAbility(roleName: string, abilityId: string): boolean
	local ability = Abilities[abilityId]
	if not ability then
		return false
	end
	for _, allowedRole in ipairs(ability.allowedRoles) do
		if allowedRole == roleName then
			return true
		end
	end
	return false
end

return AbilityConfig
