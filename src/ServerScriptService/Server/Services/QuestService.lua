--!strict
-- Server-authoritative quest service for GhostyRPG.
-- Call QuestService.Init(playerDataService, inventoryService?) once dependencies exist.
-- Required PlayerDataService interface:
--   GetData(player: Player) -> table?
--   ScheduleSave(player: Player) -> nil

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local QuestsConfig = require(Shared:WaitForChild("Config"):WaitForChild("QuestsConfig"))
local QuestRemotes = require(Shared:WaitForChild("Remotes"):WaitForChild("QuestRemotes"))
local QuestsServerConfig = require(Server:WaitForChild("Config"):WaitForChild("QuestsServerConfig"))
local QuestValidator = require(Server:WaitForChild("Validators"):WaitForChild("QuestValidator"))

local questTurnedInBindable = Instance.new("BindableEvent")

local QuestService = {}
QuestService.QuestTurnedInSignal = questTurnedInBindable.Event

local dataService: any = nil
local inventoryService: any = nil
local initialized = false
local savePending: { [Player]: boolean } = {}

local function getData(player: Player): { [string]: any }?
	assert(dataService, "QuestService requires Init(dataService) before use.")
	return dataService.GetData(player)
end

local function scheduleSave(player: Player)
	if savePending[player] then
		return
	end

	savePending[player] = true
	task.delay(5, function()
		savePending[player] = nil
		if player.Parent and dataService then
			dataService.ScheduleSave(player)
		end
	end)
end

local function getActiveQuests(data: { [string]: any }): { [string]: any }
	if not data.ActiveQuests then
		data.ActiveQuests = {}
	end
	return data.ActiveQuests
end

local function getCompletedQuests(data: { [string]: any }): { [string]: number }
	if not data.CompletedQuests then
		data.CompletedQuests = {}
	end
	return data.CompletedQuests
end

local function buildQuestEntry(questId: string): { [string]: any }
	local def = QuestsConfig.Quests[questId]
	assert(def, string.format("Quest definition '%s' was not found.", questId))

	local objectives: { [string]: { current: number, required: number } } = {}
	for _, objDef in ipairs(def.objectives) do
		objectives[objDef.id] = { current = 0, required = objDef.required }
	end

	return {
		questId = questId,
		startedAt = os.time(),
		objectives = objectives,
	}
end

local function isAllObjectivesComplete(questId: string, activeEntry: { [string]: any }): boolean
	local def = QuestsConfig.Quests[questId]
	if not def then
		return false
	end

	for _, objDef in ipairs(def.objectives) do
		local progress = activeEntry.objectives[objDef.id]
		if not progress or progress.current < objDef.required then
			return false
		end
	end

	return true
end

local function addInventoryItem(player: Player, data: { [string]: any }, itemId: string, amount: number): boolean
	if inventoryService then
		return inventoryService.AddItem(player, itemId, amount)
	end

	data.Inventory = data.Inventory or {}
	local inventory = data.Inventory
	local entry = inventory[itemId]

	if entry then
		entry.amount = (entry.amount or 0) + amount
	else
		inventory[itemId] = { itemId = itemId, amount = amount }
	end
	return true
end

local function distributeRewards(player: Player, questId: string, data: { [string]: any }): { [string]: any }
	local reward = QuestsServerConfig.Rewards[questId]
	if not reward then
		warn(string.format("[QuestService] Missing rewards for quest '%s'.", questId))
		return { exp = 0, gold = 0, items = {} }
	end

	data.Exp = (data.Exp or 0) + reward.exp
	data.Gold = (data.Gold or 0) + reward.gold

	local rolledItems = {}
	for _, itemReward in ipairs(reward.items) do
		if math.random() <= itemReward.chance then
			if addInventoryItem(player, data, itemReward.itemId, itemReward.amount) then
				table.insert(rolledItems, { itemId = itemReward.itemId, amount = itemReward.amount })
			end
		end
	end

	local granted = { exp = reward.exp, gold = reward.gold, items = rolledItems }
	questTurnedInBindable:Fire(player, questId, granted)
	return granted
end

function QuestService.AcceptQuest(player: Player, questId: string): (boolean, string?)
	if typeof(questId) ~= "string" or #questId == 0 then
		return false, "Invalid quest id."
	end

	local data = getData(player)
	if not data then
		return false, "Player data is unavailable."
	end

	local active = getActiveQuests(data)
	local completed = getCompletedQuests(data)
	local level = data.Level or 1

	local validation = QuestValidator.CanAccept(questId, level, active, completed, QuestsServerConfig.MaxActiveQuests, os.time(), QuestsServerConfig.RepeatableCooldownSeconds)
	if not validation.success then
		return false, validation.reason
	end

	active[questId] = buildQuestEntry(questId)
	scheduleSave(player)

	local def = QuestsConfig.Quests[questId]
	QuestRemotes.GetEvent("QuestAccepted"):FireClient(player, {
		questId = questId,
		name = def.name,
		objectives = active[questId].objectives,
	})

	return true, nil
end

function QuestService.AbandonQuest(player: Player, questId: string): (boolean, string?)
	if typeof(questId) ~= "string" or #questId == 0 then
		return false, "Invalid quest id."
	end

	local data = getData(player)
	if not data then
		return false, "Player data is unavailable."
	end

	local active = getActiveQuests(data)
	local validation = QuestValidator.CanAbandon(questId, active)
	if not validation.success then
		return false, validation.reason
	end

	active[questId] = nil
	scheduleSave(player)
	QuestRemotes.GetEvent("QuestAbandoned"):FireClient(player, { questId = questId })

	return true, nil
end

function QuestService.TurnInQuest(player: Player, questId: string): (boolean, string?)
	if typeof(questId) ~= "string" or #questId == 0 then
		return false, "Invalid quest id."
	end

	local data = getData(player)
	if not data then
		return false, "Player data is unavailable."
	end

	local active = getActiveQuests(data)
	local completed = getCompletedQuests(data)
	local validation = QuestValidator.CanTurnIn(questId, active)
	if not validation.success then
		return false, validation.reason
	end

	local granted = distributeRewards(player, questId, data)
	active[questId] = nil
	completed[questId] = os.time()
	scheduleSave(player)

	QuestRemotes.GetEvent("QuestTurnedIn"):FireClient(player, { questId = questId, rewards = granted })
	return true, nil
end

function QuestService.NotifyKill(player: Player, mobId: string)
	QuestService.UpdateProgress(player, "Kill", mobId, 1)
end

function QuestService.NotifyCollect(player: Player, itemId: string, amount: number?)
	QuestService.UpdateProgress(player, "Collect", itemId, amount or 1)
end

function QuestService.NotifyTalk(player: Player, npcId: string)
	QuestService.UpdateProgress(player, "Talk", npcId, 1)
end

function QuestService.NotifyExplore(player: Player, zoneId: string)
	QuestService.UpdateProgress(player, "Explore", zoneId, 1)
end

function QuestService.NotifyCraft(player: Player, itemId: string, amount: number?)
	QuestService.UpdateProgress(player, "Craft", itemId, amount or 1)
end

function QuestService.UpdateProgress(player: Player, objectiveType: string, targetId: string, amount: number)
	if amount <= 0 then
		return
	end

	local data = getData(player)
	if not data then
		return
	end

	local active = getActiveQuests(data)
	local anyUpdated = false
	local readyToTurnIn = {}

	for questId, entry in pairs(active) do
		local def = QuestsConfig.Quests[questId]
		if def then
			local questUpdated = false
			for _, objDef in ipairs(def.objectives) do
				if objDef.objectiveType == objectiveType and objDef.targetId == targetId then
					local progress = entry.objectives[objDef.id]
					if progress and progress.current < objDef.required then
						progress.current = math.min(progress.current + amount, objDef.required)
						questUpdated = true
						anyUpdated = true
					end
				end
			end

			if questUpdated then
				QuestRemotes.GetEvent("QuestProgressUpdated"):FireClient(player, { questId = questId, objectives = entry.objectives })
				if isAllObjectivesComplete(questId, entry) then
					table.insert(readyToTurnIn, questId)
				end
			end
		end
	end

	if not anyUpdated then
		return
	end

	scheduleSave(player)
	for _, questId in ipairs(readyToTurnIn) do
		QuestRemotes.GetEvent("QuestReadyToTurnIn"):FireClient(player, { questId = questId })
	end
end

local function getAvailableQuests(player: Player): { any }
	local data = getData(player)
	if not data then
		return {}
	end

	local active = getActiveQuests(data)
	local completed = getCompletedQuests(data)
	local level = data.Level or 1
	local result = {}

	for questId, def in pairs(QuestsConfig.Quests) do
		local validation = QuestValidator.CanAccept(questId, level, active, completed, QuestsServerConfig.MaxActiveQuests, os.time(), QuestsServerConfig.RepeatableCooldownSeconds)
		if validation.success then
			table.insert(result, {
				id = def.id,
				name = def.name,
				description = def.description,
				levelRequirement = def.levelRequirement,
				repeatable = def.repeatable,
				objectives = def.objectives,
			})
		end
	end

	return result
end

local function getActiveQuestList(player: Player): { any }
	local data = getData(player)
	if not data then
		return {}
	end

	local active = getActiveQuests(data)
	local result = {}

	for questId, entry in pairs(active) do
		local def = QuestsConfig.Quests[questId]
		if def then
			table.insert(result, {
				id = questId,
				name = def.name,
				description = def.description,
				objectives = def.objectives,
				progress = entry.objectives,
				startedAt = entry.startedAt,
				isComplete = isAllObjectivesComplete(questId, entry),
			})
		end
	end

	return result
end

function QuestService.Init(newDataService: any, newInventoryService: any?)
	assert(newDataService, "QuestService.Init requires a DataService.")
	assert(newDataService.GetData, "QuestService.Init requires dataService:GetData(player).")
	assert(newDataService.ScheduleSave, "QuestService.Init requires dataService.ScheduleSave(player).")

	if initialized then
		warn("[QuestService] Init called more than once; ignoring duplicate call.")
		return
	end

	dataService = newDataService
	inventoryService = newInventoryService
	initialized = true
	QuestRemotes.Ensure()

	QuestRemotes.GetEvent("AcceptQuest").OnServerEvent:Connect(function(player: Player, questId: any)
		if typeof(questId) ~= "string" then
			return
		end
		local success, reason = QuestService.AcceptQuest(player, questId)
		if not success then
			warn(string.format("[QuestService] AcceptQuest rejected for %s: %s", player.Name, tostring(reason)))
		end
	end)

	QuestRemotes.GetEvent("AbandonQuest").OnServerEvent:Connect(function(player: Player, questId: any)
		if typeof(questId) ~= "string" then
			return
		end
		local success, reason = QuestService.AbandonQuest(player, questId)
		if not success then
			warn(string.format("[QuestService] AbandonQuest rejected for %s: %s", player.Name, tostring(reason)))
		end
	end)

	QuestRemotes.GetEvent("TurnInQuest").OnServerEvent:Connect(function(player: Player, questId: any)
		if typeof(questId) ~= "string" then
			return
		end
		local success, reason = QuestService.TurnInQuest(player, questId)
		if not success then
			warn(string.format("[QuestService] TurnInQuest rejected for %s: %s", player.Name, tostring(reason)))
		end
	end)

	QuestRemotes.GetFunction("GetAvailableQuests").OnServerInvoke = getAvailableQuests
	QuestRemotes.GetFunction("GetActiveQuests").OnServerInvoke = getActiveQuestList

	Players.PlayerRemoving:Connect(function(player: Player)
		savePending[player] = nil
	end)

	print("[QuestService] Initialized.")
end

return QuestService
