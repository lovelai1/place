--!strict
--------------------------------------------------------------------------------
-- GhostyRPG | CharacterService.lua
-- ServerScriptService/Server/Services/CharacterService.lua
--
-- Manages server-side character spawn, stat application on respawn, and the
-- initial data payload sent to each client on join / class select.
--
-- FIX (Phase 7 patch):
--   BUG FIXED: buildInitialPayload() was not including magicTier or tombData.
--   TombManagementUI was therefore always receiving tier=1 and tombData=nil,
--   causing the Upgrade tab to display permanently wrong values across all
--   sessions. Both fields are now pulled from playerData and included in the
--   SendInitialData payload.
--------------------------------------------------------------------------------

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local Shared        = ReplicatedStorage:WaitForChild("Shared")
local Remotes       = Shared:WaitForChild("Remotes")

local PlayerRemotes = require(Remotes:WaitForChild("PlayerRemotes"))

local CharacterService = {}

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local playerDataService : any = nil
local statsService       : any = nil
local initialized        = false

--------------------------------------------------------------------------------
-- PRIVATE HELPERS
--------------------------------------------------------------------------------

local function assertInit()
	assert(initialized, "[CharacterService] Must call Init() before use.")
end

--- Applies current stats (MaxHealth etc.) to a live character model.
local function applyStatsToCharacter(player: Player, character: Model)
	if not playerDataService or not statsService then return end
	local data = playerDataService.GetData(player)
	if not data then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local stats = data.Stats or {}
	local maxHp  = tonumber(stats.MaxHealth) or tonumber(stats.HP) or 100
	humanoid.MaxHealth = maxHp
	humanoid.Health    = math.min(data.CurrentHealth or maxHp, maxHp)
end

--- Builds the full initial data payload sent to the client via SendInitialData.
--- FIXED: now includes magicTier and tombData so TombManagementUI receives
--- correct values on join rather than stale defaults.
local function buildInitialPayload(player: Player): { [string]: any }
	local data = playerDataService.GetData(player)
	if not data then
		return {
			level     = 1,
			gold      = 0,
			className = "",
			role      = "",
			stats     = {},
			magicTier = 1,
			tombData  = nil,
		}
	end

	-- Safely read tombData — may be nil for legacy / new characters.
	local rawTomb = data.TombData
	local tombPayload: { [string]: any }? = nil
	if type(rawTomb) == "table" then
		tombPayload = {
			Tier          = rawTomb.Tier          or 1,
			Guardians     = rawTomb.Guardians     or {},
			UnlockedRooms = rawTomb.UnlockedRooms or {},
			UpgradeLog    = rawTomb.UpgradeLog    or {},
		}
	end

	return {
		level        = data.Level            or 1,
		gold         = data.Gold             or 0,
		exp          = data.Exp              or 0,
		className    = data.SelectedClass    or "",
		role         = data.SelectedRole     or "",
		stats        = data.Stats            or {},
		health       = data.CurrentHealth    or 100,
		resource     = data.CurrentResource  or 100,
		resourceType = data.ResourceType     or "Mana",
		-- Phase 7: required by TombManagementUI.SetPlayerStats()
		magicTier    = data.MagicTier        or 1,
		tombData     = tombPayload,
	}
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

function CharacterService.Init(pds: any, ss: any)
	if initialized then
		warn("[CharacterService] Init called more than once; ignoring.")
		return
	end
	assert(pds and pds.GetData,    "[CharacterService] PlayerDataService required.")
	assert(ss  and ss.Recalculate, "[CharacterService] StatsService required.")

	playerDataService = pds
	statsService      = ss
	initialized       = true

	print("[CharacterService] Initialized.")
end

--- Wire up CharacterAdded so stats apply whenever the character respawns.
function CharacterService.WirePlayer(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		-- Wait a frame so the humanoid is fully parented.
		task.defer(function()
			if not playerDataService.IsLoaded(player) then return end
			applyStatsToCharacter(player, character)
		end)
	end)
end

--- Called after PlayerDataService has finished loading a player's data.
--- Sends the full initial payload to the client including magicTier + tombData.
function CharacterService.OnPlayerLoaded(player: Player)
	assertInit()

	local payload = buildInitialPayload(player)

	pcall(function()
		PlayerRemotes.GetEvent("SendInitialData"):FireClient(player, payload)
	end)

	-- Apply stats to any character already in-world (can happen on quick loads).
	local character = player.Character
	if character then
		applyStatsToCharacter(player, character)
	end
end

--- Re-sends the initial data payload after a class / role change so the client
--- immediately reflects the new selection without requiring a rejoin.
function CharacterService.RefreshClientData(player: Player)
	assertInit()
	if not playerDataService.IsLoaded(player) then return end

	local payload = buildInitialPayload(player)
	pcall(function()
		PlayerRemotes.GetEvent("SendInitialData"):FireClient(player, payload)
	end)
end

return CharacterService
