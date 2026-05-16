--!strict
-- Verifies that the Server folder and core descendants are visible in server runtime.
-- This catches save/publish/runtime-replication issues where edit-mode objects appear but runtime objects are missing.

local ServerScriptService = game:GetService("ServerScriptService")

local checks = {
	{ { "Server" }, "Folder" },
	{ { "Server", "Config" }, "Folder" },
	{ { "Server", "Validators" }, "Folder" },
	{ { "Server", "Services" }, "Folder" },
	{ { "Server", "Boot.server" }, "Script" },
	{ { "Server", "Services", "PlayerDataService" }, "ModuleScript" },
	{ { "Server", "Services", "DungeonService" }, "ModuleScript" },
	{ { "Server", "Validators", "DungeonValidator" }, "ModuleScript" },
	{ { "Server", "Config", "DungeonConfig" }, "ModuleScript" },
}

local function formatPath(segments: { string }): string
	return table.concat(segments, ".")
end

local function findPath(segments: { string }): Instance?
	local current: Instance = ServerScriptService
	for _, segment in ipairs(segments) do
		local child = current:FindFirstChild(segment)
		if not child then
			return nil
		end
		current = child
	end
	return current
end

local passed = 0
local failed = 0
for _, check in ipairs(checks) do
	local segments = check[1]
	local expectedClass = check[2]
	local path = formatPath(segments)
	local inst = findPath(segments)
	if inst and inst.ClassName == expectedClass then
		passed += 1
		print(string.format("[ServerRuntimeSmokeTest] [PASS] %s", path))
	else
		failed += 1
		warn(string.format("[ServerRuntimeSmokeTest] [FAIL] %s expected %s, got %s", path, expectedClass, inst and inst.ClassName or "nil"))
	end
end

if failed == 0 then
	print(string.format("[ServerRuntimeSmokeTest] Server runtime tree OK (%d checks).", passed))
else
	warn(string.format("[ServerRuntimeSmokeTest] Server runtime tree missing objects: %d passed, %d failed.", passed, failed))
end
