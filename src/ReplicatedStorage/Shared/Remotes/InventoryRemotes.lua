--!strict
-- Inventory-scoped remote registry. Only read RemoteFunctions are exposed here;
-- item grants/removals/equipment mutation stay behind validated server services.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteRegistry = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("RemoteRegistry"))

local NAMESPACE = "Inventory"

local FUNCTION_NAMES: { [string]: string } = {
	GetInventory = "Inventory_GetInventory",
	GetEquipment = "Inventory_GetEquipment",
}

local InventoryRemotes = {}
InventoryRemotes.Namespace = NAMESPACE
InventoryRemotes.FunctionNames = FUNCTION_NAMES
InventoryRemotes.FunctionKeys = table.freeze(table.clone(FUNCTION_NAMES))

local IS_SERVER = RunService:IsServer()
local functionCache: { [string]: RemoteFunction } = {}
local ensured = false

local function getRemoteName(key: string): string
	local remoteName = FUNCTION_NAMES[key]
	assert(remoteName, string.format("[InventoryRemotes] Unknown function key '%s'.", tostring(key)))
	return remoteName
end

function InventoryRemotes.Ensure(): Folder
	assert(IS_SERVER, "[InventoryRemotes] Ensure() must only be called on the server.")
	local folder = RemoteRegistry.EnsureFolder(NAMESPACE)
	for key, remoteName in pairs(FUNCTION_NAMES) do
		functionCache[key] = RemoteRegistry.EnsureFunction(NAMESPACE, remoteName)
	end
	ensured = true
	return folder
end

function InventoryRemotes.GetFunction(key: string): RemoteFunction
	local remoteName = getRemoteName(key)
	if functionCache[key] then
		return functionCache[key]
	end
	if IS_SERVER and not ensured then
		warn("[InventoryRemotes] GetFunction() called on server before Ensure(); waiting for existing remote.")
	end
	local remote = RemoteRegistry.WaitForFunction(NAMESPACE, remoteName)
	functionCache[key] = remote
	return remote
end

function InventoryRemotes.IsEnsured(): boolean
	return ensured
end

return InventoryRemotes
