--!strict
--------------------------------------------------------------------------------
-- GhostyRPG | BossAIService.lua
-- ServerScriptService/Server/Services/BossAIService.lua
--
-- Многофазный ИИ рейдовых боссов.
-- Боссы кастуют способности через SpellEffectService.
-- Переход фаз приходит из RaidService (по HP-порогу).
--
-- INIT:
--   BossAIService.Init(playerDataService, raidService, spellEffectService)
--
-- PUBLIC API:
--   BossAIService.SpawnBoss(raidRunId, bossId, raidDef, origin, difficulty)
--   BossAIService.DespawnBoss(raidRunId, bossId)
--   BossAIService.DespawnAllForRaid(raidRunId)
--   BossAIService.ApplyDamage(raidRunId, bossId, damage) → { died, phaseChanged }
--   BossAIService.OnPhaseChanged(raidRunId, bossId, newPhaseIndex, newAbilities)
--   BossAIService.GetInstance(raidRunId, bossId) → BossInstance?
--   BossAIService.GetActiveCount(raidRunId) → number
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossAIService = {}

--------------------------------------------------------------------------------
-- TYPES
--------------------------------------------------------------------------------

type AbilityCooldown = { [string]: number }

type BossInstance = {
	instanceKey     : string,
	raidRunId       : string,
	bossId          : string,
	bossConf        : any,
	model           : Model,
	humanoid        : Humanoid,
	root            : BasePart,
	hpFill          : Frame?,
	state           : string,
	currentPhase    : number,
	activeAbilities : { string },
	abilityCDs      : AbilityCooldown,
	target          : Player?,
	origin          : Vector3,
	currentHealth   : number,
	maxHealth       : number,
	difficulty      : string,
	thread          : thread?,
	lastDialogTick  : number,
}

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------

local STATE = { Idle = "Idle", Combat = "Combat", Enrage = "Enrage", Dead = "Dead" }

local TICK_RATE       = 0.25
local AGGRO_RANGE     = 60
local ATTACK_RANGE    = 14
local AUTO_ATTACK_CD  = 2.5
local DIALOG_COOLDOWN = 12
local ENRAGE_TIMER    = 600

local DIFFICULTY_DMG: { [string]: number } = {
	LFR    = 0.60,
	Normal = 1.00,
	Heroic = 1.60,
	Mythic = 2.80,
}

local HP_COLORS = {
	high   = Color3.fromRGB(80,  200, 80),
	medium = Color3.fromRGB(230, 180, 40),
	low    = Color3.fromRGB(220, 60,  60),
}

--------------------------------------------------------------------------------
-- MODULE STATE
--------------------------------------------------------------------------------

local instances: { [string]: BossInstance } = {}

local playerDataService : any = nil
local raidService       : any = nil
local spellEffectService: any = nil
local raidRemotes       : any = nil
local initialized             = false

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function makeKey(raidRunId: string, bossId: string): string
	return raidRunId .. "|" .. bossId
end

local function isAlive(player: Player): boolean
	local char = player.Character
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function rootOf(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function closestRaider(pos: Vector3, members: { Player }, range: number): Player?
	local best: Player? = nil
	local bestDist = math.huge
	for _, p in ipairs(members) do
		if not isAlive(p) then continue end
		local r = rootOf(p)
		if not r then continue end
		local d = (r.Position - pos).Magnitude
		if d < range and d < bestDist then bestDist = d; best = p end
	end
	return best
end

local function raidersInRange(pos: Vector3, members: { Player }, range: number): { Player }
	local out: { Player } = {}
	for _, p in ipairs(members) do
		if not isAlive(p) then continue end
		local r = rootOf(p)
		if r and (r.Position - pos).Magnitude <= range then table.insert(out, p) end
	end
	return out
end

local function getRaidMembers(raidRunId: string): { Player }
	if raidService and type(raidService.GetRaid) == "function" then
		local run = raidService.GetRaid(raidRunId)
		if run and type(run.members) == "table" then return run.members end
	end
	return {}
end

local function updateHPBar(boss: BossInstance)
	if not boss.hpFill then return end
	local pct = math.clamp(boss.currentHealth / math.max(1, boss.maxHealth), 0, 1)
	boss.hpFill.Size = UDim2.new(pct, 0, 1, 0)
	boss.hpFill.BackgroundColor3 = if pct > 0.6 then HP_COLORS.high
		elseif pct > 0.3 then HP_COLORS.medium
		else HP_COLORS.low
end

local function showDialog(boss: BossInstance, line: string)
	if line == "" then return end
	local now = tick()
	if now - boss.lastDialogTick < DIALOG_COOLDOWN then return end
	boss.lastDialogTick = now
	print(string.format("[BossAI] [%s] \"%s\"", boss.bossId, line))
	for _, p in ipairs(getRaidMembers(boss.raidRunId)) do
		pcall(function()
			if raidRemotes then
				raidRemotes.GetEvent("BossDialog"):FireClient(p, {
					bossId = boss.bossId, line = line,
				})
			end
		end)
	end
end

--------------------------------------------------------------------------------
-- ABILITY SYSTEM
--------------------------------------------------------------------------------

local ABILITY_CD: { [string]: number } = {
	DK_DEATH_GRIP = 15, DK_DEATH_STRIKE = 8, DK_BLOOD_BOIL = 12,
	DK_ANTI_MAGIC_SHELL = 45, DK_ARMY_OF_THE_DEAD = 120,
	SKELWAR_OSSIFY = 30, SKELWAR_REASSEMBLE = 60,
	SKELWAR_BONE_SHIELD = 20, SKELWAR_RATTLE = 10, SKELWAR_MARROW_STRIKE = 6,
	LICH_FROST_LANCE = 5, LICH_DEATH_COIL = 8, LICH_BLIZZARD = 20,
	LICH_FROZEN_ORB = 40, LICH_PHYLACTERY_RECALL = 90,
	OVERLORD_SOUL_HARVEST = 18, OVERLORD_VOID_RUPTURE = 22,
	OVERLORD_DOMINATE = 35, OVERLORD_UNDYING_WILL = 90,
	OVERLORD_NECROMANTIC_AURA = 30,
	PHANTOMMAGE_VOID_BOLT = 4, PHANTOMMAGE_MIND_FLAY = 10,
	PHANTOMMAGE_ECHO_NOVA = 25, PHANTOMMAGE_SOUL_BURST = 20,
	PHANTOMMAGE_ETHEREAL_FORM = 60,
	PHANTOMSOUL_WAIL = 12, PHANTOMSOUL_SOUL_DRAIN = 8,
	PHANTOMSOUL_HAUNT = 6, PHANTOMSOUL_PHASE_SHIFT = 40,
}

local ABILITY_DMG_MULT: { [string]: number } = {
	SKELWAR_OSSIFY        = 2.5,
	SKELWAR_REASSEMBLE    = 0,
	DK_DEATH_GRIP         = 0.8,
	DK_DEATH_STRIKE       = 1.8,
	DK_BLOOD_BOIL         = 1.2,
	DK_ANTI_MAGIC_SHELL   = 0,
	DK_ARMY_OF_THE_DEAD   = 0.5,
	LICH_FROZEN_ORB       = 3.0,
	OVERLORD_SOUL_HARVEST = 2.0,
	OVERLORD_VOID_RUPTURE = 2.5,
	OVERLORD_DOMINATE     = 1.5,
	OVERLORD_UNDYING_WILL = 0,
}

local AOE_RANGE: { [string]: number } = {
	DK_BLOOD_BOIL          = 15,
	LICH_FROZEN_ORB        = 20,
	OVERLORD_VOID_RUPTURE  = 25,
	PHANTOMMAGE_ECHO_NOVA  = 18,
	PHANTOMMAGE_SOUL_BURST = 20,
}

local HEAL_ABILITIES: { [string]: boolean } = {
	SKELWAR_REASSEMBLE    = true,
	OVERLORD_UNDYING_WILL = true,
}

local function applyDamageToPlayer(player: Player, dmg: number)
	if not playerDataService then return end
	local data = playerDataService.GetData(player)
	if not data then return end
	local shield = (type(data.ShieldHP) == "number") and data.ShieldHP or 0
	if shield > 0 then
		local abs = math.min(shield, dmg)
		data.ShieldHP = shield - abs; dmg = dmg - abs
	end
	if dmg > 0 then
		data.CurrentHealth = math.max(0,
			(type(data.CurrentHealth) == "number" and data.CurrentHealth or 0) - dmg)
		playerDataService.ScheduleSave(player)
	end
end

local function executeBossAbility(boss: BossInstance, abilityId: string, target: Player?)
	if not playerDataService then return end
	local diffMult = DIFFICULTY_DMG[boss.difficulty] or 1.0
	local baseDmg  = math.floor((boss.bossConf.baseDamage or 500) * diffMult)

	-- Самохил
	if HEAL_ABILITIES[abilityId] then
		local healAmt = math.floor(boss.maxHealth * 0.05)
		boss.currentHealth = math.min(boss.maxHealth, boss.currentHealth + healAmt)
		boss.humanoid.Health = boss.currentHealth
		updateHPBar(boss)
		return
	end

	-- Авто-атака
	if abilityId == "__autoattack" then
		if target then applyDamageToPlayer(target, baseDmg) end
		return
	end

	local mult = ABILITY_DMG_MULT[abilityId]
	if mult == nil then mult = 1.0 end
	local damage = math.floor(baseDmg * mult)
	if damage <= 0 then return end

	local aoeRange = AOE_RANGE[abilityId]
	if aoeRange then
		local targets = raidersInRange(boss.root.Position, getRaidMembers(boss.raidRunId), aoeRange)
		for _, t in ipairs(targets) do applyDamageToPlayer(t, damage) end
	elseif target then
		applyDamageToPlayer(target, damage)
	end
end

local function pickAbility(boss: BossInstance): string?
	local now = tick()
	for _, abilityId in ipairs(boss.activeAbilities) do
		if now >= (boss.abilityCDs[abilityId] or 0) then return abilityId end
	end
	return nil
end

--------------------------------------------------------------------------------
-- AI LOOP
--------------------------------------------------------------------------------

local function runBossLoop(boss: BossInstance)
	local autoAttackTimer = 0.0
	local enrageCountdown = boss.bossConf.enrageTimer or ENRAGE_TIMER

	while boss.state ~= STATE.Dead do
		task.wait(TICK_RATE)
		if not instances[boss.instanceKey] then break end
		if not boss.model.Parent then break end

		local myPos  = boss.root.Position
		local members = getRaidMembers(boss.raidRunId)

		enrageCountdown -= TICK_RATE
		if enrageCountdown <= 0 and boss.state ~= STATE.Enrage and boss.state ~= STATE.Dead then
			boss.state = STATE.Enrage
			showDialog(boss, "ENRAGE!")
		end

		if boss.state == STATE.Idle then
			local intruder = closestRaider(myPos, members, AGGRO_RANGE)
			if intruder then
				boss.state  = STATE.Combat
				boss.target = intruder
				if boss.bossConf.phases and boss.bossConf.phases[1] then
					showDialog(boss, boss.bossConf.phases[1].dialogue or "")
				end
			end

		elseif boss.state == STATE.Combat or boss.state == STATE.Enrage then
			local target = boss.target
			if not target or not isAlive(target) then
				target = closestRaider(myPos, members, AGGRO_RANGE * 2)
				boss.target = target
			end
			if not target then boss.state = STATE.Idle; continue end

			local tRoot = rootOf(target)
			if tRoot then
				local dist = (myPos - tRoot.Position).Magnitude
				if dist > ATTACK_RANGE then
					boss.humanoid.WalkSpeed = 14
					boss.humanoid:MoveTo(tRoot.Position)
				else
					boss.humanoid.WalkSpeed = 0
				end
			end

			local now = tick()

			autoAttackTimer -= TICK_RATE
			if autoAttackTimer <= 0 then
				autoAttackTimer = if boss.state == STATE.Enrage then 0.5 else AUTO_ATTACK_CD
				executeBossAbility(boss, "__autoattack", target)
			end

			local abilityId = pickAbility(boss)
			if abilityId then
				boss.abilityCDs[abilityId] = now + (ABILITY_CD[abilityId] or 10)
				executeBossAbility(boss, abilityId, target)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- MODEL BUILDER
--------------------------------------------------------------------------------

local function buildBossModel(boss: BossInstance): (Model, Humanoid, BasePart, Frame?)
	local conf  = boss.bossConf
	local model = Instance.new("Model")
	model.Name  = "Boss_" .. boss.bossId

	local sizeScale = if conf.size == "Colossal" then 3.5
		elseif conf.size == "Large" then 2.0 else 1.5

	local root      = Instance.new("Part")
	root.Name       = "HumanoidRootPart"
	root.Size       = Vector3.new(2 * sizeScale, 2 * sizeScale, 1 * sizeScale)
	root.Anchored   = false; root.CanCollide = true
	root.BrickColor = BrickColor.new("Really black")
	root.Material   = Enum.Material.SmoothPlastic
	root.Parent     = model

	local body    = Instance.new("Part")
	body.Name     = "UpperTorso"
	body.Size     = Vector3.new(2.5 * sizeScale, 4 * sizeScale, 1.5 * sizeScale)
	body.Anchored = false; body.CanCollide = false
	body.BrickColor = BrickColor.new("Smoky grey")
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root; weld.Part1 = body; weld.Parent = root
	body.Parent = model

	local hum       = Instance.new("Humanoid")
	hum.MaxHealth   = boss.maxHealth
	hum.Health      = boss.maxHealth
	hum.WalkSpeed   = 14
	hum.DisplayName = conf.name or boss.bossId
	hum.Parent      = model

	local bb = Instance.new("BillboardGui")
	bb.Adornee = root
	bb.Size    = UDim2.new(0, 240, 0, 48)
	bb.StudsOffset = Vector3.new(0, sizeScale * 3.5, 0)
	bb.AlwaysOnTop = false; bb.Parent = model

	local nameL = Instance.new("TextLabel")
	nameL.Size  = UDim2.new(1, 0, 0.55, 0)
	nameL.BackgroundTransparency = 1
	nameL.TextColor3 = Color3.fromRGB(220, 60, 60)
	nameL.TextStrokeTransparency = 0.3
	nameL.Font = Enum.Font.GothamBold; nameL.TextSize = 14
	nameL.Text = "⚔ " .. (conf.name or boss.bossId); nameL.Parent = bb

	local hpBg = Instance.new("Frame")
	hpBg.Size  = UDim2.new(1, 0, 0.45, 0)
	hpBg.Position = UDim2.new(0, 0, 0.55, 0)
	hpBg.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	hpBg.BorderSizePixel  = 0; hpBg.Parent = bb

	local hpFill = Instance.new("Frame")
	hpFill.Size  = UDim2.new(1, 0, 1, 0)
	hpFill.BackgroundColor3 = HP_COLORS.high
	hpFill.BorderSizePixel  = 0; hpFill.Parent = hpBg

	model.PrimaryPart = root
	return model, hum, root, hpFill
end

--------------------------------------------------------------------------------
-- DAMAGE API
--------------------------------------------------------------------------------

function BossAIService.ApplyDamage(raidRunId: string, bossId: string, damage: number): {
	died: boolean, phaseChanged: boolean, newPhaseIndex: number?
}
	local boss = instances[makeKey(raidRunId, bossId)]
	if not boss or boss.state == STATE.Dead then
		return { died = false, phaseChanged = false }
	end

	boss.currentHealth   = math.max(0, boss.currentHealth - math.floor(damage))
	boss.humanoid.Health = boss.currentHealth
	updateHPBar(boss)

	local result = { died = false, phaseChanged = false, newPhaseIndex = nil :: number? }

	if raidService and type(raidService.OnBossDamaged) == "function" then
		local rs = raidService.OnBossDamaged(raidRunId, bossId, damage)
		result.phaseChanged  = rs.phaseChanged
		result.newPhaseIndex = rs.newPhaseIndex
	end

	if boss.currentHealth <= 0 then
		boss.state = STATE.Dead
		boss.humanoid.Health = 0
		result.died = true
		if raidService and type(raidService.BossKilled) == "function" then
			task.spawn(function()
				task.wait(2)
				raidService.BossKilled(raidRunId, bossId)
			end)
		end
	end

	return result
end

--------------------------------------------------------------------------------
-- PHASE TRANSITION
--------------------------------------------------------------------------------

function BossAIService.OnPhaseChanged(
	raidRunId   : string,
	bossId      : string,
	newPhaseIndex: number,
	newAbilities : { string }
)
	local boss = instances[makeKey(raidRunId, bossId)]
	if not boss then return end
	boss.currentPhase = newPhaseIndex
	for _, abilityId in ipairs(newAbilities) do
		local found = false
		for _, existing in ipairs(boss.activeAbilities) do
			if existing == abilityId then found = true; break end
		end
		if not found then table.insert(boss.activeAbilities, abilityId) end
	end
	if boss.bossConf.phases then
		for _, ph in ipairs(boss.bossConf.phases) do
			if ph.phaseIndex == newPhaseIndex then
				showDialog(boss, ph.dialogue or ""); break
			end
		end
	end
	print(string.format("[BossAI] %s → Phase %d. Abilities: %s",
		bossId, newPhaseIndex, table.concat(boss.activeAbilities, ", ")))
end

--------------------------------------------------------------------------------
-- SPAWN / DESPAWN
--------------------------------------------------------------------------------

function BossAIService.SpawnBoss(
	raidRunId  : string,
	bossId     : string,
	raidDef    : any,
	origin     : Vector3,
	difficulty : string
)
	local bossConf: any = nil
	if type(raidDef.bosses) == "table" then
		for _, b in ipairs(raidDef.bosses) do
			if b.id == bossId then bossConf = b; break end
		end
	end
	if not bossConf then warn("[BossAI] Unknown bossId: " .. bossId); return end

	BossAIService.DespawnBoss(raidRunId, bossId)

	local k        = makeKey(raidRunId, bossId)
	local diffCfg: any = {}
	pcall(function()
		local Server = game:GetService("ServerScriptService"):WaitForChild("Server")
		local rc = require(Server:WaitForChild("Config"):WaitForChild("RaidConfig"))
		diffCfg = rc.GetDifficulty(difficulty) or {}
	end)

	local hpMult = if type(diffCfg.EnemyHealthMultiplier) == "number"
		then diffCfg.EnemyHealthMultiplier else 1.0
	local hp = math.floor((bossConf.baseHealth or 100000) * hpMult)

	local phase1Abilities: { string } = {}
	if type(bossConf.abilities) == "table" then
		for _, a in ipairs(bossConf.abilities) do
			table.insert(phase1Abilities, a)
		end
	end

	local boss: BossInstance = {
		instanceKey     = k,
		raidRunId       = raidRunId,
		bossId          = bossId,
		bossConf        = bossConf,
		model           = Instance.new("Model"),
		humanoid        = Instance.new("Humanoid"),
		root            = Instance.new("Part"),
		hpFill          = nil,
		state           = STATE.Idle,
		currentPhase    = 1,
		activeAbilities = phase1Abilities,
		abilityCDs      = {},
		target          = nil,
		origin          = origin,
		currentHealth   = hp,
		maxHealth       = hp,
		difficulty      = difficulty,
		thread          = nil,
		lastDialogTick  = 0,
	}

	local model, hum, root, hpFill = buildBossModel(boss)
	boss.model    = model; boss.humanoid = hum
	boss.root     = root;  boss.hpFill   = hpFill

	local raidFolder = workspace:FindFirstChild("Raids")
		and (workspace.Raids :: Folder):FindFirstChild(raidRunId)
	model:SetPrimaryPartCFrame(CFrame.new(origin))
	model.Parent = raidFolder or workspace

	hum.HealthChanged:Connect(function(newHP: number)
		if newHP < boss.currentHealth then
			boss.currentHealth = newHP; updateHPBar(boss)
			if newHP <= 0 and boss.state ~= STATE.Dead then boss.state = STATE.Dead end
		end
	end)

	instances[k] = boss
	boss.thread  = task.spawn(runBossLoop, boss)

	print(string.format("[BossAI] Spawned %s in raid %s (HP=%d, diff=%s).",
		bossId, raidRunId, hp, difficulty))
end

function BossAIService.DespawnBoss(raidRunId: string, bossId: string)
	local k    = makeKey(raidRunId, bossId)
	local boss = instances[k]
	if not boss then return end
	boss.state = STATE.Dead
	if boss.model and boss.model.Parent then boss.model:Destroy() end
	instances[k] = nil
end

function BossAIService.DespawnAllForRaid(raidRunId: string)
	for k, boss in pairs(instances) do
		if boss.raidRunId == raidRunId then
			boss.state = STATE.Dead
			if boss.model and boss.model.Parent then boss.model:Destroy() end
			instances[k] = nil
		end
	end
end

--------------------------------------------------------------------------------
-- QUERIES
--------------------------------------------------------------------------------

function BossAIService.GetInstance(raidRunId: string, bossId: string): BossInstance?
	return instances[makeKey(raidRunId, bossId)]
end

function BossAIService.GetActiveCount(raidRunId: string): number
	local n = 0
	for _, boss in pairs(instances) do if boss.raidRunId == raidRunId then n += 1 end end
	return n
end

--------------------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------------

function BossAIService.Init(pds: any, rs: any, ses: any, rr: any)
	if initialized then warn("[BossAIService] Init called more than once; ignoring."); return end
	assert(pds, "[BossAIService] PlayerDataService required.")
	assert(rs,  "[BossAIService] RaidService required.")

	playerDataService  = pds
	raidService        = rs
	spellEffectService = ses
	raidRemotes        = rr

	if rs.BossPhaseChanged then
		rs.BossPhaseChanged:Connect(function(_members: any, payload: any)
			if type(payload) ~= "table" then return end
			BossAIService.OnPhaseChanged(
				payload.raidRunId, payload.bossId,
				payload.newPhase, payload.newAbilities or {}
			)
		end)
	end

	if rs.RaidCompleted then
		rs.RaidCompleted:Connect(function(_members: any, payload: any)
			if type(payload) == "table" then
				task.delay(5, function() BossAIService.DespawnAllForRaid(payload.raidRunId) end)
			end
		end)
	end
	if rs.RaidFailed then
		rs.RaidFailed:Connect(function(_members: any, payload: any)
			if type(payload) == "table" then BossAIService.DespawnAllForRaid(payload.raidRunId) end
		end)
	end

	initialized = true
	print("[BossAIService] Initialized.")
end

return BossAIService
