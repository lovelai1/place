--!strict
-- Quest-scoped remote registry. GetEvent/GetFunction keep logical-key compatibility.
-- Server Ensure creates instances; client Get* waits through RemoteRegistry and never creates.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteRegistry = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("RemoteRegistry"))

local NAMESPACE = "Quest"

local EVENT_NAMES: { [string]: string } = {
	AcceptQuest = "Quest_AcceptQuest",
	AbandonQuest = "Quest_AbandonQuest",
	TurnInQuest = "Quest_TurnInQuest",
	QuestAccepted = "Quest_QuestAccepted",
	QuestAbandoned = "Quest_QuestAbandoned",
	QuestProgressUpdated = "Quest_QuestProgressUpdated",
	QuestReadyToTurnIn = "Quest_QuestReadyToTurnIn",
	QuestTurnedIn = "Quest_QuestTurnedIn",
	QuestFailed = "Quest_QuestFailed",
}

local FUNCTION_NAMES: { [string]: string } = {
	GetAvailableQuests = "Quest_GetAvailableQuests",
	GetActiveQuests = "Quest_GetActiveQuests",
}

local QuestRemotes = {}
QuestRemotes.Namespace = NAMESPACE
QuestRemotes.EventNames = EVENT_NAMES
QuestRemotes.FunctionNames = FUNCTION_NAMES
QuestRemotes.EventKeys = table.freeze(table.clone(EVENT_NAMES))
QuestRemotes.FunctionKeys = table.freeze(table.clone(FUNCTION_NAMES))

local IS_SERVER = RunService:IsServer()
local eventCache: { [string]: RemoteEvent } = {}
local functionCache: { [string]: RemoteFunction } = {}
local ensured = false

local function getRemoteName(key: string, names: { [string]: string }, label: string): string
	local remoteName = names[key]
	assert(remoteName, string.format("[QuestRemotes] Unknown %s key '%s'.", label, tostring(key)))
	return remoteName
end

function QuestRemotes.Ensure(): Folder
	assert(IS_SERVER, "[QuestRemotes] Ensure() must only be called on the server.")
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

function QuestRemotes.GetEvent(key: string): RemoteEvent
	local remoteName = getRemoteName(key, EVENT_NAMES, "event")
	if eventCache[key] then
		return eventCache[key]
	end
	if IS_SERVER and not ensured then
		warn("[QuestRemotes] GetEvent() called on server before Ensure(); waiting for existing remote.")
	end
	local remote = RemoteRegistry.WaitForEvent(NAMESPACE, remoteName)
	eventCache[key] = remote
	return remote
end

function QuestRemotes.GetFunction(key: string): RemoteFunction
	local remoteName = getRemoteName(key, FUNCTION_NAMES, "function")
	if functionCache[key] then
		return functionCache[key]
	end
	if IS_SERVER and not ensured then
		warn("[QuestRemotes] GetFunction() called on server before Ensure(); waiting for existing remote.")
	end
	local remote = RemoteRegistry.WaitForFunction(NAMESPACE, remoteName)
	functionCache[key] = remote
	return remote
end

function QuestRemotes.IsEnsured(): boolean
	return ensured
end

return QuestRemotes
