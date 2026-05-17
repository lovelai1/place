--!strict
-- Pure validation for GhostyRPG class and role selection.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ClassConfig"))
local RoleConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("RoleConfig"))

local ClassValidator = {}

export type ValidationResult = {
	success: boolean,
	reason: string?,
}

local function ok(): ValidationResult
	return { success = true, reason = nil }
end

local function fail(reason: string): ValidationResult
	return { success = false, reason = reason }
end

function ClassValidator.IsValidClass(className: string): boolean
	return typeof(className) == "string" and ClassConfig[className] ~= nil
end

function ClassValidator.IsValidRole(roleName: string): boolean
	return typeof(roleName) == "string" and RoleConfig[roleName] ~= nil
end

function ClassValidator.CanClassUseRole(className: string, roleName: string): ValidationResult
	if not ClassValidator.IsValidClass(className) then
		return fail(string.format("Class '%s' does not exist.", tostring(className)))
	end
	if not ClassValidator.IsValidRole(roleName) then
		return fail(string.format("Role '%s' does not exist.", tostring(roleName)))
	end

	local classData = ClassConfig[className]
	local availableRoles = classData.AvailableRoles
	if type(availableRoles) ~= "table" then
		return fail(string.format("Class '%s' has no AvailableRoles list.", className))
	end

	for _, allowedRole in ipairs(availableRoles) do
		if allowedRole == roleName then
			return ok()
		end
	end

	return fail(string.format("Class '%s' cannot use role '%s'.", className, roleName))
end

function ClassValidator.CanSelectClass(data: { [string]: any }, className: string): ValidationResult
	if not ClassValidator.IsValidClass(className) then
		return fail(string.format("Class '%s' does not exist.", tostring(className)))
	end

	local selectedClass = data.SelectedClass
	if type(selectedClass) == "string" and selectedClass ~= "" then
		local settings = data.Settings
		local resetAllowed = type(settings) == "table" and settings.ResetClassAllowed == true
		if not resetAllowed then
			return fail("Class is already selected and class reset is not allowed.")
		end
	end

	return ok()
end

function ClassValidator.CanSelectRole(data: { [string]: any }, roleName: string): ValidationResult
	local selectedClass = data.SelectedClass
	if type(selectedClass) ~= "string" or selectedClass == "" then
		return fail("Select a class before choosing a role.")
	end

	return ClassValidator.CanClassUseRole(selectedClass, roleName)
end

return ClassValidator
