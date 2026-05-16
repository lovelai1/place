--!strict
-- Server-authoritative combat core for GhostyRPG.
-- Handles ability validation, session cooldowns, resource spending, damage, and healing.
-- No remotes. No UI. No mob AI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SharedConfig = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Server = ServerScriptService:WaitForChild("Server")

local AbilityConfig = require(SharedConfig:WaitForChild("AbilityConfig"))
local AbilityValidator = require(Server:WaitForChild("Validators"):WaitForChild("AbilityValidator"))

local CombatService = {}

local playerDataService: any = nil
local statsService: any = nil
local initialized = false

export type CombatResult = {
	success: boolean,
	reason: string?,
	amount: number?,
}

local function result(success: boolean, reason: string?, amount: number?): CombatResult
	return { success = success, reason = reason, amount = amount }
end

local function assertInitialized()
	assert(initialized and playerDataService and statsService, "CombatService requires Init(playerDataService, statsService) before use.")
end

local function now(): number
	return os.clock()
end

local function clamp(value: number, minValue: number, maxValue: number): number
	return math.max(minValue, math.min(maxValue, value))
end

local function getPlayerData(player: Player): { [string]: any }
	local data = playerDataService.GetData(player)
	if not data then
		error(string.format("[CombatService] No PlayerData for %s.", player.Name))
	end
	return data
end

local function getStats(player: Player): { [string]: any }?
	local ok, stats = pcall(statsService.GetStats, player)
	if ok and type(stats) == "table" then
		return stats
	end

	if type(statsService.Recalculate) == "function" then
		local recalcOk, recalculated = pcall(statsService.Recalculate, player)
		if recalcOk and type(recalculated) == "table" then
			return recalculated
		end
	end

	return nil
end

local function getCooldownMap(data: { [string]: any }): { [string]: number }
	if type(data.AbilityCooldowns) ~= "table" then
		data.AbilityCooldowns = {}
	end
	return data.AbilityCooldowns
end

local function getResourceType(data: { [string]: any }): string
	if type(data.ResourceType) == "string" and data.ResourceType ~= "" then
		return data.ResourceType
	end
	local stats = data.Stats
	if type(stats) == "table" and type(stats.ResourceType) == "string" then
		return stats.ResourceType
	end
	return ""
end

local function getMaxResource(data: { [string]: any }, stats: { [string]: any }?): number
	if stats and type(stats.MaxResource) == "number" then
		return stats.MaxResource
	end
	if type(data.MaxResource) == "number" then
		return data.MaxResource
	end
	local dataStats = data.Stats
	if type(dataStats) == "table" and type(dataStats.MaxResource) == "number" then
		return dataStats.MaxResource
	end
	return 100
end

local function syncResourceFields(data: { [string]: any }, stats: { [string]: any }?)
	local maxResource = getMaxResource(data, stats)
	local currentResource = data.CurrentResource
	local dataStats = data.Stats

	if type(currentResource) ~= "number" and type(dataStats) == "table" and type(dataStats.Resource) == "number" then
		currentResource = dataStats.Resource
	end
	if type(currentResource) ~= "number" then
		currentResource = maxResource
	end

	currentResource = clamp(currentResource, 0, maxResource)
	data.CurrentResource = currentResource
	data.ResourceType = getResourceType(data)

	if type(dataStats) ~= "table" then
		data.Stats = {}
		dataStats = data.Stats
	end
	dataStats.Resource = currentResource
	dataStats.MaxResource = maxResource
	dataStats.ResourceType = data.ResourceType
end

local function getMaxHealth(data: { [string]: any }, stats: { [string]: any }?): number
	if stats and type(stats.MaxHealth) == "number" then
		return stats.MaxHealth
	end
	local dataStats = data.Stats
	if type(dataStats) == "table" and type(dataStats.MaxHealth) == "number" then
		return dataStats.MaxHealth
	end
	if type(data.MaxHealth) == "number" then
		return data.MaxHealth
	end
	return 100
end

local function syncHealthFields(data: { [string]: any }, stats: { [string]: any }?)
	local maxHealth = getMaxHealth(data, stats)
	local currentHealth = data.CurrentHealth
	local dataStats = data.Stats

	if type(currentHealth) ~= "number" and type(dataStats) == "table" and type(dataStats.HP) == "number" then
		currentHealth = dataStats.HP
	end
	if type(currentHealth) ~= "number" then
		currentHealth = maxHealth
	end

	currentHealth = clamp(currentHealth, 0, maxHealth)
	data.CurrentHealth = currentHealth
	if type(dataStats) == "table" then
		dataStats.HP = currentHealth
		dataStats.MaxHealth = maxHealth
	end
end

local function isOnCooldown(data: { [string]: any }, abilityId: string): boolean
	local expiry = getCooldownMap(data)[abilityId]
	return type(expiry) == "number" and expiry > now()
end

local function setCooldown(data: { [string]: any }, abilityId: string, durationSeconds: number)
	if durationSeconds > 0 then
		getCooldownMap(data)[abilityId] = now() + durationSeconds
	end
end

local function mutateHealth(targetContext: { [string]: any }, delta: number): number
	if typeof(targetContext.targetPlayer) == "Instance" and targetContext.targetPlayer:IsA("Player") then
		local targetPlayer = targetContext.targetPlayer :: Player
		local data = playerDataService.GetData(targetPlayer)
		if not data then
			return 0
		end

		local stats = getStats(targetPlayer)
		syncHealthFields(data, stats)
		local maxHealth = getMaxHealth(data, stats)
		local before = data.CurrentHealth
		data.CurrentHealth = clamp(before + delta, 0, maxHealth)
		if type(data.Stats) == "table" then
			data.Stats.HP = data.CurrentHealth
		end
		if type(playerDataService.ScheduleSave) == "function" then
			playerDataService.ScheduleSave(targetPlayer)
		end
		return data.CurrentHealth - before
	end

	if typeof(targetContext.targetModel) == "Instance" and targetContext.targetModel:IsA("Model") then
		local model = targetContext.targetModel :: Model
		local maxHealth = model:GetAttribute("MaxHealth")
		local currentHealth = model:GetAttribute("Health")
		if type(maxHealth) ~= "number" or type(currentHealth) ~= "number" then
			return 0
		end

		local newHealth = clamp(currentHealth + delta, 0, maxHealth)
		model:SetAttribute("Health", newHealth)
		return newHealth - currentHealth
	end

	return 0
end

function CombatService.Init(newPlayerDataService: any, newStatsService: any)
	if initialized then
		warn("[CombatService] Init called more than once; ignoring duplicate call.")
		return
	end

	assert(newPlayerDataService, "CombatService.Init requires PlayerDataService.")
	assert(newPlayerDataService.GetData, "CombatService.Init requires PlayerDataService.GetData.")
	assert(newPlayerDataService.ScheduleSave, "CombatService.Init requires PlayerDataService.ScheduleSave.")
	assert(newStatsService, "CombatService.Init requires StatsService.")
	assert(newStatsService.GetStats, "CombatService.Init requires StatsService.GetStats.")
	assert(newStatsService.Recalculate, "CombatService.Init requires StatsService.Recalculate.")

	playerDataService = newPlayerDataService
	statsService = newStatsService
	initialized = true
	print("[CombatService] Initialized.")
end

function CombatService.IsInitialized(): boolean
	return initialized
end

function CombatService.UseAbility(casterPlayer: Player, abilityId: string, targetContext: { [string]: any }?): CombatResult
	assertInitialized()
	assert(typeof(casterPlayer) == "Instance" and casterPlayer:IsA("Player"), "CombatService.UseAbility requires a Player caster.")
	assert(type(abilityId) == "string" and abilityId ~= "", "CombatService.UseAbility requires a non-empty abilityId.")

	targetContext = targetContext or {}
	local ability = AbilityConfig.GetAbility(abilityId)
	if not ability then
		return result(false, "unknown_ability", nil)
	end

	local data = getPlayerData(casterPlayer)
	local stats = getStats(casterPlayer)
	syncHealthFields(data, stats)
	syncResourceFields(data, stats)

	-- AbilityValidator owns level/class/role/resource validation. CombatService owns absolute expiry cooldowns.
	local validation = AbilityValidator.CanUseAbility(data, abilityId, now(), nil)
	if not validation.success then
		return result(false, validation.reason or "validation_failed", nil)
	end

	if isOnCooldown(data, abilityId) then
		return result(false, "on_cooldown", nil)
	end

	local resourceCost = if type(ability.resourceCost) == "number" then ability.resourceCost else 0
	if resourceCost > 0 and data.CurrentResource < resourceCost then
		return result(false, "insufficient_resource", nil)
	end

	if resourceCost > 0 then
		local spendResult = CombatService.SpendResource(casterPlayer, resourceCost)
		if not spendResult.success then
			return result(false, spendResult.reason or "spend_failed", nil)
		end
	end

	setCooldown(data, abilityId, if type(ability.cooldown) == "number" then ability.cooldown else 0)

	local amount = 0
	if ability.effectType == "Damage" then
		local attackPower = if stats and type(stats.AttackPower) == "number" then stats.AttackPower else 10
		local power = if type(ability.power) == "number" then ability.power else 1
		local damage = math.max(1, math.floor(attackPower * power))
		amount = CombatService.ApplyDamage(casterPlayer, targetContext, damage, ability.tags and ability.tags[1] or "Physical").amount or 0
	elseif ability.effectType == "Heal" then
		local healingPower = if stats and type(stats.HealingPower) == "number" then stats.HealingPower elseif stats and type(stats.SpellPower) == "number" then stats.SpellPower else 10
		local power = if type(ability.power) == "number" then ability.power else 1
		local healing = math.max(1, math.floor(healingPower * power))
		amount = CombatService.ApplyHeal(casterPlayer, targetContext, healing).amount or 0
	elseif ability.effectType == "ResourceGain" then
		local maxResource = getMaxResource(data, stats)
		local restoreAmount = math.max(1, math.floor(maxResource * (ability.power or 0)))
		amount = CombatService.RestoreResource(casterPlayer, restoreAmount).amount or 0
	end

	if type(playerDataService.ScheduleSave) == "function" then
		playerDataService.ScheduleSave(casterPlayer)
	end
	return result(true, nil, amount)
end

function CombatService.ApplyDamage(_source: Player | string, targetContext: { [string]: any }?, amount: number, _damageType: string?): CombatResult
	assertInitialized()
	targetContext = targetContext or {}
	amount = math.max(0, amount or 0)
	if amount <= 0 then
		return result(true, nil, 0)
	end
	local actualDelta = mutateHealth(targetContext, -amount)
	return result(true, nil, math.abs(actualDelta))
end

function CombatService.ApplyHeal(_source: Player | string, targetContext: { [string]: any }?, amount: number): CombatResult
	assertInitialized()
	targetContext = targetContext or {}
	amount = math.max(0, amount or 0)
	if amount <= 0 then
		return result(true, nil, 0)
	end
	return result(true, nil, mutateHealth(targetContext, amount))
end

function CombatService.SpendResource(player: Player, amount: number): CombatResult
	assertInitialized()
	amount = math.max(0, amount or 0)
	local data = getPlayerData(player)
	local stats = getStats(player)
	syncResourceFields(data, stats)
	local maxResource = getMaxResource(data, stats)
	if data.CurrentResource < amount then
		return result(false, "insufficient_resource", nil)
	end
	local before = data.CurrentResource
	data.CurrentResource = clamp(before - amount, 0, maxResource)
	syncResourceFields(data, stats)
	return result(true, nil, before - data.CurrentResource)
end

function CombatService.RestoreResource(player: Player, amount: number): CombatResult
	assertInitialized()
	amount = math.max(0, amount or 0)
	local data = getPlayerData(player)
	local stats = getStats(player)
	syncResourceFields(data, stats)
	local maxResource = getMaxResource(data, stats)
	local before = data.CurrentResource
	data.CurrentResource = clamp(before + amount, 0, maxResource)
	syncResourceFields(data, stats)
	return result(true, nil, data.CurrentResource - before)
end

function CombatService.GetCooldowns(player: Player): { [string]: number }
	assertInitialized()
	local data = getPlayerData(player)
	local cooldowns = getCooldownMap(data)
	local currentTime = now()
	local snapshot = {}

	for abilityId, expiry in pairs(cooldowns) do
		if type(expiry) == "number" then
			local remaining = expiry - currentTime
			if remaining > 0 then
				snapshot[abilityId] = remaining
			else
				cooldowns[abilityId] = nil
			end
		else
			cooldowns[abilityId] = nil
		end
	end

	return snapshot
end

return CombatService
