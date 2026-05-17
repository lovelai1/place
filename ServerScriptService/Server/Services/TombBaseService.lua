--!strict
--------------------------------------------------------------------------------
-- GhostyRPG | TombBaseService.lua
-- ServerScriptService/Server/Services/TombBaseService.lua
--
-- PURPOSE:
--   Server-authoritative manager for each player's personal Tomb Base —
--   GhostyRPG's equivalent of the Tomb of Nazarick from Overlord.
--   Players upgrade their Tomb tier to unlock Floor Guardians, higher-tier
--   magic, better crafting stations, and eventually the TrueOverlord class.
--
-- GAME-DESIGN SUMMARY:
--   Tomb Tier 1 → Small crypt. Tutorial zone. Holds 1 Guardian slot.
--   Tomb Tier 2 → Bone Hall. Craftable furniture. 2 Guardians. MagicTier 3 gate.
--   Tomb Tier 3 → Lich's Antechamber. Unlocks Lich class. 4 Guardians.
--   Tomb Tier 4 → Throne of Shadows. PvP Arena access. 6 Guardians.
--   Tomb Tier 5 → Tomb of Nazarick. Overlord questline unlock. 8 Guardians.
--
-- ARCHITECTURE:
--   • Reads/writes playerData.TombData (table — see TombData type below)
--   • Fires "TombUpgraded" RemoteEvent to the owning client on upgrade
--   • Each upgrade costs Gold + Materials (items in playerData.Inventory)
--   • GuardianSlots define which NPC guardians a player can have active
--
-- BOOT INTEGRATION (Boot.server.lua):
--   local TombBaseService = require(Services:WaitForChild("TombBaseService"))
--   TombBaseService.Init(PlayerDataService, InventoryService, MagicTierService)
--
-- SCHEMA PATCH (add to PlayerDataConfig DEFAULT_DATA):
--   TombData = {
--       Tier          = 0,    -- 0 = hasn't entered tomb yet (portal is gate)
--       Guardians     = {},   -- { [slotIndex: number]: guardianId: string }
--       UnlockedRooms = {},   -- { [roomId: string]: true }
--       UpgradeLog    = {},   -- { timestamp, fromTier, toTier } ordered list
--   },
--------------------------------------------------------------------------------

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TombBaseService = {}

--------------------------------------------------------------------------------
-- TOMB TIER DEFINITIONS
--------------------------------------------------------------------------------

export type GuardianSlot = {
    SlotIndex   : number,
    UnlockedAt  : number,  -- Tomb tier at which this slot becomes available
    AllowedTiers: { number }, -- Magic tier range allowed for the guardian in this slot
}

export type TombTierDef = {
    Tier              : number,
    DisplayName       : string,
    FlavorText        : string,
    GoldCost          : number,
    RequiredLevel     : number,
    RequiredMagicTier : number,
    RequiredMaterials : { { itemId: string, amount: number } },
    GuardianSlots     : number,    -- Total available guardian slots at this tier
    UnlocksRooms      : { string },-- Room IDs that become available in the Tomb
    PerksGranted      : { string },-- Passive perk tags granted to the owner
}

local TOMB_TIER_DEFS: { [number]: TombTierDef } = {
    -- Tier 0 → 1: First entry. The tutorial crypt is built automatically when
    -- a player first touches the Graveyard Portal.
    [1] = {
        Tier              = 1,
        DisplayName       = "The Hollow Crypt",
        FlavorText        = "A crumbling burial chamber. It smells of old bones and forgotten names.",
        GoldCost          = 0,         -- Free: awarded on first portal entry
        RequiredLevel     = 1,
        RequiredMagicTier = 1,
        RequiredMaterials = {},
        GuardianSlots     = 1,
        UnlocksRooms      = { "Entrance", "BasicChamber" },
        PerksGranted      = { "HomeRespawn" },  -- Player respawns at their Tomb
    },
    [2] = {
        Tier              = 2,
        DisplayName       = "The Bone Hall",
        FlavorText        = "Pillars of stacked bones line the hall. Your first servants begin to stir.",
        GoldCost          = 2500,
        RequiredLevel     = 15,
        RequiredMagicTier = 2,
        RequiredMaterials = {
            { itemId = "StoneBrick",       amount = 50  },
            { itemId = "BoneFragment",     amount = 100 },
            { itemId = "SoulCrystal_T1",   amount = 5   },
        },
        GuardianSlots     = 2,
        UnlocksRooms      = { "GuardianBarracks", "ArcaneStudy" },
        PerksGranted      = { "HomeRespawn", "GuardianBuffer" }, -- Guardians get +10% stats
    },
    [3] = {
        Tier              = 3,
        DisplayName       = "Lich's Antechamber",
        FlavorText        = "The cold hum of necromantic energy fills every stone. The Lich class awakens.",
        GoldCost          = 12000,
        RequiredLevel     = 30,
        RequiredMagicTier = 4,
        RequiredMaterials = {
            { itemId = "StoneBrick",       amount = 200 },
            { itemId = "RuneStone",        amount = 30  },
            { itemId = "SoulCrystal_T2",   amount = 20  },
            { itemId = "NecroticEssence",  amount = 10  },
        },
        GuardianSlots     = 4,
        UnlocksRooms      = { "LichStudy", "CraftingForge", "TreasureVault_T1" },
        PerksGranted      = { "HomeRespawn", "GuardianBuffer", "LichClassAccess",
                              "CraftingBonus_5pct" },
    },
    [4] = {
        Tier              = 4,
        DisplayName       = "Throne of Shadows",
        FlavorText        = "A throne carved from obsidian and shadow-steel. Enemies dare not enter.",
        GoldCost          = 50000,
        RequiredLevel     = 45,
        RequiredMagicTier = 6,
        RequiredMaterials = {
            { itemId = "ShadowStone",      amount = 500 },
            { itemId = "RuneStone",        amount = 100 },
            { itemId = "SoulCrystal_T3",   amount = 50  },
            { itemId = "PhantomEssence",   amount = 25  },
            { itemId = "VoidShard",        amount = 5   },
        },
        GuardianSlots     = 6,
        UnlocksRooms      = {
            "ThroneRoom", "PvPArena", "TreasureVault_T2",
            "ArcaneLibrary", "GuardianSanctum",
        },
        PerksGranted      = {
            "HomeRespawn", "GuardianBuffer", "LichClassAccess",
            "CraftingBonus_10pct", "PvPArenaOwner",
            "GuardianElite",  -- Guardians gain rare ability unlocks
        },
    },
    [5] = {
        Tier              = 5,
        DisplayName       = "Tomb of Nazarick",
        FlavorText        = "The pinnacle. You have re-created the legendary tomb. The Overlord questline begins.",
        GoldCost          = 250000,
        RequiredLevel     = 60,
        RequiredMagicTier = 8,
        RequiredMaterials = {
            { itemId = "AbyssalStone",     amount = 1000 },
            { itemId = "SoulCrystal_T4",   amount = 200  },
            { itemId = "VoidShard",        amount = 50   },
            { itemId = "OsmiumIngot",      amount = 100  },
            { itemId = "DragonBone",       amount = 10   },  -- Rare dungeon drop
        },
        GuardianSlots     = 8,
        UnlocksRooms      = {
            "NazarickThrone", "FloorGuardianHall", "TreasureVault_T3",
            "ArcaneLibrary_Grand", "GuildPortal",     -- Portal to invite other players
            "OverlordSanctum",                       -- Overlord questline room
        },
        PerksGranted      = {
            "HomeRespawn", "GuardianBuffer", "LichClassAccess",
            "CraftingBonus_15pct", "PvPArenaOwner", "GuardianElite",
            "OverlordQuestlineUnlock",   -- Begins the path to TrueOverlord class
            "FloorGuardianCommand",      -- Can issue commands to Guardians in the open world
        },
    },
}

local MAX_TOMB_TIER         = 5
local UPGRADE_REMOTE_NAME   = "TombUpgraded"
local GUARDIAN_ASSIGN_REMOTE = "GuardianAssigned"

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local playerDataService  : any = nil
local inventoryService   : any = nil
local magicTierService   : any = nil
local initialized                = false
local upgradeRemote      : RemoteEvent? = nil
local guardianRemote     : RemoteEvent? = nil

--------------------------------------------------------------------------------
-- PRIVATE HELPERS
--------------------------------------------------------------------------------

local function assertInit()
    assert(initialized and playerDataService,
        "[TombBaseService] Must call Init() before use.")
end

local function ensureRemote(name: string, folder: Instance): RemoteEvent
    local existing = folder:FindFirstChild(name)
    if existing and existing:IsA("RemoteEvent") then
        return existing
    end
    local re    = Instance.new("RemoteEvent")
    re.Name     = name
    re.Parent   = folder
    return re
end

--- Returns the TombData sub-table from the player's profile, initialising it
--- to sane defaults if it was missing (handles old save files).
local function getTombData(data: { [string]: any }): { [string]: any }
    if type(data.TombData) ~= "table" then
        data.TombData = {
            Tier          = 0,
            Guardians     = {},
            UnlockedRooms = {},
            UpgradeLog    = {},
        }
    end
    return data.TombData
end

--- Checks whether the player has the required inventory items for a tier upgrade.
--- Returns (hasAll: boolean, missing: string?)
local function checkMaterials(
    player  : Player,
    tierDef : TombTierDef
): (boolean, string?)
    if #tierDef.RequiredMaterials == 0 then
        return true, nil
    end

    for _, req in ipairs(tierDef.RequiredMaterials) do
        local has = inventoryService.GetItemCount(player, req.itemId)
        if (has or 0) < req.amount then
            return false, string.format(
                "Need %dx %s (have %d).", req.amount, req.itemId, has or 0)
        end
    end
    return true, nil
end

--- Consumes all required materials from inventory for a tier upgrade.
local function consumeMaterials(player: Player, tierDef: TombTierDef)
    for _, req in ipairs(tierDef.RequiredMaterials) do
        inventoryService.RemoveItem(player, req.itemId, req.amount)
    end
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Initialise TombBaseService. Must be called after InventoryService is ready.
function TombBaseService.Init(pds: any, inv: any, mts: any)
    if initialized then
        warn("[TombBaseService] Init called more than once; ignoring.")
        return
    end

    assert(pds and pds.GetData,       "[TombBaseService] PlayerDataService required.")
    assert(pds.UpdateData,             "[TombBaseService] PlayerDataService.UpdateData required.")
    assert(inv and inv.GetItemCount,  "[TombBaseService] InventoryService.GetItemCount required.")
    assert(inv.RemoveItem,             "[TombBaseService] InventoryService.RemoveItem required.")
    -- MagicTierService is optional (allows unit testing without it)
    assert(mts and mts.GetTier,       "[TombBaseService] MagicTierService.GetTier required.")

    playerDataService = pds
    inventoryService  = inv
    magicTierService  = mts
    initialized       = true

    local remotesFolder = ReplicatedStorage
        :WaitForChild("Shared")
        :WaitForChild("Remotes")

    upgradeRemote  = ensureRemote(UPGRADE_REMOTE_NAME,    remotesFolder)
    guardianRemote = ensureRemote(GUARDIAN_ASSIGN_REMOTE, remotesFolder)

    print("[TombBaseService] Initialized. Max Tomb Tier =", MAX_TOMB_TIER)
end

--- Returns the player's current Tomb Tier (0 if they've never entered).
function TombBaseService.GetTier(player: Player): number
    assertInit()
    local data = playerDataService.GetData(player)
    if not data then return 0 end
    local tombData = getTombData(data)
    return tombData.Tier or 0
end

--- Called when a player first touches the Graveyard Portal.
--- Creates their Tier-1 Tomb automatically if they don't have one.
function TombBaseService.OnFirstPortalEnter(player: Player)
    assertInit()
    local data = playerDataService.GetData(player)
    if not data then return end

    local tombData = getTombData(data)
    if (tombData.Tier or 0) >= 1 then
        -- Already has a tomb; just teleport them in (handled by world script)
        return
    end

    -- Grant Tier 1 for free
    local tierDef = TOMB_TIER_DEFS[1]
    playerDataService.UpdateData(player, function(d: { [string]: any })
        local td      = getTombData(d)
        td.Tier       = 1
        td.Guardians  = {}
        -- Mark starting rooms as unlocked
        for _, roomId in ipairs(tierDef.UnlocksRooms) do
            td.UnlockedRooms[roomId] = true
        end
        table.insert(td.UpgradeLog, {
            timestamp = os.time(),
            fromTier  = 0,
            toTier    = 1,
        })
    end)

    if upgradeRemote then
        upgradeRemote:FireClient(player, 1, tierDef)
    end

    print(string.format("[TombBaseService] Created Tier-1 Tomb for %s.", player.Name))
end

--- Attempts to upgrade the player's Tomb to the next tier.
--- Returns (success: boolean, reason: string?)
function TombBaseService.UpgradeTomb(player: Player): (boolean, string?)
    assertInit()

    local data = playerDataService.GetData(player)
    if not data then
        return false, "Player data unavailable."
    end

    local tombData   = getTombData(data)
    local currentTier = tombData.Tier or 0
    local nextTier    = currentTier + 1

    if nextTier > MAX_TOMB_TIER then
        return false, "Your Tomb is already at the maximum tier."
    end

    local tierDef = TOMB_TIER_DEFS[nextTier]
    if not tierDef then
        return false, string.format("No Tomb tier definition for tier %d.", nextTier)
    end

    -- Level gate
    if (data.Level or 1) < tierDef.RequiredLevel then
        return false, string.format(
            "Requires Level %d (you are Level %d).",
            tierDef.RequiredLevel, data.Level or 1)
    end

    -- Magic Tier gate
    local playerMagicTier = magicTierService.GetTier(player)
    if playerMagicTier < tierDef.RequiredMagicTier then
        return false, string.format(
            "Requires Magic Tier %d (you have Tier %d).",
            tierDef.RequiredMagicTier, playerMagicTier)
    end

    -- Gold check
    if (data.Gold or 0) < tierDef.GoldCost then
        return false, string.format(
            "Requires %d Gold (you have %d).",
            tierDef.GoldCost, data.Gold or 0)
    end

    -- Material check
    local matsOk, matsReason = checkMaterials(player, tierDef)
    if not matsOk then
        return false, matsReason
    end

    -- Consume gold + materials
    consumeMaterials(player, tierDef)
    playerDataService.UpdateData(player, function(d: { [string]: any })
        d.Gold = (d.Gold or 0) - tierDef.GoldCost

        local td   = getTombData(d)
        td.Tier    = nextTier

        -- Unlock new rooms
        for _, roomId in ipairs(tierDef.UnlocksRooms) do
            td.UnlockedRooms[roomId] = true
        end

        -- Record in upgrade log
        table.insert(td.UpgradeLog, {
            timestamp = os.time(),
            fromTier  = currentTier,
            toTier    = nextTier,
        })
    end)

    -- Broadcast to client for UI / cinematic
    if upgradeRemote then
        upgradeRemote:FireClient(player, nextTier, tierDef)
    end

    print(string.format("[TombBaseService] %s upgraded Tomb: Tier %d → Tier %d.",
        player.Name, currentTier, nextTier))

    return true, nil
end

--- Assigns a Floor Guardian NPC to a slot in the player's Tomb.
--- @param guardianId  A string key from a GuardianConfig (e.g. "SkeletonGeneral")
--- @param slotIndex   1-based slot index (max = GuardianSlots for current tier)
function TombBaseService.AssignGuardian(
    player    : Player,
    guardianId: string,
    slotIndex : number
): (boolean, string?)
    assertInit()

    local data = playerDataService.GetData(player)
    if not data then return false, "Player data unavailable." end

    local tombData   = getTombData(data)
    local currentTier = tombData.Tier or 0
    local tierDef     = TOMB_TIER_DEFS[currentTier]
    if not tierDef then
        return false, "Tomb not initialised."
    end

    if slotIndex < 1 or slotIndex > tierDef.GuardianSlots then
        return false, string.format(
            "Slot %d is out of range. Your Tomb supports %d Guardian slots.",
            slotIndex, tierDef.GuardianSlots)
    end

    playerDataService.UpdateData(player, function(d: { [string]: any })
        local td = getTombData(d)
        td.Guardians[slotIndex] = guardianId
    end)

    if guardianRemote then
        guardianRemote:FireClient(player, slotIndex, guardianId)
    end

    print(string.format("[TombBaseService] %s assigned Guardian '%s' to slot %d.",
        player.Name, guardianId, slotIndex))
    return true, nil
end

--- Returns the full TombData for a player (safe read-only snapshot).
function TombBaseService.GetTombData(player: Player): { [string]: any }?
    assertInit()
    local data = playerDataService.GetData(player)
    if not data then return nil end
    return getTombData(data)
end

--- Returns whether the player has a specific room unlocked.
function TombBaseService.HasRoom(player: Player, roomId: string): boolean
    assertInit()
    local data = playerDataService.GetData(player)
    if not data then return false end
    local tombData = getTombData(data)
    return tombData.UnlockedRooms[roomId] == true
end

--- Returns the TombTierDef for a given tier (for UI display).
function TombBaseService.GetTierDef(tier: number): TombTierDef?
    return TOMB_TIER_DEFS[tier]
end

--- Returns a requirements summary for the NEXT tier, ready for client-side UI.
--- Returns nil if the player is already at max tier.
function TombBaseService.GetNextUpgradeInfo(player: Player): {
    nextTier          : number,
    displayName       : string,
    goldCost          : number,
    requiredLevel     : number,
    requiredMagicTier : number,
    materials         : { { itemId: string, amount: number } },
    playerHasEnough   : boolean,
}?
    assertInit()
    local data = playerDataService.GetData(player)
    if not data then return nil end

    local tombData    = getTombData(data)
    local currentTier = tombData.Tier or 0
    local nextTier    = currentTier + 1
    if nextTier > MAX_TOMB_TIER then return nil end

    local def = TOMB_TIER_DEFS[nextTier]
    if not def then return nil end

    local playerLevel     = data.Level or 1
    local playerMagicTier = magicTierService.GetTier(player)
    local playerGold      = data.Gold or 0

    local matsOk = true
    for _, req in ipairs(def.RequiredMaterials) do
        local has = inventoryService.GetItemCount(player, req.itemId) or 0
        if has < req.amount then
            matsOk = false
            break
        end
    end

    local hasEnough = (playerGold >= def.GoldCost)
                   and (playerLevel >= def.RequiredLevel)
                   and (playerMagicTier >= def.RequiredMagicTier)
                   and matsOk

    return {
        nextTier          = nextTier,
        displayName       = def.DisplayName,
        goldCost          = def.GoldCost,
        requiredLevel     = def.RequiredLevel,
        requiredMagicTier = def.RequiredMagicTier,
        materials         = def.RequiredMaterials,
        playerHasEnough   = hasEnough,
    }
end

return TombBaseService
