--!strict
-- InventoryUI.client.lua
-- Toggle with "I" / "B". Shows inventory grid + equipment panel.
-- Equip / Unequip / Drop via InventoryRemotes.

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SharedRemotes    = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
local InventoryRemotes = require(SharedRemotes:WaitForChild("InventoryRemotes"))
local PlayerRemotes    = require(SharedRemotes:WaitForChild("PlayerRemotes"))
local ItemConfig       = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ItemConfig")
)

-- ── palette ───────────────────────────────────────────────────────────────

local RARITY_COLOR: { [string]: Color3 } = {
	Common    = Color3.fromRGB(200, 200, 200),
	Uncommon  = Color3.fromRGB(30,  200, 60),
	Rare      = Color3.fromRGB(0,   120, 255),
	Epic      = Color3.fromRGB(160, 50,  220),
	Legendary = Color3.fromRGB(255, 165, 0),
	Artifact  = Color3.fromRGB(230, 50,  50),
}
local SLOT_BG       = Color3.fromRGB(22, 25, 34)
local PANEL_BG      = Color3.fromRGB(12, 14, 22)
local HEADER_YELLOW = Color3.fromRGB(255, 200, 60)

local EQUIP_SLOTS: { { id: string, label: string } } = {
	{ id = "Head",      label = "Голова"    },
	{ id = "Shoulders", label = "Плечи"     },
	{ id = "Chest",     label = "Грудь"     },
	{ id = "Legs",      label = "Ноги"      },
	{ id = "Feet",      label = "Стопы"     },
	{ id = "MainHand",  label = "Оружие"    },
	{ id = "OffHand",   label = "Щит"       },
	{ id = "Necklace",  label = "Шея"       },
	{ id = "Ring1",     label = "Кольцо 1"  },
	{ id = "Ring2",     label = "Кольцо 2"  },
}

-- ── build GUI ─────────────────────────────────────────────────────────────

local screenGui              = Instance.new("ScreenGui")
screenGui.Name               = "InventoryUI"
screenGui.ResetOnSpawn       = false
screenGui.IgnoreGuiInset     = false
screenGui.DisplayOrder       = 10
screenGui.Enabled            = false
screenGui.Parent             = playerGui

local root                   = Instance.new("Frame")
root.Name                    = "Root"
root.AnchorPoint             = Vector2.new(0.5, 0.5)
root.Position                = UDim2.new(0.5, 0, 0.5, 0)
root.Size                    = UDim2.fromOffset(620, 440)
root.BackgroundColor3        = PANEL_BG
root.BackgroundTransparency  = 0.08
root.BorderSizePixel         = 0
root.Parent                  = screenGui
Instance.new("UICorner", root).CornerRadius = UDim.new(0, 10)

-- Title bar
local titleBar               = Instance.new("Frame")
titleBar.Name                = "TitleBar"
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
titleLabel.Text              = "◆ ИНВЕНТАРЬ"
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

-- Left: scrolling item grid
local invPanel               = Instance.new("Frame")
invPanel.Name                = "InvPanel"
invPanel.Position            = UDim2.fromOffset(10, 44)
invPanel.Size                = UDim2.new(0, 360, 1, -54)
invPanel.BackgroundTransparency = 1
invPanel.Parent              = root

local scrollFrame            = Instance.new("ScrollingFrame")
scrollFrame.Name             = "Grid"
scrollFrame.Size             = UDim2.new(1, 0, 1, 0)
scrollFrame.CanvasSize       = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel  = 0
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollBarImageColor3 = HEADER_YELLOW
scrollFrame.Parent           = invPanel

local gridLayout             = Instance.new("UIGridLayout")
gridLayout.CellSize          = UDim2.fromOffset(68, 68)
gridLayout.CellPadding       = UDim2.fromOffset(6, 6)
gridLayout.SortOrder         = Enum.SortOrder.Name
gridLayout.Parent            = scrollFrame

-- Right: equipment panel
local eqPanel                = Instance.new("Frame")
eqPanel.Name                 = "Equipment"
eqPanel.Position             = UDim2.new(0, 380, 0, 44)
eqPanel.Size                 = UDim2.new(1, -390, 1, -54)
eqPanel.BackgroundTransparency = 1
eqPanel.Parent               = root

local eqLayout               = Instance.new("UIListLayout")
eqLayout.SortOrder           = Enum.SortOrder.LayoutOrder
eqLayout.Padding             = UDim.new(0, 4)
eqLayout.Parent              = eqPanel

local eqHeader               = Instance.new("TextLabel")
eqHeader.Size                = UDim2.new(1, 0, 0, 18)
eqHeader.BackgroundTransparency = 1
eqHeader.Font                = Enum.Font.GothamBold
eqHeader.TextSize            = 11
eqHeader.TextColor3          = HEADER_YELLOW
eqHeader.TextXAlignment      = Enum.TextXAlignment.Left
eqHeader.Text                = "Экипировка"
eqHeader.LayoutOrder         = 0
eqHeader.Parent              = eqPanel

-- Tooltip (shared hover popup)
local tooltip                = Instance.new("Frame")
tooltip.Name                 = "Tooltip"
tooltip.Size                 = UDim2.fromOffset(180, 80)
tooltip.BackgroundColor3     = Color3.fromRGB(6, 8, 14)
tooltip.BackgroundTransparency = 0.1
tooltip.BorderSizePixel      = 0
tooltip.Visible              = false
tooltip.ZIndex               = 20
tooltip.Parent               = screenGui
Instance.new("UICorner", tooltip).CornerRadius = UDim.new(0, 6)

local tipPad = Instance.new("UIPadding", tooltip)
tipPad.PaddingTop    = UDim.new(0, 6)
tipPad.PaddingBottom = UDim.new(0, 6)
tipPad.PaddingLeft   = UDim.new(0, 8)
tipPad.PaddingRight  = UDim.new(0, 8)
Instance.new("UIListLayout", tooltip).Padding = UDim.new(0, 3)

local tipName = Instance.new("TextLabel", tooltip)
tipName.Size             = UDim2.new(1, 0, 0, 16)
tipName.BackgroundTransparency = 1
tipName.Font             = Enum.Font.GothamBold
tipName.TextSize         = 12
tipName.TextColor3       = Color3.fromRGB(255, 255, 200)
tipName.TextXAlignment   = Enum.TextXAlignment.Left
tipName.LayoutOrder      = 0

local tipDesc = Instance.new("TextLabel", tooltip)
tipDesc.Size             = UDim2.new(1, 0, 0, 28)
tipDesc.BackgroundTransparency = 1
tipDesc.Font             = Enum.Font.Gotham
tipDesc.TextSize         = 10
tipDesc.TextColor3       = Color3.fromRGB(180, 180, 200)
tipDesc.TextXAlignment   = Enum.TextXAlignment.Left
tipDesc.TextWrapped      = true
tipDesc.LayoutOrder      = 1

local tipAction = Instance.new("TextLabel", tooltip)
tipAction.Size             = UDim2.new(1, 0, 0, 13)
tipAction.BackgroundTransparency = 1
tipAction.Font             = Enum.Font.Gotham
tipAction.TextSize         = 10
tipAction.TextColor3       = Color3.fromRGB(100, 200, 255)
tipAction.TextXAlignment   = Enum.TextXAlignment.Left
tipAction.LayoutOrder      = 2

-- ── state ─────────────────────────────────────────────────────────────────

local inventoryData: { [string]: any } = {}
local equipmentData: { [string]: any } = {}
local eqSlotFrames: { [string]: Frame } = {}
local itemSlots: { [string]: Frame } = {}

-- ── tooltip helpers ───────────────────────────────────────────────────────

local function showTooltip(_guiObj: GuiObject, itemId: string, isEquipped: boolean)
	local def = ItemConfig.GetItem(itemId)
	if not def then tooltip.Visible = false return end

	tipName.Text      = def.name
	tipName.TextColor3 = RARITY_COLOR[def.rarity] or Color3.fromRGB(200, 200, 200)
	tipDesc.Text      = def.description or ""
	if isEquipped then
		tipAction.Text = "ЛКМ — снять"
	elseif def.equipSlot then
		tipAction.Text = "ЛКМ — надеть  |  ПКМ — выбросить"
	else
		tipAction.Text = "ПКМ — выбросить"
	end

	tooltip.AutomaticSize = Enum.AutomaticSize.Y
	tooltip.Visible       = true

	local mp = UserInputService:GetMouseLocation()
	local x  = math.min(mp.X + 12, screenGui.AbsoluteSize.X - 200)
	local y  = math.min(mp.Y + 8,  screenGui.AbsoluteSize.Y - 100)
	tooltip.Position = UDim2.fromOffset(x, y)
end

local function hideTooltip()
	tooltip.Visible = false
end

-- ── slot factory ──────────────────────────────────────────────────────────

local function makeSlotFrame(parent: Instance, name: string): Frame
	local slot               = Instance.new("Frame")
	slot.Name                = name
	slot.Size                = UDim2.fromOffset(68, 68)
	slot.BackgroundColor3    = SLOT_BG
	slot.BorderSizePixel     = 0
	slot.Parent              = parent
	Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 6)

	local colorBar           = Instance.new("Frame")
	colorBar.Name            = "ColorBar"
	colorBar.Size            = UDim2.new(1, 0, 0, 3)
	colorBar.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	colorBar.BorderSizePixel = 0
	colorBar.Parent          = slot

	local amtLabel           = Instance.new("TextLabel")
	amtLabel.Name            = "Amount"
	amtLabel.Size            = UDim2.new(1, -4, 0, 14)
	amtLabel.AnchorPoint     = Vector2.new(1, 1)
	amtLabel.Position        = UDim2.new(1, -2, 1, -2)
	amtLabel.BackgroundTransparency = 1
	amtLabel.Font            = Enum.Font.GothamBold
	amtLabel.TextSize        = 10
	amtLabel.TextColor3      = Color3.fromRGB(255, 255, 255)
	amtLabel.TextXAlignment  = Enum.TextXAlignment.Right
	amtLabel.Text            = ""
	amtLabel.Parent          = slot

	local nameLabel          = Instance.new("TextLabel")
	nameLabel.Name           = "ItemName"
	nameLabel.Size           = UDim2.new(1, -4, 0, 28)
	nameLabel.Position       = UDim2.fromOffset(2, 18)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font           = Enum.Font.Gotham
	nameLabel.TextSize       = 9
	nameLabel.TextColor3     = Color3.fromRGB(220, 220, 220)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextWrapped    = true
	nameLabel.Text           = ""
	nameLabel.Parent         = slot

	return slot
end

-- ── inventory grid ────────────────────────────────────────────────────────

local function refreshGrid()
	for itemId, slot in pairs(itemSlots) do
		if not inventoryData[itemId] then
			slot:Destroy()
			itemSlots[itemId] = nil
		end
	end

	for itemId, entry in pairs(inventoryData) do
		local def         = ItemConfig.GetItem(itemId)
		local displayName = (def and def.name) or itemId
		local rarity      = (def and def.rarity) or "Common"
		local amount      = entry.amount or 1

		local slot = itemSlots[itemId]
		if not slot then
			slot = makeSlotFrame(scrollFrame, itemId)
			itemSlots[itemId] = slot

			-- Transparent button overlay for clicks/hover
			local btn = Instance.new("TextButton")
			btn.Size               = UDim2.new(1, 0, 1, 0)
			btn.BackgroundTransparency = 1
			btn.Text               = ""
			btn.ZIndex             = 5
			btn.Parent             = slot

			local capturedId = itemId
			btn.MouseEnter:Connect(function()
				showTooltip(slot, capturedId, false)
			end)
			btn.MouseLeave:Connect(function()
				hideTooltip()
			end)
			btn.MouseButton1Click:Connect(function()
				local d = ItemConfig.GetItem(capturedId)
				if d and d.equipSlot then
					InventoryRemotes.GetEvent("EquipItem"):FireServer({ itemId = capturedId })
				end
			end)
			btn.MouseButton2Click:Connect(function()
				InventoryRemotes.GetEvent("DropItem"):FireServer({ itemId = capturedId, amount = 1 })
			end)
		end

		local bar = slot:FindFirstChild("ColorBar") :: Frame?
		if bar then bar.BackgroundColor3 = RARITY_COLOR[rarity] or RARITY_COLOR.Common end

		local nameLabel = slot:FindFirstChild("ItemName") :: TextLabel?
		if nameLabel then nameLabel.Text = displayName end

		local amtLabel = slot:FindFirstChild("Amount") :: TextLabel?
		if amtLabel then amtLabel.Text = if amount > 1 then tostring(amount) else "" end
	end
end

-- ── equipment panel ───────────────────────────────────────────────────────

local function buildEquipmentPanel()
	for i, slotInfo in ipairs(EQUIP_SLOTS) do
		local row            = Instance.new("Frame")
		row.Name             = slotInfo.id
		row.Size             = UDim2.new(1, 0, 0, 32)
		row.BackgroundColor3 = SLOT_BG
		row.BackgroundTransparency = 0.3
		row.BorderSizePixel  = 0
		row.LayoutOrder      = i
		row.Parent           = eqPanel
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

		local slotLabel      = Instance.new("TextLabel")
		slotLabel.Size       = UDim2.new(0, 72, 1, 0)
		slotLabel.BackgroundTransparency = 1
		slotLabel.Font       = Enum.Font.Gotham
		slotLabel.TextSize   = 10
		slotLabel.TextColor3 = Color3.fromRGB(140, 140, 160)
		slotLabel.TextXAlignment = Enum.TextXAlignment.Left
		slotLabel.Text       = "  " .. slotInfo.label
		slotLabel.Parent     = row

		local itemLabel      = Instance.new("TextLabel")
		itemLabel.Name       = "ItemLabel"
		itemLabel.Size       = UDim2.new(1, -110, 1, 0)
		itemLabel.Position   = UDim2.fromOffset(75, 0)
		itemLabel.BackgroundTransparency = 1
		itemLabel.Font       = Enum.Font.GothamBold
		itemLabel.TextSize   = 10
		itemLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
		itemLabel.TextXAlignment = Enum.TextXAlignment.Left
		itemLabel.Text       = "—"
		itemLabel.Parent     = row

		local unequipBtn     = Instance.new("TextButton")
		unequipBtn.Name      = "UnequipBtn"
		unequipBtn.Size      = UDim2.fromOffset(36, 22)
		unequipBtn.AnchorPoint = Vector2.new(1, 0.5)
		unequipBtn.Position  = UDim2.new(1, -4, 0.5, 0)
		unequipBtn.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
		unequipBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
		unequipBtn.Font      = Enum.Font.Gotham
		unequipBtn.TextSize  = 9
		unequipBtn.Text      = "Снять"
		unequipBtn.BorderSizePixel = 0
		unequipBtn.Visible   = false
		unequipBtn.Parent    = row
		Instance.new("UICorner", unequipBtn).CornerRadius = UDim.new(0, 3)

		local capturedSlot = slotInfo.id
		unequipBtn.MouseButton1Click:Connect(function()
			InventoryRemotes.GetEvent("UnequipSlot"):FireServer({ slot = capturedSlot })
		end)

		eqSlotFrames[slotInfo.id] = row
	end
end

local function refreshEquipment()
	for _, slotInfo in ipairs(EQUIP_SLOTS) do
		local row       = eqSlotFrames[slotInfo.id]
		if not row then continue end
		local itemLabel  = row:FindFirstChild("ItemLabel")  :: TextLabel?
		local unequipBtn = row:FindFirstChild("UnequipBtn") :: TextButton?
		local equipped   = equipmentData[slotInfo.id]

		if equipped and type(equipped.itemId) == "string" then
			local def = ItemConfig.GetItem(equipped.itemId)
			if itemLabel then
				itemLabel.Text      = (def and def.name) or equipped.itemId
				itemLabel.TextColor3 = RARITY_COLOR[(def and def.rarity) or "Common"]
			end
			if unequipBtn then unequipBtn.Visible = true end
		else
			if itemLabel then
				itemLabel.Text      = "—"
				itemLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
			end
			if unequipBtn then unequipBtn.Visible = false end
		end
	end
end

-- ── open / close ──────────────────────────────────────────────────────────

local function openInventory()
	screenGui.Enabled = true
	task.spawn(function()
		local invData = InventoryRemotes.GetFunction("GetInventory"):InvokeServer()
		local eqData  = InventoryRemotes.GetFunction("GetEquipment"):InvokeServer()
		if type(invData) == "table" then inventoryData = invData end
		if type(eqData)  == "table" then equipmentData = eqData  end
		refreshGrid()
		refreshEquipment()
	end)
end

local function closeInventory()
	screenGui.Enabled = false
	hideTooltip()
end

closeBtn.MouseButton1Click:Connect(closeInventory)

UserInputService.InputBegan:Connect(function(input: InputObject, gp: boolean)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.I or input.KeyCode == Enum.KeyCode.B then
		if screenGui.Enabled then closeInventory() else openInventory() end
	end
end)

-- Server-push: refresh when inventory changes (loot, craft, equip, drop)
InventoryRemotes.GetEvent("InventoryUpdated").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then return end
	if type(payload.inventory) == "table" then inventoryData = payload.inventory end
	if type(payload.equipment) == "table" then equipmentData = payload.equipment end
	if screenGui.Enabled then
		refreshGrid()
		refreshEquipment()
	end
end)

-- Pre-load data silently on join so opening the UI is instant
PlayerRemotes.GetEvent("SendInitialData").OnClientEvent:Connect(function(_payload: any)
	task.spawn(function()
		local invData = InventoryRemotes.GetFunction("GetInventory"):InvokeServer()
		local eqData  = InventoryRemotes.GetFunction("GetEquipment"):InvokeServer()
		if type(invData) == "table" then inventoryData = invData end
		if type(eqData)  == "table" then equipmentData = eqData  end
	end)
end)

-- ── init ──────────────────────────────────────────────────────────────────

buildEquipmentPanel()
