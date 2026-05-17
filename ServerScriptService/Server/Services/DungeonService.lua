--!strict
-- Server-authoritative, in-memory lifecycle manager for GhostyRPG dungeon runs.
-- This service tracks run state only; map loading, teleporting, spawning, and finder UI live elsewhere.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local DungeonValidator = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Validators"):WaitForChild("DungeonValidator"))

local DungeonService = {}

type RunData = {
	runId: string,
	dungeonId: string,
	difficulty: string,
	members: { Player },
	leaderUserId: number,
	status: string,
	startedAt: number?,
	objectives: { [string]: boolean },
	failReason: string?,
}

local runs: { [string]: RunData } = {}
local playerRunIndex: { [number]: string } = {}

local playerDataService: any = nil
local partyService: any = nil
local questService: any = nil
local inventoryService: any = nil
local magicTierService: any = nil  -- Phase 5: AMP on dungeon clear
local initialized = false

local function generateRunId(): string
	return "RUN_" .. HttpService:GenerateGUID(false)
end

local function safeCall(label: string, callback: () -> ())
	local ok, err = pcall(callback)
	if not ok then
		warn(string.format("[DungeonService] %s failed: %s", label, tostring(err)))
	end
end

local function copyMembers(members: { Player }): { Player }
	local copy = {}
	for index, member in ipairs(members) do
		copy[index] = member
	end
	return copy
end

local function copyObjectives(objectives: { [string]: boolean }): { [string]: boolean }
	local copy = {}
	for objectiveId, completed in pairs(objectives) do
		copy[objectiveId] = completed
	end
	return copy
end

local function snapshotRun(run: RunData): RunData
	return {
		runId = run.runId,
		dungeonId = run.dungeonId,
		difficulty = run.difficulty,
		members = copyMembers(run.members),
		leaderUserId = run.leaderUserId,
		status = run.status,
		startedAt = run.startedAt,
		objectives = copyObjectives(run.objectives),
		failReason = run.failReason,
	}
end

local function indexMembers(runId: string, members: { Player })
	for _, member in ipairs(members) do
		playerRunIndex[member.UserId] = runId
	end
end

local function deindexMembers(members: { Player })
	for _, member in ipairs(members) do
		playerRunIndex[member.UserId] = nil
	end
end

local function scheduleEviction(runId: string, run: RunData)
	task.delay(5, function()
		if runs[runId] == run and (run.status == "Completed" or run.status == "Failed") then
			runs[runId] = nil
		end
	end)
end

local function getPartyMembers(leader: Player): { Player }
	if partyService and type(partyService.GetPartyMembers) == "function" then
		local members = partyService.GetPartyMembers(leader)
		if type(members) == "table" and #members > 0 then
			return copyMembers(members)
		end
	end

	if partyService and type(partyService.GetParty) == "function" then
		local party = partyService.GetParty(leader)
		if type(party) == "table" then
			if type(party.members) == "table" and #party.members > 0 then
				return copyMembers(party.members)
			end
			if type(party.id) == "string" and type(partyService.GetMembers) == "function" then
				local members = partyService.GetMembers(party.id)
				if type(members) == "table" and #members > 0 then
					return copyMembers(members)
				end
			end
		end
	end

	return { leader }
end


local function buildEntrySnapshots(members: { Player }): ({ any }?, string?)
	if not playerDataService or type(playerDataService.GetData) ~= "function" then
		return nil, "PlayerDataService.GetData is unavailable."
	end

	local snapshots = {}
	for _, member in ipairs(members) do
		local data = playerDataService.GetData(member)
		if type(data) ~= "table" then
			return nil, string.format("Player data unavailable for %s.", member.Name)
		end
		table.insert(snapshots, {
			UserId = member.UserId,
			Level = data.Level,
			SelectedRole = data.SelectedRole or data.Role,
		})
	end
	return snapshots, nil
end

local function buildObjectives(objectiveIds: { string }?): { [string]: boolean }
	local objectives = {}
	for _, objectiveId in ipairs(objectiveIds or {}) do
		objectives[objectiveId] = false
	end
	return objectives
end

local function applyDungeonProgress(run: RunData)
	if not playerDataService then
		return
	end
	for _, member in ipairs(run.members) do
		safeCall("PlayerDataService.UpdateData", function()
			if type(playerDataService.UpdateDungeonProgress) == "function" then
				playerDataService.UpdateDungeonProgress(member, run.dungeonId, run.difficulty)
			elseif type(playerDataService.UpdateData) == "function" then
				playerDataService.UpdateData(member, function(data)
					data.DungeonProgress = data.DungeonProgress or {}
					local dungeonProgress = data.DungeonProgress[run.dungeonId]
					if type(dungeonProgress) ~= "table" then
						dungeonProgress = {}
						data.DungeonProgress[run.dungeonId] = dungeonProgress
					end
					local difficultyProgress = dungeonProgress[run.difficulty]
					if type(difficultyProgress) ~= "table" then
						difficultyProgress = { completions = 0, bestTime = nil, lastCompletedAt = nil }
						dungeonProgress[run.difficulty] = difficultyProgress
					end
					difficultyProgress.completions = (difficultyProgress.completions or 0) + 1
					difficultyProgress.lastCompletedAt = os.time()
					if run.startedAt then
						local elapsed = math.max(0, os.time() - run.startedAt)
						if difficultyProgress.bestTime == nil or elapsed < difficultyProgress.bestTime then
							difficultyProgress.bestTime = elapsed
						end
					end
				end)
			end
		end)
	end
end

local function notifyQuestExplore(run: RunData)
	if not questService or type(questService.NotifyExplore) ~= "function" then
		return
	end
	for _, member in ipairs(run.members) do
		safeCall("QuestService.NotifyExplore", function()
			questService.NotifyExplore(member, run.dungeonId)
		end)
	end
end

local function grantRewards(run: RunData)
	if not inventoryService or type(inventoryService.AddItem) ~= "function" then
		return
	end
	local rewards = DungeonValidator.GetRewards(run.dungeonId, run.difficulty)
	if type(rewards) ~= "table" then
		return
	end
	for _, member in ipairs(run.members) do
		for _, reward in ipairs(rewards) do
			local itemId = reward.itemId or reward.ItemId
			local amount = reward.amount or reward.quantity or reward.Amount or 1
			if type(itemId) == "string" and type(amount) == "number" and amount > 0 then
				safeCall("InventoryService.AddItem", function()
					inventoryService.AddItem(member, itemId, amount)
				end)
			end
		end
		-- Phase 5: grant AMP based on dungeon difficulty
		if magicTierService then
			local difficultyAMP = ({ Normal = 250, Heroic = 750, Mythic = 2000 })[run.difficulty] or 250
			pcall(magicTierService.AddAMP, member, difficultyAMP, "DungeonClear")
		end
	end
end

function DungeonService.Init(newPlayerDataService: any, newPartyService: any, newQuestService: any, newInventoryService: any, newMagicTierService: any)
	if initialized then
		warn("[DungeonService] Init called more than once; ignoring duplicate call.")
		return
	end
	assert(newPlayerDataService, "DungeonService.Init requires PlayerDataService.")
	assert(newPartyService, "DungeonService.Init requires PartyService.")
	assert(newQuestService, "DungeonService.Init requires QuestService.")
	assert(newInventoryService, "DungeonService.Init requires InventoryService.")

	playerDataService = newPlayerDataService
	partyService = newPartyService
	questService = newQuestService
	inventoryService = newInventoryService
	magicTierService = newMagicTierService  -- Phase 5 (optional)
	initialized = true

	Players.PlayerRemoving:Connect(function(player)
		if playerRunIndex[player.UserId] then
			DungeonService.AbandonRun(player)
		end
	end)

	print("[DungeonService] Initialized.")
end

function DungeonService.CreateRun(leaderPlayer: Player, dungeonId: string, difficulty: string): (string?, string?)
	assert(typeof(leaderPlayer) == "Instance" and leaderPlayer:IsA("Player"), "DungeonService.CreateRun requires leaderPlayer to be a Player.")
	assert(type(dungeonId) == "string" and dungeonId ~= "", "DungeonService.CreateRun requires dungeonId.")
	assert(type(difficulty) == "string" and difficulty ~= "", "DungeonService.CreateRun requires difficulty.")

	if playerRunIndex[leaderPlayer.UserId] then
		return nil, "Leader is already in a dungeon run."
	end

	local members = getPartyMembers(leaderPlayer)
	for _, member in ipairs(members) do
		if playerRunIndex[member.UserId] then
			return nil, string.format("Party member %s is already in a dungeon run.", member.Name)
		end
	end

	local snapshots, snapshotError = buildEntrySnapshots(members)
	if not snapshots then
		return nil, snapshotError or "Unable to build dungeon entry snapshots."
	end

	local entryValidation = DungeonValidator.CanEnterDungeon(snapshots, dungeonId, difficulty)
	if not entryValidation.success then
		return nil, entryValidation.reason or "Dungeon entry validation failed."
	end

	local validation = DungeonValidator.ValidateRun({
		dungeonId = dungeonId,
		difficulty = difficulty,
		members = members,
		leader = leaderPlayer,
	})
	if not validation.success then
		return nil, validation.reason or "Dungeon validation failed."
	end

	local runId = generateRunId()
	local run: RunData = {
		runId = runId,
		dungeonId = dungeonId,
		difficulty = difficulty,
		members = members,
		leaderUserId = leaderPlayer.UserId,
		status = "Waiting",
		startedAt = nil,
		objectives = buildObjectives(validation.objectives),
		failReason = nil,
	}
	runs[runId] = run
	indexMembers(runId, members)

	return runId, nil
end

function DungeonService.StartRun(runId: string): (boolean, string?)
	local run = runs[runId]
	if not run then
		return false, "Run not found: " .. tostring(runId)
	end
	if run.status ~= "Waiting" then
		return false, string.format("Run %s cannot be started (status=%s).", runId, run.status)
	end
	run.status = "Active"
	run.startedAt = os.time()
	return true, nil
end

function DungeonService.CompleteObjective(runId: string, objectiveId: string): (boolean, string?)
	local run = runs[runId]
	if not run then
		return false, "Run not found: " .. tostring(runId)
	end
	if run.status ~= "Active" then
		return false, string.format("Run %s is not active (status=%s).", runId, run.status)
	end
	if run.objectives[objectiveId] == nil then
		return false, string.format("Objective '%s' is not registered for run %s.", tostring(objectiveId), runId)
	end
	if run.objectives[objectiveId] then
		return false, string.format("Objective '%s' is already completed.", tostring(objectiveId))
	end
	run.objectives[objectiveId] = true
	return true, nil
end

function DungeonService.CompleteRun(runId: string): (boolean, string?)
	local run = runs[runId]
	if not run then
		return false, "Run not found: " .. tostring(runId)
	end
	if run.status ~= "Active" then
		return false, string.format("Run %s cannot be completed (status=%s).", runId, run.status)
	end

	run.status = "Completed"
	applyDungeonProgress(run)
	notifyQuestExplore(run)
	grantRewards(run)
	deindexMembers(run.members)
	scheduleEviction(runId, run)
	return true, nil
end

function DungeonService.FailRun(runId: string, reason: string?): (boolean, string?)
	local run = runs[runId]
	if not run then
		return false, "Run not found: " .. tostring(runId)
	end
	if run.status == "Completed" or run.status == "Failed" then
		return false, string.format("Run %s is already terminal (status=%s).", runId, run.status)
	end
	run.status = "Failed"
	run.failReason = reason or "Unknown reason"
	deindexMembers(run.members)
	scheduleEviction(runId, run)
	return true, nil
end

function DungeonService.GetRun(runId: string): RunData?
	local run = runs[runId]
	return if run then snapshotRun(run) else nil
end

function DungeonService.GetPlayerRun(player: Player): RunData?
	assert(typeof(player) == "Instance" and player:IsA("Player"), "DungeonService.GetPlayerRun requires a Player.")
	local runId = playerRunIndex[player.UserId]
	return if runId then DungeonService.GetRun(runId) else nil
end

function DungeonService.AbandonRun(player: Player): (boolean, string?)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "DungeonService.AbandonRun requires a Player.")
	local runId = playerRunIndex[player.UserId]
	if not runId then
		return false, "Player is not in any dungeon run."
	end
	local run = runs[runId]
	if not run then
		playerRunIndex[player.UserId] = nil
		return false, "Run record missing; stale index cleaned up."
	end
	if run.status == "Completed" or run.status == "Failed" then
		playerRunIndex[player.UserId] = nil
		return true, nil
	end
	if player.UserId == run.leaderUserId then
		return DungeonService.FailRun(runId, string.format("Leader (%s) abandoned the run.", player.Name))
	end

	playerRunIndex[player.UserId] = nil
	for index, member in ipairs(run.members) do
		if member.UserId == player.UserId then
			table.remove(run.members, index)
			break
		end
	end
	if #run.members == 0 then
		return DungeonService.FailRun(runId, "All members left the dungeon.")
	end
	return true, nil
end

function DungeonService._GetState()
	return {
		runs = runs,
		playerRunIndex = playerRunIndex,
		initialized = initialized,
	}
end

return DungeonService
