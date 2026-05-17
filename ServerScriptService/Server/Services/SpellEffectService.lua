--!strict
--------------------------------------------------------------------------------
-- GhostyRPG | SpellEffectService.lua
-- ServerScriptService/Server/Services/SpellEffectService.lua
-- Phase 6: applies concrete spell effects (damage/heal/DoT/AoE/Shield/Buff/Debuff).
-- Intentionally separated from AbilityService so boss AI can also cast.
-- BOOT: SpellEffectService.Init(PlayerDataService, StatsService, AbilityRemotes)
--------------------------------------------------------------------------------

local Players         = game:GetService("Players")
local SpellEffectService = {}

local BASE_CRIT_CHANCE  = 0.05
local CRIT_MULTIPLIER   = 2.0
local DOT_TICK_INTERVAL = 2

local playerDataService: any = nil
local statsService      : any = nil
local abilityRemotes    : any = nil
local initialized             = false

local activeDots: { [string]: { [string]: any } } = {}

local function assertInit()
	assert(initialized, "[SpellEffectService] Must call Init() before use.")
end

local function getStats(player: Player): { [string]: any }
	if statsService and statsService.GetStats then
		local ok, s = pcall(statsService.GetStats, player)
		if ok and type(s) == "table" then return s end
	end
	local data = playerDataService.GetData(player)
	return (data and data.Stats) or {}
end

local function getData(player: Player): { [string]: any }?
	return playerDataService and playerDataService.GetData(player)
end

local function currentHP(data: { [string]: any }): number
	return (type(data.CurrentHealth) == "number" and data.CurrentHealth) or 0
end

local function maxHP(data: { [string]: any }): number
	local s = data.Stats
	if type(s) == "table" and type(s.MaxHealth) == "number" then return s.MaxHealth end
	return 100
end

local function spellPower(stats: { [string]: any }): number
	return (type(stats.SpellPower) == "number" and stats.SpellPower) or 0
end

local function attackPower(stats: { [string]: any }): number
	return (type(stats.AttackPower) == "number" and stats.AttackPower) or 0
end

local function rollCrit(stats: { [string]: any }): (boolean, number)
	local cc = BASE_CRIT_CHANCE + ((type(stats.CritChance) == "number") and stats.CritChance or 0)
	if math.random() < math.clamp(cc, 0, 1) then return true, CRIT_MULTIPLIER end
	return false, 1.0
end

local function calcDamage(stats: { [string]: any }, power: number, damageType: string?): number
	local stat = (damageType == "Physical") and attackPower(stats) or spellPower(stats)
	return math.max(1, math.floor(power * (stat + 10)))
end

local function calcHeal(stats: { [string]: any }, power: number): number
	return math.max(1, math.floor(power * (spellPower(stats) + 10)))
end

local function applyHPDelta(target: Player, delta: number, source: Player?): (number, boolean)
	local data = getData(target)
	if not data then return 0, false end
	local hp    = currentHP(data)
	local mxHP  = maxHP(data)
	local newHP = math.clamp(hp + delta, 0, mxHP)
	local actual = math.abs(newHP - hp)
	data.CurrentHealth = newHP
	playerDataService.ScheduleSave(target)
	return actual, newHP <= 0
end

local function broadcastCast(caster: Player | string, abilityId: string, targetPlayer: Player?)
	if not abilityRemotes then return end
	pcall(function()
		local evt = abilityRemotes.GetEvent("AbilityCast")
		evt:FireAllClients({
			casterName = (type(caster) == "string") and caster or (caster :: Player).Name,
			abilityId  = abilityId,
			targetName = targetPlayer and targetPlayer.Name or nil,
		})
	end)
end

local function playersInRange(origin: Vector3, range: number, exclude: Player?): { Player }
	local result: { Player } = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p == exclude then continue end
		local char = p.Character
		if not char then continue end
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - origin).Magnitude <= range then
			table.insert(result, p)
		end
	end
	return result
end

local function startDotLoop()
	task.spawn(function()
		while true do
			task.wait(DOT_TICK_INTERVAL)
			for key, dot in pairs(activeDots) do
				local target: Player = dot.target
				if not target or not target.Parent then activeDots[key] = nil; continue end
				local delta = dot.isDot and -dot.tickAmount or dot.tickAmount
				local _, died = applyHPDelta(target, delta, dot.source)
				dot.ticksLeft -= 1
				if died or dot.ticksLeft <= 0 then activeDots[key] = nil end
			end
		end
	end)
end

function SpellEffectService.Init(pds: any, ss: any, ar: any)
	if initialized then warn("[SpellEffectService] Init called more than once; ignoring."); return end
	assert(pds and pds.GetData,   "[SpellEffectService] PlayerDataService required.")
	assert(pds.ScheduleSave,       "[SpellEffectService] PlayerDataService.ScheduleSave required.")
	assert(ss,                     "[SpellEffectService] StatsService required.")
	playerDataService = pds; statsService = ss; abilityRemotes = ar
	initialized = true; startDotLoop()
	print("[SpellEffectService] Initialized.")
end

export type EffectPayload = {
	abilityId: string, effectType: string, power: number,
	damageType: string?, dotDuration: number?, aoeRange: number?,
	buffDuration: number?, buffStat: string?, buffAmount: number?,
}

function SpellEffectService.Apply(
	caster: Player, target: Player?, payload: EffectPayload
): { success: boolean, damage: number?, heal: number?, isCrit: boolean? }
	assertInit()
	local casterStats = getStats(caster)
	local et = payload.effectType

	if et == "Damage" then
		if not target then return { success = false } end
		local base = calcDamage(casterStats, payload.power, payload.damageType)
		local isCrit, mult = rollCrit(casterStats)
		local actual, _ = applyHPDelta(target, -math.floor(base * mult), caster)
		broadcastCast(caster, payload.abilityId, target)
		return { success = true, damage = actual, isCrit = isCrit }

	elseif et == "Heal" then
		if not target then return { success = false } end
		local base = calcHeal(casterStats, payload.power)
		local isCrit, mult = rollCrit(casterStats)
		local actual, _ = applyHPDelta(target, math.floor(base * mult), caster)
		broadcastCast(caster, payload.abilityId, target)
		return { success = true, heal = actual, isCrit = isCrit }

	elseif et == "DoT" then
		if not target then return { success = false } end
		local dur   = payload.dotDuration or 12
		local ticks = math.max(1, math.floor(dur / DOT_TICK_INTERVAL))
		local total = calcDamage(casterStats, payload.power, payload.damageType)
		local key   = string.format("%d_%s_%d", target.UserId, payload.abilityId, os.clock())
		activeDots[key] = { target = target, source = caster, tickAmount = math.max(1, math.floor(total / ticks)), ticksLeft = ticks, isDot = true, abilityId = payload.abilityId }
		broadcastCast(caster, payload.abilityId, target)
		return { success = true, damage = total }

	elseif et == "HoT" then
		if not target then return { success = false } end
		local dur   = payload.dotDuration or 12
		local ticks = math.max(1, math.floor(dur / DOT_TICK_INTERVAL))
		local total = calcHeal(casterStats, payload.power)
		local key   = string.format("%d_%s_%d", target.UserId, payload.abilityId, os.clock())
		activeDots[key] = { target = target, source = caster, tickAmount = math.max(1, math.floor(total / ticks)), ticksLeft = ticks, isDot = false, abilityId = payload.abilityId }
		broadcastCast(caster, payload.abilityId, target)
		return { success = true, heal = total }

	elseif et == "AoE" then
		local range = payload.aoeRange or 10
		local char  = caster.Character
		local root  = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then return { success = false } end
		local targets  = playersInRange(root.Position, range, caster)
		local base     = calcDamage(casterStats, payload.power, payload.damageType)
		local isCrit, mult = rollCrit(casterStats)
		local final    = math.floor(base * mult)
		local totalDmg = 0
		for _, t in ipairs(targets) do
			local actual, _ = applyHPDelta(t, -final, caster)
			totalDmg += actual
		end
		broadcastCast(caster, payload.abilityId, nil)
		return { success = true, damage = totalDmg, isCrit = isCrit }

	elseif et == "Shield" then
		local tgt = target or caster
		local data = getData(tgt)
		if not data then return { success = false } end
		local amount = math.floor(calcDamage(casterStats, payload.power, nil))
		data.ShieldHP = ((type(data.ShieldHP) == "number") and data.ShieldHP or 0) + amount
		playerDataService.ScheduleSave(tgt)
		broadcastCast(caster, payload.abilityId, tgt)
		return { success = true, heal = amount }

	elseif et == "Buff" then
		local tgt = target or caster
		local data = getData(tgt)
		if not data then return { success = false } end
		if type(data.ActiveBuffs) ~= "table" then data.ActiveBuffs = {} end
		table.insert(data.ActiveBuffs, {
			abilityId = payload.abilityId, stat = payload.buffStat or "AttackPower",
			amount = payload.buffAmount or payload.power, expiresAt = os.time() + (payload.buffDuration or 30),
			sourceId = caster.UserId,
		})
		playerDataService.ScheduleSave(tgt)
		if statsService and statsService.Recalculate then pcall(statsService.Recalculate, tgt) end
		broadcastCast(caster, payload.abilityId, tgt)
		return { success = true }

	elseif et == "Debuff" then
		if not target then return { success = false } end
		local data = getData(target)
		if not data then return { success = false } end
		if type(data.ActiveDebuffs) ~= "table" then data.ActiveDebuffs = {} end
		table.insert(data.ActiveDebuffs, {
			abilityId = payload.abilityId, stat = payload.buffStat or "Armor",
			amount = -(payload.buffAmount or payload.power), expiresAt = os.time() + (payload.buffDuration or 10),
			sourceId = caster.UserId,
		})
		playerDataService.ScheduleSave(target)
		if statsService and statsService.Recalculate then pcall(statsService.Recalculate, target) end
		broadcastCast(caster, payload.abilityId, target)
		return { success = true }

	elseif et == "Taunt" then
		broadcastCast(caster, payload.abilityId, target)
		return { success = true }

	elseif et == "ResourceGain" then
		local data = getData(caster)
		if not data then return { success = false } end
		local maxRes = (data.Stats and data.Stats.MaxResource) or 100
		data.CurrentResource = math.clamp((data.CurrentResource or 0) + math.floor(maxRes * payload.power), 0, maxRes)
		playerDataService.ScheduleSave(caster)
		broadcastCast(caster, payload.abilityId, nil)
		return { success = true }

	else
		warn("[SpellEffectService] Unknown effectType:", et)
		return { success = false }
	end
end

function SpellEffectService.ClearEffects(player: Player)
	for key, dot in pairs(activeDots) do
		if dot.target == player then activeDots[key] = nil end
	end
end

return SpellEffectService
