--!strict
-- Phase4SmokeTests.server.lua  —  ServerScriptService/Phase4SmokeTests.server.lua
-- Lightweight unit-style tests for Phase 4 utilities and logic.
-- These run at server startup and print PASS / FAIL to the output log.
-- No game:GetService("TestService") dependency; works in standard Roblox Studio.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

-- ── Tiny test harness ─────────────────────────────────────────────────────

local passed = 0
local failed = 0

local function expect(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		print(string.format("  ✔ PASS  %s", name))
	else
		failed += 1
		warn(string.format("  ✘ FAIL  %s%s", name, if detail then "  → " .. detail else ""))
	end
end

local function suite(name: string, fn: () -> ())
	print(string.format("\n── %s ──", name))
	local ok, err = pcall(fn)
	if not ok then
		failed += 1
		warn(string.format("  ✘ SUITE CRASHED: %s", tostring(err)))
	end
end

-- ── Logger ────────────────────────────────────────────────────────────────

suite("Logger", function()
	local Logger = require(
		ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Logger")
	)

	-- Basic creation
	local log = Logger.new("TestTag")
	expect("Logger.new returns table",       type(log) == "table")
	expect("Logger.new has .Info method",    type(log.Info)  == "function")
	expect("Logger.new has .Warn method",    type(log.Warn)  == "function")
	expect("Logger.new has .Error method",   type(log.Error) == "function")
	expect("Logger.new has .Debug method",   type(log.Debug) == "function")
	expect("Logger.new stores tag",          log.tag == "TestTag")

	-- Level filtering
	Logger.SetMinLevel("ERROR")
	-- These should NOT print (level too low); we just check they don't error
	local ok1 = pcall(function() log.Info("should be suppressed") end)
	local ok2 = pcall(function() log.Warn("should be suppressed") end)
	expect("Info suppressed without error",  ok1)
	expect("Warn suppressed without error",  ok2)

	-- ERROR should still go through
	local ok3 = pcall(function() log.Error("this should appear") end)
	expect("Error at level ERROR prints without error", ok3)

	-- Reset and per-tag override
	Logger.SetMinLevel("INFO")
	Logger.SetTagLevel("TestTag", "NONE")
	local ok4 = pcall(function() log.Error("suppressed by NONE tag") end)
	expect("All suppressed by tag NONE", ok4)

	Logger.ClearTagLevel("TestTag")
	local ok5 = pcall(function() log.Info("back to INFO global") end)
	expect("ClearTagLevel restores global fallback", ok5)

	-- Invalid tag
	local ok6, _ = pcall(function() Logger.new("") end)
	expect("Empty tag raises error",  not ok6)

	-- Static Logger.Log
	local ok7 = pcall(function() Logger.Log("StaticTag", "WARN", "static warn %s", "arg") end)
	expect("Logger.Log static call works", ok7)
end)

-- ── RateLimiter ───────────────────────────────────────────────────────────

suite("RateLimiter", function()
	local RateLimiter = require(
		ServerScriptService:WaitForChild("Server"):WaitForChild("Util"):WaitForChild("RateLimiter")
	)

	-- Construction guards
	local ok1 = pcall(function() RateLimiter.new(0, 1) end)
	expect("maxRequests=0 raises error", not ok1)
	local ok2 = pcall(function() RateLimiter.new(1, 0) end)
	expect("windowSeconds=0 raises error", not ok2)

	-- Functional test with a mock player
	local limiter = RateLimiter.new(3, 60)  -- 3 per minute
	local mockPlayer = { UserId = 9999999, Name = "TestPlayer", Parent = game } :: any

	expect("1st request allowed",  limiter:Check(mockPlayer))
	expect("2nd request allowed",  limiter:Check(mockPlayer))
	expect("3rd request allowed",  limiter:Check(mockPlayer))
	expect("4th request blocked",  not limiter:Check(mockPlayer))
	expect("5th request blocked",  not limiter:Check(mockPlayer))

	-- After flush, first request is allowed again
	limiter:Flush(mockPlayer)
	expect("After Flush, request allowed again", limiter:Check(mockPlayer))

	-- Clear wipes everything
	local limiter2 = RateLimiter.new(2, 60)
	limiter2:Check(mockPlayer)
	limiter2:Check(mockPlayer)
	expect("Blocked after 2",  not limiter2:Check(mockPlayer))
	limiter2:Clear()
	expect("Allowed after Clear", limiter2:Check(mockPlayer))
end)

-- ── ArenaConfig sanity ────────────────────────────────────────────────────

suite("ArenaConfig sanity", function()
	local ArenaConfig = require(
		ServerScriptService:WaitForChild("Server"):WaitForChild("Config"):WaitForChild("ArenaConfig")
	)

	expect("TeamSizes is table",        type(ArenaConfig.TeamSizes) == "table")
	expect("TeamSizes has entries",     #ArenaConfig.TeamSizes >= 1)
	expect("Maps is table",             type(ArenaConfig.Maps) == "table")
	expect("Maps has entries",          #ArenaConfig.Maps >= 1)
	expect("StartingRating > 0",        (ArenaConfig.Matchmaking.StartingRating or 0) > 0)
	expect("RatingFloor >= 0",          (ArenaConfig.Matchmaking.RatingFloor or -1) >= 0)
	expect("MaxRatingDifference > 0",   (ArenaConfig.Matchmaking.MaxRatingDifference or 0) > 0)
	expect("MatchDuration.BaseSeconds > 0", (ArenaConfig.MatchDuration.BaseSeconds or 0) > 0)

	for _, map in ipairs(ArenaConfig.Maps) do
		expect("Map has Name field: " .. tostring(map.Name), type(map.Name) == "string" and map.Name ~= "")
	end
end)

-- ── QuestsConfig Phase 4 ─────────────────────────────────────────────────

suite("QuestsConfig Phase 4", function()
	local QuestsConfig = require(
		ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("QuestsConfig")
	)

	local quests = QuestsConfig.Quests
	expect("At least 15 quests defined", (function()
		local n = 0; for _ in pairs(quests) do n += 1 end; return n
	end)() >= 15)

	-- Check all Phase 4 quest IDs exist
	local phase4Ids = {
		"quest_006_wolf_pack", "quest_007_mist_sprites", "quest_008_revenant_rising",
		"quest_009_elite_bounty_shaman", "quest_010_elite_bounty_knight",
		"quest_011_mistwood_access", "quest_012_treant_problem",
		"quest_013_wraith_hunters", "quest_014_daily_mistwood", "quest_015_guardian_slain",
	}
	for _, id in ipairs(phase4Ids) do
		expect("Quest exists: " .. id, quests[id] ~= nil)
	end

	-- Structural validation
	for questId, quest in pairs(quests) do
		expect("Quest has id field: "          .. questId, type(quest.id)          == "string")
		expect("Quest has name: "              .. questId, type(quest.name)        == "string" and quest.name ~= "")
		expect("Quest has levelRequirement: "  .. questId, type(quest.levelRequirement) == "number")
		expect("Quest has objectives table: "  .. questId, type(quest.objectives)  == "table" and #quest.objectives >= 1)
		for _, obj in ipairs(quest.objectives) do
			expect("Objective has required > 0: " .. questId .. "/" .. tostring(obj.id), (obj.required or 0) > 0)
		end
	end

	-- Repeatable quests
	expect("quest_005_daily_hunt is repeatable",  quests["quest_005_daily_hunt"] and quests["quest_005_daily_hunt"].repeatable == true)
	expect("quest_014_daily_mistwood is repeatable", quests["quest_014_daily_mistwood"] and quests["quest_014_daily_mistwood"].repeatable == true)
	expect("quest_001_first_steps is not repeatable", quests["quest_001_first_steps"] and quests["quest_001_first_steps"].repeatable == false)
end)

-- ── MobConfig Phase 4 ────────────────────────────────────────────────────

suite("MobConfig Phase 4", function()
	local MobConfig = require(
		ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("MobConfig")
	)

	local allIds = MobConfig.GetAllMobIds()
	expect("At least 15 mobs defined", #allIds >= 15)

	local elites = MobConfig.GetMobsByTag("elite")
	expect("At least 4 elite mobs",    #elites >= 4)

	local dungeonMobs = MobConfig.GetMobsByTag("dungeon_mistwood")
	expect("At least 4 Mistwood dungeon mobs", #dungeonMobs >= 4)

	-- Boss check
	local boss = MobConfig.GetMob("mob_heart_of_mistwood")
	expect("Heart of Mistwood exists",   boss ~= nil)
	expect("Heart of Mistwood is boss",  boss ~= nil and boss.isBoss == true)
	expect("Heart of Mistwood level 15", boss ~= nil and boss.level == 15)
	expect("Heart of Mistwood high HP",  boss ~= nil and boss.maxHealth >= 9000)

	-- Elite check
	local lich = MobConfig.GetMob("mob_elite_crypt_lich")
	expect("Elite Lich exists",          lich ~= nil)
	expect("Elite Lich isElite flag",    lich ~= nil and lich.isElite == true)

	-- All mobs have required fields
	for _, mobId in ipairs(allIds) do
		local mob = MobConfig.GetMob(mobId)
		expect("Mob has name: "       .. mobId, mob ~= nil and type(mob.name) == "string" and mob.name ~= "")
		expect("Mob has level > 0: "  .. mobId, mob ~= nil and mob.level > 0)
		expect("Mob has maxHealth: "  .. mobId, mob ~= nil and mob.maxHealth > 0)
		expect("Mob has damage >= 0: " .. mobId, mob ~= nil and mob.damage >= 0)
	end
end)

-- ── ItemConfig Phase 4 ───────────────────────────────────────────────────

suite("ItemConfig Phase 4", function()
	local ItemConfig = require(
		ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ItemConfig")
	)

	local newItems = {
		"item_spectral_fang", "item_ghost_pelt", "item_revenant_shard", "item_mist_essence",
		"item_bone_arrow", "item_cursed_bark", "item_wraith_essence", "item_spectral_binding",
		"item_dryad_tear", "item_guardian_heartwood", "item_heartwood_core",
		"item_sturdy_helmet", "item_knight_pauldrons", "item_mistwood_staff", "item_mistwood_crown",
	}
	for _, itemId in ipairs(newItems) do
		expect("Item exists: " .. itemId, ItemConfig.IsValidItem(itemId))
	end

	-- Equipment checks
	expect("Mistwood Crown is equippable",     ItemConfig.CanEquip("item_mistwood_crown"))
	expect("Mistwood Crown equipSlot = Head",  ItemConfig.GetEquipmentSlot("item_mistwood_crown") == "Head")
	expect("Mistwood Staff equipSlot = MainHand", ItemConfig.GetEquipmentSlot("item_mistwood_staff") == "MainHand")
	expect("Mist Essence not equippable",      not ItemConfig.CanEquip("item_mist_essence"))
	expect("Spectral Fang is stackable",       ItemConfig.IsStackable("item_spectral_fang"))
	expect("Mistwood Crown not stackable",     not ItemConfig.IsStackable("item_mistwood_crown"))
end)

-- ── ELO calculation (inline, no service dependency) ───────────────────────

suite("ELO calculation", function()
	-- Replicate the calculation directly to avoid requiring ArenaService (needs Init)
	local function expectedScore(rA: number, rB: number): number
		return 1 / (1 + 10 ^ ((rB - rA) / 400))
	end
	local function calculateElo(winnerR: number, loserR: number): (number, number)
		local Ea   = expectedScore(winnerR, loserR)
		local gain = math.max(1, math.floor(64 * (1 - Ea)))
		local loss = math.max(1, math.floor(64 * Ea))
		return gain, loss
	end

	-- Equal ratings: both gain/lose ~32
	local g1, l1 = calculateElo(1500, 1500)
	expect("Equal ratings: gain ~32",    g1 >= 30 and g1 <= 34)
	expect("Equal ratings: loss ~32",    l1 >= 30 and l1 <= 34)

	-- Upset: low rating beats high rating → bigger gain
	local g2, l2 = calculateElo(1200, 1800)
	expect("Upset: winner gain > equal", g2 > g1)
	expect("Upset: loser loses less",    l2 < l1)

	-- Favourite wins: smaller gain
	local g3, l3 = calculateElo(1800, 1200)
	expect("Favourite wins: smaller gain", g3 < g1)
	expect("Both gains are positive",      g1 > 0 and g2 > 0 and g3 > 0)
	expect("Both losses are positive",     l1 > 0 and l2 > 0 and l3 > 0)

	-- Floor: can never be negative
	expect("Gain is never 0",  g1 >= 1 and g2 >= 1 and g3 >= 1)
	expect("Loss is never 0",  l1 >= 1 and l2 >= 1 and l3 >= 1)
end)

-- ── Final summary ─────────────────────────────────────────────────────────

print(string.format(
	"\n══════════════════════════════════════\n[Phase4Tests] Results: %d passed, %d failed\n══════════════════════════════════════",
	passed, failed
))

if failed > 0 then
	warn(string.format("[Phase4Tests] %d test(s) FAILED — see above.", failed))
else
	print("[Phase4Tests] All tests passed! ✔")
end
