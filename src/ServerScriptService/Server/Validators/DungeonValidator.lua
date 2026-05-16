--!strict
-- Pure validation for GhostyRPG dungeon entry conditions.
-- No mutation, no service access, and no yielding outside the initial config require.

local ServerScriptService = game:GetService("ServerScriptService")

local DungeonConfig = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Config"):WaitForChild("DungeonConfig"))

local DungeonValidator = {}

export type ValidationResult = {
	success: boolean,
	reason: string?,
	objectives: { string }?,
}

local function ok(objectives: { string }?): ValidationResult
	return { success = true, objectives = objectives }
end

local function fail(reason: string): ValidationResult
	return { success = false, reason = reason }
end

local function getDungeon(dungeonId: any): any?
	return if type(DungeonConfig.GetDungeon) == "function" then DungeonConfig.GetDungeon(dungeonId) else nil
end

local function hasDifficulty(dungeon: any, difficulty: string): boolean
	if type(dungeon) ~= "table" or type(dungeon.difficulties) ~= "table" then
		return false
	end
	for _, availableDifficulty in ipairs(dungeon.difficulties) do
		if availableDifficulty == difficulty then
			return true
		end
	end
	return false
end

local function getObjectiveIds(dungeon: any): { string }
	local objectiveIds = {}
	if type(dungeon) ~= "table" or type(dungeon.Objectives) ~= "table" then
		return objectiveIds
	end
	for _, objective in ipairs(dungeon.Objectives) do
		if type(objective) == "string" then
			table.insert(objectiveIds, objective)
		elseif type(objective) == "table" and type(objective.id) == "string" then
			table.insert(objectiveIds, objective.id)
		elseif type(objective) == "table" and type(objective.Id) == "string" then
			table.insert(objectiveIds, objective.Id)
		end
	end
	return objectiveIds
end

local function validateRoleCounts(playerDataList: any, requiredRoles: { [string]: number }): ValidationResult
	if type(playerDataList) ~= "table" then
		return fail("playerDataList must be a table.")
	end

	local allowedRoles: { [string]: boolean } = {}
	for role in pairs(DungeonConfig.DefaultRoleComposition or DungeonConfig.RequiredRoleComposition or {}) do
		allowedRoles[role] = true
	end
	for role in pairs(requiredRoles) do
		allowedRoles[role] = true
	end

	local roleCounts: { [string]: number } = {}
	for index, snapshot in ipairs(playerDataList) do
		if type(snapshot) ~= "table" then
			return fail(string.format("Player snapshot #%d must be a table.", index))
		end
		local role = snapshot.SelectedRole or snapshot.Role
		if type(role) ~= "string" or role == "" then
			local id = if snapshot.UserId ~= nil then tostring(snapshot.UserId) else "#" .. tostring(index)
			return fail(string.format("Player %s has no valid SelectedRole.", id))
		end
		if not allowedRoles[role] then
			return fail(string.format("Role composition invalid: Unexpected role '%s'", role))
		end
		roleCounts[role] = (roleCounts[role] or 0) + 1
	end

	local errors = {}
	for role, requiredCount in pairs(requiredRoles) do
		local minimum = math.max(0, requiredCount)
		local actual = roleCounts[role] or 0
		if actual < minimum then
			table.insert(errors, string.format("%s: need at least %d, have %d", role, minimum, actual))
		end
	end
	if #errors > 0 then
		return fail("Role composition invalid: " .. table.concat(errors, "; "))
	end
	return ok()
end
local function validateLevelsOnly(playerDataList: any, dungeonId: string, difficulty: string): ValidationResult
	if type(playerDataList) ~= "table" then
		return fail("playerDataList must be a table.")
	end
	local effectiveMinLevel = DungeonConfig.GetEffectiveMinLevel(dungeonId, difficulty)
	local underLevel = {}
	for index, snapshot in ipairs(playerDataList) do
		if type(snapshot) ~= "table" then
			return fail(string.format("Player snapshot #%d must be a table.", index))
		end
		local level = snapshot.Level
		if type(level) ~= "number" then
			local id = if snapshot.UserId ~= nil then tostring(snapshot.UserId) else "#" .. tostring(index)
			return fail(string.format("Player %s has no numeric Level field.", id))
		end
		if level < effectiveMinLevel then
			local id = if snapshot.UserId ~= nil then tostring(snapshot.UserId) else "#" .. tostring(index)
			table.insert(underLevel, string.format("Player %s (Lv %d, need %d)", id, level, effectiveMinLevel))
		end
	end
	if #underLevel > 0 then
		return fail(string.format("Level requirement not met for %s %s: %s", dungeonId, difficulty, table.concat(underLevel, "; ")))
	end
	return ok()
end

function DungeonValidator.Init(config: any)
	assert(type(config) == "table", "DungeonValidator.Init expects a table.")
	DungeonConfig = config
end

function DungeonValidator.IsValidDungeon(dungeonId: any): ValidationResult
	if type(dungeonId) ~= "string" or dungeonId == "" then
		return fail("dungeonId must be a non-empty string.")
	end
	if not getDungeon(dungeonId) then
		return fail(string.format("Unknown dungeon '%s'.", dungeonId))
	end
	return ok()
end

function DungeonValidator.IsValidDifficulty(difficulty: any): ValidationResult
	if type(difficulty) ~= "string" or difficulty == "" then
		return fail("difficulty must be a non-empty string.")
	end
	if type(DungeonConfig.ValidDifficultySet) == "table" then
		if not DungeonConfig.ValidDifficultySet[difficulty] then
			return fail(string.format("Unknown difficulty '%s'.", difficulty))
		end
		return ok()
	end
	if type(DungeonConfig.DifficultyMultipliers) == "table" and DungeonConfig.DifficultyMultipliers[difficulty] then
		return ok()
	end
	return fail(string.format("Unknown difficulty '%s'.", difficulty))
end

function DungeonValidator.ValidateRoleComposition(playerDataList: any): ValidationResult
	return validateRoleCounts(playerDataList, DungeonConfig.DefaultRoleComposition or DungeonConfig.RequiredRoleComposition or {})
end

function DungeonValidator.ValidateLevelRequirements(playerDataList: any, dungeonId: any, difficulty: any): ValidationResult
	local dungeonCheck = DungeonValidator.IsValidDungeon(dungeonId)
	if not dungeonCheck.success then
		return dungeonCheck
	end
	local difficultyCheck = DungeonValidator.IsValidDifficulty(difficulty)
	if not difficultyCheck.success then
		return difficultyCheck
	end
	local dungeon = getDungeon(dungeonId)
	if not hasDifficulty(dungeon, difficulty) then
		return fail(string.format("Difficulty '%s' is not available for dungeon '%s'.", difficulty, dungeonId))
	end
	return validateLevelsOnly(playerDataList, dungeonId, difficulty)
end

function DungeonValidator.CanEnterDungeon(playerDataList: any, dungeonId: any, difficulty: any): ValidationResult
	local dungeonCheck = DungeonValidator.IsValidDungeon(dungeonId)
	if not dungeonCheck.success then
		return dungeonCheck
	end
	local difficultyCheck = DungeonValidator.IsValidDifficulty(difficulty)
	if not difficultyCheck.success then
		return difficultyCheck
	end
	local dungeon = getDungeon(dungeonId)
	if not hasDifficulty(dungeon, difficulty) then
		return fail(string.format("Difficulty '%s' is not offered by '%s'.", difficulty, dungeonId))
	end
	if type(playerDataList) ~= "table" then
		return fail("playerDataList must be a table.")
	end
	local requiredSize = dungeon.maxPlayers or DungeonConfig.Defaults.MaxPlayers
	if #playerDataList ~= requiredSize then
		return fail(string.format("Party size mismatch: need exactly %d players, have %d.", requiredSize, #playerDataList))
	end
	local roleCheck = validateRoleCounts(playerDataList, DungeonConfig.GetRequiredRoles(dungeonId))
	if not roleCheck.success then
		return roleCheck
	end
	return validateLevelsOnly(playerDataList, dungeonId, difficulty)
end

-- Compatibility API used by DungeonService, which validates live Player members rather than PlayerData snapshots.
function DungeonValidator.ValidateRun(request: any): ValidationResult
	if type(request) ~= "table" then
		return fail("request must be a table.")
	end
	local dungeonCheck = DungeonValidator.IsValidDungeon(request.dungeonId)
	if not dungeonCheck.success then
		return dungeonCheck
	end
	local difficultyCheck = DungeonValidator.IsValidDifficulty(request.difficulty)
	if not difficultyCheck.success then
		return difficultyCheck
	end
	local dungeon = getDungeon(request.dungeonId)
	if not hasDifficulty(dungeon, request.difficulty) then
		return fail(string.format("Difficulty '%s' is not available for dungeon '%s'.", tostring(request.difficulty), tostring(request.dungeonId)))
	end
	if type(request.members) ~= "table" or #request.members == 0 then
		return fail("members must contain at least one Player.")
	end
	local maxPlayers = dungeon.maxPlayers or DungeonConfig.Defaults.MaxPlayers
	if #request.members > maxPlayers then
		return fail(string.format("Dungeon party is too large (%d/%d).", #request.members, maxPlayers))
	end
	local leaderFound = false
	local seen = {}
	for _, member in ipairs(request.members) do
		if typeof(member) ~= "Instance" or not member:IsA("Player") then
			return fail("members must contain only Player instances.")
		end
		if seen[member] then
			return fail("members must not contain duplicate players.")
		end
		seen[member] = true
		if member == request.leader then
			leaderFound = true
		end
	end
	if not leaderFound then
		return fail("leader must be included in members.")
	end
	return ok(getObjectiveIds(dungeon))
end

function DungeonValidator.GetRewards(dungeonId: string, difficulty: string): { any }
	local dungeon = getDungeon(dungeonId)
	if type(dungeon) ~= "table" or type(dungeon.Rewards) ~= "table" then
		return {}
	end
	local rewards = dungeon.Rewards[difficulty]
	if type(rewards) == "table" then
		return rewards
	end
	return {}
end

return DungeonValidator
