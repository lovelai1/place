--!strict
--------------------------------------------------------------------------------
-- GhostyRPG | RaidService.lua
-- ServerScriptService/Server/Services/RaidService.lua
--
-- Управляет рейд-инстансами: создание, слежение за участниками,
-- переход босса между фазами, таймер рейда, запись результата.
--
-- INIT:
--   RaidService.Init(playerDataService, partyService,
--                    inventoryService, magicTierService,
--                    spellEffectService, bossAIService)
--
-- PUBLIC API:
--   RaidService.CreateRaid(leader, raidId, difficulty)  → (raidRunId?, error?)
--   RaidService.StartRaid(raidRunId)                    → (ok, error?)
--   RaidService.OnBossDamaged(raidRunId, bossId, dmg)   → { died, phaseChanged, newPhase? }
--   RaidService.BossKilled(raidRunId, bossId)           → (ok, error?)
--   RaidService.CompleteRaid(raidRunId)                 → (ok, error?)
--   RaidService.FailRaid(raidRunId, reason?)            → (ok, error?)
--   RaidService.GetRaid(raidRunId)                      → RaidRun?
--   RaidService.GetPlayerRaid(player)                   → RaidRun?
--
-- SIGNALS:
--   RaidService.RaidStarted    :Fire(members, payload)
--   RaidService.RaidCompleted  :Fire(members, payload)
--   RaidService.RaidFailed     :Fire(members, payload)
--   RaidService.BossPhaseChanged:Fire(members, payload)
--   RaidService.BossDied       :Fire(members, payload)
--------------------------------------------------------------------------------

local Players             = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local Shared  = ReplicatedStorage:WaitForChild("Shared")
local Signal  = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))

local Server     = ServerScriptService:WaitForChild("Server")
local RaidConfig = require(Server:WaitForChild("Config"):WaitForChild("RaidConfig"))

local RaidService = {}

--------------------------------------------------------------------------------
-- SIGNALS
--------------------------------------------------------------------------------

RaidService.RaidStarted      = Signal.new()
RaidService.RaidCompleted    = Signal.new()
RaidService.RaidFailed       = Signal.new()
RaidService.BossPhaseChanged = Signal.new()
RaidService.BossDied         = Signal.new()

--------------------------------------------------------------------------------
-- TYPES
--------------------------------------------------------------------------------

type BossState = {
	bossId        : string,
	maxHealth     : number,
	currentHealth : number,
	currentPhase  : number,
	dead          : boolean,
}

type RaidRun = {
	raidRunId    : string,
	raidId       : string,
	difficulty   : string,
	members      : { Player },
	leaderUserId : number,
	status       : string,
	startedAt    : number?,
	endedAt      : number?,
	failReason   : string?,
	bossStates   : { [string]: BossState },
	killedBosses : { [string]: true },
	wipes        : number,
	timerThread  : thread?,
}

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local runs: { [string]: RaidRun }        = {}
local playerIndex: { [number]: string }  = {}

local playerDataService : any = nil
local partyService      : any = nil
local inventoryService  : any = nil
local magicTierService  : any = nil
local spellEffectService: any = nil
local bossAIService     : any = nil

local initialized = false
local runCounter  = 0

--------------------------------------------------------------------------------
-- PRIVATE HELPERS
--------------------------------------------------------------------------------

local function generateRunId(): string
	runCounter += 1
	return string.format("raid_%d_%d", os.time(), runCounter)
end

local function safeCall(label: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn(string.format("[RaidService] %s — pcall failed: %s", label, tostring(err)))
	end
end

local function indexMembers(raidRunId: string, members: { Player })
	for _, p in ipairs(members) do playerIndex[p.UserId] = raidRunId end
end

local function deindexMembers(members: { Player })
	for _, p in ipairs(members) do playerIndex[p.UserId] = nil end
end

local function diffHealthMult(difficulty: string): number
	local diff = RaidConfig.GetDifficulty(difficulty)
	if diff and type(diff.EnemyHealthMultiplier) == "number" then
		return diff.EnemyHealthMultiplier
	end
	return 1.0
end

local function buildBossStates(raidDef: any, difficulty: string): { [string]: BossState }
	local out: { [string]: BossState } = {}
	local mult = diffHealthMult(difficulty)
	if type(raidDef.bosses) ~= "table" then return out end
	for _, bossConf in ipairs(raidDef.bosses) do
		local hp = math.floor((bossConf.baseHealth or 100000) * mult)
		out[bossConf.id] = {
			bossId = bossConf.id, maxHealth = hp, currentHealth = hp,
			currentPhase = 1, dead = false,
		}
	end
	return out
end

local function applyRaidProgress(run: RaidRun)
	if not playerDataService then return end
	local elapsed = if run.startedAt
		then math.max(0, (run.endedAt or os.time()) - run.startedAt) else 0
	for _, member in ipairs(run.members) do
		safeCall("applyRaidProgress", function()
			local data = playerDataService.GetData(member)
			if not data then return end
			data.DungeonProgress = data.DungeonProgress or {}
			local rp = data.DungeonProgress[run.raidId]
			if type(rp) ~= "table" then rp = {}; data.DungeonProgress[run.raidId] = rp end
			local dp = rp[run.difficulty]
			if type(dp) ~= "table" then
				dp = { completions = 0, bestTime = nil, lastCompletedAt = nil, wipes = 0, totalWipes = 0 }
				rp[run.difficulty] = dp
			end
			dp.completions     = (dp.completions or 0) + 1
			dp.lastCompletedAt = os.time()
			dp.totalWipes      = (dp.totalWipes or 0) + run.wipes
			if elapsed > 0 and (dp.bestTime == nil or elapsed < dp.bestTime) then
				dp.bestTime = elapsed
			end
			playerDataService.ScheduleSave(member)
		end)
	end
end

local function grantRaidRewards(run: RaidRun)
	if not inventoryService then return end
	local raidDef = RaidConfig.GetRaid(run.raidId)
	if not raidDef then return end
	local lootPool: { string } = {}
	for _, bossConf in ipairs(raidDef.bosses or {}) do
		if run.killedBosses[bossConf.id] and type(bossConf.lootTable) == "table" then
			for _, itemId in ipairs(bossConf.lootTable) do
				table.insert(lootPool, itemId)
			end
		end
	end
	for _, member in ipairs(run.members) do
		if member.Parent ~= Players then continue end
		if #lootPool > 0 then
			local pick = lootPool[math.random(1, #lootPool)]
			safeCall("InventoryService.AddItem", function()
				inventoryService.AddItem(member, pick, 1)
			end)
		end
		if magicTierService then
			local ampReward = ({ LFR = 500, Normal = 1500, Heroic = 4000, Mythic = 10000 })[run.difficulty] or 1500
			pcall(magicTierService.AddAMP, member, ampReward, "RaidClear")
		end
	end
end

local function startTimer(raidRunId: string, seconds: number): thread
	return task.spawn(function()
		task.wait(seconds)
		local run = runs[raidRunId]
		if not run or run.status ~= "Active" then return end
		warn(string.format("[RaidService] Raid %s timed out after %ds.", raidRunId, seconds))
		RaidService.FailRaid(raidRunId, "TimeLimit")
	end)
end

--------------------------------------------------------------------------------
-- PUBLIC API — LIFECYCLE
--------------------------------------------------------------------------------

function RaidService.CreateRaid(leader: Player, raidId: string, difficulty: string): (string?, string?)
	assert(initialized, "[RaidService] Not initialized.")
	assert(typeof(leader) == "Instance" and leader:IsA("Player"), "leader must be a Player.")
	assert(type(raidId) == "string" and raidId ~= "", "raidId must be a non-empty string.")
	assert(type(difficulty) == "string" and difficulty ~= "", "difficulty must be a non-empty string.")

	if playerIndex[leader.UserId] then return nil, "Leader is already in a raid." end

	local raidDef = RaidConfig.GetRaid(raidId)
	if not raidDef then return nil, "Unknown raidId: " .. raidId end

	local diffDef = RaidConfig.GetDifficulty(difficulty)
	if not diffDef then return nil, "Unknown difficulty: " .. difficulty end

	local members: { Player } = {}
	if partyService and type(partyService.GetPartyMembers) == "function" then
		local pm = partyService.GetPartyMembers(leader)
		if pm then members = pm end
	end
	if #members == 0 then table.insert(members, leader) end

	if #members < (raidDef.minRaidSize or 1) then
		return nil, string.format("Not enough players (need %d, have %d).", raidDef.minRaidSize or 1, #members)
	end

	if difficulty == "Mythic" and diffDef.LockedRosterSize then
		if #members ~= diffDef.LockedRosterSize then
			return nil, string.format("Mythic requires exactly %d players (have %d).",
				diffDef.LockedRosterSize, #members)
		end
	end

	for _, member in ipairs(members) do
		if playerIndex[member.UserId] then
			return nil, string.format("Player %s is already in a raid.", member.Name)
		end
	end

	if playerDataService then
		for _, member in ipairs(members) do
			local data = playerDataService.GetData(member)
			if data then
				if (data.Level or 1) < (raidDef.minLevel or 1) then
					return nil, string.format("%s is too low level (need %d, have %d).",
						member.Name, raidDef.minLevel, data.Level or 1)
				end
				local tombTier = data.TombData and data.TombData.Tier or 0
				if tombTier < (raidDef.minTombTier or 0) then
					return nil, string.format("%s needs Tomb Tier %d (has %d).",
						member.Name, raidDef.minTombTier, tombTier)
				end
			end
		end
	end

	local raidRunId = generateRunId()
	local run: RaidRun = {
		raidRunId = raidRunId, raidId = raidId, difficulty = difficulty,
		members = members, leaderUserId = leader.UserId, status = "Waiting",
		startedAt = nil, endedAt = nil, failReason = nil,
		bossStates = buildBossStates(raidDef, difficulty),
		killedBosses = {}, wipes = 0, timerThread = nil,
	}

	runs[raidRunId] = run
	indexMembers(raidRunId, members)

	print(string.format("[RaidService] Created raid %s (raidId=%s, diff=%s, members=%d).",
		raidRunId, raidId, difficulty, #members))
	return raidRunId, nil
end

function RaidService.StartRaid(raidRunId: string): (boolean, string?)
	local run = runs[raidRunId]
	if not run then return false, "Raid run not found: " .. tostring(raidRunId) end
	if run.status ~= "Waiting" then
		return false, string.format("Run %s cannot start (status=%s).", raidRunId, run.status)
	end

	local raidDef = RaidConfig.GetRaid(run.raidId)
	local enrageSeconds = 3600
	if raidDef and type(raidDef.bosses) == "table" and #raidDef.bosses > 0 then
		local total = 0
		for _, b in ipairs(raidDef.bosses) do total += (b.enrageTimer or 600) end
		enrageSeconds = total
	end

	run.status      = "Active"
	run.startedAt   = os.time()
	run.timerThread = startTimer(raidRunId, enrageSeconds)

	RaidService.RaidStarted:Fire(run.members, {
		raidRunId = raidRunId, raidId = run.raidId, difficulty = run.difficulty,
		memberCount = #run.members, timerSecs = enrageSeconds,
	})

	print(string.format("[RaidService] Started raid %s — timer %ds.", raidRunId, enrageSeconds))
	return true, nil
end

--------------------------------------------------------------------------------
-- PUBLIC API — BOSS INTERACTIONS
--------------------------------------------------------------------------------

function RaidService.OnBossDamaged(raidRunId: string, bossId: string, damage: number): {
	died: boolean, phaseChanged: boolean, newPhaseIndex: number?, hpFraction: number,
}
	local run = runs[raidRunId]
	if not run or run.status ~= "Active" then
		return { died = false, phaseChanged = false, hpFraction = 1 }
	end
	local bs = run.bossStates[bossId]
	if not bs or bs.dead then
		return { died = false, phaseChanged = false, hpFraction = 0 }
	end

	bs.currentHealth = math.max(0, bs.currentHealth - math.floor(damage))
	local hpFrac = bs.currentHealth / math.max(1, bs.maxHealth)

	local raidDef      = RaidConfig.GetRaid(run.raidId)
	local bossConf     = raidDef and RaidConfig.GetBoss(run.raidId, bossId)
	local phaseChanged = false
	local newPhaseIndex: number? = nil

	if bossConf and type(bossConf.phases) == "table" then
		local targetPhase = RaidConfig.GetBossPhase(bossConf, hpFrac)
		if targetPhase and targetPhase.phaseIndex ~= bs.currentPhase then
			local oldPhase  = bs.currentPhase
			bs.currentPhase = targetPhase.phaseIndex
			phaseChanged    = true
			newPhaseIndex   = targetPhase.phaseIndex

			print(string.format("[RaidService] %s %s → Phase %d (%s).",
				raidRunId, bossId, targetPhase.phaseIndex, targetPhase.label or ""))

			RaidService.BossPhaseChanged:Fire(run.members, {
				raidRunId    = raidRunId,
				bossId       = bossId,
				oldPhase     = oldPhase,
				newPhase     = targetPhase.phaseIndex,
				phaseLabel   = targetPhase.label   or "",
				dialogue     = targetPhase.dialogue or "",
				newAbilities = targetPhase.newAbilities or {},
				mechanics    = targetPhase.mechanics    or {},
			})
		end
	end

	if bs.currentHealth <= 0 then
		bs.dead = true
		return { died = true, phaseChanged = phaseChanged, newPhaseIndex = newPhaseIndex, hpFraction = 0 }
	end
	return { died = false, phaseChanged = phaseChanged, newPhaseIndex = newPhaseIndex, hpFraction = hpFrac }
end

function RaidService.BossKilled(raidRunId: string, bossId: string): (boolean, string?)
	local run = runs[raidRunId]
	if not run or run.status ~= "Active" then return false, "Run not active." end
	local bs = run.bossStates[bossId]
	if not bs then return false, "Unknown bossId: " .. bossId end

	bs.dead = true
	run.killedBosses[bossId] = true

	RaidService.BossDied:Fire(run.members, { raidRunId = raidRunId, bossId = bossId })
	print(string.format("[RaidService] Boss %s killed in raid %s.", bossId, raidRunId))

	local raidDef = RaidConfig.GetRaid(run.raidId)
	if raidDef and type(raidDef.bosses) == "table" then
		local allDead = true
		for _, bossConf in ipairs(raidDef.bosses) do
			if not run.killedBosses[bossConf.id] then allDead = false; break end
		end
		if allDead then return RaidService.CompleteRaid(raidRunId) end
	end
	return true, nil
end

function RaidService.RecordWipe(raidRunId: string): (boolean, string?)
	local run = runs[raidRunId]
	if not run or run.status ~= "Active" then return false, "Run not active." end
	run.wipes += 1
	local diffDef = RaidConfig.GetDifficulty(run.difficulty)
	if diffDef and type(diffDef.MaxWipes) == "number" and diffDef.MaxWipes >= 0 then
		if run.wipes >= diffDef.MaxWipes then
			return RaidService.FailRaid(raidRunId, string.format(
				"WipeLimit — exceeded %d wipes.", diffDef.MaxWipes))
		end
	end
	print(string.format("[RaidService] Wipe #%d in raid %s.", run.wipes, raidRunId))
	return true, nil
end

--------------------------------------------------------------------------------
-- PUBLIC API — TERMINAL STATES
--------------------------------------------------------------------------------

function RaidService.CompleteRaid(raidRunId: string): (boolean, string?)
	local run = runs[raidRunId]
	if not run then return false, "Raid not found: " .. tostring(raidRunId) end
	if run.status ~= "Active" then
		return false, string.format("Raid %s cannot complete (status=%s).", raidRunId, run.status)
	end

	run.status  = "Completed"
	run.endedAt = os.time()
	if run.timerThread then task.cancel(run.timerThread); run.timerThread = nil end

	applyRaidProgress(run)
	grantRaidRewards(run)
	deindexMembers(run.members)

	local elapsed = if run.startedAt then run.endedAt - run.startedAt else 0
	RaidService.RaidCompleted:Fire(run.members, {
		raidRunId = raidRunId, raidId = run.raidId, difficulty = run.difficulty,
		elapsed = elapsed, wipes = run.wipes,
	})
	task.delay(300, function() runs[raidRunId] = nil end)
	print(string.format("[RaidService] Raid %s COMPLETED in %ds (%d wipes).",
		raidRunId, elapsed, run.wipes))
	return true, nil
end

function RaidService.FailRaid(raidRunId: string, reason: string?): (boolean, string?)
	local run = runs[raidRunId]
	if not run then return false, "Raid not found: " .. tostring(raidRunId) end
	if run.status == "Completed" or run.status == "Failed" then
		return false, string.format("Raid %s is already terminal (status=%s).", raidRunId, run.status)
	end

	run.status     = "Failed"
	run.endedAt    = os.time()
	run.failReason = reason or "Unknown"
	if run.timerThread then task.cancel(run.timerThread); run.timerThread = nil end

	deindexMembers(run.members)
	RaidService.RaidFailed:Fire(run.members, {
		raidRunId = raidRunId, raidId = run.raidId,
		reason = run.failReason, wipes = run.wipes,
	})
	task.delay(120, function() runs[raidRunId] = nil end)
	print(string.format("[RaidService] Raid %s FAILED — %s.", raidRunId, run.failReason))
	return true, nil
end

--------------------------------------------------------------------------------
-- PUBLIC API — QUERIES
--------------------------------------------------------------------------------

function RaidService.GetRaid(raidRunId: string): RaidRun?
	return runs[raidRunId]
end

function RaidService.GetPlayerRaid(player: Player): RaidRun?
	local id = playerIndex[player.UserId]
	return if id then runs[id] else nil
end

function RaidService.GetBossState(raidRunId: string, bossId: string): BossState?
	local run = runs[raidRunId]
	return run and run.bossStates[bossId] or nil
end

function RaidService.IsPlayerInRaid(player: Player): boolean
	return playerIndex[player.UserId] ~= nil
end

--------------------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------------

function RaidService.Init(pds: any, ps: any, inv: any, mts: any, ses: any, bas: any)
	if initialized then warn("[RaidService] Init called more than once; ignoring."); return end
	assert(pds, "[RaidService] PlayerDataService required.")
	assert(ps,  "[RaidService] PartyService required.")

	playerDataService  = pds
	partyService       = ps
	inventoryService   = inv
	magicTierService   = mts
	spellEffectService = ses
	bossAIService      = bas
	initialized        = true

	Players.PlayerRemoving:Connect(function(player)
		local raidRunId = playerIndex[player.UserId]
		if not raidRunId then return end
		local run = runs[raidRunId]
		if not run or run.status ~= "Active" then
			playerIndex[player.UserId] = nil; return
		end
		if player.UserId == run.leaderUserId then
			RaidService.FailRaid(raidRunId, string.format("Leader (%s) left the game.", player.Name))
		else
			playerIndex[player.UserId] = nil
			for i, m in ipairs(run.members) do
				if m.UserId == player.UserId then table.remove(run.members, i); break end
			end
		end
	end)

	print("[RaidService] Initialized.")
end

return RaidService
