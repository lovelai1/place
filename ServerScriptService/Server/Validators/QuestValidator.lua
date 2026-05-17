--!strict
-- Pure quest validation functions. This module does not mutate player state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuestsConfig = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("QuestsConfig")
)

local QuestValidator = {}

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

local function countMap(values: { [string]: any }): number
	local count = 0
	for _ in pairs(values) do
		count += 1
	end
	return count
end

function QuestValidator.CanAccept(
	questId: string,
	playerLevel: number,
	activeQuests: { [string]: any },
	completedQuests: { [string]: number },
	maxActive: number,
	now: number,
	repeatCooldown: number
): ValidationResult
	local def = QuestsConfig.Quests[questId]
	if not def then
		return fail("Quest does not exist.")
	end

	if activeQuests[questId] then
		return fail("Quest is already active.")
	end

	local completedAt = completedQuests[questId]
	if completedAt then
		if not def.repeatable then
			return fail("Quest has already been completed.")
		end

		local elapsed = now - completedAt
		if elapsed < repeatCooldown then
			local remaining = repeatCooldown - elapsed
			local hours = math.floor(remaining / 3600)
			local minutes = math.floor((remaining % 3600) / 60)
			return fail(string.format("Repeatable quest is available in %dh %dm.", hours, minutes))
		end
	end

	if playerLevel < def.levelRequirement then
		return fail(string.format("Requires level %d.", def.levelRequirement))
	end

	for _, prereqId in ipairs(def.prerequisiteQuests) do
		if not completedQuests[prereqId] then
			local prereqDef = QuestsConfig.Quests[prereqId]
			local prereqName = if prereqDef then prereqDef.name else prereqId
			return fail(string.format("Complete '%s' first.", prereqName))
		end
	end

	if countMap(activeQuests) >= maxActive then
		return fail(string.format("Active quest limit reached (%d).", maxActive))
	end

	return ok()
end

function QuestValidator.CanTurnIn(questId: string, activeQuests: { [string]: any }): ValidationResult
	local def = QuestsConfig.Quests[questId]
	if not def then
		return fail("Quest does not exist.")
	end

	local active = activeQuests[questId]
	if not active then
		return fail("Quest is not active.")
	end

	for _, objDef in ipairs(def.objectives) do
		local progress = active.objectives[objDef.id]
		if not progress then
			return fail(string.format("Missing progress for objective '%s'.", objDef.description))
		end
		if progress.current < objDef.required then
			return fail(string.format("Objective incomplete: %s (%d/%d).", objDef.description, progress.current, objDef.required))
		end
	end

	return ok()
end

function QuestValidator.CanAbandon(questId: string, activeQuests: { [string]: any }): ValidationResult
	if not QuestsConfig.Quests[questId] then
		return fail("Quest does not exist.")
	end
	if not activeQuests[questId] then
		return fail("Quest is not active.")
	end
	return ok()
end

return QuestValidator
