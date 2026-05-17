--!strict
-- Server-authoritative inventory and equipment operations for GhostyRPG.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ItemConfig"))
local InventoryValidator = require(script.Parent.Parent:WaitForChild("Validators"):WaitForChild("InventoryValidator"))

local InventoryService = {}

local playerDataService: any = nil
local initialized = false

local function assertInitialized()
	assert(initialized and playerDataService, "InventoryService requires Init(playerDataService) before use.")
end

local function getData(player: Player): { [string]: any }?
	assertInitialized()
	return playerDataService.GetData(player)
end

local function scheduleSave(player: Player)
	assertInitialized()
	playerDataService.ScheduleSave(player)
end

local function ensureInventory(data: { [string]: any }): { [string]: any }
	if not data.Inventory then
		data.Inventory = {}
	end
	return data.Inventory
end

local function ensureEquipment(data: { [string]: any }): { [string]: any }
	if not data.Equipment then
		data.Equipment = {}
	end
	return data.Equipment
end

local function rawAddToInventory(inventory: { [string]: any }, itemId: string, amount: number, metadata: any?)
	local entry = inventory[itemId]
	if entry then
		entry.amount = (entry.amount or 0) + amount
	else
		inventory[itemId] = { itemId = itemId, amount = amount, metadata = metadata }
	end
end

function InventoryService.Init(newPlayerDataService: any)
	if initialized then
		warn("[InventoryService] Init called more than once; ignoring duplicate call.")
		return
	end

	assert(newPlayerDataService, "InventoryService.Init requires PlayerDataService.")
	assert(newPlayerDataService.GetData, "InventoryService.Init requires PlayerDataService.GetData.")
	assert(newPlayerDataService.ScheduleSave, "InventoryService.Init requires PlayerDataService.ScheduleSave.")

	playerDataService = newPlayerDataService
	initialized = true
	print("[InventoryService] Initialized.")
end

function InventoryService.AddItem(player: Player, itemId: string, amount: number?, metadata: any?): boolean
	local itemAmount = amount or 1
	local data = getData(player)
	if not data then
		warn(string.format("[InventoryService] AddItem failed for %s: data unavailable.", player.Name))
		return false
	end

	local validation = InventoryValidator.CanAddItem(data, itemId, itemAmount)
	if not validation.success then
		warn(string.format("[InventoryService] AddItem rejected for %s: %s", player.Name, tostring(validation.reason)))
		return false
	end

	rawAddToInventory(ensureInventory(data), itemId, itemAmount, metadata)
	scheduleSave(player)
	return true
end

function InventoryService.RemoveItem(player: Player, itemId: string, amount: number?): boolean
	local itemAmount = amount or 1
	local data = getData(player)
	if not data then
		warn(string.format("[InventoryService] RemoveItem failed for %s: data unavailable.", player.Name))
		return false
	end

	local validation = InventoryValidator.CanRemoveItem(data, itemId, itemAmount)
	if not validation.success then
		warn(string.format("[InventoryService] RemoveItem rejected for %s: %s", player.Name, tostring(validation.reason)))
		return false
	end

	local inventory = ensureInventory(data)
	inventory[itemId].amount -= itemAmount
	if inventory[itemId].amount <= 0 then
		inventory[itemId] = nil
	end

	scheduleSave(player)
	return true
end

function InventoryService.HasItem(player: Player, itemId: string, amount: number?): boolean
	local itemAmount = amount or 1
	local data = getData(player)
	if not data then
		return false
	end

	local entry = (data.Inventory or {})[itemId]
	return entry ~= nil and (entry.amount or 0) >= itemAmount
end

function InventoryService.GetInventory(player: Player): { [string]: any }
	local data = getData(player)
	if not data then
		return {}
	end
	return ensureInventory(data)
end

function InventoryService.GetEquipment(player: Player): { [string]: any }
	local data = getData(player)
	if not data then
		return {}
	end
	return ensureEquipment(data)
end

function InventoryService.EquipItem(player: Player, itemId: string): boolean
	local data = getData(player)
	if not data then
		warn(string.format("[InventoryService] EquipItem failed for %s: data unavailable.", player.Name))
		return false
	end

	local validation = InventoryValidator.CanEquipItem(data, itemId)
	if not validation.success then
		warn(string.format("[InventoryService] EquipItem rejected for %s: %s", player.Name, tostring(validation.reason)))
		return false
	end

	local slotName = ItemConfig.GetEquipmentSlot(itemId)
	if not slotName then
		return false
	end

	local inventory = ensureInventory(data)
	local equipment = ensureEquipment(data)
	local sourceEntry = inventory[itemId]
	local metadata = sourceEntry and sourceEntry.metadata or nil
	local displaced = equipment[slotName]

	if displaced then
		rawAddToInventory(inventory, displaced.itemId, 1, displaced.metadata)
	end

	inventory[itemId].amount -= 1
	if inventory[itemId].amount <= 0 then
		inventory[itemId] = nil
	end

	equipment[slotName] = { itemId = itemId, amount = 1, metadata = metadata }
	scheduleSave(player)
	return true
end

function InventoryService.UnequipSlot(player: Player, slotName: string): boolean
	local data = getData(player)
	if not data then
		warn(string.format("[InventoryService] UnequipSlot failed for %s: data unavailable.", player.Name))
		return false
	end

	local validation = InventoryValidator.CanUnequipSlot(data, slotName)
	if not validation.success then
		warn(string.format("[InventoryService] UnequipSlot rejected for %s: %s", player.Name, tostring(validation.reason)))
		return false
	end

	local inventory = ensureInventory(data)
	local equipment = ensureEquipment(data)
	local equipped = equipment[slotName]
	rawAddToInventory(inventory, equipped.itemId, 1, equipped.metadata)
	equipment[slotName] = nil

	scheduleSave(player)
	return true
end

-- ── Phase 5: Methods required by TombBaseService ──────────────────────────

--- Returns total count of itemId across all stacks in the player's inventory.
function InventoryService.GetItemCount(player: Player, itemId: string): number
	local data = getData(player)
	if not data or not data.Inventory then return 0 end
	local entry = data.Inventory[itemId]
	return (entry and entry.amount) or 0
end

--- Removes up to `amount` of itemId. Returns the actual amount removed.
function InventoryService.RemoveItem(player: Player, itemId: string, amount: number): number
	local data = getData(player)
	if not data or not data.Inventory then return 0 end
	local entry = data.Inventory[itemId]
	if not entry then return 0 end
	local removed = math.min(entry.amount, amount)
	entry.amount = entry.amount - removed
	if entry.amount <= 0 then
		data.Inventory[itemId] = nil
	end
	scheduleSave(player)
	return removed
end

return InventoryService
