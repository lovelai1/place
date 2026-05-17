--!strict
-- Central creation/wait registry for GhostyRPG remotes.
-- Server code creates through Ensure*; clients wait through WaitFor* and never create instances.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WAIT_TIMEOUT_SECONDS = 10
local ROOT_PATH = { "Shared", "Remotes" }
local IS_SERVER = RunService:IsServer()

local RemoteRegistry = {}

local function assertNonEmpty(value: any, label: string)
	assert(type(value) == "string" and value ~= "", string.format("[RemoteRegistry] %s must be a non-empty string.", label))
end

local function resolveFolderChain(parent: Instance, names: { string }, canCreate: boolean): Folder
	local current = parent
	for _, name in ipairs(names) do
		local child = current:FindFirstChild(name)
		if child then
			assert(child:IsA("Folder"), string.format("[RemoteRegistry] Expected Folder '%s', got %s.", child:GetFullName(), child.ClassName))
			current = child
		elseif canCreate then
			local folder = Instance.new("Folder")
			folder.Name = name
			folder.Parent = current
			current = folder
		else
			local found = current:WaitForChild(name, WAIT_TIMEOUT_SECONDS)
			assert(found and found:IsA("Folder"), string.format("[RemoteRegistry] Timed out waiting for Folder '%s' under '%s'.", name, current:GetFullName()))
			current = found
		end
	end
	return current :: Folder
end

local function getRoot(canCreate: boolean): Folder
	return resolveFolderChain(ReplicatedStorage, ROOT_PATH, canCreate)
end

local function ensureRemote(namespace: string, key: string, className: string): Instance
	assert(IS_SERVER, string.format("[RemoteRegistry] Ensure%s() must only be called on the server.", className == "RemoteEvent" and "Event" or "Function"))
	assertNonEmpty(namespace, "namespace")
	assertNonEmpty(key, "key")

	local folder = RemoteRegistry.EnsureFolder(namespace)
	local remote = folder:FindFirstChild(key)
	if not remote then
		remote = Instance.new(className)
		remote.Name = key
		remote.Parent = folder
	end
	assert(remote.ClassName == className, string.format("[RemoteRegistry] '%s/%s' exists but is %s, not %s.", namespace, key, remote.ClassName, className))
	return remote
end

local function waitForRemote(namespace: string, key: string, className: string): Instance
	assertNonEmpty(namespace, "namespace")
	assertNonEmpty(key, "key")

	local root = getRoot(false)
	local folder = root:WaitForChild(namespace, WAIT_TIMEOUT_SECONDS)
	assert(folder and folder:IsA("Folder"), string.format("[RemoteRegistry] Timed out waiting for namespace '%s'.", namespace))
	local remote = folder:WaitForChild(key, WAIT_TIMEOUT_SECONDS)
	assert(remote and remote.ClassName == className, string.format("[RemoteRegistry] Expected %s '%s/%s'.", className, namespace, key))
	return remote
end

function RemoteRegistry.EnsureFolder(namespace: string): Folder
	assert(IS_SERVER, "[RemoteRegistry] EnsureFolder() must only be called on the server.")
	assertNonEmpty(namespace, "namespace")

	local root = getRoot(true)
	local folder = root:FindFirstChild(namespace)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = namespace
		folder.Parent = root
	end
	assert(folder:IsA("Folder"), string.format("[RemoteRegistry] '%s' exists but is %s, not Folder.", namespace, folder.ClassName))
	return folder :: Folder
end

function RemoteRegistry.EnsureEvent(namespace: string, key: string): RemoteEvent
	return ensureRemote(namespace, key, "RemoteEvent") :: RemoteEvent
end

function RemoteRegistry.EnsureFunction(namespace: string, key: string): RemoteFunction
	return ensureRemote(namespace, key, "RemoteFunction") :: RemoteFunction
end

function RemoteRegistry.WaitForEvent(namespace: string, key: string): RemoteEvent
	return waitForRemote(namespace, key, "RemoteEvent") :: RemoteEvent
end

function RemoteRegistry.WaitForFunction(namespace: string, key: string): RemoteFunction
	return waitForRemote(namespace, key, "RemoteFunction") :: RemoteFunction
end

function RemoteRegistry.Exists(namespace: string, key: string): boolean
	if type(namespace) ~= "string" or namespace == "" or type(key) ~= "string" or key == "" then
		return false
	end
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	if not shared then
		return false
	end
	local remotes = shared:FindFirstChild("Remotes")
	if not remotes then
		return false
	end
	local folder = remotes:FindFirstChild(namespace)
	if not folder then
		return false
	end
	return folder:FindFirstChild(key) ~= nil
end

return RemoteRegistry
