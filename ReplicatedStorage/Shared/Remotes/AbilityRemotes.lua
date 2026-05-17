--!strict
-- GhostyRPG | AbilityRemotes.lua
-- ReplicatedStorage/Shared/Remotes/AbilityRemotes.lua

local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteRegistry = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Remotes")
		:WaitForChild("RemoteRegistry")
)

local NAMESPACE = "Ability"

local EVENT_NAMES: { [string]: string } = {
	CastAbility    = "Ability_CastAbility",
	AbilityCast    = "Ability_AbilityCast",
	CooldownSync   = "Ability_CooldownSync",
	AbilityGranted = "Ability_AbilityGranted",
}

local AbilityRemotes = {}
AbilityRemotes.Namespace   = NAMESPACE
AbilityRemotes.EventNames  = EVENT_NAMES

local IS_SERVER = RunService:IsServer()
local eventCache: { [string]: RemoteEvent } = {}
local ensured = false

function AbilityRemotes.Ensure(): Folder
	assert(IS_SERVER, "[AbilityRemotes] Ensure() must only be called on the server.")
	local folder = RemoteRegistry.EnsureFolder(NAMESPACE)
	for key, remoteName in pairs(EVENT_NAMES) do
		eventCache[key] = RemoteRegistry.EnsureEvent(NAMESPACE, remoteName)
	end
	ensured = true
	return folder
end

function AbilityRemotes.GetEvent(key: string): RemoteEvent
	local remoteName = EVENT_NAMES[key]
	assert(remoteName, string.format("[AbilityRemotes] Unknown event key '%s'.", tostring(key)))

	if eventCache[key] then return eventCache[key] end

	if IS_SERVER and not ensured then
		warn("[AbilityRemotes] GetEvent() called on server before Ensure().")
	end

	local remote = RemoteRegistry.WaitForEvent(NAMESPACE, remoteName)
	eventCache[key] = remote
	return remote
end

function AbilityRemotes.IsEnsured(): boolean
	return ensured
end

return AbilityRemotes
