--!strict
-- The only inbound RemoteEvent/RemoteFunction boundary for the GhostyRPG MVP layer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SharedRemotes = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
local ClassRemotes = require(SharedRemotes:WaitForChild("ClassRemotes"))
local DungeonRemotes = require(SharedRemotes:WaitForChild("DungeonRemotes"))
local PartyRemotes  = require(SharedRemotes:WaitForChild("PartyRemotes"))
local ArenaRemotes  = require(SharedRemotes:WaitForChild("ArenaRemotes"))
local RateLimiter   = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Util"):WaitForChild("RateLimiter"))
local ClassConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ClassConfig"))
local DungeonConfig = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Config"):WaitForChild("DungeonConfig"))

-- Lazy-loaded so Boot can require ServerHandlers before MobAIService finishes Init
local _mobAIService: any = nil
local function getMobAI(): any?
	if _mobAIService then return _mobAIService end
	local ok, svc = pcall(function()
		return require(ServerScriptService:WaitForChild("Server"):WaitForChild("Services"):WaitForChild("MobAIService"))
	end)
	if ok then _mobAIService = svc end
	return _mobAIService
end

local MAX_ABILITY_RANGE = 40  -- studs; abilities beyond this are rejected


local ServerHandlers = {}

local initialized = false
local connections: { RBXScriptConnection } = {}

local defaultClassByRole = {
	Tank = "Warrior",
	Healer = "Priest",
	DPS = "Mage",
}

local function connect(signal: RBXScriptSignal, callback: (...any) -> ())
	table.insert(connections, signal:Connect(callback))
end

local function fireToPlayers(remote: RemoteEvent, players: { Player }, payload: any)
	for _, player in ipairs(players) do
		if player.Parent == Players then
			remote:FireClient(player, payload)
		end
	end
end

local function rejectAbility(player: Player, code: string, message: string)
	DungeonRemotes.GetEvent("AbilityRejected"):FireClient(player, {
		ok = false,
		code = code,
		message = message,
	})
end

local function getPlayerData(playerDataService: any, player: Player): any?
	if playerDataService and type(playerDataService.GetData) == "function" then
		return playerDataService.GetData(player)
	end
	return nil
end

local function classCanUseRole(className: string, roleName: string): boolean
	local classData = ClassConfig[className]
	if type(classData) ~= "table" or type(classData.AvailableRoles) ~= "table" then
		return false
	end
	for _, allowedRole in ipairs(classData.AvailableRoles) do
		if allowedRole == roleName then
			return true
		end
	end
	return false
end

local function ensureClassForRole(classService: any, playerDataService: any, player: Player, roleName: string): (boolean, string?)
	local data = getPlayerData(playerDataService, player)
	if type(data) ~= "table" then
		return false, "Player data is not loaded yet."
	end
	if type(data.SelectedClass) == "string" and data.SelectedClass ~= "" and classCanUseRole(data.SelectedClass, roleName) then
		return true, nil
	end
	local className = defaultClassByRole[roleName]
	if not className then
		return false, "No default class is mapped for role " .. tostring(roleName) .. "."
	end
	if type(data.SelectedClass) == "string" and data.SelectedClass ~= "" and data.SelectedClass ~= className then
		if type(data.Settings) ~= "table" then
			data.Settings = {}
		end
		local previousResetFlag = data.Settings.ResetClassAllowed
		data.Settings.ResetClassAllowed = true
		local switched, switchReason = classService.SelectClass(player, className)
		data.Settings.ResetClassAllowed = previousResetFlag
		if not switched then
			return false, switchReason or "Unable to switch class for that role."
		end
		return true, nil
	end
	local ok, reason = classService.SelectClass(player, className)
	if not ok then
		return false, reason or "Unable to select a default class."
	end
	return true, nil
end

local function serializeDungeonList(): { any }
	local list = {}
	for dungeonId, dungeon in pairs(DungeonConfig.Dungeons or {}) do
		table.insert(list, {
			id = dungeonId,
			name = dungeon.name or dungeon.displayName or dungeonId,
			minLevel = dungeon.minLevel or 1,
			maxPlayers = dungeon.maxPlayers or DungeonConfig.Defaults.MaxPlayers,
			difficulties = dungeon.difficulties or { "Normal" },
			timeLimit = dungeon.timeLimit or DungeonConfig.Defaults.TimeLimit,
		})
	end
	table.sort(list, function(a, b)
		if (a.minLevel or 0) ~= (b.minLevel or 0) then
			return (a.minLevel or 0) < (b.minLevel or 0)
		end
		return tostring(a.id) < tostring(b.id)
	end)
	return list
end

function ServerHandlers.Init(deps: { [string]: any })
	if initialized then
		warn("[ServerHandlers] Init called more than once; ignoring duplicate call.")
		return
	end

	local playerDataService = deps.PlayerDataService
	local classService = deps.ClassService
	local queueService = deps.QueueService
	local combatService = deps.CombatService

	assert(playerDataService, "ServerHandlers.Init requires PlayerDataService.")
	assert(classService, "ServerHandlers.Init requires ClassService.")
	assert(queueService, "ServerHandlers.Init requires QueueService.")
	assert(combatService, "ServerHandlers.Init requires CombatService.")

	connect(ClassRemotes.GetEvent("SelectClass").OnServerEvent, function(player: Player, className: any)
		if type(className) ~= "string" then
			ClassRemotes.GetEvent("ClassSelected"):FireClient(player, {
				ok = false,
				code = "INVALID_CLASS",
				message = "className must be a string.",
			})
			return
		end
		local ok, reason = classService.SelectClass(player, className)
		local message = reason
		if not message then
			message = if ok then "Class selected." else "Class selection failed."
		end
		ClassRemotes.GetEvent("ClassSelected"):FireClient(player, {
			ok = ok,
			code = if ok then "OK" else "CLASS_REJECTED",
			message = message,
			className = if ok then className else nil,
		})
	end)

	connect(ClassRemotes.GetEvent("SelectRole").OnServerEvent, function(player: Player, roleName: any)
		if type(roleName) ~= "string" then
			ClassRemotes.GetEvent("RoleSelected"):FireClient(player, {
				ok = false,
				code = "INVALID_ROLE",
				message = "roleName must be a string.",
			})
			return
		end

		local classOk, classReason = ensureClassForRole(classService, playerDataService, player, roleName)
		if not classOk then
			ClassRemotes.GetEvent("RoleSelected"):FireClient(player, {
				ok = false,
				code = "CLASS_REQUIRED",
				message = classReason or "Select a class before choosing a role.",
			})
			return
		end

		local ok, reason = classService.SelectRole(player, roleName)
		local message = reason
		if not message then
			message = if ok then "Role selected." else "Role selection failed."
		end
		ClassRemotes.GetEvent("RoleSelected"):FireClient(player, {
			ok = ok,
			code = if ok then "OK" else "ROLE_REJECTED",
			message = message,
			roleName = if ok then roleName else nil,
		})
		-- Sync Humanoid + push initial data after class+role confirmed
		if ok and deps.CharacterService then
			deps.CharacterService.OnClassSelected(player)
		end
	end)

	connect(DungeonRemotes.GetEvent("JoinQueue").OnServerEvent, function(player: Player, dungeonId: any, difficulty: any)
		local result = queueService.JoinQueue(player, dungeonId, difficulty)
		DungeonRemotes.GetEvent("QueueUpdated"):FireClient(player, result)
	end)

	connect(DungeonRemotes.GetEvent("LeaveQueue").OnServerEvent, function(player: Player)
		local result = queueService.LeaveQueue(player)
		DungeonRemotes.GetEvent("QueueUpdated"):FireClient(player, result)
	end)

	connect(DungeonRemotes.GetEvent("ReadyCheck").OnServerEvent, function(player: Player, ready: any)
		local result = queueService.SetReady(player, ready == true)
		if not result.ok then
			DungeonRemotes.GetEvent("ReadyUpdated"):FireClient(player, result)
		end
	end)

	connect(DungeonRemotes.GetEvent("UseAbility").OnServerEvent, function(player: Player, abilityId: any, targetInfo: any)
		if type(abilityId) ~= "string" or abilityId == "" then
			rejectAbility(player, "INVALID_ABILITY", "abilityId must be a non-empty string.")
			return
		end

		-- ── resolve caster position ───────────────────────────────────────
		local casterChar = player.Character
		local casterRoot = casterChar and casterChar:FindFirstChild("HumanoidRootPart") :: BasePart?

		-- ── build targetContext ───────────────────────────────────────────
		local targetContext: { [string]: any } = {}

		if type(targetInfo) == "table" then
			local targetType = targetInfo.targetType

			if targetType == "mob" then
				-- targetInfo = { targetType = "mob", instanceId = "mob_3" }
				local instanceId = targetInfo.instanceId
				if type(instanceId) == "string" then
					local mobAI = getMobAI()
					local mob = mobAI and mobAI.GetMobByInstanceId(instanceId)
					if mob and mob.model and mob.model.Parent then
						-- Distance check
						if casterRoot then
							local dist = (casterRoot.Position - mob.root.Position).Magnitude
							if dist > MAX_ABILITY_RANGE then
								rejectAbility(player, "OUT_OF_RANGE", "Target is too far away.")
								return
							end
						end
						targetContext.targetModel = mob.model
					else
						rejectAbility(player, "INVALID_TARGET", "Mob not found or already dead.")
						return
					end
				end

			elseif targetType == "player" then
				-- targetInfo = { targetType = "player", userId = 12345 }
				local userId = targetInfo.userId
				if type(userId) == "number" then
					local targetPlayer = Players:GetPlayerByUserId(userId)
					if targetPlayer then
						if casterRoot then
							local tchar = targetPlayer.Character
							local troot = tchar and tchar:FindFirstChild("HumanoidRootPart") :: BasePart?
							if troot and (casterRoot.Position - troot.Position).Magnitude > MAX_ABILITY_RANGE then
								rejectAbility(player, "OUT_OF_RANGE", "Target is too far away.")
								return
							end
						end
						targetContext.targetPlayer = targetPlayer
					end
				end

			end
		elseif type(targetInfo) == "number" then
			-- Legacy: plain userId number (backward-compat with old ClientMain)
			local targetPlayer = Players:GetPlayerByUserId(targetInfo)
			if targetPlayer then
				targetContext.targetPlayer = targetPlayer
			end
		end

		local result = combatService.UseAbility(player, abilityId, targetContext)
		if result.success then
			-- Include effectType so client can colour damage vs heal floating numbers
			local abilityDef = require(
				game:GetService("ReplicatedStorage")
					:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AbilityConfig")
			).GetAbility(abilityId)
			DungeonRemotes.GetEvent("CombatResult"):FireClient(player, {
				ok         = true,
				abilityId  = abilityId,
				amount     = result.amount or 0,
				effectType = abilityDef and abilityDef.effectType or "Damage",
			})
		else
			rejectAbility(player, "ABILITY_REJECTED", result.reason or "Ability rejected.")
		end
	end)

	connect(DungeonRemotes.GetEvent("LootAcknowledge").OnServerEvent, function(_player: Player)
		-- Reserved for a later persistent loot-claim workflow.
	end)

	DungeonRemotes.GetFunction("GetDungeonList").OnServerInvoke = function(_player: Player)
		return serializeDungeonList()
	end

	DungeonRemotes.GetFunction("GetPartyStatus").OnServerInvoke = function(player: Player)
		return queueService.GetPartyStatus(player)
	end

	table.insert(connections, queueService.PartyFormed:Connect(function(players: { Player }, payload: any)
		fireToPlayers(DungeonRemotes.GetEvent("PartyFormed"), players, payload)
	end))

	table.insert(connections, queueService.ReadyUpdated:Connect(function(players: { Player }, payload: any)
		fireToPlayers(DungeonRemotes.GetEvent("ReadyUpdated"), players, payload)
	end))

	table.insert(connections, queueService.RunStarted:Connect(function(players: { Player }, payload: any)
		fireToPlayers(DungeonRemotes.GetEvent("DungeonStateUpdate"), players, payload)
	end))

	table.insert(connections, queueService.QueueFailed:Connect(function(players: { Player }, payload: any)
		fireToPlayers(DungeonRemotes.GetEvent("DungeonFailed"), players, payload)
	end))

	-- ── Party handlers ───────────────────────────────────────────────────
	-- Rate limiter: 10 party actions per 5 seconds per player
	local partyRl = RateLimiter.new(10, 5)

	local function broadcastPartyUpdate(partyService: any, party: any)
		if not party then return end
		local members = {}
		for _, member in ipairs(party.members) do
			local char = member.Character
			local hum  = char and char:FindFirstChildOfClass("Humanoid")
			table.insert(members, {
				userId = member.UserId,
				name   = member.Name,
				hp     = if hum then math.floor(hum.Health)    else 0,
				maxHp  = if hum then math.floor(hum.MaxHealth) else 100,
			})
		end
		local snapshot = { members = members, leaderId = party.leader.UserId }
		for _, m in ipairs(party.members) do
			if m.Parent == Players then
				PartyRemotes.GetEvent("PartyUpdated"):FireClient(m, snapshot)
			end
		end
	end

	local partyService = deps.PartyService
	assert(partyService, "ServerHandlers.Init requires PartyService.")

	connect(PartyRemotes.GetEvent("InvitePlayer").OnServerEvent, function(player: Player, payload: any)
		if not partyRl:Check(player) then return end
		if type(payload) ~= "table" or type(payload.targetName) ~= "string" then return end

		local targetPlayer = Players:FindFirstChild(payload.targetName) :: Player?
		if not targetPlayer then return end

		-- Auto-create party if leader has none
		if not partyService.GetParty(player) then
			partyService.CreateParty(player)
		end

		local result = partyService.InvitePlayer(player, targetPlayer)
		if result.ok and result.data then
			local party = partyService.GetPartyById(result.data.partyId)
			PartyRemotes.GetEvent("InviteReceived"):FireClient(targetPlayer, {
				inviterName = player.Name,
				inviterId   = player.UserId,
				partyId     = result.data.partyId,
			})
			broadcastPartyUpdate(partyService, party)
		end
	end)

	connect(PartyRemotes.GetEvent("AcceptInvite").OnServerEvent, function(player: Player, payload: any)
		if not partyRl:Check(player) then return end
		if type(payload) ~= "table" or type(payload.inviterId) ~= "number" then return end

		local inviter = Players:GetPlayerByUserId(payload.inviterId)
		if not inviter then return end
		local party = partyService.GetParty(inviter)
		if not party then return end

		local result = partyService.AcceptInvite(player, party.id)
		if result.ok then
			broadcastPartyUpdate(partyService, partyService.GetParty(player))
		end
	end)

	connect(PartyRemotes.GetEvent("DeclineInvite").OnServerEvent, function(player: Player, payload: any)
		if not partyRl:Check(player) then return end
		if type(payload) ~= "table" or type(payload.inviterId) ~= "number" then return end
		local inviter = Players:GetPlayerByUserId(payload.inviterId)
		if not inviter then return end
		local party = partyService.GetParty(inviter)
		if not party then return end
		partyService.DeclineInvite(player, party.id)
	end)

	connect(PartyRemotes.GetEvent("KickMember").OnServerEvent, function(player: Player, payload: any)
		if not partyRl:Check(player) then return end
		if type(payload) ~= "table" or type(payload.userId) ~= "number" then return end
		local target = Players:GetPlayerByUserId(payload.userId)
		if not target then return end
		local result = partyService.KickMember(player, target)
		if result.ok then
			-- Notify kicked player
			PartyRemotes.GetEvent("PartyUpdated"):FireClient(target, { members = {}, leaderId = nil })
			-- Refresh remaining members
			local party = partyService.GetParty(player)
			broadcastPartyUpdate(partyService, party)
		end
	end)

	connect(PartyRemotes.GetEvent("LeaveParty").OnServerEvent, function(player: Player, _payload: any)
		if not partyRl:Check(player) then return end
		local party = partyService.GetParty(player)
		local membersCopy = if party then table.clone(party.members) else {}
		local result = partyService.LeaveParty(player)
		if result.ok then
			-- Notify the leaving player
			PartyRemotes.GetEvent("PartyUpdated"):FireClient(player, { members = {}, leaderId = nil })
			-- If party still exists, refresh survivors
			local remainingParty = if result.data and result.data.partyId
				then partyService.GetPartyById(result.data.partyId)
				else nil
			if remainingParty then
				broadcastPartyUpdate(partyService, remainingParty)
			else
				-- Party was disbanded: notify all former members
				for _, m in ipairs(membersCopy) do
					if m ~= player and m.Parent == Players then
						PartyRemotes.GetEvent("PartyUpdated"):FireClient(m, { members = {}, leaderId = nil })
					end
				end
			end
		end
	end)

	connect(PartyRemotes.GetEvent("HPPulse").OnServerEvent, function(player: Player, payload: any)
		-- No rate-limit on HP pulses (low frequency from client)
		if type(payload) ~= "table" then return end
		local party = partyService.GetParty(player)
		if not party or #party.members < 2 then return end
		local hp    = tonumber(payload.hp)    or 0
		local maxHp = tonumber(payload.maxHp) or 100
		local syncPayload = { userId = player.UserId, hp = math.floor(hp), maxHp = math.floor(maxHp) }
		for _, member in ipairs(party.members) do
			if member ~= player and member.Parent == Players then
				PartyRemotes.GetEvent("MemberHPSync"):FireClient(member, syncPayload)
			end
		end
	end)

	-- ── Arena handlers ───────────────────────────────────────────────────
	local arenaRl = RateLimiter.new(5, 3)
	local arenaService = deps.ArenaService
	assert(arenaService, "ServerHandlers.Init requires ArenaService.")

	connect(ArenaRemotes.GetEvent("JoinArenaQueue").OnServerEvent, function(player: Player, payload: any)
		if not arenaRl:Check(player) then return end
		local bracketSize = if type(payload) == "table" then tonumber(payload.bracketSize) else nil
		if not bracketSize then return end
		arenaService.JoinQueue(player, bracketSize)
	end)

	connect(ArenaRemotes.GetEvent("LeaveArenaQueue").OnServerEvent, function(player: Player, _payload: any)
		if not arenaRl:Check(player) then return end
		arenaService.LeaveQueue(player)
	end)


	--------------------------------------------------------------------------------
	-- PHASE 7: GUARDIAN / TOMB WORLD HANDLERS
	--------------------------------------------------------------------------------

	local guardianRemotes = deps.GuardianRemotes
	local guardianAISvc   = deps.GuardianAIService
	local tombWorldSvc    = deps.TombWorldService
	local tombBaseSvc     = deps.TombBaseService

	if guardianRemotes and guardianAISvc and tombWorldSvc then

		local SharedCfg   = game:GetService("ReplicatedStorage")
			:WaitForChild("Shared"):WaitForChild("Config")
		local GuardianCfg = require(SharedCfg:WaitForChild("GuardianConfig"))

		local SLOT_OFFSETS: { Vector3 } = {
			Vector3.new( 0, 0,  0), Vector3.new( 8, 0,  0), Vector3.new(-8, 0,  0),
			Vector3.new( 0, 0,  8), Vector3.new( 0, 0, -8), Vector3.new(12, 0, 12),
			Vector3.new(-12, 0, 12), Vector3.new( 0, 0, 20),
		}

		-- HireGuardian  C→S  { guardianId: string, slotIndex: number }
		connect(guardianRemotes.GetEvent("HireGuardian").OnServerEvent,
			function(player: Player, payload: any)
				if type(payload) ~= "table" then return end
				local guardianId = payload.guardianId
				local slotIndex  = payload.slotIndex
				if type(guardianId) ~= "string" then return end
				if type(slotIndex)  ~= "number"  then return end
				slotIndex = math.clamp(math.floor(slotIndex), 1, 8)

				local def = GuardianCfg.Get(guardianId)
				if not def then return end

				local data = deps.PlayerDataService.GetData(player)
				if not data then return end
				local tombData = data.TombData
				if not tombData then return end
				local tombTier = tombData.Tier or 0

				local function reject(reason: string)
					pcall(function()
						guardianRemotes.GetEvent("GuardianStatusUpdate"):FireClient(player, {
							action = "error", reason = reason,
						})
					end)
				end

				if tombTier < def.minTombTier    then reject("TombTierTooLow");  return end
				if (data.Gold or 0) < def.hireCost then reject("NotEnoughGold"); return end

				if not tombData.Guardians then tombData.Guardians = {} end
				if tombData.Guardians[tostring(slotIndex)] then reject("SlotOccupied"); return end

				-- Commit
				data.Gold = (data.Gold or 0) - def.hireCost
				tombData.Guardians[tostring(slotIndex)] = guardianId
				deps.PlayerDataService.ScheduleSave(player)

				-- Spawn NPC if player is currently inside their tomb
				if tombWorldSvc.IsInsideTomb(player) then
					local inst = tombWorldSvc.GetInstance(player.UserId)
					if inst then
						local barracks   = inst.folder:FindFirstChild("GuardianBarracks")
						local barrOrigin = barracks and barracks.PrimaryPart
							and barracks.PrimaryPart.Position
							or inst.origin + Vector3.new(50, 0, 0)
						local offset  = SLOT_OFFSETS[slotIndex] or Vector3.new(slotIndex * 6, 0, 0)
						local slotPos = barrOrigin + offset + Vector3.new(0, 1, 0)
						guardianAISvc.SpawnGuardian(player.UserId, guardianId, slotIndex, slotPos, tombTier)
					end
				end

				pcall(function()
					guardianRemotes.GetEvent("GuardianStatusUpdate"):FireClient(player, {
						slotIndex  = slotIndex,
						guardianId = guardianId,
						action     = "hired",
					})
				end)
			end
		)

		-- FireGuardian  C→S  { slotIndex: number }
		connect(guardianRemotes.GetEvent("FireGuardian").OnServerEvent,
			function(player: Player, payload: any)
				if type(payload) ~= "table" then return end
				local slotIndex = payload.slotIndex
				if type(slotIndex) ~= "number" then return end
				slotIndex = math.clamp(math.floor(slotIndex), 1, 8)

				local data = deps.PlayerDataService.GetData(player)
				if not data or not data.TombData then return end
				local tombData = data.TombData
				if not tombData.Guardians then return end

				tombData.Guardians[tostring(slotIndex)] = nil
				deps.PlayerDataService.ScheduleSave(player)

				guardianAISvc.DespawnGuardian(player.UserId, slotIndex)

				pcall(function()
					guardianRemotes.GetEvent("GuardianStatusUpdate"):FireClient(player, {
						slotIndex = slotIndex,
						action    = "fired",
					})
				end)
			end
		)

		-- EnterTomb  C→S  {}
		connect(guardianRemotes.GetEvent("EnterTomb").OnServerEvent,
			function(player: Player, _: any)
				pcall(function() tombWorldSvc.TeleportIn(player) end)
			end
		)

		-- ExitTomb  C→S  {}
		connect(guardianRemotes.GetEvent("ExitTomb").OnServerEvent,
			function(player: Player, _: any)
				pcall(function() tombWorldSvc.TeleportOut(player) end)
			end
		)

		-- InviteToTomb  C→S  { targetName: string }
		connect(guardianRemotes.GetEvent("InviteToTomb").OnServerEvent,
			function(player: Player, payload: any)
				if type(payload) ~= "table" then return end
				local targetName = payload.targetName
				if type(targetName) ~= "string" then return end
				if not tombWorldSvc.IsInsideTomb(player) then return end

				local target: Player? = nil
				for _, p in ipairs(Players:GetPlayers()) do
					if p.Name == targetName and p ~= player then
						target = p; break
					end
				end
				if not target then return end

				pcall(function() tombWorldSvc.InvitePlayer(player, target) end)
			end
		)

		-- TombUpgrade  C→S  {}
		connect(guardianRemotes.GetEvent("TombUpgrade").OnServerEvent,
			function(player: Player, _: any)
				if not tombBaseSvc then return end

				local upgradeOk   = false
				local newTier: number? = nil
				local reason      = "Unknown error"

				pcall(function()
					local ok, rsn = tombBaseSvc.UpgradeTomb(player)
					upgradeOk = ok == true
					reason    = tostring(rsn or "")
					if upgradeOk then
						local d = deps.PlayerDataService.GetData(player)
						newTier = d and d.TombData and d.TombData.Tier
					end
				end)

				if upgradeOk and newTier then
					pcall(function() tombWorldSvc.OnTombUpgraded(player, newTier) end)
					pcall(function()
						guardianRemotes.GetEvent("TombUpgradeResult"):FireClient(player, {
							ok = true, newTier = newTier,
						})
					end)
				else
					pcall(function()
						guardianRemotes.GetEvent("TombUpgradeResult"):FireClient(player, {
							ok = false, reason = reason,
						})
					end)
				end
			end
		)

	end -- end Phase 7 guardian handlers


	--------------------------------------------------------------------------------
	-- PHASE 8: RAID HANDLERS
	--------------------------------------------------------------------------------

	local raidSvc     = deps.RaidService
	local bossAISvc   = deps.BossAIService
	local raidRemotes = deps.RaidRemotes

	if raidRemotes and raidSvc then
		local SharedCfg = game:GetService("ReplicatedStorage")
			:WaitForChild("Shared"):WaitForChild("Config")
		local RaidCfg   = require(SharedCfg:WaitForChild("RaidConfig"))  -- loaded in Config now

		-- Wire RaidService signals → client remotes
		raidSvc.RaidStarted:Connect(function(members: any, payload: any)
			for _, p in ipairs(members) do
				if p.Parent == Players then
					pcall(function()
						raidRemotes.GetEvent("RaidStarted"):FireClient(p, payload)
					end)
				end
			end
		end)

		raidSvc.RaidCompleted:Connect(function(members: any, payload: any)
			for _, p in ipairs(members) do
				if p.Parent == Players then
					pcall(function()
						raidRemotes.GetEvent("RaidCompleted"):FireClient(p, payload)
					end)
				end
			end
		end)

		raidSvc.RaidFailed:Connect(function(members: any, payload: any)
			for _, p in ipairs(members) do
				if p.Parent == Players then
					pcall(function()
						raidRemotes.GetEvent("RaidFailed"):FireClient(p, payload)
					end)
				end
			end
		end)

		raidSvc.BossPhaseChanged:Connect(function(members: any, payload: any)
			for _, p in ipairs(members) do
				if p.Parent == Players then
					pcall(function()
						raidRemotes.GetEvent("BossPhaseChanged"):FireClient(p, payload)
					end)
				end
			end
		end)

		raidSvc.BossDied:Connect(function(members: any, payload: any)
			for _, p in ipairs(members) do
				if p.Parent == Players then
					pcall(function()
						raidRemotes.GetEvent("BossDied"):FireClient(p, payload)
					end)
				end
			end
		end)

		-- GetRaidList  InvokeServer → { RaidDef[] }
		local getRaidListFn = raidRemotes.GetFunction("GetRaidList")
		if getRaidListFn then
			getRaidListFn.OnServerInvoke = function(_player: Player): { any }
				local out: { any } = {}
				for _, def in ipairs(RaidCfg.GetAllRaids()) do
					table.insert(out, {
						id          = def.id,
						displayName = def.displayName,
						description = def.description,
						minLevel    = def.minLevel,
						minTombTier = def.minTombTier,
						minRaidSize = def.minRaidSize,
						bossCount   = #def.bosses,
					})
				end
				return out
			end
		end

		-- CreateRaid  C→S  { raidId: string, difficulty: string }
		connect(raidRemotes.GetEvent("CreateRaid").OnServerEvent,
			function(player: Player, payload: any)
				if type(payload) ~= "table" then return end
				local raidId    = payload.raidId
				local difficulty = payload.difficulty
				if type(raidId) ~= "string" or type(difficulty) ~= "string" then return end

				local raidRunId, err = raidSvc.CreateRaid(player, raidId, difficulty)
				if raidRunId then
					local run = raidSvc.GetRaid(raidRunId)
					pcall(function()
						raidRemotes.GetEvent("RaidCreated"):FireClient(player, {
							raidRunId   = raidRunId,
							raidId      = raidId,
							difficulty  = difficulty,
							memberCount = run and #run.members or 1,
						})
					end)
				else
					pcall(function()
						raidRemotes.GetEvent("RaidError"):FireClient(player, {
							code    = "CREATE_FAILED",
							message = err or "Failed to create raid.",
						})
					end)
				end
			end
		)

		-- StartRaid  C→S  { raidRunId: string }
		connect(raidRemotes.GetEvent("StartRaid").OnServerEvent,
			function(player: Player, payload: any)
				if type(payload) ~= "table" then return end
				local raidRunId = payload.raidRunId
				if type(raidRunId) ~= "string" then return end

				-- Only leader can start
				local run = raidSvc.GetRaid(raidRunId)
				if not run or run.leaderUserId ~= player.UserId then
					pcall(function()
						raidRemotes.GetEvent("RaidError"):FireClient(player, {
							code = "NOT_LEADER", message = "Only the raid leader can start the raid.",
						})
					end)
					return
				end

				local ok, err = raidSvc.StartRaid(raidRunId)
				if not ok then
					pcall(function()
						raidRemotes.GetEvent("RaidError"):FireClient(player, {
							code = "START_FAILED", message = err or "Failed to start raid.",
						})
					end)
					return
				end

				-- Spawn bosses if BossAIService is wired
				if bossAISvc then
					local raidDef = RaidCfg.GetRaid(run.raidId)
					if raidDef and type(raidDef.bosses) == "table" then
						local raidFolder = workspace:FindFirstChild("Raids")
						if not raidFolder then
							raidFolder = Instance.new("Folder")
							raidFolder.Name = "Raids"
							raidFolder.Parent = workspace
						end
						local instanceFolder = Instance.new("Folder")
						instanceFolder.Name = raidRunId
						instanceFolder.Parent = raidFolder

						for i, bossConf in ipairs(raidDef.bosses) do
							local yOffset = (string.len(raidRunId) * 7) % 500
						local origin = Vector3.new(i * 80, 1000 + yOffset, i * 80)
							-- Use a stable but unique Y offset per raid to avoid spatial collision
							pcall(function()
								bossAISvc.SpawnBoss(raidRunId, bossConf.id, raidDef, origin, run.difficulty)
							end)
						end
					end
				end
			end
		)

		-- AttackBoss  C→S  { raidRunId, bossId, damage }
		-- In real gameplay damage is computed server-side via CombatService.
		-- This handler accepts a pre-computed damage value from the server pipeline.
		connect(raidRemotes.GetEvent("AttackBoss").OnServerEvent,
			function(player: Player, payload: any)
				if type(payload) ~= "table" then return end
				local raidRunId = payload.raidRunId
				local bossId    = payload.bossId
				local damage    = payload.damage
				if type(raidRunId) ~= "string" or type(bossId) ~= "string" then return end
				if type(damage) ~= "number" or damage <= 0 then return end

				-- Verify player is in this raid
				local run = raidSvc.GetRaid(raidRunId)
				if not run then return end
				local isMember = false
				for _, m in ipairs(run.members) do
					if m.UserId == player.UserId then isMember = true; break end
				end
				if not isMember then return end

				-- Cap damage to prevent exploits: max 50000 per hit from client
				damage = math.min(damage, 50000)

				if bossAISvc then
					pcall(function() bossAISvc.ApplyDamage(raidRunId, bossId, damage) end)
				else
					pcall(function() raidSvc.OnBossDamaged(raidRunId, bossId, damage) end)
				end
			end
		)

		-- LeaveRaid  C→S  {}
		connect(raidRemotes.GetEvent("LeaveRaid").OnServerEvent,
			function(player: Player, _: any)
				local run = raidSvc.GetPlayerRaid(player)
				if not run then return end
				if player.UserId == run.leaderUserId then
					raidSvc.FailRaid(run.raidRunId, string.format("Leader (%s) left.", player.Name))
				end
			end
		)

		-- RecordWipe  C→S  { raidRunId }  — leader triggers after full party death
		connect(raidRemotes.GetEvent("RecordWipe").OnServerEvent,
			function(player: Player, payload: any)
				if type(payload) ~= "table" then return end
				local raidRunId = payload.raidRunId
				if type(raidRunId) ~= "string" then return end
				local run = raidSvc.GetRaid(raidRunId)
				if not run or run.leaderUserId ~= player.UserId then return end
				pcall(function() raidSvc.RecordWipe(raidRunId) end)
			end
		)


	-- ── Phase 8: Class Evolution ──────────────────────────────────────────────

	local evolutionSvc = deps.ClassEvolutionService

	if evolutionSvc then
		-- RF: GetEvolutionOptions  (Client invokes → server returns options table)
		local getOptionsRF = ClassRemotes.GetFunction("GetEvolutionOptions")
		getOptionsRF.OnServerInvoke = function(player: Player)
			local ok, result = pcall(function()
				return evolutionSvc.GetOptions(player)
			end)
			if ok then
				return result
			else
				warn("[ServerHandlers] GetEvolutionOptions error:", result)
				return {}
			end
		end

		-- RE: RequestEvolve  (Client fires → server validates & evolves)
		connect(ClassRemotes.GetEvent("RequestEvolve").OnServerEvent, function(player: Player, payload: any)
			if type(payload) ~= "table" or type(payload.targetClass) ~= "string" then
				ClassRemotes.GetEvent("EvolutionResult"):FireClient(player, {
					ok     = false,
					reason = "Invalid payload.",
				})
				return
			end

			-- Rate-limit: one evolution attempt per 5 seconds
			if not RateLimiter.Check(player, "evolve", 5) then
				ClassRemotes.GetEvent("EvolutionResult"):FireClient(player, {
					ok     = false,
					reason = "Please wait before trying again.",
				})
				return
			end

			local evolOk, evolReason = evolutionSvc.Evolve(player, payload.targetClass)
			ClassRemotes.GetEvent("EvolutionResult"):FireClient(player, {
				ok          = evolOk,
				targetClass = if evolOk then payload.targetClass else nil,
				reason      = evolReason,
			})
		end)
	else
		warn("[ServerHandlers] ClassEvolutionService not provided; evolution remotes inactive.")
	end

	end -- end Phase 8 raid handlers

	initialized = true
	print("[ServerHandlers] Initialized.")
end

function ServerHandlers.Destroy()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
	initialized = false
end

return ServerHandlers