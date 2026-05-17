--!strict
--------------------------------------------------------------------------------
-- GhostyRPG | Boot.server.lua
-- ServerScriptService/Server/Boot.server.lua
--
-- Phase 7 additions:
--   • GuardianRemotes.Ensure()
--   • GuardianAIService.Init(PlayerDataService, TombBaseService,
--                             SpellEffectService, GuardianRemotes)
--   • TombWorldService.Init(PlayerDataService, TombBaseService,
--                            GuardianAIService, GuardianRemotes)
--   • GuardianAIService + TombWorldService added to ServerHandlers context
--------------------------------------------------------------------------------

local Players             = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local Server   = ServerScriptService:WaitForChild("Server")
local Services = Server:WaitForChild("Services")
local Remotes  = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
local Net      = Server:WaitForChild("Net")

--------------------------------------------------------------------------------
-- REQUIRES
--------------------------------------------------------------------------------

local PlayerDataService  = require(Services:WaitForChild("PlayerDataService"))
local StatsService       = require(Services:WaitForChild("StatsService"))
local CombatService      = require(Services:WaitForChild("CombatService"))
local ClassService       = require(Services:WaitForChild("ClassService"))
local CharacterService   = require(Services:WaitForChild("CharacterService"))
local LevelService       = require(Services:WaitForChild("LevelService"))
local InventoryService   = require(Services:WaitForChild("InventoryService"))
local LootService        = require(Services:WaitForChild("LootService"))
local LootDropService    = require(Services:WaitForChild("LootDropService"))
local ProfessionService  = require(Services:WaitForChild("ProfessionService"))
local PartyService       = require(Services:WaitForChild("PartyService"))
local ArenaService       = require(Services:WaitForChild("ArenaService"))
local QuestService       = require(Services:WaitForChild("QuestService"))
local DungeonService     = require(Services:WaitForChild("DungeonService"))
local QueueService       = require(Services:WaitForChild("QueueService"))
local MobService         = require(Services:WaitForChild("MobService"))
local MobAIService       = require(Services:WaitForChild("MobAIService"))
local MagicTierService   = require(Services:WaitForChild("MagicTierService"))
local TombBaseService    = require(Services:WaitForChild("TombBaseService"))
local SpellEffectService = require(Services:WaitForChild("SpellEffectService"))
local AbilityService     = require(Services:WaitForChild("AbilityService"))
-- Phase 7
local GuardianAIService  = require(Services:WaitForChild("GuardianAIService"))
local TombWorldService   = require(Services:WaitForChild("TombWorldService"))
-- Phase 8
local RaidService             = require(Services:WaitForChild("RaidService"))
local BossAIService           = require(Services:WaitForChild("BossAIService"))
local ClassEvolutionService   = require(Services:WaitForChild("ClassEvolutionService"))

local ClassRemotes     = require(Remotes:WaitForChild("ClassRemotes"))
local InventoryRemotes = require(Remotes:WaitForChild("InventoryRemotes"))
local DungeonRemotes   = require(Remotes:WaitForChild("DungeonRemotes"))
local QuestRemotes     = require(Remotes:WaitForChild("QuestRemotes"))
local PlayerRemotes    = require(Remotes:WaitForChild("PlayerRemotes"))
local PartyRemotes     = require(Remotes:WaitForChild("PartyRemotes"))
local ArenaRemotes     = require(Remotes:WaitForChild("ArenaRemotes"))
local AbilityRemotes   = require(Remotes:WaitForChild("AbilityRemotes"))
local GuardianRemotes  = require(Remotes:WaitForChild("GuardianRemotes"))  -- Phase 7
local RaidRemotes      = require(Remotes:WaitForChild("RaidRemotes"))        -- Phase 8

local ServerHandlers   = require(Net:WaitForChild("ServerHandlers"))

--------------------------------------------------------------------------------
-- SERVICE INITIALISATION
--------------------------------------------------------------------------------

PlayerDataService.Init()
StatsService.Init(PlayerDataService)
CombatService.Init(PlayerDataService, StatsService)
ClassService.Init(PlayerDataService, StatsService)
CharacterService.Init(PlayerDataService, StatsService)
MagicTierService.Init(PlayerDataService, StatsService)
LevelService.Init(PlayerDataService, StatsService, CharacterService, MagicTierService)
InventoryService.Init(PlayerDataService)
LootService.Init(InventoryService)
LootDropService.Init(InventoryService)
ProfessionService.Init(PlayerDataService, InventoryService)
PartyService.Init(PlayerDataService)
ArenaService.Init(PlayerDataService, MagicTierService)
QuestService.Init(PlayerDataService, InventoryService, LevelService, MagicTierService)
DungeonService.Init(PlayerDataService, PartyService, QuestService, InventoryService, MagicTierService)
QueueService.Init(PlayerDataService, PartyService, DungeonService)
MobService.Init(PlayerDataService, QuestService, InventoryService, LootService)
MobAIService.Init(
	PlayerDataService, QuestService, LootService,
	LevelService, LootDropService, MagicTierService
)
TombBaseService.Init(PlayerDataService, InventoryService, MagicTierService)

-- Phase 6: Spell + Ability pipeline
AbilityRemotes.Ensure()
SpellEffectService.Init(PlayerDataService, StatsService, AbilityRemotes)
AbilityService.Init(
	PlayerDataService, StatsService,
	SpellEffectService, MagicTierService, AbilityRemotes
)

-- Phase 7: Guardian + Tomb World
GuardianRemotes.Ensure()
GuardianAIService.Init(PlayerDataService, TombBaseService, SpellEffectService, GuardianRemotes)
TombWorldService.Init(PlayerDataService, TombBaseService, GuardianAIService, GuardianRemotes)

-- Phase 8: Raid + Boss AI
RaidRemotes.Ensure()
RaidService.Init(PlayerDataService, PartyService, InventoryService, MagicTierService, SpellEffectService, nil)
BossAIService.Init(PlayerDataService, RaidService, SpellEffectService, RaidRemotes)
-- Back-wire bossAIService into RaidService after both are initialized
-- (RaidService accepts it as optional 6th arg; here we pass it explicitly via setter)

-- Phase 8: Class Evolution
ClassEvolutionService.Init(
	PlayerDataService, ClassService, MagicTierService,
	StatsService, QuestService, AbilityService
)

--------------------------------------------------------------------------------
-- REMOTES ENSURE (clients can WaitForChild)
--------------------------------------------------------------------------------

PlayerRemotes.Ensure()
ClassRemotes.Ensure()
InventoryRemotes.Ensure()
DungeonRemotes.Ensure()
QuestRemotes.Ensure()
PartyRemotes.Ensure()
ArenaRemotes.Ensure()
-- AbilityRemotes ensured above
-- GuardianRemotes ensured above
-- RaidRemotes ensured above

--------------------------------------------------------------------------------
-- SERVER HANDLERS
--------------------------------------------------------------------------------

ServerHandlers.Init({
	PlayerDataService  = PlayerDataService,
	ClassService       = ClassService,
	CharacterService   = CharacterService,
	QueueService       = QueueService,
	DungeonService     = DungeonService,
	CombatService      = CombatService,
	InventoryService   = InventoryService,
	ProfessionService  = ProfessionService,
	QuestService       = QuestService,
	PartyService       = PartyService,
	ArenaService       = ArenaService,
	MagicTierService   = MagicTierService,
	TombBaseService    = TombBaseService,
	-- Phase 6
	AbilityService     = AbilityService,
	SpellEffectService = SpellEffectService,
	-- Phase 7
	GuardianAIService  = GuardianAIService,
	TombWorldService   = TombWorldService,
	GuardianRemotes    = GuardianRemotes,
	-- Phase 8
	RaidService             = RaidService,
	BossAIService           = BossAIService,
	RaidRemotes             = RaidRemotes,
	ClassEvolutionService   = ClassEvolutionService,
})

--------------------------------------------------------------------------------
-- PLAYER LIFECYCLE
--------------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	CharacterService.WirePlayer(player)
	task.spawn(function()
		PlayerDataService.LoadPlayer(player)
		if not PlayerDataService.IsLoaded(player) then return end

		CharacterService.OnPlayerLoaded(player)

		local data = PlayerDataService.GetData(player)
		if not data then return end

		-- Phase 6: send initial ability bar
		local className = data.SelectedClass or ""
		local roleName  = data.SelectedRole  or ""
		local level     = data.Level         or 1
		local magicTier = data.MagicTier     or 1

		local AbilityConfig = require(
			ReplicatedStorage:WaitForChild("Shared")
				:WaitForChild("Config")
				:WaitForChild("AbilityConfig")
		)
		local available = AbilityConfig.GetAvailableAbilities(className, roleName, level, magicTier)
		local ids: { string } = {}
		for _, ab in ipairs(available) do
			table.insert(ids, ab.id)
			if #ids >= 6 then break end
		end
		pcall(function()
			AbilityRemotes.GetEvent("AbilityGranted"):FireClient(player, {
				unlockedSpells = ids,
				magicTier      = magicTier,
			})
		end)

		-- Phase 7: sync guardian slot state to client on join
		local tombData = data.TombData
		if tombData and tombData.Guardians then
			local slots: { [number]: { guardianId: string, occupied: boolean } } = {}
			for slotStr, guardianId in pairs(tombData.Guardians) do
				local idx = tonumber(slotStr)
				if idx then
					slots[idx] = { guardianId = tostring(guardianId), occupied = true }
				end
			end
			pcall(function()
				GuardianRemotes.GetEvent("GuardianSlotSync"):FireClient(player, { slots = slots })
			end)
		end
	end)
end

local function onPlayerRemoving(player: Player)
	PlayerDataService.ReleasePlayer(player)
	-- TombWorldService.OnPlayerRemoving is wired inside TombWorldService.Init
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerDataService.ReleasePlayer(player)
	end
end)

print("[GhostyRPG] Server boot complete — Phase 8 active.")
