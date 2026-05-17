--!strict
--------------------------------------------------------------------------------
-- GhostyRPG | RaidRemotes.lua
-- ReplicatedStorage/Shared/Remotes/RaidRemotes.lua
-- Phase 8: Remote events для рейд/босс системы.
--------------------------------------------------------------------------------

local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteRegistry = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Remotes")
		:WaitForChild("RemoteRegistry")
)

local NAMESPACE = "Raid"

local EVENT_NAMES: { [string]: string } = {
	-- Client → Server
	CreateRaid      = "Raid_CreateRaid",      -- { raidId, difficulty }
	StartRaid       = "Raid_StartRaid",        -- { raidRunId }
	LeaveRaid       = "Raid_LeaveRaid",        -- {}
	AttackBoss      = "Raid_AttackBoss",       -- { raidRunId, bossId, damage }
	RecordWipe      = "Raid_RecordWipe",       -- { raidRunId }
	-- Server → Client
	RaidCreated     = "Raid_RaidCreated",      -- { raidRunId, raidId, difficulty, memberCount }
	RaidStarted     = "Raid_RaidStarted",      -- { raidRunId, timerSecs }
	RaidCompleted   = "Raid_RaidCompleted",    -- { raidRunId, elapsed, wipes }
	RaidFailed      = "Raid_RaidFailed",       -- { raidRunId, reason, wipes }
	BossPhaseChanged = "Raid_BossPhaseChanged",-- { raidRunId, bossId, newPhase, phaseLabel, dialogue, mechanics }
	BossDied        = "Raid_BossDied",         -- { raidRunId, bossId }
	BossDialog      = "Raid_BossDialog",       -- { bossId, line }
	RaidError       = "Raid_RaidError",        -- { code, message }
}

local FUNCTION_NAMES: { [string]: string } = {
	GetRaidList     = "Raid_GetRaidList",      -- () → { RaidDef[] }
}

local RaidRemotes              = {}
RaidRemotes.Namespace          = NAMESPACE
RaidRemotes.EventNames         = EVENT_NAMES
RaidRemotes.FunctionNames      = FUNCTION_NAMES

local IS_SERVER                              = RunService:IsServer()
local eventCache: { [string]: RemoteEvent }    = {}
local funcCache: { [string]: RemoteFunction }  = {}
local ensured                                = false

function RaidRemotes.Ensure(): Folder
	assert(IS_SERVER, "[RaidRemotes] Ensure() must only be called on the server.")
	local folder = RemoteRegistry.EnsureFolder(NAMESPACE)
	for key, remoteName in pairs(EVENT_NAMES) do
		eventCache[key] = RemoteRegistry.EnsureEvent(NAMESPACE, remoteName)
	end
	for key, remoteName in pairs(FUNCTION_NAMES) do
		funcCache[key] = RemoteRegistry.EnsureFunction(NAMESPACE, remoteName)
	end
	ensured = true
	return folder
end

function RaidRemotes.GetEvent(key: string): RemoteEvent
	local remoteName = EVENT_NAMES[key]
	assert(remoteName, string.format("[RaidRemotes] Unknown event key '%s'.", tostring(key)))
	if eventCache[key] then return eventCache[key] end
	if IS_SERVER and not ensured then
		warn("[RaidRemotes] GetEvent() called on server before Ensure().")
	end
	local remote = RemoteRegistry.WaitForEvent(NAMESPACE, remoteName)
	eventCache[key] = remote
	return remote
end

function RaidRemotes.GetFunction(key: string): RemoteFunction
	local remoteName = FUNCTION_NAMES[key]
	assert(remoteName, string.format("[RaidRemotes] Unknown function key '%s'.", tostring(key)))
	if funcCache[key] then return funcCache[key] end
	local remote = RemoteRegistry.WaitForFunction(NAMESPACE, remoteName)
	funcCache[key] = remote
	return remote
end

function RaidRemotes.IsEnsured(): boolean
	return ensured
end

return RaidRemotes
