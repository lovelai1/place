--!strict
-- Server-authoritative class and role selection for GhostyRPG.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ClassValidator = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Validators"):WaitForChild("ClassValidator"))
local ClassConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ClassConfig"))

local ClassService = {}

local playerDataService: any = nil
local statsService: any = nil
local initialized = false

local function assertInitialized()
	assert(initialized and playerDataService and statsService, "ClassService requires Init(playerDataService, statsService) before use.")
end

local function applyClassResource(data: { [string]: any }, className: string)
	local classData = ClassConfig[className]
	local resourceType = if classData and type(classData.ResourceType) == "string" then classData.ResourceType else ""
	local maxResource = if classData and type(classData.BaseResource) == "number" then classData.BaseResource else 100

	data.ResourceType = resourceType
	if type(data.CurrentResource) ~= "number" then
		data.CurrentResource = maxResource
	end
	if type(data.Stats) == "table" then
		data.Stats.ResourceType = resourceType
		data.Stats.Resource = data.CurrentResource
		data.Stats.MaxResource = data.Stats.MaxResource or maxResource
	end
end

function ClassService.Init(newPlayerDataService: any, newStatsService: any)
	if initialized then
		warn("[ClassService] Init called more than once; ignoring duplicate call.")
		return
	end

	assert(newPlayerDataService, "ClassService.Init requires PlayerDataService.")
	assert(newPlayerDataService.GetData, "ClassService.Init requires PlayerDataService.GetData.")
	assert(newPlayerDataService.ScheduleSave, "ClassService.Init requires PlayerDataService.ScheduleSave.")
	assert(newStatsService, "ClassService.Init requires StatsService.")
	assert(newStatsService.Recalculate, "ClassService.Init requires StatsService.Recalculate.")

	playerDataService = newPlayerDataService
	statsService = newStatsService
	initialized = true
	print("[ClassService] Initialized.")
end

function ClassService.SelectClass(player: Player, className: string): (boolean, string?)
	assertInitialized()

	local data = playerDataService.GetData(player)
	if not data then
		return false, "Player data is unavailable."
	end

	local validation = ClassValidator.CanSelectClass(data, className)
	if not validation.success then
		return false, validation.reason
	end

	data.SelectedClass = className
	data.SelectedRole = ""
	statsService.Recalculate(player)
	applyClassResource(data, className)
	playerDataService.ScheduleSave(player)
	return true, nil
end

function ClassService.SelectRole(player: Player, roleName: string): (boolean, string?)
	assertInitialized()

	local data = playerDataService.GetData(player)
	if not data then
		return false, "Player data is unavailable."
	end

	local validation = ClassValidator.CanSelectRole(data, roleName)
	if not validation.success then
		return false, validation.reason
	end

	data.SelectedRole = roleName
	statsService.Recalculate(player)
	playerDataService.ScheduleSave(player)
	return true, nil
end

function ClassService.GetClass(player: Player): string?
	assertInitialized()
	local data = playerDataService.GetData(player)
	if not data or type(data.SelectedClass) ~= "string" or data.SelectedClass == "" then
		return nil
	end
	return data.SelectedClass
end

function ClassService.GetRole(player: Player): string?
	assertInitialized()
	local data = playerDataService.GetData(player)
	if not data or type(data.SelectedRole) ~= "string" or data.SelectedRole == "" then
		return nil
	end
	return data.SelectedRole
end

return ClassService
