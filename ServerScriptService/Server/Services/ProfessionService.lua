--!strict
-- Server-authoritative profession progression, gathering, and crafting.
-- Dependencies are injected through Init; no player state is touched until public methods are called.

local ServerScriptService = game:GetService("ServerScriptService")

local ProfessionConfig = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Config"):WaitForChild("ProfessionConfig"))
local ProfessionValidator = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Validators"):WaitForChild("ProfessionValidator"))

local ProfessionService = {}

local playerDataService: any = nil
local inventoryService: any = nil
local initialized = false

local function ok(payload: any?)
	return { success = true, data = payload }
end

local function fail(reason: string)
	return { success = false, reason = reason }
end

local function assertInitialized()
	assert(initialized and playerDataService and inventoryService, "ProfessionService requires Init(playerDataService, inventoryService) before use.")
end

local function getPlayerData(player: Player): any?
	assertInitialized()
	return playerDataService.GetData(player)
end

local function scheduleSave(player: Player)
	if type(playerDataService.ScheduleSave) == "function" then
		playerDataService.ScheduleSave(player)
	end
end

local function ensureProfessions(data: any): { [string]: any }
	if type(data.Professions) ~= "table" then
		data.Professions = {}
	end
	for professionName in pairs(ProfessionConfig.Professions) do
		if type(data.Professions[professionName]) ~= "table" then
			data.Professions[professionName] = { Level = 1, XP = 0 }
		else
			local professionData = data.Professions[professionName]
			if type(professionData.Level) ~= "number" then
				professionData.Level = professionData.level or 1
			end
			if type(professionData.XP) ~= "number" then
				professionData.XP = professionData.exp or 0
			end
		end
	end
	return data.Professions
end

local function experienceForLevel(professionConfig: any, currentLevel: number): number
	local formula = professionConfig.ExperiencePerLevel
	if type(formula) == "function" then
		return math.max(1, math.floor(formula(currentLevel)))
	end
	if type(formula) == "number" then
		return math.max(1, math.floor(currentLevel * formula))
	end
	return math.max(1, currentLevel * 100)
end

local function applyLevelUps(professionConfig: any, professionData: any): number
	local maxLevel = professionConfig.MaxLevel or math.huge
	local gained = 0
	while professionData.Level < maxLevel do
		local threshold = experienceForLevel(professionConfig, professionData.Level)
		if professionData.XP < threshold then
			break
		end
		professionData.XP -= threshold
		professionData.Level += 1
		gained += 1
	end
	if professionData.Level >= maxLevel then
		professionData.XP = 0
	end
	return gained
end

function ProfessionService.Init(newPlayerDataService: any, newInventoryService: any)
	if initialized then
		warn("[ProfessionService] Init called more than once; ignoring duplicate call.")
		return
	end
	assert(newPlayerDataService, "ProfessionService.Init requires PlayerDataService.")
	assert(type(newPlayerDataService.GetData) == "function", "ProfessionService.Init requires PlayerDataService.GetData.")
	assert(type(newPlayerDataService.ScheduleSave) == "function", "ProfessionService.Init requires PlayerDataService.ScheduleSave.")
	assert(newInventoryService, "ProfessionService.Init requires InventoryService.")
	assert(type(newInventoryService.AddItem) == "function", "ProfessionService.Init requires InventoryService.AddItem.")
	assert(type(newInventoryService.RemoveItem) == "function", "ProfessionService.Init requires InventoryService.RemoveItem.")
	assert(type(newInventoryService.HasItem) == "function", "ProfessionService.Init requires InventoryService.HasItem.")

	playerDataService = newPlayerDataService
	inventoryService = newInventoryService
	initialized = true
	print("[ProfessionService] Initialized.")
end

function ProfessionService.AddExperience(player: Player, professionName: string, amount: number)
	local data = getPlayerData(player)
	if not data then
		return fail("Player data unavailable.")
	end
	ensureProfessions(data)

	local validation = ProfessionValidator.CanGainExperience(data, professionName, amount)
	if not validation.success then
		return fail(validation.reason or "Cannot gain profession experience.")
	end

	local professionData = data.Professions[professionName]
	local professionConfig = ProfessionConfig.Professions[professionName]
	professionData.XP += amount
	local levelsGained = applyLevelUps(professionConfig, professionData)
	scheduleSave(player)
	return ok({ levelsGained = levelsGained, newLevel = professionData.Level, newXP = professionData.XP })
end

function ProfessionService.GetProfessionData(player: Player, professionName: string)
	local valid = ProfessionValidator.IsValidProfession(professionName)
	if not valid.success then
		return fail(valid.reason or "Invalid profession.")
	end
	local data = getPlayerData(player)
	if not data then
		return fail("Player data unavailable.")
	end
	ensureProfessions(data)
	local professionData = data.Professions[professionName]
	local professionConfig = ProfessionConfig.Professions[professionName]
	return ok({
		Level = professionData.Level,
		XP = professionData.XP,
		NextLevelXP = if professionData.Level < (professionConfig.MaxLevel or math.huge) then experienceForLevel(professionConfig, professionData.Level) else 0,
		MaxLevel = professionConfig.MaxLevel,
	})
end

function ProfessionService.Gather(player: Player, professionName: string, materialId: string, amount: number?)
	local data = getPlayerData(player)
	if not data then
		return fail("Player data unavailable.")
	end
	ensureProfessions(data)

	local validation = ProfessionValidator.CanGather(data, professionName, materialId)
	if not validation.success then
		return fail(validation.reason or "Cannot gather material.")
	end
	local gatherAmount = if type(amount) == "number" and amount > 0 then math.floor(amount) else 1
	local material = ProfessionConfig.Professions[professionName].Materials[materialId]
	local itemAmount = (material.Amount or 1) * gatherAmount
	if inventoryService.AddItem(player, material.ItemId, itemAmount) == false then
		return fail(string.format("InventoryService failed to add item '%s'.", material.ItemId))
	end
	local xpReward = (material.XPReward or 0) * gatherAmount
	if xpReward > 0 then
		ProfessionService.AddExperience(player, professionName, xpReward)
	else
		scheduleSave(player)
	end
	return ok({ itemId = material.ItemId, itemAmount = itemAmount, xpAwarded = xpReward })
end

function ProfessionService.Craft(player: Player, professionName: string, recipeName: string)
	local data = getPlayerData(player)
	if not data then
		return fail("Player data unavailable.")
	end
	ensureProfessions(data)

	local validation = ProfessionValidator.CanCraft(data, professionName, recipeName)
	if not validation.success then
		return fail(validation.reason or "Cannot craft recipe.")
	end
	local recipe = ProfessionConfig.Professions[professionName].Recipes[recipeName]

	for _, ingredient in ipairs(recipe.Ingredients or {}) do
		if not inventoryService.HasItem(player, ingredient.ItemId, ingredient.Amount) then
			return fail(string.format("Missing ingredient: %d x %s.", ingredient.Amount, ingredient.ItemId))
		end
	end

	local consumed = {}
	for _, ingredient in ipairs(recipe.Ingredients or {}) do
		if inventoryService.RemoveItem(player, ingredient.ItemId, ingredient.Amount) == false then
			for _, restored in ipairs(consumed) do
				inventoryService.AddItem(player, restored.ItemId, restored.Amount)
			end
			return fail(string.format("Failed to consume ingredient '%s'.", ingredient.ItemId))
		end
		table.insert(consumed, { ItemId = ingredient.ItemId, Amount = ingredient.Amount })
	end

	local output = recipe.Output
	local outputAmount = output.Amount or 1
	if inventoryService.AddItem(player, output.ItemId, outputAmount) == false then
		for _, restored in ipairs(consumed) do
			inventoryService.AddItem(player, restored.ItemId, restored.Amount)
		end
		return fail(string.format("InventoryService failed to add output item '%s'.", output.ItemId))
	end

	local xpReward = recipe.XPReward or 0
	if xpReward > 0 then
		ProfessionService.AddExperience(player, professionName, xpReward)
	else
		scheduleSave(player)
	end
	return ok({ recipeName = recipeName, outputItemId = output.ItemId, outputAmount = outputAmount, xpAwarded = xpReward })
end

return ProfessionService
