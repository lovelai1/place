--!strict
--------------------------------------------------------------------------------
-- GhostyRPG | AbilityBarUI.client.lua
-- StarterPlayer/StarterPlayerScripts/GhostyRPG/AbilityBarUI.client.lua
--
-- PURPOSE:
--   6-slot ability hotbar at the bottom of the screen.
--
-- FEATURES:
--   • Slots 1–6, bound to keys 1–6 on keyboard
--   • Spinning arc cooldown overlay (ImageLabel UIGradient trick)
--   • Tier-lock state: greyed + padlock label when MagicTier insufficient
--   • Hover tooltip: ability name, description, cost, cooldown remaining
--   • Fires AbilityRemotes.CastAbility on click / key press
--   • Listens to CooldownSync  → updates remaining cooldown display
--   • Listens to AbilityGranted → re-populates bar on class / tier change
--
-- DEPENDENCIES:
--   ReplicatedStorage/Shared/Config/AbilityConfig
--   ReplicatedStorage/Shared/Remotes/AbilityRemotes
--
-- No server calls from this file except the CastAbility fire.
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared        = ReplicatedStorage:WaitForChild("Shared")
local AbilityConfig = require(Shared:WaitForChild("Config"):WaitForChild("AbilityConfig"))
local AbilityRemotes = require(Shared:WaitForChild("Remotes"):WaitForChild("AbilityRemotes"))

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------

local BAR_SLOTS       = 6
local SLOT_SIZE       = 64       -- px
local SLOT_GAP        = 8        -- px
local BOTTOM_OFFSET   = 24       -- px from bottom edge
local TOOLTIP_WIDTH   = 240
local TOOLTIP_PADDING = 8

-- key codes 1–6
local KEYBINDS: { Enum.KeyCode } = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
}

-- Colour palette
local COL_BG        = Color3.fromRGB(15, 18, 24)
local COL_BORDER    = Color3.fromRGB(60, 70, 90)
local COL_HOVER     = Color3.fromRGB(80, 90, 120)
local COL_LOCKED    = Color3.fromRGB(40, 40, 40)
local COL_CD_TINT   = Color3.fromRGB(0, 0, 0)
local COL_TEXT      = Color3.fromRGB(230, 230, 230)
local COL_SUBTEXT   = Color3.fromRGB(155, 165, 180)
local COL_TOOLTIP   = Color3.fromRGB(20, 24, 32)
local COL_HIGHLIGHT = Color3.fromRGB(100, 200, 255)

-- Tag-to-colour map for ability school label
local SCHOOL_COLOURS: { [string]: Color3 } = {
	Shadow  = Color3.fromRGB(160,  80, 220),
	Arcane  = Color3.fromRGB(100, 120, 255),
	Fire    = Color3.fromRGB(255, 120,  40),
	Frost   = Color3.fromRGB( 80, 200, 255),
	Holy    = Color3.fromRGB(255, 240, 120),
	Nature  = Color3.fromRGB( 80, 210,  80),
	Physical= Color3.fromRGB(210, 180, 120),
}

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

-- Slot definitions: which ability is loaded in each slot
type SlotData = {
	abilityId  : string?,
	cooldownEnd: number,   -- os.clock() when CD expires (0 = off CD)
	locked     : boolean,  -- tier-locked
}

local slots: { SlotData } = {}
for i = 1, BAR_SLOTS do
	slots[i] = { abilityId = nil, cooldownEnd = 0, locked = false }
end

-- Reference tables for frame objects, filled during build
local slotFrames   : { Frame }       = {}
local cdOverlays   : { Frame }       = {}
local cdLabels     : { TextLabel }   = {}
local lockLabels   : { TextLabel }   = {}
local iconLabels   : { TextLabel }   = {}  -- text emoji stand-in for real icons
local keyLabels    : { TextLabel }   = {}

local tooltip      : Frame? = nil
local tooltipVisible = false
local hoveredSlot  = 0

local playerMagicTier = 1   -- updated from server data

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function getSchoolColour(tags: { string }): Color3
	for _, tag in ipairs(tags) do
		local col = SCHOOL_COLOURS[tag]
		if col then return col end
	end
	return COL_SUBTEXT
end

local function formatCooldown(secs: number): string
	if secs <= 0 then return "" end
	if secs < 60 then return string.format("%.1fs", secs) end
	return string.format("%dm", math.ceil(secs / 60))
end

local function formatResource(ability: AbilityConfig.AbilityDefinition): string
	if not ability.resourceType or ability.resourceCost <= 0 then return "Free" end
	return string.format("%d %s", ability.resourceCost, ability.resourceType)
end

--------------------------------------------------------------------------------
-- BUILD UI
--------------------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name          = "AbilityBarUI"
screenGui.ResetOnSpawn  = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent        = playerGui

-- Total bar width
local totalWidth = BAR_SLOTS * SLOT_SIZE + (BAR_SLOTS - 1) * SLOT_GAP

-- Bar container
local barFrame = Instance.new("Frame")
barFrame.Name            = "AbilityBar"
barFrame.AnchorPoint     = Vector2.new(0.5, 1)
barFrame.Position        = UDim2.new(0.5, 0, 1, -BOTTOM_OFFSET)
barFrame.Size            = UDim2.fromOffset(totalWidth, SLOT_SIZE)
barFrame.BackgroundTransparency = 1
barFrame.Parent          = screenGui

-- Tooltip (hidden by default)
local tooltipFrame = Instance.new("Frame")
tooltipFrame.Name              = "Tooltip"
tooltipFrame.AnchorPoint       = Vector2.new(0.5, 1)
tooltipFrame.Position          = UDim2.new(0.5, 0, 1, -(BOTTOM_OFFSET + SLOT_SIZE + 8))
tooltipFrame.Size              = UDim2.fromOffset(TOOLTIP_WIDTH, 1)
tooltipFrame.AutomaticSize     = Enum.AutomaticSize.Y
tooltipFrame.BackgroundColor3  = COL_TOOLTIP
tooltipFrame.BackgroundTransparency = 0.05
tooltipFrame.BorderSizePixel   = 0
tooltipFrame.Visible           = false
tooltipFrame.ZIndex            = 20
tooltipFrame.Parent            = screenGui
tooltip = tooltipFrame

local ttCorner = Instance.new("UICorner")
ttCorner.CornerRadius = UDim.new(0, 6)
ttCorner.Parent = tooltipFrame

local ttPad = Instance.new("UIPadding")
ttPad.PaddingTop    = UDim.new(0, TOOLTIP_PADDING)
ttPad.PaddingBottom = UDim.new(0, TOOLTIP_PADDING)
ttPad.PaddingLeft   = UDim.new(0, TOOLTIP_PADDING)
ttPad.PaddingRight  = UDim.new(0, TOOLTIP_PADDING)
ttPad.Parent = tooltipFrame

local ttLayout = Instance.new("UIListLayout")
ttLayout.SortOrder        = Enum.SortOrder.LayoutOrder
ttLayout.Padding          = UDim.new(0, 4)
ttLayout.FillDirection    = Enum.FillDirection.Vertical
ttLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
ttLayout.Parent           = tooltipFrame

local function makeTTLabel(name: string, order: number, size: number, bold: boolean): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.Name            = name
	lbl.LayoutOrder     = order
	lbl.Size            = UDim2.new(1, 0, 0, size + 4)
	lbl.AutomaticSize   = Enum.AutomaticSize.Y
	lbl.BackgroundTransparency = 1
	lbl.TextColor3      = COL_TEXT
	lbl.TextSize        = size
	lbl.Font            = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	lbl.TextXAlignment  = Enum.TextXAlignment.Left
	lbl.TextWrapped     = true
	lbl.Text            = ""
	lbl.ZIndex          = 21
	lbl.Parent          = tooltipFrame
	return lbl
end

local ttName    = makeTTLabel("TT_Name",    1, 14, true)
local ttSchool  = makeTTLabel("TT_School",  2, 11, false)
local ttDesc    = makeTTLabel("TT_Desc",    3, 11, false)
local ttCost    = makeTTLabel("TT_Cost",    4, 11, false)
local ttCD      = makeTTLabel("TT_CD",      5, 11, false)
local ttTier    = makeTTLabel("TT_Tier",    6, 11, false)
ttSchool.TextColor3 = COL_SUBTEXT
ttDesc.TextColor3   = Color3.fromRGB(200, 200, 200)
ttCost.TextColor3   = COL_SUBTEXT
ttCD.TextColor3     = COL_SUBTEXT
ttTier.TextColor3   = Color3.fromRGB(255, 200, 80)

-- Build each slot
for i = 1, BAR_SLOTS do
	local x = (i - 1) * (SLOT_SIZE + SLOT_GAP)

	-- Outer frame (border)
	local outer = Instance.new("Frame")
	outer.Name            = "Slot" .. i
	outer.Position        = UDim2.fromOffset(x, 0)
	outer.Size            = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)
	outer.BackgroundColor3 = COL_BORDER
	outer.BorderSizePixel  = 0
	outer.Parent          = barFrame

	local outerCorner = Instance.new("UICorner")
	outerCorner.CornerRadius = UDim.new(0, 8)
	outerCorner.Parent = outer

	-- Inner background
	local inner = Instance.new("Frame")
	inner.Name              = "Inner"
	inner.Position          = UDim2.fromOffset(2, 2)
	inner.Size              = UDim2.fromOffset(SLOT_SIZE - 4, SLOT_SIZE - 4)
	inner.BackgroundColor3  = COL_BG
	inner.BorderSizePixel   = 0
	inner.ZIndex            = 2
	inner.Parent            = outer

	local innerCorner = Instance.new("UICorner")
	innerCorner.CornerRadius = UDim.new(0, 6)
	innerCorner.Parent = inner

	-- Icon label (text emoji as placeholder; swap for ImageLabel + asset in production)
	local iconLbl = Instance.new("TextLabel")
	iconLbl.Name               = "Icon"
	iconLbl.Size               = UDim2.fromScale(1, 1)
	iconLbl.BackgroundTransparency = 1
	iconLbl.TextColor3         = COL_TEXT
	iconLbl.TextSize           = 28
	iconLbl.Font               = Enum.Font.GothamBold
	iconLbl.Text               = "—"
	iconLbl.ZIndex             = 3
	iconLbl.Parent             = inner
	iconLabels[i] = iconLbl

	-- Keybind label (bottom-right corner)
	local keyLbl = Instance.new("TextLabel")
	keyLbl.Name               = "KeyBind"
	keyLbl.AnchorPoint        = Vector2.new(1, 1)
	keyLbl.Position           = UDim2.new(1, -4, 1, -4)
	keyLbl.Size               = UDim2.fromOffset(16, 14)
	keyLbl.BackgroundTransparency = 1
	keyLbl.TextColor3         = COL_SUBTEXT
	keyLbl.TextSize           = 11
	keyLbl.Font               = Enum.Font.Gotham
	keyLbl.Text               = tostring(i)
	keyLbl.ZIndex             = 4
	keyLbl.Parent             = inner
	keyLabels[i] = keyLbl

	-- Cooldown overlay (dark tint + arc label)
	local cdOverlay = Instance.new("Frame")
	cdOverlay.Name              = "CDOverlay"
	cdOverlay.Size              = UDim2.fromScale(1, 1)
	cdOverlay.BackgroundColor3  = COL_CD_TINT
	cdOverlay.BackgroundTransparency = 0.4
	cdOverlay.BorderSizePixel   = 0
	cdOverlay.Visible           = false
	cdOverlay.ZIndex            = 5
	cdOverlay.Parent            = inner

	local cdCorner = Instance.new("UICorner")
	cdCorner.CornerRadius = UDim.new(0, 6)
	cdCorner.Parent = cdOverlay

	local cdLbl = Instance.new("TextLabel")
	cdLbl.Name               = "CDLabel"
	cdLbl.Size               = UDim2.fromScale(1, 1)
	cdLbl.BackgroundTransparency = 1
	cdLbl.TextColor3         = Color3.fromRGB(255, 255, 255)
	cdLbl.TextSize           = 16
	cdLbl.Font               = Enum.Font.GothamBold
	cdLbl.Text               = ""
	cdLbl.ZIndex             = 6
	cdLbl.Parent             = cdOverlay
	cdOverlays[i]  = cdOverlay
	cdLabels[i]    = cdLbl

	-- Tier-lock overlay
	local lockOverlay = Instance.new("Frame")
	lockOverlay.Name              = "LockOverlay"
	lockOverlay.Size              = UDim2.fromScale(1, 1)
	lockOverlay.BackgroundColor3  = COL_LOCKED
	lockOverlay.BackgroundTransparency = 0.3
	lockOverlay.BorderSizePixel   = 0
	lockOverlay.Visible           = false
	lockOverlay.ZIndex            = 7
	lockOverlay.Parent            = inner

	local lockCorner = Instance.new("UICorner")
	lockCorner.CornerRadius = UDim.new(0, 6)
	lockCorner.Parent = lockOverlay

	local lockLbl = Instance.new("TextLabel")
	lockLbl.Name               = "LockLabel"
	lockLbl.Size               = UDim2.fromScale(1, 1)
	lockLbl.BackgroundTransparency = 1
	lockLbl.TextColor3         = Color3.fromRGB(255, 200, 80)
	lockLbl.TextSize           = 22
	lockLbl.Font               = Enum.Font.GothamBold
	lockLbl.Text               = "🔒"
	lockLbl.ZIndex             = 8
	lockLbl.Parent             = lockOverlay
	lockLabels[i] = lockLbl

	slotFrames[i] = outer

	-- Hover detection via MouseEnter / MouseLeave on inner
	inner.MouseEnter:Connect(function()
		hoveredSlot = i
		if slots[i].abilityId then
			updateTooltip(i)
			tooltipFrame.Visible = true
		end
		if not slots[i].locked then
			TweenService:Create(outer, TweenInfo.new(0.1), { BackgroundColor3 = COL_HOVER }):Play()
		end
	end)
	inner.MouseLeave:Connect(function()
		if hoveredSlot == i then
			hoveredSlot = 0
			tooltipFrame.Visible = false
		end
		TweenService:Create(outer, TweenInfo.new(0.1), { BackgroundColor3 = COL_BORDER }):Play()
	end)

	-- Click to cast
	local button = Instance.new("TextButton")
	button.Name               = "ClickTarget"
	button.Size               = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.Text               = ""
	button.ZIndex             = 10
	button.Parent             = inner
	button.MouseButton1Click:Connect(function()
		castSlot(i)
	end)
end

--------------------------------------------------------------------------------
-- SLOT POPULATION
--------------------------------------------------------------------------------

--- Update a single slot's visual to reflect its ability (or empty).
local function refreshSlot(i: number)
	local data    = slots[i]
	local abilityId = data.abilityId
	local outer   = slotFrames[i]
	local iconLbl = iconLabels[i]
	local lockOv  = slotFrames[i]:FindFirstChild("Inner", true) :: Frame
	local lockOlay = lockOv and lockOv:FindFirstChild("LockOverlay") :: Frame?

	if not abilityId then
		iconLbl.Text = "—"
		iconLbl.TextColor3 = COL_SUBTEXT
		if lockOlay then lockOlay.Visible = false end
		outer.BackgroundColor3 = COL_BORDER
		return
	end

	local ability = AbilityConfig.GetAbility(abilityId)
	if not ability then
		iconLbl.Text = "?"
		return
	end

	-- Icon: use animationTag initials as stand-in
	local tag = ability.animationTag or ability.id
	iconLbl.Text = string.sub(tag, 1, 2):upper()
	iconLbl.TextColor3 = getSchoolColour(ability.tags)

	-- Tier lock
	local tierRequired = ability.minMagicTier or 0
	data.locked = (tierRequired > playerMagicTier)
	if lockOlay then
		lockOlay.Visible = data.locked
	end

	-- Border colour: school colour tint if unlocked
	if data.locked then
		outer.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	else
		outer.BackgroundColor3 = COL_BORDER
	end
end

--- Populate slots with an ordered list of ability IDs.
local function loadAbilities(abilityIds: { string })
	for i = 1, BAR_SLOTS do
		slots[i].abilityId   = abilityIds[i] or nil
		slots[i].cooldownEnd = 0
		slots[i].locked      = false
		refreshSlot(i)
	end
end

--------------------------------------------------------------------------------
-- TOOLTIP UPDATE
--------------------------------------------------------------------------------

function updateTooltip(i: number)
	local abilityId = slots[i].abilityId
	if not abilityId then return end
	local ability = AbilityConfig.GetAbility(abilityId)
	if not ability then return end

	ttName.Text  = ability.name
	ttName.TextColor3 = getSchoolColour(ability.tags)

	-- School tags
	local schools: { string } = {}
	for _, tag in ipairs(ability.tags) do
		if SCHOOL_COLOURS[tag] then table.insert(schools, tag) end
	end
	ttSchool.Text = #schools > 0 and table.concat(schools, " / ") or ""

	ttDesc.Text = ability.description

	-- Cost
	ttCost.Text = "Cost: " .. formatResource(ability)

	-- Cooldown
	local cdSecs = slots[i].cooldownEnd > 0
		and math.max(0, slots[i].cooldownEnd - os.clock())
		or 0
	if ability.cooldown > 0 then
		ttCD.Text = cdSecs > 0
			and string.format("Cooldown: %.1fs remaining", cdSecs)
			or string.format("Cooldown: %ds", ability.cooldown)
	else
		ttCD.Text = "Cooldown: None"
	end

	-- Tier requirement
	local tier = ability.minMagicTier or 0
	if tier > 0 then
		ttTier.Text = string.format("Requires Magic Tier %d  (you have %d)", tier, playerMagicTier)
		ttTier.TextColor3 = slots[i].locked
			and Color3.fromRGB(255, 80, 80)
			or Color3.fromRGB(80, 220, 80)
	else
		ttTier.Text = ""
	end

	-- Reposition tooltip above hovered slot
	local slotFrame = slotFrames[i]
	local barCentreX = (SLOT_SIZE + SLOT_GAP) * (i - 1) + SLOT_SIZE / 2
	local totalW = BAR_SLOTS * SLOT_SIZE + (BAR_SLOTS - 1) * SLOT_GAP
	local normX  = (barCentreX) / totalW
	if tooltip then
		tooltip.Position = UDim2.new(normX, 0, 1, -(BOTTOM_OFFSET + SLOT_SIZE + 12))
	end
end

--------------------------------------------------------------------------------
-- CAST
--------------------------------------------------------------------------------

function castSlot(i: number)
	local data = slots[i]
	if not data.abilityId then return end
	if data.locked then return end

	-- Local CD gate (server is authoritative; this just prevents spam clicks)
	if data.cooldownEnd > 0 and os.clock() < data.cooldownEnd then return end

	-- Fire to server — targetId omitted (server infers Self/AoE or requires explicit targeting)
	local castEvent = AbilityRemotes.GetEvent("CastAbility")
	castEvent:FireServer(data.abilityId, nil)

	-- Optimistic: pulse the slot border
	local outer = slotFrames[i]
	TweenService:Create(outer, TweenInfo.new(0.08), { BackgroundColor3 = COL_HIGHLIGHT }):Play()
	task.delay(0.15, function()
		if not data.locked then
			TweenService:Create(outer, TweenInfo.new(0.15), { BackgroundColor3 = COL_BORDER }):Play()
		end
	end)
end

--------------------------------------------------------------------------------
-- COOLDOWN UPDATE (from CooldownSync remote)
--------------------------------------------------------------------------------

local function applyCooldownSync(cdMap: { [string]: number })
	-- cdMap: { [abilityId] = remainingSeconds }
	local now = os.clock()
	for i = 1, BAR_SLOTS do
		local abilityId = slots[i].abilityId
		if not abilityId then continue end
		local remaining = cdMap[abilityId]
		if type(remaining) == "number" and remaining > 0 then
			slots[i].cooldownEnd = now + remaining
		elseif cdMap[abilityId] == 0 then
			slots[i].cooldownEnd = 0
		end
	end
end

--------------------------------------------------------------------------------
-- RUNSERVICE: cooldown overlay tick
--------------------------------------------------------------------------------

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for i = 1, BAR_SLOTS do
		local data    = slots[i]
		local overlay = cdOverlays[i]
		local lbl     = cdLabels[i]
		if data.cooldownEnd > 0 then
			local rem = data.cooldownEnd - now
			if rem > 0 then
				overlay.Visible = true
				lbl.Text = formatCooldown(rem)
			else
				data.cooldownEnd = 0
				overlay.Visible = false
				lbl.Text = ""
				-- Flash slot available
				TweenService:Create(slotFrames[i], TweenInfo.new(0.2), {
					BackgroundColor3 = Color3.fromRGB(120, 200, 120)
				}):Play()
				task.delay(0.3, function()
					TweenService:Create(slotFrames[i], TweenInfo.new(0.2), {
						BackgroundColor3 = data.locked and Color3.fromRGB(50, 50, 60) or COL_BORDER
					}):Play()
				end)
			end
		else
			overlay.Visible = false
			lbl.Text = ""
		end
	end
end)

--------------------------------------------------------------------------------
-- KEYBOARD INPUT
--------------------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end
	for i, keyCode in ipairs(KEYBINDS) do
		if input.KeyCode == keyCode then
			castSlot(i)
			return
		end
	end
end)

--------------------------------------------------------------------------------
-- REMOTE LISTENERS
--------------------------------------------------------------------------------

-- CooldownSync: server sends remaining seconds map after a cast
local syncEvent = AbilityRemotes.GetEvent("CooldownSync")
syncEvent.OnClientEvent:Connect(function(cdMap: any)
	if type(cdMap) ~= "table" then return end
	applyCooldownSync(cdMap :: { [string]: number })
end)

-- AbilityGranted: server sends updated ability list on tier/class change
local grantedEvent = AbilityRemotes.GetEvent("AbilityGranted")
grantedEvent.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	-- payload.unlockedSpells: { string } — ordered list for hotbar
	-- payload.magicTier: number
	if type(payload.magicTier) == "number" then
		playerMagicTier = payload.magicTier
	end
	if type(payload.unlockedSpells) == "table" then
		loadAbilities(payload.unlockedSpells :: { string })
	else
		-- Just refresh tier lock state
		for i = 1, BAR_SLOTS do refreshSlot(i) end
	end
end)

--------------------------------------------------------------------------------
-- INITIAL LOAD
-- Request the player's current class abilities from local data if available,
-- or wait for the AbilityGranted event from the server.
-- As a safe default, pre-populate with empty slots so the bar is always visible.
--------------------------------------------------------------------------------

task.spawn(function()
	-- Give PlayerDataService time to load
	task.wait(3)
	-- Attempt to read class + tier from character attributes set by CharacterService
	local char = player.Character or player.CharacterAdded:Wait()
	local mt = char:GetAttribute("MagicTier")
	if type(mt) == "number" then
		playerMagicTier = mt
	end

	-- Class abilities: read from AbilityConfig based on class attribute
	local className = char:GetAttribute("SelectedClass") :: string?
	local roleName  = char:GetAttribute("SelectedRole") :: string?
	local level     = char:GetAttribute("Level") :: number? or 1

	if className and roleName then
		local available = AbilityConfig.GetAvailableAbilities(
			className, roleName, level, playerMagicTier
		)
		local ids: { string } = {}
		for _, ab in ipairs(available) do
			table.insert(ids, ab.id)
			if #ids >= BAR_SLOTS then break end
		end
		loadAbilities(ids)
	end
end)

print("[AbilityBarUI] Hotbar ready.")
