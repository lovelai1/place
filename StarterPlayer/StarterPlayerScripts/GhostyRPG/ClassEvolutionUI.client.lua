--!strict
--------------------------------------------------------------------------------
-- GhostyRPG | ClassEvolutionUI.client.lua
-- StarterPlayerScripts/GhostyRPG/ClassEvolutionUI.client.lua
--
-- Экран эволюции Overlord-класса.
--   • Текущий класс — слева.
--   • Стрелка → доступные варианты справа.
--   • Каждый вариант: список требований с ✓/✗.
--   • Кнопка «Эволюционировать» активна только если все требования выполнены.
--   • Открывается по нажатию кнопки эволюции в HUD или через RemoteEvent.
--
-- Ремоуты (Phase 8):
--   ClassRemotes.GetFunction("GetEvolutionOptions")  → EvolutionOption[]
--   ClassRemotes.GetEvent("RequestEvolve")            ← { targetClass }
--   ClassRemotes.GetEvent("EvolutionResult")          → { ok, targetClass?, reason? }
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SharedRemotes = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
local ClassRemotes  = require(SharedRemotes:WaitForChild("ClassRemotes"))

local SharedConfig        = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local OverlordClassConfig = require(SharedConfig:WaitForChild("OverlordClassConfig"))

--------------------------------------------------------------------------------
-- COLOURS & CONSTANTS
--------------------------------------------------------------------------------

local C = {
	BG         = Color3.fromRGB(10, 12, 18),
	PANEL      = Color3.fromRGB(18, 22, 32),
	CARD       = Color3.fromRGB(24, 30, 44),
	CARD_SEL   = Color3.fromRGB(35, 45, 70),
	HEADER     = Color3.fromRGB(140, 100, 220),
	TEXT       = Color3.fromRGB(220, 215, 235),
	TEXT_DIM   = Color3.fromRGB(130, 125, 145),
	OK         = Color3.fromRGB(80,  210, 110),
	FAIL       = Color3.fromRGB(220,  65,  65),
	BTN_ACT    = Color3.fromRGB(100,  60, 200),
	BTN_DIS    = Color3.fromRGB(50,   45,  70),
	BORDER     = Color3.fromRGB(60,   50,  90),
	ARROW      = Color3.fromRGB(140, 100, 220),
}

local TWEEN_FAST = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_MED  = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function makeCorner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function makeStroke(parent: Instance, col: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color     = col
	s.Thickness = thickness
	s.Parent    = parent
	return s
end

local function makePad(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop    = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft   = UDim.new(0, px)
	p.PaddingRight  = UDim.new(0, px)
	p.Parent = parent
	return p
end

local function label(parent: Instance, text: string, size: number, col: Color3, bold: boolean?): TextLabel
	local l = Instance.new("TextLabel")
	l.Text              = text
	l.TextSize          = size
	l.TextColor3        = col
	l.Font              = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	l.BackgroundTransparency = 1
	l.TextXAlignment    = Enum.TextXAlignment.Left
	l.Size              = UDim2.new(1, 0, 0, size + 6)
	l.Parent            = parent
	return l
end

local function hline(parent: Instance)
	local f = Instance.new("Frame")
	f.Size                = UDim2.new(1, 0, 0, 1)
	f.BackgroundColor3    = C.BORDER
	f.BorderSizePixel     = 0
	f.BackgroundTransparency = 0.4
	f.Parent              = parent
	return f
end

--------------------------------------------------------------------------------
-- SCREEN GUI
--------------------------------------------------------------------------------

local screenGui                = Instance.new("ScreenGui")
screenGui.Name                 = "ClassEvolutionUI"
screenGui.ResetOnSpawn         = false
screenGui.IgnoreGuiInset       = false
screenGui.DisplayOrder         = 20
screenGui.Enabled              = false
screenGui.Parent               = playerGui

-- Dim backdrop
local backdrop                 = Instance.new("Frame")
backdrop.Name                  = "Backdrop"
backdrop.Size                  = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3      = C.BG
backdrop.BackgroundTransparency = 0.3
backdrop.BorderSizePixel       = 0
backdrop.Parent                = screenGui

-- Main panel
local panel                    = Instance.new("Frame")
panel.Name                     = "Panel"
panel.AnchorPoint              = Vector2.new(0.5, 0.5)
panel.Position                 = UDim2.fromScale(0.5, 0.5)
panel.Size                     = UDim2.fromOffset(860, 540)
panel.BackgroundColor3         = C.PANEL
panel.BorderSizePixel          = 0
panel.Parent                   = screenGui
makeCorner(panel, 14)
makeStroke(panel, C.BORDER, 2)

-- Title bar
local titleBar                 = Instance.new("Frame")
titleBar.Name                  = "TitleBar"
titleBar.Size                  = UDim2.new(1, 0, 0, 52)
titleBar.BackgroundColor3      = Color3.fromRGB(25, 15, 45)
titleBar.BorderSizePixel       = 0
titleBar.Parent                = panel
makeCorner(titleBar, 14)

local titleLabel               = Instance.new("TextLabel")
titleLabel.Text                = "⚗  Class Evolution"
titleLabel.TextSize            = 22
titleLabel.Font                = Enum.Font.GothamBold
titleLabel.TextColor3          = C.HEADER
titleLabel.BackgroundTransparency = 1
titleLabel.Size                = UDim2.new(1, -60, 1, 0)
titleLabel.Position            = UDim2.fromOffset(20, 0)
titleLabel.TextXAlignment      = Enum.TextXAlignment.Left
titleLabel.Parent              = titleBar

-- Close button
local closeBtn                 = Instance.new("TextButton")
closeBtn.Text                  = "✕"
closeBtn.TextSize              = 18
closeBtn.Font                  = Enum.Font.GothamBold
closeBtn.TextColor3            = C.TEXT_DIM
closeBtn.BackgroundTransparency = 1
closeBtn.Size                  = UDim2.fromOffset(40, 52)
closeBtn.Position              = UDim2.new(1, -44, 0, 0)
closeBtn.Parent                = titleBar

-- Body frame below title bar
local body                     = Instance.new("Frame")
body.Name                      = "Body"
body.Position                  = UDim2.fromOffset(0, 56)
body.Size                      = UDim2.new(1, 0, 1, -56)
body.BackgroundTransparency    = 1
body.Parent                    = panel
makePad(body, 16)

-- LEFT column: current class card
local leftCol                  = Instance.new("Frame")
leftCol.Name                   = "LeftCol"
leftCol.Size                   = UDim2.new(0.28, 0, 1, 0)
leftCol.BackgroundTransparency = 1
leftCol.Parent                 = body

local currentCard              = Instance.new("Frame")
currentCard.Name               = "CurrentCard"
currentCard.Size               = UDim2.new(1, 0, 0, 180)
currentCard.BackgroundColor3   = C.CARD
currentCard.BorderSizePixel    = 0
currentCard.Parent             = leftCol
makeCorner(currentCard, 10)
makeStroke(currentCard, C.BORDER, 1)
makePad(currentCard, 14)

local currentList              = Instance.new("UIListLayout")
currentList.FillDirection      = Enum.FillDirection.Vertical
currentList.SortOrder          = Enum.SortOrder.LayoutOrder
currentList.Padding            = UDim.new(0, 6)
currentList.Parent             = currentCard

local currentTitle             = Instance.new("TextLabel")
currentTitle.Text              = "Current Class"
currentTitle.TextSize          = 11
currentTitle.Font              = Enum.Font.Gotham
currentTitle.TextColor3        = C.TEXT_DIM
currentTitle.BackgroundTransparency = 1
currentTitle.Size              = UDim2.new(1, 0, 0, 18)
currentTitle.TextXAlignment    = Enum.TextXAlignment.Left
currentTitle.LayoutOrder       = 1
currentTitle.Parent            = currentCard

local currentName              = Instance.new("TextLabel")
currentName.Name               = "ClassName"
currentName.Text               = "—"
currentName.TextSize           = 20
currentName.Font               = Enum.Font.GothamBold
currentName.TextColor3         = C.HEADER
currentName.BackgroundTransparency = 1
currentName.Size               = UDim2.new(1, 0, 0, 28)
currentName.TextXAlignment     = Enum.TextXAlignment.Left
currentName.LayoutOrder        = 2
currentName.Parent             = currentCard

local currentDesc              = Instance.new("TextLabel")
currentDesc.Name               = "ClassDesc"
currentDesc.Text               = ""
currentDesc.TextSize           = 12
currentDesc.Font               = Enum.Font.Gotham
currentDesc.TextColor3         = C.TEXT_DIM
currentDesc.BackgroundTransparency = 1
currentDesc.Size               = UDim2.new(1, 0, 0, 80)
currentDesc.TextXAlignment     = Enum.TextXAlignment.Left
currentDesc.TextYAlignment     = Enum.TextYAlignment.Top
currentDesc.TextWrapped        = true
currentDesc.LayoutOrder        = 3
currentDesc.Parent             = currentCard

-- ARROW
local arrowLabel               = Instance.new("TextLabel")
arrowLabel.Text                = "→"
arrowLabel.TextSize            = 36
arrowLabel.Font                = Enum.Font.GothamBold
arrowLabel.TextColor3          = C.ARROW
arrowLabel.BackgroundTransparency = 1
arrowLabel.AnchorPoint         = Vector2.new(0.5, 0.5)
arrowLabel.Position            = UDim2.fromScale(0.5, 0.5)
arrowLabel.Size                = UDim2.fromOffset(50, 50)
arrowLabel.Parent              = body

local arrowFrame               = Instance.new("Frame")
arrowFrame.Name                = "ArrowFrame"
arrowFrame.Size                = UDim2.new(0.08, 0, 1, 0)
arrowFrame.Position            = UDim2.new(0.28, 0, 0, 0)
arrowFrame.BackgroundTransparency = 1
arrowFrame.Parent              = body
arrowLabel.Parent              = arrowFrame

-- RIGHT column: evolution options scroll
local rightCol                 = Instance.new("Frame")
rightCol.Name                  = "RightCol"
rightCol.Position              = UDim2.new(0.36, 0, 0, 0)
rightCol.Size                  = UDim2.new(0.64, 0, 1, -50)
rightCol.BackgroundTransparency = 1
rightCol.Parent                = body

local scrollFrame              = Instance.new("ScrollingFrame")
scrollFrame.Name               = "OptionsScroll"
scrollFrame.Size               = UDim2.fromScale(1, 1)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel    = 0
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollBarImageColor3 = C.HEADER
scrollFrame.CanvasSize         = UDim2.fromOffset(0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent             = rightCol

local optionsList              = Instance.new("UIListLayout")
optionsList.FillDirection      = Enum.FillDirection.Vertical
optionsList.SortOrder          = Enum.SortOrder.LayoutOrder
optionsList.Padding            = UDim.new(0, 10)
optionsList.Parent             = scrollFrame

-- EVOLVE button (bottom of right col)
local evolveBtn                = Instance.new("TextButton")
evolveBtn.Name                 = "EvolveBtn"
evolveBtn.Text                 = "Evolve"
evolveBtn.TextSize             = 16
evolveBtn.Font                 = Enum.Font.GothamBold
evolveBtn.TextColor3           = Color3.new(1, 1, 1)
evolveBtn.BackgroundColor3     = C.BTN_DIS
evolveBtn.Size                 = UDim2.new(0.64, 0, 0, 42)
evolveBtn.Position             = UDim2.new(0.36, 0, 1, -42)
evolveBtn.BorderSizePixel      = 0
evolveBtn.AutoButtonColor      = false
evolveBtn.Active               = false
evolveBtn.Parent               = body
makeCorner(evolveBtn, 8)

-- Status label
local statusLabel              = Instance.new("TextLabel")
statusLabel.Name               = "StatusLabel"
statusLabel.Text               = ""
statusLabel.TextSize           = 13
statusLabel.Font               = Enum.Font.Gotham
statusLabel.TextColor3         = C.TEXT_DIM
statusLabel.BackgroundTransparency = 1
statusLabel.Size               = UDim2.new(1, 0, 0, 20)
statusLabel.Position           = UDim2.new(0, 0, 1, -68)
statusLabel.TextXAlignment     = Enum.TextXAlignment.Center
statusLabel.Parent             = body

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local selectedTargetClass: string? = nil
local optionCards: { Frame }       = {}
local loading                      = false

--------------------------------------------------------------------------------
-- BUILD OPTION CARD
--------------------------------------------------------------------------------

local function buildOptionCard(opt: any, index: number): Frame
	local card                     = Instance.new("Frame")
	card.Name                      = "Option_" .. index
	card.Size                      = UDim2.new(1, 0, 0, 0)
	card.AutomaticSize             = Enum.AutomaticSize.Y
	card.BackgroundColor3          = C.CARD
	card.BorderSizePixel           = 0
	card.LayoutOrder               = index
	card.Parent                    = scrollFrame
	makeCorner(card, 10)

	local stroke = makeStroke(card, C.BORDER, 1)
	makePad(card, 12)

	local cardList                 = Instance.new("UIListLayout")
	cardList.FillDirection         = Enum.FillDirection.Vertical
	cardList.SortOrder             = Enum.SortOrder.LayoutOrder
	cardList.Padding               = UDim.new(0, 5)
	cardList.Parent                = card

	-- Header row
	local headerRow                = Instance.new("Frame")
	headerRow.Size                 = UDim2.new(1, 0, 0, 26)
	headerRow.BackgroundTransparency = 1
	headerRow.LayoutOrder          = 1
	headerRow.Parent               = card

	local optName                  = Instance.new("TextLabel")
	optName.Text                   = opt.displayName or opt.targetClass
	optName.TextSize               = 17
	optName.Font                   = Enum.Font.GothamBold
	optName.TextColor3             = if opt.met then C.OK else C.TEXT
	optName.BackgroundTransparency = 1
	optName.Size                   = UDim2.new(0.7, 0, 1, 0)
	optName.TextXAlignment         = Enum.TextXAlignment.Left
	optName.Parent                 = headerRow

	local metBadge                 = Instance.new("TextLabel")
	metBadge.Text                  = if opt.met then "✓ READY" else "✗ LOCKED"
	metBadge.TextSize              = 11
	metBadge.Font                  = Enum.Font.GothamBold
	metBadge.TextColor3            = if opt.met then C.OK else C.FAIL
	metBadge.BackgroundTransparency = 1
	metBadge.Size                  = UDim2.new(0.3, 0, 1, 0)
	metBadge.Position              = UDim2.new(0.7, 0, 0, 0)
	metBadge.TextXAlignment        = Enum.TextXAlignment.Right
	metBadge.Parent                = headerRow

	hline(card).LayoutOrder        = 2

	-- Requirements
	local reqs: { any } = opt.requirements or {}
	for ri, req in ipairs(reqs) do
		local reqRow               = Instance.new("Frame")
		reqRow.Size                = UDim2.new(1, 0, 0, 20)
		reqRow.BackgroundTransparency = 1
		reqRow.LayoutOrder         = 2 + ri
		reqRow.Parent              = card

		local icon                 = Instance.new("TextLabel")
		icon.Text                  = if req.ok then "✓" else "✗"
		icon.TextSize              = 13
		icon.Font                  = Enum.Font.GothamBold
		icon.TextColor3            = if req.ok then C.OK else C.FAIL
		icon.BackgroundTransparency = 1
		icon.Size                  = UDim2.fromOffset(18, 20)
		icon.TextXAlignment        = Enum.TextXAlignment.Center
		icon.Parent                = reqRow

		local reqText              = Instance.new("TextLabel")
		reqText.Text               = req.label or "?"
		reqText.TextSize           = 12
		reqText.Font               = Enum.Font.Gotham
		reqText.TextColor3         = if req.ok then C.TEXT else C.TEXT_DIM
		reqText.BackgroundTransparency = 1
		reqText.Size               = UDim2.new(0.65, 0, 1, 0)
		reqText.Position           = UDim2.fromOffset(22, 0)
		reqText.TextXAlignment     = Enum.TextXAlignment.Left
		reqText.TextWrapped        = false
		reqText.Parent             = reqRow

		local progress             = Instance.new("TextLabel")
		progress.Text              = (req.have or "?") .. " / " .. (req.need or "?")
		progress.TextSize          = 11
		progress.Font              = Enum.Font.Gotham
		progress.TextColor3        = if req.ok then C.OK else C.FAIL
		progress.BackgroundTransparency = 1
		progress.Size              = UDim2.new(0.3, 0, 1, 0)
		progress.Position          = UDim2.new(0.7, 0, 0, 0)
		progress.TextXAlignment    = Enum.TextXAlignment.Right
		progress.Parent            = reqRow
	end

	-- Lore text if available
	local loreOk, loreText = pcall(function()
		return (OverlordClassConfig :: any).GetLore and
			(OverlordClassConfig :: any).GetLore(opt.targetClass) or nil
	end)
	if loreOk and type(loreText) == "string" and #loreText > 0 then
		local loreSep = hline(card)
		loreSep.LayoutOrder = 99

		local lore             = Instance.new("TextLabel")
		lore.Text              = loreText
		lore.TextSize          = 11
		lore.Font              = Enum.Font.GothamItalic
		lore.TextColor3        = C.TEXT_DIM
		lore.BackgroundTransparency = 1
		lore.Size              = UDim2.new(1, 0, 0, 0)
		lore.AutomaticSize     = Enum.AutomaticSize.Y
		lore.TextXAlignment    = Enum.TextXAlignment.Left
		lore.TextWrapped       = true
		lore.LayoutOrder       = 100
		lore.Parent            = card
	end

	-- Click to select
	local btn                  = Instance.new("TextButton")
	btn.Text                   = ""
	btn.BackgroundTransparency = 1
	btn.Size                   = UDim2.fromScale(1, 1)
	btn.ZIndex                 = card.ZIndex + 5
	btn.Parent                 = card

	btn.MouseButton1Click:Connect(function()
		selectedTargetClass = opt.targetClass
		-- Highlight selection
		for _, c in ipairs(optionCards) do
			TweenService:Create(c, TWEEN_FAST, { BackgroundColor3 = C.CARD }):Play()
		end
		TweenService:Create(card, TWEEN_FAST, { BackgroundColor3 = C.CARD_SEL }):Play()
		stroke.Color = C.HEADER

		if opt.met then
			evolveBtn.Active        = true
			evolveBtn.BackgroundColor3 = C.BTN_ACT
			evolveBtn.Text          = "Evolve → " .. (opt.displayName or opt.targetClass)
		else
			evolveBtn.Active        = false
			evolveBtn.BackgroundColor3 = C.BTN_DIS
			evolveBtn.Text          = "Requirements not met"
		end
		statusLabel.Text = ""
	end)

	return card
end

--------------------------------------------------------------------------------
-- POPULATE UI
--------------------------------------------------------------------------------

local function clearOptions()
	for _, c in ipairs(optionCards) do c:Destroy() end
	table.clear(optionCards)
	selectedTargetClass = nil
	evolveBtn.Active = false
	evolveBtn.BackgroundColor3 = C.BTN_DIS
	evolveBtn.Text = "Select an evolution path"
	statusLabel.Text = ""
end

local function populate()
	if loading then return end
	loading = true
	statusLabel.Text  = "Loading…"
	statusLabel.TextColor3 = C.TEXT_DIM

	clearOptions()

	-- Fetch current class name from LocalPlayer's PlayerData via attribute or HUD
	-- We get it indirectly through the options response (first option's current context)
	local RF = ClassRemotes.GetFunction("GetEvolutionOptions")
	local options: { any } = {}
	local ok, result = pcall(function()
		options = RF:InvokeServer() or {}
	end)

	loading = false

	if not ok then
		statusLabel.Text = "Failed to load options. Try again."
		statusLabel.TextColor3 = C.FAIL
		return
	end

	if #options == 0 then
		statusLabel.Text = "No evolution paths available for your current class."
		statusLabel.TextColor3 = C.TEXT_DIM
		return
	end

	statusLabel.Text = ""
	for i, opt in ipairs(options) do
		local card = buildOptionCard(opt, i)
		table.insert(optionCards, card)
	end
end

--------------------------------------------------------------------------------
-- SHOW / HIDE
--------------------------------------------------------------------------------

local function show()
	screenGui.Enabled = true
	panel.Position    = UDim2.fromScale(0.5, 0.55)
	panel.GroupTransparency = 1
	TweenService:Create(panel, TWEEN_MED, {
		Position         = UDim2.fromScale(0.5, 0.5),
		GroupTransparency = 0,
	}):Play()
	populate()
end

local function hide()
	TweenService:Create(panel, TWEEN_MED, {
		Position         = UDim2.fromScale(0.5, 0.55),
		GroupTransparency = 1,
	}):Play()
	task.delay(0.36, function()
		screenGui.Enabled = false
		clearOptions()
	end)
end

--------------------------------------------------------------------------------
-- EVOLVE BUTTON
--------------------------------------------------------------------------------

evolveBtn.MouseButton1Click:Connect(function()
	if not evolveBtn.Active then return end
	if not selectedTargetClass then return end
	if loading then return end

	loading = true
	evolveBtn.Active = false
	evolveBtn.Text   = "Evolving…"
	statusLabel.Text = ""

	ClassRemotes.GetEvent("RequestEvolve"):FireServer({ targetClass = selectedTargetClass })
end)

-- Hover effect
evolveBtn.MouseEnter:Connect(function()
	if evolveBtn.Active then
		TweenService:Create(evolveBtn, TWEEN_FAST, {
			BackgroundColor3 = Color3.fromRGB(130, 80, 240)
		}):Play()
	end
end)
evolveBtn.MouseLeave:Connect(function()
	if evolveBtn.Active then
		TweenService:Create(evolveBtn, TWEEN_FAST, {
			BackgroundColor3 = C.BTN_ACT
		}):Play()
	end
end)

--------------------------------------------------------------------------------
-- RESULT HANDLER
--------------------------------------------------------------------------------

ClassRemotes.GetEvent("EvolutionResult").OnClientEvent:Connect(function(payload: any)
	loading = false
	if type(payload) ~= "table" then return end

	if payload.ok then
		statusLabel.TextColor3 = C.OK
		statusLabel.Text       = "✓ Evolution complete! You are now " .. tostring(payload.targetClass) .. "."
		evolveBtn.Text         = "✓ Evolved!"
		-- Refresh after a moment so player can see updated options
		task.delay(2, function()
			if screenGui.Enabled then populate() end
		end)
	else
		statusLabel.TextColor3 = C.FAIL
		statusLabel.Text       = "✗ " .. tostring(payload.reason or "Evolution failed.")
		evolveBtn.Active       = (selectedTargetClass ~= nil)
		evolveBtn.BackgroundColor3 = if evolveBtn.Active then C.BTN_ACT else C.BTN_DIS
		evolveBtn.Text         = "Evolve → " .. tostring(selectedTargetClass or "?")
	end
end)

--------------------------------------------------------------------------------
-- CLOSE / ESC
--------------------------------------------------------------------------------

closeBtn.MouseButton1Click:Connect(hide)
backdrop.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		hide()
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape and screenGui.Enabled then
		hide()
	end
end)

--------------------------------------------------------------------------------
-- EXPOSE open/close for HUD button
--------------------------------------------------------------------------------

local EvolutionUIController = {}

function EvolutionUIController.Open()
	show()
end

function EvolutionUIController.Close()
	hide()
end

function EvolutionUIController.Toggle()
	if screenGui.Enabled then hide() else show() end
end

-- Allow other scripts to wire the HUD button
-- e.g. from ClientMain:  require(script.Parent.ClassEvolutionUI).Toggle()
return EvolutionUIController
