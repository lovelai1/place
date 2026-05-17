--!strict
-- Class-scoped remote registry.
-- Phase 8 addition: Evolution events (GetEvolutionOptions, RequestEvolve, EvolutionResult).

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteRegistry = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("RemoteRegistry"))

local NAMESPACE = "Class"

local EVENT_NAMES: { [string]: string } = {
	-- Class / Role
	SelectClass   = "Class_SelectClass",
	SelectRole    = "Class_SelectRole",
	ClassSelected = "Class_ClassSelected",
	RoleSelected  = "Class_RoleSelected",
	-- Phase 8: Evolution
	RequestEvolve  = "Class_RequestEvolve",   -- Client → Server  { targetClass: string }
	EvolutionResult = "Class_EvolutionResult", -- Server → Client  { ok, targetClass?, reason? }
}

local FUNCTION_NAMES: { [string]: string } = {
	-- Phase 8: fetch available evolution options with requirement details
	GetEvolutionOptions = "Class_GetEvolutionOptions",  -- () → EvolutionOption[]
}

local ClassRemotes = {}
ClassRemotes.Namespace  = NAMESPACE
ClassRemotes.EventNames = EVENT_NAMES
ClassRemotes.EventKeys  = table.freeze(table.clone(EVENT_NAMES))

local IS_SERVER = RunService:IsServer()
local eventCache: { [string]: RemoteEvent }    = {}
local funcCache: { [string]: RemoteFunction }  = {}
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
	for key, remoteName in pairs(FUNCTION_NAMES) do
		funcCache[key] = RemoteRegistry.EnsureFunction(NAMESPACE, remoteName)
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

function ClassRemotes.GetFunction(key: string): RemoteFunction
	local remoteName = FUNCTION_NAMES[key]
	assert(remoteName, string.format("[ClassRemotes] Unknown function key '%s'.", tostring(key)))
	if funcCache[key] then return funcCache[key] end
	local remote = RemoteRegistry.WaitForFunction(NAMESPACE, remoteName)
	funcCache[key] = remote
	return remote
end

function ClassRemotes.IsEnsured(): boolean
	return ensured
end

return ClassRemotes
