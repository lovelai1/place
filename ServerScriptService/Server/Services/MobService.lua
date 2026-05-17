--!strict
-- Server-authoritative mob registry and reward pipeline for GhostyRPG.
-- Tracks live mob state in memory, handles damage/death, grants rewards, and notifies quests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MobConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("MobConfig"))
local MobServerConfig = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Config"):WaitForChild("MobServerConfig"))

local MobService = {}

export type MobState = {
	mobId: string,
	currentHealth: number,
	maxHealth: number,
	level: number,
	isDead: boolean,
	killedBy: Player?,
}

local playerDataService: any = nil
local questService: any = nil
local inventoryService: any = nil
local lootService: any = nil
local initialized = false
local registry: { [Instance]: MobState } = {}

local function assertInitialized()
	assert(initialized and playerDataService and questService and inventoryService and lootService, "MobService requires Init(playerDataService, questService, inventoryService, lootService) before use.")
end

local function safeCall(label: string, callback: () -> ())
	local ok, err = pcall(callback)
	if not ok then
		warn(string.format("[MobService] %s failed: %s", label, tostring(err)))
	end
	return ok
end


function MobService.Init(newPlayerDataService: any, newQuestService: any, newInventoryService: any, newLootService: any)
	if initialized then
		warn("[MobService] Init called more than once; ignoring duplicate call.")
		return
	end

	assert(newPlayerDataService, "MobService.Init requires PlayerDataService.")
	assert(type(newPlayerDataService.AddExp) == "function", "MobService.Init requires PlayerDataService.AddExp.")
	assert(type(newPlayerDataService.AddGold) == "function", "MobService.Init requires PlayerDataService.AddGold.")
	assert(newQuestService, "MobService.Init requires QuestService.")
	assert(type(newQuestService.NotifyKill) == "function", "MobService.Init requires QuestService.NotifyKill.")
	assert(newInventoryService, "MobService.Init requires InventoryService.")
	assert(type(newInventoryService.AddItem) == "function", "MobService.Init requires InventoryService.AddItem.")
	assert(newLootService, "MobService.Init requires LootService.")
	assert(type(newLootService.GrantLoot) == "function", "MobService.Init requires LootService.GrantLoot.")

	playerDataService = newPlayerDataService
	questService = newQuestService
	inventoryService = newInventoryService
	lootService = newLootService
	initialized = true
	print("[MobService] Initialized.")
end

function MobService.SetLootService(newLootService: any)
	assert(type(newLootService) == "table" and type(newLootService.GrantLoot) == "function", "MobService.SetLootService requires LootService.GrantLoot.")
	lootService = newLootService
end

function MobService.RegisterMob(model: Instance, mobId: string): MobState
	assertInitialized()
	assert(typeof(model) == "Instance", "MobService.RegisterMob requires an Instance model.")
	assert(type(mobId) == "string" and mobId ~= "", "MobService.RegisterMob requires a non-empty mobId.")
	assert(MobConfig.IsValidMob(mobId), "MobService.RegisterMob unknown mobId: " .. mobId)

	if registry[model] then
		warn(string.format("[MobService] RegisterMob overwriting existing registry entry for %s.", model:GetFullName()))
	end

	local maxHealth = MobConfig.GetMaxHealth(mobId) or 1
	local level = MobConfig.GetLevel(mobId) or 1
	local state: MobState = {
		mobId = mobId,
		currentHealth = maxHealth,
		maxHealth = maxHealth,
		level = level,
		isDead = false,
		killedBy = nil,
	}

	registry[model] = state
	model:SetAttribute("MobId", mobId)
	model:SetAttribute("CurrentHealth", maxHealth)
	model:SetAttribute("MaxHealth", maxHealth)
	model:SetAttribute("Level", level)
	return state
end

function MobService.UnregisterMob(model: Instance)
	if registry[model] == nil then
		return
	end
	registry[model] = nil
end

function MobService.IsRegistered(model: Instance): boolean
	return registry[model] ~= nil
end

function MobService.GetMobState(model: Instance): MobState?
	return registry[model]
end

function MobService.ApplyDamage(model: Instance, amount: number, sourcePlayer: Player?)
	assertInitialized()
	assert(typeof(model) == "Instance", "MobService.ApplyDamage requires an Instance model.")
	assert(type(amount) == "number" and amount >= 0, "MobService.ApplyDamage requires non-negative damage.")

	local state = registry[model]
	if not state or state.isDead then
		return
	end

	local mobDef = MobConfig.GetMob(state.mobId)
	local armor = if mobDef then mobDef.armor else 0
	local effectiveDamage = math.max(0, amount - armor)
	state.currentHealth = math.max(0, state.currentHealth - effectiveDamage)
	model:SetAttribute("CurrentHealth", state.currentHealth)

	if state.currentHealth <= 0 then
		MobService.KillMob(model, sourcePlayer)
	end
end

function MobService.KillMob(model: Instance, killerPlayer: Player?)
	assertInitialized()
	assert(typeof(model) == "Instance", "MobService.KillMob requires an Instance model.")

	local state = registry[model]
	if not state or state.isDead then
		return
	end

	state.isDead = true
	state.killedBy = killerPlayer
	state.currentHealth = 0
	model:SetAttribute("CurrentHealth", 0)

	local mobId = state.mobId
	if killerPlayer and typeof(killerPlayer) == "Instance" and killerPlayer:IsA("Player") then
		local serverData = MobServerConfig.GetServerMob(mobId)
		if serverData then
			if serverData.exp > 0 then
				safeCall("PlayerDataService.AddExp", function()
					playerDataService.AddExp(killerPlayer, serverData.exp)
				end)
			end
			if serverData.gold > 0 then
				safeCall("PlayerDataService.AddGold", function()
					playerDataService.AddGold(killerPlayer, serverData.gold)
				end)
			end
			local lootResult = lootService.GrantLoot(killerPlayer, serverData.loot or {})
			if not lootResult.success then
				warn(string.format("[MobService] LootService.GrantLoot failed for %s: %s", mobId, tostring(lootResult.reason)))
			end
		else
			warn(string.format("[MobService] No MobServerConfig reward entry for %s.", mobId))
		end

		safeCall("QuestService.NotifyKill", function()
			questService.NotifyKill(killerPlayer, mobId)
		end)
	end

	MobService.UnregisterMob(model)
end

return MobService
