--!strict
-- QuestTrackerUI.client.lua
-- Right-side quest tracker panel.
-- Appears after SendInitialData. Updates on QuestAccepted, QuestProgressUpdated,
-- QuestReadyToTurnIn, QuestAbandoned, QuestTurnedIn.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SharedRemotes = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
local QuestRemotes  = require(SharedRemotes:WaitForChild("QuestRemotes"))
local PlayerRemotes = require(SharedRemotes:WaitForChild("PlayerRemotes"))

-- ── GUI setup ─────────────────────────────────────────────────────────────

local screenGui            = Instance.new("ScreenGui")
screenGui.Name             = "QuestTrackerUI"
screenGui.ResetOnSpawn     = false
screenGui.IgnoreGuiInset   = false
screenGui.DisplayOrder     = 4
screenGui.Enabled          = false
screenGui.Parent           = playerGui

local panel                = Instance.new("Frame")
panel.Name                 = "TrackerPanel"
panel.AnchorPoint          = Vector2.new(1, 0)
panel.Position             = UDim2.new(1, -16, 0, 16)
panel.Size                 = UDim2.fromOffset(220, 0)
panel.AutomaticSize        = Enum.AutomaticSize.Y
panel.BackgroundColor3     = Color3.fromRGB(10, 12, 18)
panel.BackgroundTransparency = 0.25
panel.BorderSizePixel      = 0
panel.Parent               = screenGui

local panelCorner          = Instance.new("UICorner")
panelCorner.CornerRadius   = UDim.new(0, 8)
panelCorner.Parent         = panel

local panelPad             = Instance.new("UIPadding")
panelPad.PaddingTop        = UDim.new(0, 8)
panelPad.PaddingBottom     = UDim.new(0, 8)
panelPad.PaddingLeft       = UDim.new(0, 10)
panelPad.PaddingRight      = UDim.new(0, 10)
panelPad.Parent            = panel

local listLayout           = Instance.new("UIListLayout")
listLayout.SortOrder       = Enum.SortOrder.LayoutOrder
listLayout.Padding         = UDim.new(0, 6)
listLayout.Parent          = panel

local headerLabel          = Instance.new("TextLabel")
headerLabel.Name           = "Header"
headerLabel.Size           = UDim2.new(1, 0, 0, 18)
headerLabel.BackgroundTransparency = 1
headerLabel.Font           = Enum.Font.GothamBold
headerLabel.TextSize       = 12
headerLabel.TextColor3     = Color3.fromRGB(255, 200, 60)
headerLabel.TextXAlignment = Enum.TextXAlignment.Left
headerLabel.Text           = "◆ КВЕСТЫ"
headerLabel.LayoutOrder    = 0
headerLabel.Parent         = panel

-- ── state ─────────────────────────────────────────────────────────────────

-- questFrames[questId] = Frame
local questFrames: { [string]: Frame } = {}
-- questData[questId] = { name, objectives: { [objId]: {current, required, description} } }
local questData: { [string]: any } = {}

-- ── helpers ───────────────────────────────────────────────────────────────

local READY_COLOR = Color3.fromRGB(100, 220, 100)
local NORMAL_COLOR = Color3.fromRGB(200, 200, 220)

local function makeQuestFrame(questId: string, name: string): Frame
	local frame            = Instance.new("Frame")
	frame.Name             = questId
	frame.Size             = UDim2.new(1, 0, 0, 0)
	frame.AutomaticSize    = Enum.AutomaticSize.Y
	frame.BackgroundTransparency = 1
	frame.LayoutOrder      = os.clock() * 1000  -- insertion order

	local fl               = Instance.new("UIListLayout")
	fl.SortOrder           = Enum.SortOrder.LayoutOrder
	fl.Padding             = UDim.new(0, 2)
	fl.Parent              = frame

	local title            = Instance.new("TextLabel")
	title.Name             = "Title"
	title.Size             = UDim2.new(1, 0, 0, 15)
	title.BackgroundTransparency = 1
	title.Font             = Enum.Font.GothamBold
	title.TextSize         = 11
	title.TextColor3       = Color3.fromRGB(255, 220, 100)
	title.TextXAlignment   = Enum.TextXAlignment.Left
	title.TextTruncate     = Enum.TextTruncate.AtEnd
	title.Text             = name
	title.LayoutOrder      = 0
	title.Parent           = frame

	return frame
end

local function makeObjLabel(parent: Frame, objId: string, text: string, layoutOrder: number): TextLabel
	local lbl              = Instance.new("TextLabel")
	lbl.Name               = "obj_" .. objId
	lbl.Size               = UDim2.new(1, 0, 0, 13)
	lbl.BackgroundTransparency = 1
	lbl.Font               = Enum.Font.Gotham
	lbl.TextSize           = 10
	lbl.TextColor3         = NORMAL_COLOR
	lbl.TextXAlignment     = Enum.TextXAlignment.Left
	lbl.TextTruncate       = Enum.TextTruncate.AtEnd
	lbl.Text               = "  " .. text
	lbl.LayoutOrder        = layoutOrder
	lbl.Parent             = parent
	return lbl
end

local function buildObjectivesText(objId: string, obj: any): string
	local base = obj.description or objId
	return string.format("%s  %d / %d", base, obj.current or 0, obj.required or 1)
end

local function refreshQuestFrame(questId: string)
	local frame = questFrames[questId]
	local qd    = questData[questId]
	if not frame or not qd then return end

	local allDone = true
	local order   = 1
	for objId, obj in pairs(qd.objectives or {}) do
		local text = buildObjectivesText(objId, obj)
		local lbl  = frame:FindFirstChild("obj_" .. objId) :: TextLabel?
		if not lbl then
			lbl = makeObjLabel(frame, objId, text, order)
		else
			lbl.Text = "  " .. text
		end
		order += 1
		if (obj.current or 0) < (obj.required or 1) then
			allDone = false
		end
	end

	-- Colour title green when ready to turn in
	local title = frame:FindFirstChild("Title") :: TextLabel?
	if title then
		if allDone then
			title.TextColor3 = READY_COLOR
			title.Text       = "✓ " .. (qd.name or questId)
		else
			title.TextColor3 = Color3.fromRGB(255, 220, 100)
			title.Text       = qd.name or questId
		end
	end
end

local function addQuest(questId: string, name: string, objectives: any)
	if questFrames[questId] then return end  -- already tracked

	questData[questId] = { name = name, objectives = objectives or {} }
	local frame = makeQuestFrame(questId, name)
	questFrames[questId] = frame

	-- Build initial objective labels
	local order = 1
	for objId, obj in pairs(objectives or {}) do
		makeObjLabel(frame, objId, buildObjectivesText(objId, obj), order)
		order += 1
	end

	frame.Parent = panel
	refreshQuestFrame(questId)
end

local function removeQuest(questId: string)
	local frame = questFrames[questId]
	if frame then
		TweenService:Create(frame, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		task.delay(0.35, function()
			if frame.Parent then frame:Destroy() end
		end)
		questFrames[questId] = nil
	end
	questData[questId] = nil
end

-- ── remote listeners ──────────────────────────────────────────────────────

QuestRemotes.GetEvent("QuestAccepted").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	-- payload: { questId, name, objectives: { [objId]: { current, required, description } } }
	addQuest(payload.questId, payload.name or payload.questId, payload.objectives)
end)

QuestRemotes.GetEvent("QuestProgressUpdated").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	local qd = questData[payload.questId]
	if not qd then return end
	-- Merge updated objectives
	for objId, prog in pairs(payload.objectives or {}) do
		if qd.objectives[objId] then
			qd.objectives[objId].current = prog.current
		end
	end
	refreshQuestFrame(payload.questId)
end)

QuestRemotes.GetEvent("QuestReadyToTurnIn").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	refreshQuestFrame(payload.questId)  -- title turns green
end)

QuestRemotes.GetEvent("QuestTurnedIn").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	removeQuest(payload.questId)
end)

QuestRemotes.GetEvent("QuestAbandoned").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	removeQuest(payload.questId)
end)

QuestRemotes.GetEvent("QuestFailed").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	local frame = questFrames[payload.questId]
	if frame then
		local title = frame:FindFirstChild("Title") :: TextLabel?
		if title then title.TextColor3 = Color3.fromRGB(220, 80, 80) end
	end
	task.delay(2, function() removeQuest(payload.questId) end)
end)

-- Show panel after initial data arrives
PlayerRemotes.GetEvent("SendInitialData").OnClientEvent:Connect(function(_payload: any)
	screenGui.Enabled = true
end)
