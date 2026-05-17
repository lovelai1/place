--!strict
-- ArenaService.lua  —  ServerScriptService/Server/Services/ArenaService.lua
-- Server-authoritative PvP arena: queue, matchmaking, match lifecycle, ELO rating.
-- Supports 2v2, 3v3, and 5v5 brackets (configured in ArenaConfig).

local Players             = game:GetService("Players")
local HttpService         = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local ArenaConfig = require(
	ServerScriptService:WaitForChild("Server"):WaitForChild("Config"):WaitForChild("ArenaConfig")
)
local ArenaRemotes = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("ArenaRemotes")
)

local ArenaService = {}

-- ── types ──────────────────────────────────────────────────────────────────

type TeamColor = "Red" | "Blue"

type MatchMember = {
	player       : Player,
	team         : TeamColor,
	alive        : boolean,
	ratingBefore : number,
}

type MatchData = {
	matchId     : string,
	bracketSize : number,
	members     : { MatchMember },
	team1Alive  : number,
	team2Alive  : number,
	status      : "Active" | "Ended",
	startedAt   : number,
	mapName     : string,
	mapOriginCF : CFrame,
	watchdog    : thread?,
}

type QueueEntry = {
	player   : Player,
	rating   : number,
	joinedAt : number,
}

-- ── module state ────────────────────────────────────────────────────────────

local queues:      { [number]: { QueueEntry } } = {}
local playerQueue: { [number]: number }         = {}
local matches:     { [string]: MatchData }      = {}
local playerMatch: { [number]: string }         = {}

local playerDataService: any = nil
local magicTierService: any  = nil  -- Phase 5: AMP on arena win
local initialized            = false

local MAP_ORIGINS: { CFrame } = {
	CFrame.new( 500, 700, 0),
	CFrame.new(-500, 700, 0),
	CFrame.new(   0, 700, 500),
	CFrame.new(   0, 700,-500),
}
local nextMapSlot = 1

-- ── ELO helpers ─────────────────────────────────────────────────────────────

local function kFactor(rating: number): number
	local best = 64
	for threshold, k in pairs(ArenaConfig.Matchmaking.KFactor) do
		if rating >= threshold and k < best then best = k end
	end
	return best
end

local function expectedScore(rA: number, rB: number): number
	return 1 / (1 + 10 ^ ((rB - rA) / 400))
end

local function calculateElo(winnerRating: number, loserRating: number): (number, number)
	local Ea   = expectedScore(winnerRating, loserRating)
	local gain = math.max(1, math.floor(kFactor(winnerRating) * (1 - Ea)))
	local loss = math.max(1, math.floor(kFactor(loserRating)  * Ea))
	return gain, loss
end

-- ── data helpers ────────────────────────────────────────────────────────────

local function getPlayerRating(player: Player): number
	if playerDataService and type(playerDataService.GetData) == "function" then
		local data = playerDataService.GetData(player)
		if type(data) == "table" and type(data.ArenaProfile) == "table" then
			return data.ArenaProfile.rating or ArenaConfig.Matchmaking.StartingRating
		end
	end
	return ArenaConfig.Matchmaking.StartingRating
end

local function setPlayerRating(player: Player, newRating: number)
	if not playerDataService then return end
	local data = playerDataService.GetData(player)
	if type(data) ~= "table" then return end
	if type(data.ArenaProfile) ~= "table" then
		data.ArenaProfile = { rating = ArenaConfig.Matchmaking.StartingRating, wins = 0, losses = 0, season = 1 }
	end
	data.ArenaProfile.rating = math.max(ArenaConfig.Matchmaking.RatingFloor, newRating)
end

local function recordResult(player: Player, won: boolean)
	if not playerDataService then return end
	local data = playerDataService.GetData(player)
	if type(data) ~= "table" then return end
	if type(data.ArenaProfile) ~= "table" then
		data.ArenaProfile = { rating = ArenaConfig.Matchmaking.StartingRating, wins = 0, losses = 0, season = 1 }
	end
	if won then
		data.ArenaProfile.wins = (data.ArenaProfile.wins or 0) + 1
	else
		data.ArenaProfile.losses = (data.ArenaProfile.losses or 0) + 1
	end
	if playerDataService.ScheduleSave then
		playerDataService.ScheduleSave(player)
	end
end

local function pickMap(): (string, CFrame)
	local maps = ArenaConfig.Maps
	local idx  = math.random(1, #maps)
	local slot = MAP_ORIGINS[nextMapSlot]
	nextMapSlot = (nextMapSlot % #MAP_ORIGINS) + 1
	return maps[idx].Name, slot
end

local function teleportToArena(match: MatchData)
	local origin = match.mapOriginCF
	local t1i, t2i = 0, 0
	for _, m in ipairs(match.members) do
		local char = m.player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local offset: Vector3
			if m.team == "Red" then
				t1i += 1; offset = Vector3.new(-10 + (t1i-1)*4, 3,  12)
			else
				t2i += 1; offset = Vector3.new(-10 + (t2i-1)*4, 3, -12)
			end
			root.CFrame = origin * CFrame.new(offset)
		end
	end
end

local LOBBY_CF = CFrame.new(0, 5, 0)

local function teleportToLobby(match: MatchData)
	for _, m in ipairs(match.members) do
		local char = m.player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then root.CFrame = LOBBY_CF end
	end
end

local function fireAllInMatch(match: MatchData, event: RemoteEvent, payload: any)
	for _, m in ipairs(match.members) do
		if m.player.Parent == Players then
			event:FireClient(m.player, payload)
		end
	end
end

-- ── match end ──────────────────────────────────────────────────────────────

local function endMatch(match: MatchData, winnerTeam: TeamColor?)
	if match.status == "Ended" then return end
	match.status = "Ended"

	if match.watchdog then task.cancel(match.watchdog); match.watchdog = nil end

	local winnerRatings, loserRatings = {}, {}
	for _, m in ipairs(match.members) do
		if winnerTeam == nil then
			table.insert(winnerRatings, m.ratingBefore)
		elseif m.team == winnerTeam then
			table.insert(winnerRatings, m.ratingBefore)
		else
			table.insert(loserRatings, m.ratingBefore)
		end
	end

	local function avg(t: { number }): number
		if #t == 0 then return ArenaConfig.Matchmaking.StartingRating end
		local s = 0; for _, v in ipairs(t) do s += v end; return s / #t
	end

	local ratingGain, ratingLoss = calculateElo(avg(winnerRatings), avg(loserRatings))

	for _, m in ipairs(match.members) do
		playerMatch[m.player.UserId] = nil
		local isDraw   = winnerTeam == nil
		local isWinner = not isDraw and m.team == winnerTeam
		local delta    = if isDraw then 0 elseif isWinner then ratingGain else -ratingLoss
		local newR     = math.max(ArenaConfig.Matchmaking.RatingFloor, m.ratingBefore + delta)

		setPlayerRating(m.player, newR)
		recordResult(m.player, isWinner)

		-- Phase 5: AMP reward for winning a match
		if isWinner and magicTierService then
			pcall(magicTierService.AddAMP, m.player, 100, "ArenaWin")
		end

		ArenaRemotes.GetEvent("MatchEnded"):FireClient(m.player, {
			result       = if isDraw then "Draw" elseif isWinner then "Win" else "Loss",
			ratingChange = delta,
			newRating    = newR,
		})
	end

	task.delay(8, function()
		teleportToLobby(match)
		matches[match.matchId] = nil
	end)
end

-- ── public: player died ─────────────────────────────────────────────────────

function ArenaService.OnPlayerDied(player: Player)
	local matchId = playerMatch[player.UserId]
	if not matchId then return end
	local match = matches[matchId]
	if not match or match.status ~= "Active" then return end

	for _, m in ipairs(match.members) do
		if m.player == player then
			if not m.alive then return end
			m.alive = false
			if m.team == "Red" then match.team1Alive -= 1 else match.team2Alive -= 1 end
			break
		end
	end

	fireAllInMatch(match, ArenaRemotes.GetEvent("MatchStateUpdate"), {
		event = "PlayerDied",
		data  = { playerName = player.Name },
	})

	if match.team1Alive <= 0 then      endMatch(match, "Blue")
	elseif match.team2Alive <= 0 then  endMatch(match, "Red") end
end

-- ── create match ────────────────────────────────────────────────────────────

local function createMatch(team1: { QueueEntry }, team2: { QueueEntry }, bracketSize: number)
	local matchId           = "ARENA_" .. HttpService:GenerateGUID(false)
	local mapName, originCF = pickMap()

	local members: { MatchMember } = {}
	local function addTeam(entries: { QueueEntry }, team: TeamColor)
		for _, e in ipairs(entries) do
			table.insert(members, { player = e.player, team = team, alive = true, ratingBefore = e.rating })
		end
	end
	addTeam(team1, "Red")
	addTeam(team2, "Blue")

	local match: MatchData = {
		matchId     = matchId,
		bracketSize = bracketSize,
		members     = members,
		team1Alive  = bracketSize,
		team2Alive  = bracketSize,
		status      = "Active",
		startedAt   = os.time(),
		mapName     = mapName,
		mapOriginCF = originCF,
		watchdog    = nil,
	}
	matches[matchId] = match
	for _, m in ipairs(members) do playerMatch[m.player.UserId] = matchId end

	local function buildOpponents(myTeam: TeamColor)
		local list = {}
		for _, m in ipairs(members) do
			if m.team ~= myTeam then
				table.insert(list, { name = m.player.Name, rating = m.ratingBefore })
			end
		end
		return list
	end

	for _, m in ipairs(members) do
		ArenaRemotes.GetEvent("MatchFound"):FireClient(m.player, {
			matchId   = matchId,
			mapName   = mapName,
			teamColor = m.team,
			opponents = buildOpponents(m.team),
		})
	end

	task.delay(3, function()
		teleportToArena(match)
		fireAllInMatch(match, ArenaRemotes.GetEvent("MatchStarted"), {
			matchId  = matchId,
			duration = ArenaConfig.MatchDuration.BaseSeconds,
		})
	end)

	for _, m in ipairs(members) do
		local capturedMember = m
		local function wireChar(char: Model)
			local hum = char:WaitForChild("Humanoid") :: Humanoid
			hum.Died:Connect(function()
				ArenaService.OnPlayerDied(capturedMember.player)
			end)
		end
		if m.player.Character then wireChar(m.player.Character) end
		m.player.CharacterAdded:Connect(function(newChar)
			wireChar(newChar)
			if matches[matchId] and matches[matchId].status == "Active" then
				task.delay(1, function()
					local root = newChar:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root then root.CFrame = originCF * CFrame.new(0, 3, 0) end
				end)
			end
		end)
	end

	-- Time-limit watchdog
	local cfg = ArenaConfig.MatchDuration
	match.watchdog = task.delay(cfg.BaseSeconds, function()
		if match.status ~= "Active" then return end
		if cfg.TimeLimitExpiry == "DrawOrLowerHP" then
			local t1hp, t2hp = 0, 0
			for _, m in ipairs(members) do
				if m.alive then
					local char = m.player.Character
					local hum  = char and char:FindFirstChildOfClass("Humanoid")
					if hum then
						if m.team == "Red" then t1hp += hum.Health else t2hp += hum.Health end
					end
				end
			end
			if t1hp > t2hp then endMatch(match, "Red")
			elseif t2hp > t1hp then endMatch(match, "Blue")
			else endMatch(match, nil) end
		else
			endMatch(match, nil)
		end
	end)

	print(string.format("[ArenaService] Match %s created (%dv%d) on %s.", matchId, bracketSize, bracketSize, mapName))
end

-- ── matchmaking sweep ───────────────────────────────────────────────────────

local function tryMatchmake(bracketSize: number)
	local queue = queues[bracketSize]
	if not queue or #queue < bracketSize * 2 then return end
	table.sort(queue, function(a, b) return a.rating < b.rating end)

	local maxDiff = ArenaConfig.Matchmaking.MaxRatingDifference
	local i = 1
	while i <= #queue - bracketSize * 2 + 1 do
		local team1: { QueueEntry } = {}
		for j = i, i + bracketSize - 1 do table.insert(team1, queue[j]) end
		local baseRating = team1[1].rating

		local team2: { QueueEntry } = {}
		for j = i + bracketSize, i + bracketSize * 2 - 1 do
			if queue[j] and math.abs(queue[j].rating - baseRating) <= maxDiff then
				table.insert(team2, queue[j])
			end
		end

		if #team2 == bracketSize then
			local toRemove: { Player } = {}
			for _, e in ipairs(team1) do table.insert(toRemove, e.player) end
			for _, e in ipairs(team2) do table.insert(toRemove, e.player) end
			for _, p in ipairs(toRemove) do
				playerQueue[p.UserId] = nil
				for qi, entry in ipairs(queue) do
					if entry.player == p then table.remove(queue, qi); break end
				end
			end
			createMatch(team1, team2, bracketSize)
			return
		end
		i += 1
	end
end

-- ── public API ──────────────────────────────────────────────────────────────

function ArenaService.JoinQueue(player: Player, bracketSize: number): (boolean, string?)
	assert(initialized, "[ArenaService] Call Init() first.")
	local valid = false
	for _, s in ipairs(ArenaConfig.TeamSizes) do if s == bracketSize then valid = true; break end end
	if not valid then return false, "Invalid bracket size." end
	if playerQueue[player.UserId] then return false, "Already in queue." end
	if playerMatch[player.UserId] then return false, "Already in a match." end

	local rating = getPlayerRating(player)
	queues[bracketSize] = queues[bracketSize] or {}
	table.insert(queues[bracketSize], { player = player, rating = rating, joinedAt = os.time() })
	playerQueue[player.UserId] = bracketSize

	ArenaRemotes.GetEvent("QueueStatus"):FireClient(player, {
		inQueue      = true,
		bracketSize  = bracketSize,
		position     = #queues[bracketSize],
		estimatedWait = bracketSize * 30,
	})

	tryMatchmake(bracketSize)
	return true, nil
end

function ArenaService.LeaveQueue(player: Player): (boolean, string?)
	local bracketSize = playerQueue[player.UserId]
	if not bracketSize then return false, "Not in queue." end
	playerQueue[player.UserId] = nil
	local queue = queues[bracketSize]
	if queue then
		for i, entry in ipairs(queue) do
			if entry.player == player then table.remove(queue, i); break end
		end
	end
	ArenaRemotes.GetEvent("QueueStatus"):FireClient(player, { inQueue = false })
	return true, nil
end

function ArenaService.GetArenaProfile(player: Player): { [string]: any }
	local data = playerDataService and playerDataService.GetData(player)
	if type(data) == "table" and type(data.ArenaProfile) == "table" then
		return data.ArenaProfile
	end
	return { rating = ArenaConfig.Matchmaking.StartingRating, wins = 0, losses = 0, season = 1 }
end

function ArenaService.Init(newPlayerDataService: any, newMagicTierService: any?)
	if initialized then warn("[ArenaService] Init called more than once."); return end
	assert(newPlayerDataService, "[ArenaService] Init requires PlayerDataService.")
	playerDataService = newPlayerDataService
	magicTierService  = newMagicTierService  -- Phase 5
	initialized       = true

	task.spawn(function()
		while true do
			task.wait(5)
			if initialized then
				for _, bracketSize in ipairs(ArenaConfig.TeamSizes) do
					tryMatchmake(bracketSize)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		ArenaService.LeaveQueue(player)
		local matchId = playerMatch[player.UserId]
		if matchId then
			local match = matches[matchId]
			if match and match.status == "Active" then
				ArenaService.OnPlayerDied(player)
			end
			playerMatch[player.UserId] = nil
		end
	end)

	ArenaRemotes.GetFunction("GetArenaProfile").OnServerInvoke = function(player: Player)
		return ArenaService.GetArenaProfile(player)
	end

	ArenaRemotes.GetFunction("GetLeaderboard").OnServerInvoke = function(_player: Player)
		local result = {}
		for _, p in ipairs(Players:GetPlayers()) do
			local profile = ArenaService.GetArenaProfile(p)
			table.insert(result, { name = p.Name, rating = profile.rating or 1500 })
		end
		table.sort(result, function(a, b) return a.rating > b.rating end)
		return result
	end

	print("[ArenaService] Initialized.")
end

return ArenaService
