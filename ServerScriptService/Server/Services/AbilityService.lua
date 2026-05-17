--!strict
--------------------------------------------------------------------------------
-- GhostyRPG | AbilityService.lua
-- ServerScriptService/Server/Services/AbilityService.lua
-- Phase 6: server-authoritative ability orchestrator.
-- PIPELINE: AbilityValidator.CanUseAbility → MagicTierService.CanCastTier
--           → deduct resource → stamp cooldown → SpellEffectService.Apply → CooldownSync
-- BOOT: AbilityService.Init(PlayerDataService, StatsService, SpellEffectService, MagicTierService, AbilityRemotes)
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared         = ReplicatedStorage:WaitForChild("Shared")
local AbilityConfig  = require(Shared:WaitForChild("Config"):WaitForChild("AbilityConfig"))
local AbilityValidator = require(
	game:GetService("ServerScriptService")
		:WaitForChild("Server")
		:WaitForChild("Validators")
		:WaitForChild("AbilityValidator")
)

local AbilityService = {}

local CAST_RATE_LIMIT_SECONDS = 0.2
local GLOBAL_CD_KEY           = "_gcd"

local playerDataService  : any = nil
local statsService        : any = nil
local spellEffectService  : any = nil
local magicTierService    : any = nil
local abilityRemotes      : any = nil
local initialized               = false

local lastCastTime: { [number]: number } = {}

local function assertInit()
	assert(initialized, "[AbilityService] Must call Init() before use.")
end

local function getData(player: Player): { [string]: any }?
	return playerDataService.GetData(player)
end

local function getCooldowns(data: { [string]: any }): { [string]: number }
	if type(data.AbilityCooldowns) ~= "table" then data.AbilityCooldowns = {} end
	return data.AbilityCooldowns
end

local function syncCooldowns(player: Player, cds: { [string]: number })
	if not abilityRemotes then return end
	local now = os.clock()
	local remaining: { [string]: number } = {}
	for id, t in pairs(cds) do
		local ability = AbilityConfig.GetAbility(id)
		if not ability then continue end
		local r = ability.cooldown - (now - t)
		if r > 0 then remaining[id] = r end
	end
	pcall(function()
		abilityRemotes.GetEvent("CooldownSync"):FireClient(player, remaining)
	end)
end

local function deductResource(data: { [string]: any }, resType: string?, cost: number): boolean
	if not resType or cost <= 0 then return true end
	if resType == "RunePower" then
		local charges = (type(data.RuneCharges) == "number") and data.RuneCharges or 6
		if charges < cost then return false end
		data.RuneCharges = charges - cost
		return true
	end
	local cur = (type(data.CurrentResource) == "number") and data.CurrentResource or 0
	if cur < cost then return false end
	data.CurrentResource = cur - cost
	return true
end

local function buildEffectPayload(ability: any): any
	local aoeTypes = { AreaEnemy = true, AreaAlly = true }
	local effectType = ability.effectType
	if aoeTypes[ability.targetType] and effectType == "Damage" then effectType = "AoE" end
	local damageType = "Shadow"
	for _, tag in ipairs(ability.tags or {}) do
		if tag == "Physical" or tag == "Fire" or tag == "Frost" or tag == "Shadow"
			or tag == "Holy" or tag == "Arcane" or tag == "Nature" then
			damageType = tag; break
		end
	end
	return {
		abilityId    = ability.id,
		effectType   = effectType,
		power        = ability.power or 1.0,
		damageType   = damageType,
		dotDuration  = ability.dotDuration,
		aoeRange     = ability.range,
		buffDuration = ability.buffDuration,
		buffStat     = ability.buffStat,
		buffAmount   = ability.buffAmount,
	}
end

local function resolveTarget(targetId: any): Player?
	if type(targetId) ~= "number" then return nil end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == targetId then return p end
	end
	return nil
end

function AbilityService.Cast(player: Player, abilityId: string, targetId: any): boolean
	assertInit()
	local now = os.clock()
	local last = lastCastTime[player.UserId] or 0
	if now - last < CAST_RATE_LIMIT_SECONDS then return false end
	lastCastTime[player.UserId] = now

	local data = getData(player)
	if not data then return false end

	local cds    = getCooldowns(data)
	local result = AbilityValidator.CanUseAbility(data, abilityId, now, cds)
	if not result.success then
		warn(string.format("[AbilityService] Cast rejected for %s (%s): %s", player.Name, abilityId, tostring(result.reason)))
		return false
	end

	local ability = AbilityConfig.GetAbility(abilityId)
	if not ability then return false end

	if ability.minMagicTier and magicTierService then
		if not magicTierService.CanCastTier(player, ability.minMagicTier) then
			warn(string.format("[AbilityService] %s: Magic Tier %d required for %s.", player.Name, ability.minMagicTier, abilityId))
			return false
		end
	end

	if (data.CurrentHealth or 0) <= 0 then return false end

	if not deductResource(data, ability.resourceType, ability.resourceCost) then
		warn(string.format("[AbilityService] %s: insufficient resource for %s.", player.Name, abilityId))
		return false
	end

	cds[abilityId] = now
	if (ability.globalCooldown or 0) > 0 then cds[GLOBAL_CD_KEY] = now end
	playerDataService.ScheduleSave(player)

	local targetPlayer = resolveTarget(targetId)
	if ability.targetType == "Self" then targetPlayer = player end

	local payload = buildEffectPayload(ability)
	local effectResult = spellEffectService.Apply(player, targetPlayer, payload)
	if not effectResult.success then
		warn(string.format("[AbilityService] SpellEffectService.Apply failed for %s / %s.", player.Name, abilityId))
	end

	syncCooldowns(player, cds)
	return true
end

function AbilityService.GetCooldowns(player: Player): { [string]: number }
	assertInit()
	local data = getData(player)
	if not data then return {} end
	local now = os.clock()
	local cds = getCooldowns(data)
	local remaining: { [string]: number } = {}
	for id, t in pairs(cds) do
		local ability = AbilityConfig.GetAbility(id)
		if ability then
			local r = ability.cooldown - (now - t)
			if r > 0 then remaining[id] = r end
		end
	end
	return remaining
end

function AbilityService.ResetCooldowns(player: Player)
	assertInit()
	local data = getData(player)
	if not data then return end
	data.AbilityCooldowns = {}
	playerDataService.ScheduleSave(player)
end

function AbilityService.GetUnlockedAbilities(player: Player): { string }
	assertInit()
	local data = getData(player)
	if not data then return {} end
	local className = data.SelectedClass or ""
	local roleName  = data.SelectedRole  or ""
	local level     = data.Level          or 1
	local magicTier = data.MagicTier      or 1
	local available = AbilityConfig.GetAvailableAbilities(className, roleName, level, magicTier)
	local ids: { string } = {}
	for _, ab in ipairs(available) do table.insert(ids, ab.id) end
	return ids
end

function AbilityService.Init(pds: any, ss: any, ses: any, mts: any, ar: any)
	if initialized then warn("[AbilityService] Init called more than once; ignoring."); return end
	assert(pds and pds.GetData,    "[AbilityService] PlayerDataService required.")
	assert(pds.ScheduleSave,        "[AbilityService] PlayerDataService.ScheduleSave required.")
	assert(ses and ses.Apply,       "[AbilityService] SpellEffectService.Apply required.")

	playerDataService = pds; statsService = ss; spellEffectService = ses
	magicTierService = mts; abilityRemotes = ar
	initialized = true

	if abilityRemotes then
		local castEvent = abilityRemotes.GetEvent("CastAbility")
		castEvent.OnServerEvent:Connect(function(player: Player, abilityId: any, targetId: any)
			if type(abilityId) ~= "string" then return end
			AbilityService.Cast(player, abilityId, targetId)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastCastTime[player.UserId] = nil
	end)

	print("[AbilityService] Initialized.")
end

return AbilityService
