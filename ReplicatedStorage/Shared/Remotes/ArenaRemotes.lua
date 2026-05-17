--!strict
-- ArenaRemotes.lua  —  ReplicatedStorage/Shared/Remotes/ArenaRemotes.lua
-- Remote registry for the PvP arena system.

local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteRegistry = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("RemoteRegistry")
)

local NAMESPACE = "Arena"

local EVENT_NAMES: { [string]: string } = {
	-- C→S
	JoinArenaQueue   = "Arena_JoinQueue",      -- { bracketSize: number }
	LeaveArenaQueue  = "Arena_LeaveQueue",     -- (no payload)
	-- S→C
	QueueStatus      = "Arena_QueueStatus",    -- { inQueue, bracketSize, position, estimatedWait }
	MatchFound       = "Arena_MatchFound",     -- { matchId, mapName, teamColor, opponents }
	MatchStarted     = "Arena_MatchStarted",   -- { matchId, duration }
	MatchStateUpdate = "Arena_StateUpdate",    -- { event, data }
	MatchEnded       = "Arena_MatchEnded",     -- { result, ratingChange, newRating }
}

local FUNCTION_NAMES: { [string]: string } = {
	GetArenaProfile = "Arena_GetArenaProfile", -- → { rating, wins, losses, season }
	GetLeaderboard  = "Arena_GetLeaderboard",  -- → [{ name, rating }]
}

local ArenaRemotes         = {}
ArenaRemotes.Namespace     = NAMESPACE
ArenaRemotes.EventNames    = EVENT_NAMES
ArenaRemotes.EventKeys     = table.freeze(table.clone(EVENT_NAMES))
ArenaRemotes.FunctionNames = FUNCTION_NAMES
ArenaRemotes.FunctionKeys  = table.freeze(table.clone(FUNCTION_NAMES))

local IS_SERVER = RunService:IsServer()
local eventCache:    { [string]: RemoteEvent }    = {}
local functionCache: { [string]: RemoteFunction } = {}
local ensured = false

function ArenaRemotes.Ensure(): Folder
	assert(IS_SERVER, "[ArenaRemotes] Ensure() must only be called on the server.")
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

function ArenaRemotes.GetEvent(key: string): RemoteEvent
	local remoteName = EVENT_NAMES[key]
	assert(remoteName, string.format("[ArenaRemotes] Unknown event key '%s'.", tostring(key)))
	if eventCache[key] then return eventCache[key] end
	local remote = RemoteRegistry.WaitForEvent(NAMESPACE, remoteName)
	eventCache[key] = remote
	return remote
end

function ArenaRemotes.GetFunction(key: string): RemoteFunction
	local remoteName = FUNCTION_NAMES[key]
	assert(remoteName, string.format("[ArenaRemotes] Unknown function key '%s'.", tostring(key)))
	if functionCache[key] then return functionCache[key] end
	local remote = RemoteRegistry.WaitForFunction(NAMESPACE, remoteName)
	functionCache[key] = remote
	return remote
end

function ArenaRemotes.IsEnsured(): boolean
	return ensured
end

return ArenaRemotes
