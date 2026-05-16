--!strict
-- The only inbound RemoteEvent/RemoteFunction boundary for the GhostyRPG MVP layer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SharedRemotes = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
local ClassRemotes = require(SharedRemotes:WaitForChild("ClassRemotes"))
local DungeonRemotes = require(SharedRemotes:WaitForChild("DungeonRemotes"))
local ClassConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ClassConfig"))
local DungeonConfig = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Config"):WaitForChild("DungeonConfig"))

local ServerHandlers = {}

local initialized = false
local connections: { RBXScriptConnection } = {}

local defaultClassByRole = {
	Tank = "Warrior",
	Healer = "Priest",
	DPS = "Mage",
}

local function connect(signal: RBXScriptSignal, callback: (...any) -> ())
	table.insert(connections, signal:Connect(callback))
end

local function fireToPlayers(remote: RemoteEvent, players: { Player }, payload: any)
	for _, player in ipairs(players) do
		if player.Parent == Players then
			remote:FireClient(player, payload)
		end
	end
end

local function rejectAbility(player: Player, code: string, message: string)
	DungeonRemotes.GetEvent("AbilityRejected"):FireClient(player, {
		ok = false,
		code = code,
		message = message,
	})
end

local function getPlayerData(playerDataService: any, player: Player): any?
	if playerDataService and type(playerDataService.GetData) == "function" then
		return playerDataService.GetData(player)
	end
	return nil
end

local function classCanUseRole(className: string, roleName: string): boolean
	local classData = ClassConfig[className]
	if type(classData) ~= "table" or type(classData.AvailableRoles) ~= "table" then
		return false
	end
	for _, allowedRole in ipairs(classData.AvailableRoles) do
		if allowedRole == roleName then
			return true
		end
	end
	return false
end

local function ensureClassForRole(classService: any, playerDataService: any, player: Player, roleName: string): (boolean, string?)
	local data = getPlayerData(playerDataService, player)
	if type(data) ~= "table" then
		return false, "Player data is not loaded yet."
	end
	if type(data.SelectedClass) == "string" and data.SelectedClass ~= "" and classCanUseRole(data.SelectedClass, roleName) then
		return true, nil
	end
	local className = defaultClassByRole[roleName]
	if not className then
		return false, "No default class is mapped for role " .. tostring(roleName) .. "."
	end
	if type(data.SelectedClass) == "string" and data.SelectedClass ~= "" and data.SelectedClass ~= className then
		if type(data.Settings) ~= "table" then
			data.Settings = {}
		end
		local previousResetFlag = data.Settings.ResetClassAllowed
		data.Settings.ResetClassAllowed = true
		local switched, switchReason = classService.SelectClass(player, className)
		data.Settings.ResetClassAllowed = previousResetFlag
		if not switched then
			return false, switchReason or "Unable to switch class for that role."
		end
		return true, nil
	end
	local ok, reason = classService.SelectClass(player, className)
	if not ok then
		return false, reason or "Unable to select a default class."
	end
	return true, nil
end

local function serializeDungeonList(): { any }
	local list = {}
	for dungeonId, dungeon in pairs(DungeonConfig.Dungeons or {}) do
		table.insert(list, {
			id = dungeonId,
			name = dungeon.name or dungeon.displayName or dungeonId,
			minLevel = dungeon.minLevel or 1,
			maxPlayers = dungeon.maxPlayers or DungeonConfig.Defaults.MaxPlayers,
			difficulties = dungeon.difficulties or { "Normal" },
			timeLimit = dungeon.timeLimit or DungeonConfig.Defaults.TimeLimit,
		})
	end
	table.sort(list, function(a, b)
		if (a.minLevel or 0) ~= (b.minLevel or 0) then
			return (a.minLevel or 0) < (b.minLevel or 0)
		end
		return tostring(a.id) < tostring(b.id)
	end)
	return list
end

function ServerHandlers.Init(deps: { [string]: any })
	if initialized then
		warn("[ServerHandlers] Init called more than once; ignoring duplicate call.")
		return
	end

	local playerDataService = deps.PlayerDataService
	local classService = deps.ClassService
	local queueService = deps.QueueService
	local combatService = deps.CombatService

	assert(playerDataService, "ServerHandlers.Init requires PlayerDataService.")
	assert(classService, "ServerHandlers.Init requires ClassService.")
	assert(queueService, "ServerHandlers.Init requires QueueService.")
	assert(combatService, "ServerHandlers.Init requires CombatService.")

	connect(ClassRemotes.GetEvent("SelectClass").OnServerEvent, function(player: Player, className: any)
		if type(className) ~= "string" then
			ClassRemotes.GetEvent("ClassSelected"):FireClient(player, {
				ok = false,
				code = "INVALID_CLASS",
				message = "className must be a string.",
			})
			return
		end
		local ok, reason = classService.SelectClass(player, className)
		local message = reason
		if not message then
			message = if ok then "Class selected." else "Class selection failed."
		end
		ClassRemotes.GetEvent("ClassSelected"):FireClient(player, {
			ok = ok,
			code = if ok then "OK" else "CLASS_REJECTED",
			message = message,
			className = if ok then className else nil,
		})
	end)

	connect(ClassRemotes.GetEvent("SelectRole").OnServerEvent, function(player: Player, roleName: any)
		if type(roleName) ~= "string" then
			ClassRemotes.GetEvent("RoleSelected"):FireClient(player, {
				ok = false,
				code = "INVALID_ROLE",
				message = "roleName must be a string.",
			})
			return
		end

		local classOk, classReason = ensureClassForRole(classService, playerDataService, player, roleName)
		if not classOk then
			ClassRemotes.GetEvent("RoleSelected"):FireClient(player, {
				ok = false,
				code = "CLASS_REQUIRED",
				message = classReason or "Select a class before choosing a role.",
			})
			return
		end

		local ok, reason = classService.SelectRole(player, roleName)
		local message = reason
		if not message then
			message = if ok then "Role selected." else "Role selection failed."
		end
		ClassRemotes.GetEvent("RoleSelected"):FireClient(player, {
			ok = ok,
			code = if ok then "OK" else "ROLE_REJECTED",
			message = message,
			roleName = if ok then roleName else nil,
		})
	end)

	connect(DungeonRemotes.GetEvent("JoinQueue").OnServerEvent, function(player: Player, dungeonId: any, difficulty: any)
		local result = queueService.JoinQueue(player, dungeonId, difficulty)
		DungeonRemotes.GetEvent("QueueUpdated"):FireClient(player, result)
	end)

	connect(DungeonRemotes.GetEvent("LeaveQueue").OnServerEvent, function(player: Player)
		local result = queueService.LeaveQueue(player)
		DungeonRemotes.GetEvent("QueueUpdated"):FireClient(player, result)
	end)

	connect(DungeonRemotes.GetEvent("ReadyCheck").OnServerEvent, function(player: Player, ready: any)
		local result = queueService.SetReady(player, ready == true)
		if not result.ok then
			DungeonRemotes.GetEvent("ReadyUpdated"):FireClient(player, result)
		end
	end)

	connect(DungeonRemotes.GetEvent("UseAbility").OnServerEvent, function(player: Player, abilityId: any, targetUserId: any)
		if type(abilityId) ~= "string" or abilityId == "" then
			rejectAbility(player, "INVALID_ABILITY", "abilityId must be a non-empty string.")
			return
		end

		local targetContext = {}
		if type(targetUserId) == "number" then
			local targetPlayer = Players:GetPlayerByUserId(targetUserId)
			if targetPlayer then
				targetContext.targetPlayer = targetPlayer
			end
		end

		local result = combatService.UseAbility(player, abilityId, targetContext)
		if result.success then
			DungeonRemotes.GetEvent("CombatResult"):FireClient(player, {
				ok = true,
				abilityId = abilityId,
				amount = result.amount or 0,
			})
		else
			rejectAbility(player, "ABILITY_REJECTED", result.reason or "Ability rejected.")
		end
	end)

	connect(DungeonRemotes.GetEvent("LootAcknowledge").OnServerEvent, function(_player: Player)
		-- Reserved for a later persistent loot-claim workflow.
	end)

	DungeonRemotes.GetFunction("GetDungeonList").OnServerInvoke = function(_player: Player)
		return serializeDungeonList()
	end

	DungeonRemotes.GetFunction("GetPartyStatus").OnServerInvoke = function(player: Player)
		return queueService.GetPartyStatus(player)
	end

	table.insert(connections, queueService.PartyFormed:Connect(function(players: { Player }, payload: any)
		fireToPlayers(DungeonRemotes.GetEvent("PartyFormed"), players, payload)
	end))

	table.insert(connections, queueService.ReadyUpdated:Connect(function(players: { Player }, payload: any)
		fireToPlayers(DungeonRemotes.GetEvent("ReadyUpdated"), players, payload)
	end))

	table.insert(connections, queueService.RunStarted:Connect(function(players: { Player }, payload: any)
		fireToPlayers(DungeonRemotes.GetEvent("DungeonStateUpdate"), players, payload)
	end))

	table.insert(connections, queueService.QueueFailed:Connect(function(players: { Player }, payload: any)
		fireToPlayers(DungeonRemotes.GetEvent("DungeonFailed"), players, payload)
	end))

	initialized = true
	print("[ServerHandlers] Initialized.")
end

function ServerHandlers.Destroy()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
	initialized = false
end

return ServerHandlers