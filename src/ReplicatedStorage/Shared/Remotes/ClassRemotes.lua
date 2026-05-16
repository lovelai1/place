--!strict
-- Class-scoped remote registry. It declares request/confirmation events only;
-- class and role mutation remains server-authoritative through ClassService.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteRegistry = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("RemoteRegistry"))

local NAMESPACE = "Class"

local EVENT_NAMES: { [string]: string } = {
	SelectClass = "Class_SelectClass",
	SelectRole = "Class_SelectRole",
	ClassSelected = "Class_ClassSelected",
	RoleSelected = "Class_RoleSelected",
}

local ClassRemotes = {}
ClassRemotes.Namespace = NAMESPACE
ClassRemotes.EventNames = EVENT_NAMES
ClassRemotes.EventKeys = table.freeze(table.clone(EVENT_NAMES))

local IS_SERVER = RunService:IsServer()
local eventCache: { [string]: RemoteEvent } = {}
local ensured = false

local function getRemoteName(key: string): string
	local remoteName = EVENT_NAMES[key]
	assert(remoteName, string.format("[ClassRemotes] Unknown event key '%s'.", tostring(key)))
	return remoteName
end

function ClassRemotes.Ensure(): Folder
	assert(IS_SERVER, "[ClassRemotes] Ensure() must only be called on the server.")
	local folder = RemoteRegistry.EnsureFolder(NAMESPACE)
	for key, remoteName in pairs(EVENT_NAMES) do
		eventCache[key] = RemoteRegistry.EnsureEvent(NAMESPACE, remoteName)
	end
	ensured = true
	return folder
end

function ClassRemotes.GetEvent(key: string): RemoteEvent
	local remoteName = getRemoteName(key)
	if eventCache[key] then
		return eventCache[key]
	end
	if IS_SERVER and not ensured then
		warn("[ClassRemotes] GetEvent() called on server before Ensure(); waiting for existing remote.")
	end
	local remote = RemoteRegistry.WaitForEvent(NAMESPACE, remoteName)
	eventCache[key] = remote
	return remote
end

function ClassRemotes.IsEnsured(): boolean
	return ensured
end

return ClassRemotes
