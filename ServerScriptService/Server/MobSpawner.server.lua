--!strict
-- MobSpawner.server.lua
-- Размести этот скрипт в ServerScriptService/Server/
-- Спавнит все три типа мобов в мире и перезапускает их после смерти.
--
-- Точки спавна: замени координаты на реальные позиции в твоей карте.
-- Формат: { mobId, Vector3-позиция, кол-во экземпляров }

local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService:WaitForChild("Server"):WaitForChild("Services")

-- MobAIService.Init уже был вызван из Boot — просто требуем модуль.
local MobAIService = require(Services:WaitForChild("MobAIService"))

type SpawnEntry = {
	mobId:  string,
	pos:    Vector3,
	count:  number,
}

local SPAWN_TABLE: { SpawnEntry } = {
	-- Ghost Slimes: близко к стартовой точке, лёгкие
	{ mobId = "mob_ghost_slime",       pos = Vector3.new(  20, 0,  20), count = 3 },
	{ mobId = "mob_ghost_slime",       pos = Vector3.new( -20, 0,  15), count = 2 },

	-- Grave Goblins: чуть дальше
	{ mobId = "mob_grave_goblin",      pos = Vector3.new(  50, 0,  40), count = 2 },
	{ mobId = "mob_grave_goblin",      pos = Vector3.new( -50, 0,  50), count = 2 },

	-- Restless Skeletons: далеко, опасные
	{ mobId = "mob_restless_skeleton", pos = Vector3.new( 100, 0,  80), count = 2 },
	{ mobId = "mob_restless_skeleton", pos = Vector3.new(-100, 0, 100), count = 1 },
}

-- ── spawn helpers ─────────────────────────────────────────────────────────

local function jitter(base: Vector3, radius: number): Vector3
	local angle  = math.random() * math.pi * 2
	local dist   = math.random() * radius
	return base + Vector3.new(
		math.cos(angle) * dist,
		0,
		math.sin(angle) * dist
	)
end

local function spawnOne(entry: SpawnEntry)
	local pos = jitter(entry.pos, 6)   -- spread mobs within 6 studs of anchor

	-- Wait MobConfig respawnSeconds then re-spawn after death
	local mobDef = require(
		game:GetService("ReplicatedStorage")
			:WaitForChild("Shared")
			:WaitForChild("Config")
			:WaitForChild("MobConfig")
	).GetMob(entry.mobId)

	local respawnDelay = (mobDef and mobDef.respawnSeconds) or 30

	MobAIService.SpawnMob(entry.mobId, pos, function()
		-- Respawn after the configured delay
		task.delay(respawnDelay, function()
			spawnOne(entry)
		end)
	end)
end

-- ── boot ─────────────────────────────────────────────────────────────────

-- Small yield to ensure MobAIService.Init has run from Boot
task.wait(0.5)

for _, entry in ipairs(SPAWN_TABLE) do
	for _ = 1, entry.count do
		-- Stagger spawns slightly to avoid 50 AI loops firing simultaneously
		task.wait(0.05)
		task.spawn(spawnOne, entry)
	end
end

print(string.format("[MobSpawner] Spawned %d mob groups.", #SPAWN_TABLE))
