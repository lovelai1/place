--!strict
-- HudUI.client.lua
-- Minimal HUD for GhostyRPG Phase 1:
--   • HP bar (red)            — updates on SyncStats / SyncHealth
--   • Resource bar (coloured) — Mana/Rage/Energy/Focus
--   • Level + Exp text
--   • Gold counter
--   • "EXP gained" toast on ExpGained
-- Appears only after SendInitialData.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SharedRemotes = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
local PlayerRemotes = require(SharedRemotes:WaitForChild("PlayerRemotes"))

-- ── resource colours ─────────────────────────────────────────────────────

local RESOURCE_COLOR: { [string]: Color3 } = {
	Mana   = Color3.fromRGB(90, 140, 240),
	Rage   = Color3.fromRGB(220, 60, 60),
	Energy = Color3.fromRGB(240, 220, 60),
	Focus  = Color3.fromRGB(200, 170, 90),
}
local DEFAULT_RESOURCE_COLOR = Color3.fromRGB(100, 100, 200)

-- ── GUI ───────────────────────────────────────────────────────────────────

local screenGui              = Instance.new("ScreenGui")
screenGui.Name               = "HudUI"
screenGui.ResetOnSpawn       = false
screenGui.IgnoreGuiInset     = false
screenGui.DisplayOrder       = 5
screenGui.Enabled            = false
screenGui.Parent             = playerGui

-- Bottom-left panel
local panel                  = Instance.new("Frame")
panel.Name                   = "HudPanel"
panel.AnchorPoint            = Vector2.new(0, 1)
panel.Position               = UDim2.new(0, 16, 1, -16)
panel.Size                   = UDim2.fromOffset(280, 84)
panel.BackgroundColor3       = Color3.fromRGB(12, 14, 20)
panel.BackgroundTransparency = 0.3
panel.BorderSizePixel        = 0
panel.Parent                 = screenGui

local panelCorner            = Instance.new("UICorner")
panelCorner.CornerRadius     = UDim.new(0, 10)
panelCorner.Parent           = panel

local pad                    = Instance.new("UIPadding")
pad.PaddingTop               = UDim.new(0, 10)
pad.PaddingLeft              = UDim.new(0, 12)
pad.PaddingRight             = UDim.new(0, 12)
pad.PaddingBottom            = UDim.new(0, 10)
pad.Parent                   = panel

-- Class / level / gold line
local infoLine               = Instance.new("TextLabel")
infoLine.Name                = "InfoLine"
infoLine.Size                = UDim2.new(1, 0, 0, 16)
infoLine.Position            = UDim2.fromOffset(0, 0)
infoLine.BackgroundTransparency = 1
infoLine.Font                = Enum.Font.GothamBold
infoLine.TextSize            = 13
infoLine.TextColor3          = Color3.fromRGB(220, 220, 240)
infoLine.TextXAlignment      = Enum.TextXAlignment.Left
infoLine.Text                = "Lv.? — Gold: 0"
infoLine.Parent              = panel

-- HP bar background + fill
local hpBg                   = Instance.new("Frame")
hpBg.Name                    = "HpBg"
hpBg.Size                    = UDim2.new(1, 0, 0, 14)
hpBg.Position                = UDim2.fromOffset(0, 22)
hpBg.BackgroundColor3        = Color3.fromRGB(40, 10, 10)
hpBg.BorderSizePixel         = 0
hpBg.Parent                  = panel

Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 4)

local hpFill                 = Instance.new("Frame")
hpFill.Name                  = "HpFill"
hpFill.Size                  = UDim2.fromScale(1, 1)
hpFill.BackgroundColor3      = Color3.fromRGB(220, 50, 50)
hpFill.BorderSizePixel       = 0
hpFill.Parent                = hpBg

Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 4)

local hpLabel                = Instance.new("TextLabel")
hpLabel.Name                 = "HpLabel"
hpLabel.Size                 = UDim2.fromScale(1, 1)
hpLabel.BackgroundTransparency = 1
hpLabel.Font                 = Enum.Font.GothamBold
hpLabel.TextSize             = 11
hpLabel.TextColor3           = Color3.fromRGB(255, 255, 255)
hpLabel.TextStrokeTransparency = 0.5
hpLabel.Text                 = "HP: 100 / 100"
hpLabel.Parent               = hpBg

-- Resource bar
local resBg                  = Instance.new("Frame")
resBg.Name                   = "ResBg"
resBg.Size                   = UDim2.new(1, 0, 0, 14)
resBg.Position               = UDim2.fromOffset(0, 42)
resBg.BackgroundColor3       = Color3.fromRGB(10, 10, 40)
resBg.BorderSizePixel        = 0
resBg.Parent                 = panel

Instance.new("UICorner", resBg).CornerRadius = UDim.new(0, 4)

local resFill                = Instance.new("Frame")
resFill.Name                 = "ResFill"
resFill.Size                 = UDim2.fromScale(1, 1)
resFill.BackgroundColor3     = RESOURCE_COLOR.Mana
resFill.BorderSizePixel      = 0
resFill.Parent               = resBg

Instance.new("UICorner", resFill).CornerRadius = UDim.new(0, 4)

local resLabel               = Instance.new("TextLabel")
resLabel.Name                = "ResLabel"
resLabel.Size                = UDim2.fromScale(1, 1)
resLabel.BackgroundTransparency = 1
resLabel.Font                = Enum.Font.GothamBold
resLabel.TextSize            = 11
resLabel.TextColor3          = Color3.fromRGB(255, 255, 255)
resLabel.TextStrokeTransparency = 0.5
resLabel.Text                = "Mana: 100 / 100"
resLabel.Parent              = resBg

-- Exp bar (thin strip at bottom)
local expBg                  = Instance.new("Frame")
expBg.Name                   = "ExpBg"
expBg.Size                   = UDim2.new(1, 0, 0, 6)
expBg.Position               = UDim2.fromOffset(0, 62)
expBg.BackgroundColor3       = Color3.fromRGB(20, 20, 30)
expBg.BorderSizePixel        = 0
expBg.Parent                 = panel

Instance.new("UICorner", expBg).CornerRadius = UDim.new(0, 3)

local expFill                = Instance.new("Frame")
expFill.Name                 = "ExpFill"
expFill.Size                 = UDim2.new(0, 0, 1, 0)
expFill.BackgroundColor3     = Color3.fromRGB(180, 140, 240)
expFill.BorderSizePixel      = 0
expFill.Parent               = expBg

Instance.new("UICorner", expFill).CornerRadius = UDim.new(0, 3)

-- EXP toast (top-right)
local expToast               = Instance.new("TextLabel")
expToast.Name                = "ExpToast"
expToast.AnchorPoint         = Vector2.new(1, 0)
expToast.Position            = UDim2.new(1, -16, 0, 60)
expToast.Size                = UDim2.fromOffset(240, 36)
expToast.BackgroundColor3    = Color3.fromRGB(20, 20, 30)
expToast.BackgroundTransparency = 0.2
expToast.BorderSizePixel     = 0
expToast.Font                = Enum.Font.GothamBold
expToast.TextSize            = 14
expToast.TextColor3          = Color3.fromRGB(220, 200, 255)
expToast.Text                = ""
expToast.Visible             = false
expToast.Parent              = screenGui

Instance.new("UICorner", expToast).CornerRadius = UDim.new(0, 8)

-- ── state ─────────────────────────────────────────────────────────────────

local EXP_PER_LEVEL = 100   -- placeholder; replace with StatFormulas when ready

local cachedHp:      number = 100
local cachedMaxHp:   number = 100
local cachedRes:     number = 100
local cachedMaxRes:  number = 100
local cachedResType: string = "Mana"
local cachedLevel:   number = 1
local cachedExp:     number = 0
local cachedGold:    number = 0

-- ── update functions ──────────────────────────────────────────────────────

local function tweenBar(fill: Frame, pct: number)
	TweenService:Create(fill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0),
	}):Play()
end

local function refreshHp()
	local pct = if cachedMaxHp > 0 then cachedHp / cachedMaxHp else 0
	tweenBar(hpFill, pct)
	hpLabel.Text = string.format("HP  %d / %d", cachedHp, cachedMaxHp)
end

local function refreshResource()
	local pct   = if cachedMaxRes > 0 then cachedRes / cachedMaxRes else 0
	local color = RESOURCE_COLOR[cachedResType] or DEFAULT_RESOURCE_COLOR
	resFill.BackgroundColor3 = color
	tweenBar(resFill, pct)
	resLabel.Text = string.format("%s  %d / %d", cachedResType, cachedRes, cachedMaxRes)
end

local function refreshInfo()
	infoLine.Text = string.format("Lv.%d   Gold: %d", cachedLevel, cachedGold)
end

local function refreshExp()
	local pct = math.clamp(cachedExp / EXP_PER_LEVEL, 0, 1)
	tweenBar(expFill, pct)
end

local function applyPayload(payload: { [string]: any })
	local stats = payload.stats or {}

	cachedMaxHp  = (type(stats.MaxHealth)  == "number" and stats.MaxHealth)  or cachedMaxHp
	cachedMaxRes = (type(stats.MaxResource) == "number" and stats.MaxResource) or cachedMaxRes
	cachedHp     = payload.currentHealth   or cachedHp
	cachedRes    = payload.currentResource or cachedRes
	cachedResType = payload.resourceType   or stats.ResourceType or cachedResType
	cachedLevel  = payload.level           or cachedLevel
	cachedExp    = payload.exp             or cachedExp
	cachedGold   = payload.gold            or cachedGold

	refreshHp()
	refreshResource()
	refreshInfo()
	refreshExp()
end

-- ── toast helper ──────────────────────────────────────────────────────────

local toastThread: thread? = nil
local function showToast(text: string)
	expToast.Text            = text
	expToast.TextTransparency = 0
	expToast.BackgroundTransparency = 0.2
	expToast.Visible         = true

	if toastThread then
		task.cancel(toastThread)
	end
	toastThread = task.delay(2.5, function()
		TweenService:Create(expToast, TweenInfo.new(0.5), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		}):Play()
		task.wait(0.5)
		expToast.Visible = false
	end)
end

-- ── remote listeners ─────────────────────────────────────────────────────

PlayerRemotes.GetEvent("SendInitialData").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	applyPayload(payload)
	screenGui.Enabled = true
end)

PlayerRemotes.GetEvent("SyncStats").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	applyPayload(payload)
end)

PlayerRemotes.GetEvent("SyncHealth").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	if type(payload.currentHealth)  == "number" then cachedHp  = payload.currentHealth  end
	if type(payload.currentResource) == "number" then cachedRes = payload.currentResource end
	refreshHp()
	refreshResource()
end)

PlayerRemotes.GetEvent("ExpGained").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	local exp  = payload.exp  or 0
	local gold = payload.gold or 0
	if exp > 0 or gold > 0 then
		local parts = {}
		if exp  > 0 then table.insert(parts, "+" .. exp .. " EXP") end
		if gold > 0 then table.insert(parts, "+" .. gold .. " Gold") end
		showToast(table.concat(parts, "   "))
	end
	cachedExp  = cachedExp + (type(payload.exp)  == "number" and payload.exp  or 0)
	cachedGold = cachedGold + (type(payload.gold) == "number" and payload.gold or 0)
	refreshInfo()
	refreshExp()
end)

PlayerRemotes.GetEvent("LevelUp").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	cachedLevel = payload.level or cachedLevel
	cachedExp   = payload.exp   or 0
	refreshInfo()
	refreshExp()
	showToast("🎉 Level Up!  Now Lv." .. cachedLevel)
end)
