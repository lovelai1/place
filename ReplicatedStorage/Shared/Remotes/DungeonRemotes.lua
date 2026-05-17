--!strict
-- Queue, dungeon, and combat remote contract for the GhostyRPG MVP.
-- Names live here so server handlers and client UI do not hard-code strings.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteRegistry = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("RemoteRegistry"))

local NAMESPACE = "Dungeon"

local EVENT_NAMES: { [string]: string } = {
	JoinQueue = "Dungeon_JoinQueue",
	LeaveQueue = "Dungeon_LeaveQueue",
	ReadyCheck = "Dungeon_ReadyCheck",
	UseAbility = "Dungeon_UseAbility",
	LootAcknowledge = "Dungeon_LootAcknowledge",

	QueueUpdated = "Dungeon_QueueUpdated",
	PartyFormed = "Dungeon_PartyFormed",
	ReadyUpdated = "Dungeon_ReadyUpdated",
	DungeonStateUpdate = "Dungeon_DungeonStateUpdate",
	CombatResult = "Dungeon_CombatResult",
	AbilityRejected = "Dungeon_AbilityRejected",
	DungeonCleared = "Dungeon_DungeonCleared",
	DungeonFailed = "Dungeon_DungeonFailed",
	RewardGranted = "Dungeon_RewardGranted",
}

local FUNCTION_NAMES: { [string]: string } = {
	GetDungeonList = "Dungeon_GetDungeonList",
	GetPartyStatus = "Dungeon_GetPartyStatus",
}

local DungeonRemotes = {}
DungeonRemotes.Namespace = NAMESPACE
DungeonRemotes.EventNames = EVENT_NAMES
DungeonRemotes.FunctionNames = FUNCTION_NAMES
DungeonRemotes.EventKeys = table.freeze(table.clone(EVENT_NAMES))
DungeonRemotes.FunctionKeys = table.freeze(table.clone(FUNCTION_NAMES))

local IS_SERVER = RunService:IsServer()
local eventCache: { [string]: RemoteEvent } = {}
local functionCache: { [string]: RemoteFunction } = {}
local ensured = false

local function getRemoteName(key: string, names: { [string]: string }, label: string): string
	local remoteName = names[key]
	assert(remoteName, string.format("[DungeonRemotes] Unknown %s key '%s'.", label, tostring(key)))
	return remoteName
end

function DungeonRemotes.Ensure(): Folder
	assert(IS_SERVER, "[DungeonRemotes] Ensure() must only be called on the server.")
	local folder = RemoteRegistry.EnsureFolder(NAMESPACE)
	for key, remoteName in pairs(EVENT_NAMES) do
		eventCache[key] = RemoteRegistry.EnsureEvent(NAMESPACE, remoteName)
	end
	for key, remoteName in pairs(FUNCTION_NAMES) do
		functionCache[key] = RemoteRegistry.EnsureFunction(NAMESPACE, remoteName)
	end
	ensured = true
	return folder
end

function DungeonRemotes.GetEvent(key: string): RemoteEvent
	local remoteName = getRemoteName(key, EVENT_NAMES, "event")
	if eventCache[key] then
		return eventCache[key]
	end
	if IS_SERVER and not ensured then
		warn("[DungeonRemotes] GetEvent() called on server before Ensure(); waiting for existing remote.")
	end
	local remote = RemoteRegistry.WaitForEvent(NAMESPACE, remoteName)
	eventCache[key] = remote
	return remote
end

function DungeonRemotes.GetFunction(key: string): RemoteFunction
	local remoteName = getRemoteName(key, FUNCTION_NAMES, "function")
	if functionCache[key] then
		return functionCache[key]
	end
	if IS_SERVER and not ensured then
		warn("[DungeonRemotes] GetFunction() called on server before Ensure(); waiting for existing remote.")
	end
	local remote = RemoteRegistry.WaitForFunction(NAMESPACE, remoteName)
	functionCache[key] = remote
	return remote
end

function DungeonRemotes.IsEnsured(): boolean
	return ensured
end

return DungeonRemotes