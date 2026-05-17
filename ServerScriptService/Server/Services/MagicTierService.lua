--!strict
--------------------------------------------------------------------------------
-- GhostyRPG | MagicTierService.lua
-- ServerScriptService/Server/Services/MagicTierService.lua
--
-- PURPOSE:
--   Server-authoritative service that governs which Magic Tiers a player can
--   currently access and cast.  Inspired by Overlord's Tier Magic system
--   (Tier 1 → Tier 10 / "Super Tier").
--
-- ARCHITECTURE:
--   • Reads / writes playerData.MagicTier  (added to PlayerDataConfig schema)
--   • Reads playerData.SelectedClass to enforce class restrictions
--   • Fires a "MagicTierUnlocked" remote event to the client on tier-up
--   • All mutations go through PlayerDataService.UpdateData for safe saving
--
-- BOOT INTEGRATION  (Boot.server.lua):
--   local MagicTierService = require(Services:WaitForChild("MagicTierService"))
--   MagicTierService.Init(PlayerDataService, StatsService)
--   -- Then add to ServerHandlers if you need client-facing RPC calls.
--
-- DATASTORE NOTE:
--   PlayerDataConfig must be updated to version 3 and include:
--     MagicTier   = 1,   (default field in DEFAULT_DATA)
--   See the patch section at the bottom of this file.
--------------------------------------------------------------------------------

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared             = ReplicatedStorage:WaitForChild("Shared")
local Config             = Shared:WaitForChild("Config")
local OverlordClassConfig = require(Config:WaitForChild("OverlordClassConfig"))

local MagicTierService = {}

--------------------------------------------------------------------------------
-- TIER DEFINITIONS
-- Each tier has: a display name, a minimum player level to unlock it, the XP
-- cost in "Arcane Mastery Points" (AMP — earned from dungeons / boss kills),
-- and which spell categories become available.
--------------------------------------------------------------------------------

export type TierDefinition = {
    Name          : string,
    MinLevel      : number,    -- Player level gate
    AmpCost       : number,    -- Arcane Mastery Points required to unlock
    UnlocksSpells : { string }, -- Spell-tag categories unlocked at this tier
    FlavorText    : string,
}

-- AMP = Arcane Mastery Points (stored in playerData.ArcaneMasteryPoints)
local TIER_DEFINITIONS: { [number]: TierDefinition } = {
    [1] = {
        Name          = "First Tier",
        MinLevel      = 1,
        AmpCost       = 0,           -- Free — everyone starts here
        UnlocksSpells = { "BasicMagic", "MinorHealing", "MagicBolt" },
        FlavorText    = "The weakest rung of magic. Even a fresh spirit can manage this.",
    },
    [2] = {
        Name          = "Second Tier",
        MinLevel      = 5,
        AmpCost       = 100,
        UnlocksSpells = { "ElementalBasics", "SummonSkeleton", "CorpseExplosion" },
        FlavorText    = "Novice undead mages learn to shape elemental forces.",
    },
    [3] = {
        Name          = "Third Tier",
        MinLevel      = 15,
        AmpCost       = 350,
        UnlocksSpells = { "DarkBarrage", "SoulBind", "SkeletonArmy", "VampiricTouch" },
        FlavorText    = "Only the dedicated reach this point. The living begin to fear you.",
    },
    [4] = {
        Name          = "Fourth Tier",
        MinLevel      = 25,
        AmpCost       = 900,
        UnlocksSpells = { "DeathWave", "NecroticAura", "TimeStutter", "PlagueCloud" },
        FlavorText    = "A true undead caster. Minor lords of the living world.",
    },
    [5] = {
        Name          = "Fifth Tier",
        MinLevel      = 35,
        AmpCost       = 2200,
        UnlocksSpells = { "ShadowTempest", "SoulStorm", "AnimateDead", "CurseOfWeakness" },
        FlavorText    = "The average guild magician reaches Tier 5 after decades of study.",
    },
    [6] = {
        Name          = "Sixth Tier",
        MinLevel      = 45,
        AmpCost       = 5000,
        UnlocksSpells = { "HellBlast", "VoidRift", "ChainOfSouls", "BoneStorm" },
        FlavorText    = "Legendary. Few adventurers ever reach this level of mastery.",
    },
    [7] = {
        Name          = "Seventh Tier",
        MinLevel      = 52,
        AmpCost       = 12000,
        UnlocksSpells = { "GravityMaelstrom", "SphereSuperior", "MassSummon", "RealityDent" },
        FlavorText    = "World-class power. Nations bow before Tier 7 casters.",
    },
    [8] = {
        Name          = "Eighth Tier",
        MinLevel      = 56,
        AmpCost       = 30000,
        UnlocksSpells = { "AbyssalPortal", "NecroticArmageddon", "EternalFreeze", "SoulDevour" },
        FlavorText    = "Transcendent. The laws of the world begin to bend.",
    },
    [9] = {
        Name          = "Ninth Tier",
        MinLevel      = 60,
        AmpCost       = 80000,
        UnlocksSpells = { "TimeStop", "GrimReaper", "WorldDespair", "UltimateCurse" },
        FlavorText    = "The highest tier mortal beings can touch. You are a god among shadows.",
    },
    -- Tier 10 = Super Tier — exclusive to TrueOverlord prestige class
    [10] = {
        Name          = "Super Tier (Overlord)",
        MinLevel      = 60,
        AmpCost       = 999999,      -- Effectively requires completing the Overlord questline
        UnlocksSpells = { "ImmortalCataclysm", "AbsoluteZero", "VoidEaten" },
        FlavorText    = "Magic beyond magic. To cast this is to rewrite the rules of reality.",
    },
}

local MAX_NORMAL_TIER  = 9
local SUPER_TIER       = 10

-- Remote event name for broadcasting tier-up to the owning client.
-- Ensure this is registered in RemoteRegistry / PlayerRemotes before Init().
local TIER_UP_REMOTE_NAME = "MagicTierUnlocked"

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local playerDataService : any = nil
local statsService       : any = nil
local initialized        = false

-- Cached reference to the RemoteEvent (created lazily in Init)
local tierUpRemote: RemoteEvent? = nil

--------------------------------------------------------------------------------
-- PRIVATE HELPERS
--------------------------------------------------------------------------------

local function assertInit()
    assert(initialized and playerDataService,
        "[MagicTierService] Must call Init(playerDataService, statsService) first.")
end

--- Safely reads a numeric field from player data, returning a fallback on nil.
local function readNum(data: { [string]: any }, key: string, fallback: number): number
    local v = data[key]
    return (type(v) == "number" and v or fallback)
end

--- Returns the class-config entry for a player (checks Overlord classes first,
---   then falls back to the base ClassConfig).
local function getClassDef(className: string): { [string]: any }?
    if OverlordClassConfig.IsOverlordClass(className) then
        return OverlordClassConfig.Get(className)
    end
    -- Fallback: try the base WoW-style ClassConfig for hybrid servers.
    local ok, ClassConfig = pcall(function()
        return require(ReplicatedStorage
            :WaitForChild("Shared")
            :WaitForChild("Config")
            :WaitForChild("ClassConfig")) :: any
    end)
    if ok and ClassConfig then
        return (ClassConfig :: any)[className]
    end
    return nil
end

--- Returns true if the player's class allows casting the given tier.
local function classAllowsTier(playerData: { [string]: any }, tier: number): boolean
    local className = playerData.SelectedClass
    if not className or className == "" then
        -- No class selected: allow Tier 1 only (tutorial state)
        return tier <= 1
    end

    local classDef = getClassDef(className)
    if not classDef then
        return tier <= 1
    end

    local allowed = classDef.AllowedMagicTiers
    if not allowed then
        -- WoW-style classes that have no AllowedMagicTiers get Tier 1–2 by default
        return tier <= 2
    end

    for _, t in ipairs(allowed :: { number }) do
        if t == tier then return true end
    end
    return false
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Initialise the service. Must be called from Boot.server.lua.
--- @param pds  PlayerDataService (must expose GetData, UpdateData, ScheduleSave)
--- @param ss   StatsService (must expose Recalculate)
function MagicTierService.Init(pds: any, ss: any)
    if initialized then
        warn("[MagicTierService] Init called more than once; ignoring.")
        return
    end

    assert(pds and pds.GetData,    "[MagicTierService] PlayerDataService required.")
    assert(pds.UpdateData,          "[MagicTierService] PlayerDataService.UpdateData required.")
    assert(ss and ss.Recalculate,  "[MagicTierService] StatsService.Recalculate required.")

    playerDataService = pds
    statsService      = ss
    initialized       = true

    -- Create or locate the tier-up RemoteEvent in ReplicatedStorage.
    -- Place it alongside your other Remotes (e.g., under Shared/Remotes).
    local remotesFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
    local existing = remotesFolder:FindFirstChild(TIER_UP_REMOTE_NAME)
    if existing and existing:IsA("RemoteEvent") then
        tierUpRemote = existing
    else
        local re = Instance.new("RemoteEvent")
        re.Name   = TIER_UP_REMOTE_NAME
        re.Parent = remotesFolder
        tierUpRemote = re
    end

    print("[MagicTierService] Initialized. Max tier =", MAX_NORMAL_TIER,
          "| Super Tier =", SUPER_TIER)
end

--- Returns the TierDefinition for a given tier number (1–10), or nil.
function MagicTierService.GetTierDef(tier: number): TierDefinition?
    return TIER_DEFINITIONS[tier]
end

--- Returns the player's current MagicTier (defaults to 1 if not set).
function MagicTierService.GetTier(player: Player): number
    assertInit()
    local data = playerDataService.GetData(player)
    if not data then return 1 end
    return readNum(data, "MagicTier", 1)
end

--- Returns the player's current Arcane Mastery Points.
function MagicTierService.GetAMP(player: Player): number
    assertInit()
    local data = playerDataService.GetData(player)
    if not data then return 0 end
    return readNum(data, "ArcaneMasteryPoints", 0)
end

--- Adds AMP to a player and schedules a save. Returns the new total.
--- @param source  Short string tag for logging (e.g. "BossKill", "DungeonClear")
function MagicTierService.AddAMP(player: Player, amount: number, source: string?): number
    assertInit()
    if type(amount) ~= "number" or amount <= 0 then return 0 end

    local newTotal = 0
    playerDataService.UpdateData(player, function(data: { [string]: any })
        data.ArcaneMasteryPoints = readNum(data, "ArcaneMasteryPoints", 0) + math.floor(amount)
        newTotal = data.ArcaneMasteryPoints
    end)

    print(string.format("[MagicTierService] +%d AMP to %s from %s (total: %d)",
        amount, player.Name, tostring(source or "?"), newTotal))
    return newTotal
end

--- Attempts to unlock the next Magic Tier for the player.
--- Returns (success: boolean, reason: string?)
function MagicTierService.UnlockNextTier(player: Player): (boolean, string?)
    assertInit()

    local data = playerDataService.GetData(player)
    if not data then
        return false, "Player data unavailable."
    end

    local currentTier = readNum(data, "MagicTier", 1)
    local nextTier    = currentTier + 1

    -- Hard cap: Super Tier requires prestige class
    if nextTier > MAX_NORMAL_TIER then
        local className = data.SelectedClass or ""
        if className ~= "TrueOverlord" then
            return false, "Only a True Overlord may access Super Tier magic."
        end
    end

    if nextTier > SUPER_TIER then
        return false, "Magic Tier is already at the maximum."
    end

    local tierDef = TIER_DEFINITIONS[nextTier]
    if not tierDef then
        return false, string.format("No definition found for Tier %d.", nextTier)
    end

    -- Level check
    local playerLevel = readNum(data, "Level", 1)
    if playerLevel < tierDef.MinLevel then
        return false, string.format(
            "Requires Level %d (you are Level %d).", tierDef.MinLevel, playerLevel)
    end

    -- AMP cost check
    local currentAMP = readNum(data, "ArcaneMasteryPoints", 0)
    if currentAMP < tierDef.AmpCost then
        return false, string.format(
            "Requires %d Arcane Mastery Points (you have %d).",
            tierDef.AmpCost, currentAMP)
    end

    -- Class restriction check
    if not classAllowsTier(data, nextTier) then
        return false, string.format(
            "Your class (%s) cannot access Tier %d magic.", data.SelectedClass or "None", nextTier)
    end

    -- All checks passed — apply the upgrade
    playerDataService.UpdateData(player, function(d: { [string]: any })
        d.ArcaneMasteryPoints = readNum(d, "ArcaneMasteryPoints", 0) - tierDef.AmpCost
        d.MagicTier           = nextTier
    end)

    -- Recalculate stats in case SpellPower formulas depend on tier
    statsService.Recalculate(player)

    -- Broadcast to the owning client (triggers UI fanfare)
    if tierUpRemote then
        tierUpRemote:FireClient(player, nextTier, tierDef)
    end

    print(string.format("[MagicTierService] %s unlocked %s (Tier %d).",
        player.Name, tierDef.Name, nextTier))

    return true, nil
end

--- Returns a list of all spell-tag strings the player can currently cast.
--- The client / AbilityService should cross-reference this list before allowing cast.
function MagicTierService.GetUnlockedSpells(player: Player): { string }
    assertInit()
    local data = playerDataService.GetData(player)
    if not data then return {} end

    local currentTier = readNum(data, "MagicTier", 1)
    local spells: { string } = {}

    for tier = 1, currentTier do
        local def = TIER_DEFINITIONS[tier]
        if def and classAllowsTier(data, tier) then
            for _, spellTag in ipairs(def.UnlocksSpells) do
                table.insert(spells, spellTag)
            end
        end
    end

    return spells
end

--- Returns true if the player can cast a specific tier right now.
--- Useful for AbilityValidator quick-checks.
function MagicTierService.CanCastTier(player: Player, tier: number): boolean
    assertInit()
    local data = playerDataService.GetData(player)
    if not data then return false end

    local currentTier = readNum(data, "MagicTier", 1)
    if tier > currentTier then return false end

    return classAllowsTier(data, tier)
end

--- Grants a free tier unlock (used for tutorial / quest rewards). Bypasses AMP cost.
--- @param forcedTier  If provided, sets the tier to exactly this value (clamped to max).
function MagicTierService.GrantTier(player: Player, forcedTier: number?): (boolean, string?)
    assertInit()

    local data = playerDataService.GetData(player)
    if not data then return false, "Player data unavailable." end

    local targetTier = forcedTier and math.clamp(forcedTier, 1, SUPER_TIER)
        or readNum(data, "MagicTier", 1) + 1

    if targetTier > SUPER_TIER then
        return false, "Already at maximum tier."
    end

    local tierDef = TIER_DEFINITIONS[targetTier]
    if not tierDef then
        return false, string.format("No tier definition for %d.", targetTier)
    end

    playerDataService.UpdateData(player, function(d: { [string]: any })
        d.MagicTier = targetTier
    end)

    statsService.Recalculate(player)

    if tierUpRemote then
        tierUpRemote:FireClient(player, targetTier, tierDef)
    end

    print(string.format("[MagicTierService] Granted Tier %d to %s (forced).",
        targetTier, player.Name))
    return true, nil
end

--- Returns the full TIER_DEFINITIONS table (read-only reference).
--- Useful for client-side UI that needs to show unlock requirements.
function MagicTierService.GetAllTierDefs(): { [number]: TierDefinition }
    return TIER_DEFINITIONS
end

return MagicTierService

--------------------------------------------------------------------------------
-- SCHEMA PATCH  (apply to PlayerDataConfig.lua)
-- Add these two fields to the DEFAULT_DATA table, then bump CURRENT_VERSION to 3.
-- Also add the migration block in `migrate()` in PlayerDataService.
--
--   MagicTier            = 1,    -- int, 1–10
--   ArcaneMasteryPoints  = 0,    -- int, earned from bosses / dungeons
--
-- Migration block (PlayerDataService.lua → migrate function):
--   if data.MagicTier == nil then data.MagicTier = 1 end
--   if data.ArcaneMasteryPoints == nil then data.ArcaneMasteryPoints = 0 end
--
-- GameEnums patch:
--   export type ResourceType = ... | "SoulEnergy" | "BoneRage" | "RunePower"
--   GameEnums.ResourceType.SoulEnergy = "SoulEnergy"
--   GameEnums.ResourceType.BoneRage   = "BoneRage"
--   GameEnums.ResourceType.RunePower  = "RunePower"
--------------------------------------------------------------------------------
