--!strict
-- Server-only smoke test for the shared remote registry modules.
-- Creates declared remotes through Ensure(), verifies type/name, and never fires/invokes them.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

assert(RunService:IsServer(), "[RemotesSmokeTest] Must run on the server.")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = Shared:WaitForChild("Remotes")

local passed = 0
local failed = 0
local failures: { string } = {}

local function record(label: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		print(string.format("[RemotesSmokeTest] [PASS] %s", label))
	else
		failed += 1
		local message = string.format("%s%s", label, if detail then ": " .. detail else "")
		table.insert(failures, message)
		warn(string.format("[RemotesSmokeTest] [FAIL] %s", message))
	end
end

local remoteRegistry = require(Remotes:WaitForChild("RemoteRegistry") :: ModuleScript)
local questRemotes = require(Remotes:WaitForChild("QuestRemotes") :: ModuleScript)
local classRemotes = require(Remotes:WaitForChild("ClassRemotes") :: ModuleScript)
local inventoryRemotes = require(Remotes:WaitForChild("InventoryRemotes") :: ModuleScript)

record("RemoteRegistry loads", type(remoteRegistry) == "table")
record("QuestRemotes loads", type(questRemotes) == "table")
record("ClassRemotes loads", type(classRemotes) == "table")
record("InventoryRemotes loads", type(inventoryRemotes) == "table")

local function ensureModule(label: string, module: any)
	local ok, err = pcall(function()
		module.Ensure()
	end)
	record(label .. ".Ensure()", ok, tostring(err))
	local okAgain, errAgain = pcall(function()
		module.Ensure()
	end)
	record(label .. ".Ensure() idempotent", okAgain, tostring(errAgain))
end

ensureModule("QuestRemotes", questRemotes)
ensureModule("ClassRemotes", classRemotes)
ensureModule("InventoryRemotes", inventoryRemotes)

local function findRemote(namespace: string, remoteName: string): Instance?
	local folder = Remotes:FindFirstChild(namespace)
	if not folder then
		return nil
	end
	return folder:FindFirstChild(remoteName)
end

local function verifyRemoteMap(namespace: string, names: { [string]: string }, expectedClassName: string)
	for key, remoteName in pairs(names) do
		local inst = findRemote(namespace, remoteName)
		record(string.format("%s.%s exists", namespace, key), inst ~= nil, remoteName)
		if inst then
			record(string.format("%s.%s is %s", namespace, key, expectedClassName), inst.ClassName == expectedClassName, inst.ClassName)
		end
		local existsOk = remoteRegistry.Exists(namespace, remoteName)
		record(string.format("RemoteRegistry.Exists(%s/%s)", namespace, remoteName), existsOk)
	end
end

verifyRemoteMap(questRemotes.Namespace, questRemotes.EventNames, "RemoteEvent")
verifyRemoteMap(questRemotes.Namespace, questRemotes.FunctionNames, "RemoteFunction")
verifyRemoteMap(classRemotes.Namespace, classRemotes.EventNames, "RemoteEvent")
verifyRemoteMap(inventoryRemotes.Namespace, inventoryRemotes.FunctionNames, "RemoteFunction")

local blankOk = pcall(function()
	remoteRegistry.EnsureEvent("", "BlankNamespaceShouldFail")
end)
record("RemoteRegistry rejects blank namespace", not blankOk)

local missingExistsOk, missingExists = pcall(function()
	return remoteRegistry.Exists("MissingNamespace", "MissingRemote")
end)
record("RemoteRegistry.Exists missing remote is safe", missingExistsOk and missingExists == false)

if failed == 0 then
	print(string.format("[RemotesSmokeTest] PASSED %d checks, 0 failures", passed))
else
	warn(string.format("[RemotesSmokeTest] FAILED %d passed, %d failed", passed, failed))
	for index, failure in ipairs(failures) do
		warn(string.format("[RemotesSmokeTest] [%d] %s", index, failure))
	end
end
