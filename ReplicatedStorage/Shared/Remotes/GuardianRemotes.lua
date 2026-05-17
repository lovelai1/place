--!strict
--------------------------------------------------------------------------------
-- GhostyRPG | GuardianRemotes.lua
-- ReplicatedStorage/Shared/Remotes/GuardianRemotes.lua
-- Phase 7: Remote events for the Floor Guardian / Tomb World system.
--------------------------------------------------------------------------------

local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteRegistry = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Remotes")
		:WaitForChild("RemoteRegistry")
)

local NAMESPACE = "Guardian"

local EVENT_NAMES: { [string]: string } = {
	-- Client → Server
	HireGuardian         = "Guardian_HireGuardian",
	FireGuardian         = "Guardian_FireGuardian",
	EnterTomb            = "Guardian_EnterTomb",
	ExitTomb             = "Guardian_ExitTomb",
	InviteToTomb         = "Guardian_InviteToTomb",
	TombUpgrade          = "Guardian_TombUpgrade",
	-- Server → Client
	GuardianStatusUpdate = "Guardian_GuardianStatusUpdate",
	TombEntered          = "Guardian_TombEntered",
	TombRoomUnlocked     = "Guardian_TombRoomUnlocked",
	GuardianDialog       = "Guardian_GuardianDialog",
	TombUpgradeResult    = "Guardian_TombUpgradeResult",
	GuardianSlotSync     = "Guardian_GuardianSlotSync",
}

local GuardianRemotes              = {}
GuardianRemotes.Namespace          = NAMESPACE
GuardianRemotes.EventNames         = EVENT_NAMES

local IS_SERVER                              = RunService:IsServer()
local eventCache: { [string]: RemoteEvent } = {}
local ensured                                = false

function GuardianRemotes.Ensure(): Folder
	assert(IS_SERVER, "[GuardianRemotes] Ensure() must only be called on the server.")
	local folder = RemoteRegistry.EnsureFolder(NAMESPACE)
	for key, remoteName in pairs(EVENT_NAMES) do
		eventCache[key] = RemoteRegistry.EnsureEvent(NAMESPACE, remoteName)
	end
	ensured = true
	return folder
end

function GuardianRemotes.GetEvent(key: string): RemoteEvent
	local remoteName = EVENT_NAMES[key]
	assert(remoteName, string.format("[GuardianRemotes] Unknown event key '%s'.", tostring(key)))
	if eventCache[key] then return eventCache[key] end
	if IS_SERVER and not ensured then
		warn("[GuardianRemotes] GetEvent() called on server before Ensure().")
	end
	local remote = RemoteRegistry.WaitForEvent(NAMESPACE, remoteName)
	eventCache[key] = remote
	return remote
end

function GuardianRemotes.IsEnsured(): boolean
	return ensured
end

return GuardianRemotes
