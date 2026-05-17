--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local sharedConfig = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local serverConfig = ServerScriptService:WaitForChild("Server"):WaitForChild("Config")

local sharedModules = { "GameEnums", "ClassConfig", "RoleConfig", "StatFormulas", "AbilityConfig", "MobConfig", "QuestsConfig", "PlayerDataConfig", "ItemConfig" }
local serverModules = { "ProfessionConfig", "DungeonConfig", "RaidConfig", "ArenaConfig", "MobServerConfig", "QuestsServerConfig" }

for _, moduleName in ipairs(sharedModules) do
	require(sharedConfig:WaitForChild(moduleName))
end

for _, moduleName in ipairs(serverModules) do
	require(serverConfig:WaitForChild(moduleName))
end

print(string.format("[GhostyRPG] Config smoke test loaded %d modules.", #sharedModules + #serverModules))
