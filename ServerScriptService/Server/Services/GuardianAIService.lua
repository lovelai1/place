--!strict
--------------------------------------------------------------------------------
-- GhostyRPG | GuardianAIService.lua
-- ServerScriptService/Server/Services/GuardianAIService.lua
--
-- Server-authoritative AI for Floor Guardians inside player Tombs.
--
-- STATE MACHINE:
--   Patrol → Alert → Aggro → Combat → Leash → Dead
--
-- INIT:
--   GuardianAIService.Init(playerDataService, tombBaseService,
--                          spellEffectService, guardianRemotes)
--
-- API:
--   GuardianAIService.SpawnGuardian(ownerId, guardianId, slotIndex, postPosition, tombTier)
--   GuardianAIService.DespawnGuardian(ownerId, slotIndex)
--   GuardianAIService.DespawnAllForOwner(ownerId)
--   GuardianAIService.ApplyDamage(instanceKey, damage) → bool (died?)
--   GuardianAIService.GetInstanceKey(ownerId, slotIndex) → string
--   GuardianAIService.GetActiveKeys(ownerId) → { string }
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedConfig         = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local GuardianConfig       = require(SharedConfig:WaitForChild("GuardianConfig"))
local GuardianDialogConfig = require(SharedConfig:WaitForChild("GuardianDialogConfig"))

local GuardianAIService = {}

--------------------------------------------------------------------------------
-- TYPES
--------------------------------------------------------------------------------

type AbilityCooldown = { [string]: number }

type GuardianInstance = {
	instanceKey    : string,
	ownerId        : number,
	guardianId     : string,
	slotIndex      : number,
	def            : any,
	model          : Model,
	humanoid       : Humanoid,
	root           : BasePart,
	hpFill         : Frame?,
	state          : string,
	target         : Player?,
	postPosition   : Vector3,
	tombTier       : number,
	maxHealth      : number,
	currentHealth  : number,
	abilityCDs     : AbilityCooldown,
	lastDialogTick : number,
	alertTick      : number?,
	thread         : thread?,
}

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------

local STATE = { Patrol = "Patrol", Alert = "Alert", Aggro = "Aggro",
	Combat = "Combat", Leash = "Leash", Dead = "Dead" }

local TICK_RATE          = 0.2
local ALERT_WARN_DELAY   = 1.5
local DIALOG_COOLDOWN    = 8
local RESPAWN_DELAY      = 30
local PATROL_CHANGE_DIST = 3

--------------------------------------------------------------------------------
-- MODULE STATE
--------------------------------------------------------------------------------

local activeGuardians: { [string]: GuardianInstance } = {}

local playerDataService: any  = nil
local tombBaseService: any    = nil
local spellEffectService: any = nil
local guardianRemotes: any    = nil
local initialized             = false

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function key(ownerId: number, slotIndex: number): string
	return tostring(ownerId) .. "_" .. tostring(slotIndex)
end

local function getOwnerPlayer(ownerId: number): Player?
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == ownerId then return p end
	end
	return nil
end

local function isAlliedPlayer(ownerId: number, player: Player): boolean
	return player.UserId == ownerId
end

local function isAlive(player: Player): boolean
	local char = player.Character
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function playerRootPosition(player: Player): Vector3?
	local char = player.Character
	if not char then return nil end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position or nil
end

local function scanForIntruder(pos: Vector3, ownerId: number, range: number): Player?
	local best: Player? = nil
	local bestDist = math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		if isAlliedPlayer(ownerId, p) then continue end
		if not isAlive(p) then continue end
		local pPos = playerRootPosition(p)
		if not pPos then continue end
		local d = (pPos - pos).Magnitude
		if d < range and d < bestDist then bestDist = d; best = p end
	end
	return best
end

local function showDialog(guardian: GuardianInstance, category: string)
	local now = tick()
	if now - guardian.lastDialogTick < DIALOG_COOLDOWN then return end
	guardian.lastDialogTick = now
	local line = GuardianDialogConfig.GetLine(guardian.guardianId, category :: any)
	if not line or line == "" then return end
	if guardianRemotes then
		pcall(function()
			for _, p in ipairs(Players:GetPlayers()) do
				guardianRemotes.GetEvent("GuardianDialog"):FireClient(p, {
					guardianId = guardian.guardianId,
					category   = category,
					line       = line,
					modelName  = guardian.model.Name,
				})
			end
		end)
	end
end

local function nextPatrolWaypoint(post: Vector3, radius: number): Vector3
	local angle = math.random() * math.pi * 2
	local dist  = math.random() * radius
	return Vector3.new(post.X + math.cos(angle) * dist, post.Y, post.Z + math.sin(angle) * dist)
end

local function pickReadyAbility(guardian: GuardianInstance): string?
	local now = tick()
	for _, abRef in ipairs(guardian.def.abilities) do
		if now >= (guardian.abilityCDs[abRef.abilityId] or 0) then
			return abRef.abilityId
		end
	end
	return nil
end

--- Applies guardian damage directly to target's PlayerData.
--- Guardians are not Player instances, so we bypass SpellEffectService.Apply
--- and write to playerDataService directly. ShieldHP is absorbed first.
local function castAbility(guardian: GuardianInstance, target: Player)
	local abilityId = pickReadyAbility(guardian)
	if not abilityId then return end

	local cdSecs = 8
	for _, abRef in ipairs(guardian.def.abilities) do
		if abRef.abilityId == abilityId then cdSecs = abRef.cooldown; break end
	end
	guardian.abilityCDs[abilityId] = tick() + cdSecs

	if not playerDataService then return end

	local damage = GuardianConfig.GetScaledDamage(guardian.guardianId, guardian.tombTier)
	local data   = playerDataService.GetData(target)
	if not data then return end

	-- Absorb shield
	local shield = (type(data.ShieldHP) == "number") and data.ShieldHP or 0
	if shield > 0 then
		local absorbed = math.min(shield, damage)
		data.ShieldHP  = shield - absorbed
		damage         = damage - absorbed
	end

	if damage > 0 then
		data.CurrentHealth = math.max(0,
			(type(data.CurrentHealth) == "number" and data.CurrentHealth or 0) - damage)
		playerDataService.ScheduleSave(target)
	end
end

local function updateHPBar(guardian: GuardianInstance)
	if not guardian.hpFill then return end
	local pct = math.clamp(guardian.currentHealth / math.max(1, guardian.maxHealth), 0, 1)
	guardian.hpFill.Size = UDim2.new(pct, 0, 1, 0)
	guardian.hpFill.BackgroundColor3 = Color3.fromRGB(
		math.floor(255 * (1 - pct)), math.floor(200 * pct), 50)
end

local function moveTo(guardian: GuardianInstance, pos: Vector3)
	guardian.humanoid.WalkSpeed = guardian.def.moveSpeed
	guardian.humanoid:MoveTo(pos)
end

--------------------------------------------------------------------------------
-- AI LOOP
--------------------------------------------------------------------------------

local function runAILoop(guardian: GuardianInstance)
	local patrolTarget = nextPatrolWaypoint(guardian.postPosition, guardian.def.patrolRadius)

	while guardian.state ~= STATE.Dead do
		task.wait(TICK_RATE)
		if not activeGuardians[guardian.instanceKey] then break end
		if not guardian.model.Parent then break end

		local myPos = guardian.root.Position
		local now   = tick()

		if guardian.state == STATE.Patrol then
			guardian.humanoid.WalkSpeed = guardian.def.patrolSpeed
			local intruder = scanForIntruder(myPos, guardian.ownerId, guardian.def.aggroRange)
			if intruder then
				guardian.state = STATE.Alert; guardian.target = intruder
				guardian.alertTick = now; showDialog(guardian, "WarnEnemy"); continue
			end
			if (myPos - patrolTarget).Magnitude < PATROL_CHANGE_DIST then
				patrolTarget = nextPatrolWaypoint(guardian.postPosition, guardian.def.patrolRadius)
			end
			moveTo(guardian, patrolTarget)

		elseif guardian.state == STATE.Alert then
			guardian.humanoid.WalkSpeed = 0
			if now - (guardian.alertTick or now) >= ALERT_WARN_DELAY then
				guardian.state = STATE.Aggro
			end
			local t = guardian.target
			if not t or not isAlive(t) then guardian.state = STATE.Patrol; guardian.target = nil end

		elseif guardian.state == STATE.Aggro then
			local t = guardian.target
			if not t or not isAlive(t) then guardian.state = STATE.Leash; guardian.target = nil; continue end
			local tPos = playerRootPosition(t)
			if not tPos then guardian.state = STATE.Leash; guardian.target = nil; continue end
			if (myPos - guardian.postPosition).Magnitude > guardian.def.leashRange then
				guardian.state = STATE.Leash; guardian.target = nil; continue
			end
			if (myPos - tPos).Magnitude <= guardian.def.attackRange then
				guardian.state = STATE.Combat; continue
			end
			guardian.humanoid.WalkSpeed = guardian.def.moveSpeed
			moveTo(guardian, tPos)

		elseif guardian.state == STATE.Combat then
			local t = guardian.target
			if not t or not isAlive(t) then
				showDialog(guardian, "OnVictory")
				guardian.state = STATE.Leash; guardian.target = nil; continue
			end
			local tPos = playerRootPosition(t)
			if not tPos then guardian.state = STATE.Leash; continue end
			if (myPos - tPos).Magnitude > guardian.def.attackRange * 1.5 then
				guardian.state = STATE.Aggro; continue
			end
			if (myPos - guardian.postPosition).Magnitude > guardian.def.leashRange then
				guardian.state = STATE.Leash; guardian.target = nil; continue
			end
			guardian.humanoid.WalkSpeed = 0
			castAbility(guardian, t)

		elseif guardian.state == STATE.Leash then
			guardian.currentHealth  = guardian.maxHealth
			guardian.humanoid.Health = guardian.humanoid.MaxHealth
			updateHPBar(guardian)
			guardian.humanoid.WalkSpeed = guardian.def.moveSpeed + 4
			if (myPos - guardian.postPosition).Magnitude < PATROL_CHANGE_DIST then
				guardian.state = STATE.Patrol
				patrolTarget   = nextPatrolWaypoint(guardian.postPosition, guardian.def.patrolRadius)
			else
				moveTo(guardian, guardian.postPosition)
			end
		end

		-- Greet master on proximity
		local owner = getOwnerPlayer(guardian.ownerId)
		if owner and isAlive(owner) and guardian.state == STATE.Patrol then
			local ownerPos = playerRootPosition(owner)
			if ownerPos and (myPos - ownerPos).Magnitude < 20 then
				showDialog(guardian, "GreetMaster")
			end
		end
	end
end

--------------------------------------------------------------------------------
-- MODEL BUILDER
--------------------------------------------------------------------------------

local function buildModel(guardian: GuardianInstance): (Model, Humanoid, BasePart, Frame?)
	local def   = guardian.def
	local model = Instance.new("Model")
	model.Name  = "Guardian_" .. guardian.guardianId .. "_" .. guardian.slotIndex

	local root      = Instance.new("Part")
	root.Name       = "HumanoidRootPart"
	root.Size       = Vector3.new(2, 2, 1)
	root.Anchored   = false; root.CanCollide = true
	root.BrickColor = BrickColor.new("Dark grey")
	root.Parent     = model

	local body    = Instance.new("Part")
	body.Name     = "UpperTorso"; body.Size = Vector3.new(2, 3, 1)
	body.Anchored = false; body.CanCollide = false
	body.BrickColor = BrickColor.new("Smoky grey")
	local weld    = Instance.new("WeldConstraint")
	weld.Part0    = root; weld.Part1 = body; weld.Parent = root
	body.Parent   = model

	local hum       = Instance.new("Humanoid")
	hum.MaxHealth   = GuardianConfig.GetScaledHealth(guardian.guardianId, guardian.tombTier)
	hum.Health      = hum.MaxHealth
	hum.WalkSpeed   = def.patrolSpeed
	hum.DisplayName = def.displayName
	hum.Parent      = model

	local bb    = Instance.new("BillboardGui")
	bb.Adornee  = root; bb.Size = UDim2.new(0, 160, 0, 30)
	bb.StudsOffset = Vector3.new(0, 3.5, 0); bb.AlwaysOnTop = false; bb.Parent = model

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size  = UDim2.new(1, 0, 0.6, 0); nameLbl.BackgroundTransparency = 1
	nameLbl.TextColor3 = Color3.fromRGB(255, 220, 80); nameLbl.TextStrokeTransparency = 0.4
	nameLbl.Font  = Enum.Font.GothamBold; nameLbl.TextSize = 13
	nameLbl.Text  = def.icon .. " " .. def.displayName; nameLbl.Parent = bb

	local hpBg  = Instance.new("Frame")
	hpBg.Size   = UDim2.new(1, 0, 0.4, 0); hpBg.Position = UDim2.new(0, 0, 0.6, 0)
	hpBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40); hpBg.BorderSizePixel = 0; hpBg.Parent = bb

	local hpFill = Instance.new("Frame")
	hpFill.Size  = UDim2.new(1, 0, 1, 0)
	hpFill.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
	hpFill.BorderSizePixel  = 0; hpFill.Parent = hpBg

	model.PrimaryPart = root
	return model, hum, root, hpFill
end

--------------------------------------------------------------------------------
-- DAMAGE API
--------------------------------------------------------------------------------

function GuardianAIService.ApplyDamage(instanceKey: string, damage: number): boolean
	local g = activeGuardians[instanceKey]
	if not g or g.state == STATE.Dead then return false end

	g.currentHealth = math.max(0, g.currentHealth - damage)
	g.humanoid.Health = g.currentHealth
	updateHPBar(g)
	showDialog(g, "OnHit")

	if g.currentHealth <= 0 then
		g.state = STATE.Dead
		g.humanoid.Health = 0
		local owner = getOwnerPlayer(g.ownerId)
		if owner and guardianRemotes then
			pcall(function()
				guardianRemotes.GetEvent("GuardianStatusUpdate"):FireClient(owner, {
					slotIndex  = g.slotIndex,
					guardianId = g.guardianId,
					action     = "defeated",
				})
			end)
		end
		task.delay(RESPAWN_DELAY, function()
			local still = activeGuardians[instanceKey]
			if not still then return end
			still.currentHealth   = still.maxHealth
			still.humanoid.Health = still.maxHealth
			still.state           = STATE.Patrol
			still.target          = nil
			updateHPBar(still)
			print(string.format("[GuardianAI] %s respawned slot %d (owner %d).",
				still.guardianId, still.slotIndex, still.ownerId))
		end)
		return true
	end
	return false
end

--------------------------------------------------------------------------------
-- SPAWN / DESPAWN
--------------------------------------------------------------------------------

function GuardianAIService.SpawnGuardian(
	ownerId      : number,
	guardianId   : string,
	slotIndex    : number,
	postPosition : Vector3,
	tombTier     : number
)
	local def = GuardianConfig.Get(guardianId)
	if not def then warn("[GuardianAI] Unknown guardianId: " .. guardianId); return end

	GuardianAIService.DespawnGuardian(ownerId, slotIndex)

	local k        = key(ownerId, slotIndex)
	local scaledHP = GuardianConfig.GetScaledHealth(guardianId, tombTier)

	local guardian: GuardianInstance = {
		instanceKey   = k, ownerId = ownerId, guardianId = guardianId,
		slotIndex     = slotIndex, def = def,
		model         = Instance.new("Model"),
		humanoid      = Instance.new("Humanoid"),
		root          = Instance.new("Part"),
		hpFill        = nil,
		state         = STATE.Patrol, target = nil,
		postPosition  = postPosition, tombTier = tombTier,
		maxHealth     = scaledHP, currentHealth = scaledHP,
		abilityCDs    = {}, lastDialogTick = 0, alertTick = nil, thread = nil,
	}

	local model, hum, root, hpFill = buildModel(guardian)
	guardian.model = model; guardian.humanoid = hum
	guardian.root  = root;  guardian.hpFill   = hpFill

	local tombFolder = workspace:FindFirstChild("Tombs")
		and (workspace.Tombs :: Folder):FindFirstChild(tostring(ownerId))
	model:SetPrimaryPartCFrame(CFrame.new(postPosition))
	model.Parent = tombFolder or workspace

	hum.HealthChanged:Connect(function(newHP: number)
		if newHP < guardian.currentHealth then
			guardian.currentHealth = newHP
			updateHPBar(guardian)
			if newHP <= 0 and guardian.state ~= STATE.Dead then
				guardian.state = STATE.Dead
			end
		end
	end)

	activeGuardians[k] = guardian
	guardian.thread    = task.spawn(runAILoop, guardian)

	print(string.format("[GuardianAI] Spawned %s slot %d owner %d HP %d.",
		guardianId, slotIndex, ownerId, scaledHP))
end

function GuardianAIService.DespawnGuardian(ownerId: number, slotIndex: number)
	local k = key(ownerId, slotIndex)
	local g = activeGuardians[k]
	if not g then return end
	g.state = STATE.Dead
	if g.model and g.model.Parent then g.model:Destroy() end
	activeGuardians[k] = nil
end

function GuardianAIService.DespawnAllForOwner(ownerId: number)
	for k, g in pairs(activeGuardians) do
		if g.ownerId == ownerId then
			g.state = STATE.Dead
			if g.model and g.model.Parent then g.model:Destroy() end
			activeGuardians[k] = nil
		end
	end
end

function GuardianAIService.GetInstanceKey(ownerId: number, slotIndex: number): string
	return key(ownerId, slotIndex)
end

function GuardianAIService.GetActiveKeys(ownerId: number): { string }
	local out: { string } = {}
	for k, g in pairs(activeGuardians) do
		if g.ownerId == ownerId then table.insert(out, k) end
	end
	return out
end

--------------------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------------

function GuardianAIService.Init(pds: any, tbs: any, ses: any, gr: any)
	assert(pds, "[GuardianAIService] PlayerDataService required.")
	assert(tbs, "[GuardianAIService] TombBaseService required.")
	playerDataService  = pds
	tombBaseService    = tbs
	spellEffectService = ses
	guardianRemotes    = gr
	initialized        = true
	print("[GuardianAIService] Initialized.")
end

return GuardianAIService
