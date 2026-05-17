--!strict
-- Player-scoped remote registry for GhostyRPG.
-- Server creates via Ensure(); client waits via GetEvent().
-- Handles initial data sync, class-select prompt, stat/health updates, mob feedback.

local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteRegistry = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("RemoteRegistry")
)

local NAMESPACE = "Player"

-- Keys are the short names callers use; values are the actual RemoteEvent names in the hierarchy.
local EVENT_NAMES: { [string]: string } = {
	SendInitialData  = "Player_SendInitialData",  -- S→C: full payload on join / class select
	NeedsClassSelect = "Player_NeedsClassSelect", -- S→C: show class-selection screen
	SyncStats        = "Player_SyncStats",         -- S→C: stats changed (equip, level-up …)
	SyncHealth       = "Player_SyncHealth",        -- S→C: HP/resource tick
	MobDamaged       = "Player_MobDamaged",        -- S→C: player took damage (floating numbers)
	MobDied          = "Player_MobDied",           -- S→C: a nearby mob died
	ExpGained        = "Player_ExpGained",         -- S→C: exp + gold reward after kill
	LevelUp          = "Player_LevelUp",           -- S→C: level-up notification
}

local PlayerRemotes         = {}
PlayerRemotes.Namespace     = NAMESPACE
PlayerRemotes.EventNames    = EVENT_NAMES

local IS_SERVER                        = RunService:IsServer()
local eventCache: { [string]: RemoteEvent } = {}
local ensured                          = false

-- Called once from Boot on the server — creates all RemoteEvents.
function PlayerRemotes.Ensure(): Folder
	assert(IS_SERVER, "[PlayerRemotes] Ensure() must only be called on the server.")
	local folder = RemoteRegistry.EnsureFolder(NAMESPACE)
	for key, remoteName in pairs(EVENT_NAMES) do
		eventCache[key] = RemoteRegistry.EnsureEvent(NAMESPACE, remoteName)
	end
	ensured = true
	return folder
end

-- Works on both server and client. Server should call Ensure() first.
function PlayerRemotes.GetEvent(key: string): RemoteEvent
	local remoteName = EVENT_NAMES[key]
	assert(remoteName, string.format("[PlayerRemotes] Unknown event key '%s'.", tostring(key)))

	if eventCache[key] then
		return eventCache[key]
	end

	if IS_SERVER and not ensured then
		warn("[PlayerRemotes] GetEvent() called on server before Ensure().")
	end

	local remote = RemoteRegistry.WaitForEvent(NAMESPACE, remoteName)
	eventCache[key] = remote
	return remote
end

function PlayerRemotes.IsEnsured(): boolean
	return ensured
end

return PlayerRemotes
