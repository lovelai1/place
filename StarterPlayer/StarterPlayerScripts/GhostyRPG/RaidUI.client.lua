--!strict
--------------------------------------------------------------------------------
-- GhostyRPG | RaidUI.client.lua
-- StarterPlayerScripts/GhostyRPG/RaidUI.client.lua
--
-- HUD рейда:
--   • HP-бары всех участников группы (сетка 2×5)
--   • HP-бар текущего босса с меткой фазы
--   • Таймер обратного отсчёта
--   • Индикатор механики («Беги от красного круга!»)
--   • Диалоговая строка босса
--
-- Слушает RaidRemotes события:
--   RaidStarted       → { raidRunId, timerSecs }
--   RaidCompleted     → { raidRunId, elapsed, wipes }
--   RaidFailed        → { raidRunId, reason, wipes }
--   BossPhaseChanged  → { raidRunId, bossId, newPhase, phaseLabel, dialogue, mechanics }
--   BossDied          → { raidRunId, bossId }
--   BossDialog        → { bossId, line }
--
-- Также слушает PartyRemotes для синхронизации HP-баров участников.
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SharedRemotes = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
local RaidRemotes   = require(SharedRemotes:WaitForChild("RaidRemotes"))
local PartyRemotes  = require(SharedRemotes:WaitForChild("PartyRemotes"))

--------------------------------------------------------------------------------
-- COLOUR PALETTE
--------------------------------------------------------------------------------

local C = {
	BG        = Color3.fromRGB(8,  10, 16),
	PANEL     = Color3.fromRGB(16, 20, 30),
	CARD      = Color3.fromRGB(22, 28, 42),
	TEXT      = Color3.fromRGB(220, 215, 235),
	TEXT_DIM  = Color3.fromRGB(120, 115, 135),
	HP_HIGH   = Color3.fromRGB(60,  200, 90),
	HP_MID    = Color3.fromRGB(230, 180, 40),
	HP_LOW    = Color3.fromRGB(220, 60,  60),
	BOSS_HP   = Color3.fromRGB(200, 50,  50),
	BOSS_PH1  = Color3.fromRGB(200, 50,  50),
	BOSS_PH2  = Color3.fromRGB(220, 120, 30),
	BOSS_PH3  = Color3.fromRGB(160, 30,  200),
	TIMER_OK  = Color3.fromRGB(220, 215, 235),
	TIMER_WARN = Color3.fromRGB(230, 80,  50),
	MECH_BG   = Color3.fromRGB(180, 40,  30),
	MECH_TEXT = Color3.fromRGB(255, 240, 80),
	BORDER    = Color3.fromRGB(45,  40,  65),
	DIALOG_BG = Color3.fromRGB(20,  12,  35),
	DIALOG_TEXT = Color3.fromRGB(200, 170, 240),
}

local PHASE_COLORS: { [number]: Color3 } = {
	[1] = C.BOSS_PH1,
	[2] = C.BOSS_PH2,
	[3] = C.BOSS_PH3,
}

local TWEEN_FAST = TweenInfo.new(0.2,  Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_MED  = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_SLOW = TweenInfo.new(1.5,  Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function makeCorner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function makeStroke(parent: Instance, col: Color3, thick: number)
	local s = Instance.new("UIStroke")
	s.Color     = col
	s.Thickness = thick
	s.Parent    = parent
end

local function makePad(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop    = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft   = UDim.new(0, px)
	p.PaddingRight  = UDim.new(0, px)
	p.Parent = parent
end

local function hpColor(pct: number): Color3
	if pct > 0.5 then
		return C.HP_HIGH:Lerp(C.HP_MID, (1 - pct) * 2)
	else
		return C.HP_MID:Lerp(C.HP_LOW, (0.5 - pct) * 2)
	end
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

--------------------------------------------------------------------------------
-- SCREEN GUI
--------------------------------------------------------------------------------

local screenGui             = Instance.new("ScreenGui")
screenGui.Name              = "RaidUI"
screenGui.ResetOnSpawn      = false
screenGui.IgnoreGuiInset    = false
screenGui.DisplayOrder      = 15
screenGui.Enabled           = false
screenGui.Parent            = playerGui

--------------------------------------------------------------------------------
-- BOSS HP BAR (top-center)
--------------------------------------------------------------------------------

local bossPanel             = Instance.new("Frame")
bossPanel.Name              = "BossPanel"
bossPanel.AnchorPoint       = Vector2.new(0.5, 0)
bossPanel.Position          = UDim2.new(0.5, 0, 0, 12)
bossPanel.Size              = UDim2.fromOffset(500, 70)
bossPanel.BackgroundColor3  = C.PANEL
bossPanel.BorderSizePixel   = 0
bossPanel.Parent            = screenGui
makeCorner(bossPanel, 8)
makeStroke(bossPanel, C.BORDER, 1)
makePad(bossPanel, 10)

local bossNameLabel         = Instance.new("TextLabel")
bossNameLabel.Name          = "BossName"
bossNameLabel.Text          = "???"
bossNameLabel.TextSize      = 15
bossNameLabel.Font          = Enum.Font.GothamBold
bossNameLabel.TextColor3    = Color3.new(1, 1, 1)
bossNameLabel.BackgroundTransparency = 1
bossNameLabel.Size          = UDim2.new(0.65, 0, 0, 20)
bossNameLabel.TextXAlignment = Enum.TextXAlignment.Left
bossNameLabel.Parent        = bossPanel

local bossPhaseLabel        = Instance.new("TextLabel")
bossPhaseLabel.Name         = "BossPhase"
bossPhaseLabel.Text         = "Phase 1"
bossPhaseLabel.TextSize     = 12
bossPhaseLabel.Font         = Enum.Font.GothamBold
bossPhaseLabel.TextColor3   = C.BOSS_PH1
bossPhaseLabel.BackgroundTransparency = 1
bossPhaseLabel.Size         = UDim2.new(0.35, 0, 0, 20)
bossPhaseLabel.Position     = UDim2.new(0.65, 0, 0, 0)
bossPhaseLabel.TextXAlignment = Enum.TextXAlignment.Right
bossPhaseLabel.Parent       = bossPanel

-- HP bar track
local bossHpTrack           = Instance.new("Frame")
bossHpTrack.Name            = "HpTrack"
bossHpTrack.Size            = UDim2.new(1, 0, 0, 14)
bossHpTrack.Position        = UDim2.new(0, 0, 0, 24)
bossHpTrack.BackgroundColor3 = Color3.fromRGB(30, 20, 30)
bossHpTrack.BorderSizePixel = 0
bossHpTrack.Parent          = bossPanel
makeCorner(bossHpTrack, 4)

local bossHpBar             = Instance.new("Frame")
bossHpBar.Name              = "HpBar"
bossHpBar.Size              = UDim2.fromScale(1, 1)
bossHpBar.BackgroundColor3  = C.BOSS_HP
bossHpBar.BorderSizePixel   = 0
bossHpBar.Parent            = bossHpTrack
makeCorner(bossHpBar, 4)

local bossHpText            = Instance.new("TextLabel")
bossHpText.Name             = "HpText"
bossHpText.Text             = "100%"
bossHpText.TextSize         = 11
bossHpText.Font             = Enum.Font.GothamBold
bossHpText.TextColor3       = Color3.new(1, 1, 1)
bossHpText.BackgroundTransparency = 1
bossHpText.Size             = UDim2.fromScale(1, 1)
bossHpText.TextXAlignment   = Enum.TextXAlignment.Center
bossHpText.Parent           = bossHpTrack

-- HP percentage markers (25% / 50% / 75%)
for _, pct in ipairs({ 0.25, 0.5, 0.75 }) do
	local marker            = Instance.new("Frame")
	marker.Size             = UDim2.new(0, 2, 1, 0)
	marker.Position         = UDim2.new(pct, -1, 0, 0)
	marker.BackgroundColor3 = Color3.fromRGB(200, 200, 220)
	marker.BackgroundTransparency = 0.5
	marker.BorderSizePixel  = 0
	marker.ZIndex           = bossHpBar.ZIndex + 1
	marker.Parent           = bossHpTrack
end

-- Wipe counter
local wipeLabel             = Instance.new("TextLabel")
wipeLabel.Name              = "WipeLabel"
wipeLabel.Text              = "Wipes: 0"
wipeLabel.TextSize          = 12
wipeLabel.Font              = Enum.Font.Gotham
wipeLabel.TextColor3        = C.TEXT_DIM
wipeLabel.BackgroundTransparency = 1
wipeLabel.Size              = UDim2.new(1, 0, 0, 16)
wipeLabel.Position          = UDim2.new(0, 0, 0, 42)
wipeLabel.TextXAlignment    = Enum.TextXAlignment.Left
wipeLabel.Parent            = bossPanel

--------------------------------------------------------------------------------
-- TIMER (top-right corner)
--------------------------------------------------------------------------------

local timerPanel            = Instance.new("Frame")
timerPanel.Name             = "TimerPanel"
timerPanel.AnchorPoint      = Vector2.new(1, 0)
timerPanel.Position         = UDim2.new(1, -12, 0, 12)
timerPanel.Size             = UDim2.fromOffset(120, 50)
timerPanel.BackgroundColor3 = C.PANEL
timerPanel.BorderSizePixel  = 0
timerPanel.Parent           = screenGui
makeCorner(timerPanel, 8)
makeStroke(timerPanel, C.BORDER, 1)

local timerIcon             = Instance.new("TextLabel")
timerIcon.Text              = "⏱"
timerIcon.TextSize          = 14
timerIcon.Font              = Enum.Font.GothamBold
timerIcon.TextColor3        = C.TEXT_DIM
timerIcon.BackgroundTransparency = 1
timerIcon.Size              = UDim2.fromOffset(30, 50)
timerIcon.TextXAlignment    = Enum.TextXAlignment.Center
timerIcon.Parent            = timerPanel

local timerLabel            = Instance.new("TextLabel")
timerLabel.Name             = "TimerLabel"
timerLabel.Text             = "00:00"
timerLabel.TextSize         = 22
timerLabel.Font             = Enum.Font.GothamBold
timerLabel.TextColor3       = C.TIMER_OK
timerLabel.BackgroundTransparency = 1
timerLabel.Size             = UDim2.new(1, -34, 1, 0)
timerLabel.Position         = UDim2.fromOffset(30, 0)
timerLabel.TextXAlignment   = Enum.TextXAlignment.Left
timerLabel.Parent           = timerPanel

--------------------------------------------------------------------------------
-- PARTY HP BARS (bottom-left grid)
--------------------------------------------------------------------------------

local MAX_MEMBERS = 10

local partyPanel            = Instance.new("Frame")
partyPanel.Name             = "PartyPanel"
partyPanel.AnchorPoint      = Vector2.new(0, 1)
partyPanel.Position         = UDim2.new(0, 12, 1, -12)
partyPanel.Size             = UDim2.fromOffset(260, 230)
partyPanel.BackgroundColor3 = C.PANEL
partyPanel.BackgroundTransparency = 0.1
partyPanel.BorderSizePixel  = 0
partyPanel.Parent           = screenGui
makeCorner(partyPanel, 8)
makeStroke(partyPanel, C.BORDER, 1)
makePad(partyPanel, 8)

local partyTitle            = Instance.new("TextLabel")
partyTitle.Text             = "Raid Members"
partyTitle.TextSize         = 12
partyTitle.Font             = Enum.Font.GothamBold
partyTitle.TextColor3       = C.TEXT_DIM
partyTitle.BackgroundTransparency = 1
partyTitle.Size             = UDim2.new(1, 0, 0, 18)
partyTitle.TextXAlignment   = Enum.TextXAlignment.Left
partyTitle.Parent           = partyPanel

local partyGrid             = Instance.new("Frame")
partyGrid.Name              = "PartyGrid"
partyGrid.Size              = UDim2.new(1, 0, 1, -22)
partyGrid.Position          = UDim2.fromOffset(0, 22)
partyGrid.BackgroundTransparency = 1
partyGrid.Parent            = partyPanel

local partyLayout           = Instance.new("UIGridLayout")
partyLayout.CellSize        = UDim2.fromOffset(112, 36)
partyLayout.CellPaddingH    = UDim.new(0, 6)
partyLayout.CellPaddingV    = UDim.new(0, 5)
partyLayout.SortOrder       = Enum.SortOrder.LayoutOrder
partyLayout.FillDirection   = Enum.FillDirection.Horizontal
partyLayout.Parent          = partyGrid

-- Pre-create member bar slots
type MemberBar = {
	frame    : Frame,
	nameLabel: TextLabel,
	hpTrack  : Frame,
	hpBar    : Frame,
	hpLabel  : TextLabel,
}
local memberBars: { MemberBar } = {}

for i = 1, MAX_MEMBERS do
	local slot              = Instance.new("Frame")
	slot.Name               = "Slot_" .. i
	slot.BackgroundColor3   = C.CARD
	slot.BorderSizePixel    = 0
	slot.LayoutOrder        = i
	slot.Visible            = false
	slot.Parent             = partyGrid
	makeCorner(slot, 5)
	makePad(slot, 4)

	local nameL             = Instance.new("TextLabel")
	nameL.Text              = "Player"
	nameL.TextSize          = 11
	nameL.Font              = Enum.Font.GothamBold
	nameL.TextColor3        = C.TEXT
	nameL.BackgroundTransparency = 1
	nameL.Size              = UDim2.new(1, 0, 0, 14)
	nameL.TextXAlignment    = Enum.TextXAlignment.Left
	nameL.TextTruncate      = Enum.TextTruncate.AtEnd
	nameL.Parent            = slot

	local track             = Instance.new("Frame")
	track.Size              = UDim2.new(1, 0, 0, 8)
	track.Position          = UDim2.new(0, 0, 0, 16)
	track.BackgroundColor3  = Color3.fromRGB(30, 25, 40)
	track.BorderSizePixel   = 0
	track.Parent            = slot
	makeCorner(track, 3)

	local bar               = Instance.new("Frame")
	bar.Size                = UDim2.fromScale(1, 1)
	bar.BackgroundColor3    = C.HP_HIGH
	bar.BorderSizePixel     = 0
	bar.Parent              = track
	makeCorner(bar, 3)

	local hpLbl             = Instance.new("TextLabel")
	hpLbl.Text              = "100%"
	hpLbl.TextSize          = 9
	hpLbl.Font              = Enum.Font.Gotham
	hpLbl.TextColor3        = C.TEXT_DIM
	hpLbl.BackgroundTransparency = 1
	hpLbl.Size              = UDim2.new(1, 0, 0, 10)
	hpLbl.Position          = UDim2.new(0, 0, 0, 25)
	hpLbl.TextXAlignment    = Enum.TextXAlignment.Right
	hpLbl.Parent            = slot

	memberBars[i] = {
		frame     = slot,
		nameLabel = nameL,
		hpTrack   = track,
		hpBar     = bar,
		hpLabel   = hpLbl,
	}
end

--------------------------------------------------------------------------------
-- MECHANIC ALERT (center-bottom flash)
--------------------------------------------------------------------------------

local mechAlert             = Instance.new("Frame")
mechAlert.Name              = "MechAlert"
mechAlert.AnchorPoint       = Vector2.new(0.5, 1)
mechAlert.Position          = UDim2.new(0.5, 0, 1, -110)
mechAlert.Size              = UDim2.fromOffset(520, 56)
mechAlert.BackgroundColor3  = C.MECH_BG
mechAlert.BackgroundTransparency = 1
mechAlert.BorderSizePixel   = 0
mechAlert.Parent            = screenGui
makeCorner(mechAlert, 10)
makeStroke(mechAlert, Color3.fromRGB(255, 80, 40), 2)

local mechText              = Instance.new("TextLabel")
mechText.Name               = "MechText"
mechText.Text               = ""
mechText.TextSize           = 18
mechText.Font               = Enum.Font.GothamBold
mechText.TextColor3         = C.MECH_TEXT
mechText.BackgroundTransparency = 1
mechText.Size               = UDim2.fromScale(1, 1)
mechText.TextXAlignment     = Enum.TextXAlignment.Center
mechText.TextYAlignment     = Enum.TextYAlignment.Center
mechText.Parent             = mechAlert

local mechDismissTimer: thread? = nil

local function showMechanic(text: string, durationSecs: number?)
	local dur = durationSecs or 4

	if mechDismissTimer then task.cancel(mechDismissTimer) end

	mechText.Text = text
	TweenService:Create(mechAlert, TWEEN_FAST, { BackgroundTransparency = 0 }):Play()

	mechDismissTimer = task.delay(dur, function()
		TweenService:Create(mechAlert, TWEEN_MED, { BackgroundTransparency = 1 }):Play()
	end)
end

--------------------------------------------------------------------------------
-- BOSS DIALOGUE (below boss HP bar)
--------------------------------------------------------------------------------

local dialogFrame           = Instance.new("Frame")
dialogFrame.Name            = "DialogFrame"
dialogFrame.AnchorPoint     = Vector2.new(0.5, 0)
dialogFrame.Position        = UDim2.new(0.5, 0, 0, 90)
dialogFrame.Size            = UDim2.fromOffset(500, 36)
dialogFrame.BackgroundColor3 = C.DIALOG_BG
dialogFrame.BackgroundTransparency = 1
dialogFrame.BorderSizePixel = 0
dialogFrame.Parent          = screenGui
makeCorner(dialogFrame, 6)
makePad(dialogFrame, 8)

local dialogText            = Instance.new("TextLabel")
dialogText.Name             = "DialogText"
dialogText.Text             = ""
dialogText.TextSize         = 13
dialogText.Font             = Enum.Font.GothamItalic
dialogText.TextColor3       = C.DIALOG_TEXT
dialogText.BackgroundTransparency = 1
dialogText.Size             = UDim2.fromScale(1, 1)
dialogText.TextXAlignment   = Enum.TextXAlignment.Center
dialogText.TextYAlignment   = Enum.TextYAlignment.Center
dialogText.TextWrapped      = true
dialogText.Parent           = dialogFrame

local dialogTimer: thread?  = nil

local function showDialog(text: string, durationSecs: number?)
	local dur = durationSecs or 5
	if dialogTimer then task.cancel(dialogTimer) end

	dialogText.Text = "\"" .. text .. "\""
	TweenService:Create(dialogFrame, TWEEN_FAST, { BackgroundTransparency = 0.15 }):Play()

	dialogTimer = task.delay(dur, function()
		TweenService:Create(dialogFrame, TWEEN_MED, { BackgroundTransparency = 1 }):Play()
	end)
end

--------------------------------------------------------------------------------
-- RESULT OVERLAY (victory / defeat)
--------------------------------------------------------------------------------

local resultOverlay         = Instance.new("Frame")
resultOverlay.Name          = "ResultOverlay"
resultOverlay.AnchorPoint   = Vector2.new(0.5, 0.5)
resultOverlay.Position      = UDim2.fromScale(0.5, 0.5)
resultOverlay.Size          = UDim2.fromOffset(460, 160)
resultOverlay.BackgroundColor3 = C.BG
resultOverlay.BackgroundTransparency = 1
resultOverlay.BorderSizePixel = 0
resultOverlay.Parent        = screenGui
makeCorner(resultOverlay, 14)

local resultTitle           = Instance.new("TextLabel")
resultTitle.Name            = "ResultTitle"
resultTitle.Text            = ""
resultTitle.TextSize        = 36
resultTitle.Font            = Enum.Font.GothamBold
resultTitle.TextColor3      = Color3.new(1, 1, 1)
resultTitle.BackgroundTransparency = 1
resultTitle.Size            = UDim2.new(1, 0, 0, 50)
resultTitle.Position        = UDim2.fromOffset(0, 30)
resultTitle.TextXAlignment  = Enum.TextXAlignment.Center
resultTitle.Parent          = resultOverlay

local resultSub             = Instance.new("TextLabel")
resultSub.Name              = "ResultSub"
resultSub.Text              = ""
resultSub.TextSize          = 15
resultSub.Font              = Enum.Font.Gotham
resultSub.TextColor3        = C.TEXT_DIM
resultSub.BackgroundTransparency = 1
resultSub.Size              = UDim2.new(1, 0, 0, 30)
resultSub.Position          = UDim2.fromOffset(0, 88)
resultSub.TextXAlignment    = Enum.TextXAlignment.Center
resultSub.Parent            = resultOverlay

local function showResult(title: string, subtitle: string, success: boolean)
	resultTitle.Text       = title
	resultTitle.TextColor3 = if success then C.HP_HIGH else C.HP_LOW
	resultSub.Text         = subtitle
	TweenService:Create(resultOverlay, TWEEN_MED, { BackgroundTransparency = 0.25 }):Play()
	task.delay(6, function()
		TweenService:Create(resultOverlay, TWEEN_SLOW, { BackgroundTransparency = 1 }):Play()
	end)
end

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local currentRaidRunId: string? = nil
local timerEndTime: number      = 0
local timerActive               = false
local wipeCount                 = 0

local memberData: { [number]: { name: string, hp: number, maxHp: number } } = {}
local bossHpPct                 = 1.0
local bossCurrentPhase          = 1

--------------------------------------------------------------------------------
-- UPDATE HP BARS
--------------------------------------------------------------------------------

local function updateMemberBar(index: number)
	local bar = memberBars[index]
	if not bar then return end

	local data = memberData[index]
	if not data then
		bar.frame.Visible = false
		return
	end

	bar.frame.Visible = true
	bar.nameLabel.Text = data.name

	local pct = if data.maxHp > 0 then math.clamp(data.hp / data.maxHp, 0, 1) else 0
	local col = hpColor(pct)
	bar.hpBar.BackgroundColor3 = col
	TweenService:Create(bar.hpBar, TWEEN_FAST, { Size = UDim2.fromScale(pct, 1) }):Play()
	bar.hpLabel.Text = math.floor(pct * 100) .. "%"

	-- Dead styling
	bar.frame.BackgroundTransparency = if pct <= 0 then 0.55 else 0
	bar.nameLabel.TextColor3 = if pct <= 0 then C.TEXT_DIM else C.TEXT
end

local function updateBossHp(pct: number)
	bossHpPct = math.clamp(pct, 0, 1)
	local col = PHASE_COLORS[bossCurrentPhase] or C.BOSS_HP
	TweenService:Create(bossHpBar, TWEEN_FAST, {
		Size             = UDim2.fromScale(bossHpPct, 1),
		BackgroundColor3 = col,
	}):Play()
	bossHpText.Text = math.floor(bossHpPct * 100) .. "%"
end

--------------------------------------------------------------------------------
-- SHOW / HIDE
--------------------------------------------------------------------------------

local function showUI()
	screenGui.Enabled = true
	-- Reset result overlay
	resultOverlay.BackgroundTransparency = 1
	resultTitle.Text = ""
	resultSub.Text   = ""
end

local function hideUI()
	task.delay(6, function()
		screenGui.Enabled = false
	end)
end

local function resetState()
	currentRaidRunId = nil
	timerActive      = false
	wipeCount        = 0
	bossHpPct        = 1.0
	bossCurrentPhase = 1
	table.clear(memberData)
	for i = 1, MAX_MEMBERS do
		if memberBars[i] then
			memberBars[i].frame.Visible = false
		end
	end
	updateBossHp(1)
	bossNameLabel.Text = "???"
	bossPhaseLabel.Text = "Phase 1"
	bossPhaseLabel.TextColor3 = PHASE_COLORS[1]
	wipeLabel.Text = "Wipes: 0"
	timerLabel.Text = "00:00"
	timerLabel.TextColor3 = C.TIMER_OK
	mechAlert.BackgroundTransparency = 1
	dialogFrame.BackgroundTransparency = 1
end

--------------------------------------------------------------------------------
-- TIMER UPDATE LOOP
--------------------------------------------------------------------------------

RunService.Heartbeat:Connect(function()
	if not timerActive then return end
	local remaining = math.max(0, timerEndTime - os.clock())
	local mins      = math.floor(remaining / 60)
	local secs      = math.floor(remaining % 60)
	timerLabel.Text = string.format("%02d:%02d", mins, secs)

	-- Warn when < 60 seconds
	if remaining < 60 then
		timerLabel.TextColor3 = C.TIMER_WARN
		-- Pulse effect
		if math.floor(remaining) % 2 == 0 then
			timerLabel.TextTransparency = 0
		else
			timerLabel.TextTransparency = 0.35
		end
	else
		timerLabel.TextColor3       = C.TIMER_OK
		timerLabel.TextTransparency = 0
	end

	if remaining <= 0 then
		timerActive = false
	end
end)

--------------------------------------------------------------------------------
-- BOSS HP SYNC: derive from BossPhaseChanged + local simulation
-- Real HP sync fires from RaidService via a custom RemoteEvent piggyback
-- We expose a method so other client scripts (or extended RaidRemotes) can call it
--------------------------------------------------------------------------------

local RaidUIController = {}

function RaidUIController.UpdateBossHp(pct: number)
	updateBossHp(pct)
end

function RaidUIController.UpdateMember(index: number, name: string, hp: number, maxHp: number)
	memberData[index] = { name = name, hp = hp, maxHp = maxHp }
	updateMemberBar(index)
end

function RaidUIController.ClearMember(index: number)
	memberData[index] = nil
	updateMemberBar(index)
end

function RaidUIController.ShowMechanic(text: string, dur: number?)
	showMechanic(text, dur)
end

--------------------------------------------------------------------------------
-- RAID REMOTE LISTENERS
--------------------------------------------------------------------------------

-- Raid started
RaidRemotes.GetEvent("RaidStarted").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	currentRaidRunId = payload.raidRunId
	wipeCount        = 0
	wipeLabel.Text   = "Wipes: 0"

	-- Timer
	local dur        = tonumber(payload.timerSecs) or 1800
	timerEndTime     = os.clock() + dur
	timerActive      = true

	showUI()
	bossNameLabel.Text = payload.bossName or "???"
	updateBossHp(1)
	bossCurrentPhase = 1
	bossPhaseLabel.Text = "Phase 1"
	bossPhaseLabel.TextColor3 = PHASE_COLORS[1]
end)

-- Boss phase changed
RaidRemotes.GetEvent("BossPhaseChanged").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	if payload.raidRunId ~= currentRaidRunId then return end

	local phase      = tonumber(payload.newPhase) or 1
	bossCurrentPhase = phase
	local col        = PHASE_COLORS[phase] or C.BOSS_HP
	bossPhaseLabel.Text      = payload.phaseLabel or ("Phase " .. phase)
	bossPhaseLabel.TextColor3 = col

	-- Animate phase change flash on boss bar
	TweenService:Create(bossHpBar, TweenInfo.new(0.1), { BackgroundColor3 = Color3.new(1, 1, 1) }):Play()
	task.delay(0.12, function()
		TweenService:Create(bossHpBar, TWEEN_FAST, { BackgroundColor3 = col }):Play()
	end)

	-- Dialogue
	if type(payload.dialogue) == "string" and #payload.dialogue > 0 then
		showDialog(payload.dialogue)
	end

	-- Mechanics
	if type(payload.mechanics) == "table" then
		for _, mechLine in ipairs(payload.mechanics) do
			if type(mechLine) == "string" then
				showMechanic(mechLine, 6)
				break  -- show first mechanic; subsequent ones override after delay
			end
		end
	end
end)

-- Boss dialogue
RaidRemotes.GetEvent("BossDialog").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	if type(payload.line) == "string" and #payload.line > 0 then
		showDialog(payload.line)
	end
end)

-- Boss died
RaidRemotes.GetEvent("BossDied").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	if payload.raidRunId ~= currentRaidRunId then return end

	updateBossHp(0)
	timerActive = false
end)

-- Raid completed (victory)
RaidRemotes.GetEvent("RaidCompleted").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	timerActive = false

	local elapsed = tonumber(payload.elapsed) or 0
	local mins    = math.floor(elapsed / 60)
	local secs    = math.floor(elapsed % 60)
	local wipes   = tonumber(payload.wipes) or 0

	showResult(
		"🏆  VICTORY",
		string.format("Time: %02d:%02d  •  Wipes: %d", mins, secs, wipes),
		true
	)
	hideUI()
	resetState()
end)

-- Raid failed (wipe / timeout)
RaidRemotes.GetEvent("RaidFailed").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end

	if payload.raidRunId ~= currentRaidRunId then return end

	wipeCount += 1
	wipeLabel.Text = "Wipes: " .. wipeCount

	local reason = tostring(payload.reason or "The raid has failed.")
	showResult("💀  DEFEATED", reason, false)

	timerActive = false
	hideUI()
	resetState()
end)

-- Party HP sync (piggyback PartyRemotes for member HP bars in raid context)
PartyRemotes.GetEvent("PartyUpdated").OnClientEvent:Connect(function(payload: any)
	if not screenGui.Enabled then return end
	if type(payload) ~= "table" or type(payload.members) ~= "table" then return end

	for i, member in ipairs(payload.members) do
		if i > MAX_MEMBERS then break end
		if type(member) == "table" then
			memberData[i] = {
				name  = tostring(member.name or "?"),
				hp    = tonumber(member.hp)    or 0,
				maxHp = tonumber(member.maxHp) or 1,
			}
			updateMemberBar(i)
		end
	end

	-- Hide unused slots
	for i = #payload.members + 1, MAX_MEMBERS do
		memberData[i] = nil
		updateMemberBar(i)
	end
end)

return RaidUIController
