--!strict
-- ClassSelectorUI.client.lua
-- Показывается при получении NeedsClassSelect от сервера.
-- Шаг 1: выбрать класс из 6 карточек.
-- Шаг 2: выбрать роль (только те, что доступны классу).
-- Прячется после успешного RoleSelected.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SharedRemotes = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
local ClassRemotes  = require(SharedRemotes:WaitForChild("ClassRemotes"))
local PlayerRemotes = require(SharedRemotes:WaitForChild("PlayerRemotes"))
local ClassConfig   = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ClassConfig")
)

-- ── class data for display ────────────────────────────────────────────────

local CLASS_ORDER  = { "Warrior", "Paladin", "Mage", "Priest", "Rogue", "Hunter" }
local CLASS_ICON   = { Warrior = "⚔", Paladin = "🛡", Mage = "✨", Priest = "✝", Rogue = "🗡", Hunter = "🏹" }
local ROLE_COLOR   = {
	Tank   = Color3.fromRGB(100, 160, 240),
	Healer = Color3.fromRGB(90,  210,  90),
	DPS    = Color3.fromRGB(230,  80,  80),
}
local RESOURCE_COLOR = {
	Mana   = Color3.fromRGB(90,  140, 240),
	Rage   = Color3.fromRGB(220,  60,  60),
	Energy = Color3.fromRGB(240, 220,  60),
	Focus  = Color3.fromRGB(200, 170,  90),
}

-- ── GUI construction ──────────────────────────────────────────────────────

local screenGui              = Instance.new("ScreenGui")
screenGui.Name               = "ClassSelectorUI"
screenGui.ResetOnSpawn       = false
screenGui.IgnoreGuiInset     = false
screenGui.DisplayOrder       = 10
screenGui.Enabled            = false
screenGui.Parent             = playerGui

-- Dimmed backdrop
local backdrop               = Instance.new("Frame")
backdrop.Name                = "Backdrop"
backdrop.Size                = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3    = Color3.fromRGB(8, 10, 14)
backdrop.BackgroundTransparency = 0.25
backdrop.BorderSizePixel     = 0
backdrop.Parent              = screenGui

-- Main panel
local panel                  = Instance.new("Frame")
panel.Name                   = "Panel"
panel.AnchorPoint            = Vector2.new(0.5, 0.5)
panel.Position               = UDim2.fromScale(0.5, 0.5)
panel.Size                   = UDim2.fromOffset(760, 460)
panel.BackgroundColor3       = Color3.fromRGB(16, 20, 28)
panel.BorderSizePixel        = 0
panel.Parent                 = screenGui

local panelCorner            = Instance.new("UICorner")
panelCorner.CornerRadius     = UDim.new(0, 12)
panelCorner.Parent           = panel

local panelPad               = Instance.new("UIPadding")
panelPad.PaddingTop          = UDim.new(0, 20)
panelPad.PaddingBottom       = UDim.new(0, 20)
panelPad.PaddingLeft         = UDim.new(0, 20)
panelPad.PaddingRight        = UDim.new(0, 20)
panelPad.Parent              = panel

-- Title
local titleLabel             = Instance.new("TextLabel")
titleLabel.Size              = UDim2.new(1, 0, 0, 32)
titleLabel.Position          = UDim2.fromOffset(0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Font              = Enum.Font.GothamBold
titleLabel.TextSize          = 22
titleLabel.TextColor3        = Color3.fromRGB(240, 240, 255)
titleLabel.Text              = "Choose Your Class"
titleLabel.TextXAlignment    = Enum.TextXAlignment.Center
titleLabel.Parent            = panel

-- Status line (feedback)
local statusLabel            = Instance.new("TextLabel")
statusLabel.Size             = UDim2.new(1, 0, 0, 20)
statusLabel.Position         = UDim2.fromOffset(0, 36)
statusLabel.BackgroundTransparency = 1
statusLabel.Font             = Enum.Font.Gotham
statusLabel.TextSize         = 13
statusLabel.TextColor3       = Color3.fromRGB(180, 180, 200)
statusLabel.Text             = "Select a class to begin your adventure."
statusLabel.TextXAlignment   = Enum.TextXAlignment.Center
statusLabel.Parent           = panel

-- Class card grid
local cardGrid               = Instance.new("Frame")
cardGrid.Name                = "CardGrid"
cardGrid.Size                = UDim2.new(1, 0, 0, 290)
cardGrid.Position            = UDim2.fromOffset(0, 64)
cardGrid.BackgroundTransparency = 1
cardGrid.Parent              = panel

local gridLayout             = Instance.new("UIGridLayout")
gridLayout.CellSize          = UDim2.fromOffset(220, 130)
gridLayout.CellPadding       = UDim2.fromOffset(12, 12)
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.SortOrder         = Enum.SortOrder.LayoutOrder
gridLayout.Parent            = cardGrid

-- Role selection (hidden until class is chosen)
local roleRow                = Instance.new("Frame")
roleRow.Name                 = "RoleRow"
roleRow.Size                 = UDim2.new(1, 0, 0, 60)
roleRow.Position             = UDim2.fromOffset(0, 370)
roleRow.BackgroundTransparency = 1
roleRow.Visible              = false
roleRow.Parent               = panel

local roleLayout             = Instance.new("UIListLayout")
roleLayout.FillDirection     = Enum.FillDirection.Horizontal
roleLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
roleLayout.Padding           = UDim.new(0, 14)
roleLayout.SortOrder         = Enum.SortOrder.LayoutOrder
roleLayout.Parent            = roleRow

-- ── helpers ───────────────────────────────────────────────────────────────

local selectedClass: string? = nil
local pendingConfirm         = false

local function setStatus(text: string, colour: Color3?)
	statusLabel.Text       = text
	statusLabel.TextColor3 = colour or Color3.fromRGB(180, 180, 200)
end

local function clearRoleRow()
	for _, child in ipairs(roleRow:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function makeRoleButton(roleName: string): TextButton
	local btn                 = Instance.new("TextButton")
	btn.Name                  = roleName .. "Btn"
	btn.Size                  = UDim2.fromOffset(140, 44)
	btn.BackgroundColor3      = ROLE_COLOR[roleName] or Color3.fromRGB(60, 60, 80)
	btn.BorderSizePixel       = 0
	btn.Font                  = Enum.Font.GothamBold
	btn.TextSize              = 15
	btn.TextColor3            = Color3.fromRGB(255, 255, 255)
	btn.Text                  = roleName
	btn.AutoButtonColor       = true

	local c                   = Instance.new("UICorner")
	c.CornerRadius            = UDim.new(0, 8)
	c.Parent                  = btn

	btn.MouseButton1Click:Connect(function()
		if pendingConfirm then return end
		pendingConfirm = true
		setStatus("Confirming " .. roleName .. "…", Color3.fromRGB(240, 200, 60))
		ClassRemotes.GetEvent("SelectRole"):FireServer(roleName)
	end)

	return btn
end

local function showRoleRow(roles: { string })
	clearRoleRow()
	for _, roleName in ipairs(roles) do
		makeRoleButton(roleName).Parent = roleRow
	end
	roleRow.Visible = true
end

-- ── class cards ───────────────────────────────────────────────────────────

local cardButtons: { [string]: TextButton } = {}

local function highlightCard(className: string)
	for name, btn in pairs(cardButtons) do
		btn.BackgroundColor3 = if name == className
			then Color3.fromRGB(45, 58, 90)
			else Color3.fromRGB(26, 32, 44)
	end
end

for order, className in ipairs(CLASS_ORDER) do
	local classData = ClassConfig[className]
	if not classData then continue end

	local card                  = Instance.new("TextButton")
	card.Name                   = className
	card.LayoutOrder            = order
	card.Size                   = UDim2.fromOffset(220, 130)
	card.BackgroundColor3       = Color3.fromRGB(26, 32, 44)
	card.BorderSizePixel        = 0
	card.AutoButtonColor        = false
	card.Text                   = ""
	card.Parent                 = cardGrid

	local cardCorner            = Instance.new("UICorner")
	cardCorner.CornerRadius     = UDim.new(0, 8)
	cardCorner.Parent           = card

	local cardPad               = Instance.new("UIPadding")
	cardPad.PaddingTop          = UDim.new(0, 10)
	cardPad.PaddingLeft         = UDim.new(0, 12)
	cardPad.PaddingRight        = UDim.new(0, 8)
	cardPad.Parent              = card

	-- Icon + name
	local nameRow               = Instance.new("TextLabel")
	nameRow.Size                = UDim2.new(1, 0, 0, 28)
	nameRow.BackgroundTransparency = 1
	nameRow.Font                = Enum.Font.GothamBold
	nameRow.TextSize            = 16
	nameRow.TextColor3          = Color3.fromRGB(240, 240, 255)
	nameRow.TextXAlignment      = Enum.TextXAlignment.Left
	nameRow.Text                = (CLASS_ICON[className] or "") .. "  " .. className
	nameRow.Parent              = card

	-- Resource type badge
	local resType               = classData.ResourceType or "Mana"
	local resBadge              = Instance.new("TextLabel")
	resBadge.Size               = UDim2.new(0, 70, 0, 18)
	resBadge.Position           = UDim2.fromOffset(0, 32)
	resBadge.BackgroundColor3   = RESOURCE_COLOR[resType] or Color3.fromRGB(80, 80, 120)
	resBadge.BackgroundTransparency = 0.35
	resBadge.BorderSizePixel    = 0
	resBadge.Font               = Enum.Font.GothamBold
	resBadge.TextSize           = 11
	resBadge.TextColor3         = Color3.fromRGB(255, 255, 255)
	resBadge.Text               = resType
	resBadge.TextXAlignment     = Enum.TextXAlignment.Center
	resBadge.Parent             = card

	local badgeCorner           = Instance.new("UICorner")
	badgeCorner.CornerRadius    = UDim.new(0, 4)
	badgeCorner.Parent          = resBadge

	-- Primary stat
	local primaryStat           = Instance.new("TextLabel")
	primaryStat.Size            = UDim2.new(1, 0, 0, 16)
	primaryStat.Position        = UDim2.fromOffset(0, 54)
	primaryStat.BackgroundTransparency = 1
	primaryStat.Font            = Enum.Font.Gotham
	primaryStat.TextSize        = 12
	primaryStat.TextColor3      = Color3.fromRGB(170, 170, 200)
	primaryStat.TextXAlignment  = Enum.TextXAlignment.Left
	primaryStat.Text            = "Primary: " .. (classData.PrimaryStat or "—")
	primaryStat.Parent          = card

	-- Roles line
	local roles                 = classData.AvailableRoles or {}
	local rolesLabel            = Instance.new("TextLabel")
	rolesLabel.Size             = UDim2.new(1, 0, 0, 16)
	rolesLabel.Position         = UDim2.fromOffset(0, 72)
	rolesLabel.BackgroundTransparency = 1
	rolesLabel.Font             = Enum.Font.Gotham
	rolesLabel.TextSize         = 12
	rolesLabel.TextColor3       = Color3.fromRGB(140, 200, 140)
	rolesLabel.TextXAlignment   = Enum.TextXAlignment.Left
	rolesLabel.Text             = "Roles: " .. table.concat(roles, ", ")
	rolesLabel.Parent           = card

	-- HP hint
	local hpHint                = Instance.new("TextLabel")
	hpHint.Size                 = UDim2.new(1, 0, 0, 16)
	hpHint.Position             = UDim2.fromOffset(0, 90)
	hpHint.BackgroundTransparency = 1
	hpHint.Font                 = Enum.Font.Gotham
	hpHint.TextSize             = 12
	hpHint.TextColor3           = Color3.fromRGB(220, 80, 80)
	hpHint.TextXAlignment       = Enum.TextXAlignment.Left
	hpHint.Text                 = "HP: " .. tostring(classData.BaseHealth or 0)
	hpHint.Parent               = card

	cardButtons[className] = card

	card.MouseEnter:Connect(function()
		if selectedClass ~= className then
			TweenService:Create(card, TweenInfo.new(0.1), {
				BackgroundColor3 = Color3.fromRGB(34, 42, 58)
			}):Play()
		end
	end)
	card.MouseLeave:Connect(function()
		if selectedClass ~= className then
			TweenService:Create(card, TweenInfo.new(0.1), {
				BackgroundColor3 = Color3.fromRGB(26, 32, 44)
			}):Play()
		end
	end)

	card.MouseButton1Click:Connect(function()
		if pendingConfirm then return end
		selectedClass  = className
		pendingConfirm = true
		highlightCard(className)
		setStatus("Requesting " .. className .. "…", Color3.fromRGB(240, 200, 60))
		roleRow.Visible = false
		ClassRemotes.GetEvent("SelectClass"):FireServer(className)
	end)
end

-- ── remote listeners ──────────────────────────────────────────────────────

ClassRemotes.GetEvent("ClassSelected").OnClientEvent:Connect(function(payload: any)
	pendingConfirm = false
	if type(payload) ~= "table" then return end

	if payload.ok then
		-- Class accepted → show role chooser
		local classData = ClassConfig[payload.className or ""]
		local roles     = (classData and classData.AvailableRoles) or { "DPS" }
		titleLabel.Text = "Choose Your Role — " .. (payload.className or "")
		setStatus("Now pick a role.", Color3.fromRGB(140, 220, 140))
		showRoleRow(roles)
	else
		setStatus("❌ " .. (payload.message or "Class rejected."), Color3.fromRGB(230, 80, 80))
		selectedClass = nil
		highlightCard("")
	end
end)

ClassRemotes.GetEvent("RoleSelected").OnClientEvent:Connect(function(payload: any)
	pendingConfirm = false
	if type(payload) ~= "table" then return end

	if payload.ok then
		-- Done — SendInitialData will arrive from CharacterService; hide the selector.
		setStatus("✅ Ready! Loading…", Color3.fromRGB(100, 230, 100))
		task.wait(0.8)
		screenGui.Enabled = false
	else
		setStatus("❌ " .. (payload.message or "Role rejected."), Color3.fromRGB(230, 80, 80))
	end
end)

-- Server fires this when the player has no class saved
PlayerRemotes.GetEvent("NeedsClassSelect").OnClientEvent:Connect(function()
	selectedClass   = nil
	pendingConfirm  = false
	titleLabel.Text = "Choose Your Class"
	setStatus("Select a class to begin your adventure.")
	roleRow.Visible = false
	clearRoleRow()
	highlightCard("")
	screenGui.Enabled = true
end)
