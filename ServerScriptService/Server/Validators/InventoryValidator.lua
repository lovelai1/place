--!strict
-- Pure server-side validation for GhostyRPG inventory and equipment operations.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ItemConfig"))

local InventoryValidator = {}

local MAX_INVENTORY_SLOTS = 100

export type ValidationResult = {
	success: boolean,
	reason: string?,
}

local function ok(): ValidationResult
	return { success = true, reason = nil }
end

local function fail(reason: string): ValidationResult
	return { success = false, reason = reason }
end

local function isPositiveInteger(value: any): boolean
	return type(value) == "number" and value >= 1 and value == math.floor(value)
end

local function countSlots(inventory: { [string]: any }): number
	local count = 0
	for _ in pairs(inventory) do
		count += 1
	end
	return count
end

function InventoryValidator.CanAddItem(data: { [string]: any }, itemId: string, amount: number): ValidationResult
	if typeof(itemId) ~= "string" or itemId == "" then
		return fail("Invalid item id.")
	end
	if not ItemConfig.IsValidItem(itemId) then
		return fail("Unknown item: " .. itemId)
	end
	if not isPositiveInteger(amount) then
		return fail("Amount must be a positive integer.")
	end

	local inventory = data.Inventory or {}
	local existing = inventory[itemId]
	local currentAmount = if existing then (existing.amount or 0) else 0

	if ItemConfig.IsStackable(itemId) then
		local maxStack = ItemConfig.GetMaxStack(itemId)
		if currentAmount + amount > maxStack then
			return fail(string.format("Stack limit exceeded for %s (%d/%d).", itemId, currentAmount + amount, maxStack))
		end
	else
		if amount ~= 1 then
			return fail("Non-stackable items must be added one at a time.")
		end
		if currentAmount >= 1 then
			return fail("Non-stackable item is already present: " .. itemId)
		end
	end

	if not existing and countSlots(inventory) >= MAX_INVENTORY_SLOTS then
		return fail(string.format("Inventory is full (%d slots).", MAX_INVENTORY_SLOTS))
	end

	return ok()
end

function InventoryValidator.CanRemoveItem(data: { [string]: any }, itemId: string, amount: number): ValidationResult
	if typeof(itemId) ~= "string" or itemId == "" then
		return fail("Invalid item id.")
	end
	if not ItemConfig.IsValidItem(itemId) then
		return fail("Unknown item: " .. itemId)
	end
	if not isPositiveInteger(amount) then
		return fail("Amount must be a positive integer.")
	end

	local inventory = data.Inventory or {}
	local existing = inventory[itemId]
	local currentAmount = if existing then (existing.amount or 0) else 0
	if currentAmount < amount then
		return fail(string.format("Not enough %s: have %d, need %d.", itemId, currentAmount, amount))
	end

	return ok()
end

function InventoryValidator.CanEquipItem(data: { [string]: any }, itemId: string): ValidationResult
	if typeof(itemId) ~= "string" or itemId == "" then
		return fail("Invalid item id.")
	end
	if not ItemConfig.IsValidItem(itemId) then
		return fail("Unknown item: " .. itemId)
	end
	if not ItemConfig.CanEquip(itemId) then
		return fail("Item is not equippable: " .. itemId)
	end

	local inventory = data.Inventory or {}
	local existing = inventory[itemId]
	if not existing or (existing.amount or 0) < 1 then
		return fail("Item is not in inventory: " .. itemId)
	end

	local itemDef = ItemConfig.GetItem(itemId)
	local requiredLevel = if itemDef then (itemDef.requiredLevel or 1) else 1
	local playerLevel = data.Level or 1
	if playerLevel < requiredLevel then
		return fail(string.format("Level %d required to equip %s.", requiredLevel, itemId))
	end

	return ok()
end

function InventoryValidator.CanUnequipSlot(data: { [string]: any }, slotName: string): ValidationResult
	if typeof(slotName) ~= "string" or slotName == "" then
		return fail("Invalid equipment slot.")
	end

	local equipment = data.Equipment or {}
	if not equipment[slotName] then
		return fail("No item equipped in slot: " .. slotName)
	end

	return ok()
end

return InventoryValidator
