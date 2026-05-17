--!strict
--------------------------------------------------------------------------------
-- GhostyRPG | TombWorldService.lua
-- ServerScriptService/Server/Services/TombWorldService.lua
--
-- Manages the physical space of each player's personal Tomb.
-- INIT: TombWorldService.Init(playerDataService, tombBaseService,
--                              guardianAIService, guardianRemotes)
-- KEY API:
--   TombWorldService.TeleportIn(player)
--   TombWorldService.TeleportOut(player)
--   TombWorldService.OnTombUpgraded(player, newTier)
--   TombWorldService.InvitePlayer(owner, guest)
--   TombWorldService.GetInvitedPlayers(ownerId) → { Player }
--   TombWorldService.IsInsideTomb(player) → boolean
--   TombWorldService.GetInstance(ownerId) → TombInstance?
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedConfig   = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local GuardianConfig = require(SharedConfig:WaitForChild("GuardianConfig"))

local TombWorldService = {}

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------

local OVERWORLD_SPAWN     = Vector3.new(0, 5, 0)
local TOMB_OFFSET_X       = 2000
local PLAYER_SPAWN_HEIGHT = 5

local DEFAULT_SLOT_OFFSETS: { Vector3 } = {
	Vector3.new( 0,  0,  0), Vector3.new( 8,  0,  0), Vector3.new(-8,  0,  0),
	Vector3.new( 0,  0,  8), Vector3.new( 0,  0, -8), Vector3.new(12,  0, 12),
	Vector3.new(-12, 0, 12), Vector3.new( 0,  0, 20),
}

local TIER_ROOMS: { [number]: { string } } = {
	[1] = { "Entrance", "BasicChamber" },
	[2] = { "Entrance", "BasicChamber", "GuardianBarracks", "ArcaneStudy" },
	[3] = { "Entrance", "BasicChamber", "GuardianBarracks", "ArcaneStudy",
	        "LichStudy", "CraftingForge", "TreasureVault_T1" },
	[4] = { "Entrance", "BasicChamber", "GuardianBarracks", "ArcaneStudy",
	        "LichStudy", "CraftingForge", "TreasureVault_T1",
	        "ThroneRoom", "PvPArena", "TreasureVault_T2", "ArcaneLibrary", "GuardianSanctum" },
	[5] = { "Entrance", "BasicChamber", "GuardianBarracks", "ArcaneStudy",
	        "LichStudy", "CraftingForge", "TreasureVault_T1",
	        "ThroneRoom", "PvPArena", "TreasureVault_T2", "ArcaneLibrary", "GuardianSanctum",
	        "NazarickThrone", "FloorGuardianHall", "TreasureVault_T3",
	        "ArcaneLibrary_Grand", "GuildPortal", "OverlordSanctum" },
}

--------------------------------------------------------------------------------
-- TYPES / STATE
--------------------------------------------------------------------------------

type TombInstance = {
	ownerId          : number,
	folder           : Folder,
	origin           : Vector3,
	tier             : number,
	spawnPosition    : Vector3,
	invitedPlayers   : { [number]: true },
	previousPosition : { [number]: Vector3 },
}

local instances: { [number]: TombInstance } = {}
local ownerIndex = 0

local playerDataService: any = nil
local tombBaseService: any   = nil
local guardianAIService: any = nil
local guardianRemotes: any   = nil
local initialized            = false

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function nextOrigin(): Vector3
	ownerIndex += 1
	return Vector3.new(ownerIndex * TOMB_OFFSET_X, 1000, 0)
end

local function getTombsFolder(): Folder
	local f = workspace:FindFirstChild("Tombs")
	if not f then
		f = Instance.new("Folder"); f.Name = "Tombs"; f.Parent = workspace
	end
	return f :: Folder
end

local function loadRoom(roomId: string, position: Vector3, parent: Folder): Model
	local roomsFolder = ServerStorage:FindFirstChild("TombRooms")
	local template    = roomsFolder and roomsFolder:FindFirstChild(roomId)

	if template and template:IsA("Model") then
		local cloned = template:Clone()
		cloned.Name = roomId
		if cloned.PrimaryPart then cloned:SetPrimaryPartCFrame(CFrame.new(position)) end
		cloned.Parent = parent
		return cloned
	end

	-- Placeholder platform
	local placeholder = Instance.new("Model")
	placeholder.Name  = roomId

	local floor   = Instance.new("Part")
	floor.Name    = "Floor"; floor.Size = Vector3.new(40, 1, 40)
	floor.Position = position; floor.Anchored = true
	floor.BrickColor = BrickColor.new("Dark grey metallic")
	floor.Material = Enum.Material.SmoothPlastic
	floor.Parent   = placeholder

	local sign    = Instance.new("Part")
	sign.Size     = Vector3.new(8, 2, 0.5)
	sign.Position = position + Vector3.new(0, 4, -20)
	sign.Anchored = true; sign.BrickColor = BrickColor.new("Black")
	sign.Parent   = placeholder

	local gui = Instance.new("SurfaceGui"); gui.Face = Enum.NormalId.Front; gui.Parent = sign
	local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1; lbl.TextColor3 = Color3.fromRGB(200, 160, 50)
	lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 28; lbl.Text = roomId; lbl.Parent = gui

	placeholder.PrimaryPart = floor
	placeholder.Parent      = parent
	return placeholder
end

local function getSlotPosition(roomModel: Model, slotIndex: number, roomOrigin: Vector3): Vector3
	local slotPart = roomModel:FindFirstChild("GuardianSlot_" .. slotIndex) :: BasePart?
	if slotPart then return slotPart.Position end
	local offset = DEFAULT_SLOT_OFFSETS[slotIndex] or Vector3.new(slotIndex * 6, 0, 0)
	return roomOrigin + offset + Vector3.new(0, 1, 0)
end

local function buildTombInstance(player: Player, tombData: any, origin: Vector3): TombInstance
	local ownerId = player.UserId
	local tier    = tombData.Tier or 1
	local rooms   = TIER_ROOMS[tier] or TIER_ROOMS[1]

	local tombsFolder = getTombsFolder()
	local existing    = tombsFolder:FindFirstChild(tostring(ownerId))
	if existing then existing:Destroy() end

	local folder = Instance.new("Folder")
	folder.Name = tostring(ownerId); folder.Parent = tombsFolder

	local marker = Instance.new("Part")
	marker.Name = "Origin"; marker.Anchored = true; marker.CanCollide = false
	marker.Transparency = 1; marker.Size = Vector3.new(1, 1, 1)
	marker.Position = origin; marker.Parent = folder

	local spawnPos    = origin + Vector3.new(0, PLAYER_SPAWN_HEIGHT, 0)
	local roomSpacing = 50

	for i, roomId in ipairs(rooms) do
		if tombData.UnlockedRooms and not tombData.UnlockedRooms[roomId] then continue end
		loadRoom(roomId, origin + Vector3.new((i - 1) * roomSpacing, 0, 0), folder)
	end

	-- Spawn guardians
	if guardianAIService and tombData.Guardians then
		local barracksRoom  = folder:FindFirstChild("GuardianBarracks")
		local barrackOrigin = barracksRoom and barracksRoom.PrimaryPart
			and barracksRoom.PrimaryPart.Position
			or origin + Vector3.new(roomSpacing, 0, 0)

		for slotIndexStr, guardianId in pairs(tombData.Guardians) do
			local slotIndex = tonumber(slotIndexStr) or 1
			local slotPos   = barracksRoom
				and getSlotPosition(barracksRoom, slotIndex, barrackOrigin)
				or barrackOrigin + Vector3.new(slotIndex * 6, 0, 0)
			guardianAIService.SpawnGuardian(ownerId, guardianId, slotIndex, slotPos, tier)
		end
	end

	print(string.format("[TombWorldService] Built Tier-%d tomb for %s.", tier, player.Name))
	return {
		ownerId = ownerId, folder = folder, origin = origin,
		tier = tier, spawnPosition = spawnPos,
		invitedPlayers = {}, previousPosition = {},
	}
end

local function teleportCharTo(player: Player, pos: Vector3)
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then root.CFrame = CFrame.new(pos) end
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

function TombWorldService.TeleportIn(player: Player)
	assert(initialized, "[TombWorldService] Not initialized.")
	local data = playerDataService.GetData(player)
	if not data then return end

	local tombData = data.TombData
	if not tombData or (tombData.Tier or 0) < 1 then
		if tombBaseService and tombBaseService.OnFirstPortalEnter then
			tombBaseService.OnFirstPortalEnter(player)
		end
		data     = playerDataService.GetData(player)
		tombData = data and data.TombData
		if not tombData then return end
	end

	local ownerId = player.UserId
	local inst    = instances[ownerId]

	if not inst or inst.tier ~= (tombData.Tier or 1) then
		local origin = inst and inst.origin or nextOrigin()
		inst         = buildTombInstance(player, tombData, origin)
		instances[ownerId] = inst
	end

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then inst.previousPosition[ownerId] = root.Position end

	task.wait(0.1)
	teleportCharTo(player, inst.spawnPosition)

	if guardianRemotes then
		pcall(function()
			guardianRemotes.GetEvent("TombEntered"):FireClient(player, {
				tombTier = inst.tier, ownerId = ownerId,
			})
		end)
	end

	print(string.format("[TombWorldService] %s entered Tier-%d tomb.", player.Name, inst.tier))
end

function TombWorldService.TeleportOut(player: Player)
	assert(initialized, "[TombWorldService] Not initialized.")
	local ownerId   = player.UserId
	local returnPos = OVERWORLD_SPAWN

	for _, inst in pairs(instances) do
		local prev = inst.previousPosition[ownerId]
		if prev then
			returnPos = prev
			inst.previousPosition[ownerId] = nil
			if inst.ownerId ~= ownerId then inst.invitedPlayers[ownerId] = nil end
			break
		end
	end

	teleportCharTo(player, returnPos)
	print(string.format("[TombWorldService] %s exited tomb.", player.Name))
end

function TombWorldService.OnTombUpgraded(player: Player, newTier: number)
	assert(initialized, "[TombWorldService] Not initialized.")
	local ownerId = player.UserId
	local data    = playerDataService.GetData(player)
	if not data or not data.TombData then return end

	if guardianAIService then guardianAIService.DespawnAllForOwner(ownerId) end

	local origin = instances[ownerId] and instances[ownerId].origin or nextOrigin()
	instances[ownerId] = buildTombInstance(player, data.TombData, origin)

	if guardianRemotes then
		local rooms   = TIER_ROOMS[newTier] or {}
		local prevSet: { [string]: true } = {}
		for _, r in ipairs(TIER_ROOMS[newTier - 1] or {}) do prevSet[r] = true end
		for _, roomId in ipairs(rooms) do
			if not prevSet[roomId] then
				pcall(function()
					guardianRemotes.GetEvent("TombRoomUnlocked"):FireClient(player, {
						roomId = roomId, displayName = roomId:gsub("_", " "),
					})
				end)
			end
		end
	end
end

function TombWorldService.InvitePlayer(owner: Player, guest: Player)
	local inst = instances[owner.UserId]
	if not inst then warn("[TombWorldService] Owner has no active tomb."); return end
	inst.invitedPlayers[guest.UserId] = true
	local char = guest.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then inst.previousPosition[guest.UserId] = root.Position end
	task.wait(0.1)
	teleportCharTo(guest, inst.spawnPosition)
	if guardianRemotes then
		pcall(function()
			guardianRemotes.GetEvent("TombEntered"):FireClient(guest, {
				tombTier = inst.tier, ownerId = inst.ownerId,
			})
		end)
	end
end

function TombWorldService.GetInvitedPlayers(ownerId: number): { Player }
	local inst = instances[ownerId]
	if not inst then return {} end
	local out: { Player } = {}
	for uid in pairs(inst.invitedPlayers) do
		for _, p in ipairs(Players:GetPlayers()) do
			if p.UserId == uid then table.insert(out, p); break end
		end
	end
	return out
end

function TombWorldService.OnPlayerRemoving(player: Player)
	local ownerId = player.UserId
	local inst    = instances[ownerId]
	if inst then
		for guestId in pairs(inst.invitedPlayers) do
			for _, p in ipairs(Players:GetPlayers()) do
				if p.UserId == guestId then TombWorldService.TeleportOut(p); break end
			end
		end
		if guardianAIService then guardianAIService.DespawnAllForOwner(ownerId) end
		if inst.folder and inst.folder.Parent then inst.folder:Destroy() end
		instances[ownerId] = nil
	end
	for _, i in pairs(instances) do
		i.previousPosition[ownerId] = nil
		i.invitedPlayers[ownerId]   = nil
	end
end

function TombWorldService.IsInsideTomb(player: Player): boolean
	local ownerId = player.UserId
	for _, inst in pairs(instances) do
		if inst.ownerId == ownerId then
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (root.Position - inst.origin).Magnitude < 500 then return true end
		end
		if inst.previousPosition[ownerId] then return true end
	end
	return false
end

function TombWorldService.GetInstance(ownerId: number): any?
	return instances[ownerId]
end

--------------------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------------

function TombWorldService.Init(pds: any, tbs: any, gas: any, gr: any)
	assert(pds, "[TombWorldService] PlayerDataService required.")
	assert(tbs, "[TombWorldService] TombBaseService required.")
	playerDataService = pds; tombBaseService = tbs
	guardianAIService = gas; guardianRemotes = gr
	initialized       = true
	getTombsFolder()
	Players.PlayerRemoving:Connect(TombWorldService.OnPlayerRemoving)
	print("[TombWorldService] Initialized.")
end

return TombWorldService
