--!strict
-- Pure validation for GhostyRPG professions. No service access and no mutation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfessionConfig = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Config"):WaitForChild("ProfessionConfig"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ItemConfig"))

local ProfessionValidator = {}

export type ValidationResult = {
	success: boolean,
	reason: string?,
}

local function ok(): ValidationResult
	return { success = true }
end

local function fail(reason: string): ValidationResult
	return { success = false, reason = reason }
end

local function getProfessionConfig(professionName: string): any?
	local professions = ProfessionConfig.Professions
	return if type(professions) == "table" then professions[professionName] else nil
end

local function getProfessionData(data: any, professionName: string): any?
	if type(data) ~= "table" or type(data.Professions) ~= "table" then
		return nil
	end
	return data.Professions[professionName]
end

local function getProfessionLevel(professionData: any): number
	if type(professionData) ~= "table" then
		return 0
	end
	if type(professionData.Level) == "number" then
		return professionData.Level
	end
	if type(professionData.level) == "number" then
		return professionData.level
	end
	return 0
end

local function isKnownItem(itemId: any): boolean
	return type(itemId) == "string" and type(ItemConfig.IsValidItem) == "function" and ItemConfig.IsValidItem(itemId)
end

function ProfessionValidator.IsValidProfession(professionName: string): ValidationResult
	if type(professionName) ~= "string" or professionName == "" then
		return fail("professionName must be a non-empty string.")
	end
	if not getProfessionConfig(professionName) then
		return fail(string.format("Unknown profession '%s'.", professionName))
	end
	return ok()
end

function ProfessionValidator.CanGainExperience(data: any, professionName: string, amount: number): ValidationResult
	local valid = ProfessionValidator.IsValidProfession(professionName)
	if not valid.success then
		return valid
	end
	if type(amount) ~= "number" or amount <= 0 then
		return fail("amount must be a positive number.")
	end

	local professionData = getProfessionData(data, professionName)
	if not professionData then
		return fail(string.format("Player has no data for profession '%s'.", professionName))
	end

	local professionConfig = getProfessionConfig(professionName)
	local maxLevel = professionConfig.MaxLevel or math.huge
	if getProfessionLevel(professionData) >= maxLevel then
		return fail(string.format("Profession '%s' is already at max level.", professionName))
	end
	return ok()
end

function ProfessionValidator.CanGather(data: any, professionName: string, materialId: string): ValidationResult
	local valid = ProfessionValidator.IsValidProfession(professionName)
	if not valid.success then
		return valid
	end
	if type(materialId) ~= "string" or materialId == "" then
		return fail("materialId must be a non-empty string.")
	end

	local professionConfig = getProfessionConfig(professionName)
	local materials = professionConfig.Materials
	local materialDef = if type(materials) == "table" then materials[materialId] else nil
	if not materialDef then
		return fail(string.format("Material '%s' is not available in profession '%s'.", materialId, professionName))
	end
	if not isKnownItem(materialDef.ItemId) then
		return fail(string.format("Item '%s' referenced by material '%s' does not exist in ItemConfig.", tostring(materialDef.ItemId), materialId))
	end

	local professionData = getProfessionData(data, professionName)
	if not professionData then
		return fail(string.format("Player has no data for profession '%s'.", professionName))
	end
	local requiredLevel = materialDef.Level or materialDef.MinLevel or 1
	local level = getProfessionLevel(professionData)
	if level < requiredLevel then
		return fail(string.format("Requires %s level %d (player is level %d).", professionName, requiredLevel, level))
	end
	return ok()
end

function ProfessionValidator.CanCraft(data: any, professionName: string, recipeName: string): ValidationResult
	local valid = ProfessionValidator.IsValidProfession(professionName)
	if not valid.success then
		return valid
	end
	if type(recipeName) ~= "string" or recipeName == "" then
		return fail("recipeName must be a non-empty string.")
	end

	local professionConfig = getProfessionConfig(professionName)
	local recipes = professionConfig.Recipes
	local recipeDef = if type(recipes) == "table" then recipes[recipeName] else nil
	if not recipeDef then
		return fail(string.format("Recipe '%s' is not available in profession '%s'.", recipeName, professionName))
	end
	if type(recipeDef.Output) ~= "table" or not isKnownItem(recipeDef.Output.ItemId) then
		return fail(string.format("Output item '%s' for recipe '%s' does not exist in ItemConfig.", tostring(recipeDef.Output and recipeDef.Output.ItemId), recipeName))
	end
	for _, ingredient in ipairs(recipeDef.Ingredients or {}) do
		if not isKnownItem(ingredient.ItemId) then
			return fail(string.format("Ingredient item '%s' for recipe '%s' does not exist in ItemConfig.", tostring(ingredient.ItemId), recipeName))
		end
	end

	local professionData = getProfessionData(data, professionName)
	if not professionData then
		return fail(string.format("Player has no data for profession '%s'.", professionName))
	end
	local requiredLevel = recipeDef.Level or recipeDef.RequiredLevel or 1
	local level = getProfessionLevel(professionData)
	if level < requiredLevel then
		return fail(string.format("Recipe '%s' requires %s level %d (player is level %d).", recipeName, professionName, requiredLevel, level))
	end
	return ok()
end

return ProfessionValidator
