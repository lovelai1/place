--!strict
-- Pure, stateless validation for GhostyRPG party operations.
-- No service access, no mutation, and no Roblox-only calls so it can be tested with fake players.

local PartyValidator = {}

PartyValidator.MAX_PARTY_SIZE = 5
PartyValidator.INVITE_EXPIRE_SECONDS = 60
PartyValidator.INVITE_EXPIRE_S = PartyValidator.INVITE_EXPIRE_SECONDS

export type Result = {
	ok: boolean,
	code: string,
	message: string,
}

local function ok(): Result
	return { ok = true, code = "OK", message = "OK" }
end

local function fail(code: string, message: string): Result
	return { ok = false, code = code, message = message }
end

local function isPlayer(value: any): boolean
	-- Intentionally duck-typed: production passes Player instances, tests can pass plain tables.
	return value ~= nil
end

local function hasMember(party: any, player: any): boolean
	if type(party) ~= "table" or type(party.members) ~= "table" then
		return false
	end
	for _, member in ipairs(party.members) do
		if member == player then
			return true
		end
	end
	return false
end

function PartyValidator.ValidateCreateParty(leader: any, playerPartyMap: { [any]: string? }): Result
	if not isPlayer(leader) then
		return fail("INVALID_PLAYER", "Leader must be a valid player.")
	end
	if playerPartyMap[leader] ~= nil then
		return fail("ALREADY_IN_PARTY", "Leader is already in a party.")
	end
	return ok()
end

function PartyValidator.ValidateInvite(leader: any, target: any, leaderParty: any, playerPartyMap: { [any]: string? }, pendingInvites: { [any]: { [string]: number } }, now: number): Result
	if not isPlayer(leader) then
		return fail("INVALID_PLAYER", "Leader must be a valid player.")
	end
	if not isPlayer(target) then
		return fail("INVALID_PLAYER", "Target must be a valid player.")
	end
	if leader == target then
		return fail("INVITE_TO_SELF", "You cannot invite yourself.")
	end
	if type(leaderParty) ~= "table" then
		return fail("NOT_IN_PARTY", "Leader does not have an active party.")
	end
	if leaderParty.leader ~= leader then
		return fail("NOT_LEADER", "Only the party leader can send invites.")
	end
	if type(leaderParty.members) ~= "table" then
		return fail("INVALID_PARTY", "Party is missing its members list.")
	end
	if #leaderParty.members >= PartyValidator.MAX_PARTY_SIZE then
		return fail("PARTY_FULL", string.format("The party is full (max %d players).", PartyValidator.MAX_PARTY_SIZE))
	end
	if hasMember(leaderParty, target) then
		return fail("INVITE_ALREADY_MEMBER", "That player is already in your party.")
	end
	if playerPartyMap[target] ~= nil then
		return fail("INVITE_TARGET_IN_PARTY", "That player is already in another party.")
	end

	local targetInvites = pendingInvites[target]
	local expiry = if targetInvites then targetInvites[leaderParty.id] else nil
	if type(expiry) == "number" and now < expiry then
		return fail("INVITE_PENDING", "An invite to that player is already pending.")
	end

	return ok()
end

function PartyValidator.ValidateAccept(player: any, partyId: string, party: any, playerPartyMap: { [any]: string? }, pendingInvites: { [any]: { [string]: number } }, now: number): Result
	if not isPlayer(player) then
		return fail("INVALID_PLAYER", "Player must be valid.")
	end
	if type(partyId) ~= "string" or partyId == "" or type(party) ~= "table" then
		return fail("INVALID_PARTY", "Party does not exist.")
	end
	if playerPartyMap[player] ~= nil then
		return fail("ALREADY_IN_PARTY", "You are already in a party.")
	end

	local playerInvites = pendingInvites[player]
	local expiry = if playerInvites then playerInvites[partyId] else nil
	if type(expiry) ~= "number" then
		return fail("INVITE_NOT_FOUND", "No pending invite found for that party.")
	end
	if now >= expiry then
		return fail("INVITE_NOT_FOUND", "The invite has expired.")
	end
	if type(party.members) ~= "table" then
		return fail("INVALID_PARTY", "Party is missing its members list.")
	end
	if #party.members >= PartyValidator.MAX_PARTY_SIZE then
		return fail("PARTY_FULL", "The party is now full.")
	end

	return ok()
end

function PartyValidator.ValidateDecline(player: any, partyId: string, pendingInvites: { [any]: { [string]: number } }): Result
	if not isPlayer(player) then
		return fail("INVALID_PLAYER", "Player must be valid.")
	end
	local playerInvites = pendingInvites[player]
	if type(partyId) ~= "string" or partyId == "" or not playerInvites or playerInvites[partyId] == nil then
		return fail("INVITE_NOT_FOUND", "No pending invite found for that party.")
	end
	return ok()
end

function PartyValidator.ValidateLeave(player: any, party: any): Result
	if not isPlayer(player) then
		return fail("INVALID_PLAYER", "Player must be valid.")
	end
	if type(party) ~= "table" then
		return fail("NOT_IN_PARTY", "You are not in a party.")
	end
	return ok()
end

function PartyValidator.ValidateKick(leader: any, target: any, party: any): Result
	if not isPlayer(leader) then
		return fail("INVALID_PLAYER", "Leader must be valid.")
	end
	if not isPlayer(target) then
		return fail("INVALID_PLAYER", "Target must be valid.")
	end
	if type(party) ~= "table" then
		return fail("NOT_IN_PARTY", "You are not in a party.")
	end
	if party.leader ~= leader then
		return fail("NOT_LEADER", "Only the party leader can kick members.")
	end
	if leader == target then
		return fail("KICK_SELF", "You cannot kick yourself; leave or disband the party instead.")
	end
	if not hasMember(party, target) then
		return fail("KICK_NOT_MEMBER", "That player is not in your party.")
	end
	return ok()
end

return PartyValidator
