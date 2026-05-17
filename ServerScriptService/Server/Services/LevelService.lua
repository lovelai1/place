--!strict
-- LevelService — canonical XP/level-up authority for GhostyRPG.
-- Replaces direct data.Exp mutations: always call LevelService.AddExp(player, amount).
--
-- Formula: expToNextLevel(level) = floor(100 * level ^ 1.55)
--   L1→2  =   100 xp    L10→11 = 1 393 xp
--   L20→21 = 4 179 xp   L30→31 = 8 103 xp
--   L59→60 = 76 308 xp  (MaxLevel = 60, from StatFormulas)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerRemotes = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("PlayerRemotes")
)

local LevelService = {}

local MAX_LEVEL = 60

local playerDataService : any = nil
local statsService      : any = nil
local characterService  : any = nil
local magicTierService  : any = nil  -- Phase 5: AMP rewards on level-up
local initialized            = false

-- ── helpers ───────────────────────────────────────────────────────────────

local function expToNextLevel(level: number): number
	if level >= MAX_LEVEL then return math.huge end
	return math.floor(100 * (level ^ 1.55))
end

local function assertInit()
	assert(initialized, "[LevelService] Call Init() before use.")
end

-- ── public API ────────────────────────────────────────────────────────────

--- Canonical entry-point for all XP grants.
--- Handles multi-level-ups in a single call.
function LevelService.AddExp(player: Player, amount: number)
	assertInit()
	if type(amount) ~= "number" or amount <= 0 then return end

	local data = playerDataService.GetData(player)
	if not data then return end

	data.Exp = (data.Exp or 0) + math.floor(amount)

	-- Level-up loop
	local leveled = false
	while (data.Level or 1) < MAX_LEVEL do
		local level    = data.Level or 1
		local needed   = expToNextLevel(level)
		if data.Exp < needed then break end

		data.Exp   = data.Exp - needed
		data.Level = level + 1
		leveled    = true

		-- Phase 5: grant AMP for each level gained
		if magicTierService then
			pcall(magicTierService.AddAMP, player, (data.Level) * 15, "LevelUp")
		end

		-- Notify client immediately for each level
		-- Keys match HudUI: payload.level, payload.exp
		PlayerRemotes.GetEvent("LevelUp"):FireClient(player, {
			level = data.Level,
			exp   = data.Exp,
		})
	end

	-- Cap exp at current threshold when at max level
	if (data.Level or 1) >= MAX_LEVEL then
		data.Exp = 0
	end

	if leveled then
		-- Recalculate stats and push to client
		if statsService then
			statsService.Recalculate(player)
		end
		if characterService then
			pcall(characterService.SyncToClient, player)
		end
	end

	playerDataService.ScheduleSave(player)
end

--- Returns how much XP is needed to reach the next level.
function LevelService.ExpToNextLevel(level: number): number
	return expToNextLevel(level)
end

function LevelService.GetMaxLevel(): number
	return MAX_LEVEL
end

function LevelService.Init(
	newPlayerDataService : any,
	newStatsService      : any,
	newCharacterService  : any,
	newMagicTierService  : any   -- Phase 5: optional, injected after MagicTierService.Init
)
	if initialized then
		warn("[LevelService] Init called more than once; ignoring.")
		return
	end
	assert(newPlayerDataService, "[LevelService] requires PlayerDataService")
	assert(newStatsService,      "[LevelService] requires StatsService")

	playerDataService = newPlayerDataService
	statsService      = newStatsService
	characterService  = newCharacterService   -- may be nil early in boot
	magicTierService  = newMagicTierService   -- Phase 5
	initialized       = true
	print("[LevelService] Initialized.")
end

return LevelService
