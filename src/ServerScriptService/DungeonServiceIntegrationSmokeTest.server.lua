--!strict
-- Non-destructive integration smoke for DungeonService.CreateRun.
-- Uses the live first player when available and verifies the CreateRun -> PlayerData snapshots -> CanEnterDungeon path.
-- Full successful 5-player dungeon creation is intentionally left to a manual multiplayer test.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Services = Server:WaitForChild("Services")

local PlayerDataService = require(Services:WaitForChild("PlayerDataService") :: ModuleScript)
local DungeonService = require(Services:WaitForChild("DungeonService") :: ModuleScript)
local DungeonValidator = require(Server:WaitForChild("Validators"):WaitForChild("DungeonValidator") :: ModuleScript)

local passed = 0
local failed = 0
local skipped = 0

local function pass(label: string)
	passed += 1
	print("[DungeonServiceIntegrationSmokeTest] [PASS] " .. label)
end

local function fail(label: string, detail: string?)
	failed += 1
	warn(string.format("[DungeonServiceIntegrationSmokeTest] [FAIL] %s%s", label, if detail then ": " .. detail else ""))
end

local function skip(label: string, detail: string?)
	skipped += 1
	warn(string.format("[DungeonServiceIntegrationSmokeTest] [SKIP] %s%s", label, if detail then ": " .. detail else ""))
end

local function waitForFirstPlayer(timeoutSeconds: number): Player?
	local existing = Players:GetPlayers()[1]
	if existing then
		return existing
	end
	local deadline = os.clock() + timeoutSeconds
	while os.clock() < deadline do
		task.wait(0.25)
		existing = Players:GetPlayers()[1]
		if existing then
			return existing
		end
	end
	return nil
end

local player = waitForFirstPlayer(10)
if not player then
	skip("live-player CreateRun path", "no player joined within 10 seconds")
else
	local deadline = os.clock() + 10
	while not PlayerDataService.IsLoaded(player) and os.clock() < deadline do
		task.wait(0.25)
	end

	if not PlayerDataService.IsLoaded(player) then
		skip("live-player CreateRun path", "PlayerDataService did not load player within 10 seconds")
	else
		local data = PlayerDataService.GetData(player)
		if type(data) ~= "table" then
			fail("PlayerDataService.GetData", "returned non-table")
		else
			local originalLevel = data.Level
			local originalRole = data.SelectedRole
			PlayerDataService.UpdateData(player, function(profile)
				profile.Level = 10
				profile.SelectedRole = "Tank"
			end)

			local beforeRun = DungeonService.GetPlayerRun(player)
			local runId, err = DungeonService.CreateRun(player, "dungeon_sealed_crypt", "Normal")
			local afterRun = DungeonService.GetPlayerRun(player)

			if runId == nil and type(err) == "string" and string.find(string.lower(err), "party size", 1, true) then
				pass("CreateRun reached CanEnterDungeon and rejected solo party size")
			else
				fail("CreateRun solo rejection", string.format("runId=%s err=%s", tostring(runId), tostring(err)))
				if runId then
					DungeonService.FailRun(runId, "integration smoke cleanup")
				end
			end

			if beforeRun == nil and afterRun == nil then
				pass("CreateRun rejection left player out of dungeon run")
			else
				fail("CreateRun rejection state cleanup", "player was indexed into a run unexpectedly")
			end

			local validatorResult = DungeonValidator.CanEnterDungeon({
				{ UserId = player.UserId, Level = 10, SelectedRole = "Tank" },
			}, "dungeon_sealed_crypt", "Normal")
			if type(validatorResult) == "table" and validatorResult.success == false then
				pass("DungeonValidator.CanEnterDungeon returns result object for integration path")
			else
				fail("DungeonValidator.CanEnterDungeon result shape", tostring(validatorResult))
			end

			PlayerDataService.UpdateData(player, function(profile)
				profile.Level = originalLevel
				profile.SelectedRole = originalRole
			end)
		end
	end
end

if #Players:GetPlayers() < 5 then
	skip("valid 5-player CreateRun", "requires manual Start Server test with 5 players")
else
	pass("5-player environment available for manual CreateRun validation")
end

if failed == 0 then
	print(string.format("[DungeonServiceIntegrationSmokeTest] Complete: %d passed, %d skipped, 0 failed.", passed, skipped))
else
	warn(string.format("[DungeonServiceIntegrationSmokeTest] Complete: %d passed, %d skipped, %d failed.", passed, skipped, failed))
end
