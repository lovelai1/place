--!strict
-- Minimal GhostyRPG client UI for role selection, queueing, ready-check, and ability smoke testing.
-- The client only sends intent; all decisions come back from server remotes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SharedRemotes = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
local ClassRemotes = require(SharedRemotes:WaitForChild("ClassRemotes"))
local DungeonRemotes = require(SharedRemotes:WaitForChild("DungeonRemotes"))

-- Phase 7 FIX: wire up PlayerRemotes so we can listen to SendInitialData,
-- and load TombManagementUI so gold/level/magicTier stay in sync after join.
local PlayerRemotes    = require(SharedRemotes:WaitForChild("PlayerRemotes"))
local GhostyScripts    = player:WaitForChild("PlayerScripts"):WaitForChild("GhostyRPG")
local TombManagementUI = require(GhostyScripts:WaitForChild("TombManagementUI"))

local selectRoleEvent = ClassRemotes.GetEvent("SelectRole")
local roleSelectedEvent = ClassRemotes.GetEvent("RoleSelected")
local joinQueueEvent = DungeonRemotes.GetEvent("JoinQueue")
local leaveQueueEvent = DungeonRemotes.GetEvent("LeaveQueue")
local readyCheckEvent = DungeonRemotes.GetEvent("ReadyCheck")
local useAbilityEvent = DungeonRemotes.GetEvent("UseAbility")
local queueUpdatedEvent = DungeonRemotes.GetEvent("QueueUpdated")
local partyFormedEvent = DungeonRemotes.GetEvent("PartyFormed")
local readyUpdatedEvent = DungeonRemotes.GetEvent("ReadyUpdated")
local dungeonStateEvent = DungeonRemotes.GetEvent("DungeonStateUpdate")
local combatResultEvent = DungeonRemotes.GetEvent("CombatResult")
local abilityRejectedEvent = DungeonRemotes.GetEvent("AbilityRejected")
local dungeonFailedEvent = DungeonRemotes.GetEvent("DungeonFailed")
local getDungeonList = DungeonRemotes.GetFunction("GetDungeonList")

local selectedRole: string? = nil
local selectedDungeonId = "dungeon_sealed_crypt"
local selectedDifficulty = "Normal"
local readySent = false
local ROLE_ROW_HEIGHT = 40
local QUEUE_ROW_HEIGHT = 40
local ABILITY_BUTTON_HEIGHT = 40

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GhostyRPGClient"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.Parent = playerGui

local openButton = Instance.new("TextButton")
openButton.Name = "OpenPanelButton"
openButton.Position = UDim2.fromOffset(16, 16)
openButton.Size = UDim2.fromOffset(132, 34)
openButton.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
openButton.BorderSizePixel = 0
openButton.Font = Enum.Font.GothamBold
openButton.TextColor3 = Color3.fromRGB(255, 255, 255)
openButton.TextSize = 13
openButton.Text = "GhostyRPG"
openButton.Visible = false
openButton.Parent = screenGui

local openCorner = Instance.new("UICorner")
openCorner.CornerRadius = UDim.new(0, 8)
openCorner.Parent = openButton

local root = Instance.new("Frame")
root.Name = "Root"
root.AnchorPoint = Vector2.new(0, 0)
root.Position = UDim2.fromOffset(16, 16)
root.Size = UDim2.fromOffset(360, 0)
root.AutomaticSize = Enum.AutomaticSize.Y
root.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
root.BorderSizePixel = 0
root.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = root

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 12)
padding.PaddingBottom = UDim.new(0, 12)
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.Parent = root

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = root

local function makeLabel(name: string, text: string, height: number, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.new(1, 0, 0, height)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextColor3 = Color3.fromRGB(235, 240, 245)
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = root
	return label
end

local title = makeLabel("Title", "GhostyRPG MVP", 28, 20)
title.Font = Enum.Font.GothamBold

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, 0, 0, 0)
closeButton.Size = UDim2.fromOffset(28, 28)
closeButton.BackgroundColor3 = Color3.fromRGB(45, 58, 72)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 12
closeButton.Text = "X"
closeButton.Parent = title

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeButton

closeButton.MouseButton1Click:Connect(function()
	root.Visible = false
	openButton.Visible = true
end)

openButton.MouseButton1Click:Connect(function()
	root.Visible = true
	openButton.Visible = false
end)

local roleStatus = makeLabel("RoleStatus", "Choose a role.", 34, 14)
local queueStatus = makeLabel("QueueStatus", "Queue idle.", 42, 14)
local partyStatus = makeLabel("PartyStatus", "No party yet.", 96, 13)
partyStatus.TextYAlignment = Enum.TextYAlignment.Top
local combatStatus = makeLabel("CombatStatus", "Combat idle.", 34, 13)

local roleRow = Instance.new("Frame")
roleRow.Name = "RoleRow"
roleRow.Size = UDim2.new(1, 0, 0, ROLE_ROW_HEIGHT)
roleRow.BackgroundTransparency = 1
roleRow.LayoutOrder = 10
roleRow.Parent = root

local roleLayout = Instance.new("UIListLayout")
roleLayout.FillDirection = Enum.FillDirection.Horizontal
roleLayout.Padding = UDim.new(0, 8)
roleLayout.SortOrder = Enum.SortOrder.LayoutOrder
roleLayout.Parent = roleRow

local function makeButton(parent: Instance, name: string, text: string): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(0, 104, 1, 0)
	button.BackgroundColor3 = Color3.fromRGB(45, 58, 72)
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 14
	button.Text = text
	button.Parent = parent
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 6)
	buttonCorner.Parent = button
	return button
end

for _, roleName in ipairs({ "Tank", "Healer", "DPS" }) do
	local button = makeButton(roleRow, roleName .. "Button", roleName)
	button.MouseButton1Click:Connect(function()
		roleStatus.Text = "Selecting " .. roleName .. "..."
		selectRoleEvent:FireServer(roleName)
	end)
end

local queueRow = Instance.new("Frame")
queueRow.Name = "QueueRow"
queueRow.Size = UDim2.new(1, 0, 0, 40)
queueRow.BackgroundTransparency = 1
queueRow.LayoutOrder = 20
queueRow.Parent = root

local queueLayout = Instance.new("UIListLayout")
queueLayout.FillDirection = Enum.FillDirection.Horizontal
queueLayout.Padding = UDim.new(0, 8)
queueLayout.SortOrder = Enum.SortOrder.LayoutOrder
queueLayout.Parent = queueRow

local joinButton = makeButton(queueRow, "JoinQueueButton", "Join Queue")
local leaveButton = makeButton(queueRow, "LeaveQueueButton", "Leave")
local readyButton = makeButton(queueRow, "ReadyButton", "Ready")
readyButton.Visible = false

local abilityButton = makeButton(root, "SecondWindButton", "Use Second Wind")
abilityButton.Size = UDim2.new(1, 0, 0, 0)
abilityButton.LayoutOrder = 30
abilityButton.Visible = false

local function setRolePickerVisible(visible: boolean)
	roleRow.Visible = visible
	roleRow.Size = UDim2.new(1, 0, 0, if visible then ROLE_ROW_HEIGHT else 0)
end

local function setQueueControlsVisible(visible: boolean)
	queueRow.Visible = visible
	queueRow.Size = UDim2.new(1, 0, 0, if visible then QUEUE_ROW_HEIGHT else 0)
end

local function setAbilityButtonVisible(visible: boolean)
	abilityButton.Visible = visible
	abilityButton.Size = UDim2.new(1, 0, 0, if visible then ABILITY_BUTTON_HEIGHT else 0)
end

local function setPartyText(payload: any)
	if type(payload) ~= "table" then
		return
	end
	local lines = {
		string.format("%s %s", tostring(payload.dungeonId or "Dungeon"), tostring(payload.state or "")),
	}
	if type(payload.members) == "table" then
		for _, member in ipairs(payload.members) do
			if type(member) == "table" then
				table.insert(lines, string.format("%s - %s%s", tostring(member.name), tostring(member.role), if member.ready then " (ready)" else ""))
			end
		end
	end
	partyStatus.Text = table.concat(lines, "\n")
end

local function loadDungeonList()
	local ok, dungeons = pcall(function()
		return getDungeonList:InvokeServer()
	end)
	if ok and type(dungeons) == "table" and type(dungeons[1]) == "table" then
		selectedDungeonId = dungeons[1].id or selectedDungeonId
		if type(dungeons[1].difficulties) == "table" and type(dungeons[1].difficulties[1]) == "string" then
			selectedDifficulty = dungeons[1].difficulties[1]
		end
		queueStatus.Text = "Selected: " .. tostring(dungeons[1].name or selectedDungeonId) .. " / " .. selectedDifficulty
	else
		queueStatus.Text = "Selected: " .. selectedDungeonId .. " / " .. selectedDifficulty
	end
end

joinButton.MouseButton1Click:Connect(function()
	if not selectedRole then
		queueStatus.Text = "Choose a role first."
		return
	end
	queueStatus.Text = "Joining queue..."
	joinQueueEvent:FireServer(selectedDungeonId, selectedDifficulty)
end)

leaveButton.MouseButton1Click:Connect(function()
	leaveQueueEvent:FireServer()
	readyButton.Visible = false
	readySent = false
	setQueueControlsVisible(true)
	setAbilityButtonVisible(false)
end)

readyButton.MouseButton1Click:Connect(function()
	readySent = not readySent
	readyButton.Text = if readySent then "Unready" else "Ready"
	readyCheckEvent:FireServer(readySent)
end)

abilityButton.MouseButton1Click:Connect(function()
	combatStatus.Text = "Using Second Wind..."
	useAbilityEvent:FireServer("SHARED_SECOND_WIND")
end)

roleSelectedEvent.OnClientEvent:Connect(function(payload: any)
	if type(payload) == "table" and payload.ok == true then
		selectedRole = payload.roleName
		roleStatus.Text = "Role: " .. tostring(payload.roleName)
		queueStatus.Text = "Role locked. Join queue when ready."
		setRolePickerVisible(false)
	elseif type(payload) == "string" then
		selectedRole = payload
		roleStatus.Text = "Role: " .. payload
		queueStatus.Text = "Role locked. Join queue when ready."
		setRolePickerVisible(false)
	else
		roleStatus.Text = "Role rejected: " .. tostring(type(payload) == "table" and payload.message or payload)
		setRolePickerVisible(true)
	end
end)

queueUpdatedEvent.OnClientEvent:Connect(function(payload: any)
	if type(payload) == "table" and payload.ok ~= nil then
		local data = payload.data
		queueStatus.Text = tostring(payload.message or payload.code)
		if type(data) == "table" and data.state then
			queueStatus.Text = tostring(data.state) .. " - " .. tostring(payload.message or "")
			if data.state == "Queued" then
				setRolePickerVisible(false)
			elseif data.state == "Idle" then
				setRolePickerVisible(true)
			end
		end
	elseif type(payload) == "table" then
		queueStatus.Text = tostring(payload.state or "Queue updated")
	end
end)

partyFormedEvent.OnClientEvent:Connect(function(payload: any)
	readySent = false
	readyButton.Text = "Ready"
	readyButton.Visible = true
	queueStatus.Text = "Party formed. Ready check active."
	setRolePickerVisible(false)
	setQueueControlsVisible(true)
	setAbilityButtonVisible(false)
	setPartyText(payload)
end)

readyUpdatedEvent.OnClientEvent:Connect(function(payload: any)
	if type(payload) == "table" and payload.ok == false then
		queueStatus.Text = tostring(payload.message or payload.code or "Ready rejected")
	else
		setPartyText(payload)
	end
end)

dungeonStateEvent.OnClientEvent:Connect(function(payload: any)
	readyButton.Visible = false
	setRolePickerVisible(false)
	setQueueControlsVisible(false)
	setAbilityButtonVisible(true)
	if type(payload) == "table" then
		queueStatus.Text = "Dungeon state: " .. tostring(payload.state or "Active")
		setPartyText(payload)
	end
end)

combatResultEvent.OnClientEvent:Connect(function(payload: any)
	if type(payload) == "table" then
		combatStatus.Text = "Ability ok: " .. tostring(payload.abilityId) .. " (" .. tostring(payload.amount or 0) .. ")"
	else
		combatStatus.Text = "Ability resolved."
	end
end)

abilityRejectedEvent.OnClientEvent:Connect(function(payload: any)
	combatStatus.Text = "Ability rejected: " .. tostring(type(payload) == "table" and payload.message or payload)
end)

dungeonFailedEvent.OnClientEvent:Connect(function(payload: any)
	readyButton.Visible = false
	setQueueControlsVisible(true)
	setAbilityButtonVisible(false)
	queueStatus.Text = "Dungeon failed: " .. tostring(type(payload) == "table" and payload.message or payload)
	setPartyText(payload)
end)

task.spawn(loadDungeonList)

-- Phase 7 FIX: listen to SendInitialData so TombManagementUI always has correct
-- gold, level, and magicTier after join or class/role change. Without this
-- TombManagementUI.SetPlayerStats() was never called from the client side,
-- leaving the Upgrade tab permanently showing stale default values.
PlayerRemotes.GetEvent("SendInitialData").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	TombManagementUI.SetPlayerStats({
		level     = payload.level,
		gold      = payload.gold,
		magicTier = payload.magicTier,
	})
	-- If the server included a full tombData snapshot, apply tier too.
	if type(payload.tombData) == "table" then
		local tier = payload.tombData.Tier
		if tier then
			TombManagementUI.SetTombTier(tier)
		end
	end
end)
