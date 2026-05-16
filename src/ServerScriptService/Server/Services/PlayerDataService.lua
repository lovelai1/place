--!strict
-- Server-only player profile manager for GhostyRPG.
-- Owns DataStore access and exposes the GetData/ScheduleSave interface used by QuestService.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("PlayerDataConfig"))

local DATASTORE_NAME = "GhostyRPG_PlayerData_v1"
local CURRENT_VERSION = PlayerDataConfig.CURRENT_VERSION
local SAVE_DEBOUNCE_SECONDS = 30
local MAX_SAVE_RETRIES = 3

local PlayerDataService = {}

local dataStore: GlobalDataStore? = nil
local initialized = false
local profiles: { [Player]: any } = {}
local loading: { [Player]: boolean } = {}
local pendingSaves: { [Player]: thread } = {}

local function getKey(player: Player): string
	return string.format("player_%d", player.UserId)
end

local function migrate(data: { [any]: any }): { [any]: any }
	local version = data.Version or data.version or 0

	if data.version ~= nil and data.Version == nil then
		data.Version = data.version
		data.version = nil
	end

	if data.level ~= nil and data.Level == nil then data.Level = data.level end
	if data.exp ~= nil and data.Exp == nil then data.Exp = data.exp end
	if data.gold ~= nil and data.Gold == nil then data.Gold = data.gold end
	if data.inventory ~= nil and data.Inventory == nil then data.Inventory = data.inventory end
	if data.activeQuests ~= nil and data.ActiveQuests == nil then data.ActiveQuests = data.activeQuests end
	if data.completedQuests ~= nil and data.CompletedQuests == nil then data.CompletedQuests = data.completedQuests end

	if version < CURRENT_VERSION then
		-- Future schema migrations go here.
	end

	data.Version = CURRENT_VERSION
	return data
end

local function safeGet(key: string): (boolean, any)
	if not dataStore then
		return false, nil
	end

	local ok, result = pcall(function()
		return dataStore:GetAsync(key)
	end)
	if not ok then
		warn(string.format("[PlayerDataService] GetAsync failed for %s: %s", key, tostring(result)))
	end
	return ok, if ok then result else nil
end

local function safeUpdate(key: string, snapshot: any): boolean
	if not dataStore then
		return false
	end

	local lastError = nil
	for attempt = 1, MAX_SAVE_RETRIES do
		local ok, result = pcall(function()
			return dataStore:UpdateAsync(key, function(_oldValue)
				return snapshot
			end)
		end)

		if ok then
			return true
		end

		lastError = result
		warn(string.format("[PlayerDataService] UpdateAsync attempt %d/%d failed for %s: %s", attempt, MAX_SAVE_RETRIES, key, tostring(lastError)))
		if attempt < MAX_SAVE_RETRIES then
			task.wait(2 ^ attempt)
		end
	end

	return false
end

function PlayerDataService.Init()
	if initialized then
		warn("[PlayerDataService] Init called more than once; ignoring duplicate call.")
		return
	end

	initialized = true
	local ok, storeOrError = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)

	if ok then
		dataStore = storeOrError
		print("[PlayerDataService] DataStore acquired.")
	else
		warn(string.format("[PlayerDataService] DataStore unavailable; using session-only data. %s", tostring(storeOrError)))
	end
end

function PlayerDataService.LoadPlayer(player: Player)
	if profiles[player] then
		warn(string.format("[PlayerDataService] %s is already loaded.", player.Name))
		return
	end
	if loading[player] then
		warn(string.format("[PlayerDataService] %s is already loading.", player.Name))
		return
	end

	loading[player] = true
	local loadedData = nil
	local ok, rawData = safeGet(getKey(player))
	if ok and rawData ~= nil then
		if type(rawData) == "table" then
			loadedData = migrate(rawData)
		else
			warn(string.format("[PlayerDataService] Corrupt non-table data for %s; using defaults.", player.Name))
		end
	end

	if loadedData == nil then
		loadedData = PlayerDataConfig.DeepCopyDefault()
	else
		PlayerDataConfig.Reconcile(loadedData, PlayerDataConfig.DeepCopyDefault())
	end

	-- Cooldowns are session-transient combat state and should never resume from a persisted save.
	loadedData.AbilityCooldowns = {}

	if not player.Parent then
		loading[player] = nil
		return
	end

	profiles[player] = loadedData
	loading[player] = nil
	print(string.format("[PlayerDataService] Loaded %s at level %d.", player.Name, loadedData.Level or 1))
end

function PlayerDataService.SavePlayer(player: Player): boolean
	local data = profiles[player]
	if not data then
		warn(string.format("[PlayerDataService] SavePlayer called for unloaded player %s.", player.Name))
		return false
	end

	data.Version = CURRENT_VERSION
	local snapshot = PlayerDataConfig.DeepCopy(data)
	-- Ability cooldowns are transient combat state; keep persisted saves clean.
	snapshot.AbilityCooldowns = {}
	local success = safeUpdate(getKey(player), snapshot)
	if success then
		print(string.format("[PlayerDataService] Saved %s.", player.Name))
	else
		warn(string.format("[PlayerDataService] Failed to save %s.", player.Name))
	end
	return success
end

function PlayerDataService.ScheduleSave(player: Player)
	if pendingSaves[player] then
		return
	end

	pendingSaves[player] = task.delay(SAVE_DEBOUNCE_SECONDS, function()
		pendingSaves[player] = nil
		if profiles[player] then
			PlayerDataService.SavePlayer(player)
		end
	end)
end

function PlayerDataService.GetData(player: Player): any?
	return profiles[player]
end

function PlayerDataService.UpdateData(player: Player, mutator: (any) -> ())
	local data = profiles[player]
	if not data then
		warn(string.format("[PlayerDataService] UpdateData called for unloaded player %s.", player.Name))
		return
	end

	mutator(data)
	PlayerDataService.ScheduleSave(player)
end

function PlayerDataService.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function PlayerDataService.AddExp(player: Player, amount: number): boolean
	local data = profiles[player]
	if not data then
		warn(string.format("[PlayerDataService] AddExp called for unloaded player %s.", player.Name))
		return false
	end
	if type(amount) ~= "number" or amount <= 0 then
		return false
	end
	data.Exp = (data.Exp or 0) + math.floor(amount)
	PlayerDataService.ScheduleSave(player)
	return true
end

function PlayerDataService.AddGold(player: Player, amount: number): boolean
	local data = profiles[player]
	if not data then
		warn(string.format("[PlayerDataService] AddGold called for unloaded player %s.", player.Name))
		return false
	end
	if type(amount) ~= "number" or amount <= 0 then
		return false
	end
	data.Gold = (data.Gold or 0) + math.floor(amount)
	PlayerDataService.ScheduleSave(player)
	return true
end

function PlayerDataService.ReleasePlayer(player: Player)
	local pending = pendingSaves[player]
	if pending then
		task.cancel(pending)
		pendingSaves[player] = nil
	end

	if profiles[player] then
		PlayerDataService.SavePlayer(player)
	end

	profiles[player] = nil
	loading[player] = nil
	pendingSaves[player] = nil
	print(string.format("[PlayerDataService] Released %s.", player.Name))
end

return PlayerDataService
