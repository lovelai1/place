--!strict
--------------------------------------------------------------------------------
-- GhostyRPG | AbilityConfig.lua
-- ReplicatedStorage/Shared/Config/AbilityConfig.lua
--
-- Pure replicated data only: no combat execution, no UI, no side effects.
--
-- FIX (Phase 6 patch):
--   BUG FIXED 1: Added GetAvailableAbilities() which was called from Boot and
--     AbilityService but did not exist, causing a server crash on startup.
--   BUG FIXED 2: Added optional `minMagicTier` field to AbilityDefinition type
--     and populated it on abilities that require higher magic tiers, so
--     AbilityService.CanCastTier checks behave correctly.
--   BUG FIXED 3: Added six Undead class ability sets from the roadmap:
--     PhantomSoul, SkeletonWarrior, PhantomMage, DeathKnight, Lich, TrueOverlord.
--------------------------------------------------------------------------------

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
	-- Phase 6: required by AbilityService.CanCastTier; nil means no tier gate
	minMagicTier: number?,
}

local Abilities: { [string]: AbilityDefinition } = {

	------------------------------------------------------------------------
	-- WARRIOR | Rage | Tank / DPS
	------------------------------------------------------------------------
	WARRIOR_TAUNT             = { id="WARRIOR_TAUNT",             name="Taunt",             description="Force a single enemy to attack you for 3 seconds. Does not deal damage.",                                          className="Warrior",       allowedRoles={"Tank"},           requiredLevel=1,  resourceType="Rage",   resourceCost=0,  cooldown=8,   globalCooldown=0,   range=12, targetType="Enemy",     effectType="Taunt",       power=0,    threatModifier=3.5, tags={"Taunt","Utility","OffGCD"} },
	WARRIOR_SHIELD_SLAM       = { id="WARRIOR_SHIELD_SLAM",       name="Shield Slam",       description="Slam your shield into the enemy, dealing physical damage and generating high threat.",                              className="Warrior",       allowedRoles={"Tank"},           requiredLevel=1,  resourceType="Rage",   resourceCost=20, cooldown=6,   globalCooldown=1.5, range=5,  targetType="Enemy",     effectType="Damage",      power=1.2,  threatModifier=2.5, tags={"Physical","Melee","Shield"} },
	WARRIOR_DEFENSIVE_STANCE  = { id="WARRIOR_DEFENSIVE_STANCE",  name="Defensive Stance",  description="Enter a protective stance, reducing incoming damage by 20% and boosting threat generation.",                       className="Warrior",       allowedRoles={"Tank"},           requiredLevel=2,  resourceType="Rage",   resourceCost=0,  cooldown=20,  globalCooldown=0,   range=0,  targetType="Self",      effectType="Shield",      power=0.20, threatModifier=1.5, tags={"Stance","Defensive","Self","OffGCD"} },
	WARRIOR_BATTLE_SHOUT      = { id="WARRIOR_BATTLE_SHOUT",      name="Battle Shout",      description="A rallying war cry that raises the attack power of all nearby allies.",                                            className="Warrior",       allowedRoles={"Tank","DPS"},     requiredLevel=3,  resourceType="Rage",   resourceCost=10, cooldown=30,  globalCooldown=1.5, range=20, targetType="AreaAlly",  effectType="Buff",        power=0.15, threatModifier=1.0, tags={"Buff","AoE","Physical"} },
	WARRIOR_HEROIC_STRIKE     = { id="WARRIOR_HEROIC_STRIKE",     name="Heroic Strike",     description="A powerful overhead swing dealing heavy physical damage.",                                                          className="Warrior",       allowedRoles={"DPS","Tank"},     requiredLevel=1,  resourceType="Rage",   resourceCost=15, cooldown=0,   globalCooldown=1.5, range=5,  targetType="Enemy",     effectType="Damage",      power=1.5,  threatModifier=1.2, tags={"Physical","Melee"} },
	WARRIOR_WHIRLWIND         = { id="WARRIOR_WHIRLWIND",         name="Whirlwind",         description="Spin in a furious arc, striking all nearby enemies with your weapon.",                                             className="Warrior",       allowedRoles={"DPS"},            requiredLevel=6,  resourceType="Rage",   resourceCost=25, cooldown=10,  globalCooldown=1.5, range=8,  targetType="AreaEnemy", effectType="Damage",      power=1.1,  threatModifier=1.3, tags={"Physical","Melee","AoE"} },

	------------------------------------------------------------------------
	-- PALADIN | Mana | Tank / Healer / DPS
	------------------------------------------------------------------------
	PALADIN_HOLY_LIGHT        = { id="PALADIN_HOLY_LIGHT",        name="Holy Light",        description="Channel radiant divine energy to heal a friendly target.",                                                         className="Paladin",       allowedRoles={"Healer"},         requiredLevel=1,  resourceType="Mana",   resourceCost=30, cooldown=0,   globalCooldown=1.5, range=30, targetType="Ally",      effectType="Heal",        power=1.4,  threatModifier=0.5, tags={"Holy","Heal","Single"} },
	PALADIN_LAY_ON_HANDS      = { id="PALADIN_LAY_ON_HANDS",      name="Lay on Hands",      description="Pour your remaining holy energy into an ally, restoring a large amount of health. Long cooldown.",                className="Paladin",       allowedRoles={"Healer","Tank"},  requiredLevel=8,  resourceType="Mana",   resourceCost=80, cooldown=300, globalCooldown=1.5, range=20, targetType="Ally",      effectType="Heal",        power=5.0,  threatModifier=0.3, tags={"Holy","Heal","Emergency","Cooldown"} },
	PALADIN_DIVINE_SHIELD     = { id="PALADIN_DIVINE_SHIELD",     name="Divine Shield",     description="Surround yourself with a bubble of holy energy, absorbing significant incoming damage.",                          className="Paladin",       allowedRoles={"Tank","Healer"},  requiredLevel=4,  resourceType="Mana",   resourceCost=25, cooldown=60,  globalCooldown=0,   range=0,  targetType="Self",      effectType="Shield",      power=1.0,  threatModifier=0.5, tags={"Holy","Shield","Defensive","Self","OffGCD"} },
	PALADIN_CONSECRATION      = { id="PALADIN_CONSECRATION",      name="Consecration",      description="Consecrate the ground beneath you, dealing Holy damage to all nearby enemies and generating steady threat.",      className="Paladin",       allowedRoles={"Tank","DPS"},     requiredLevel=5,  resourceType="Mana",   resourceCost=40, cooldown=12,  globalCooldown=1.5, range=8,  targetType="AreaEnemy", effectType="Damage",      power=0.8,  threatModifier=1.8, tags={"Holy","AoE","GroundEffect"} },
	PALADIN_HAMMER_OF_JUSTICE = { id="PALADIN_HAMMER_OF_JUSTICE", name="Hammer of Justice", description="Strike an enemy with righteous force, dealing Holy damage and generating high threat.",                           className="Paladin",       allowedRoles={"Tank","DPS"},     requiredLevel=1,  resourceType="Mana",   resourceCost=20, cooldown=4,   globalCooldown=1.5, range=5,  targetType="Enemy",     effectType="Damage",      power=1.1,  threatModifier=1.6, tags={"Holy","Melee"} },

	------------------------------------------------------------------------
	-- MAGE | Mana | DPS
	------------------------------------------------------------------------
	MAGE_FIREBALL             = { id="MAGE_FIREBALL",             name="Fireball",          description="Hurl a blazing ball of fire at a distant enemy.",                                                                  className="Mage",          allowedRoles={"DPS"},            requiredLevel=1,  resourceType="Mana",   resourceCost=25, cooldown=0,   globalCooldown=1.5, range=40, targetType="Enemy",     effectType="Damage",      power=1.6,  threatModifier=1.0, tags={"Fire","Ranged","Spell"} },
	MAGE_ARCANE_BLAST         = { id="MAGE_ARCANE_BLAST",         name="Arcane Blast",      description="Unleash a focused bolt of raw arcane energy.",                                                                     className="Mage",          allowedRoles={"DPS"},            requiredLevel=1,  resourceType="Mana",   resourceCost=20, cooldown=0,   globalCooldown=1.5, range=40, targetType="Enemy",     effectType="Damage",      power=1.4,  threatModifier=1.0, tags={"Arcane","Ranged","Spell"} },
	MAGE_FROST_NOVA           = { id="MAGE_FROST_NOVA",           name="Frost Nova",        description="Burst with a shockwave of frost, dealing Frost damage to all nearby enemies.",                                    className="Mage",          allowedRoles={"DPS"},            requiredLevel=3,  resourceType="Mana",   resourceCost=35, cooldown=15,  globalCooldown=1.5, range=10, targetType="AreaEnemy", effectType="Damage",      power=1.0,  threatModifier=1.2, tags={"Frost","AoE","Spell"} },
	MAGE_MANA_SHIELD          = { id="MAGE_MANA_SHIELD",          name="Mana Shield",       description="Convert Mana into a protective barrier that absorbs incoming hits.",                                               className="Mage",          allowedRoles={"DPS"},            requiredLevel=5,  resourceType="Mana",   resourceCost=30, cooldown=30,  globalCooldown=0,   range=0,  targetType="Self",      effectType="Shield",      power=0.8,  threatModifier=0.5, tags={"Arcane","Shield","Defensive","Self","OffGCD"} },
	MAGE_BLINK                = { id="MAGE_BLINK",                name="Blink",             description="Teleport forward in an instant, breaking movement-impairing effects.",                                            className="Mage",          allowedRoles={"DPS"},            requiredLevel=6,  resourceType="Mana",   resourceCost=15, cooldown=15,  globalCooldown=0,   range=20, targetType="Self",      effectType="Buff",        power=0,    threatModifier=0.8, tags={"Arcane","Mobility","Utility","Self","OffGCD"} },

	------------------------------------------------------------------------
	-- PRIEST | Mana | Healer / DPS
	------------------------------------------------------------------------
	PRIEST_FLASH_HEAL         = { id="PRIEST_FLASH_HEAL",         name="Flash Heal",        description="A quick but expensive heal on a single friendly target.",                                                          className="Priest",        allowedRoles={"Healer"},         requiredLevel=1,  resourceType="Mana",   resourceCost=25, cooldown=0,   globalCooldown=1.5, range=35, targetType="Ally",      effectType="Heal",        power=1.2,  threatModifier=0.4, tags={"Holy","Heal","Single","Fast"} },
	PRIEST_RENEW              = { id="PRIEST_RENEW",              name="Renew",             description="Suffuse the target with holy energy, healing them gradually over time.",                                           className="Priest",        allowedRoles={"Healer"},         requiredLevel=3,  resourceType="Mana",   resourceCost=20, cooldown=0,   globalCooldown=1.5, range=35, targetType="Ally",      effectType="Heal",        power=0.9,  threatModifier=0.3, tags={"Holy","Heal","HealOverTime"} },
	PRIEST_PRAYER_OF_HEALING  = { id="PRIEST_PRAYER_OF_HEALING",  name="Prayer of Healing", description="A powerful group prayer that heals all nearby allies.",                                                            className="Priest",        allowedRoles={"Healer"},         requiredLevel=6,  resourceType="Mana",   resourceCost=55, cooldown=10,  globalCooldown=1.5, range=25, targetType="AreaAlly",  effectType="Heal",        power=1.0,  threatModifier=0.6, tags={"Holy","Heal","AoE"} },
	PRIEST_POWER_WORD_SHIELD  = { id="PRIEST_POWER_WORD_SHIELD",  name="Power Word: Shield",description="Surround an ally with a defensive shield that absorbs the next instance of damage.",                              className="Priest",        allowedRoles={"Healer","DPS"},   requiredLevel=2,  resourceType="Mana",   resourceCost=20, cooldown=8,   globalCooldown=1.5, range=35, targetType="Ally",      effectType="Shield",      power=1.1,  threatModifier=0.5, tags={"Holy","Shield","Absorb"} },
	PRIEST_SMITE              = { id="PRIEST_SMITE",              name="Smite",             description="Strike an enemy with a bolt of holy light.",                                                                       className="Priest",        allowedRoles={"DPS","Healer"},   requiredLevel=1,  resourceType="Mana",   resourceCost=15, cooldown=0,   globalCooldown=1.5, range=35, targetType="Enemy",     effectType="Damage",      power=1.0,  threatModifier=1.0, tags={"Holy","Ranged","Spell"} },

	------------------------------------------------------------------------
	-- ROGUE | Energy | DPS
	------------------------------------------------------------------------
	ROGUE_SINISTER_STRIKE     = { id="ROGUE_SINISTER_STRIKE",     name="Sinister Strike",   description="A quick, vicious stab that generates a Combo Point on the target.",                                               className="Rogue",         allowedRoles={"DPS"},            requiredLevel=1,  resourceType="Energy", resourceCost=30, cooldown=0,   globalCooldown=1.0, range=5,  targetType="Enemy",     effectType="Damage",      power=1.1,  threatModifier=0.9, tags={"Physical","Melee","ComboBuilder"} },
	ROGUE_BACKSTAB            = { id="ROGUE_BACKSTAB",            name="Backstab",          description="Drive your blade into an unguarded back, dealing devastating damage. Positional requirement.",                    className="Rogue",         allowedRoles={"DPS"},            requiredLevel=1,  resourceType="Energy", resourceCost=40, cooldown=0,   globalCooldown=1.0, range=5,  targetType="Enemy",     effectType="Damage",      power=2.0,  threatModifier=0.8, tags={"Physical","Melee","Positional","HighDamage"} },
	ROGUE_EVISCERATE          = { id="ROGUE_EVISCERATE",          name="Eviscerate",        description="A brutal finishing move whose damage scales with active Combo Points.",                                            className="Rogue",         allowedRoles={"DPS"},            requiredLevel=3,  resourceType="Energy", resourceCost=25, cooldown=0,   globalCooldown=1.0, range=5,  targetType="Enemy",     effectType="Damage",      power=1.8,  threatModifier=0.9, tags={"Physical","Melee","Finisher","ComboSpender"} },
	ROGUE_KIDNEY_SHOT         = { id="ROGUE_KIDNEY_SHOT",         name="Kidney Shot",       description="A precise strike to the kidney that deals damage and briefly stuns the target.",                                  className="Rogue",         allowedRoles={"DPS"},            requiredLevel=5,  resourceType="Energy", resourceCost=35, cooldown=20,  globalCooldown=1.0, range=5,  targetType="Enemy",     effectType="Damage",      power=1.2,  threatModifier=1.0, tags={"Physical","Melee","Stun","Control","Finisher"} },
	ROGUE_VANISH              = { id="ROGUE_VANISH",              name="Vanish",            description="Instantly enter stealth, dropping all threat. Long cooldown.",                                                     className="Rogue",         allowedRoles={"DPS"},            requiredLevel=4,  resourceType="Energy", resourceCost=0,  cooldown=120, globalCooldown=0,   range=0,  targetType="Self",      effectType="Buff",        power=0,    threatModifier=0.0, tags={"Stealth","Utility","ThreatDrop","Self","Cooldown","OffGCD"} },

	------------------------------------------------------------------------
	-- HUNTER | Focus | DPS
	------------------------------------------------------------------------
	HUNTER_AIMED_SHOT         = { id="HUNTER_AIMED_SHOT",         name="Aimed Shot",        description="A carefully lined-up ranged shot that deals high physical damage.",                                               className="Hunter",        allowedRoles={"DPS"},            requiredLevel=1,  resourceType="Focus",  resourceCost=30, cooldown=0,   globalCooldown=1.5, range=60, targetType="Enemy",     effectType="Damage",      power=1.7,  threatModifier=1.0, tags={"Physical","Ranged","Bow"} },
	HUNTER_SERPENT_STING      = { id="HUNTER_SERPENT_STING",      name="Serpent Sting",     description="Coat your arrow with venom, dealing Nature damage to the target over time.",                                      className="Hunter",        allowedRoles={"DPS"},            requiredLevel=1,  resourceType="Focus",  resourceCost=20, cooldown=0,   globalCooldown=1.5, range=50, targetType="Enemy",     effectType="Damage",      power=0.7,  threatModifier=0.8, tags={"Nature","Ranged","DamageOverTime","Poison"} },
	HUNTER_HUNTERS_MARK       = { id="HUNTER_HUNTERS_MARK",       name="Hunter's Mark",     description="Paint a target with a hunter's mark, increasing all damage the target takes.",                                   className="Hunter",        allowedRoles={"DPS"},            requiredLevel=2,  resourceType="Focus",  resourceCost=10, cooldown=0,   globalCooldown=1.5, range=60, targetType="Enemy",     effectType="Debuff",      power=0.1,  threatModifier=0.5, tags={"Debuff","Ranged","Utility"} },
	HUNTER_MULTI_SHOT         = { id="HUNTER_MULTI_SHOT",         name="Multi-Shot",        description="Loose several arrows simultaneously, striking multiple enemies in a forward arc.",                                className="Hunter",        allowedRoles={"DPS"},            requiredLevel=3,  resourceType="Focus",  resourceCost=40, cooldown=10,  globalCooldown=1.5, range=40, targetType="AreaEnemy", effectType="Damage",      power=1.0,  threatModifier=1.1, tags={"Physical","Ranged","AoE","Bow"} },
	HUNTER_RAPID_FIRE         = { id="HUNTER_RAPID_FIRE",         name="Rapid Fire",        description="Enter a firing frenzy, temporarily increasing your ranged attack speed. Long cooldown.",                         className="Hunter",        allowedRoles={"DPS"},            requiredLevel=6,  resourceType="Focus",  resourceCost=15, cooldown=120, globalCooldown=0,   range=0,  targetType="Self",      effectType="Buff",        power=0.4,  threatModifier=1.0, tags={"Physical","Ranged","Haste","Buff","Cooldown","Self","OffGCD"} },

	------------------------------------------------------------------------
	-- PHANTOM SOUL | Ectoplasm | Healer / DPS  (Undead – Tier 1+)
	------------------------------------------------------------------------
	PHANTOMSOUL_WAIL          = { id="PHANTOMSOUL_WAIL",          name="Spectral Wail",     description="Release a haunting cry that damages all nearby enemies and briefly disorients them.",                             className="PhantomSoul",   allowedRoles={"DPS"},            requiredLevel=1,  resourceType="Ectoplasm", resourceCost=20, cooldown=8,   globalCooldown=1.5, range=12, targetType="AreaEnemy", effectType="Damage",      power=0.9,  threatModifier=1.1, tags={"Spectral","AoE","Disorient"}, minMagicTier=1 },
	PHANTOMSOUL_SOUL_DRAIN    = { id="PHANTOMSOUL_SOUL_DRAIN",    name="Soul Drain",        description="Siphon life force from an enemy, healing yourself for a portion of the damage dealt.",                           className="PhantomSoul",   allowedRoles={"DPS","Healer"},   requiredLevel=2,  resourceType="Ectoplasm", resourceCost=30, cooldown=12,  globalCooldown=1.5, range=25, targetType="Enemy",     effectType="Damage",      power=1.1,  threatModifier=0.9, tags={"Spectral","LifeSteal","Ranged"}, minMagicTier=1 },
	PHANTOMSOUL_PHASE_SHIFT   = { id="PHANTOMSOUL_PHASE_SHIFT",   name="Phase Shift",       description="Briefly phase into the ethereal plane, becoming untargetable for 1.5 seconds.",                                  className="PhantomSoul",   allowedRoles={"DPS","Healer"},   requiredLevel=4,  resourceType="Ectoplasm", resourceCost=25, cooldown=30,  globalCooldown=0,   range=0,  targetType="Self",      effectType="Buff",        power=0,    threatModifier=0.0, tags={"Spectral","Defensive","Immunity","Self","OffGCD"}, minMagicTier=1 },
	PHANTOMSOUL_SPIRIT_MEND   = { id="PHANTOMSOUL_SPIRIT_MEND",   name="Spirit Mend",       description="Channel ghostly energy into an ally, restoring health over 6 seconds.",                                           className="PhantomSoul",   allowedRoles={"Healer"},         requiredLevel=3,  resourceType="Ectoplasm", resourceCost=35, cooldown=0,   globalCooldown=1.5, range=30, targetType="Ally",      effectType="Heal",        power=1.0,  threatModifier=0.4, tags={"Spectral","Heal","HealOverTime"}, minMagicTier=1 },
	PHANTOMSOUL_HAUNT         = { id="PHANTOMSOUL_HAUNT",         name="Haunt",             description="Attach a spectral parasite to an enemy, amplifying all damage they receive for 8 seconds.",                     className="PhantomSoul",   allowedRoles={"DPS"},            requiredLevel=6,  resourceType="Ectoplasm", resourceCost=40, cooldown=20,  globalCooldown=1.5, range=30, targetType="Enemy",     effectType="Debuff",      power=0.2,  threatModifier=0.7, tags={"Spectral","Debuff","AmpDebuff"}, minMagicTier=2 },

	------------------------------------------------------------------------
	-- SKELETON WARRIOR | Marrow | Tank / DPS  (Undead – Tier 1+)
	------------------------------------------------------------------------
	SKELWAR_BONE_SHIELD       = { id="SKELWAR_BONE_SHIELD",       name="Bone Shield",       description="Conjure a barrier of animated bones that absorbs the next three hits.",                                           className="SkeletonWarrior",allowedRoles={"Tank"},           requiredLevel=1,  resourceType="Marrow",    resourceCost=20, cooldown=20,  globalCooldown=0,   range=0,  targetType="Self",      effectType="Shield",      power=0.9,  threatModifier=1.3, tags={"Bone","Shield","Defensive","Self","OffGCD"}, minMagicTier=1 },
	SKELWAR_RATTLE            = { id="SKELWAR_RATTLE",            name="Bone Rattle",       description="Smash your bones together with a terrifying clatter, taunting all nearby enemies.",                              className="SkeletonWarrior",allowedRoles={"Tank"},           requiredLevel=1,  resourceType="Marrow",    resourceCost=0,  cooldown=12,  globalCooldown=0,   range=14, targetType="AreaEnemy", effectType="Taunt",        power=0,    threatModifier=4.0, tags={"Bone","Taunt","AoE","OffGCD"}, minMagicTier=1 },
	SKELWAR_MARROW_STRIKE     = { id="SKELWAR_MARROW_STRIKE",     name="Marrow Strike",     description="Drive a sharpened bone shard into the enemy, dealing physical damage.",                                          className="SkeletonWarrior",allowedRoles={"Tank","DPS"},     requiredLevel=1,  resourceType="Marrow",    resourceCost=15, cooldown=0,   globalCooldown=1.5, range=5,  targetType="Enemy",     effectType="Damage",      power=1.3,  threatModifier=1.5, tags={"Bone","Physical","Melee"}, minMagicTier=1 },
	SKELWAR_REASSEMBLE        = { id="SKELWAR_REASSEMBLE",        name="Reassemble",        description="Rapidly knit broken bones back together, recovering a moderate amount of health.",                               className="SkeletonWarrior",allowedRoles={"Tank"},           requiredLevel=4,  resourceType="Marrow",    resourceCost=40, cooldown=25,  globalCooldown=1.5, range=0,  targetType="Self",      effectType="Heal",        power=1.0,  threatModifier=0.0, tags={"Bone","SelfHeal","Defensive","Self"}, minMagicTier=1 },
	SKELWAR_OSSIFY            = { id="SKELWAR_OSSIFY",            name="Ossify",            description="Harden your bones to stone for 6 seconds, drastically reducing all incoming damage.",                            className="SkeletonWarrior",allowedRoles={"Tank"},           requiredLevel=6,  resourceType="Marrow",    resourceCost=50, cooldown=60,  globalCooldown=0,   range=0,  targetType="Self",      effectType="Shield",      power=0.5,  threatModifier=1.2, tags={"Bone","Defensive","Cooldown","Self","OffGCD"}, minMagicTier=2 },

	------------------------------------------------------------------------
	-- PHANTOM MAGE | Ectoplasm | DPS  (Undead – Tier 2+)
	------------------------------------------------------------------------
	PHANTOMMAGE_VOID_BOLT     = { id="PHANTOMMAGE_VOID_BOLT",     name="Void Bolt",         description="Fire a bolt of void energy at a distant enemy.",                                                                  className="PhantomMage",   allowedRoles={"DPS"},            requiredLevel=1,  resourceType="Ectoplasm", resourceCost=20, cooldown=0,   globalCooldown=1.5, range=45, targetType="Enemy",     effectType="Damage",      power=1.5,  threatModifier=1.0, tags={"Void","Ranged","Spell"}, minMagicTier=2 },
	PHANTOMMAGE_ECHO_NOVA     = { id="PHANTOMMAGE_ECHO_NOVA",     name="Echo Nova",         description="Detonate spectral resonance around you, dealing Void damage to all nearby enemies.",                             className="PhantomMage",   allowedRoles={"DPS"},            requiredLevel=3,  resourceType="Ectoplasm", resourceCost=35, cooldown=15,  globalCooldown=1.5, range=10, targetType="AreaEnemy", effectType="Damage",      power=1.1,  threatModifier=1.2, tags={"Void","Spectral","AoE","Spell"}, minMagicTier=2 },
	PHANTOMMAGE_MIND_FLAY     = { id="PHANTOMMAGE_MIND_FLAY",     name="Mind Flay",         description="Assault the enemy's mind, dealing sustained Void damage and slowing their movement.",                            className="PhantomMage",   allowedRoles={"DPS"},            requiredLevel=2,  resourceType="Ectoplasm", resourceCost=25, cooldown=0,   globalCooldown=1.5, range=35, targetType="Enemy",     effectType="Damage",      power=0.8,  threatModifier=0.9, tags={"Void","Ranged","Slow","Channeled"}, minMagicTier=2 },
	PHANTOMMAGE_ETHEREAL_FORM = { id="PHANTOMMAGE_ETHEREAL_FORM", name="Ethereal Form",     description="Dissolve into pure spectral energy, becoming immune and increasing spell power. Long cooldown.",                 className="PhantomMage",   allowedRoles={"DPS"},            requiredLevel=8,  resourceType="Ectoplasm", resourceCost=0,  cooldown=180, globalCooldown=0,   range=0,  targetType="Self",      effectType="Buff",        power=0.3,  threatModifier=0.6, tags={"Void","Spectral","Immunity","Cooldown","Self","OffGCD"}, minMagicTier=3 },
	PHANTOMMAGE_SOUL_BURST    = { id="PHANTOMMAGE_SOUL_BURST",    name="Soul Burst",        description="Unleash concentrated soul energy in a massive explosion that hits everything nearby.",                            className="PhantomMage",   allowedRoles={"DPS"},            requiredLevel=6,  resourceType="Ectoplasm", resourceCost=60, cooldown=30,  globalCooldown=1.5, range=15, targetType="AreaEnemy", effectType="Damage",      power=2.0,  threatModifier=1.4, tags={"Void","Spectral","AoE","HighDamage"}, minMagicTier=3 },

	------------------------------------------------------------------------
	-- DEATH KNIGHT | Runic Power | Tank / DPS  (Undead – Tier 3+)
	------------------------------------------------------------------------
	DK_DEATH_GRIP             = { id="DK_DEATH_GRIP",             name="Death Grip",        description="Rip an enemy across the battlefield to your feet with necrotic force, generating threat.",                       className="DeathKnight",   allowedRoles={"Tank"},           requiredLevel=1,  resourceType="RunicPower", resourceCost=0,  cooldown=25,  globalCooldown=0,   range=30, targetType="Enemy",     effectType="Taunt",       power=0,    threatModifier=3.0, tags={"Runic","Taunt","Mobility","OffGCD"}, minMagicTier=3 },
	DK_BLOOD_BOIL             = { id="DK_BLOOD_BOIL",             name="Blood Boil",        description="Cause the blood of nearby enemies to boil, dealing AoE disease damage.",                                         className="DeathKnight",   allowedRoles={"Tank","DPS"},     requiredLevel=1,  resourceType="RunicPower", resourceCost=20, cooldown=6,   globalCooldown=1.5, range=10, targetType="AreaEnemy", effectType="Damage",      power=0.9,  threatModifier=1.6, tags={"Runic","Disease","AoE","Melee"}, minMagicTier=3 },
	DK_DEATH_STRIKE           = { id="DK_DEATH_STRIKE",           name="Death Strike",      description="A powerful melee strike that deals physical damage and heals you based on recent damage taken.",                 className="DeathKnight",   allowedRoles={"Tank","DPS"},     requiredLevel=2,  resourceType="RunicPower", resourceCost=30, cooldown=0,   globalCooldown=1.5, range=5,  targetType="Enemy",     effectType="Damage",      power=1.4,  threatModifier=1.4, tags={"Runic","Physical","Melee","LifeSteal"}, minMagicTier=3 },
	DK_ANTI_MAGIC_SHELL       = { id="DK_ANTI_MAGIC_SHELL",       name="Anti-Magic Shell",  description="Surround yourself with a field that absorbs all incoming magic damage for 5 seconds.",                           className="DeathKnight",   allowedRoles={"Tank"},           requiredLevel=4,  resourceType="RunicPower", resourceCost=0,  cooldown=45,  globalCooldown=0,   range=0,  targetType="Self",      effectType="Shield",      power=1.0,  threatModifier=0.8, tags={"Runic","Shield","MagicImmunity","Self","OffGCD"}, minMagicTier=3 },
	DK_ARMY_OF_THE_DEAD       = { id="DK_ARMY_OF_THE_DEAD",       name="Army of the Dead",  description="Summon a shambling horde of undead to fight at your side. Long cooldown.",                                       className="DeathKnight",   allowedRoles={"DPS","Tank"},     requiredLevel=8,  resourceType="RunicPower", resourceCost=80, cooldown=600, globalCooldown=1.5, range=0,  targetType="Self",      effectType="Summon",      power=1.2,  threatModifier=1.5, tags={"Runic","Summon","AoE","Cooldown"}, minMagicTier=4 },

	------------------------------------------------------------------------
	-- LICH | Soul Shard | DPS / Healer  (Undead – Tier 5+)
	------------------------------------------------------------------------
	LICH_FROST_LANCE          = { id="LICH_FROST_LANCE",          name="Frost Lance",       description="Hurl a lance of pure frost that pierces through the target and freezes everything behind them.",                 className="Lich",          allowedRoles={"DPS"},            requiredLevel=1,  resourceType="SoulShard",  resourceCost=20, cooldown=0,   globalCooldown=1.5, range=50, targetType="Enemy",     effectType="Damage",      power=1.8,  threatModifier=1.0, tags={"Frost","Ranged","Spell","Pierce"}, minMagicTier=5 },
	LICH_DEATH_COIL           = { id="LICH_DEATH_COIL",           name="Death Coil",        description="Hurl unholy energy that damages enemies or heals undead allies.",                                                 className="Lich",          allowedRoles={"DPS","Healer"},   requiredLevel=2,  resourceType="SoulShard",  resourceCost=30, cooldown=0,   globalCooldown=1.5, range=40, targetType="Enemy",     effectType="Damage",      power=1.5,  threatModifier=1.0, tags={"Unholy","Ranged","Spell","DualUse"}, minMagicTier=5 },
	LICH_BLIZZARD             = { id="LICH_BLIZZARD",             name="Blizzard",          description="Call down a freezing storm over a wide area, dealing heavy Frost damage over 8 seconds.",                       className="Lich",          allowedRoles={"DPS"},            requiredLevel=5,  resourceType="SoulShard",  resourceCost=60, cooldown=25,  globalCooldown=1.5, range=35, targetType="AreaEnemy", effectType="Damage",      power=1.4,  threatModifier=1.2, tags={"Frost","AoE","Channeled","GroundEffect"}, minMagicTier=5 },
	LICH_PHYLACTERY_RECALL    = { id="LICH_PHYLACTERY_RECALL",    name="Phylactery Recall", description="Draw power from your phylactery to restore a large amount of health. Counts as a death defiance on a 10min CD.", className="Lich",          allowedRoles={"DPS","Healer"},   requiredLevel=6,  resourceType="SoulShard",  resourceCost=0,  cooldown=600, globalCooldown=0,   range=0,  targetType="Self",      effectType="Heal",        power=4.0,  threatModifier=0.0, tags={"Undead","SelfHeal","Cooldown","Legendary","Self","OffGCD"}, minMagicTier=6 },
	LICH_FROZEN_ORB           = { id="LICH_FROZEN_ORB",           name="Frozen Orb",        description="Launch a spinning orb of absolute zero that explodes for massive Frost damage on impact.",                       className="Lich",          allowedRoles={"DPS"},            requiredLevel=8,  resourceType="SoulShard",  resourceCost=80, cooldown=60,  globalCooldown=1.5, range=45, targetType="AreaEnemy", effectType="Damage",      power=2.8,  threatModifier=1.3, tags={"Frost","AoE","HighDamage","Cooldown"}, minMagicTier=7 },

	------------------------------------------------------------------------
	-- TRUE OVERLORD | Dominion | Tank / DPS / Healer  (Undead – Tier 8+)
	------------------------------------------------------------------------
	OVERLORD_SOUL_HARVEST     = { id="OVERLORD_SOUL_HARVEST",     name="Soul Harvest",      description="Tear the souls from all nearby enemies simultaneously, dealing massive AoE damage and healing allies.",          className="TrueOverlord",  allowedRoles={"DPS","Healer"},   requiredLevel=1,  resourceType="Dominion",   resourceCost=50, cooldown=30,  globalCooldown=1.5, range=15, targetType="AreaEnemy", effectType="Damage",      power=2.2,  threatModifier=1.2, tags={"Void","Spectral","AoE","LifeSteal","HighDamage"}, minMagicTier=8 },
	OVERLORD_DOMINATE         = { id="OVERLORD_DOMINATE",         name="Dominate",          description="Seize control of an enemy, turning them into a temporary ally. Does not work on bosses.",                       className="TrueOverlord",  allowedRoles={"DPS"},            requiredLevel=3,  resourceType="Dominion",   resourceCost=80, cooldown=120, globalCooldown=1.5, range=30, targetType="Enemy",     effectType="Control",     power=0,    threatModifier=0.5, tags={"Void","Control","Charm","Cooldown"}, minMagicTier=8 },
	OVERLORD_UNDYING_WILL     = { id="OVERLORD_UNDYING_WILL",     name="Undying Will",      description="Project your dominion onto all allies, making every party member temporarily unkillable.",                       className="TrueOverlord",  allowedRoles={"Tank","Healer"},  requiredLevel=6,  resourceType="Dominion",   resourceCost=100,cooldown=600, globalCooldown=1.5, range=25, targetType="AreaAlly",  effectType="Shield",      power=1.0,  threatModifier=1.0, tags={"Void","Immunity","Buff","AoE","Legendary","Cooldown"}, minMagicTier=9 },
	OVERLORD_VOID_RUPTURE     = { id="OVERLORD_VOID_RUPTURE",     name="Void Rupture",      description="Tear open a rift in reality, unleashing a torrent of void energy in a massive radius.",                         className="TrueOverlord",  allowedRoles={"DPS"},            requiredLevel=5,  resourceType="Dominion",   resourceCost=70, cooldown=45,  globalCooldown=1.5, range=20, targetType="AreaEnemy", effectType="Damage",      power=3.0,  threatModifier=1.5, tags={"Void","AoE","HighDamage","Rift"}, minMagicTier=8 },
	OVERLORD_NECROMANTIC_AURA = { id="OVERLORD_NECROMANTIC_AURA", name="Necromantic Aura",  description="Radiate overwhelming necrotic energy, boosting all undead allies and generating extreme threat.",               className="TrueOverlord",  allowedRoles={"Tank","DPS"},     requiredLevel=2,  resourceType="Dominion",   resourceCost=30, cooldown=40,  globalCooldown=1.5, range=20, targetType="AreaAlly",  effectType="Buff",        power=0.25, threatModifier=2.5, tags={"Undead","Buff","AoE","Threat"}, minMagicTier=8 },

	------------------------------------------------------------------------
	-- SHARED | Any class / role
	------------------------------------------------------------------------
	SHARED_SECOND_WIND        = { id="SHARED_SECOND_WIND",        name="Second Wind",       description="Catch your breath, restoring a portion of your primary resource.",                                               className=nil,             allowedRoles={"Tank","DPS","Healer"}, requiredLevel=1, resourceType=nil, resourceCost=0, cooldown=60, globalCooldown=0, range=0, targetType="Self", effectType="ResourceGain", power=0.15, threatModifier=0.0, tags={"Utility","Self","ResourceGain","OffGCD"} },
}

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

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

--- Phase 6 FIX: this function was called from AbilityService and Boot but
--- was missing, causing a crash on server start.
--- Returns all abilities the given class/role/level/magicTier can currently access.
function AbilityConfig.GetAvailableAbilities(
	className: string,
	roleName: string,
	level: number,
	magicTier: number
): { AbilityDefinition }
	local result = {}
	for _, ability in pairs(Abilities) do
		-- Class gate: nil className means shared (any class may use it)
		local classOk = ability.className == nil or ability.className == className
		if not classOk then continue end

		-- Role gate
		local roleOk = false
		for _, r in ipairs(ability.allowedRoles) do
			if r == roleName then roleOk = true break end
		end
		if not roleOk then continue end

		-- Level gate
		if ability.requiredLevel > level then continue end

		-- Magic tier gate (Phase 6: minMagicTier field)
		local tierReq = ability.minMagicTier or 0
		if tierReq > magicTier then continue end

		table.insert(result, ability)
	end
	return result
end

function AbilityConfig.CanClassUseAbility(className: string, abilityId: string): boolean
	local ability = Abilities[abilityId]
	if not ability then return false end
	return ability.className == nil or ability.className == className
end

function AbilityConfig.CanRoleUseAbility(roleName: string, abilityId: string): boolean
	local ability = Abilities[abilityId]
	if not ability then return false end
	for _, allowedRole in ipairs(ability.allowedRoles) do
		if allowedRole == roleName then return true end
	end
	return false
end

return AbilityConfig
