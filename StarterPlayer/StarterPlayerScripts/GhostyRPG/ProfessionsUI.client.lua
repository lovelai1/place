--!strict
-- ProfessionsUI.client.lua
-- Toggle with "P". Shows profession levels and crafting recipes.
-- Craft via InventoryRemotes → CraftItem event.
-- Data pulled from PlayerRemotes.SendInitialData and InventoryUpdated pushes.

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SharedRemotes    = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
local InventoryRemotes = require(SharedRemotes:WaitForChild("InventoryRemotes"))
local PlayerRemotes    = require(SharedRemotes:WaitForChild("PlayerRemotes"))
local ItemConfig       = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ItemConfig")
)

-- ── palette ───────────────────────────────────────────────────────────────

local PANEL_BG      = Color3.fromRGB(12, 14, 22)
local CARD_BG       = Color3.fromRGB(20, 23, 35)
local SLOT_BG       = Color3.fromRGB(22, 25, 34)
local HEADER_YELLOW = Color3.fromRGB(255, 200, 60)
local TEXT_DIM      = Color3.fromRGB(140, 140, 160)
local TEXT_BRIGHT   = Color3.fromRGB(220, 220, 230)
local GREEN         = Color3.fromRGB(60, 210, 90)
local RED           = Color3.fromRGB(220, 70, 70)
local GOLD          = Color3.fromRGB(255, 195, 40)

-- ── profession definitions (mirrors ProfessionConfig.Professions) ─────────
-- We embed the recipe data client-side for display only.
-- The server validates and executes the actual craft.

type Ingredient = { itemId: string, amount: number }
type Recipe = {
	recipeName   : string,
	displayName  : string,
	requiredLevel: number,
	ingredients  : { Ingredient },
	outputItemId : string,
	outputAmount : number,
	xpReward     : number,
}
type ProfessionDef = {
	name     : string,
	icon     : string,
	maxLevel : number,
	recipes  : { Recipe },
}

local PROFESSIONS: { [string]: ProfessionDef } = {
	Alchemy = {
		name    = "Алхимия",
		icon    = "⚗",
		maxLevel = 100,
		recipes = {
			{
				recipeName    = "health_potion",
				displayName   = "Зелье здоровья",
				requiredLevel = 1,
				ingredients   = {
					{ itemId = "item_mistleaf", amount = 2 },
					{ itemId = "empty_vial",   amount = 1 },
				},
				outputItemId  = "item_health_potion",
				outputAmount  = 1,
				xpReward      = 20,
			},
			{
				recipeName    = "mana_potion",
				displayName   = "Зелье маны",
				requiredLevel = 10,
				ingredients   = {
					{ itemId = "item_mistleaf", amount = 1 },
					{ itemId = "empty_vial",   amount = 1 },
				},
				outputItemId  = "item_mana_potion",
				outputAmount  = 1,
				xpReward      = 40,
			},
		},
	},
	Mining = {
		name    = "Горное дело",
		icon    = "⛏",
		maxLevel = 100,
		recipes = {},  -- Mining is a gathering profession; no crafting recipes
	},
}

-- ── state ─────────────────────────────────────────────────────────────────

local playerProfessions: { [string]: { Level: number, XP: number } } = {
	Mining  = { Level = 1, XP = 0 },
	Alchemy = { Level = 1, XP = 0 },
}
local playerInventory: { [string]: { amount: number } } = {}
local activeProfKey = "Alchemy"

local craftCooldown = false  -- simple client-side debounce

-- ── build GUI ─────────────────────────────────────────────────────────────

local screenGui              = Instance.new("ScreenGui")
screenGui.Name               = "ProfessionsUI"
screenGui.ResetOnSpawn       = false
screenGui.IgnoreGuiInset     = false
screenGui.DisplayOrder       = 11
screenGui.Enabled            = false
screenGui.Parent             = playerGui

-- Root frame
local root                   = Instance.new("Frame")
root.Name                    = "Root"
root.AnchorPoint             = Vector2.new(0.5, 0.5)
root.Position                = UDim2.new(0.5, 0, 0.5, 0)
root.Size                    = UDim2.fromOffset(580, 440)
root.BackgroundColor3        = PANEL_BG
root.BackgroundTransparency  = 0.08
root.BorderSizePixel         = 0
root.Parent                  = screenGui
Instance.new("UICorner", root).CornerRadius = UDim.new(0, 10)

-- Title bar
local titleBar               = Instance.new("Frame")
titleBar.Size                = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3    = Color3.fromRGB(8, 10, 18)
titleBar.BorderSizePixel     = 0
titleBar.Parent              = root
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

local titleLabel             = Instance.new("TextLabel")
titleLabel.Size              = UDim2.new(1, -50, 1, 0)
titleLabel.Position          = UDim2.fromOffset(14, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Font              = Enum.Font.GothamBold
titleLabel.TextSize          = 14
titleLabel.TextColor3        = HEADER_YELLOW
titleLabel.TextXAlignment    = Enum.TextXAlignment.Left
titleLabel.Text              = "⚗ ПРОФЕССИИ"
titleLabel.Parent            = titleBar

local closeBtn               = Instance.new("TextButton")
closeBtn.Size                = UDim2.fromOffset(28, 28)
closeBtn.AnchorPoint         = Vector2.new(1, 0.5)
closeBtn.Position            = UDim2.new(1, -6, 0.5, 0)
closeBtn.BackgroundColor3    = Color3.fromRGB(160, 40, 40)
closeBtn.TextColor3          = Color3.fromRGB(255, 230, 230)
closeBtn.Font                = Enum.Font.GothamBold
closeBtn.TextSize            = 14
closeBtn.Text                = "×"
closeBtn.BorderSizePixel     = 0
closeBtn.Parent              = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)

-- Left: tab list
local tabColumn              = Instance.new("Frame")
tabColumn.Name               = "Tabs"
tabColumn.Position           = UDim2.fromOffset(0, 36)
tabColumn.Size               = UDim2.fromOffset(140, 404)
tabColumn.BackgroundColor3   = Color3.fromRGB(8, 10, 18)
tabColumn.BorderSizePixel    = 0
tabColumn.Parent             = root

local tabLayout              = Instance.new("UIListLayout")
tabLayout.SortOrder          = Enum.SortOrder.LayoutOrder
tabLayout.Padding            = UDim.new(0, 0)
tabLayout.Parent             = tabColumn

-- Right: content area
local contentArea            = Instance.new("Frame")
contentArea.Name             = "Content"
contentArea.Position         = UDim2.fromOffset(140, 36)
contentArea.Size             = UDim2.new(1, -140, 1, -36)
contentArea.BackgroundTransparency = 1
contentArea.ClipsDescendants = true
contentArea.Parent           = root

-- Status bar (feedback line at the bottom of content)
local statusBar              = Instance.new("Frame")
statusBar.Name               = "StatusBar"
statusBar.AnchorPoint        = Vector2.new(0, 1)
statusBar.Position           = UDim2.new(0, 0, 1, 0)
statusBar.Size               = UDim2.new(1, 0, 0, 28)
statusBar.BackgroundColor3   = Color3.fromRGB(8, 10, 18)
statusBar.BorderSizePixel    = 0
statusBar.Parent             = contentArea

local statusLabel            = Instance.new("TextLabel")
statusLabel.Size             = UDim2.new(1, -12, 1, 0)
statusLabel.Position         = UDim2.fromOffset(10, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Font             = Enum.Font.Gotham
statusLabel.TextSize         = 11
statusLabel.TextColor3       = TEXT_DIM
statusLabel.TextXAlignment   = Enum.TextXAlignment.Left
statusLabel.Text             = "Выберите рецепт для крафта."
statusLabel.Parent           = statusBar

-- ── tab button factory ────────────────────────────────────────────────────

local tabButtons: { [string]: TextButton } = {}

local function setStatus(msg: string, color: Color3?)
	statusLabel.Text      = msg
	statusLabel.TextColor3 = color or TEXT_DIM
	task.delay(4, function()
		if statusLabel.Text == msg then
			statusLabel.Text      = "Выберите рецепт для крафта."
			statusLabel.TextColor3 = TEXT_DIM
		end
	end)
end

local contentFrames: { [string]: Frame } = {}

local function switchTab(profKey: string)
	activeProfKey = profKey

	for key, frame in pairs(contentFrames) do
		frame.Visible = key == profKey
	end
	for key, btn in pairs(tabButtons) do
		btn.BackgroundColor3 = if key == profKey
			then Color3.fromRGB(28, 32, 50)
			else Color3.fromRGB(8, 10, 18)
		btn.TextColor3 = if key == profKey then HEADER_YELLOW else TEXT_DIM
	end
end

local function makeTabButton(profKey: string, profDef: ProfessionDef, order: number): TextButton
	local btn            = Instance.new("TextButton")
	btn.Name             = profKey
	btn.Size             = UDim2.new(1, 0, 0, 56)
	btn.BackgroundColor3 = Color3.fromRGB(8, 10, 18)
	btn.BorderSizePixel  = 0
	btn.LayoutOrder      = order
	btn.Parent           = tabColumn

	local iconLabel      = Instance.new("TextLabel")
	iconLabel.Size       = UDim2.new(1, 0, 0, 24)
	iconLabel.Position   = UDim2.fromOffset(0, 8)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Font       = Enum.Font.GothamBold
	iconLabel.TextSize   = 18
	iconLabel.TextColor3 = HEADER_YELLOW
	iconLabel.Text       = profDef.icon
	iconLabel.Parent     = btn

	local nameLabel      = Instance.new("TextLabel")
	nameLabel.Size       = UDim2.new(1, 0, 0, 14)
	nameLabel.Position   = UDim2.fromOffset(0, 34)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font       = Enum.Font.Gotham
	nameLabel.TextSize   = 10
	nameLabel.TextColor3 = TEXT_DIM
	nameLabel.Text       = profDef.name
	nameLabel.Parent     = btn

	-- Separator line at the bottom
	local sep            = Instance.new("Frame")
	sep.Size             = UDim2.new(1, 0, 0, 1)
	sep.AnchorPoint      = Vector2.new(0, 1)
	sep.Position         = UDim2.new(0, 0, 1, 0)
	sep.BackgroundColor3 = Color3.fromRGB(30, 34, 50)
	sep.BorderSizePixel  = 0
	sep.Parent           = btn

	btn.MouseButton1Click:Connect(function()
		switchTab(profKey)
	end)

	tabButtons[profKey] = btn
	return btn
end

-- ── content panel builder ─────────────────────────────────────────────────

local recipeButtons: { [string]: TextButton } = {}  -- recipeName → craft button

local function canCraft(recipe: Recipe): boolean
	local profData = playerProfessions["Alchemy"]  -- only Alchemy has recipes
	if not profData or profData.Level < recipe.requiredLevel then return false end
	for _, ing in ipairs(recipe.ingredients) do
		local slot = playerInventory[ing.itemId]
		local have = if slot then slot.amount else 0
		if have < ing.amount then return false end
	end
	return true
end

local function refreshRecipeButtons()
	for recipeName, btn in pairs(recipeButtons) do
		-- Walk all professions to find the recipe
		for _, profDef in pairs(PROFESSIONS) do
			for _, recipe in ipairs(profDef.recipes) do
				if recipe.recipeName == recipeName then
					local craftable     = canCraft(recipe)
					btn.BackgroundColor3 = if craftable then Color3.fromRGB(30, 100, 50) else Color3.fromRGB(60, 30, 30)
					btn.TextColor3       = if craftable then GREEN else RED
					btn.AutoButtonColor  = craftable
				end
			end
		end
	end
end

local function buildContentFrame(profKey: string, profDef: ProfessionDef): Frame
	local frame              = Instance.new("Frame")
	frame.Name               = profKey
	frame.Size               = UDim2.new(1, 0, 1, -30)  -- leave room for status bar
	frame.BackgroundTransparency = 1
	frame.Visible            = false
	frame.Parent             = contentArea

	-- ── profession header: level + XP bar ────────────────────────────────

	local headerCard         = Instance.new("Frame")
	headerCard.Size          = UDim2.new(1, -20, 0, 64)
	headerCard.Position      = UDim2.fromOffset(10, 10)
	headerCard.BackgroundColor3 = CARD_BG
	headerCard.BorderSizePixel  = 0
	headerCard.Parent        = frame
	Instance.new("UICorner", headerCard).CornerRadius = UDim.new(0, 8)

	local profNameLabel      = Instance.new("TextLabel")
	profNameLabel.Name       = "ProfName"
	profNameLabel.Size       = UDim2.new(0.5, 0, 0, 20)
	profNameLabel.Position   = UDim2.fromOffset(12, 8)
	profNameLabel.BackgroundTransparency = 1
	profNameLabel.Font       = Enum.Font.GothamBold
	profNameLabel.TextSize   = 13
	profNameLabel.TextColor3 = HEADER_YELLOW
	profNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	profNameLabel.Text       = profDef.icon .. "  " .. profDef.name
	profNameLabel.Parent     = headerCard

	local levelLabel         = Instance.new("TextLabel")
	levelLabel.Name          = "LevelLabel"
	levelLabel.Size          = UDim2.new(0.5, -12, 0, 20)
	levelLabel.AnchorPoint   = Vector2.new(1, 0)
	levelLabel.Position      = UDim2.new(1, -12, 0, 8)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Font          = Enum.Font.GothamBold
	levelLabel.TextSize      = 13
	levelLabel.TextColor3    = GOLD
	levelLabel.TextXAlignment = Enum.TextXAlignment.Right
	levelLabel.Text          = "Ур. 1"
	levelLabel.Parent        = headerCard

	-- XP bar background
	local xpBarBg            = Instance.new("Frame")
	xpBarBg.Name             = "XPBarBg"
	xpBarBg.Size             = UDim2.new(1, -24, 0, 8)
	xpBarBg.Position         = UDim2.fromOffset(12, 36)
	xpBarBg.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	xpBarBg.BorderSizePixel  = 0
	xpBarBg.Parent           = headerCard
	Instance.new("UICorner", xpBarBg).CornerRadius = UDim.new(0, 4)

	local xpBarFill          = Instance.new("Frame")
	xpBarFill.Name           = "XPBarFill"
	xpBarFill.Size           = UDim2.new(0, 0, 1, 0)
	xpBarFill.BackgroundColor3 = GOLD
	xpBarFill.BorderSizePixel  = 0
	xpBarFill.Parent         = xpBarBg
	Instance.new("UICorner", xpBarFill).CornerRadius = UDim.new(0, 4)

	local xpLabel            = Instance.new("TextLabel")
	xpLabel.Name             = "XPLabel"
	xpLabel.Size             = UDim2.new(1, -24, 0, 14)
	xpLabel.Position         = UDim2.fromOffset(12, 48)
	xpLabel.BackgroundTransparency = 1
	xpLabel.Font             = Enum.Font.Gotham
	xpLabel.TextSize         = 9
	xpLabel.TextColor3       = TEXT_DIM
	xpLabel.TextXAlignment   = Enum.TextXAlignment.Left
	xpLabel.Text             = "0 / 0 XP"
	xpLabel.Parent           = headerCard

	-- ── recipe list ───────────────────────────────────────────────────────

	if #profDef.recipes == 0 then
		local gatherNote     = Instance.new("TextLabel")
		gatherNote.Size      = UDim2.new(1, -20, 0, 60)
		gatherNote.Position  = UDim2.fromOffset(10, 82)
		gatherNote.BackgroundTransparency = 1
		gatherNote.Font      = Enum.Font.Gotham
		gatherNote.TextSize  = 11
		gatherNote.TextColor3 = TEXT_DIM
		gatherNote.TextWrapped = true
		gatherNote.TextXAlignment = Enum.TextXAlignment.Left
		gatherNote.Text      = "Это профессия добычи ресурсов.\nКрафт не требуется — добывайте узлы в открытом мире для получения материалов и XP."
		gatherNote.Parent    = frame
		return frame
	end

	local recipeScroll       = Instance.new("ScrollingFrame")
	recipeScroll.Name        = "RecipeList"
	recipeScroll.Position    = UDim2.fromOffset(10, 82)
	recipeScroll.Size        = UDim2.new(1, -20, 1, -92)
	recipeScroll.CanvasSize  = UDim2.new(0, 0, 0, 0)
	recipeScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	recipeScroll.BackgroundTransparency = 1
	recipeScroll.BorderSizePixel = 0
	recipeScroll.ScrollBarThickness = 4
	recipeScroll.ScrollBarImageColor3 = HEADER_YELLOW
	recipeScroll.Parent      = frame

	local recipeListLayout   = Instance.new("UIListLayout")
	recipeListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	recipeListLayout.Padding  = UDim.new(0, 6)
	recipeListLayout.Parent  = recipeScroll

	for ri, recipe in ipairs(profDef.recipes) do
		local card           = Instance.new("Frame")
		card.Name            = recipe.recipeName
		card.Size            = UDim2.new(1, 0, 0, 80)
		card.BackgroundColor3 = CARD_BG
		card.BorderSizePixel  = 0
		card.LayoutOrder     = ri
		card.Parent          = recipeScroll
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 7)

		-- Recipe title
		local rNameLabel     = Instance.new("TextLabel")
		rNameLabel.Size      = UDim2.new(1, -100, 0, 18)
		rNameLabel.Position  = UDim2.fromOffset(10, 8)
		rNameLabel.BackgroundTransparency = 1
		rNameLabel.Font      = Enum.Font.GothamBold
		rNameLabel.TextSize  = 12
		rNameLabel.TextColor3 = TEXT_BRIGHT
		rNameLabel.TextXAlignment = Enum.TextXAlignment.Left
		rNameLabel.Text      = recipe.displayName
		rNameLabel.Parent    = card

		-- Required level badge
		local lvlBadge       = Instance.new("TextLabel")
		lvlBadge.Size        = UDim2.fromOffset(80, 16)
		lvlBadge.AnchorPoint = Vector2.new(1, 0)
		lvlBadge.Position    = UDim2.new(1, -8, 0, 8)
		lvlBadge.BackgroundTransparency = 1
		lvlBadge.Font        = Enum.Font.Gotham
		lvlBadge.TextSize    = 10
		lvlBadge.TextColor3  = TEXT_DIM
		lvlBadge.TextXAlignment = Enum.TextXAlignment.Right
		lvlBadge.Text        = "Треб. ур. " .. recipe.requiredLevel
		lvlBadge.Parent      = card

		-- Output line
		local outputDef      = ItemConfig.GetItem(recipe.outputItemId)
		local outputName     = (outputDef and outputDef.name) or recipe.outputItemId
		local outputLabel    = Instance.new("TextLabel")
		outputLabel.Size     = UDim2.new(1, -100, 0, 14)
		outputLabel.Position = UDim2.fromOffset(10, 28)
		outputLabel.BackgroundTransparency = 1
		outputLabel.Font     = Enum.Font.Gotham
		outputLabel.TextSize = 10
		outputLabel.TextColor3 = GREEN
		outputLabel.TextXAlignment = Enum.TextXAlignment.Left
		outputLabel.Text     = "→ " .. outputName .. " ×" .. recipe.outputAmount
			.. "  (+" .. recipe.xpReward .. " XP)"
		outputLabel.Parent   = card

		-- Ingredients list
		local ingredParts: { string } = {}
		for _, ing in ipairs(recipe.ingredients) do
			local ingDef = ItemConfig.GetItem(ing.itemId)
			local ingName = (ingDef and ingDef.name) or ing.itemId
			local have    = if playerInventory[ing.itemId] then playerInventory[ing.itemId].amount else 0
			table.insert(ingredParts, string.format("%s ×%d (%d)", ingName, ing.amount, have))
		end

		local ingredLabel    = Instance.new("TextLabel")
		ingredLabel.Name     = "Ingredients"
		ingredLabel.Size     = UDim2.new(1, -100, 0, 28)
		ingredLabel.Position = UDim2.fromOffset(10, 44)
		ingredLabel.BackgroundTransparency = 1
		ingredLabel.Font     = Enum.Font.Gotham
		ingredLabel.TextSize = 9
		ingredLabel.TextColor3 = TEXT_DIM
		ingredLabel.TextXAlignment = Enum.TextXAlignment.Left
		ingredLabel.TextWrapped = true
		ingredLabel.Text     = table.concat(ingredParts, "  •  ")
		ingredLabel.Parent   = card

		-- Craft button
		local craftBtn       = Instance.new("TextButton")
		craftBtn.Name        = "CraftBtn"
		craftBtn.Size        = UDim2.fromOffset(72, 30)
		craftBtn.AnchorPoint = Vector2.new(1, 0.5)
		craftBtn.Position    = UDim2.new(1, -8, 0.5, 0)
		craftBtn.BackgroundColor3 = Color3.fromRGB(30, 100, 50)
		craftBtn.TextColor3  = GREEN
		craftBtn.Font        = Enum.Font.GothamBold
		craftBtn.TextSize    = 11
		craftBtn.Text        = "Создать"
		craftBtn.BorderSizePixel = 0
		craftBtn.Parent      = card
		Instance.new("UICorner", craftBtn).CornerRadius = UDim.new(0, 5)

		recipeButtons[recipe.recipeName] = craftBtn

		local capturedRecipe = recipe
		craftBtn.MouseButton1Click:Connect(function()
			if craftCooldown then return end
			if not canCraft(capturedRecipe) then
				setStatus("Недостаточно материалов или уровня.", RED)
				return
			end

			craftCooldown = true
			craftBtn.Text = "…"

			InventoryRemotes.GetEvent("CraftItem"):FireServer({
				professionName = profKey,
				recipeName     = capturedRecipe.recipeName,
			})

			setStatus("Создание: " .. capturedRecipe.displayName .. "…", GOLD)

			-- Re-enable after a short debounce (server will push InventoryUpdated)
			task.delay(1.5, function()
				craftCooldown   = false
				craftBtn.Text   = "Создать"
			end)
		end)
	end

	-- Store references for live updates
	frame:SetAttribute("_profKey", profKey)

	-- Update XP bar & level display when UI is refreshed
	local function updateHeader()
		local profData = playerProfessions[profKey]
		if not profData then return end

		local lvl    = profData.Level
		local xp     = profData.XP
		local maxXP  = math.floor(lvl * 100 * (lvl ^ 0.6))  -- approx formula

		levelLabel.Text = "Ур. " .. lvl
		xpLabel.Text    = xp .. " / " .. maxXP .. " XP"
		local pct = math.clamp(xp / math.max(maxXP, 1), 0, 1)
		TweenService:Create(xpBarFill, TweenInfo.new(0.4), {
			Size = UDim2.new(pct, 0, 1, 0),
		}):Play()
	end

	-- Expose so we can call it from the refresh logic below
	frame:SetAttribute("_hasRecipes", #profDef.recipes > 0)
	frame.AttributeChanged:Connect(function(attr)
		if attr == "_refresh" then
			updateHeader()
			refreshRecipeButtons()
		end
	end)

	updateHeader()
	return frame
end

-- ── ingredient counts in recipe cards ────────────────────────────────────

local function updateIngredientLabels()
	for _, profDef in pairs(PROFESSIONS) do
		for _, recipe in ipairs(profDef.recipes) do
			local frame = contentFrames[activeProfKey]
			if not frame then continue end
			local recipeCard = frame:FindFirstDescendant(recipe.recipeName) :: Frame?
			if not recipeCard then continue end
			local ingredLabel = recipeCard:FindFirstChild("Ingredients") :: TextLabel?
			if not ingredLabel then continue end

			local parts: { string } = {}
			for _, ing in ipairs(recipe.ingredients) do
				local ingDef  = ItemConfig.GetItem(ing.itemId)
				local ingName = (ingDef and ingDef.name) or ing.itemId
				local have    = if playerInventory[ing.itemId] then playerInventory[ing.itemId].amount else 0
				local col     = if have >= ing.amount then "\u{001b}[32m" else ""  -- not used directly
				table.insert(parts, string.format("%s ×%d (%d)", ingName, ing.amount, have))
			end
			ingredLabel.Text = table.concat(parts, "  •  ")
		end
	end
end

local function fullRefresh()
	for profKey, frame in pairs(contentFrames) do
		-- Trigger header update via attribute sentinel
		frame:SetAttribute("_refresh", not frame:GetAttribute("_refresh"))
	end
	updateIngredientLabels()
	refreshRecipeButtons()
end

-- ── build all tabs ────────────────────────────────────────────────────────

local tabOrder = { "Alchemy", "Mining" }

for i, profKey in ipairs(tabOrder) do
	local profDef = PROFESSIONS[profKey]
	makeTabButton(profKey, profDef, i)
	contentFrames[profKey] = buildContentFrame(profKey, profDef)
end

switchTab("Alchemy")

-- ── open / close ──────────────────────────────────────────────────────────

local function openProfessions()
	screenGui.Enabled = true
	fullRefresh()
end

local function closeProfessions()
	screenGui.Enabled = false
end

closeBtn.MouseButton1Click:Connect(closeProfessions)

UserInputService.InputBegan:Connect(function(input: InputObject, gp: boolean)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.P then
		if screenGui.Enabled then closeProfessions() else openProfessions() end
	end
end)

-- ── data sync ─────────────────────────────────────────────────────────────

-- Parse profession data out of SendInitialData payload
PlayerRemotes.GetEvent("SendInitialData").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	if type(payload.Professions) == "table" then
		for profKey, profData in pairs(payload.Professions) do
			if type(profData) == "table" then
				playerProfessions[profKey] = {
					Level = profData.Level or 1,
					XP    = profData.XP    or 0,
				}
			end
		end
	end
	if type(payload.Inventory) == "table" then
		playerInventory = payload.Inventory
	end
	if screenGui.Enabled then fullRefresh() end
end)

-- Re-sync inventory (and possibly profession XP) whenever the server pushes an update
InventoryRemotes.GetEvent("InventoryUpdated").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end

	if type(payload.inventory) == "table" then
		playerInventory = payload.inventory
	end
	if type(payload.professions) == "table" then
		for profKey, profData in pairs(payload.professions) do
			if type(profData) == "table" then
				playerProfessions[profKey] = {
					Level = profData.Level or 1,
					XP    = profData.XP    or 0,
				}
			end
		end
	end

	if screenGui.Enabled then fullRefresh() end
	setStatus("Инвентарь обновлён.", GREEN)
end)
