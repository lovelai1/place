--!strict
-- PartyRemotes.lua  —  ReplicatedStorage/Shared/Remotes/PartyRemotes.lua
-- Remote registry for the party system. Pattern mirrors ClassRemotes / InventoryRemotes.

local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteRegistry = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("RemoteRegistry")
)

local NAMESPACE = "Party"

local EVENT_NAMES: { [string]: string } = {
	-- C→S
	InvitePlayer   = "Party_InvitePlayer",    -- { targetName: string }
	AcceptInvite   = "Party_AcceptInvite",    -- { inviterId: number }
	DeclineInvite  = "Party_DeclineInvite",   -- { inviterId: number }
	KickMember     = "Party_KickMember",      -- { userId: number }
	LeaveParty     = "Party_LeaveParty",      -- (no payload)
	HPPulse        = "Party_HPPulse",         -- { hp: number, maxHp: number }
	-- S→C
	PartyUpdated   = "Party_Updated",         -- full snapshot: { members, leaderId }
	InviteReceived = "Party_InviteReceived",  -- { inviterName, inviterId, partyId }
	MemberHPSync   = "Party_MemberHPSync",    -- { userId, hp, maxHp }
}

local PartyRemotes      = {}
PartyRemotes.Namespace  = NAMESPACE
PartyRemotes.EventNames = EVENT_NAMES
PartyRemotes.EventKeys  = table.freeze(table.clone(EVENT_NAMES))

local IS_SERVER = RunService:IsServer()
local eventCache: { [string]: RemoteEvent } = {}
local ensured = false

function PartyRemotes.Ensure(): Folder
	assert(IS_SERVER, "[PartyRemotes] Ensure() must only be called on the server.")
	local folder = RemoteRegistry.EnsureFolder(NAMESPACE)
	for key, remoteName in pairs(EVENT_NAMES) do
		eventCache[key] = RemoteRegistry.EnsureEvent(NAMESPACE, remoteName)
	end
	ensured = true
	return folder
end

function PartyRemotes.GetEvent(key: string): RemoteEvent
	local remoteName = EVENT_NAMES[key]
	assert(remoteName, string.format("[PartyRemotes] Unknown event key '%s'.", tostring(key)))
	if eventCache[key] then return eventCache[key] end
	local remote = RemoteRegistry.WaitForEvent(NAMESPACE, remoteName)
	eventCache[key] = remote
	return remote
end

function PartyRemotes.IsEnsured(): boolean
	return ensured
end

return PartyRemotes
