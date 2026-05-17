--!strict
-- SealedCryptRunner.server.lua
-- Full dungeon level for "The Sealed Crypt" (dungeon_sealed_crypt).
--
-- Flow:
--   1. Listens for QueueService.RunStarted signal filtered to dungeon_sealed_crypt.
--   2. Teleports the party to the dungeon area (CRYPT_ORIGIN + room offsets).
--   3. Spawns Room-1 mobs (3× Crypt Guard) → objective "seal_breach".
--   4. On Room-1 cleared: opens gate, spawns Room-2 mobs (3× Restless Skeleton).
--   5. On Room-2 cleared: spawns Crypt Lord boss → objective "crypt_lord".
--   6. On boss dead: CompleteRun → DungeonStateUpdate "Completed" → teleport home.
--   7. Time-limit watchdog: FailRun if 1800s elapse → teleport home.
--   8. Clean-up on server shutdown or all players leaving early.
--
-- Map assumption:
--   Workspace contains a Model named "Dungeons/SealedCrypt" with anchored
--   BasePart "Origin" (CFrame reference). If absent, the dungeon spawns at
--   the hardcoded FALLBACK_ORIGIN CFrame and flat floor parts are inserted
--   automatically so the run still functions during development.

local Players             = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Workspace           = game:GetService("Workspace")

-- ── service references (lazy-resolved so this script loads independently) ─

local Server   = ServerScriptService:WaitForChild("Server")
local Services = Server:WaitForChild("Services")

local MobAIService   = require(Services:WaitForChild("MobAIService"))
local DungeonService = require(Services:WaitForChild("DungeonService"))
local QueueService   = require(Services:WaitForChild("QueueService"))

local DungeonRemotes = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("DungeonRemotes")
)

-- ── constants ─────────────────────────────────────────────────────────────

local DUNGEON_ID      = "dungeon_sealed_crypt"
local OBJ_BREACH      = "seal_breach"
local OBJ_BOSS        = "crypt_lord"
local TIME_LIMIT      = 1800        -- seconds
local LOBBY_SPAWN_CF  = CFrame.new(0, 5, 0)   -- where players respawn after run

-- Fallback dungeon origin (used when the Workspace map model is absent).
-- Place this far above the overworld so it stays out of sight.
local FALLBACK_ORIGIN = CFrame.new(0, 600, 0)

-- Room offsets relative to the dungeon origin (all same Y since floor is flat).
local ROOM1_OFFSET  = Vector3.new(0,   0,  0)
local ROOM2_OFFSET  = Vector3.new(0,   0, 60)
local BOSS_OFFSET   = Vector3.new(0,   0, 120)

-- Mob spawn positions within each room (spread around centre).
local ROOM1_SPAWNS: { Vector3 } = {
	Vector3.new(-8,  0,  5),
	Vector3.new( 0,  0,  5),
	Vector3.new( 8,  0,  5),
}
local ROOM2_SPAWNS: { Vector3 } = {
	Vector3.new(-8,  0,  5),
	Vector3.new( 0,  0,  5),
	Vector3.new( 8,  0,  5),
}

-- Player arrival spots in the dungeon entrance (staggered line).
local PLAYER_SPAWN_OFFSETS: { Vector3 } = {
	Vector3.new(-4, 0, -20),
	Vector3.new(-2, 0, -20),
	Vector3.new( 0, 0, -20),
	Vector3.new( 2, 0, -20),
	Vector3.new( 4, 0, -20),
}

-- ── active run table ──────────────────────────────────────────────────────

type RunContext = {
	runId        : string,
	dungeonId    : string,
	players      : { Player },
	origin       : CFrame,
	aliveRoom1   : number,
	aliveRoom2   : number,
	bossAlive    : boolean,
	completed    : boolean,
	watchdogConn : thread?,
}

local activeRuns: { [string]: RunContext } = {}

-- ── helpers ───────────────────────────────────────────────────────────────

local function fireAllPlayers(ctx: RunContext, event: RemoteEvent, payload: any)
	for _, player in ipairs(ctx.players) do
		if player.Parent == Players then
			event:FireClient(player, payload)
		end
	end
end

local function resolveOrigin(): CFrame
	local dungeonsFolder = Workspace:FindFirstChild("Dungeons")
	if dungeonsFolder then
		local cryptModel = dungeonsFolder:FindFirstChild("SealedCrypt")
		if cryptModel then
			local originPart = cryptModel:FindFirstChild("Origin") :: BasePart?
			if originPart then
				return originPart.CFrame
			end
		end
	end
	return FALLBACK_ORIGIN
end

-- Builds a minimal flat floor so mobs and players have something to stand on
-- when the workspace map doesn't have the SealedCrypt model.
local function ensureFallbackFloor(origin: CFrame)
	local dungeonsFolder = Workspace:FindFirstChild("Dungeons")
	if dungeonsFolder and dungeonsFolder:FindFirstChild("SealedCrypt") then
		return  -- real map exists, skip
	end

	local folder = Workspace:FindFirstChild("_CryptTemp") :: Folder?
	if folder then return end  -- already built

	folder = Instance.new("Folder")
	folder.Name = "_CryptTemp"

	local rooms = {
		{ offset = ROOM1_OFFSET,  size = Vector3.new(30, 1, 30) },
		{ offset = ROOM2_OFFSET,  size = Vector3.new(30, 1, 30) },
		{ offset = BOSS_OFFSET,   size = Vector3.new(40, 1, 40) },
	}
	for _, room in ipairs(rooms) do
		local floorPos = (origin * CFrame.new(room.offset)).Position - Vector3.new(0, 1, 0)
		local floor = Instance.new("Part")
		floor.Size        = room.size
		floor.CFrame      = CFrame.new(floorPos)
		floor.Anchored    = true
		floor.Material    = Enum.Material.SmoothPlastic
		floor.Color       = Color3.fromRGB(45, 40, 55)
		floor.Name        = "CryptFloor"
		floor.Parent      = folder
	end

	folder.Parent = Workspace
end

local function teleportPlayers(ctx: RunContext, positions: { Vector3 })
	for i, player in ipairs(ctx.players) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local pos = positions[i] or positions[#positions]
			root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
		end
	end
end

local function teleportToLobby(ctx: RunContext)
	for _, player in ipairs(ctx.players) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.CFrame = LOBBY_SPAWN_CF
		end
	end
end

local function endRun(ctx: RunContext, success: boolean, reason: string?)
	if ctx.completed then return end
	ctx.completed = true

	-- Cancel watchdog
	if ctx.watchdogConn then
		task.cancel(ctx.watchdogConn)
		ctx.watchdogConn = nil
	end

	local stateEvent = DungeonRemotes.GetEvent("DungeonStateUpdate")

	if success then
		DungeonService.CompleteRun(ctx.runId)
		fireAllPlayers(ctx, stateEvent, {
			status    = "Completed",
			dungeonId = ctx.dungeonId,
			message   = "Крипта Запечатана. Победа!",
		})
	else
		DungeonService.FailRun(ctx.runId, reason or "Время вышло.")
		fireAllPlayers(ctx, stateEvent, {
			status    = "Failed",
			dungeonId = ctx.dungeonId,
			message   = reason or "Вы не успели — провал.",
		})
	end

	-- Brief pause so clients can display the result screen before returning.
	task.delay(6, function()
		teleportToLobby(ctx)
		-- Clean up the temp floor if we built it.
		local tempFolder = Workspace:FindFirstChild("_CryptTemp")
		if tempFolder then tempFolder:Destroy() end
		activeRuns[ctx.runId] = nil
	end)
end

-- ── dungeon progression ───────────────────────────────────────────────────

local function spawnBoss(ctx: RunContext)
	if ctx.completed then return end

	local bossWorldPos = (ctx.origin * CFrame.new(BOSS_OFFSET)).Position

	DungeonService.StartRun(ctx.runId)  -- ensure status is Active if not yet set

	MobAIService.SpawnMob("mob_crypt_lord", bossWorldPos, function()
		-- Boss died → complete crypt_lord objective
		if ctx.completed then return end
		DungeonService.CompleteObjective(ctx.runId, OBJ_BOSS)
		ctx.bossAlive = false

		fireAllPlayers(ctx, DungeonRemotes.GetEvent("DungeonStateUpdate"), {
			status    = "BossDefeated",
			dungeonId = ctx.dungeonId,
			message   = "Властелин Крипты повержен!",
		})

		endRun(ctx, true)
	end)

	fireAllPlayers(ctx, DungeonRemotes.GetEvent("DungeonStateUpdate"), {
		status    = "BossSpawned",
		dungeonId = ctx.dungeonId,
		message   = "Властелин Крипты пробуждается!",
	})
end

local function spawnRoom2(ctx: RunContext)
	if ctx.completed then return end

	local originCF = ctx.origin * CFrame.new(ROOM2_OFFSET)
	ctx.aliveRoom2 = #ROOM2_SPAWNS

	for _, localOffset in ipairs(ROOM2_SPAWNS) do
		local worldPos = (originCF * CFrame.new(localOffset)).Position
		MobAIService.SpawnMob("mob_restless_skeleton", worldPos, function()
			if ctx.completed then return end
			ctx.aliveRoom2 -= 1
			if ctx.aliveRoom2 <= 0 then
				-- All guards in room 2 cleared → spawn boss
				task.delay(2, function()
					spawnBoss(ctx)
				end)
			end
		end)
	end

	fireAllPlayers(ctx, DungeonRemotes.GetEvent("DungeonStateUpdate"), {
		status    = "Room2",
		dungeonId = ctx.dungeonId,
		message   = "Проход открыт. Беспокойные стражи преграждают путь!",
	})
end

local function spawnRoom1(ctx: RunContext)
	if ctx.completed then return end

	local originCF = ctx.origin * CFrame.new(ROOM1_OFFSET)
	ctx.aliveRoom1 = #ROOM1_SPAWNS

	for _, localOffset in ipairs(ROOM1_SPAWNS) do
		local worldPos = (originCF * CFrame.new(localOffset)).Position
		MobAIService.SpawnMob("mob_crypt_guard", worldPos, function()
			if ctx.completed then return end
			ctx.aliveRoom1 -= 1
			if ctx.aliveRoom1 <= 0 then
				-- Room 1 cleared → complete seal_breach objective
				DungeonService.CompleteObjective(ctx.runId, OBJ_BREACH)
				fireAllPlayers(ctx, DungeonRemotes.GetEvent("DungeonStateUpdate"), {
					status    = "Room1Cleared",
					dungeonId = ctx.dungeonId,
					message   = "Печать нарушителя уничтожена. Двигайтесь вперёд!",
				})
				task.delay(3, function()
					spawnRoom2(ctx)
				end)
			end
		end)
	end

	fireAllPlayers(ctx, DungeonRemotes.GetEvent("DungeonStateUpdate"), {
		status    = "Room1",
		dungeonId = ctx.dungeonId,
		message   = "Стражи Крипты атакуют! Уничтожьте их всех.",
	})
end

-- ── run start handler ─────────────────────────────────────────────────────

local function onRunStarted(players: { Player }, payload: any)
	if type(payload) ~= "table" then return end
	if payload.dungeonId ~= DUNGEON_ID then return end

	local runId = payload.runId
	if type(runId) ~= "string" or runId == "" then
		warn("[SealedCryptRunner] RunStarted payload missing runId.")
		return
	end

	if activeRuns[runId] then return end  -- guard against duplicate fires

	local origin = resolveOrigin()
	ensureFallbackFloor(origin)

	-- Build spawn positions in world space
	local spawnPositions: { Vector3 } = {}
	for i, offset in ipairs(PLAYER_SPAWN_OFFSETS) do
		spawnPositions[i] = (origin * CFrame.new(offset)).Position
	end

	local ctx: RunContext = {
		runId       = runId,
		dungeonId   = DUNGEON_ID,
		players     = players,
		origin      = origin,
		aliveRoom1  = 0,
		aliveRoom2  = 0,
		bossAlive   = false,
		completed   = false,
		watchdogConn = nil,
	}
	activeRuns[runId] = ctx

	-- Small delay so the client DungeonStateUpdate "RunStarted" is received first.
	task.delay(1.5, function()
		teleportPlayers(ctx, spawnPositions)
	end)

	-- Spawn first room after teleport settles
	task.delay(4, function()
		spawnRoom1(ctx)
	end)

	-- Start time-limit watchdog
	ctx.watchdogConn = task.delay(TIME_LIMIT, function()
		if not ctx.completed then
			endRun(ctx, false, "Время данжа истекло. Провал!")
		end
	end)
end

-- ── hook into QueueService.RunStarted ────────────────────────────────────
-- QueueService.RunStarted fires (players: {Player}, payload: {runId, dungeonId, difficulty})

QueueService.RunStarted:Connect(onRunStarted)

-- ── player-removing safety net ────────────────────────────────────────────
-- If all members of an active run disconnect, fail the run.

Players.PlayerRemoving:Connect(function(leavingPlayer: Player)
	for runId, ctx in pairs(activeRuns) do
		for idx, player in ipairs(ctx.players) do
			if player == leavingPlayer then
				table.remove(ctx.players, idx)
				break
			end
		end
		if #ctx.players == 0 and not ctx.completed then
			endRun(ctx, false, "Все игроки покинули данж.")
		end
	end
end)

print("[SealedCryptRunner] Loaded — listening for dungeon_sealed_crypt runs.")
