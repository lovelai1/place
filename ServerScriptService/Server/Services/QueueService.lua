--!strict
-- Server-authoritative dungeon queue and ready-check flow for the GhostyRPG MVP.
-- No remotes here: ServerHandlers owns the network boundary.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))
local RoleConfig = require(Shared:WaitForChild("Config"):WaitForChild("RoleConfig"))
local DungeonConfig = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Config"):WaitForChild("DungeonConfig"))

local QueueService = {}

QueueService.QueueUpdated = Signal.new()
QueueService.PartyFormed = Signal.new()
QueueService.ReadyUpdated = Signal.new()
QueueService.RunStarted = Signal.new()
QueueService.QueueFailed = Signal.new()

type Result = {
	ok: boolean,
	code: string,
	message: string,
	data: any?,
}

type QueueEntry = {
	player: Player,
	dungeonId: string,
	difficulty: string,
	role: string,
	joinedAt: number,
}

type FormedParty = {
	partyId: string,
	dungeonId: string,
	difficulty: string,
	leader: Player,
	members: { Player },
	ready: { [number]: boolean },
	createdAt: number,
}

local DEFAULT_DIFFICULTY = "Normal"

local playerDataService: any = nil
local partyService: any = nil
local dungeonService: any = nil
local initialized = false

local queues: { [string]: { QueueEntry } } = {}
local playerQueue: { [Player]: string } = {}
local formedParties: { [string]: FormedParty } = {}
local playerFormedParty: { [Player]: string } = {}

local function makeResult(ok: boolean, code: string, message: string, data: any?): Result
	return { ok = ok, code = code, message = message, data = data }
end

local function okResult(message: string, data: any?): Result
	return makeResult(true, "OK", message, data)
end

local function failResult(code: string, message: string, data: any?): Result
	return makeResult(false, code, message, data)
end

local function assertInitialized()
	assert(initialized, "QueueService.Init() must be called before use.")
end

local function queueKey(dungeonId: string, difficulty: string): string
	return dungeonId .. "::" .. difficulty
end

local function parseQueueKey(key: string): (string, string)
	local splitAt = string.find(key, "::", 1, true)
	if not splitAt then
		return key, DEFAULT_DIFFICULTY
	end
	return string.sub(key, 1, splitAt - 1), string.sub(key, splitAt + 2)
end

local function isDifficultyAvailable(dungeon: any, difficulty: string): boolean
	if type(dungeon) ~= "table" or type(dungeon.difficulties) ~= "table" then
		return false
	end
	for _, available in ipairs(dungeon.difficulties) do
		if available == difficulty then
			return true
		end
	end
	return false
end

local function getDungeonOrError(dungeonId: any, difficulty: any): (any?, string?, string?)
	if type(dungeonId) ~= "string" or dungeonId == "" then
		return nil, nil, "INVALID_DUNGEON"
	end
	local normalizedDifficulty = if type(difficulty) == "string" and difficulty ~= "" then difficulty else DEFAULT_DIFFICULTY
	local dungeon = DungeonConfig.GetDungeon(dungeonId)
	if type(dungeon) ~= "table" then
		return nil, nil, "INVALID_DUNGEON"
	end
	if not isDifficultyAvailable(dungeon, normalizedDifficulty) then
		return nil, nil, "INVALID_DIFFICULTY"
	end
	return dungeon, normalizedDifficulty, nil
end

local function getPlayerData(player: Player): any?
	if not playerDataService or type(playerDataService.GetData) ~= "function" then
		return nil
	end
	return playerDataService.GetData(player)
end

local function getPlayerRole(player: Player): string?
	local data = getPlayerData(player)
	if type(data) ~= "table" then
		return nil
	end
	local role = data.SelectedRole or data.Role
	if type(role) ~= "string" or role == "" then
		return nil
	end
	if RoleConfig[role] == nil then
		return nil
	end
	return role
end

local function serializeMember(player: Player, readyMap: { [number]: boolean }?): { [string]: any }
	return {
		userId = player.UserId,
		name = player.Name,
		displayName = player.DisplayName,
		role = getPlayerRole(player) or "Unknown",
		ready = if readyMap then readyMap[player.UserId] == true else false,
	}
end

local function serializeMembers(members: { Player }, readyMap: { [number]: boolean }?): { any }
	local result = {}
	for _, member in ipairs(members) do
		table.insert(result, serializeMember(member, readyMap))
	end
	return result
end

local function serializeParty(party: FormedParty, state: string): { [string]: any }
	return {
		state = state,
		partyId = party.partyId,
		dungeonId = party.dungeonId,
		difficulty = party.difficulty,
		leaderUserId = party.leader.UserId,
		members = serializeMembers(party.members, party.ready),
		readyCount = QueueService.GetReadyCount(party.partyId),
		requiredReady = #party.members,
	}
end

local function removeQueuedPlayer(player: Player): (QueueEntry?, string?)
	local key = playerQueue[player]
	if not key then
		return nil, nil
	end
	local queue = queues[key]
	playerQueue[player] = nil
	if not queue then
		return nil, key
	end
	for index, entry in ipairs(queue) do
		if entry.player == player then
			table.remove(queue, index)
			return entry, key
		end
	end
	return nil, key
end

local function queueSnapshot(player: Player, key: string, state: string): { [string]: any }
	local dungeonId, difficulty = parseQueueKey(key)
	local queue = queues[key] or {}
	return {
		state = state,
		dungeonId = dungeonId,
		difficulty = difficulty,
		queuedCount = #queue,
		playerUserId = player.UserId,
	}
end

local function cleanupFormedParty(partyId: string, disband: boolean)
	local party = formedParties[partyId]
	if not party then
		return
	end
	for _, member in ipairs(party.members) do
		playerFormedParty[member] = nil
	end
	formedParties[partyId] = nil
	if disband and partyService and type(partyService.DisbandParty) == "function" then
		local ok, err = pcall(function()
			partyService.DisbandParty(partyId)
		end)
		if not ok then
			warn("[QueueService] Failed to disband party " .. partyId .. ": " .. tostring(err))
		end
	end
end

local function emitQueueUpdate(player: Player, payload: { [string]: any })
	QueueService.QueueUpdated:Fire({ player }, payload)
end

local function emitPartyFailure(party: FormedParty, code: string, message: string)
	local payload = serializeParty(party, "Failed")
	payload.code = code
	payload.message = message
	QueueService.QueueFailed:Fire(party.members, payload)
end

local function getQueueRoleRules(dungeonId: string): ({ [string]: number }, { [string]: number }, number)
	local dungeon = DungeonConfig.GetDungeon(dungeonId)
	local groupSize = if type(dungeon) == "table" and type(dungeon.maxPlayers) == "number"
		then dungeon.maxPlayers
		else DungeonConfig.Defaults.MaxPlayers
	local requiredRoles = DungeonConfig.GetRequiredRoles(dungeonId)

	local minimumRoles = if type(DungeonConfig.GetQueueRoleMinimums) == "function"
		then DungeonConfig.GetQueueRoleMinimums(dungeonId)
		elseif type(dungeon) == "table" and type(dungeon.queueRoleMinimums) == "table"
		then dungeon.queueRoleMinimums
		else requiredRoles
	local maximumRoles = if type(DungeonConfig.GetQueueRoleMaximums) == "function"
		then DungeonConfig.GetQueueRoleMaximums(dungeonId)
		elseif type(dungeon) == "table" and type(dungeon.queueRoleMaximums) == "table"
		then dungeon.queueRoleMaximums
		else {
			Tank = 2,
			Healer = 2,
			DPS = groupSize,
		}

	return minimumRoles, maximumRoles, groupSize
end

local function chooseEntries(queue: { QueueEntry }, minimumRoles: { [string]: number }, maximumRoles: { [string]: number }, groupSize: number): { QueueEntry }?
	local selected: { QueueEntry } = {}
	local used: { [QueueEntry]: boolean } = {}
	local roleCounts: { [string]: number } = {}

	for role, requiredCount in pairs(minimumRoles) do
		local foundForRole = 0
		for _, entry in ipairs(queue) do
			if not used[entry] and entry.role == role then
				table.insert(selected, entry)
				used[entry] = true
				roleCounts[entry.role] = (roleCounts[entry.role] or 0) + 1
				foundForRole += 1
				if foundForRole >= requiredCount then
					break
				end
			end
		end
		if foundForRole < requiredCount then
			return nil
		end
	end

	for _, entry in ipairs(queue) do
		if #selected >= groupSize then
			break
		end
		if not used[entry] then
			local current = roleCounts[entry.role] or 0
			local maxAllowed = maximumRoles[entry.role]
			if maxAllowed == nil or maxAllowed == 0 then
				maxAllowed = math.huge
			end
			if current < maxAllowed then
				table.insert(selected, entry)
				used[entry] = true
				roleCounts[entry.role] = current + 1
			end
		end
	end

	if #selected < groupSize then
		return nil
	end

	return selected
end

local function removeSelectedFromQueue(key: string, selected: { QueueEntry })
	local queue = queues[key]
	if not queue then
		return
	end
	local selectedSet: { [QueueEntry]: boolean } = {}
	for _, entry in ipairs(selected) do
		selectedSet[entry] = true
		playerQueue[entry.player] = nil
	end
	for index = #queue, 1, -1 do
		if selectedSet[queue[index]] then
			table.remove(queue, index)
		end
	end
end

local function tryFormParty(key: string): FormedParty?
	local queue = queues[key]
	if not queue or #queue == 0 then
		return nil
	end

	local dungeonId, difficulty = parseQueueKey(key)
	local minimumRoles, maximumRoles, groupSize = getQueueRoleRules(dungeonId)
	if #queue < groupSize then
		return nil
	end
	local selected = chooseEntries(queue, minimumRoles, maximumRoles, groupSize)
	if not selected then
		return nil
	end

	removeSelectedFromQueue(key, selected)

	local members: { Player } = {}
	for _, entry in ipairs(selected) do
		if entry.player.Parent == Players then
			table.insert(members, entry.player)
		end
	end
	if #members ~= #selected then
		for _, entry in ipairs(selected) do
			if entry.player.Parent == Players then
				table.insert(queue, entry)
				playerQueue[entry.player] = key
				emitQueueUpdate(entry.player, queueSnapshot(entry.player, key, "Queued"))
			end
		end
		return nil
	end

	local leader = members[1]
	local createResult = if partyService and type(partyService.CreatePartyFromMembers) == "function"
		then partyService.CreatePartyFromMembers(leader, members)
		else nil
	if type(createResult) ~= "table" or createResult.ok ~= true or type(createResult.data) ~= "table" or type(createResult.data.party) ~= "table" then
		local message = if type(createResult) == "table" and type(createResult.message) == "string" then createResult.message else "Party creation failed."
		for _, entry in ipairs(selected) do
			table.insert(queue, entry)
			playerQueue[entry.player] = key
			emitQueueUpdate(entry.player, queueSnapshot(entry.player, key, "Queued"))
		end
		warn("[QueueService] " .. message)
		return nil
	end

	local partyId = createResult.data.party.id
	local ready: { [number]: boolean } = {}
	for _, member in ipairs(members) do
		ready[member.UserId] = false
	end

	local formedParty: FormedParty = {
		partyId = partyId,
		dungeonId = dungeonId,
		difficulty = difficulty,
		leader = leader,
		members = members,
		ready = ready,
		createdAt = os.clock(),
	}
	formedParties[partyId] = formedParty
	for _, member in ipairs(members) do
		playerFormedParty[member] = partyId
	end

	QueueService.PartyFormed:Fire(members, serializeParty(formedParty, "Formed"))
	tryFormParty(key)
	return formedParty
end

function QueueService.Init(newPlayerDataService: any, newPartyService: any, newDungeonService: any)
	if initialized then
		warn("[QueueService] Init called more than once; ignoring duplicate call.")
		return
	end
	assert(newPlayerDataService ~= nil, "QueueService.Init requires PlayerDataService.")
	assert(newPartyService ~= nil, "QueueService.Init requires PartyService.")
	assert(newDungeonService ~= nil, "QueueService.Init requires DungeonService.")

	playerDataService = newPlayerDataService
	partyService = newPartyService
	dungeonService = newDungeonService
	initialized = true

	Players.PlayerRemoving:Connect(function(player)
		QueueService.LeaveQueue(player)
	end)

	print("[QueueService] Initialized.")
end

function QueueService.JoinQueue(player: Player, dungeonId: string, difficulty: string?): Result
	assertInitialized()
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return failResult("INVALID_PLAYER", "Expected a Player.", nil)
	end
	local _dungeon, normalizedDifficulty, dungeonError = getDungeonOrError(dungeonId, difficulty)
	if dungeonError then
		return failResult(dungeonError, "Invalid dungeon queue request.", nil)
	end
	if playerQueue[player] then
		return failResult("ALREADY_QUEUED", "You are already queued.", nil)
	end
	if playerFormedParty[player] then
		return failResult("PARTY_PENDING", "Your party is already formed.", nil)
	end
	if partyService and type(partyService.GetParty) == "function" and partyService.GetParty(player) ~= nil then
		return failResult("IN_PARTY", "Leave your current party before using the solo dungeon queue.", nil)
	end
	if dungeonService and type(dungeonService.GetPlayerRun) == "function" then
		local run = dungeonService.GetPlayerRun(player)
		if type(run) == "table" and run.status ~= "Failed" and run.status ~= "Completed" then
			return failResult("IN_DUNGEON", "You are already in a dungeon run.", nil)
		end
	end
	local role = getPlayerRole(player)
	if not role then
		return failResult("NO_ROLE", "Choose a valid role before queueing.", nil)
	end

	local key = queueKey(dungeonId, normalizedDifficulty :: string)
	queues[key] = queues[key] or {}
	table.insert(queues[key], {
		player = player,
		dungeonId = dungeonId,
		difficulty = normalizedDifficulty :: string,
		role = role,
		joinedAt = os.clock(),
	})
	playerQueue[player] = key

	local payload = queueSnapshot(player, key, "Queued")
	emitQueueUpdate(player, payload)
	tryFormParty(key)
	return okResult("Queued for dungeon.", payload)
end

function QueueService.LeaveQueue(player: Player): Result
	assertInitialized()
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return failResult("INVALID_PLAYER", "Expected a Player.", nil)
	end

	local partyId = playerFormedParty[player]
	if partyId then
		local party = formedParties[partyId]
		if party then
			emitPartyFailure(party, "PARTY_CANCELLED", player.Name .. " left before the dungeon started.")
			cleanupFormedParty(partyId, true)
			return okResult("Pending party cancelled.", { state = "Cancelled", partyId = partyId })
		end
	end

	local _entry, key = removeQueuedPlayer(player)
	if not key then
		return failResult("NOT_QUEUED", "You are not queued.", nil)
	end

	local payload = queueSnapshot(player, key, "Idle")
	emitQueueUpdate(player, payload)
	return okResult("Left queue.", payload)
end

function QueueService.SetReady(player: Player, ready: boolean): Result
	assertInitialized()
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return failResult("INVALID_PLAYER", "Expected a Player.", nil)
	end
	local partyId = playerFormedParty[player]
	local party = if partyId then formedParties[partyId] else nil
	if not party then
		return failResult("NO_PENDING_PARTY", "You do not have a pending ready check.", nil)
	end

	party.ready[player.UserId] = ready == true
	local readyPayload = serializeParty(party, "ReadyCheck")
	QueueService.ReadyUpdated:Fire(party.members, readyPayload)

	if QueueService.GetReadyCount(partyId :: string) < #party.members then
		return okResult("Ready state updated.", readyPayload)
	end

	local runId, createError = dungeonService.CreateRun(party.leader, party.dungeonId, party.difficulty)
	if not runId then
		emitPartyFailure(party, "RUN_CREATE_FAILED", createError or "Dungeon run creation failed.")
		cleanupFormedParty(partyId :: string, true)
		return failResult("RUN_CREATE_FAILED", createError or "Dungeon run creation failed.", nil)
	end

	local started, startError = dungeonService.StartRun(runId)
	if not started then
		emitPartyFailure(party, "RUN_START_FAILED", startError or "Dungeon run start failed.")
		cleanupFormedParty(partyId :: string, true)
		return failResult("RUN_START_FAILED", startError or "Dungeon run start failed.", nil)
	end

	local startedPayload = serializeParty(party, "Active")
	startedPayload.runId = runId
	QueueService.RunStarted:Fire(party.members, startedPayload)
	cleanupFormedParty(partyId :: string, true)
	return okResult("Dungeon started.", startedPayload)
end

function QueueService.GetReadyCount(partyId: string): number
	local party = formedParties[partyId]
	if not party then
		return 0
	end
	local count = 0
	for _, member in ipairs(party.members) do
		if party.ready[member.UserId] == true then
			count += 1
		end
	end
	return count
end

function QueueService.GetPartyStatus(player: Player): any?
	assertInitialized()
	local partyId = playerFormedParty[player]
	local party = if partyId then formedParties[partyId] else nil
	if party then
		return serializeParty(party, "ReadyCheck")
	end
	if dungeonService and type(dungeonService.GetPlayerRun) == "function" then
		local run = dungeonService.GetPlayerRun(player)
		if type(run) == "table" then
			return {
				state = run.status,
				runId = run.runId,
				dungeonId = run.dungeonId,
				difficulty = run.difficulty,
			}
		end
	end
	return nil
end

function QueueService._GetState()
	return {
		queues = queues,
		playerQueue = playerQueue,
		formedParties = formedParties,
		playerFormedParty = playerFormedParty,
		initialized = initialized,
	}
end

return QueueService