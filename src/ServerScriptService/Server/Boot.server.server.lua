--!strict
-- Minimal GhostyRPG server boot. Owns service initialization order and player profile lifecycle.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Services = Server:WaitForChild("Services")
local Remotes = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
local Net = Server:WaitForChild("Net")

local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local StatsService = require(Services:WaitForChild("StatsService"))
local CombatService = require(Services:WaitForChild("CombatService"))
local ClassService = require(Services:WaitForChild("ClassService"))
local InventoryService = require(Services:WaitForChild("InventoryService"))
local ProfessionService = require(Services:WaitForChild("ProfessionService"))
local PartyService = require(Services:WaitForChild("PartyService"))
local DungeonService = require(Services:WaitForChild("DungeonService"))
local QueueService = require(Services:WaitForChild("QueueService"))
local LootService = require(Services:WaitForChild("LootService"))
local QuestService = require(Services:WaitForChild("QuestService"))
local MobService = require(Services:WaitForChild("MobService"))
local ClassRemotes = require(Remotes:WaitForChild("ClassRemotes"))
local InventoryRemotes = require(Remotes:WaitForChild("InventoryRemotes"))
local DungeonRemotes = require(Remotes:WaitForChild("DungeonRemotes"))
local ServerHandlers = require(Net:WaitForChild("ServerHandlers"))

PlayerDataService.Init()
StatsService.Init(PlayerDataService)
CombatService.Init(PlayerDataService, StatsService)
ClassService.Init(PlayerDataService, StatsService)
InventoryService.Init(PlayerDataService)
ProfessionService.Init(PlayerDataService, InventoryService)
PartyService.Init(PlayerDataService)
LootService.Init(InventoryService)
QuestService.Init(PlayerDataService, InventoryService)
DungeonService.Init(PlayerDataService, PartyService, QuestService, InventoryService)
QueueService.Init(PlayerDataService, PartyService, DungeonService)
MobService.Init(PlayerDataService, QuestService, InventoryService, LootService)
ClassRemotes.Ensure()
InventoryRemotes.Ensure()
DungeonRemotes.Ensure()
ServerHandlers.Init({
	PlayerDataService = PlayerDataService,
	ClassService = ClassService,
	QueueService = QueueService,
	DungeonService = DungeonService,
	CombatService = CombatService,
})

local function onPlayerAdded(player: Player)
	task.spawn(function()
		PlayerDataService.LoadPlayer(player)
		if PlayerDataService.IsLoaded(player) then
			StatsService.Recalculate(player)
		end
	end)
end

local function onPlayerRemoving(player: Player)
	PlayerDataService.ReleasePlayer(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerDataService.ReleasePlayer(player)
	end
end)

print("[GhostyRPG] Server boot complete.")
