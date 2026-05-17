--!strict
-- CombatUI.client.lua  — Phase 2 combat HUD
-- Три системы в одном файле (общий доступ к currentTarget без доп. модулей):
--   1. Таргетинг    — клик мышью по мобу/игроку, target-фрейм сверху слева
--   2. Панель абилок — 6 слотов, хоткеи 1-6, кулдаун-оверлей, fires UseAbility
--   3. Числа урона   — BillboardGui + tween на позиции цели / экранный fallback
--
-- Зависимости: DungeonRemotes, PlayerRemotes, AbilityConfig, ClassConfig (клиент-safe)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SharedRemotes  = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
local DungeonRemotes = require(SharedRemotes:WaitForChild("DungeonRemotes"))
local PlayerRemotes  = require(SharedRemotes:WaitForChild("PlayerRemotes"))
local AbilityConfig  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AbilityConfig"))

-- ── module state ───────────────────────────────────────────────────────────

local currentClass: string? = nil
local slotAbilities: { string } = {}                    -- [slotIndex] = abilityId
local abilityCooldowns: { [string]: number } = {}       -- [abilityId] = endTime (os.clock)

type TargetInfo = {
	targetType  : string,    -- "mob" | "player"
	instanceId  : string?,   -- mob only
	userId      : number?,   -- player only
	model       : Model,
	displayName : string,
	getHpPct    : () -> number,
}
local currentTarget: TargetInfo? = nil

-- ── ScreenGui ─────────────────────────────────────────────────────────────

local screenGui              = Instance.new("ScreenGui")
screenGui.Name               = "CombatUI"
screenGui.ResetOnSpawn       = false
screenGui.IgnoreGuiInset     = false
screenGui.DisplayOrder       = 6     -- above HUD (5) and tracker (4)
screenGui.Enabled            = false
screenGui.Parent             = playerGui

-- ═══════════════════════════════════════════════════════════════════════════
--  1. TARGET FRAME  (top-left, below HUD panel)
-- ═══════════════════════════════════════════════════════════════════════════

local targetFrame                     = Instance.new("Frame")
targetFrame.Name                      = "TargetFrame"
targetFrame.AnchorPoint               = Vector2.new(0, 0)
targetFrame.Position                  = UDim2.new(0, 16, 0, 110)   -- below HUD panel
targetFrame.Size                      = UDim2.fromOffset(220, 54)
targetFrame.BackgroundColor3          = Color3.fromRGB(10, 14, 22)
targetFrame.BackgroundTransparency    = 0.25
targetFrame.BorderSizePixel           = 0
targetFrame.Visible                   = false
targetFrame.Parent                    = screenGui

Instance.new("UICorner", targetFrame).CornerRadius = UDim.new(0, 8)

local tfPad                           = Instance.new("UIPadding")
tfPad.PaddingTop                      = UDim.new(0, 8)
tfPad.PaddingBottom                   = UDim.new(0, 8)
tfPad.PaddingLeft                     = UDim.new(0, 10)
tfPad.PaddingRight                    = UDim.new(0, 10)
tfPad.Parent                          = targetFrame

local targetNameLabel                 = Instance.new("TextLabel")
targetNameLabel.Name                  = "TargetName"
targetNameLabel.Size                  = UDim2.new(1, 0, 0, 18)
targetNameLabel.BackgroundTransparency = 1
targetNameLabel.Font                  = Enum.Font.GothamBold
targetNameLabel.TextSize              = 13
targetNameLabel.TextColor3            = Color3.fromRGB(255, 110, 110)
targetNameLabel.TextXAlignment        = Enum.TextXAlignment.Left
targetNameLabel.Text                  = ""
targetNameLabel.Parent                = targetFrame

local tfHpBg                          = Instance.new("Frame")
tfHpBg.Size                          = UDim2.new(1, 0, 0, 12)
tfHpBg.Position                      = UDim2.fromOffset(0, 24)
tfHpBg.BackgroundColor3              = Color3.fromRGB(40, 10, 10)
tfHpBg.BorderSizePixel               = 0
tfHpBg.Parent                        = targetFrame
Instance.new("UICorner", tfHpBg).CornerRadius = UDim.new(0, 4)

local tfHpFill                        = Instance.new("Frame")
tfHpFill.Name                        = "Fill"
tfHpFill.Size                        = UDim2.fromScale(1, 1)
tfHpFill.BackgroundColor3            = Color3.fromRGB(210, 50, 50)
tfHpFill.BorderSizePixel             = 0
tfHpFill.Parent                      = tfHpBg
Instance.new("UICorner", tfHpFill).CornerRadius = UDim.new(0, 4)

-- ═══════════════════════════════════════════════════════════════════════════
--  2. ABILITY BAR  (bottom-center, 6 slots)
-- ═══════════════════════════════════════════════════════════════════════════

local SLOT_SIZE = 54
local SLOT_GAP  = 6

local abilityBar                      = Instance.new("Frame")
abilityBar.Name                       = "AbilityBar"
abilityBar.AnchorPoint               = Vector2.new(0.5, 1)
abilityBar.Position                  = UDim2.new(0.5, 0, 1, -20)
abilityBar.Size                      = UDim2.fromOffset(
	6 * SLOT_SIZE + 5 * SLOT_GAP + 20,   -- 6 slots + gaps + padding
	SLOT_SIZE + 18
)
abilityBar.BackgroundColor3          = Color3.fromRGB(10, 12, 18)
abilityBar.BackgroundTransparency    = 0.25
abilityBar.BorderSizePixel           = 0
abilityBar.Parent                    = screenGui
Instance.new("UICorner", abilityBar).CornerRadius = UDim.new(0, 10)

local barList                         = Instance.new("UIListLayout")
barList.FillDirection                = Enum.FillDirection.Horizontal
barList.HorizontalAlignment          = Enum.HorizontalAlignment.Center
barList.VerticalAlignment            = Enum.VerticalAlignment.Center
barList.Padding                      = UDim.new(0, SLOT_GAP)
barList.Parent                       = abilityBar

local barPad                          = Instance.new("UIPadding")
barPad.PaddingLeft                   = UDim.new(0, 10)
barPad.PaddingRight                  = UDim.new(0, 10)
barPad.Parent                        = abilityBar

-- Emoji icon map  (text fallback — swap for ImageLabels when you have icons)
local ABILITY_ICONS: { [string]: string } = {
	WARRIOR_TAUNT             = "⚡",  WARRIOR_SHIELD_SLAM      = "🛡",
	WARRIOR_DEFENSIVE_STANCE  = "🔰",  WARRIOR_BATTLE_SHOUT     = "📯",
	WARRIOR_HEROIC_STRIKE     = "⚔",   WARRIOR_WHIRLWIND        = "🌀",
	PALADIN_HOLY_LIGHT        = "✨",  PALADIN_LAY_ON_HANDS     = "🙏",
	PALADIN_DIVINE_SHIELD     = "💫",  PALADIN_CONSECRATION     = "✝",
	PALADIN_HAMMER_OF_JUSTICE = "🔨",
	MAGE_FIREBALL             = "🔥",  MAGE_ARCANE_BLAST        = "💠",
	MAGE_FROST_NOVA           = "❄",   MAGE_MANA_SHIELD         = "🔮",
	MAGE_BLINK                = "⚡",
	PRIEST_FLASH_HEAL         = "💚",  PRIEST_RENEW             = "🌿",
	PRIEST_PRAYER_OF_HEALING  = "🕊",  PRIEST_POWER_WORD_SHIELD = "🔵",
	PRIEST_SMITE              = "🌟",
	ROGUE_SINISTER_STRIKE     = "🗡",  ROGUE_BACKSTAB           = "🔪",
	ROGUE_EVISCERATE          = "💀",  ROGUE_KIDNEY_SHOT        = "👊",
	ROGUE_VANISH              = "👁",
	HUNTER_AIMED_SHOT         = "🏹",  HUNTER_SERPENT_STING     = "🐍",
	HUNTER_HUNTERS_MARK       = "🎯",  HUNTER_MULTI_SHOT        = "↯",
	HUNTER_RAPID_FIRE         = "💨",
	SHARED_SECOND_WIND        = "💨",
}

-- Per-slot widget bundle
type SlotData = {
	frame     : Frame,
	icon      : TextLabel,
	hotkeyLbl : TextLabel,
	cdOverlay : Frame,
	cdLabel   : TextLabel,
}
local slots: { SlotData } = {}

local function makeSlot(index: number): SlotData
	local frame                           = Instance.new("Frame")
	frame.Name                            = "Slot" .. index
	frame.Size                            = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)
	frame.BackgroundColor3               = Color3.fromRGB(22, 28, 40)
	frame.BorderSizePixel                = 0
	frame.Parent                         = abilityBar
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

	local icon                            = Instance.new("TextLabel")
	icon.Name                             = "Icon"
	icon.Size                             = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency          = 1
	icon.Font                            = Enum.Font.GothamBold
	icon.TextSize                        = 22
	icon.TextColor3                      = Color3.fromRGB(180, 180, 200)
	icon.Text                            = "—"
	icon.Parent                          = frame

	local hotkeyLbl                       = Instance.new("TextLabel")
	hotkeyLbl.Name                        = "Hotkey"
	hotkeyLbl.Size                        = UDim2.fromOffset(14, 14)
	hotkeyLbl.AnchorPoint                = Vector2.new(0, 0)
	hotkeyLbl.Position                   = UDim2.fromOffset(3, 3)
	hotkeyLbl.BackgroundTransparency     = 1
	hotkeyLbl.Font                       = Enum.Font.GothamBold
	hotkeyLbl.TextSize                   = 10
	hotkeyLbl.TextColor3                 = Color3.fromRGB(130, 130, 160)
	hotkeyLbl.Text                       = tostring(index)
	hotkeyLbl.Parent                     = frame

	local cdOverlay                       = Instance.new("Frame")
	cdOverlay.Name                        = "CDOverlay"
	cdOverlay.Size                        = UDim2.fromScale(1, 1)
	cdOverlay.BackgroundColor3           = Color3.fromRGB(0, 0, 0)
	cdOverlay.BackgroundTransparency     = 0.45
	cdOverlay.BorderSizePixel            = 0
	cdOverlay.Visible                    = false
	cdOverlay.ZIndex                     = 2
	cdOverlay.Parent                     = frame
	Instance.new("UICorner", cdOverlay).CornerRadius = UDim.new(0, 8)

	local cdLabel                         = Instance.new("TextLabel")
	cdLabel.Name                          = "CDLabel"
	cdLabel.Size                          = UDim2.fromScale(1, 1)
	cdLabel.BackgroundTransparency       = 1
	cdLabel.Font                         = Enum.Font.GothamBold
	cdLabel.TextSize                     = 17
	cdLabel.TextColor3                   = Color3.fromRGB(255, 255, 255)
	cdLabel.Text                         = ""
	cdLabel.ZIndex                       = 3
	cdLabel.Parent                       = cdOverlay

	return { frame = frame, icon = icon, hotkeyLbl = hotkeyLbl,
	         cdOverlay = cdOverlay, cdLabel = cdLabel }
end

for i = 1, 6 do
	slots[i] = makeSlot(i)
end

-- ── ability list builder ───────────────────────────────────────────────────

local function buildAbilityList(className: string): { string }
	local defs = AbilityConfig.GetClassAbilities(className)
	-- Sort by requiredLevel ascending
	table.sort(defs, function(a, b)
		return (a.requiredLevel or 0) < (b.requiredLevel or 0)
	end)
	local ids: { string } = {}
	for _, def in ipairs(defs) do
		if #ids >= 5 then break end
		table.insert(ids, def.id)
	end
	-- Slot 6 is always the shared utility
	table.insert(ids, "SHARED_SECOND_WIND")
	-- Pad to 6 with empty
	while #ids < 6 do
		table.insert(ids, "")
	end
	return ids
end

local function applyAbilityToSlot(slotIndex: number, abilityId: string)
	local slot = slots[slotIndex]
	if not slot then return end

	if abilityId == "" then
		slot.icon.Text       = "—"
		slot.icon.TextColor3 = Color3.fromRGB(60, 60, 80)
		slot.frame.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
		return
	end

	local def = AbilityConfig.GetAbility(abilityId)
	slot.icon.Text           = ABILITY_ICONS[abilityId] or (def and def.name:sub(1, 4)) or "?"
	slot.icon.TextColor3     = Color3.fromRGB(220, 220, 240)
	slot.frame.BackgroundColor3 = Color3.fromRGB(28, 36, 52)
end

local function initAbilityBar(className: string)
	slotAbilities = buildAbilityList(className)
	for i = 1, 6 do
		applyAbilityToSlot(i, slotAbilities[i] or "")
	end
end

-- ── cooldown overlay loop ──────────────────────────────────────────────────

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for i, slot in ipairs(slots) do
		local abilityId = slotAbilities[i] or ""
		if abilityId == "" then
			slot.cdOverlay.Visible = false
			continue
		end
		local endTime = abilityCooldowns[abilityId]
		if endTime and endTime > now then
			local rem = endTime - now
			slot.cdOverlay.Visible = true
			slot.cdLabel.Text      = if rem >= 10
				then string.format("%d", math.ceil(rem))
				else string.format("%.1f", rem)
		else
			slot.cdOverlay.Visible = false
			slot.cdLabel.Text      = ""
		end
	end
end)

-- ═══════════════════════════════════════════════════════════════════════════
--  3. TARGETING SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════

local camera = workspace.CurrentCamera

-- Walk up ancestors to find a Model tagged as a mob
local function findMobModel(hit: BasePart): Model?
	local inst: Instance? = hit
	while inst and inst ~= workspace do
		if inst:IsA("Model") then
			local attr = inst:GetAttribute("MobInstanceId")
			if type(attr) == "string" and attr ~= "" then
				return inst :: Model
			end
		end
		inst = inst.Parent
	end
	return nil
end

-- Walk up ancestors to find an enemy player's character
local function findEnemyPlayer(hit: BasePart): Player?
	local inst: Instance? = hit
	while inst and inst ~= workspace do
		if inst:IsA("Model") then
			local p = Players:GetPlayerFromCharacter(inst :: Model)
			if p and p ~= player then return p end
		end
		inst = inst.Parent
	end
	return nil
end

local function setTarget(tgt: TargetInfo?)
	currentTarget = tgt
	if not tgt then
		targetFrame.Visible = false
		return
	end
	targetNameLabel.Text = tgt.displayName
	targetFrame.Visible  = true
end

-- Target HP bar update
RunService.RenderStepped:Connect(function()
	-- Auto-clear stale mob target (model removed from workspace on death)
	if currentTarget and currentTarget.targetType == "mob" then
		if not currentTarget.model or not currentTarget.model.Parent then
			setTarget(nil)
			return
		end
	end
	if currentTarget then
		local pct = currentTarget.getHpPct()
		tfHpFill.Size = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0)
	end
end)

-- Click-to-target
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

	local mousePos = UserInputService:GetMouseLocation()
	local unitRay  = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

	local rayParams                          = RaycastParams.new()
	rayParams.FilterType                     = Enum.RaycastFilterType.Exclude
	local myChar = player.Character
	if myChar then
		rayParams.FilterDescendantsInstances = { myChar }
	end

	local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 250, rayParams)
	if not result then
		setTarget(nil)
		return
	end

	local hitPart = result.Instance :: BasePart

	-- Check for mob first
	local mobModel = findMobModel(hitPart)
	if mobModel then
		local instanceId = mobModel:GetAttribute("MobInstanceId") :: string
		local hum = mobModel:FindFirstChildOfClass("Humanoid")
		setTarget({
			targetType  = "mob",
			instanceId  = instanceId,
			userId      = nil,
			model       = mobModel,
			displayName = mobModel.Name,
			getHpPct    = function()
				if not hum then return 0 end
				return math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
			end,
		})
		return
	end

	-- Check for enemy player
	local enemyPlayer = findEnemyPlayer(hitPart)
	if enemyPlayer then
		local char = enemyPlayer.Character
		local hum  = char and char:FindFirstChildOfClass("Humanoid")
		setTarget({
			targetType  = "player",
			instanceId  = nil,
			userId      = enemyPlayer.UserId,
			model       = char :: Model,
			displayName = enemyPlayer.DisplayName or enemyPlayer.Name,
			getHpPct    = function()
				if not hum then return 0 end
				return math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
			end,
		})
		return
	end

	-- Click on terrain / environment → clear target
	setTarget(nil)
end)

-- ═══════════════════════════════════════════════════════════════════════════
--  4. ABILITY FIRING + HOTKEYS
-- ═══════════════════════════════════════════════════════════════════════════

local useAbilityEvent = DungeonRemotes.GetEvent("UseAbility")

local function fireAbility(slotIndex: number)
	local abilityId = slotAbilities[slotIndex] or ""
	if abilityId == "" then return end

	-- Client-side early-out if cooldown clearly hasn't expired
	local endTime = abilityCooldowns[abilityId]
	if endTime and endTime > os.clock() then return end

	-- Build targetInfo from currentTarget
	local targetInfo: { [string]: any }? = nil
	local tgt = currentTarget
	if tgt then
		if tgt.targetType == "mob" and tgt.instanceId then
			targetInfo = { targetType = "mob", instanceId = tgt.instanceId }
		elseif tgt.targetType == "player" and tgt.userId then
			targetInfo = { targetType = "player", userId = tgt.userId }
		end
	end

	useAbilityEvent:FireServer(abilityId, targetInfo)
end

local HOTKEY_MAP: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One]   = 1,
	[Enum.KeyCode.Two]   = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four]  = 4,
	[Enum.KeyCode.Five]  = 5,
	[Enum.KeyCode.Six]   = 6,
}

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	local idx = HOTKEY_MAP[input.KeyCode]
	if idx then fireAbility(idx) end
end)

-- ═══════════════════════════════════════════════════════════════════════════
--  5. FLOATING DAMAGE NUMBERS
-- ═══════════════════════════════════════════════════════════════════════════

local function spawnWorldNumber(text: string, color: Color3, worldPos: Vector3)
	-- Temporary invisible anchor part
	local anchor           = Instance.new("Part")
	anchor.Anchored        = true
	anchor.CanCollide      = false
	anchor.Transparency    = 1
	anchor.Size            = Vector3.one
	anchor.CFrame          = CFrame.new(worldPos)
	anchor.Parent          = workspace

	local billboard               = Instance.new("BillboardGui")
	billboard.Size                = UDim2.fromOffset(110, 44)
	billboard.StudsOffset         = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop         = true
	billboard.Parent              = anchor

	local label                   = Instance.new("TextLabel")
	label.Size                    = UDim2.fromScale(1, 1)
	label.BackgroundTransparency  = 1
	label.Font                    = Enum.Font.GothamBold
	label.TextSize                = 26
	label.TextColor3              = color
	label.TextStrokeTransparency  = 0.25
	label.Text                    = text
	label.Parent                  = billboard

	-- Float up + fade
	local floatGoal = CFrame.new(worldPos + Vector3.new(math.random(-15, 15) * 0.1, 5, 0))
	TweenService:Create(anchor, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = floatGoal
	}):Play()
	TweenService:Create(label, TweenInfo.new(1.1), {
		TextTransparency      = 1,
		TextStrokeTransparency = 1,
	}):Play()

	task.delay(1.2, function()
		anchor:Destroy()
	end)
end

local function spawnScreenNumber(text: string, color: Color3)
	local label                   = Instance.new("TextLabel")
	label.Size                    = UDim2.fromOffset(130, 44)
	label.AnchorPoint             = Vector2.new(0.5, 0.5)
	label.Position                = UDim2.new(
		0.5, math.random(-50, 50),
		0.42, math.random(-20, 0)
	)
	label.BackgroundTransparency  = 1
	label.Font                    = Enum.Font.GothamBold
	label.TextSize                = 28
	label.TextColor3              = color
	label.TextStrokeTransparency  = 0.25
	label.Text                    = text
	label.ZIndex                  = 10
	label.Parent                  = screenGui

	TweenService:Create(label, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position            = UDim2.new(0.5, math.random(-50, 50), 0.32, -20),
		TextTransparency    = 1,
		TextStrokeTransparency = 1,
	}):Play()

	task.delay(1.2, function()
		label:Destroy()
	end)
end

local function spawnDamageNumber(amount: number, isHeal: boolean, worldPos: Vector3?)
	local text: string
	local color: Color3
	if isHeal then
		text  = "+" .. tostring(amount)
		color = Color3.fromRGB(100, 240, 110)
	else
		text  = "-" .. tostring(amount)
		color = Color3.fromRGB(255, 225, 60)
	end

	if worldPos then
		spawnWorldNumber(text, color, worldPos)
	else
		spawnScreenNumber(text, color)
	end
end

-- ── remote listeners ──────────────────────────────────────────────────────

-- Ability landed on server
DungeonRemotes.GetEvent("CombatResult").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" or not payload.ok then return end

	local abilityId  = payload.abilityId or ""
	local amount     = tonumber(payload.amount) or 0
	local effectType = payload.effectType or "Damage"   -- added in ServerHandlers

	-- Start local cooldown tracking
	if abilityId ~= "" then
		local def = AbilityConfig.GetAbility(abilityId)
		if def and (def.cooldown or 0) > 0 then
			abilityCooldowns[abilityId] = os.clock() + def.cooldown
		end
	end

	if amount > 0 then
		local isHeal = (effectType == "Heal") or (effectType == "ResourceGain")
		local worldPos: Vector3? = nil
		local tgt = currentTarget
		if tgt and tgt.model and tgt.model.Parent then
			local root = tgt.model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then worldPos = root.Position end
		end
		spawnDamageNumber(amount, isHeal, worldPos)
	end
end)

-- Player took damage from a mob (red number on screen, no world pos needed)
PlayerRemotes.GetEvent("MobDamaged").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	local amount = tonumber(payload.amount) or 0
	if amount > 0 then
		spawnScreenNumber("-" .. tostring(amount), Color3.fromRGB(255, 60, 60))
	end
end)

-- ── initial data ──────────────────────────────────────────────────────────

PlayerRemotes.GetEvent("SendInitialData").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	local cls = payload.selectedClass
	if type(cls) == "string" and cls ~= "" then
		currentClass = cls
		initAbilityBar(cls)
	end
	screenGui.Enabled = true
end)

PlayerRemotes.GetEvent("SyncStats").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	local cls = payload.selectedClass
	if type(cls) == "string" and cls ~= "" and cls ~= currentClass then
		currentClass = cls
		initAbilityBar(cls)
	end
end)
