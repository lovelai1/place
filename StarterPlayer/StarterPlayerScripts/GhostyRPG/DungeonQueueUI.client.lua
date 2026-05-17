--!strict
-- DungeonQueueUI.client.lua — Phase 3
-- Full dungeon queue UI replacing the smoke-test section in ClientMain.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SharedRemotes  = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
local DungeonRemotes = require(SharedRemotes:WaitForChild("DungeonRemotes"))

local C = {
	bg          = Color3.fromRGB( 10,  14,  22),
	panel       = Color3.fromRGB( 16,  20,  32),
	border      = Color3.fromRGB( 60,  80, 120),
	header      = Color3.fromRGB( 25,  32,  52),
	title       = Color3.fromRGB(180, 200, 255),
	body        = Color3.fromRGB(200, 205, 220),
	dim         = Color3.fromRGB(110, 115, 140),
	selected    = Color3.fromRGB( 40,  90, 180),
	selectedFg  = Color3.fromRGB(255, 255, 255),
	normal      = Color3.fromRGB( 28,  34,  52),
	btnGreen    = Color3.fromRGB( 35, 130,  65),
	btnRed      = Color3.fromRGB(130,  35,  35),
	btnGray     = Color3.fromRGB( 45,  50,  70),
	gold        = Color3.fromRGB(255, 200,  60),
	readyGreen  = Color3.fromRGB( 80, 200, 100),
	notReadyRed = Color3.fromRGB(200,  80,  80),
}

local screenGui             = Instance.new("ScreenGui")
screenGui.Name              = "DungeonQueueUI"
screenGui.ResetOnSpawn      = false
screenGui.IgnoreGuiInset    = false
screenGui.DisplayOrder      = 8
screenGui.Enabled           = true
screenGui.Parent            = playerGui

local toggleBtn             = Instance.new("TextButton")
toggleBtn.Name              = "ToggleBtn"
toggleBtn.AnchorPoint       = Vector2.new(1, 1)
toggleBtn.Position          = UDim2.new(1, -16, 1, -80)
toggleBtn.Size              = UDim2.fromOffset(88, 36)
toggleBtn.BackgroundColor3  = C.btnGray
toggleBtn.BorderSizePixel   = 0
toggleBtn.Font              = Enum.Font.GothamBold
toggleBtn.TextSize          = 13
toggleBtn.TextColor3        = Color3.fromRGB(200, 210, 255)
toggleBtn.Text              = "⚔ Данж"
toggleBtn.AutoButtonColor   = false
toggleBtn.ZIndex            = 5
toggleBtn.Parent            = screenGui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)

local panel                 = Instance.new("Frame")
panel.Name                  = "Panel"
panel.AnchorPoint           = Vector2.new(1, 1)
panel.Position              = UDim2.new(1, -16, 1, -124)
panel.Size                  = UDim2.fromOffset(360, 460)
panel.BackgroundColor3      = C.bg
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel       = 0
panel.Visible               = false
panel.ZIndex                = 6
panel.Parent                = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

local panelStroke           = Instance.new("UIStroke")
panelStroke.Color           = C.border
panelStroke.Thickness       = 1.2
panelStroke.Parent          = panel

local panelHeader           = Instance.new("Frame")
panelHeader.Name            = "Header"
panelHeader.Size            = UDim2.new(1, 0, 0, 44)
panelHeader.BackgroundColor3 = C.header
panelHeader.BorderSizePixel = 0
panelHeader.ZIndex          = 7
panelHeader.Parent          = panel
Instance.new("UICorner", panelHeader).CornerRadius = UDim.new(0, 12)

local hMask                 = Instance.new("Frame")
hMask.Size                  = UDim2.new(1, 0, 0.5, 0)
hMask.Position              = UDim2.new(0, 0, 0.5, 0)
hMask.BackgroundColor3      = C.header
hMask.BorderSizePixel       = 0
hMask.ZIndex                = 8
hMask.Parent                = panelHeader

local panelTitle            = Instance.new("TextLabel")
panelTitle.Size             = UDim2.new(1, -16, 1, 0)
panelTitle.Position         = UDim2.fromOffset(16, 0)
panelTitle.BackgroundTransparency = 1
panelTitle.Font             = Enum.Font.GothamBold
panelTitle.TextSize         = 15
panelTitle.TextColor3       = C.title
panelTitle.TextXAlignment   = Enum.TextXAlignment.Left
panelTitle.ZIndex           = 9
panelTitle.Text             = "⚔  Выбор Данжа"
panelTitle.Parent           = panelHeader

local closeBtn              = Instance.new("TextButton")
closeBtn.AnchorPoint        = Vector2.new(1, 0.5)
closeBtn.Position           = UDim2.new(1, -10, 0.5, 0)
closeBtn.Size               = UDim2.fromOffset(28, 28)
closeBtn.BackgroundTransparency = 1
closeBtn.Font               = Enum.Font.GothamBold
closeBtn.TextSize           = 16
closeBtn.TextColor3         = C.dim
closeBtn.Text               = "✕"
closeBtn.ZIndex             = 10
closeBtn.Parent             = panelHeader

local listFrame             = Instance.new("ScrollingFrame")
listFrame.Name              = "DungeonList"
listFrame.Position          = UDim2.new(0, 10, 0, 52)
listFrame.Size              = UDim2.new(1, -20, 0, 200)
listFrame.BackgroundTransparency = 1
listFrame.BorderSizePixel   = 0
listFrame.ScrollBarThickness = 4
listFrame.ScrollBarImageColor3 = C.border
listFrame.CanvasSize        = UDim2.new(0, 0, 0, 0)
listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
listFrame.ZIndex            = 7
listFrame.Parent            = panel

local listLayout            = Instance.new("UIListLayout")
listLayout.SortOrder        = Enum.SortOrder.LayoutOrder
listLayout.Padding          = UDim.new(0, 4)
listLayout.Parent           = listFrame

local diffLabel             = Instance.new("TextLabel")
diffLabel.Position          = UDim2.new(0, 10, 0, 262)
diffLabel.Size              = UDim2.new(0, 80, 0, 22)
diffLabel.BackgroundTransparency = 1
diffLabel.Font              = Enum.Font.GothamBold
diffLabel.TextSize          = 12
diffLabel.TextColor3        = C.dim
diffLabel.TextXAlignment    = Enum.TextXAlignment.Left
diffLabel.Text              = "Сложность:"
diffLabel.ZIndex            = 7
diffLabel.Parent            = panel

local diffRow               = Instance.new("Frame")
diffRow.Position            = UDim2.new(0, 10, 0, 286)
diffRow.Size                = UDim2.new(1, -20, 0, 34)
diffRow.BackgroundTransparency = 1
diffRow.ZIndex              = 7
diffRow.Parent              = panel

local diffList              = Instance.new("UIListLayout")
diffList.FillDirection      = Enum.FillDirection.Horizontal
diffList.Padding            = UDim.new(0, 6)
diffList.VerticalAlignment  = Enum.VerticalAlignment.Center
diffList.Parent             = diffRow

local DIFFICULTIES = { "Normal", "Hard", "Nightmare" }
local diffBtns: { [string]: TextButton } = {}
local selectedDifficulty = "Normal"

local function makeDiffBtn(label: string): TextButton
	local btn               = Instance.new("TextButton")
	btn.Name                = label
	btn.Size                = UDim2.fromOffset(88, 30)
	btn.BackgroundColor3    = C.normal
	btn.BorderSizePixel     = 0
	btn.Font                = Enum.Font.GothamBold
	btn.TextSize            = 12
	btn.TextColor3          = Color3.fromRGB(180, 185, 210)
	btn.Text                = label
	btn.AutoButtonColor     = false
	btn.ZIndex              = 7
	btn.Parent              = diffRow
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	return btn
end

local function refreshDiffBtns()
	for diff, btn in pairs(diffBtns) do
		if diff == selectedDifficulty then
			btn.BackgroundColor3 = C.selected
			btn.TextColor3       = C.selectedFg
		else
			btn.BackgroundColor3 = C.normal
			btn.TextColor3       = Color3.fromRGB(170, 175, 200)
		end
	end
end

for _, diff in ipairs(DIFFICULTIES) do
	local btn = makeDiffBtn(diff)
	diffBtns[diff] = btn
	btn.MouseButton1Click:Connect(function()
		selectedDifficulty = diff
		refreshDiffBtns()
	end)
end
refreshDiffBtns()

local statusLabel           = Instance.new("TextLabel")
statusLabel.Position        = UDim2.new(0, 10, 0, 330)
statusLabel.Size            = UDim2.new(1, -20, 0, 22)
statusLabel.BackgroundTransparency = 1
statusLabel.Font            = Enum.Font.Gotham
statusLabel.TextSize        = 12
statusLabel.TextColor3      = C.body
statusLabel.TextXAlignment  = Enum.TextXAlignment.Left
statusLabel.Text            = "Не в очереди."
statusLabel.ZIndex          = 7
statusLabel.Parent          = panel

local joinBtn               = Instance.new("TextButton")
joinBtn.Name                = "JoinBtn"
joinBtn.Position            = UDim2.new(0, 10, 0, 360)
joinBtn.Size                = UDim2.new(0.5, -14, 0, 40)
joinBtn.BackgroundColor3    = C.btnGreen
joinBtn.BorderSizePixel     = 0
joinBtn.Font                = Enum.Font.GothamBold
joinBtn.TextSize            = 13
joinBtn.TextColor3          = Color3.fromRGB(255, 255, 255)
joinBtn.Text                = "В очередь"
joinBtn.AutoButtonColor     = false
joinBtn.ZIndex              = 7
joinBtn.Parent              = panel
Instance.new("UICorner", joinBtn).CornerRadius = UDim.new(0, 8)

local leaveBtn              = Instance.new("TextButton")
leaveBtn.Name               = "LeaveBtn"
leaveBtn.Position           = UDim2.new(0.5, 4, 0, 360)
leaveBtn.Size               = UDim2.new(0.5, -14, 0, 40)
leaveBtn.BackgroundColor3   = C.btnRed
leaveBtn.BorderSizePixel    = 0
leaveBtn.Font               = Enum.Font.GothamBold
leaveBtn.TextSize           = 13
leaveBtn.TextColor3         = Color3.fromRGB(255, 255, 255)
leaveBtn.Text               = "Покинуть"
leaveBtn.AutoButtonColor    = false
leaveBtn.ZIndex             = 7
leaveBtn.Visible            = false
leaveBtn.Parent             = panel
Instance.new("UICorner", leaveBtn).CornerRadius = UDim.new(0, 8)

-- ── Ready-check popup ─────────────────────────────────────────────────────

local rdPopup               = Instance.new("Frame")
rdPopup.Name                = "ReadyPopup"
rdPopup.AnchorPoint         = Vector2.new(0.5, 0.5)
rdPopup.Position            = UDim2.new(0.5, 0, 0.5, 0)
rdPopup.Size                = UDim2.fromOffset(300, 0)
rdPopup.AutomaticSize       = Enum.AutomaticSize.Y
rdPopup.BackgroundColor3    = Color3.fromRGB(8, 12, 20)
rdPopup.BackgroundTransparency = 0.05
rdPopup.BorderSizePixel     = 0
rdPopup.Visible             = false
rdPopup.ZIndex              = 30
rdPopup.Parent              = screenGui
Instance.new("UICorner", rdPopup).CornerRadius = UDim.new(0, 12)

local rdStroke              = Instance.new("UIStroke")
rdStroke.Color              = Color3.fromRGB(255, 200, 60)
rdStroke.Thickness          = 1.5
rdStroke.Parent             = rdPopup

local rdList                = Instance.new("UIListLayout")
rdList.SortOrder            = Enum.SortOrder.LayoutOrder
rdList.Padding              = UDim.new(0, 0)
rdList.Parent               = rdPopup

local rdPad                 = Instance.new("UIPadding")
rdPad.PaddingTop            = UDim.new(0, 14)
rdPad.PaddingBottom         = UDim.new(0, 14)
rdPad.PaddingLeft           = UDim.new(0, 16)
rdPad.PaddingRight          = UDim.new(0, 16)
rdPad.Parent                = rdPopup

local rdTitle               = Instance.new("TextLabel")
rdTitle.Size                = UDim2.new(1, 0, 0, 24)
rdTitle.BackgroundTransparency = 1
rdTitle.Font                = Enum.Font.GothamBold
rdTitle.TextSize            = 16
rdTitle.TextColor3          = C.gold
rdTitle.Text                = "⚔ Пати готова!"
rdTitle.LayoutOrder         = 0
rdTitle.Parent              = rdPopup

local rdTimerLabel          = Instance.new("TextLabel")
rdTimerLabel.Size           = UDim2.new(1, 0, 0, 20)
rdTimerLabel.BackgroundTransparency = 1
rdTimerLabel.Font           = Enum.Font.Gotham
rdTimerLabel.TextSize       = 13
rdTimerLabel.TextColor3     = C.dim
rdTimerLabel.Text           = "Подтверди готовность (30)"
rdTimerLabel.LayoutOrder    = 1
rdTimerLabel.Parent         = rdPopup

local rdPlayerList          = Instance.new("Frame")
rdPlayerList.Name           = "PlayerList"
rdPlayerList.Size           = UDim2.new(1, 0, 0, 0)
rdPlayerList.AutomaticSize  = Enum.AutomaticSize.Y
rdPlayerList.BackgroundTransparency = 1
rdPlayerList.LayoutOrder    = 2
rdPlayerList.Parent         = rdPopup

local rdPLList              = Instance.new("UIListLayout")
rdPLList.SortOrder          = Enum.SortOrder.LayoutOrder
rdPLList.Padding            = UDim.new(0, 2)
rdPLList.Parent             = rdPlayerList

local rdReadyBtn            = Instance.new("TextButton")
rdReadyBtn.Size             = UDim2.new(0.5, -4, 0, 36)
rdReadyBtn.BackgroundColor3 = C.btnGreen
rdReadyBtn.BorderSizePixel  = 0
rdReadyBtn.Font             = Enum.Font.GothamBold
rdReadyBtn.TextSize         = 13
rdReadyBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
rdReadyBtn.Text             = "Готов!"
rdReadyBtn.AutoButtonColor  = false
rdReadyBtn.LayoutOrder      = 3
rdReadyBtn.Parent           = rdPopup
Instance.new("UICorner", rdReadyBtn).CornerRadius = UDim.new(0, 8)

local rdNotReadyBtn         = Instance.new("TextButton")
rdNotReadyBtn.Size          = UDim2.new(0.5, -4, 0, 36)
rdNotReadyBtn.BackgroundColor3 = C.btnRed
rdNotReadyBtn.BorderSizePixel = 0
rdNotReadyBtn.Font          = Enum.Font.GothamBold
rdNotReadyBtn.TextSize      = 13
rdNotReadyBtn.TextColor3    = Color3.fromRGB(255, 255, 255)
rdNotReadyBtn.Text          = "Не готов"
rdNotReadyBtn.AutoButtonColor = false
rdNotReadyBtn.LayoutOrder   = 4
rdNotReadyBtn.Parent        = rdPopup
Instance.new("UICorner", rdNotReadyBtn).CornerRadius = UDim.new(0, 8)

-- ── state ─────────────────────────────────────────────────────────────────

local panelOpen             = false
local inQueue               = false
local selectedDungeonId: string? = nil
local readyTimerThread: thread?  = nil
local readyCountdown             = 30

-- ── dungeon list helpers ──────────────────────────────────────────────────

local function clearList()
	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
end

local function selectDungeon(dungeonId: string, rowFrame: Frame)
	selectedDungeonId = dungeonId
	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("Frame") then
			child.BackgroundColor3 = C.panel
			local lbl = child:FindFirstChildOfClass("TextLabel")
			if lbl then lbl.TextColor3 = C.body end
		end
	end
	rowFrame.BackgroundColor3 = C.selected
	local lbl = rowFrame:FindFirstChildOfClass("TextLabel")
	if lbl then lbl.TextColor3 = C.selectedFg end
end

local function buildDungeonRow(entry: any)
	local row               = Instance.new("Frame")
	row.Size                = UDim2.new(1, 0, 0, 52)
	row.BackgroundColor3    = C.panel
	row.BorderSizePixel     = 0
	row.ZIndex              = 8
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)
	Instance.new("UIStroke", row)

	local name              = Instance.new("TextLabel")
	name.Position           = UDim2.fromOffset(10, 6)
	name.Size               = UDim2.new(1, -80, 0, 20)
	name.BackgroundTransparency = 1
	name.Font               = Enum.Font.GothamBold
	name.TextSize           = 13
	name.TextColor3         = C.body
	name.TextXAlignment     = Enum.TextXAlignment.Left
	name.Text               = entry.name or entry.id
	name.ZIndex             = 8
	name.Parent             = row

	local meta              = Instance.new("TextLabel")
	meta.Position           = UDim2.fromOffset(10, 28)
	meta.Size               = UDim2.new(1, -20, 0, 16)
	meta.BackgroundTransparency = 1
	meta.Font               = Enum.Font.Gotham
	meta.TextSize           = 11
	meta.TextColor3         = C.dim
	meta.TextXAlignment     = Enum.TextXAlignment.Left
	meta.Text               = string.format(
		"Уровень %d+  •  %d/%d игр.  •  %d сек",
		entry.minLevel   or 1,
		0,
		entry.maxPlayers or 5,
		entry.timeLimit  or 900
	)
	meta.ZIndex             = 8
	meta.Parent             = row

	row.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			selectDungeon(entry.id, row)
		end
	end)

	row.Parent = listFrame
end

local function loadDungeons()
	clearList()
	local ok, result = pcall(function()
		return DungeonRemotes.GetFunction("GetDungeonList"):InvokeServer()
	end)
	if not ok or type(result) ~= "table" then
		statusLabel.Text = "Ошибка загрузки списка данжей."
		return
	end
	if #result == 0 then
		statusLabel.Text = "Данжи пока недоступны."
		return
	end
	for _, entry in ipairs(result) do
		buildDungeonRow(entry)
	end
	local first = listFrame:FindFirstChildOfClass("Frame")
	if first and result[1] then
		selectedDungeonId = result[1].id
		first.BackgroundColor3 = C.selected
		local lbl = first:FindFirstChildOfClass("TextLabel")
		if lbl then lbl.TextColor3 = C.selectedFg end
	end
end

-- ── ready-check helpers ───────────────────────────────────────────────────

local function stopReadyTimer()
	if readyTimerThread then
		task.cancel(readyTimerThread)
		readyTimerThread = nil
	end
end

local function startReadyTimer(seconds: number)
	stopReadyTimer()
	readyCountdown = seconds
	readyTimerThread = task.spawn(function()
		while readyCountdown > 0 do
			rdTimerLabel.Text = string.format("Подтверди готовность (%d)", readyCountdown)
			task.wait(1)
			readyCountdown -= 1
		end
		rdTimerLabel.Text = "Время вышло!"
		task.wait(1)
		rdPopup.Visible = false
	end)
end

local function clearPlayerList()
	for _, child in ipairs(rdPlayerList:GetChildren()) do
		if child:IsA("TextLabel") then child:Destroy() end
	end
end

local function addReadyRow(name: string, isReady: boolean)
	local lbl               = Instance.new("TextLabel")
	lbl.Size                = UDim2.new(1, 0, 0, 18)
	lbl.BackgroundTransparency = 1
	lbl.Font                = Enum.Font.GothamBold
	lbl.TextSize            = 12
	lbl.TextXAlignment      = Enum.TextXAlignment.Left
	lbl.TextColor3          = if isReady then C.readyGreen else C.notReadyRed
	lbl.Text                = (if isReady then "✓ " else "○ ") .. name
	lbl.Parent              = rdPlayerList
end

-- ── event wiring ─────────────────────────────────────────────────────────

DungeonRemotes.GetEvent("QueueUpdated").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	inQueue = payload.inQueue == true
	if inQueue then
		statusLabel.Text = string.format(
			"⏳ В очереди (%s) — %d / %d",
			payload.dungeonId or "?",
			payload.queueSize or 1,
			payload.requiredSize or 5
		)
		joinBtn.Visible  = false
		leaveBtn.Visible = true
	else
		statusLabel.Text = payload.reason or "Не в очереди."
		joinBtn.Visible  = true
		leaveBtn.Visible = false
	end
end)

DungeonRemotes.GetEvent("ReadyUpdated").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	clearPlayerList()
	if type(payload.players) == "table" then
		for _, info in ipairs(payload.players) do
			addReadyRow(info.name or "???", info.ready == true)
		end
	end
end)

DungeonRemotes.GetEvent("PartyFormed").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	rdPopup.Visible = true
	clearPlayerList()
	if type(payload.players) == "table" then
		for _, info in ipairs(payload.players) do
			addReadyRow(info.name or "???", false)
		end
	end
	startReadyTimer(payload.timeout or 30)
end)

DungeonRemotes.GetEvent("DungeonStateUpdate").OnClientEvent:Connect(function(payload: any)
	rdPopup.Visible = false
	stopReadyTimer()
	inQueue          = false
	joinBtn.Visible  = true
	leaveBtn.Visible = false
	if type(payload) == "table" then
		statusLabel.Text = "Данж начался! (" .. tostring(payload.dungeonId or "?") .. ")"
	end
end)

DungeonRemotes.GetEvent("DungeonFailed").OnClientEvent:Connect(function(payload: any)
	rdPopup.Visible = false
	stopReadyTimer()
	inQueue          = false
	joinBtn.Visible  = true
	leaveBtn.Visible = false
	if type(payload) == "table" then
		statusLabel.Text = "Очередь отменена: " .. tostring(payload.reason or "unknown")
	end
end)

-- ── button callbacks ──────────────────────────────────────────────────────

toggleBtn.MouseButton1Click:Connect(function()
	panelOpen     = not panelOpen
	panel.Visible = panelOpen
	if panelOpen then loadDungeons() end
end)

closeBtn.MouseButton1Click:Connect(function()
	panelOpen     = false
	panel.Visible = false
end)

joinBtn.MouseButton1Click:Connect(function()
	if not selectedDungeonId then
		statusLabel.Text = "Сначала выбери данж."
		return
	end
	DungeonRemotes.GetEvent("JoinQueue"):FireServer(selectedDungeonId, selectedDifficulty)
end)

leaveBtn.MouseButton1Click:Connect(function()
	DungeonRemotes.GetEvent("LeaveQueue"):FireServer()
end)

rdReadyBtn.MouseButton1Click:Connect(function()
	DungeonRemotes.GetEvent("ReadyCheck"):FireServer(true)
	rdReadyBtn.BackgroundColor3 = Color3.fromRGB(20, 80, 40)
	rdReadyBtn.Text             = "✓ Готов"
end)

rdNotReadyBtn.MouseButton1Click:Connect(function()
	DungeonRemotes.GetEvent("ReadyCheck"):FireServer(false)
	rdPopup.Visible = false
	stopReadyTimer()
end)
