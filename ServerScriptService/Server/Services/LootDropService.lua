--!strict
-- LootDropService — spawns a physical loot bag in the world when a mob dies.
-- Players walk up and collect via ProximityPrompt.
-- First player to trigger gets the loot (kill-priority hint kept as metadata).
--
-- Usage:
--   LootDropService.SpawnBag(items, position, killerPlayer?)

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")

local LootDropService = {}

local BAG_LIFETIME_SECONDS = 60   -- bag despawns after this
local MAX_RANGE_STUDS      = 6    -- ProximityPrompt max distance

local inventoryService: any = nil
local initialized           = false

-- ── helpers ───────────────────────────────────────────────────────────────

local function buildBag(position: Vector3, items: { { itemId: string, amount: number } }): Part
	local bag          = Instance.new("Part")
	bag.Name           = "LootBag"
	bag.Size           = Vector3.new(1.2, 1.2, 1.2)
	bag.CFrame         = CFrame.new(position + Vector3.new(0, 0.6, 0))
	bag.Anchored       = true
	bag.CanCollide     = false
	bag.Shape          = Enum.PartType.Ball
	bag.BrickColor     = BrickColor.new("Bright yellow")
	bag.Material       = Enum.Material.Neon
	bag.CastShadow     = false
	bag.Parent         = workspace

	-- Subtle bob tween
	local goal         = bag.CFrame * CFrame.new(0, 0.4, 0)
	local tweenInfo    = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(bag, tweenInfo, { CFrame = goal }):Play()

	-- Label showing item names
	local billboard                    = Instance.new("BillboardGui")
	billboard.Size                     = UDim2.new(0, 160, 0, 36)
	billboard.StudsOffset              = Vector3.new(0, 2.2, 0)
	billboard.AlwaysOnTop              = false
	billboard.Parent                   = bag

	local label                        = Instance.new("TextLabel")
	label.Size                         = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency       = 1
	label.Font                         = Enum.Font.GothamBold
	label.TextSize                     = 13
	label.TextColor3                   = Color3.fromRGB(255, 220, 60)
	label.TextStrokeTransparency       = 0.3
	label.TextWrapped                  = true

	local names: { string } = {}
	for _, item in ipairs(items) do
		table.insert(names, (item.itemId:gsub("item_", ""):gsub("_", " ")))
	end
	label.Text   = table.concat(names, ", ")
	label.Parent = billboard

	-- ProximityPrompt
	local prompt                    = Instance.new("ProximityPrompt")
	prompt.ActionText               = "Подобрать"
	prompt.ObjectText               = "Лут"
	prompt.MaxActivationDistance    = MAX_RANGE_STUDS
	prompt.HoldDuration             = 0
	prompt.RequiresLineOfSight      = false
	prompt.Parent                   = bag

	return bag
end

-- ── public API ────────────────────────────────────────────────────────────

--- Spawn a loot bag at a world position.
--- items  — array of { itemId: string, amount: number }
--- killer — optional priority looter (first fire goes to killer if present)
function LootDropService.SpawnBag(
	items  : { { itemId: string, amount: number } },
	position  : Vector3,
	killer    : Player?
)
	assert(initialized, "[LootDropService] Call Init() before SpawnBag().")
	if not items or #items == 0 then return end

	local bag      = buildBag(position, items)
	local claimed  = false

	local function doLoot(looter: Player)
		if claimed then return end
		if not looter or not looter.Parent then return end
		claimed = true

		-- Grant items
		for _, item in ipairs(items) do
			pcall(function()
				inventoryService.AddItem(looter, item.itemId, item.amount)
			end)
		end

		-- Visual feedback: shrink and destroy
		local tween = TweenService:Create(bag, TweenInfo.new(0.25), {
			Size  = Vector3.new(0.01, 0.01, 0.01),
			CFrame = CFrame.new(bag.Position),
		})
		tween:Play()
		tween.Completed:Connect(function()
			bag:Destroy()
		end)
	end

	-- If killer is nearby and present, give them a short priority window
	if killer and killer.Parent then
		local killerChar = killer.Character
		local killerRoot = killerChar and killerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		if killerRoot and (killerRoot.Position - position).Magnitude <= MAX_RANGE_STUDS * 2 then
			task.delay(0.3, function()
				if not claimed then
					-- killer is still close enough → auto-collect
					local root2 = killer.Character and killer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root2 and (root2.Position - position).Magnitude <= MAX_RANGE_STUDS * 2 then
						doLoot(killer)
						return
					end
				end
			end)
		end
	end

	-- ProximityPrompt: open to everyone
	local prompt = bag:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function(looter: Player)
			doLoot(looter)
		end)
	end

	-- Auto-despawn
	task.delay(BAG_LIFETIME_SECONDS, function()
		if bag.Parent and not claimed then
			bag:Destroy()
		end
	end)
end

function LootDropService.Init(newInventoryService: any)
	if initialized then
		warn("[LootDropService] Init called more than once; ignoring.")
		return
	end
	assert(newInventoryService, "[LootDropService] requires InventoryService")
	inventoryService = newInventoryService
	initialized      = true
	print("[LootDropService] Initialized.")
end

return LootDropService
