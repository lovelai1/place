--!strict
-- Pure server-side validation for ability usage.
-- Does not execute combat and never mutates player data or cooldown state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedConfig = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local AbilityConfig = require(SharedConfig:WaitForChild("AbilityConfig"))
local ClassConfig = require(SharedConfig:WaitForChild("ClassConfig"))
local RoleConfig = require(SharedConfig:WaitForChild("RoleConfig"))

local AbilityValidator = {}

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

local function hasConfigEntry(config: any, getterName: string, key: string): boolean
	local getter = config[getterName]
	if type(getter) == "function" then
		return getter(key) ~= nil
	end
	return config[key] ~= nil
end

local function getResource(data: { [string]: any }): number
	local stats = data.Stats
	if type(stats) == "table" and type(stats.Resource) == "number" then
		return stats.Resource
	end
	if type(data.Resource) == "number" then
		return data.Resource
	end
	return 0
end

local function getResourceType(data: { [string]: any }): string?
	local stats = data.Stats
	if type(stats) == "table" and type(stats.ResourceType) == "string" and stats.ResourceType ~= "" then
		return stats.ResourceType
	end
	if type(data.ResourceType) == "string" and data.ResourceType ~= "" then
		return data.ResourceType
	end
	return nil
end

function AbilityValidator.HasRequiredLevel(data: { [string]: any }, abilityId: string): ValidationResult
	local ability = AbilityConfig.GetAbility(abilityId)
	if not ability then
		return fail(string.format("Unknown ability '%s'.", abilityId))
	end

	local level = if type(data.Level) == "number" then data.Level else 1
	if level < ability.requiredLevel then
		return fail(string.format("'%s' requires level %d (you are level %d).", ability.name, ability.requiredLevel, level))
	end
	return ok()
end

function AbilityValidator.HasRequiredClassAndRole(data: { [string]: any }, abilityId: string): ValidationResult
	local ability = AbilityConfig.GetAbility(abilityId)
	if not ability then
		return fail(string.format("Unknown ability '%s'.", abilityId))
	end

	if ability.className ~= nil then
		local selectedClass = data.SelectedClass
		if type(selectedClass) ~= "string" or selectedClass == "" then
			return fail("No class selected.")
		end
		if not hasConfigEntry(ClassConfig, "GetClass", selectedClass) then
			return fail(string.format("Class '%s' is not a recognised class.", selectedClass))
		end
		if not AbilityConfig.CanClassUseAbility(selectedClass, abilityId) then
			return fail(string.format("Class '%s' cannot use '%s' (requires class '%s').", selectedClass, ability.name, ability.className))
		end
	end

	if type(ability.allowedRoles) == "table" and #ability.allowedRoles > 0 then
		local selectedRole = data.SelectedRole
		if type(selectedRole) ~= "string" or selectedRole == "" then
			return fail(string.format("No role selected. '%s' requires one of: %s.", ability.name, table.concat(ability.allowedRoles, ", ")))
		end
		if not hasConfigEntry(RoleConfig, "GetRole", selectedRole) then
			return fail(string.format("Role '%s' is not a recognised role.", selectedRole))
		end
		if not AbilityConfig.CanRoleUseAbility(selectedRole, abilityId) then
			return fail(string.format("Role '%s' cannot use '%s' (allowed roles: %s).", selectedRole, ability.name, table.concat(ability.allowedRoles, ", ")))
		end
	end

	return ok()
end

function AbilityValidator.HasEnoughResource(data: { [string]: any }, abilityId: string): ValidationResult
	local ability = AbilityConfig.GetAbility(abilityId)
	if not ability then
		return fail(string.format("Unknown ability '%s'.", abilityId))
	end

	if type(ability.resourceCost) ~= "number" or ability.resourceCost <= 0 then
		return ok()
	end

	if ability.resourceType ~= nil then
		local playerResourceType = getResourceType(data)
		if playerResourceType ~= nil and playerResourceType ~= ability.resourceType then
			return fail(string.format("Ability '%s' requires %s, but your resource type is %s.", ability.name, ability.resourceType, playerResourceType))
		end
	end

	local currentResource = getResource(data)
	if currentResource < ability.resourceCost then
		return fail(string.format("Not enough %s to use '%s': need %d, have %d.", ability.resourceType or "resource", ability.name, ability.resourceCost, currentResource))
	end
	return ok()
end

function AbilityValidator.IsOffCooldown(abilityId: string, now: number, cooldownState: { [string]: number }?): ValidationResult
	local ability = AbilityConfig.GetAbility(abilityId)
	if not ability then
		return fail(string.format("Unknown ability '%s'.", abilityId))
	end

	local state = cooldownState or {}
	if ability.cooldown > 0 then
		local lastUsed = state[abilityId]
		if type(lastUsed) == "number" then
			local remaining = ability.cooldown - (now - lastUsed)
			if remaining > 0 then
				return fail(string.format("'%s' is on cooldown (%.1fs remaining).", ability.name, remaining))
			end
		end
	end

	if ability.globalCooldown > 0 then
		local lastGCD = state._gcd
		if type(lastGCD) == "number" then
			local remaining = ability.globalCooldown - (now - lastGCD)
			if remaining > 0 then
				return fail(string.format("Global cooldown active (%.2fs remaining).", remaining))
			end
		end
	end

	return ok()
end

function AbilityValidator.CanUseAbility(data: { [string]: any }, abilityId: string, now: number, cooldownState: { [string]: number }?): ValidationResult
	if not AbilityConfig.IsValidAbility(abilityId) then
		return fail(string.format("Unknown ability '%s'.", abilityId))
	end

	local levelResult = AbilityValidator.HasRequiredLevel(data, abilityId)
	if not levelResult.success then return levelResult end

	local classRoleResult = AbilityValidator.HasRequiredClassAndRole(data, abilityId)
	if not classRoleResult.success then return classRoleResult end

	local resourceResult = AbilityValidator.HasEnoughResource(data, abilityId)
	if not resourceResult.success then return resourceResult end

	return AbilityValidator.IsOffCooldown(abilityId, now, cooldownState)
end

return AbilityValidator
