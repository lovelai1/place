--!strict
-- Centralized server-side loot rolling and granting for GhostyRPG.
-- Safe to require before Init: validation/rolling lazy-load ItemConfig; granting requires Init.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LootService = {}

export type LootEntry = {
	itemId: string,
	minAmount: number,
	maxAmount: number,
	chance: number,
}

export type LootItem = {
	itemId: string,
	amount: number,
}

export type LootResult = {
	success: boolean,
	reason: string?,
	items: { LootItem },
}

local inventoryService: any = nil
local itemConfig: any = nil
local initialized = false

local function result(success: boolean, reason: string?, items: { LootItem }?): LootResult
	return { success = success, reason = reason, items = items or {} }
end

local function getItemConfig(): any
	if itemConfig == nil then
		local ok, configOrError = pcall(function()
			return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ItemConfig"))
		end)
		if not ok or type(configOrError) ~= "table" then
			error("[LootService] Failed to load ItemConfig: " .. tostring(configOrError), 2)
		end
		itemConfig = configOrError
	end
	return itemConfig
end

local function isKnownItem(itemId: string): boolean
	local ok, config = pcall(getItemConfig)
	if not ok then
		return false
	end
	if type(config.IsValidItem) == "function" then
		return config.IsValidItem(itemId)
	end
	return config[itemId] ~= nil
end

local function isPositiveInteger(value: any): boolean
	return type(value) == "number" and value >= 1 and value == math.floor(value)
end

function LootService.ValidateLootTable(lootTable: any): { success: boolean, reason: string? }
	if type(lootTable) ~= "table" then
		return { success = false, reason = "lootTable must be a table." }
	end
	if #lootTable == 0 then
		return { success = false, reason = "lootTable is empty." }
	end

	for index, entry in ipairs(lootTable) do
		local prefix = string.format("Entry[%d]: ", index)
		if type(entry) ~= "table" then
			return { success = false, reason = prefix .. "entry must be a table." }
		end
		if type(entry.itemId) ~= "string" or entry.itemId == "" then
			return { success = false, reason = prefix .. "itemId must be a non-empty string." }
		end
		if not isKnownItem(entry.itemId) then
			return { success = false, reason = prefix .. string.format("itemId %q is not registered in ItemConfig.", entry.itemId) }
		end
		if not isPositiveInteger(entry.minAmount) then
			return { success = false, reason = prefix .. "minAmount must be a positive integer." }
		end
		if type(entry.maxAmount) ~= "number" or entry.maxAmount ~= math.floor(entry.maxAmount) then
			return { success = false, reason = prefix .. "maxAmount must be an integer." }
		end
		if entry.maxAmount < entry.minAmount then
			return { success = false, reason = prefix .. "maxAmount must be >= minAmount." }
		end
		if type(entry.chance) ~= "number" then
			return { success = false, reason = prefix .. "chance must be a number." }
		end
		if entry.chance <= 0 or entry.chance > 1 then
			return { success = false, reason = prefix .. "chance must be in the range (0, 1]." }
		end
	end

	return { success = true }
end

function LootService.RollLoot(lootTable: any, rng: Random?): LootResult
	local validation = LootService.ValidateLootTable(lootTable)
	if not validation.success then
		return result(false, validation.reason, {})
	end

	if rng == nil then
		rng = Random.new()
	elseif typeof(rng) ~= "Random" then
		return result(false, "rng must be a Random instance or nil.", {})
	end

	local won: { LootItem } = {}
	for _, entry in ipairs(lootTable) do
		if rng:NextNumber() <= entry.chance then
			local amount = if entry.minAmount == entry.maxAmount then entry.minAmount else rng:NextInteger(entry.minAmount, entry.maxAmount)
			local merged = false
			for _, existing in ipairs(won) do
				if existing.itemId == entry.itemId then
					existing.amount += amount
					merged = true
					break
				end
			end
			if not merged then
				table.insert(won, { itemId = entry.itemId, amount = amount })
			end
		end
	end

	return result(true, nil, won)
end

function LootService.GrantLoot(player: Player, lootTable: any, rng: Random?): LootResult
	if not initialized then
		return result(false, "LootService.Init() has not been called.", {})
	end
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return result(false, "player must be a Player instance.", {})
	end

	local rollResult = LootService.RollLoot(lootTable, rng)
	if not rollResult.success then
		return rollResult
	end

	local granted: { LootItem } = {}
	local failures = {}
	for _, drop in ipairs(rollResult.items) do
		local ok, addResult = pcall(function()
			return inventoryService.AddItem(player, drop.itemId, drop.amount)
		end)
		if ok and addResult ~= false then
			table.insert(granted, { itemId = drop.itemId, amount = drop.amount })
		else
			table.insert(failures, string.format("[%s x%d] %s", drop.itemId, drop.amount, tostring(addResult)))
		end
	end

	if #failures > 0 then
		return result(false, "Some items failed to grant: " .. table.concat(failures, "; "), granted)
	end
	return result(true, nil, granted)
end

function LootService.Init(newInventoryService: any)
	if initialized then
		warn("[LootService] Init called more than once; ignoring duplicate call.")
		return
	end
	assert(type(newInventoryService) == "table" and type(newInventoryService.AddItem) == "function", "LootService.Init requires InventoryService.AddItem.")
	inventoryService = newInventoryService
	initialized = true
	print("[LootService] Initialized.")
end

function LootService.IsInitialized(): boolean
	return initialized
end

return LootService
