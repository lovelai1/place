--!strict
-- PartyUI.client.lua  —  StarterPlayer/StarterPlayerScripts/GhostyRPG/PartyUI.client.lua
-- Phase 4: Party panel with member HP bars, invite flow, and kick button.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local PlayerGui   = localPlayer:WaitForChild("PlayerGui")

local PartyRemotes = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("PartyRemotes")
)

-- ── State ──────────────────────────────────────────────────────────────────

local partyData: { members: { { userId:number, name:string, hp:number, maxHp:number } }, leaderId:number? } = {
	members = {}, leaderId = nil,
}
local pendingInvite: { inviterName:string, inviterId:number, partyId:string }? = nil

-- ── UI Creation ─────────────────────────────────────────────────────────────

local screenGui = Instance.new("ScreenGui")
screenGui.Name            = "PartyUI"
screenGui.ResetOnSpawn    = false
screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
screenGui.Parent          = PlayerGui

-- Party Panel
local panel = Instance.new("Frame")
panel.Name                  = "PartyPanel"
panel.Size                  = UDim2.new(0, 220, 0, 280)
panel.Position              = UDim2.new(0, 12, 0, 120)
panel.BackgroundColor3      = Color3.fromRGB(20, 20, 28)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel       = 0
panel.Visible               = false
panel.Parent                = screenGui
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,8); c.Parent = panel end

-- Header
local header = Instance.new("Frame")
header.Size               = UDim2.new(1, 0, 0, 36)
header.BackgroundColor3   = Color3.fromRGB(60, 40, 90)
header.BorderSizePixel    = 0
header.Parent             = panel
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,8); c.Parent = header end

local titleLabel = Instance.new("TextLabel")
titleLabel.Size              = UDim2.new(1, -40, 1, 0)
titleLabel.Position          = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text              = "⚔ Party"
titleLabel.Font              = Enum.Font.GothamBold
titleLabel.TextSize          = 15
titleLabel.TextColor3        = Color3.fromRGB(230, 210, 255)
titleLabel.TextXAlignment    = Enum.TextXAlignment.Left
titleLabel.Parent            = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size                = UDim2.new(0, 30, 0, 30)
closeBtn.Position            = UDim2.new(1, -34, 0, 3)
closeBtn.BackgroundTransparency = 1
closeBtn.Text                = "✕"
closeBtn.Font                = Enum.Font.GothamBold
closeBtn.TextSize            = 14
closeBtn.TextColor3          = Color3.fromRGB(200, 180, 220)
closeBtn.Parent              = header
closeBtn.MouseButton1Click:Connect(function() panel.Visible = false end)

-- Member list
local memberList = Instance.new("ScrollingFrame")
memberList.Name               = "MemberList"
memberList.Size               = UDim2.new(1, -12, 0, 180)
memberList.Position           = UDim2.new(0, 6, 0, 42)
memberList.BackgroundTransparency = 1
memberList.BorderSizePixel    = 0
memberList.ScrollBarThickness = 4
memberList.CanvasSize         = UDim2.new(0, 0, 0, 0)
memberList.Parent             = panel
do
	local l = Instance.new("UIListLayout")
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding   = UDim.new(0, 4)
	l.Parent    = memberList
end

-- Invite button
local inviteBtn = Instance.new("TextButton")
inviteBtn.Size             = UDim2.new(1, -12, 0, 30)
inviteBtn.Position         = UDim2.new(0, 6, 1, -68)
inviteBtn.BackgroundColor3 = Color3.fromRGB(70, 100, 180)
inviteBtn.BorderSizePixel  = 0
inviteBtn.Text             = "+ Invite Player"
inviteBtn.Font             = Enum.Font.GothamSemibold
inviteBtn.TextSize         = 13
inviteBtn.TextColor3       = Color3.new(1,1,1)
inviteBtn.Parent           = panel
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = inviteBtn end

-- Leave button
local leaveBtn = Instance.new("TextButton")
leaveBtn.Size             = UDim2.new(1, -12, 0, 30)
leaveBtn.Position         = UDim2.new(0, 6, 1, -34)
leaveBtn.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
leaveBtn.BorderSizePixel  = 0
leaveBtn.Text             = "Leave Party"
leaveBtn.Font             = Enum.Font.GothamSemibold
leaveBtn.TextSize         = 13
leaveBtn.TextColor3       = Color3.new(1,1,1)
leaveBtn.Parent           = panel
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = leaveBtn end

-- Toggle button (HUD)
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name             = "PartyToggle"
toggleBtn.Size             = UDim2.new(0, 90, 0, 28)
toggleBtn.Position         = UDim2.new(0, 12, 0, 86)
toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 90)
toggleBtn.BorderSizePixel  = 0
toggleBtn.Text             = "⚔ Party"
toggleBtn.Font             = Enum.Font.GothamSemibold
toggleBtn.TextSize         = 13
toggleBtn.TextColor3       = Color3.fromRGB(220, 200, 255)
toggleBtn.Parent           = screenGui
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = toggleBtn end
toggleBtn.MouseButton1Click:Connect(function() panel.Visible = not panel.Visible end)

-- Invite popup
local invitePopup = Instance.new("Frame")
invitePopup.Name             = "InvitePopup"
invitePopup.Size             = UDim2.new(0, 280, 0, 140)
invitePopup.Position         = UDim2.new(0.5, -140, 0.5, -70)
invitePopup.BackgroundColor3 = Color3.fromRGB(25, 18, 38)
invitePopup.BorderSizePixel  = 0
invitePopup.Visible          = false
invitePopup.Parent           = screenGui
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,10); c.Parent = invitePopup end

local inviteTitle = Instance.new("TextLabel")
inviteTitle.Size              = UDim2.new(1, -16, 0, 30)
inviteTitle.Position          = UDim2.new(0, 8, 0, 8)
inviteTitle.BackgroundTransparency = 1
inviteTitle.Text              = "Invite Player"
inviteTitle.Font              = Enum.Font.GothamBold
inviteTitle.TextSize          = 16
inviteTitle.TextColor3        = Color3.fromRGB(220, 200, 255)
inviteTitle.Parent            = invitePopup

local inviteInput = Instance.new("TextBox")
inviteInput.Size             = UDim2.new(1, -16, 0, 34)
inviteInput.Position         = UDim2.new(0, 8, 0, 46)
inviteInput.BackgroundColor3 = Color3.fromRGB(40, 30, 55)
inviteInput.BorderSizePixel  = 0
inviteInput.PlaceholderText  = "Player name..."
inviteInput.Text             = ""
inviteInput.Font             = Enum.Font.Gotham
inviteInput.TextSize         = 14
inviteInput.TextColor3       = Color3.new(1,1,1)
inviteInput.PlaceholderColor3 = Color3.fromRGB(150, 130, 170)
inviteInput.Parent           = invitePopup
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = inviteInput end

local inviteSendBtn = Instance.new("TextButton")
inviteSendBtn.Size             = UDim2.new(0.48, -4, 0, 30)
inviteSendBtn.Position         = UDim2.new(0, 8, 1, -38)
inviteSendBtn.BackgroundColor3 = Color3.fromRGB(70, 100, 180)
inviteSendBtn.BorderSizePixel  = 0
inviteSendBtn.Text             = "Send Invite"
inviteSendBtn.Font             = Enum.Font.GothamSemibold
inviteSendBtn.TextSize         = 13
inviteSendBtn.TextColor3       = Color3.new(1,1,1)
inviteSendBtn.Parent           = invitePopup
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = inviteSendBtn end

local inviteCancelBtn = Instance.new("TextButton")
inviteCancelBtn.Size             = UDim2.new(0.48, -4, 0, 30)
inviteCancelBtn.Position         = UDim2.new(0.52, 0, 1, -38)
inviteCancelBtn.BackgroundColor3 = Color3.fromRGB(80, 55, 80)
inviteCancelBtn.BorderSizePixel  = 0
inviteCancelBtn.Text             = "Cancel"
inviteCancelBtn.Font             = Enum.Font.GothamSemibold
inviteCancelBtn.TextSize         = 13
inviteCancelBtn.TextColor3       = Color3.new(1,1,1)
inviteCancelBtn.Parent           = invitePopup
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = inviteCancelBtn end

-- Received-invite popup
local receivedPopup = Instance.new("Frame")
receivedPopup.Name             = "ReceivedInvitePopup"
receivedPopup.Size             = UDim2.new(0, 280, 0, 120)
receivedPopup.Position         = UDim2.new(0.5, -140, 0, 80)
receivedPopup.BackgroundColor3 = Color3.fromRGB(25, 18, 38)
receivedPopup.BorderSizePixel  = 0
receivedPopup.Visible          = false
receivedPopup.Parent           = screenGui
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,10); c.Parent = receivedPopup end

local receivedTitle = Instance.new("TextLabel")
receivedTitle.Size              = UDim2.new(1, -16, 0, 50)
receivedTitle.Position          = UDim2.new(0, 8, 0, 10)
receivedTitle.BackgroundTransparency = 1
receivedTitle.Text              = "Party Invite"
receivedTitle.Font              = Enum.Font.GothamBold
receivedTitle.TextSize          = 14
receivedTitle.TextColor3        = Color3.fromRGB(220, 200, 255)
receivedTitle.TextWrapped       = true
receivedTitle.Parent            = receivedPopup

local acceptBtn = Instance.new("TextButton")
acceptBtn.Size             = UDim2.new(0.46, -4, 0, 30)
acceptBtn.Position         = UDim2.new(0, 8, 1, -38)
acceptBtn.BackgroundColor3 = Color3.fromRGB(50, 140, 80)
acceptBtn.BorderSizePixel  = 0
acceptBtn.Text             = "Accept"
acceptBtn.Font             = Enum.Font.GothamSemibold
acceptBtn.TextSize         = 13
acceptBtn.TextColor3       = Color3.new(1,1,1)
acceptBtn.Parent           = receivedPopup
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = acceptBtn end

local declineBtn = Instance.new("TextButton")
declineBtn.Size             = UDim2.new(0.46, -4, 0, 30)
declineBtn.Position         = UDim2.new(0.54, 0, 1, -38)
declineBtn.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
declineBtn.BorderSizePixel  = 0
declineBtn.Text             = "Decline"
declineBtn.Font             = Enum.Font.GothamSemibold
declineBtn.TextSize         = 13
declineBtn.TextColor3       = Color3.new(1,1,1)
declineBtn.Parent           = receivedPopup
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = declineBtn end

-- ── Member row factory ──────────────────────────────────────────────────────

local function createMemberRow(
	member: { userId:number, name:string, hp:number, maxHp:number },
	isLeader: boolean,
	isSelf: boolean
): Frame
	local row = Instance.new("Frame")
	row.Name             = "Member_" .. member.userId
	row.Size             = UDim2.new(1, 0, 0, 48)
	row.BackgroundColor3 = if isSelf then Color3.fromRGB(50,35,75) else Color3.fromRGB(35,28,50)
	row.BorderSizePixel  = 0
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = row end

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size              = UDim2.new(1, -40, 0, 18)
	nameLabel.Position          = UDim2.new(0, 8, 0, 4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text              = (if isLeader then "♛ " else "  ") .. member.name
	nameLabel.Font              = Enum.Font.GothamSemibold
	nameLabel.TextSize          = 12
	nameLabel.TextColor3        = if isLeader then Color3.fromRGB(255,215,80) else Color3.new(1,1,1)
	nameLabel.TextXAlignment    = Enum.TextXAlignment.Left
	nameLabel.Parent            = row

	local hpBg = Instance.new("Frame")
	hpBg.Name             = "HPBg"
	hpBg.Size             = UDim2.new(1, -16, 0, 10)
	hpBg.Position         = UDim2.new(0, 8, 0, 26)
	hpBg.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
	hpBg.BorderSizePixel  = 0
	hpBg.Parent           = row
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,4); c.Parent = hpBg end

	local hpPct  = if member.maxHp > 0 then math.clamp(member.hp / member.maxHp, 0, 1) else 0
	local hpFill = Instance.new("Frame")
	hpFill.Name             = "HPFill"
	hpFill.Size             = UDim2.new(hpPct, 0, 1, 0)
	hpFill.BackgroundColor3 = Color3.fromRGB(80, 200, 100)
	hpFill.BorderSizePixel  = 0
	hpFill.Parent           = hpBg
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,4); c.Parent = hpFill end

	local hpText = Instance.new("TextLabel")
	hpText.Name              = "HPText"
	hpText.Size              = UDim2.new(1, 0, 1, 0)
	hpText.BackgroundTransparency = 1
	hpText.Text              = string.format("%d / %d", member.hp, member.maxHp)
	hpText.Font              = Enum.Font.Gotham
	hpText.TextSize          = 9
	hpText.TextColor3        = Color3.new(1,1,1)
	hpText.Parent            = hpBg

	if partyData.leaderId == localPlayer.UserId and not isSelf then
		local kickBtn = Instance.new("TextButton")
		kickBtn.Size             = UDim2.new(0, 28, 0, 28)
		kickBtn.Position         = UDim2.new(1, -32, 0, 10)
		kickBtn.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
		kickBtn.BorderSizePixel  = 0
		kickBtn.Text             = "✕"
		kickBtn.Font             = Enum.Font.GothamBold
		kickBtn.TextSize         = 12
		kickBtn.TextColor3       = Color3.new(1,1,1)
		kickBtn.Parent           = row
		do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,5); c.Parent = kickBtn end
		kickBtn.MouseButton1Click:Connect(function()
			PartyRemotes.GetEvent("KickMember"):FireServer({ userId = member.userId })
		end)
	end

	return row
end

-- ── Rebuild member list ─────────────────────────────────────────────────────

local function rebuildMemberList()
	for _, child in ipairs(memberList:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	local totalHeight = 0
	for _, member in ipairs(partyData.members) do
		local isLeader = member.userId == partyData.leaderId
		local isSelf   = member.userId == localPlayer.UserId
		local row      = createMemberRow(member, isLeader, isSelf)
		row.LayoutOrder = if isSelf then 0 else 1
		row.Parent = memberList
		totalHeight += 52
	end
	memberList.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
	if #partyData.members > 1 then panel.Visible = true end
end

-- ── HP update ───────────────────────────────────────────────────────────────

local function updateMemberHP(userId: number, hp: number, maxHp: number)
	for _, member in ipairs(partyData.members) do
		if member.userId == userId then
			member.hp    = hp
			member.maxHp = maxHp
			break
		end
	end
	local row = memberList:FindFirstChild("Member_" .. userId)
	if row then
		local hpBg = row:FindFirstChild("HPBg") :: Frame?
		if hpBg then
			local hpFill = hpBg:FindFirstChild("HPFill") :: Frame?
			local hpText = hpBg:FindFirstChild("HPText") :: TextLabel?
			if hpFill then
				local pct = if maxHp > 0 then math.clamp(hp / maxHp, 0, 1) else 0
				TweenService:Create(hpFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
					Size = UDim2.new(pct, 0, 1, 0),
				}):Play()
			end
			if hpText then
				hpText.Text = string.format("%d / %d", hp, maxHp)
			end
		end
	end
end

-- ── Remote events ────────────────────────────────────────────────────────────

PartyRemotes.GetEvent("PartyUpdated").OnClientEvent:Connect(function(data: any)
	partyData.members  = data.members  or {}
	partyData.leaderId = data.leaderId
	rebuildMemberList()
	if #partyData.members == 0 then panel.Visible = false end
end)

PartyRemotes.GetEvent("InviteReceived").OnClientEvent:Connect(function(data: any)
	pendingInvite = { inviterName = data.inviterName, inviterId = data.inviterId, partyId = data.partyId }
	receivedTitle.Text = string.format("⚔ Party Invite\n%s wants you to join their party.", data.inviterName)
	receivedPopup.Visible = true
end)

PartyRemotes.GetEvent("MemberHPSync").OnClientEvent:Connect(function(data: any)
	updateMemberHP(data.userId, data.hp, data.maxHp)
end)

-- ── Button logic ─────────────────────────────────────────────────────────────

inviteBtn.MouseButton1Click:Connect(function()
	inviteInput.Text = ""
	invitePopup.Visible = true
end)

inviteCancelBtn.MouseButton1Click:Connect(function()
	invitePopup.Visible = false
end)

inviteSendBtn.MouseButton1Click:Connect(function()
	local targetName = inviteInput.Text
	if targetName == "" then return end
	PartyRemotes.GetEvent("InvitePlayer"):FireServer({ targetName = targetName })
	invitePopup.Visible = false
end)

leaveBtn.MouseButton1Click:Connect(function()
	PartyRemotes.GetEvent("LeaveParty"):FireServer({})
	partyData.members  = {}
	partyData.leaderId = nil
	panel.Visible = false
end)

acceptBtn.MouseButton1Click:Connect(function()
	if pendingInvite then
		PartyRemotes.GetEvent("AcceptInvite"):FireServer({ inviterId = pendingInvite.inviterId })
		pendingInvite = nil
	end
	receivedPopup.Visible = false
end)

declineBtn.MouseButton1Click:Connect(function()
	if pendingInvite then
		PartyRemotes.GetEvent("DeclineInvite"):FireServer({ inviterId = pendingInvite.inviterId })
		pendingInvite = nil
	end
	receivedPopup.Visible = false
end)

-- ── HP pulse loop ─────────────────────────────────────────────────────────────

task.spawn(function()
	while true do
		task.wait(2)
		local char = localPlayer.Character
		local hum  = char and char:FindFirstChildOfClass("Humanoid")
		if hum and #partyData.members > 1 then
			PartyRemotes.GetEvent("HPPulse"):FireServer({
				hp    = math.floor(hum.Health),
				maxHp = math.floor(hum.MaxHealth),
			})
		end
	end
end)

print("[PartyUI] Loaded.")
