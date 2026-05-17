--!strict
--------------------------------------------------------------------------------
-- GhostyRPG | OverlordClassConfig.lua
-- ReplicatedStorage/Shared/Config/OverlordClassConfig.lua
--
-- PURPOSE:
--   Defines the six Overlord-themed undead/spirit classes that players unlock
--   as they rise from a weak spirit into a supreme Overlord. These extend
--   (but do NOT replace) the existing ClassConfig.lua WoW-style classes.
--
-- INTEGRATION:
--   ClassService.lua reads ClassConfig[className].  Require BOTH configs and
--   merge them in ClassConfig.lua (or keep separate and update ClassService
--   to check OverlordClassConfig as a fallback).  Recommended merge pattern:
--
--     local ClassConfig = require(path.ClassConfig)
--     local OverlordCfg = require(path.OverlordClassConfig)
--     for k, v in pairs(OverlordCfg) do ClassConfig[k] = v end
--
-- PHILOSOPHY (from Overlord):
--   Tier 1–2  → Weak spirit / skeleton forms      (tutorial / early game)
--   Tier 3–5  → Undead warrior / mage forms       (mid game)
--   Tier 6–8  → Death Knight / Lich / Valkyrie    (end game)
--   Super Tier → Overlord / True Undead Sovereign  (prestige)
--
-- MAGIC TIER affects which spells are castable. See MagicTierService.lua.
--------------------------------------------------------------------------------

local OverlordClassConfig = {}

-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │  TIER 1–2 STARTER CLASSES  (spawn with one of these)                   │
-- └─────────────────────────────────────────────────────────────────────────┘

-- A fragile soul that just died.  Strong single-target magic, frail body.
-- Overlord flavour: the moment of awakening as an undead — raw arcane chaos.
OverlordClassConfig.PhantomSoul = {
    DisplayName    = "Phantom Soul",
    Lore           = "A newly-departed spirit that barely remembers life. Raw magical potential hides behind their ghostly form.",
    Tier           = 1,                       -- Overlord class tier (1–9)
    PrimaryStat    = "Intellect",
    ResourceType   = "SoulEnergy",            -- New resource; see GameEnums patch below
    BaseHealth     = 450,
    BaseResource   = 180,
    BaseArmor      = 30,
    BaseAttackPower = 5,
    BaseSpellPower  = 90,
    AvailableRoles  = { "DPS" },              -- Limited roles at Tier 1
    MinMagicTier    = 1,                      -- Requires at least Magic Tier 1 to unlock
    EvolvesInto     = { "PhantomMage", "DeathKnight" }, -- Class-change options at Tier 3

    StatMultipliers = {
        SpellPowerPerIntellect  = 1.6,
        ManaPerIntellect        = 22,
        ManaRegenPerSpirit      = 6,
        HealthPerStamina        = 8,          -- Frail body = low HP scaling
        CritChancePerIntellect  = 0.045,
    },
    ResourceBehaviour = {
        -- SoulEnergy regenerates passively from kills; drains on spellcast
        BaseRegen              = 0,
        RegenPerKill           = 25,
        CombatDrainPerSecond   = 5,
        OutOfCombatRegenRate   = 15,
        MaxResource            = 180,
    },
    -- Which Overlord spell tiers this class can channel
    AllowedMagicTiers = { 1, 2 },
    PassiveAbilities  = {
        "SoulDrift",       -- Briefly phase through obstacles (0.5s)
        "EtherealBody",    -- 10 % chance to fully dodge a physical hit
    },
}

-- A skeleton who remembers martial training from its past life.
-- Tank/DPS hybrid — tough bones but slow, cannot use advanced magic.
OverlordClassConfig.SkeletonWarrior = {
    DisplayName    = "Skeleton Warrior",
    Lore           = "Bone and fury. This undead soldier retained muscle memory from countless battles fought in life.",
    Tier           = 1,
    PrimaryStat    = "Strength",
    ResourceType   = "BoneRage",             -- Generates on hit / on damage taken
    BaseHealth     = 820,
    BaseResource   = 100,
    BaseArmor      = 310,
    BaseAttackPower = 85,
    BaseSpellPower  = 0,
    AvailableRoles  = { "Tank", "DPS" },
    MinMagicTier    = 1,
    EvolvesInto     = { "DeathKnight", "BoneColossus" },

    StatMultipliers = {
        AttackPowerPerStrength  = 2.3,
        ArmorPerStamina         = 5.0,        -- Skeletons armor up with Stamina
        HealthPerStamina        = 13,
        CritChancePerAgility    = 0.035,
        DodgeChancePerAgility   = 0.03,
    },
    ResourceBehaviour = {
        GeneratesOnHit         = true,
        GeneratesOnDamage      = true,        -- Taking damage builds rage (WoW Warrior feel)
        BaseRegen              = 0,
        OutOfCombatDrain       = 5,
        MaxResource            = 100,
    },
    AllowedMagicTiers = {},                   -- Skeleton Warriors cannot cast spells at Tier 1
    PassiveAbilities  = {
        "BoneArmour",      -- Passively absorbs first 50 dmg per fight
        "UnyieldingSkeleton", -- Immune to Bleed / Poison effects
    },
}

-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │  TIER 3–5 EVOLUTION CLASSES  (unlocked via class change quest)          │
-- └─────────────────────────────────────────────────────────────────────────┘

-- The evolved Phantom Soul — a disciplined undead spellcaster.
OverlordClassConfig.PhantomMage = {
    DisplayName    = "Phantom Mage",
    Lore           = "Through study and sacrifice, this spirit has mastered the lower tiers of Overlord magic.",
    Tier           = 3,
    PrimaryStat    = "Intellect",
    ResourceType   = "SoulEnergy",
    BaseHealth     = 680,
    BaseResource   = 320,
    BaseArmor      = 75,
    BaseAttackPower = 12,
    BaseSpellPower  = 210,
    AvailableRoles  = { "DPS", "Healer" },
    MinMagicTier    = 3,
    RequiredLevel   = 20,
    EvolvesInto     = { "Lich", "AbyssalSorcerer" },

    StatMultipliers = {
        SpellPowerPerIntellect  = 1.9,
        ManaPerIntellect        = 28,
        ManaRegenPerSpirit      = 8,
        HealthPerStamina        = 9,
        CritChancePerIntellect  = 0.05,
    },
    ResourceBehaviour = {
        BaseRegen              = 0,
        RegenPerKill           = 40,
        CombatDrainPerSecond   = 8,
        OutOfCombatRegenRate   = 20,
        MaxResource            = 320,
    },
    AllowedMagicTiers = { 1, 2, 3, 4, 5 },
    PassiveAbilities  = {
        "SpellAmplification",  -- Tier 3+ spells deal 15 % bonus damage
        "PhantomStep",         -- Blink 10 studs on ability use (no cooldown share)
        "SoulDrain",           -- Kills restore 8 % max SoulEnergy
    },
}

-- A Death Knight: the martial elite of the undead army. Melee + dark magic hybrid.
OverlordClassConfig.DeathKnight = {
    DisplayName    = "Death Knight",
    Lore           = "Forged from the strongest undead warriors, they wield runeblade and dark magic as one.",
    Tier           = 4,
    PrimaryStat    = "Strength",
    ResourceType   = "RunePower",            -- Regenerates slowly, spenders deal massive burst
    BaseHealth     = 1400,
    BaseResource   = 6,                      -- Rune system: 6 charges, not a big pool
    BaseArmor      = 520,
    BaseAttackPower = 140,
    BaseSpellPower  = 60,                    -- Minor dark-magic spells
    AvailableRoles  = { "Tank", "DPS" },
    MinMagicTier    = 4,
    RequiredLevel   = 30,
    EvolvesInto     = { "AbyssalKnight", "UndeadLord" },

    StatMultipliers = {
        AttackPowerPerStrength  = 2.5,
        SpellPowerPerStrength   = 0.4,
        HealthPerStamina        = 16,
        ArmorPerStamina         = 6.0,
        CritChancePerAgility    = 0.04,
    },
    ResourceBehaviour = {
        -- Rune system: each Rune recharges independently every 10 s
        MaxRunes               = 6,
        RuneRechargeSeconds    = 10,
        MaxResource            = 6,
        GeneratesOnHit         = false,      -- Ability cost = rune count, not pool
    },
    AllowedMagicTiers = { 1, 2, 3, 4 },
    PassiveAbilities  = {
        "RuneForge",           -- Weapon deals bonus Shadow / Frost damage
        "DeathGrip",           -- Pull a target to you (iconic DK ability)
        "IcyVeins",            -- Attack speed buff on Rune use
        "DeathAndDecay",       -- Persistent AoE ground effect (Tank utility)
    },
}

-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │  TIER 6–8 ELITE CLASSES  (late game; requires high-level tomb)          │
-- └─────────────────────────────────────────────────────────────────────────┘

-- The Lich — supreme undead spellcaster.  Closest to Ainz's caster form.
OverlordClassConfig.Lich = {
    DisplayName    = "Lich",
    Lore           = "A being that transcended death through forbidden knowledge. Commands Super-Tier magic.",
    Tier           = 7,
    PrimaryStat    = "Intellect",
    ResourceType   = "SoulEnergy",
    BaseHealth     = 900,
    BaseResource   = 800,
    BaseArmor      = 100,
    BaseAttackPower = 20,
    BaseSpellPower  = 550,
    AvailableRoles  = { "DPS", "Healer" },
    MinMagicTier    = 7,
    RequiredLevel   = 50,
    RequiredTombTier = 3,                    -- Must have a Tier-3 Tomb Base
    EvolvesInto     = { "TrueOverlord" },

    StatMultipliers = {
        SpellPowerPerIntellect  = 2.4,
        ManaPerIntellect        = 38,
        ManaRegenPerSpirit      = 12,
        HealthPerStamina        = 10,
        CritChancePerIntellect  = 0.065,
    },
    ResourceBehaviour = {
        BaseRegen              = 0,
        RegenPerKill           = 80,
        CombatDrainPerSecond   = 12,
        OutOfCombatRegenRate   = 40,
        MaxResource            = 800,
    },
    AllowedMagicTiers = { 1, 2, 3, 4, 5, 6, 7, 8, 9 },  -- Unlocks Super Tier at Tier 9
    PassiveAbilities  = {
        "PhilosopherOfDeath",  -- All death-type spells cost 20 % less SoulEnergy
        "LichsPhylactery",     -- On-death: resurrect once per dungeon run at 30 % HP
        "TimeStop",            -- Super-Tier signature: freeze all enemies for 3 s (long CD)
        "CastingAura",         -- Passively boosts party spell power by 8 %
    },
}

-- The supreme prestige class. One per server. Requires completion of the Overlord Questline.
OverlordClassConfig.TrueOverlord = {
    DisplayName    = "True Overlord",
    Lore           = "You have surpassed life, death, and every rule of this world. All shall kneel.",
    Tier           = 9,
    PrimaryStat    = "Intellect",
    ResourceType   = "SoulEnergy",
    BaseHealth     = 2000,
    BaseResource   = 2000,
    BaseArmor      = 300,
    BaseAttackPower = 200,
    BaseSpellPower  = 1200,
    AvailableRoles  = { "DPS", "Tank", "Healer" },  -- Truly multi-role
    MinMagicTier    = 9,
    RequiredLevel   = 60,
    RequiredTombTier = 5,
    IsPrestigeClass  = true,                -- Only one TrueOverlord can exist per server

    StatMultipliers = {
        SpellPowerPerIntellect  = 3.0,
        AttackPowerPerStrength  = 3.0,
        ManaPerIntellect        = 50,
        HealthPerStamina        = 20,
        CritChancePerIntellect  = 0.08,
    },
    ResourceBehaviour = {
        BaseRegen              = 20,
        RegenPerKill           = 120,
        OutOfCombatRegenRate   = 60,
        MaxResource            = 2000,
    },
    AllowedMagicTiers = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },  -- 10 = Super Tier (unique)
    PassiveAbilities  = {
        "WorldClass",           -- All stats +15 %
        "FloorGuardianCommand", -- Can summon up to 3 Floor Guardian NPCs in open world
        "GravityMaelstrom",     -- Super-Tier: massive AoE implosion
        "ImmortalSovereign",    -- Revive twice per combat instead of once
        "OverlordPresence",     -- Nearby enemies have 25 % reduced damage output
    },
}

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

--- Returns the class definition table for a given class name, or nil.
function OverlordClassConfig.Get(className: string): { [string]: any }?
    return (OverlordClassConfig :: any)[className]
end

--- Returns true if className is a valid Overlord-class key.
function OverlordClassConfig.IsOverlordClass(className: string): boolean
    local entry = (OverlordClassConfig :: any)[className]
    return type(entry) == "table" and entry.Tier ~= nil
end

--- Returns a sorted list of all Overlord class names ordered by Tier.
function OverlordClassConfig.GetAllSortedByTier(): { string }
    local results: { { name: string, tier: number } } = {}
    for key, value in pairs(OverlordClassConfig :: any) do
        if type(value) == "table" and value.Tier ~= nil then
            table.insert(results, { name = key, tier = value.Tier })
        end
    end
    table.sort(results, function(a, b) return a.tier < b.tier end)

    local names: { string } = {}
    for _, entry in ipairs(results) do
        table.insert(names, entry.name)
    end
    return names
end

--- Returns which classes the player can currently evolve into, given their data.
--- Requires playerData.SelectedClass to be set and playerData.Level / MagicTier to be present.
function OverlordClassConfig.GetEvolutionOptions(playerData: { [string]: any }): { string }
    local currentClass = playerData.SelectedClass
    if not currentClass or currentClass == "" then return {} end

    local classDef = (OverlordClassConfig :: any)[currentClass]
    if not classDef or not classDef.EvolvesInto then return {} end

    local options: { string } = {}
    for _, targetClassName in ipairs(classDef.EvolvesInto) do
        local targetDef = (OverlordClassConfig :: any)[targetClassName]
        if targetDef then
            local levelOk = (not targetDef.RequiredLevel)
                         or (playerData.Level or 1) >= targetDef.RequiredLevel
            local tierOk  = (not targetDef.MinMagicTier)
                         or (playerData.MagicTier or 1) >= targetDef.MinMagicTier
            local tombOk  = (not targetDef.RequiredTombTier)
                         or (playerData.TombTier or 0) >= targetDef.RequiredTombTier
            if levelOk and tierOk and tombOk then
                table.insert(options, targetClassName)
            end
        end
    end
    return options
end

return OverlordClassConfig
