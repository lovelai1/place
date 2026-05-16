--!strict
-- Server-only smoke test for DungeonConfig and DungeonValidator.
-- Uses plain PlayerData snapshots and never creates live dungeon runs.

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local DungeonConfig = require(Server:WaitForChild("Config"):WaitForChild("DungeonConfig") :: ModuleScript)
local DungeonValidator = require(Server:WaitForChild("Validators"):WaitForChild("DungeonValidator") :: ModuleScript)

DungeonValidator.Init(DungeonConfig)

local passed = 0
local failed = 0
local LOG_PASSES = false -- keep Output readable; failures and summary always print.

local function record(label: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		if LOG_PASSES then
			print("[DungeonValidatorSmokeTest] [PASS] " .. label)
		end
	else
		failed += 1
		warn(string.format("[DungeonValidatorSmokeTest] [FAIL] %s%s", label, if detail then ": " .. detail else ""))
	end
end

local function ok(label: string, result: any)
	record(label, type(result) == "table" and result.success == true, if type(result) == "table" then result.reason else tostring(result))
end

local function failResult(label: string, result: any, expected: string?)
	local passedFailure = type(result) == "table" and result.success == false
	if expected and passedFailure then
		passedFailure = type(result.reason) == "string" and string.find(string.lower(result.reason), string.lower(expected), 1, true) ~= nil
	end
	record(label, passedFailure, if type(result) == "table" then tostring(result.reason) else tostring(result))
end

local function makeParty(level: number?): { any }
	local partyLevel = level or 10
	return {
		{ UserId = 101, Level = partyLevel, SelectedRole = "Tank" },
		{ UserId = 102, Level = partyLevel, SelectedRole = "Healer" },
		{ UserId = 103, Level = partyLevel, SelectedRole = "DPS" },
		{ UserId = 104, Level = partyLevel, SelectedRole = "DPS" },
		{ UserId = 105, Level = partyLevel, SelectedRole = "DPS" },
	}
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[key] = deepCopy(child)
	end
	return copy
end

local function deepEqual(left: any, right: any): boolean
	if type(left) ~= type(right) then
		return false
	end
	if type(left) ~= "table" then
		return left == right
	end
	for key, value in pairs(left) do
		if not deepEqual(value, right[key]) then
			return false
		end
	end
	for key in pairs(right) do
		if left[key] == nil then
			return false
		end
	end
	return true
end

record("DungeonConfig.Dungeons exists", type(DungeonConfig.Dungeons) == "table")
record("DungeonConfig dungeon_sealed_crypt defined", type(DungeonConfig.Dungeons.dungeon_sealed_crypt) == "table")
record("DungeonConfig dungeon_mistwood_depths defined", type(DungeonConfig.Dungeons.dungeon_mistwood_depths) == "table")
for _, methodName in ipairs({ "IsValidDungeon", "IsValidDifficulty", "ValidateRoleComposition", "ValidateLevelRequirements", "CanEnterDungeon", "ValidateRun", "GetRewards" }) do
	record("DungeonValidator." .. methodName, type(DungeonValidator[methodName]) == "function")
end

ok("IsValidDungeon sealed crypt", DungeonValidator.IsValidDungeon("dungeon_sealed_crypt"))
ok("IsValidDungeon mistwood depths", DungeonValidator.IsValidDungeon("dungeon_mistwood_depths"))
failResult("IsValidDungeon unknown", DungeonValidator.IsValidDungeon("dungeon_missing"), "unknown")
failResult("IsValidDungeon empty", DungeonValidator.IsValidDungeon(""), "non-empty")

ok("IsValidDifficulty Normal", DungeonValidator.IsValidDifficulty("Normal"))
ok("IsValidDifficulty Hard", DungeonValidator.IsValidDifficulty("Hard"))
ok("IsValidDifficulty Nightmare", DungeonValidator.IsValidDifficulty("Nightmare"))
failResult("IsValidDifficulty lowercase normal", DungeonValidator.IsValidDifficulty("normal"), "unknown")
failResult("IsValidDifficulty Easy", DungeonValidator.IsValidDifficulty("Easy"), "unknown")

ok("ValidateRoleComposition valid", DungeonValidator.ValidateRoleComposition(makeParty()))
failResult("ValidateRoleComposition no healer", DungeonValidator.ValidateRoleComposition({
	{ UserId = 1, Level = 10, SelectedRole = "Tank" },
	{ UserId = 2, Level = 10, SelectedRole = "DPS" },
	{ UserId = 3, Level = 10, SelectedRole = "DPS" },
	{ UserId = 4, Level = 10, SelectedRole = "DPS" },
	{ UserId = 5, Level = 10, SelectedRole = "DPS" },
}), "healer")
failResult("ValidateRoleComposition unexpected role", DungeonValidator.ValidateRoleComposition({
	{ UserId = 1, Level = 10, SelectedRole = "Tank" },
	{ UserId = 2, Level = 10, SelectedRole = "Healer" },
	{ UserId = 3, Level = 10, SelectedRole = "DPS" },
	{ UserId = 4, Level = 10, SelectedRole = "DPS" },
	{ UserId = 5, Level = 10, SelectedRole = "Bard" },
}), "unexpected")

ok("ValidateLevelRequirements sealed Normal", DungeonValidator.ValidateLevelRequirements(makeParty(10), "dungeon_sealed_crypt", "Normal"))
ok("ValidateLevelRequirements mistwood Normal", DungeonValidator.ValidateLevelRequirements(makeParty(8), "dungeon_mistwood_depths", "Normal"))
failResult("ValidateLevelRequirements mistwood Hard underlevel", DungeonValidator.ValidateLevelRequirements(makeParty(12), "dungeon_mistwood_depths", "Hard"), "level requirement")
failResult("ValidateLevelRequirements sealed Nightmare underlevel", DungeonValidator.ValidateLevelRequirements(makeParty(10), "dungeon_sealed_crypt", "Nightmare"), "level requirement")

ok("CanEnterDungeon sealed Normal", DungeonValidator.CanEnterDungeon(makeParty(10), "dungeon_sealed_crypt", "Normal"))
ok("CanEnterDungeon mistwood Hard", DungeonValidator.CanEnterDungeon(makeParty(13), "dungeon_mistwood_depths", "Hard"))
failResult("CanEnterDungeon four players", DungeonValidator.CanEnterDungeon({
	{ UserId = 1, Level = 10, SelectedRole = "Tank" },
	{ UserId = 2, Level = 10, SelectedRole = "Healer" },
	{ UserId = 3, Level = 10, SelectedRole = "DPS" },
	{ UserId = 4, Level = 10, SelectedRole = "DPS" },
}, "dungeon_sealed_crypt", "Normal"), "party size")
failResult("CanEnterDungeon all DPS", DungeonValidator.CanEnterDungeon({
	{ UserId = 1, Level = 10, SelectedRole = "DPS" },
	{ UserId = 2, Level = 10, SelectedRole = "DPS" },
	{ UserId = 3, Level = 10, SelectedRole = "DPS" },
	{ UserId = 4, Level = 10, SelectedRole = "DPS" },
	{ UserId = 5, Level = 10, SelectedRole = "DPS" },
}, "dungeon_sealed_crypt", "Normal"), "role composition")

local immutableParty = makeParty(10)
local before = deepCopy(immutableParty)
DungeonValidator.ValidateRoleComposition(immutableParty)
DungeonValidator.ValidateLevelRequirements(immutableParty, "dungeon_sealed_crypt", "Normal")
DungeonValidator.CanEnterDungeon(immutableParty, "dungeon_sealed_crypt", "Normal")
record("Player snapshots not mutated", deepEqual(immutableParty, before))

if failed == 0 then
	print(string.format("[DungeonValidatorSmokeTest] All checks passed (%d assertions).", passed))
else
	warn(string.format("[DungeonValidatorSmokeTest] %d passed, %d failed.", passed, failed))
end
