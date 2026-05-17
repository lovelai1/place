--!strict
-- NPCDialogUI.client.lua — Phase 3
-- Shows a dialog popup when a player triggers an NPC's TalkPrompt.
-- Listens for QuestRemotes.NPCDialogOpen { npcName, offers[], turnedIn? }.
-- Each offer has Accept button → fires QuestRemotes.AcceptQuest → server accepts →
-- QuestAccepted fires → QuestTrackerUI adds the row.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SharedRemotes = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
local QuestRemotes  = require(SharedRemotes:WaitForChild("QuestRemotes"))

-- ── palette ───────────────────────────────────────────────────────────────

local C = {
	bg         = Color3.fromRGB( 12,  16,  24),
	border     = Color3.fromRGB( 60,  80, 120),
	header     = Color3.fromRGB( 30,  38,  58),
	npcName    = Color3.fromRGB(255, 200,  60),
	bodyText   = Color3.fromRGB(210, 215, 230),
	questTitle = Color3.fromRGB(220, 220, 255),
	questDesc  = Color3.fromRGB(150, 155, 175),
	btnAccept  = Color3.fromRGB( 40, 140,  70),
	btnHover   = Color3.fromRGB( 50, 170,  90),
	btnClose   = Color3.fromRGB( 55,  60,  80),
	btnCloseFg = Color3.fromRGB(180, 180, 200),
	turnedIn   = Color3.fromRGB( 80, 200, 100),
}

-- ── ScreenGui ─────────────────────────────────────────────────────────────

local screenGui             = Instance.new("ScreenGui")
screenGui.Name              = "NPCDialogUI"
screenGui.ResetOnSpawn      = false
screenGui.IgnoreGuiInset    = false
screenGui.DisplayOrder      = 20
screenGui.Enabled           = true
screenGui.Parent            = playerGui

local backdrop              = Instance.new("Frame")
backdrop.Name               = "Backdrop"
backdrop.Size               = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3   = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.55
backdrop.BorderSizePixel    = 0
backdrop.Visible            = false
backdrop.Parent             = screenGui

-- ── dialog frame ──────────────────────────────────────────────────────────

local dialog                      = Instance.new("Frame")
dialog.Name                       = "Dialog"
dialog.AnchorPoint                = Vector2.new(0.5, 0.5)
dialog.Position                   = UDim2.new(0.5, 0, 0.5, 0)
dialog.Size                       = UDim2.fromOffset(400, 0)
dialog.AutomaticSize              = Enum.AutomaticSize.Y
dialog.BackgroundColor3           = C.bg
dialog.BackgroundTransparency     = 0.05
dialog.BorderSizePixel            = 0
dialog.Visible                    = false
dialog.Parent                     = screenGui

Instance.new("UICorner", dialog).CornerRadius = UDim.new(0, 12)

local dialogStroke                = Instance.new("UIStroke")
dialogStroke.Color                = C.border
dialogStroke.Thickness            = 1.5
dialogStroke.Parent               = dialog

local dialogList                  = Instance.new("UIListLayout")
dialogList.SortOrder              = Enum.SortOrder.LayoutOrder
dialogList.Padding                = UDim.new(0, 0)
dialogList.Parent                 = dialog

-- ── header ────────────────────────────────────────────────────────────────

local header                      = Instance.new("Frame")
header.Name                       = "Header"
header.Size                       = UDim2.new(1, 0, 0, 48)
header.BackgroundColor3           = C.header
header.BorderSizePixel            = 0
header.LayoutOrder                = 0
header.Parent                     = dialog

Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

local hMask                       = Instance.new("Frame")
hMask.Size                        = UDim2.new(1, 0, 0.5, 0)
hMask.Position                    = UDim2.new(0, 0, 0.5, 0)
hMask.BackgroundColor3            = C.header
hMask.BorderSizePixel             = 0
hMask.ZIndex                      = 2
hMask.Parent                      = header

local npcLabel                    = Instance.new("TextLabel")
npcLabel.Name                     = "NPCName"
npcLabel.Size                     = UDim2.new(1, -16, 1, 0)
npcLabel.Position                 = UDim2.fromOffset(16, 0)
npcLabel.BackgroundTransparency   = 1
npcLabel.Font                     = Enum.Font.GothamBold
npcLabel.TextSize                 = 17
npcLabel.TextColor3               = C.npcName
npcLabel.TextXAlignment           = Enum.TextXAlignment.Left
npcLabel.ZIndex                   = 3
npcLabel.Text                     = "NPC"
npcLabel.Parent                   = header

-- ── body ──────────────────────────────────────────────────────────────────

local body                        = Instance.new("Frame")
body.Name                         = "Body"
body.Size                         = UDim2.new(1, 0, 0, 0)
body.AutomaticSize                = Enum.AutomaticSize.Y
body.BackgroundTransparency       = 1
body.LayoutOrder                  = 1
body.Parent                       = dialog

local bodyList                    = Instance.new("UIListLayout")
bodyList.SortOrder                = Enum.SortOrder.LayoutOrder
bodyList.Padding                  = UDim.new(0, 6)
bodyList.Parent                   = body

local bodyPad                     = Instance.new("UIPadding")
bodyPad.PaddingTop                = UDim.new(0, 12)
bodyPad.PaddingBottom             = UDim.new(0, 16)
bodyPad.PaddingLeft               = UDim.new(0, 16)
bodyPad.PaddingRight              = UDim.new(0, 16)
bodyPad.Parent                    = body

-- ── state ─────────────────────────────────────────────────────────────────

local isOpen = false

-- ── helpers ───────────────────────────────────────────────────────────────

local function clearBody()
	for _, child in ipairs(body:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
end

local function makeQuestEntry(offer: { questId: string, name: string, description: string })
	local entry                      = Instance.new("Frame")
	entry.Size                       = UDim2.new(1, 0, 0, 0)
	entry.AutomaticSize              = Enum.AutomaticSize.Y
	entry.BackgroundColor3           = Color3.fromRGB(22, 28, 42)
	entry.BackgroundTransparency     = 0.1
	entry.BorderSizePixel            = 0
	Instance.new("UICorner", entry).CornerRadius = UDim.new(0, 8)

	local entryList                  = Instance.new("UIListLayout")
	entryList.SortOrder              = Enum.SortOrder.LayoutOrder
	entryList.Padding                = UDim.new(0, 2)
	entryList.Parent                 = entry

	local entryPad                   = Instance.new("UIPadding")
	entryPad.PaddingTop              = UDim.new(0, 8)
	entryPad.PaddingBottom           = UDim.new(0, 10)
	entryPad.PaddingLeft             = UDim.new(0, 10)
	entryPad.PaddingRight            = UDim.new(0, 10)
	entryPad.Parent                  = entry

	local title                      = Instance.new("TextLabel")
	title.Size                       = UDim2.new(1, -100, 0, 18)
	title.BackgroundTransparency     = 1
	title.Font                       = Enum.Font.GothamBold
	title.TextSize                   = 13
	title.TextColor3                 = C.questTitle
	title.TextXAlignment             = Enum.TextXAlignment.Left
	title.Text                       = "! " .. offer.name
	title.LayoutOrder                = 0
	title.Parent                     = entry

	local desc                       = Instance.new("TextLabel")
	desc.Size                        = UDim2.new(1, 0, 0, 0)
	desc.AutomaticSize               = Enum.AutomaticSize.Y
	desc.BackgroundTransparency      = 1
	desc.Font                        = Enum.Font.Gotham
	desc.TextSize                    = 11
	desc.TextColor3                  = C.questDesc
	desc.TextXAlignment              = Enum.TextXAlignment.Left
	desc.TextWrapped                 = true
	desc.Text                        = offer.description
	desc.LayoutOrder                 = 1
	desc.Parent                      = entry

	local acceptBtn                  = Instance.new("TextButton")
	acceptBtn.Name                   = "AcceptBtn"
	acceptBtn.Size                   = UDim2.new(0, 90, 0, 28)
	acceptBtn.BackgroundColor3       = C.btnAccept
	acceptBtn.BorderSizePixel        = 0
	acceptBtn.Font                   = Enum.Font.GothamBold
	acceptBtn.TextSize               = 12
	acceptBtn.TextColor3             = Color3.fromRGB(255, 255, 255)
	acceptBtn.Text                   = "Принять"
	acceptBtn.LayoutOrder            = 2
	acceptBtn.AutoButtonColor        = false
	Instance.new("UICorner", acceptBtn).CornerRadius = UDim.new(0, 6)
	acceptBtn.Parent                 = entry

	acceptBtn.MouseEnter:Connect(function()
		TweenService:Create(acceptBtn, TweenInfo.new(0.1), { BackgroundColor3 = C.btnHover }):Play()
	end)
	acceptBtn.MouseLeave:Connect(function()
		TweenService:Create(acceptBtn, TweenInfo.new(0.1), { BackgroundColor3 = C.btnAccept }):Play()
	end)
	acceptBtn.MouseButton1Click:Connect(function()
		QuestRemotes.GetEvent("AcceptQuest"):FireServer(offer.questId)
		entry:Destroy()
		local remaining = 0
		for _, child in ipairs(body:GetChildren()) do
			if child:IsA("Frame") then remaining += 1 end
		end
		if remaining == 0 then
			task.delay(0.3, function()
				if isOpen then
					isOpen = false
					dialog.Visible   = false
					backdrop.Visible = false
				end
			end)
		end
	end)

	entry.Parent = body
end

local function open(payload: any)
	if type(payload) ~= "table" then return end

	clearBody()
	npcLabel.Text = payload.npcName or "???"
	isOpen        = true

	local offers   = payload.offers   or {}
	local turnedIn = payload.turnedIn or {}

	for _, questId in ipairs(turnedIn) do
		local row                    = Instance.new("TextLabel")
		row.Size                     = UDim2.new(1, 0, 0, 22)
		row.BackgroundTransparency   = 1
		row.Font                     = Enum.Font.GothamBold
		row.TextSize                 = 12
		row.TextColor3               = C.turnedIn
		row.TextXAlignment           = Enum.TextXAlignment.Left
		row.Text                     = "✓ Квест сдан: " .. questId
		row.Parent                   = body
	end

	if #offers == 0 and #turnedIn == 0 then
		local noQuests               = Instance.new("TextLabel")
		noQuests.Size                = UDim2.new(1, 0, 0, 22)
		noQuests.BackgroundTransparency = 1
		noQuests.Font                = Enum.Font.Gotham
		noQuests.TextSize            = 12
		noQuests.TextColor3          = C.bodyText
		noQuests.TextXAlignment      = Enum.TextXAlignment.Left
		noQuests.Text                = "У меня пока ничего нет для тебя."
		noQuests.Parent              = body
	else
		for _, offer in ipairs(offers) do
			makeQuestEntry(offer)
		end
	end

	local closeBtn                   = Instance.new("TextButton")
	closeBtn.Name                    = "CloseBtn"
	closeBtn.Size                    = UDim2.new(1, 0, 0, 32)
	closeBtn.BackgroundColor3        = C.btnClose
	closeBtn.BorderSizePixel         = 0
	closeBtn.Font                    = Enum.Font.GothamBold
	closeBtn.TextSize                = 12
	closeBtn.TextColor3              = C.btnCloseFg
	closeBtn.Text                    = "Закрыть"
	closeBtn.AutoButtonColor         = false
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
	closeBtn.Parent                  = body

	closeBtn.MouseButton1Click:Connect(function()
		isOpen           = false
		dialog.Visible   = false
		backdrop.Visible = false
	end)

	dialog.Size     = UDim2.fromOffset(400, 0)
	dialog.Visible  = true
	backdrop.Visible = true

	dialog.BackgroundTransparency = 1
	TweenService:Create(dialog, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.05,
	}):Play()
end

backdrop.InputBegan:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isOpen           = false
		dialog.Visible   = false
		backdrop.Visible = false
	end
end)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Escape and isOpen then
		isOpen           = false
		dialog.Visible   = false
		backdrop.Visible = false
	end
end)

-- ── remote listener ───────────────────────────────────────────────────────

QuestRemotes.GetEvent("NPCDialogOpen").OnClientEvent:Connect(function(payload: any)
	open(payload)
end)
