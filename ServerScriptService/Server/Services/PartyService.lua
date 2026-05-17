--!strict
-- Server-authoritative, session-scoped party state for GhostyRPG.
-- Parties are in-memory only; UI remotes can call this service after validating requests server-side.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local PartyValidator = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Validators"):WaitForChild("PartyValidator"))

local PartyService = {}

type Party = {
	id: string,
	leader: Player,
	members: { Player },
	createdAt: number,
}

type Result = {
	ok: boolean,
	code: string,
	message: string,
	data: any?,
}

local parties: { [string]: Party } = {}
local playerParty: { [Player]: string } = {}
local pendingInvites: { [Player]: { [string]: number } } = {}
local playerDataService: any = nil
local initialized = false

local function makeResult(ok: boolean, code: string, message: string, data: any?): Result
	return { ok = ok, code = code, message = message, data = data }
end

local function okResult(message: string?, data: any?): Result
	return makeResult(true, "OK", message or "OK", data)
end

local function failResult(validationResult: any, data: any?): Result
	return makeResult(false, validationResult.code or "ERROR", validationResult.message or "Party operation failed.", data)
end

local function playerName(player: any): string
	local name = if player ~= nil then player.Name else nil
	return if type(name) == "string" then name else "Player"
end

local function generatePartyId(): string
	return "party_" .. HttpService:GenerateGUID(false)
end

local function clearInviteForParty(partyId: string)
	for target, inviteMap in pairs(pendingInvites) do
		inviteMap[partyId] = nil
		if next(inviteMap) == nil then
			pendingInvites[target] = nil
		end
	end
end

local function pruneExpiredInvites(player: Player?)
	if player == nil then
		return
	end
	local inviteMap = pendingInvites[player]
	if not inviteMap then
		return
	end
	local now = os.clock()
	for partyId, expiry in pairs(inviteMap) do
		if now >= expiry or parties[partyId] == nil then
			inviteMap[partyId] = nil
		end
	end
	if next(inviteMap) == nil then
		pendingInvites[player] = nil
	end
end

local function removeMemberFromParty(party: Party, player: Player)
	local members = {}
	for _, member in ipairs(party.members) do
		if member ~= player then
			table.insert(members, member)
		end
	end
	party.members = members
	playerParty[player] = nil
end

local function forgetPlayer(player: Player)
	local partyId = playerParty[player]
	local party = if partyId then parties[partyId] else nil
	if party then
		if party.leader == player then
			PartyService.DisbandParty(partyId)
		else
			removeMemberFromParty(party, player)
		end
	else
		playerParty[player] = nil
	end

	pendingInvites[player] = nil
	for target, inviteMap in pairs(pendingInvites) do
		for invitePartyId in pairs(inviteMap) do
			if parties[invitePartyId] == nil then
				inviteMap[invitePartyId] = nil
			end
		end
		if next(inviteMap) == nil then
			pendingInvites[target] = nil
		end
	end
end

function PartyService.Init(newPlayerDataService: any)
	if initialized then
		warn("[PartyService] Init called more than once; ignoring duplicate call.")
		return
	end
	assert(newPlayerDataService ~= nil, "PartyService.Init requires PlayerDataService.")

	playerDataService = newPlayerDataService
	initialized = true

	Players.PlayerRemoving:Connect(function(player)
		forgetPlayer(player)
	end)

	print("[PartyService] Initialized.")
end

function PartyService.CreateParty(leader: Player): Result
	local validation = PartyValidator.ValidateCreateParty(leader, playerParty)
	if not validation.ok then
		return failResult(validation)
	end

	local partyId = generatePartyId()
	local party: Party = {
		id = partyId,
		leader = leader,
		members = { leader },
		createdAt = os.clock(),
	}
	parties[partyId] = party
	playerParty[leader] = partyId

	return okResult("Party created.", { party = party })
end

function PartyService.InvitePlayer(leader: Player, targetPlayer: Player): Result
	pruneExpiredInvites(targetPlayer)
	local leaderParty = parties[playerParty[leader]]
	local now = os.clock()
	local validation = PartyValidator.ValidateInvite(leader, targetPlayer, leaderParty, playerParty, pendingInvites, now)
	if not validation.ok then
		return failResult(validation)
	end

	if not pendingInvites[targetPlayer] then
		pendingInvites[targetPlayer] = {}
	end
	local expiry = now + PartyValidator.INVITE_EXPIRE_SECONDS
	pendingInvites[targetPlayer][leaderParty.id] = expiry

	return okResult(string.format("Invite sent to %s.", playerName(targetPlayer)), { partyId = leaderParty.id, expiry = expiry })
end

function PartyService.AcceptInvite(player: Player, partyId: string): Result
	pruneExpiredInvites(player)
	local party = parties[partyId]
	local validation = PartyValidator.ValidateAccept(player, partyId, party, playerParty, pendingInvites, os.clock())
	if not validation.ok then
		return failResult(validation)
	end

	pendingInvites[player][partyId] = nil
	if next(pendingInvites[player]) == nil then
		pendingInvites[player] = nil
	end

	table.insert(party.members, player)
	playerParty[player] = partyId

	return okResult(string.format("%s joined the party.", playerName(player)), { party = party })
end

function PartyService.DeclineInvite(player: Player, partyId: string): Result
	pruneExpiredInvites(player)
	local validation = PartyValidator.ValidateDecline(player, partyId, pendingInvites)
	if not validation.ok then
		return failResult(validation)
	end

	pendingInvites[player][partyId] = nil
	if next(pendingInvites[player]) == nil then
		pendingInvites[player] = nil
	end

	return okResult("Invite declined.", { partyId = partyId })
end

function PartyService.LeaveParty(player: Player): Result
	local partyId = playerParty[player]
	local party = if partyId then parties[partyId] else nil
	local validation = PartyValidator.ValidateLeave(player, party)
	if not validation.ok then
		return failResult(validation)
	end

	if party.leader == player then
		return PartyService.DisbandParty(partyId)
	end

	removeMemberFromParty(party, player)
	return okResult(string.format("%s left the party.", playerName(player)), { partyId = partyId, remainingMembers = #party.members })
end

function PartyService.KickMember(leader: Player, targetPlayer: Player): Result
	local partyId = playerParty[leader]
	local party = if partyId then parties[partyId] else nil
	local validation = PartyValidator.ValidateKick(leader, targetPlayer, party)
	if not validation.ok then
		return failResult(validation)
	end

	removeMemberFromParty(party, targetPlayer)
	pendingInvites[targetPlayer] = nil
	return okResult(string.format("%s was kicked from the party.", playerName(targetPlayer)), { partyId = partyId, kicked = targetPlayer })
end

function PartyService.DisbandParty(partyId: string): Result
	local party = parties[partyId]
	if not party then
		return makeResult(false, "INVALID_PARTY", "Party does not exist.", nil)
	end

	local evictedMembers = {}
	for _, member in ipairs(party.members) do
		playerParty[member] = nil
		table.insert(evictedMembers, member)
	end
	parties[partyId] = nil
	clearInviteForParty(partyId)

	return okResult("Party disbanded.", { partyId = partyId, evictedMembers = evictedMembers })
end


function PartyService.CreatePartyFromMembers(leader: Player, members: { Player }): Result
	if typeof(leader) ~= "Instance" or not leader:IsA("Player") then
		return makeResult(false, "INVALID_PLAYER", "Leader must be a Player.", nil)
	end
	if type(members) ~= "table" or #members == 0 then
		return makeResult(false, "INVALID_MEMBERS", "Members must be a non-empty array.", nil)
	end
	if #members > PartyValidator.MAX_PARTY_SIZE then
		return makeResult(false, "PARTY_FULL", string.format("The party is too large (max %d players).", PartyValidator.MAX_PARTY_SIZE), nil)
	end

	local seen: { [Player]: boolean } = {}
	local leaderIncluded = false
	for _, member in ipairs(members) do
		if typeof(member) ~= "Instance" or not member:IsA("Player") then
			return makeResult(false, "INVALID_PLAYER", "Members must contain only Player instances.", nil)
		end
		if seen[member] then
			return makeResult(false, "DUPLICATE_MEMBER", "Members must not contain duplicates.", nil)
		end
		if playerParty[member] ~= nil then
			return makeResult(false, "ALREADY_IN_PARTY", string.format("%s is already in a party.", playerName(member)), nil)
		end
		seen[member] = true
		if member == leader then
			leaderIncluded = true
		end
	end
	if not leaderIncluded then
		return makeResult(false, "LEADER_NOT_INCLUDED", "Leader must be included in members.", nil)
	end

	local partyId = generatePartyId()
	local party: Party = {
		id = partyId,
		leader = leader,
		members = {},
		createdAt = os.clock(),
	}
	for index, member in ipairs(members) do
		party.members[index] = member
		playerParty[member] = partyId
	end
	parties[partyId] = party

	return okResult("Party created from queue.", { party = party })
end
function PartyService.GetParty(player: Player?): Party?
	if player == nil then
		return nil
	end
	local partyId = playerParty[player]
	return if partyId then parties[partyId] else nil
end

function PartyService.GetPartyById(partyId: string?): Party?
	return if type(partyId) == "string" then parties[partyId] else nil
end

function PartyService.IsLeader(player: Player?): boolean
	local party = PartyService.GetParty(player)
	return party ~= nil and party.leader == player
end

function PartyService.GetMembers(partyId: string?): { Player }?
	if type(partyId) ~= "string" then
		return nil
	end
	local party = parties[partyId]
	if not party then
		return nil
	end
	local copy = {}
	for index, member in ipairs(party.members) do
		copy[index] = member
	end
	return copy
end


function PartyService.GetPartyMembers(player: Player?): { Player }?
	local party = PartyService.GetParty(player)
	if not party then
		return nil
	end
	return PartyService.GetMembers(party.id)
end

function PartyService._GetState()
	return {
		parties = parties,
		playerParty = playerParty,
		pendingInvites = pendingInvites,
		playerDataService = playerDataService,
		initialized = initialized,
	}
end

return PartyService
