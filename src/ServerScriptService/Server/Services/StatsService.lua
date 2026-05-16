--!strict
-- Server-authoritative stat calculation for GhostyRPG.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedConfig = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local ClassConfig = require(SharedConfig:WaitForChild("ClassConfig"))
local RoleConfig = require(SharedConfig:WaitForChild("RoleConfig"))
local StatFormulas = require(SharedConfig:WaitForChild("StatFormulas"))
local ItemConfig = require(SharedConfig:WaitForChild("ItemConfig"))

local StatsService = {}

local playerDataService: any = nil
local initialized = false

local BASE_PRIMARY_STATS = {
	Strength = 5,
	Agility = 5,
	Intellect = 5,
	Stamina = 8,
	Spirit = 5,
}

local function copyBasePrimaryStats(): { [string]: number }
	local stats = {}
	for statName, value in pairs(BASE_PRIMARY_STATS) do
		stats[statName] = value
	end
	return stats
end

local function addNumber(stats: { [string]: number }, key: string, amount: any)
	if type(amount) == "number" then
		stats[key] = (stats[key] or 0) + amount
	end
end

local function applyBonuses(stats: { [string]: number }, bonuses: any)
	if type(bonuses) ~= "table" then
		return
	end
	for statName, amount in pairs(bonuses) do
		if type(statName) == "string" and type(amount) == "number" then
			addNumber(stats, statName, amount)
		end
	end
end

local function getEquipmentItemId(equipmentEntry: any): string?
	if type(equipmentEntry) == "string" then
		return equipmentEntry
	end
	if type(equipmentEntry) == "table" and type(equipmentEntry.itemId) == "string" then
		return equipmentEntry.itemId
	end
	return nil
end

local function addEquipmentBonuses(stats: { [string]: number }, equipment: any)
	if type(equipment) ~= "table" then
		return
	end

	for _, equipmentEntry in pairs(equipment) do
		local itemId = getEquipmentItemId(equipmentEntry)
		if itemId then
			local itemDef = ItemConfig.GetItem(itemId)
			if itemDef then
				applyBonuses(stats, itemDef.statBonuses)
			end
		end
	end
end

function StatsService.Init(newPlayerDataService: any)
	if initialized then
		warn("[StatsService] Init called more than once; ignoring duplicate call.")
		return
	end

	assert(newPlayerDataService, "StatsService.Init requires PlayerDataService.")
	assert(newPlayerDataService.GetData, "StatsService.Init requires PlayerDataService.GetData.")
	assert(newPlayerDataService.ScheduleSave, "StatsService.Init requires PlayerDataService.ScheduleSave.")

	playerDataService = newPlayerDataService
	initialized = true
	print("[StatsService] Initialized.")
end

function StatsService.CalculateFromData(data: { [string]: any }): { [string]: number }
	local level = if type(data.Level) == "number" then math.max(1, data.Level) else 1
	local selectedClass = if type(data.SelectedClass) == "string" then data.SelectedClass else ""
	local selectedRole = if type(data.SelectedRole) == "string" then data.SelectedRole else ""

	local stats = copyBasePrimaryStats()
	stats.Level = level

	local classData = ClassConfig[selectedClass]
	if classData then
		stats.MaxHealth = classData.BaseHealth or 100
		stats.MaxResource = classData.BaseResource or 100
		stats.Armor = classData.BaseArmor or 0
		stats.AttackPower = classData.BaseAttackPower or 0
		stats.SpellPower = classData.BaseSpellPower or 0
	else
		stats.MaxHealth = 100
		stats.MaxResource = 100
		stats.Armor = 0
		stats.AttackPower = 10
		stats.SpellPower = 0
	end

	-- Level growth gives stable progression even before gear/class tuning is complete.
	local growth = math.max(0, level - 1)
	stats.Stamina += growth * 2
	stats.Strength += growth
	stats.Agility += growth
	stats.Intellect += growth
	stats.Spirit += growth

	local roleData = RoleConfig[selectedRole]
	if roleData then
		applyBonuses(stats, roleData.BaseStatBonuses)
	end

	addEquipmentBonuses(stats, data.Equipment)

	local multipliers = if classData and type(classData.StatMultipliers) == "table" then classData.StatMultipliers else {}
	local healthPerStamina = multipliers.HealthPerStamina or StatFormulas.HealthPerStamina or 10
	local manaPerIntellect = multipliers.ManaPerIntellect or StatFormulas.ManaPerIntellect or 10
	local attackPerStrength = multipliers.AttackPowerPerStrength or StatFormulas.AttackPowerPerStrength or 1
	local attackPerAgility = multipliers.AttackPowerPerAgility or StatFormulas.AttackPowerPerAgility or 0
	local spellPerIntellect = multipliers.SpellPowerPerIntellect or StatFormulas.SpellPowerPerIntellect or 1
	local armorPerAgility = multipliers.ArmorPerAgility or 0
	local critPerAgility = multipliers.CritChancePerAgility or StatFormulas.CritChancePerAgility or 0
	local critPerIntellect = multipliers.CritChancePerIntellect or StatFormulas.CritChancePerIntellect or 0

	stats.MaxHealth += stats.Stamina * healthPerStamina
	stats.MaxResource += stats.Intellect * manaPerIntellect
	stats.AttackPower += stats.Strength * attackPerStrength + stats.Agility * attackPerAgility
	stats.SpellPower += stats.Intellect * spellPerIntellect
	stats.Armor += stats.Agility * armorPerAgility
	stats.CritChance = (StatFormulas.BaseCritChance or 5) + (stats.Agility * critPerAgility) + (stats.Intellect * critPerIntellect)
	stats.HealingPower = stats.SpellPower + (stats.Spirit * (StatFormulas.HealingBonusPerSpirit or 0))

	-- Simple aliases for future UI/combat modules while canonical RPG stats remain above.
	stats.HP = stats.MaxHealth
	stats.MP = stats.MaxResource
	stats.Attack = stats.AttackPower
	stats.Defense = stats.Armor
	stats.Speed = 10

	for statName, value in pairs(stats) do
		stats[statName] = math.max(0, math.floor(value))
	end

	return stats
end

function StatsService.Recalculate(player: Player): { [string]: number }?
	assert(initialized and playerDataService, "StatsService.Recalculate requires Init first.")

	local data = playerDataService.GetData(player)
	if not data then
		warn(string.format("[StatsService] No data for %s; cannot recalculate.", player.Name))
		return nil
	end

	local stats = StatsService.CalculateFromData(data)
	data.Stats = stats
	playerDataService.ScheduleSave(player)
	return stats
end

function StatsService.GetStats(player: Player): { [string]: number }?
	assert(initialized and playerDataService, "StatsService.GetStats requires Init first.")

	local data = playerDataService.GetData(player)
	if not data then
		return nil
	end
	return data.Stats
end

return StatsService
