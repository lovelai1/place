--!strict
-- ArenaUI.client.lua  —  StarterPlayer/StarterPlayerScripts/GhostyRPG/ArenaUI.client.lua
-- Phase 4: PvP Arena UI — queue panel, match HUD, result popup, leaderboard.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local PlayerGui   = localPlayer:WaitForChild("PlayerGui")

local ArenaRemotes = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("ArenaRemotes")
)

-- ── State ──────────────────────────────────────────────────────────────────

local inQueue    = false
local inMatch    = false
local matchTimer = 0
local timerThread: thread? = nil

-- ── Screen GUI ─────────────────────────────────────────────────────────────

local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "ArenaUI"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = PlayerGui

-- ── Helper ─────────────────────────────────────────────────────────────────

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	for k, v in pairs(props) do (l :: any)[k] = v end
	l.Parent = parent
	return l
end

local function btn(parent: Instance, props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	for k, v in pairs(props) do (b :: any)[k] = v end
	b.Parent = parent
	return b
end

-- ── Toggle button ──────────────────────────────────────────────────────────

local toggleBtn = btn(screenGui, {
	Name             = "ArenaToggle",
	Size             = UDim2.new(0, 90, 0, 28),
	Position         = UDim2.new(0, 12, 0, 120),
	BackgroundColor3 = Color3.fromRGB(120, 40, 40),
	BorderSizePixel  = 0,
	Text             = "⚔ Arena",
	Font             = Enum.Font.GothamSemibold,
	TextSize         = 13,
	TextColor3       = Color3.fromRGB(255, 200, 200),
})
corner(toggleBtn, 6)

-- ── Arena Panel ────────────────────────────────────────────────────────────

local panel = Instance.new("Frame")
panel.Name                   = "ArenaPanel"
panel.Size                   = UDim2.new(0, 260, 0, 340)
panel.Position               = UDim2.new(0, 12, 0, 156)
panel.BackgroundColor3       = Color3.fromRGB(20, 12, 12)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel        = 0
panel.Visible                = false
panel.Parent                 = screenGui
corner(panel, 10)

-- Header
local panelHeader = Instance.new("Frame")
panelHeader.Size             = UDim2.new(1, 0, 0, 36)
panelHeader.BackgroundColor3 = Color3.fromRGB(100, 30, 30)
panelHeader.BorderSizePixel  = 0
panelHeader.Parent           = panel
corner(panelHeader, 10)

label(panelHeader, {
	Size              = UDim2.new(1, -40, 1, 0),
	Position          = UDim2.new(0, 10, 0, 0),
	BackgroundTransparency = 1,
	Text              = "⚔ PvP Arena",
	Font              = Enum.Font.GothamBold,
	TextSize          = 15,
	TextColor3        = Color3.fromRGB(255, 200, 180),
	TextXAlignment    = Enum.TextXAlignment.Left,
})

local panelClose = btn(panelHeader, {
	Size                = UDim2.new(0, 30, 0, 30),
	Position            = UDim2.new(1, -34, 0, 3),
	BackgroundTransparency = 1,
	Text                = "✕",
	Font                = Enum.Font.GothamBold,
	TextSize            = 14,
	TextColor3          = Color3.fromRGB(220, 180, 180),
})
panelClose.MouseButton1Click:Connect(function() panel.Visible = false end)

-- Rating display
local ratingLabel = label(panel, {
	Size              = UDim2.new(1, -16, 0, 24),
	Position          = UDim2.new(0, 8, 0, 44),
	BackgroundTransparency = 1,
	Text              = "Rating: ···",
	Font              = Enum.Font.GothamSemibold,
	TextSize          = 14,
	TextColor3        = Color3.fromRGB(255, 215, 80),
	TextXAlignment    = Enum.TextXAlignment.Left,
})

-- W/L display
local wlLabel = label(panel, {
	Size              = UDim2.new(1, -16, 0, 20),
	Position          = UDim2.new(0, 8, 0, 68),
	BackgroundTransparency = 1,
	Text              = "W: 0  L: 0",
	Font              = Enum.Font.Gotham,
	TextSize          = 12,
	TextColor3        = Color3.fromRGB(180, 160, 160),
	TextXAlignment    = Enum.TextXAlignment.Left,
})

-- Bracket selector label
label(panel, {
	Size              = UDim2.new(1, -16, 0, 18),
	Position          = UDim2.new(0, 8, 0, 96),
	BackgroundTransparency = 1,
	Text              = "Select bracket:",
	Font              = Enum.Font.GothamSemibold,
	TextSize          = 12,
	TextColor3        = Color3.fromRGB(200, 180, 180),
	TextXAlignment    = Enum.TextXAlignment.Left,
})

-- Bracket buttons
local brackets = { { size = 2, label = "2v2" }, { size = 3, label = "3v3" }, { size = 5, label = "5v5" } }
local selectedBracket = 2
local bracketBtns: { TextButton } = {}

for i, bk in ipairs(brackets) do
	local bkBtn = btn(panel, {
		Size             = UDim2.new(0, 66, 0, 28),
		Position         = UDim2.new(0, 8 + (i-1)*72, 0, 118),
		BackgroundColor3 = if bk.size == selectedBracket then Color3.fromRGB(140, 50, 50) else Color3.fromRGB(60, 30, 30),
		BorderSizePixel  = 0,
		Text             = bk.label,
		Font             = Enum.Font.GothamSemibold,
		TextSize         = 13,
		TextColor3       = Color3.new(1,1,1),
	})
	corner(bkBtn, 6)
	table.insert(bracketBtns, bkBtn)
	bkBtn.MouseButton1Click:Connect(function()
		selectedBracket = bk.size
		for j, bb in ipairs(bracketBtns) do
			bb.BackgroundColor3 = if brackets[j].size == selectedBracket
				then Color3.fromRGB(140, 50, 50)
				else Color3.fromRGB(60, 30, 30)
		end
	end)
end

-- Queue status
local queueStatus = label(panel, {
	Name              = "QueueStatus",
	Size              = UDim2.new(1, -16, 0, 40),
	Position          = UDim2.new(0, 8, 0, 154),
	BackgroundTransparency = 1,
	Text              = "Not in queue.",
	Font              = Enum.Font.Gotham,
	TextSize          = 12,
	TextColor3        = Color3.fromRGB(180, 160, 160),
	TextXAlignment    = Enum.TextXAlignment.Left,
	TextWrapped       = true,
})

-- Join/leave queue button
local joinBtn = btn(panel, {
	Size             = UDim2.new(1, -16, 0, 34),
	Position         = UDim2.new(0, 8, 0, 200),
	BackgroundColor3 = Color3.fromRGB(160, 40, 40),
	BorderSizePixel  = 0,
	Text             = "Join Queue",
	Font             = Enum.Font.GothamSemibold,
	TextSize         = 14,
	TextColor3       = Color3.new(1,1,1),
})
corner(joinBtn, 6)

-- Leaderboard button
local lbBtn = btn(panel, {
	Size             = UDim2.new(1, -16, 0, 30),
	Position         = UDim2.new(0, 8, 0, 242),
	BackgroundColor3 = Color3.fromRGB(60, 50, 80),
	BorderSizePixel  = 0,
	Text             = "🏆 Leaderboard",
	Font             = Enum.Font.GothamSemibold,
	TextSize         = 13,
	TextColor3       = Color3.fromRGB(220, 200, 255),
})
corner(lbBtn, 6)

-- ── Match HUD (shown during active match) ──────────────────────────────────

local matchHud = Instance.new("Frame")
matchHud.Name             = "MatchHUD"
matchHud.Size             = UDim2.new(0, 220, 0, 56)
matchHud.Position         = UDim2.new(0.5, -110, 0, 8)
matchHud.BackgroundColor3 = Color3.fromRGB(20, 12, 12)
matchHud.BackgroundTransparency = 0.15
matchHud.BorderSizePixel  = 0
matchHud.Visible          = false
matchHud.Parent           = screenGui
corner(matchHud, 8)

local teamLabel = label(matchHud, {
	Size              = UDim2.new(0.5, -4, 1, 0),
	Position          = UDim2.new(0, 8, 0, 0),
	BackgroundTransparency = 1,
	Text              = "Team: —",
	Font              = Enum.Font.GothamBold,
	TextSize          = 14,
	TextColor3        = Color3.new(1,1,1),
	TextXAlignment    = Enum.TextXAlignment.Left,
	TextYAlignment    = Enum.TextYAlignment.Center,
})

local timerLabel = label(matchHud, {
	Name              = "TimerLabel",
	Size              = UDim2.new(0.5, -8, 1, 0),
	Position          = UDim2.new(0.5, 0, 0, 0),
	BackgroundTransparency = 1,
	Text              = "5:00",
	Font              = Enum.Font.GothamBold,
	TextSize          = 18,
	TextColor3        = Color3.fromRGB(255, 200, 180),
	TextXAlignment    = Enum.TextXAlignment.Right,
	TextYAlignment    = Enum.TextYAlignment.Center,
})

-- ── Match Found popup ──────────────────────────────────────────────────────

local foundPopup = Instance.new("Frame")
foundPopup.Name             = "MatchFoundPopup"
foundPopup.Size             = UDim2.new(0, 300, 0, 160)
foundPopup.Position         = UDim2.new(0.5, -150, 0.35, 0)
foundPopup.BackgroundColor3 = Color3.fromRGB(20, 12, 12)
foundPopup.BackgroundTransparency = 0.05
foundPopup.BorderSizePixel  = 0
foundPopup.Visible          = false
foundPopup.Parent           = screenGui
corner(foundPopup, 10)

local foundTitle = label(foundPopup, {
	Size              = UDim2.new(1, -16, 0, 30),
	Position          = UDim2.new(0, 8, 0, 8),
	BackgroundTransparency = 1,
	Text              = "⚔ Match Found!",
	Font              = Enum.Font.GothamBold,
	TextSize          = 18,
	TextColor3        = Color3.fromRGB(255, 200, 100),
	TextXAlignment    = Enum.TextXAlignment.Center,
})

local foundMap = label(foundPopup, {
	Size              = UDim2.new(1, -16, 0, 24),
	Position          = UDim2.new(0, 8, 0, 44),
	BackgroundTransparency = 1,
	Text              = "Map: —",
	Font              = Enum.Font.Gotham,
	TextSize          = 13,
	TextColor3        = Color3.fromRGB(200, 180, 180),
	TextXAlignment    = Enum.TextXAlignment.Center,
})

local foundTeam = label(foundPopup, {
	Size              = UDim2.new(1, -16, 0, 24),
	Position          = UDim2.new(0, 8, 0, 70),
	BackgroundTransparency = 1,
	Text              = "Team: —",
	Font              = Enum.Font.GothamSemibold,
	TextSize          = 14,
	TextColor3        = Color3.new(1,1,1),
	TextXAlignment    = Enum.TextXAlignment.Center,
})

local foundOpponents = label(foundPopup, {
	Size              = UDim2.new(1, -16, 0, 40),
	Position          = UDim2.new(0, 8, 0, 96),
	BackgroundTransparency = 1,
	Text              = "vs. —",
	Font              = Enum.Font.Gotham,
	TextSize          = 12,
	TextColor3        = Color3.fromRGB(220, 180, 180),
	TextXAlignment    = Enum.TextXAlignment.Center,
	TextWrapped       = true,
})

-- ── Match Result popup ─────────────────────────────────────────────────────

local resultPopup = Instance.new("Frame")
resultPopup.Name             = "MatchResultPopup"
resultPopup.Size             = UDim2.new(0, 280, 0, 160)
resultPopup.Position         = UDim2.new(0.5, -140, 0.35, 0)
resultPopup.BackgroundColor3 = Color3.fromRGB(20, 12, 12)
resultPopup.BackgroundTransparency = 0.05
resultPopup.BorderSizePixel  = 0
resultPopup.Visible          = false
resultPopup.Parent           = screenGui
corner(resultPopup, 10)

local resultTitle = label(resultPopup, {
	Size              = UDim2.new(1, -16, 0, 40),
	Position          = UDim2.new(0, 8, 0, 12),
	BackgroundTransparency = 1,
	Text              = "—",
	Font              = Enum.Font.GothamBold,
	TextSize          = 22,
	TextColor3        = Color3.new(1,1,1),
	TextXAlignment    = Enum.TextXAlignment.Center,
})

local resultRating = label(resultPopup, {
	Size              = UDim2.new(1, -16, 0, 30),
	Position          = UDim2.new(0, 8, 0, 58),
	BackgroundTransparency = 1,
	Text              = "",
	Font              = Enum.Font.GothamSemibold,
	TextSize          = 15,
	TextColor3        = Color3.fromRGB(255, 215, 80),
	TextXAlignment    = Enum.TextXAlignment.Center,
})

local resultNewRating = label(resultPopup, {
	Size              = UDim2.new(1, -16, 0, 24),
	Position          = UDim2.new(0, 8, 0, 90),
	BackgroundTransparency = 1,
	Text              = "",
	Font              = Enum.Font.Gotham,
	TextSize          = 13,
	TextColor3        = Color3.fromRGB(200, 180, 200),
	TextXAlignment    = Enum.TextXAlignment.Center,
})

local resultCloseBtn = btn(resultPopup, {
	Size             = UDim2.new(0.6, 0, 0, 30),
	Position         = UDim2.new(0.2, 0, 1, -38),
	BackgroundColor3 = Color3.fromRGB(60, 40, 80),
	BorderSizePixel  = 0,
	Text             = "Back to Lobby",
	Font             = Enum.Font.GothamSemibold,
	TextSize         = 13,
	TextColor3       = Color3.new(1,1,1),
})
corner(resultCloseBtn, 6)
resultCloseBtn.MouseButton1Click:Connect(function()
	resultPopup.Visible = false
end)

-- ── Leaderboard popup ──────────────────────────────────────────────────────

local lbPopup = Instance.new("Frame")
lbPopup.Name             = "LeaderboardPopup"
lbPopup.Size             = UDim2.new(0, 260, 0, 320)
lbPopup.Position         = UDim2.new(0.5, -130, 0.5, -160)
lbPopup.BackgroundColor3 = Color3.fromRGB(18, 10, 10)
lbPopup.BackgroundTransparency = 0.05
lbPopup.BorderSizePixel  = 0
lbPopup.Visible          = false
lbPopup.Parent           = screenGui
corner(lbPopup, 10)

local lbHeader = Instance.new("Frame")
lbHeader.Size             = UDim2.new(1, 0, 0, 36)
lbHeader.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
lbHeader.BorderSizePixel  = 0
lbHeader.Parent           = lbPopup
corner(lbHeader, 10)
label(lbHeader, {
	Size              = UDim2.new(1, -40, 1, 0),
	Position          = UDim2.new(0, 10, 0, 0),
	BackgroundTransparency = 1,
	Text              = "🏆 Arena Leaderboard",
	Font              = Enum.Font.GothamBold,
	TextSize          = 14,
	TextColor3        = Color3.fromRGB(255, 215, 80),
	TextXAlignment    = Enum.TextXAlignment.Left,
})
local lbCloseX = btn(lbHeader, {
	Size                = UDim2.new(0, 30, 0, 30),
	Position            = UDim2.new(1, -34, 0, 3),
	BackgroundTransparency = 1,
	Text                = "✕",
	Font                = Enum.Font.GothamBold,
	TextSize            = 14,
	TextColor3          = Color3.fromRGB(220, 180, 180),
})
lbCloseX.MouseButton1Click:Connect(function() lbPopup.Visible = false end)

local lbList = Instance.new("ScrollingFrame")
lbList.Size               = UDim2.new(1, -12, 1, -44)
lbList.Position           = UDim2.new(0, 6, 0, 40)
lbList.BackgroundTransparency = 1
lbList.BorderSizePixel    = 0
lbList.ScrollBarThickness = 4
lbList.CanvasSize         = UDim2.new(0, 0, 0, 0)
lbList.Parent             = lbPopup
do
	local ll = Instance.new("UIListLayout")
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Padding   = UDim.new(0, 2)
	ll.Parent    = lbList
end

local function populateLeaderboard(entries: { { name:string, rating:number } })
	for _, child in ipairs(lbList:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	for rank, entry in ipairs(entries) do
		local row = Instance.new("Frame")
		row.Size             = UDim2.new(1, 0, 0, 28)
		row.BackgroundColor3 = if rank % 2 == 0 then Color3.fromRGB(28, 15, 15) else Color3.fromRGB(35, 18, 18)
		row.BorderSizePixel  = 0
		row.LayoutOrder      = rank
		row.Parent           = lbList
		corner(row, 4)

		label(row, {
			Size              = UDim2.new(0, 24, 1, 0),
			Position          = UDim2.new(0, 6, 0, 0),
			BackgroundTransparency = 1,
			Text              = tostring(rank),
			Font              = Enum.Font.GothamBold,
			TextSize          = 12,
			TextColor3        = Color3.fromRGB(180, 150, 150),
			TextXAlignment    = Enum.TextXAlignment.Left,
		})
		label(row, {
			Size              = UDim2.new(1, -80, 1, 0),
			Position          = UDim2.new(0, 32, 0, 0),
			BackgroundTransparency = 1,
			Text              = entry.name,
			Font              = Enum.Font.GothamSemibold,
			TextSize          = 12,
			TextColor3        = Color3.new(1,1,1),
			TextXAlignment    = Enum.TextXAlignment.Left,
		})
		label(row, {
			Size              = UDim2.new(0, 60, 1, 0),
			Position          = UDim2.new(1, -64, 0, 0),
			BackgroundTransparency = 1,
			Text              = tostring(entry.rating),
			Font              = Enum.Font.GothamBold,
			TextSize          = 12,
			TextColor3        = Color3.fromRGB(255, 215, 80),
			TextXAlignment    = Enum.TextXAlignment.Right,
		})
	end
	lbList.CanvasSize = UDim2.new(0, 0, 0, #entries * 30)
end

-- ── Timer helper ────────────────────────────────────────────────────────────

local function startTimer(seconds: number)
	if timerThread then task.cancel(timerThread) end
	matchTimer = seconds
	timerThread = task.spawn(function()
		while matchTimer > 0 do
			local m = math.floor(matchTimer / 60)
			local s = matchTimer % 60
			timerLabel.Text = string.format("%d:%02d", m, s)
			task.wait(1)
			matchTimer -= 1
		end
		timerLabel.Text = "0:00"
	end)
end

-- ── Remote event handlers ───────────────────────────────────────────────────

ArenaRemotes.GetEvent("QueueStatus").OnClientEvent:Connect(function(data: any)
	inQueue = data.inQueue == true
	if inQueue then
		queueStatus.Text = string.format(
			"In queue (%s)…\nPosition: %d  Est. wait: %ds",
			tostring(data.bracketSize) .. "v" .. tostring(data.bracketSize),
			data.position or 0,
			data.estimatedWait or 0
		)
		joinBtn.Text             = "Leave Queue"
		joinBtn.BackgroundColor3 = Color3.fromRGB(100, 80, 30)
	else
		queueStatus.Text         = "Not in queue."
		joinBtn.Text             = "Join Queue"
		joinBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
	end
end)

ArenaRemotes.GetEvent("MatchFound").OnClientEvent:Connect(function(data: any)
	inQueue   = false
	inMatch   = true
	queueStatus.Text = "Match found!"
	joinBtn.Text     = "In Match"
	joinBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)

	-- Populate found popup
	foundMap.Text  = "Map: " .. tostring(data.mapName or "—")
	local teamStr  = if data.teamColor == "Red" then "🔴 Red Team" else "🔵 Blue Team"
	local teamCol  = if data.teamColor == "Red" then Color3.fromRGB(255,100,100) else Color3.fromRGB(100,160,255)
	foundTeam.Text      = teamStr
	foundTeam.TextColor3 = teamCol
	teamLabel.Text      = teamStr
	teamLabel.TextColor3 = teamCol

	if type(data.opponents) == "table" then
		local names = {}
		for _, opp in ipairs(data.opponents) do
			table.insert(names, string.format("%s (%d)", opp.name, opp.rating or 0))
		end
		foundOpponents.Text = "vs. " .. table.concat(names, ", ")
	end

	foundPopup.Visible = true
	task.delay(4, function()
		TweenService:Create(foundPopup, TweenInfo.new(0.5), { BackgroundTransparency = 1.0 }):Play()
		task.wait(0.5)
		foundPopup.Visible = false
		foundPopup.BackgroundTransparency = 0.05
	end)
end)

ArenaRemotes.GetEvent("MatchStarted").OnClientEvent:Connect(function(data: any)
	matchHud.Visible = true
	startTimer(data.duration or 300)
end)

ArenaRemotes.GetEvent("MatchStateUpdate").OnClientEvent:Connect(function(_data: any)
	-- Future: show kill feed, alive counts, etc.
end)

ArenaRemotes.GetEvent("MatchEnded").OnClientEvent:Connect(function(data: any)
	inMatch = false
	matchHud.Visible = false
	if timerThread then task.cancel(timerThread); timerThread = nil end

	local result = tostring(data.result or "—")
	local delta  = data.ratingChange or 0
	local newR   = data.newRating or 0

	resultTitle.Text = if result == "Win" then "🏆 Victory!" elseif result == "Loss" then "💀 Defeat" else "⚖ Draw"
	resultTitle.TextColor3 = if result == "Win" then Color3.fromRGB(100,255,120)
		elseif result == "Loss" then Color3.fromRGB(255,100,100)
		else Color3.fromRGB(220,200,100)
	resultRating.Text    = if delta >= 0
		then string.format("Rating: +%d", delta)
		else string.format("Rating: %d", delta)
	resultRating.TextColor3 = if delta >= 0 then Color3.fromRGB(80,230,100) else Color3.fromRGB(230,80,80)
	resultNewRating.Text = string.format("New Rating: %d", newR)

	resultPopup.Visible = true

	-- Refresh own profile label
	joinBtn.Text             = "Join Queue"
	joinBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
	queueStatus.Text         = "Not in queue."

	-- Refresh rating from server
	task.delay(0.5, function()
		local profile = ArenaRemotes.GetFunction("GetArenaProfile"):InvokeServer()
		if type(profile) == "table" then
			ratingLabel.Text = string.format("Rating: %d", profile.rating or 1500)
			wlLabel.Text     = string.format("W: %d  L: %d", profile.wins or 0, profile.losses or 0)
		end
	end)
end)

-- ── Button logic ─────────────────────────────────────────────────────────────

toggleBtn.MouseButton1Click:Connect(function()
	panel.Visible = not panel.Visible
end)

joinBtn.MouseButton1Click:Connect(function()
	if inMatch then return end
	if inQueue then
		ArenaRemotes.GetEvent("LeaveArenaQueue"):FireServer({})
	else
		ArenaRemotes.GetEvent("JoinArenaQueue"):FireServer({ bracketSize = selectedBracket })
	end
end)

lbBtn.MouseButton1Click:Connect(function()
	local entries = ArenaRemotes.GetFunction("GetLeaderboard"):InvokeServer()
	if type(entries) == "table" then
		populateLeaderboard(entries)
	end
	lbPopup.Visible = true
end)

-- ── Initial profile fetch ─────────────────────────────────────────────────

task.delay(2, function()
	local ok, profile = pcall(function()
		return ArenaRemotes.GetFunction("GetArenaProfile"):InvokeServer()
	end)
	if ok and type(profile) == "table" then
		ratingLabel.Text = string.format("Rating: %d", profile.rating or 1500)
		wlLabel.Text     = string.format("W: %d  L: %d", profile.wins or 0, profile.losses or 0)
	end
end)

print("[ArenaUI] Loaded.")
