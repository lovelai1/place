--!strict
-- Server-authoritative mob AI for GhostyRPG.
-- Each mob runs in its own task.spawn loop:
--   Idle (wander) → Aggro (chase) → Combat (attack) → Dead (reward + respawn callback)
--
-- Bug-fixes vs. draft:
--   • questService.OnMobKilled  → questService.NotifyKill   (matches QuestService public API)
--   • lootService.RollAndGrantLoot → lootService.GrantLoot  (matches LootService public API)
--
-- Dependencies injected via Init(); no circular requires.

local Players             = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local SharedConfig = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local MobConfig    = require(SharedConfig:WaitForChild("MobConfig"))

local PlayerRemotes = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("PlayerRemotes")
)

local MobAIService = {}

-- ── types ─────────────────────────────────────────────────────────────────

type MobInstance = {
	instanceId    : string,
	mobId         : string,
	model         : Model,
	humanoid      : Humanoid,
	root          : BasePart,
	hpFill        : Frame,
	state         : string,
	aggroTarget   : Player?,
	spawnPosition : Vector3,
	onDied        : (() -> ())?,
}

-- ── module state ──────────────────────────────────────────────────────────

local STATE = { Idle = "Idle", Aggro = "Aggro", Combat = "Combat", Dead = "Dead" }

local activeMobs: { [string]: MobInstance } = {}
local mobCounter                            = 0

local playerDataService: any = nil
local questService: any      = nil
local lootService: any       = nil
local levelService: any      = nil
local lootDropService: any   = nil
local magicTierService: any  = nil  -- Phase 5: AMP on elite kill
local initialized            = false

-- ── helpers ───────────────────────────────────────────────────────────────

local function nextId(): string
	mobCounter += 1
	return "mob_" .. mobCounter
end

local function closestPlayer(pos: Vector3, range: number): Player?
	local best:     Player? = nil
	local bestDist: number  = math.huge

	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		if not char then continue end
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then continue end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then continue end
		local d = (root.Position - pos).Magnitude
		if d < range and d < bestDist then
			bestDist = d
			best     = p
		end
	end
	return best
end

local function nearbyPlayers(pos: Vector3, range: number): { Player }
	local out: { Player } = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		if not char then continue end
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then continue end
		if (root.Position - pos).Magnitude <= range then
			table.insert(out, p)
		end
	end
	return out
end

-- ── reward on death ───────────────────────────────────────────────────────

local function grantRewards(mob: MobInstance)
	local killer = mob.aggroTarget
	if not killer or not killer.Parent then return end

	-- Lazy-load server config to avoid circular dependency at module-load time.
	local serverCfg
	pcall(function()
		serverCfg = require(
			ServerScriptService
				:WaitForChild("Server")
				:WaitForChild("Config")
				:WaitForChild("MobServerConfig")
		)
	end)
	if not serverCfg then return end

	local entry = serverCfg.GetServerMob(mob.mobId)
	if not entry then return end

	local expAmt  = entry.exp  or 0
	local goldAmt = entry.gold or 0

	-- EXP: go through LevelService so level-up logic fires; fall back to raw add
	if expAmt > 0 then
		if levelService then
			pcall(levelService.AddExp, killer, expAmt)
		elseif playerDataService then
			playerDataService.AddExp(killer, expAmt)
		end
	end
	if goldAmt > 0 and playerDataService then
		playerDataService.AddGold(killer, goldAmt)
	end

	PlayerRemotes.GetEvent("ExpGained"):FireClient(killer, { exp = expAmt, gold = goldAmt })

	-- Loot: roll items then spawn physical bag in the world
	if lootService and entry.loot then
		local ok, rolled = pcall(lootService.RollTable, entry.loot)
		if ok and rolled and #rolled > 0 then
			if lootDropService then
				-- World bag at death position so others can also pick up
				lootDropService.SpawnBag(rolled, mob.root.Position, killer)
			else
				-- Fallback: grant directly if drop service not ready
				pcall(lootService.GrantLoot, killer, entry.loot)
			end
		end
	end

	-- Quest kill progress — NotifyKill(player, mobId)
	if questService then
		pcall(questService.NotifyKill, killer, mob.mobId)
	end

	-- Phase 5: grant AMP for elite/boss mob kills
	if magicTierService and entry.isElite then
		local ampAmt = entry.isBoss and 75 or 25
		pcall(magicTierService.AddAMP, killer, ampAmt, "EliteKill")
	end
end

-- ── death handling ────────────────────────────────────────────────────────

local function handleDeath(mob: MobInstance)
	if mob.state == STATE.Dead then return end
	mob.state = STATE.Dead

	-- Notify nearby players (kill-feed placeholder)
	for _, p in ipairs(nearbyPlayers(mob.root.Position, 60)) do
		PlayerRemotes.GetEvent("MobDied"):FireClient(p, { mobId = mob.mobId })
	end

	grantRewards(mob)

	-- Freeze the model in place
	mob.humanoid.WalkSpeed  = 0
	mob.humanoid.JumpPower  = 0
	mob.humanoid.AutoRotate = false

	task.delay(2.5, function()
		if mob.model.Parent then
			mob.model.Parent = nil
		end
		activeMobs[mob.instanceId] = nil
		if mob.onDied then
			mob.onDied()
		end
	end)
end

-- ── AI loop ───────────────────────────────────────────────────────────────

local function runLoop(mob: MobInstance)
	local def = MobConfig.GetMob(mob.mobId)
	if not def then return end

	local aggroRange     = def.aggroRange  or 20
	local attackRange    = def.attackRange or 5
	local damage         = def.damage      or 10
	local leashRange     = aggroRange * 2.5
	local attackCooldown = 2.0   -- seconds between hits

	while mob.state ~= STATE.Dead and mob.model.Parent ~= nil do
		task.wait(0.05)

		if mob.humanoid.Health <= 0 then
			handleDeath(mob)
			break
		end

		-- ── Idle: wander and scan ────────────────────────────────────────
		if mob.state == STATE.Idle then
			local target = closestPlayer(mob.root.Position, aggroRange)
			if target then
				mob.aggroTarget = target
				mob.state       = STATE.Aggro
			else
				local offset = Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
				mob.humanoid:MoveTo(mob.spawnPosition + offset)
				task.wait(3 + math.random() * 3)
			end

		-- ── Aggro: chase the target ──────────────────────────────────────
		elseif mob.state == STATE.Aggro then
			local target = mob.aggroTarget
			if not target or not target.Parent then
				mob.state       = STATE.Idle
				mob.aggroTarget = nil
				mob.humanoid:MoveTo(mob.spawnPosition)
				continue
			end

			local char  = target.Character
			local troot = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not troot then
				mob.state = STATE.Idle
				continue
			end

			-- Leash check: too far from spawn → reset and full-heal
			if (mob.root.Position - mob.spawnPosition).Magnitude > leashRange then
				mob.state              = STATE.Idle
				mob.aggroTarget        = nil
				mob.humanoid.Health    = mob.humanoid.MaxHealth
				mob.humanoid:MoveTo(mob.spawnPosition)
				task.wait(1)
				continue
			end

			local dist = (mob.root.Position - troot.Position).Magnitude
			if dist <= attackRange then
				mob.state = STATE.Combat
			else
				mob.humanoid:MoveTo(troot.Position)
				task.wait(0.25)
			end

		-- ── Combat: attack the target ────────────────────────────────────
		elseif mob.state == STATE.Combat then
			local target = mob.aggroTarget
			if not target or not target.Parent then
				mob.state = STATE.Idle
				continue
			end

			local char  = target.Character
			local troot = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local thum  = char and char:FindFirstChildOfClass("Humanoid")

			if not troot or not thum or thum.Health <= 0 then
				mob.state       = STATE.Idle
				mob.aggroTarget = nil
				continue
			end

			-- If target moved away, re-enter aggro
			if (mob.root.Position - troot.Position).Magnitude > attackRange * 1.8 then
				mob.state = STATE.Aggro
				continue
			end

			thum:TakeDamage(damage)
			PlayerRemotes.GetEvent("MobDamaged"):FireClient(target, {
				source         = "mob",
				mobId          = mob.mobId,
				amount         = damage,
				targetIsPlayer = true,
			})

			task.wait(attackCooldown)
		end
	end
end

-- ── model builder ─────────────────────────────────────────────────────────

local BODY_COLORS: { [string]: BrickColor } = {
	mob_ghost_slime       = BrickColor.new("Bright blue"),
	mob_grave_goblin      = BrickColor.new("Bright green"),
	mob_restless_skeleton = BrickColor.new("White"),
}

local function buildModel(
	mobId:    string,
	def:      any,
	position: Vector3
): (Model, Humanoid, BasePart, Frame)

	local model    = Instance.new("Model")
	model.Name     = def.name

	-- Invisible physics root
	local root            = Instance.new("Part")
	root.Name             = "HumanoidRootPart"
	root.Size             = Vector3.new(2, 2, 1)
	root.CFrame           = CFrame.new(position + Vector3.new(0, 1, 0))
	root.Anchored         = false
	root.CanCollide       = true
	root.Transparency     = 1
	root.Parent           = model

	-- Visible torso
	local brickColor      = BODY_COLORS[mobId] or BrickColor.new("Medium stone grey")
	local torso           = Instance.new("Part")
	torso.Name            = "Torso"
	torso.Size            = Vector3.new(2, 2, 1)
	torso.CFrame          = root.CFrame
	torso.CanCollide      = false
	torso.BrickColor      = brickColor
	torso.Parent          = model

	local torsoWeld       = Instance.new("WeldConstraint")
	torsoWeld.Part0       = root
	torsoWeld.Part1       = torso
	torsoWeld.Parent      = root

	-- Head
	local head            = Instance.new("Part")
	head.Name             = "Head"
	head.Size             = Vector3.new(1.6, 1.6, 1.6)
	head.CFrame           = root.CFrame * CFrame.new(0, 1.8, 0)
	head.CanCollide       = false
	head.BrickColor       = brickColor
	head.Parent           = model

	local headWeld        = Instance.new("WeldConstraint")
	headWeld.Part0        = root
	headWeld.Part1        = head
	headWeld.Parent       = root

	-- Billboard GUI (name + HP bar)
	local billboard              = Instance.new("BillboardGui")
	billboard.Size               = UDim2.new(0, 180, 0, 44)
	billboard.StudsOffset        = Vector3.new(0, 3.5, 0)
	billboard.AlwaysOnTop        = false
	billboard.Parent             = root

	local nameLabel              = Instance.new("TextLabel")
	nameLabel.Size               = UDim2.new(1, 0, 0, 20)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font               = Enum.Font.GothamBold
	nameLabel.TextSize           = 13
	nameLabel.TextColor3         = Color3.fromRGB(255, 100, 100)
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Text               = def.name .. "  Lv." .. def.level
	nameLabel.Parent             = billboard

	local hpBg                   = Instance.new("Frame")
	hpBg.Size                    = UDim2.new(1, 0, 0, 10)
	hpBg.Position                = UDim2.new(0, 0, 0, 22)
	hpBg.BackgroundColor3        = Color3.fromRGB(50, 10, 10)
	hpBg.BorderSizePixel         = 0
	hpBg.Parent                  = billboard

	local hpFill                 = Instance.new("Frame")
	hpFill.Name                  = "Fill"
	hpFill.Size                  = UDim2.new(1, 0, 1, 0)
	hpFill.BackgroundColor3      = Color3.fromRGB(220, 50, 50)
	hpFill.BorderSizePixel       = 0
	hpFill.Parent                = hpBg

	-- Humanoid
	local humanoid               = Instance.new("Humanoid")
	humanoid.MaxHealth           = def.maxHealth
	humanoid.Health              = def.maxHealth
	humanoid.WalkSpeed           = 12
	humanoid.DisplayName         = ""
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent              = model

	model.PrimaryPart = root
	model.Parent      = workspace

	return model, humanoid, root, hpFill
end

-- ── public API ────────────────────────────────────────────────────────────

--- Spawn a mob at a world position. onDied() fires after the corpse is cleaned up.
--- Returns the instanceId string (or nil on failure).
function MobAIService.SpawnMob(
	mobId:    string,
	position: Vector3,
	onDied:   (() -> ())?
): string?
	assert(initialized, "[MobAIService] Call Init() before SpawnMob().")

	local def = MobConfig.GetMob(mobId)
	if not def then
		warn("[MobAIService] Unknown mobId:", mobId)
		return nil
	end

	local model, humanoid, root, hpFill = buildModel(mobId, def, position)
	local instanceId = nextId()

	local mob: MobInstance = {
		instanceId    = instanceId,
		mobId         = mobId,
		model         = model,
		humanoid      = humanoid,
		root          = root,
		hpFill        = hpFill,
		state         = STATE.Idle,
		aggroTarget   = nil,
		spawnPosition = position,
		onDied        = onDied,
	}
	activeMobs[instanceId] = mob

	-- Tag the model so the client's click-to-target raycast can identify it
	model:SetAttribute("MobInstanceId", instanceId)

	-- Keep the HP bar in sync with the Humanoid
	humanoid.HealthChanged:Connect(function(hp: number)
		local pct    = math.clamp(hp / def.maxHealth, 0, 1)
		hpFill.Size  = UDim2.new(pct, 0, 1, 0)
	end)

	-- Humanoid.Died fires once reliably
	humanoid.Died:Connect(function()
		handleDeath(mob)
	end)

	task.spawn(runLoop, mob)
	return instanceId
end

function MobAIService.GetActiveMobCount(): number
	local n = 0
	for _ in pairs(activeMobs) do n += 1 end
	return n
end

--- Must be called before SpawnMob.
function MobAIService.Init(
	newPlayerDataService: any,
	newQuestService: any,
	newLootService: any,
	newLevelService: any,
	newLootDropService: any,
	newMagicTierService: any  -- Phase 5
)
	if initialized then
		warn("[MobAIService] Init called more than once; ignoring.")
		return
	end
	assert(newPlayerDataService, "[MobAIService] requires PlayerDataService")
	playerDataService = newPlayerDataService
	questService      = newQuestService
	lootService       = newLootService
	levelService      = newLevelService
	lootDropService   = newLootDropService
	magicTierService  = newMagicTierService  -- Phase 5
	initialized       = true
	print("[MobAIService] Initialized.")
end

--- Returns the active MobInstance for a given Model, or nil.
--- Used by ServerHandlers to resolve mob targets for ability hits.
function MobAIService.GetMobByModel(model: Model): any?
	for _, mob in pairs(activeMobs) do
		if mob.model == model then
			return mob
		end
	end
	return nil
end

--- Returns the active MobInstance by instanceId, or nil.
function MobAIService.GetMobByInstanceId(instanceId: string): any?
	return activeMobs[instanceId]
end

return MobAIService
