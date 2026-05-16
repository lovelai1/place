--!strict
-- Module-loading smoke test for GhostyRPG foundations.
-- Does not initialize services, mutate player data, spawn combat, or make network calls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local allPassed = true
local passCount = 0
local failCount = 0
local results: { string } = {}

local function record(label: string, passed: boolean, detail: string?)
	if passed then
		passCount += 1
		table.insert(results, string.format("[PASS] %s", label))
	else
		failCount += 1
		allPassed = false
		table.insert(results, string.format("[FAIL] %s%s", label, if detail then ": " .. detail else ""))
	end
end

local function checkResultShape(result: any, label: string)
	record(label .. " returns table", type(result) == "table")
	if type(result) == "table" then
		record(label .. ".success is boolean", type(result.success) == "boolean")
		if result.success == false then
			record(label .. ".reason is non-empty on failure", type(result.reason) == "string" and #result.reason > 0)
		end
	end
end

local Config = Shared:WaitForChild("Config")
local Validators = Server:WaitForChild("Validators")

local playerDataConfig = require(Config:WaitForChild("PlayerDataConfig") :: ModuleScript)
local itemConfig = require(Config:WaitForChild("ItemConfig") :: ModuleScript)
local abilityConfig = require(Config:WaitForChild("AbilityConfig") :: ModuleScript)
local mobConfig = require(Config:WaitForChild("MobConfig") :: ModuleScript)
require(Config:WaitForChild("QuestsConfig") :: ModuleScript)
local questRemotes = require(Shared:WaitForChild("Remotes"):WaitForChild("QuestRemotes") :: ModuleScript)
local mobServerConfig = require(Server:WaitForChild("Config"):WaitForChild("MobServerConfig") :: ModuleScript)
require(Server:WaitForChild("Config"):WaitForChild("QuestsServerConfig") :: ModuleScript)
require(Validators:WaitForChild("QuestValidator") :: ModuleScript)
require(Validators:WaitForChild("InventoryValidator") :: ModuleScript)
local abilityValidator = require(Validators:WaitForChild("AbilityValidator") :: ModuleScript)
local classValidator = require(Validators:WaitForChild("ClassValidator") :: ModuleScript)
local professionValidator = require(Validators:WaitForChild("ProfessionValidator") :: ModuleScript)
local partyValidator = require(Validators:WaitForChild("PartyValidator") :: ModuleScript)
local dungeonValidator = require(Validators:WaitForChild("DungeonValidator") :: ModuleScript)
local playerDataService = require(Server:WaitForChild("Services"):WaitForChild("PlayerDataService") :: ModuleScript)
local inventoryService = require(Server:WaitForChild("Services"):WaitForChild("InventoryService") :: ModuleScript)
local statsService = require(Server:WaitForChild("Services"):WaitForChild("StatsService") :: ModuleScript)
local combatService = require(Server:WaitForChild("Services"):WaitForChild("CombatService") :: ModuleScript)
local lootService = require(Server:WaitForChild("Services"):WaitForChild("LootService") :: ModuleScript)
local professionService = require(Server:WaitForChild("Services"):WaitForChild("ProfessionService") :: ModuleScript)
local partyService = require(Server:WaitForChild("Services"):WaitForChild("PartyService") :: ModuleScript)
local dungeonService = require(Server:WaitForChild("Services"):WaitForChild("DungeonService") :: ModuleScript)
local mobService = require(Server:WaitForChild("Services"):WaitForChild("MobService") :: ModuleScript)
local classService = require(Server:WaitForChild("Services"):WaitForChild("ClassService") :: ModuleScript)
require(Server:WaitForChild("Services"):WaitForChild("QuestService") :: ModuleScript)

record("QuestRemotes.Ensure", type(questRemotes.Ensure) == "function")
record("QuestRemotes.GetEvent", type(questRemotes.GetEvent) == "function")
record("QuestRemotes.GetFunction", type(questRemotes.GetFunction) == "function")

for _, methodName in ipairs({ "GetAbility", "IsValidAbility", "GetClassAbilities", "CanClassUseAbility", "CanRoleUseAbility" }) do
	record(string.format("AbilityConfig.%s", methodName), type(abilityConfig[methodName]) == "function")
end

for _, methodName in ipairs({ "CanUseAbility", "HasRequiredLevel", "HasRequiredClassAndRole", "HasEnoughResource", "IsOffCooldown" }) do
	record(string.format("AbilityValidator.%s", methodName), type(abilityValidator[methodName]) == "function")
end

for _, methodName in ipairs({ "GetMob", "IsValidMob", "GetMaxHealth", "GetLevel", "GetAll", "GetAllMobIds" }) do
	record(string.format("MobConfig.%s", methodName), type(mobConfig[methodName]) == "function")
end

for _, methodName in ipairs({ "GetServerMob", "GetExp", "GetGold", "GetLootTable", "GetAll" }) do
	record(string.format("MobServerConfig.%s", methodName), type(mobServerConfig[methodName]) == "function")
end

for _, methodName in ipairs({ "Init", "LoadPlayer", "SavePlayer", "ScheduleSave", "GetData", "UpdateData", "IsLoaded", "AddExp", "AddGold", "ReleasePlayer" }) do
	record(string.format("PlayerDataService.%s", methodName), type(playerDataService[methodName]) == "function")
end

for _, methodName in ipairs({ "Init", "AddItem", "RemoveItem", "HasItem", "GetInventory", "EquipItem", "UnequipSlot", "GetEquipment" }) do
	record(string.format("InventoryService.%s", methodName), type(inventoryService[methodName]) == "function")
end

for _, methodName in ipairs({ "IsValidClass", "IsValidRole", "CanSelectClass", "CanSelectRole", "CanClassUseRole" }) do
	record(string.format("ClassValidator.%s", methodName), type(classValidator[methodName]) == "function")
end

for _, methodName in ipairs({ "IsValidProfession", "CanGainExperience", "CanGather", "CanCraft" }) do
	record(string.format("ProfessionValidator.%s", methodName), type(professionValidator[methodName]) == "function")
end

for _, methodName in ipairs({ "ValidateCreateParty", "ValidateInvite", "ValidateAccept", "ValidateDecline", "ValidateLeave", "ValidateKick" }) do
	record(string.format("PartyValidator.%s", methodName), type(partyValidator[methodName]) == "function")
end
record("PartyValidator.MAX_PARTY_SIZE", partyValidator.MAX_PARTY_SIZE == 5)
record("PartyValidator.INVITE_EXPIRE_SECONDS", partyValidator.INVITE_EXPIRE_SECONDS == 60)

for _, methodName in ipairs({ "IsValidDungeon", "IsValidDifficulty", "ValidateRoleComposition", "ValidateLevelRequirements", "CanEnterDungeon", "ValidateRun", "GetRewards" }) do
	record(string.format("DungeonValidator.%s", methodName), type(dungeonValidator[methodName]) == "function")
end
record("DungeonValidator accepts Normal difficulty", dungeonValidator.IsValidDifficulty("Normal").success)
record("DungeonValidator rejects invalid difficulty", not dungeonValidator.IsValidDifficulty("Impossible").success)

for _, methodName in ipairs({ "Init", "Recalculate", "CalculateFromData", "GetStats" }) do
	record(string.format("StatsService.%s", methodName), type(statsService[methodName]) == "function")
end

for _, methodName in ipairs({ "Init", "SelectClass", "SelectRole", "GetClass", "GetRole" }) do
	record(string.format("ClassService.%s", methodName), type(classService[methodName]) == "function")
end

for _, methodName in ipairs({ "Init", "IsInitialized", "UseAbility", "ApplyDamage", "ApplyHeal", "SpendResource", "RestoreResource", "GetCooldowns" }) do
	record(string.format("CombatService.%s", methodName), type(combatService[methodName]) == "function")
end
record("CombatService.IsInitialized() false before Init", combatService.IsInitialized() == false)

for _, methodName in ipairs({ "Init", "SetLootService", "RegisterMob", "UnregisterMob", "ApplyDamage", "KillMob", "GetMobState", "IsRegistered" }) do
	record(string.format("MobService.%s", methodName), type(mobService[methodName]) == "function")
end

for _, methodName in ipairs({ "Init", "IsInitialized", "ValidateLootTable", "RollLoot", "GrantLoot" }) do
	record(string.format("LootService.%s", methodName), type(lootService[methodName]) == "function")
end
record("LootService.IsInitialized() false before Init", lootService.IsInitialized() == false)

for _, methodName in ipairs({ "Init", "AddExperience", "GetProfessionData", "Gather", "Craft" }) do
	record(string.format("ProfessionService.%s", methodName), type(professionService[methodName]) == "function")
end

for _, methodName in ipairs({ "Init", "CreateParty", "InvitePlayer", "AcceptInvite", "DeclineInvite", "LeaveParty", "KickMember", "DisbandParty", "GetParty", "GetPartyById", "IsLeader", "GetMembers", "GetPartyMembers" }) do
	record(string.format("PartyService.%s", methodName), type(partyService[methodName]) == "function")
end
record("PartyService.GetParty(nil)", partyService.GetParty(nil) == nil)
record("PartyService.GetPartyById unknown", partyService.GetPartyById("__ghost__") == nil)
record("PartyService.IsLeader(nil)", partyService.IsLeader(nil) == false)
record("PartyService.GetMembers unknown", partyService.GetMembers("__ghost__") == nil)

for _, methodName in ipairs({ "Init", "CreateRun", "StartRun", "CompleteObjective", "CompleteRun", "FailRun", "GetRun", "GetPlayerRun", "AbandonRun" }) do
	record(string.format("DungeonService.%s", methodName), type(dungeonService[methodName]) == "function")
end
record("DungeonService.GetRun unknown", dungeonService.GetRun("__ghost_run__") == nil)
local failRunOk, failRunSuccess = pcall(dungeonService.FailRun, "__ghost_run__", "smoke")
record("DungeonService.FailRun unknown returns false", failRunOk and failRunSuccess == false)
local getPlayerRunOk = pcall(dungeonService.GetPlayerRun, nil)
record("DungeonService.GetPlayerRun nil errors", not getPlayerRunOk)
local abandonRunOk = pcall(dungeonService.AbandonRun, nil)
record("DungeonService.AbandonRun nil errors", not abandonRunOk)


for _, className in ipairs({ "Warrior", "Paladin", "Mage", "Priest", "Rogue", "Hunter" }) do
	local abilities = abilityConfig.GetClassAbilities(className)
	record(string.format("%s has at least one ability", className), type(abilities) == "table" and #abilities >= 1, string.format("found %d", if type(abilities) == "table" then #abilities else 0))
end

local requiredFields = { "id", "name", "description", "allowedRoles", "requiredLevel", "resourceCost", "cooldown", "globalCooldown", "range", "targetType", "effectType", "power", "threatModifier", "tags" }
local sampleIds = { "WARRIOR_TAUNT", "WARRIOR_SHIELD_SLAM", "PALADIN_HOLY_LIGHT", "PALADIN_CONSECRATION", "MAGE_FIREBALL", "MAGE_MANA_SHIELD", "PRIEST_FLASH_HEAL", "PRIEST_POWER_WORD_SHIELD", "ROGUE_BACKSTAB", "ROGUE_VANISH", "HUNTER_AIMED_SHOT", "HUNTER_RAPID_FIRE", "SHARED_SECOND_WIND" }
for _, abilityId in ipairs(sampleIds) do
	local ability = abilityConfig.GetAbility(abilityId)
	record(string.format("GetAbility(%s)", abilityId), type(ability) == "table")
	if type(ability) == "table" then
		for _, field in ipairs(requiredFields) do
			record(string.format("%s.%s present", abilityId, field), ability[field] ~= nil)
		end
		record(string.format("%s.id matches key", abilityId), ability.id == abilityId)
		record(string.format("%s.allowedRoles non-empty", abilityId), type(ability.allowedRoles) == "table" and #ability.allowedRoles >= 1)
		record(string.format("%s.tags table", abilityId), type(ability.tags) == "table")
	end
end

record("Warrior can use Taunt", abilityConfig.CanClassUseAbility("Warrior", "WARRIOR_TAUNT"))
record("Mage cannot use Taunt", not abilityConfig.CanClassUseAbility("Mage", "WARRIOR_TAUNT"))
record("Warrior cannot use Fireball", not abilityConfig.CanClassUseAbility("Warrior", "MAGE_FIREBALL"))
record("Rogue cannot use Holy Light", not abilityConfig.CanClassUseAbility("Rogue", "PALADIN_HOLY_LIGHT"))
for _, className in ipairs({ "Warrior", "Paladin", "Mage", "Priest", "Rogue", "Hunter" }) do
	record(className .. " can use shared Second Wind", abilityConfig.CanClassUseAbility(className, "SHARED_SECOND_WIND"))
end
record("Tank can use Taunt", abilityConfig.CanRoleUseAbility("Tank", "WARRIOR_TAUNT"))
record("Healer cannot use Taunt", not abilityConfig.CanRoleUseAbility("Healer", "WARRIOR_TAUNT"))
record("Healer can use Flash Heal", abilityConfig.CanRoleUseAbility("Healer", "PRIEST_FLASH_HEAL"))
record("DPS cannot use Flash Heal", not abilityConfig.CanRoleUseAbility("DPS", "PRIEST_FLASH_HEAL"))
record("Unknown ability invalid", not abilityConfig.IsValidAbility("NOT_A_REAL_ABILITY"))

local warriorTank = { Level = 10, SelectedClass = "Warrior", SelectedRole = "Tank", Stats = { Resource = 50, MaxResource = 100, ResourceType = "Rage" } }
local mageDps = { Level = 10, SelectedClass = "Mage", SelectedRole = "DPS", Stats = { Resource = 80, MaxResource = 100, ResourceType = "Mana" } }
local priestHealer = { Level = 10, SelectedClass = "Priest", SelectedRole = "Healer", Stats = { Resource = 100, MaxResource = 100, ResourceType = "Mana" } }
local rogueDps = { Level = 10, SelectedClass = "Rogue", SelectedRole = "DPS", Stats = { Resource = 100, MaxResource = 100, ResourceType = "Energy" } }
local lowLevelMage = { Level = 1, SelectedClass = "Mage", SelectedRole = "DPS", Stats = { Resource = 100, MaxResource = 100, ResourceType = "Mana" } }
local noResourceRogue = { Level = 10, SelectedClass = "Rogue", SelectedRole = "DPS" }

local now = os.clock()
checkResultShape(abilityValidator.HasRequiredLevel(warriorTank, "WARRIOR_TAUNT"), "HasRequiredLevel")
checkResultShape(abilityValidator.HasRequiredClassAndRole(warriorTank, "WARRIOR_TAUNT"), "HasRequiredClassAndRole")
checkResultShape(abilityValidator.HasEnoughResource(warriorTank, "WARRIOR_TAUNT"), "HasEnoughResource")
checkResultShape(abilityValidator.IsOffCooldown("WARRIOR_TAUNT", now, {}), "IsOffCooldown")
checkResultShape(abilityValidator.CanUseAbility(warriorTank, "WARRIOR_TAUNT", now, {}), "CanUseAbility")

record("Warrior Tank can use Taunt", abilityValidator.CanUseAbility(warriorTank, "WARRIOR_TAUNT", now, {}).success)
record("Warrior Tank can use Shield Slam", abilityValidator.CanUseAbility(warriorTank, "WARRIOR_SHIELD_SLAM", now, {}).success)
record("Mage DPS can use Fireball", abilityValidator.CanUseAbility(mageDps, "MAGE_FIREBALL", now, {}).success)
record("Priest Healer can use Flash Heal", abilityValidator.CanUseAbility(priestHealer, "PRIEST_FLASH_HEAL", now, {}).success)
record("Rogue DPS can use Backstab", abilityValidator.CanUseAbility(rogueDps, "ROGUE_BACKSTAB", now, {}).success)
record("Mage DPS can use shared Second Wind", abilityValidator.CanUseAbility(mageDps, "SHARED_SECOND_WIND", now, {}).success)

record("Mage cannot use Warrior Taunt", not abilityValidator.HasRequiredClassAndRole(mageDps, "WARRIOR_TAUNT").success)
record("Wrong role/class rejected", not abilityValidator.HasRequiredClassAndRole(warriorTank, "PRIEST_FLASH_HEAL").success)
record("Low level rejected", not abilityValidator.HasRequiredLevel(lowLevelMage, "MAGE_MANA_SHIELD").success)
record("Missing resource rejected", not abilityValidator.HasEnoughResource(noResourceRogue, "ROGUE_SINISTER_STRIKE").success)
record("Unknown ability rejected", not abilityValidator.CanUseAbility(warriorTank, "NOT_REAL", now, {}).success)

record("Shield Slam cooldown active", not abilityValidator.IsOffCooldown("WARRIOR_SHIELD_SLAM", now, { WARRIOR_SHIELD_SLAM = now - 2 }).success)
record("Shield Slam cooldown expired", abilityValidator.IsOffCooldown("WARRIOR_SHIELD_SLAM", now, { WARRIOR_SHIELD_SLAM = now - 10 }).success)
record("Shield Slam never used", abilityValidator.IsOffCooldown("WARRIOR_SHIELD_SLAM", now, {}).success)
record("GCD active blocks Heroic Strike", not abilityValidator.IsOffCooldown("WARRIOR_HEROIC_STRIKE", now, { _gcd = now - 0.5 }).success)
record("GCD expired allows Heroic Strike", abilityValidator.IsOffCooldown("WARRIOR_HEROIC_STRIKE", now, { _gcd = now - 2.0 }).success)
record("Off-GCD Taunt bypasses GCD", abilityValidator.IsOffCooldown("WARRIOR_TAUNT", now, { _gcd = now - 0.5 }).success)

local originalLevel = warriorTank.Level
local originalResource = warriorTank.Stats.Resource
local cdSnapshot = { WARRIOR_TAUNT = now - 100 }
local originalCooldown = cdSnapshot.WARRIOR_TAUNT
abilityValidator.CanUseAbility(warriorTank, "WARRIOR_TAUNT", now, cdSnapshot)
record("data.Level not mutated", warriorTank.Level == originalLevel)
record("data.Stats.Resource not mutated", warriorTank.Stats.Resource == originalResource)
record("cooldownState not mutated", cdSnapshot.WARRIOR_TAUNT == originalCooldown)

local professionData = { Professions = { Mining = { Level = 1, XP = 0 }, Alchemy = { Level = 1, XP = 0 } } }
record("ProfessionValidator accepts Mining", professionValidator.IsValidProfession("Mining").success)
record("ProfessionValidator rejects Fishing", not professionValidator.IsValidProfession("Fishing").success)
record("ProfessionValidator CanGainExperience succeeds", professionValidator.CanGainExperience(professionData, "Mining", 25).success)
record("ProfessionValidator rejects negative profession XP", not professionValidator.CanGainExperience(professionData, "Mining", -5).success)
record("ProfessionValidator CanGather copper_ore succeeds", professionValidator.CanGather(professionData, "Mining", "copper_ore").success)
record("ProfessionValidator rejects unknown material", not professionValidator.CanGather(professionData, "Mining", "phantom_material").success)
record("ProfessionValidator CanCraft health_potion succeeds", professionValidator.CanCraft(professionData, "Alchemy", "health_potion").success)
record("ProfessionValidator rejects low-level mana_potion", not professionValidator.CanCraft(professionData, "Alchemy", "mana_potion").success)
record("ProfessionValidator rejects wrong-profession recipe", not professionValidator.CanCraft(professionData, "Mining", "health_potion").success)


local fakeLeader = { Name = "Leader" }
local fakeTarget = { Name = "Target" }
local fakeThird = { Name = "Third" }
local fakeParty = { id = "party_test", leader = fakeLeader, members = { fakeLeader } }
local now = os.clock()
record("PartyValidator creates party for free leader", partyValidator.ValidateCreateParty(fakeLeader, {}).ok)
record("PartyValidator rejects duplicate party membership", not partyValidator.ValidateCreateParty(fakeLeader, { [fakeLeader] = "party_test" }).ok)
record("PartyValidator rejects self invite", partyValidator.ValidateInvite(fakeLeader, fakeLeader, fakeParty, { [fakeLeader] = "party_test" }, {}, now).code == "INVITE_TO_SELF")
record("PartyValidator accepts valid invite", partyValidator.ValidateInvite(fakeLeader, fakeTarget, fakeParty, { [fakeLeader] = "party_test" }, {}, now).ok)
record("PartyValidator rejects pending invite", partyValidator.ValidateInvite(fakeLeader, fakeTarget, fakeParty, { [fakeLeader] = "party_test" }, { [fakeTarget] = { party_test = now + 30 } }, now).code == "INVITE_PENDING")
record("PartyValidator accepts invite after expiry", partyValidator.ValidateInvite(fakeLeader, fakeTarget, fakeParty, { [fakeLeader] = "party_test" }, { [fakeTarget] = { party_test = now - 1 } }, now).ok)
record("PartyValidator accepts valid invite acceptance", partyValidator.ValidateAccept(fakeTarget, "party_test", fakeParty, {}, { [fakeTarget] = { party_test = now + 30 } }, now).ok)
record("PartyValidator rejects expired invite acceptance", partyValidator.ValidateAccept(fakeTarget, "party_test", fakeParty, {}, { [fakeTarget] = { party_test = now - 1 } }, now).code == "INVITE_NOT_FOUND")
record("PartyValidator accepts decline with pending invite", partyValidator.ValidateDecline(fakeTarget, "party_test", { [fakeTarget] = { party_test = now + 30 } }).ok)
record("PartyValidator rejects missing decline invite", partyValidator.ValidateDecline(fakeTarget, "party_test", {}).code == "INVITE_NOT_FOUND")
record("PartyValidator accepts member leave", partyValidator.ValidateLeave(fakeLeader, fakeParty).ok)
record("PartyValidator rejects leave without party", partyValidator.ValidateLeave(fakeLeader, nil).code == "NOT_IN_PARTY")
record("PartyValidator rejects self kick", partyValidator.ValidateKick(fakeLeader, fakeLeader, fakeParty).code == "KICK_SELF")
record("PartyValidator rejects non-member kick", partyValidator.ValidateKick(fakeLeader, fakeThird, fakeParty).code == "KICK_NOT_MEMBER")

local validLootTable = { { itemId = "item_health_potion", minAmount = 1, maxAmount = 2, chance = 1 } }
local validLootSnapshot = validLootTable[1].minAmount
record("LootService validates known item loot table", lootService.ValidateLootTable(validLootTable).success)
record("LootService rejects nil loot table", not lootService.ValidateLootTable(nil).success)
record("LootService rejects empty loot table", not lootService.ValidateLootTable({}).success)
record("LootService rejects unknown item", not lootService.ValidateLootTable({ { itemId = "__missing_item__", minAmount = 1, maxAmount = 1, chance = 1 } }).success)
record("LootService rejects invalid minAmount", not lootService.ValidateLootTable({ { itemId = "item_health_potion", minAmount = 0, maxAmount = 1, chance = 1 } }).success)
record("LootService rejects invalid maxAmount", not lootService.ValidateLootTable({ { itemId = "item_health_potion", minAmount = 2, maxAmount = 1, chance = 1 } }).success)
record("LootService rejects invalid chance", not lootService.ValidateLootTable({ { itemId = "item_health_potion", minAmount = 1, maxAmount = 1, chance = 0 } }).success)
local lootRoll = lootService.RollLoot(validLootTable, Random.new(42))
record("LootService.RollLoot succeeds with seeded Random", lootRoll.success and type(lootRoll.items) == "table")
record("LootService.RollLoot includes guaranteed item", lootRoll.success and #lootRoll.items == 1 and lootRoll.items[1].itemId == "item_health_potion")
record("LootService.RollLoot does not mutate source table", validLootTable[1].minAmount == validLootSnapshot)
record("LootService.RollLoot rejects bad rng", not lootService.RollLoot(validLootTable, "not_random").success)
local noPlayer: any = nil
local grantBeforeInit = lootService.GrantLoot(noPlayer, validLootTable)
record("LootService.GrantLoot rejects before Init", not grantBeforeInit.success and type(grantBeforeInit.reason) == "string" and string.find(string.lower(grantBeforeInit.reason), "init", 1, true) ~= nil)

local requiredMobIds = { "mob_ghost_slime", "mob_grave_goblin", "mob_restless_skeleton" }
local requiredMobFields = { "mobId", "name", "level", "maxHealth", "armor", "damage", "attackRange", "aggroRange", "tags", "respawnSeconds" }
for _, mobId in ipairs(requiredMobIds) do
	local mob = mobConfig.GetMob(mobId)
	record(string.format("MobConfig has %s", mobId), type(mob) == "table")
	if type(mob) == "table" then
		for _, field in ipairs(requiredMobFields) do
			record(string.format("%s.%s present", mobId, field), mob[field] ~= nil)
		end
		record(string.format("%s tags table", mobId), type(mob.tags) == "table")
		record(string.format("%s maxHealth positive", mobId), type(mob.maxHealth) == "number" and mob.maxHealth > 0)
		record(string.format("%s GetMaxHealth matches", mobId), mobConfig.GetMaxHealth(mobId) == mob.maxHealth)
		record(string.format("%s GetLevel matches", mobId), mobConfig.GetLevel(mobId) == mob.level)
	end

	local serverMob = mobServerConfig.GetServerMob(mobId)
	record(string.format("MobServerConfig has %s", mobId), type(serverMob) == "table")
	if type(serverMob) == "table" then
		record(string.format("%s exp positive", mobId), type(serverMob.exp) == "number" and serverMob.exp > 0)
		record(string.format("%s gold non-negative", mobId), type(serverMob.gold) == "number" and serverMob.gold >= 0)
		record(string.format("%s loot table", mobId), type(serverMob.loot) == "table")
		for index, loot in ipairs(serverMob.loot) do
			record(string.format("%s loot[%d] item valid", mobId, index), type(loot.itemId) == "string" and itemConfig.IsValidItem(loot.itemId))
			record(string.format("%s loot[%d] amount range valid", mobId, index), type(loot.minAmount) == "number" and type(loot.maxAmount) == "number" and loot.minAmount <= loot.maxAmount)
			record(string.format("%s loot[%d] chance valid", mobId, index), type(loot.chance) == "number" and loot.chance >= 0 and loot.chance <= 1)
		end
	end
end

local fakePart = Instance.new("Part")
record("MobService.IsRegistered false before Init", mobService.IsRegistered(fakePart) == false)
record("MobService.GetMobState nil before Init", mobService.GetMobState(fakePart) == nil)
fakePart:Destroy()

for _, itemId in ipairs({ "item_health_potion", "item_mana_potion", "item_mistleaf", "item_goblin_dagger", "item_crypt_key", "item_iron_guard_vest", "item_bone_fragment", "starter_sword", "starter_staff", "starter_shield", "copper_ore", "empty_vial" }) do
	record(string.format("ItemConfig has %s", itemId), itemConfig.IsValidItem(itemId))
end

local okData, data = pcall(playerDataConfig.DeepCopyDefault)
if okData and type(data) == "table" then
	for _, key in ipairs({ "Version", "Level", "Exp", "Gold", "SelectedClass", "SelectedRole", "CurrentHealth", "CurrentResource", "ResourceType", "Stats", "Inventory", "Equipment", "ActiveQuests", "CompletedQuests", "Professions", "DungeonProgress", "ArenaProfile", "AbilityCooldowns", "Settings" }) do
		record(string.format("PlayerData default has %s", key), data[key] ~= nil)
	end
	record("PlayerData default has Stats.Resource", type(data.Stats) == "table" and type(data.Stats.Resource) == "number")
	record("PlayerData default has Stats.MaxResource", type(data.Stats) == "table" and type(data.Stats.MaxResource) == "number")
	record("PlayerData default has Stats.ResourceType", type(data.Stats) == "table" and type(data.Stats.ResourceType) == "string")
	record("PlayerData default has CurrentHealth", type(data.CurrentHealth) == "number")
	record("PlayerData default has CurrentResource", type(data.CurrentResource) == "number")
	record("PlayerData default has ResourceType", type(data.ResourceType) == "string")
	record("PlayerData default has Mining profession", type(data.Professions.Mining) == "table")
	record("PlayerData default Mining.Level is number", type(data.Professions.Mining.Level) == "number")
	record("PlayerData default Mining.XP is number", type(data.Professions.Mining.XP) == "number")
	record("PlayerData default has Alchemy profession", type(data.Professions.Alchemy) == "table")
	record("PlayerData default Alchemy.Level is number", type(data.Professions.Alchemy.Level) == "number")
	record("PlayerData default Alchemy.XP is number", type(data.Professions.Alchemy.XP) == "number")
else
	record("PlayerDataConfig.DeepCopyDefault", false, "failed or returned non-table")
end
record("PlayerDataConfig.Reconcile", type(playerDataConfig.Reconcile) == "function")
record("PlayerDataConfig.BackFill", type(playerDataConfig.BackFill) == "function")
if type(playerDataConfig.BackFill) == "function" then
	local existing = { CurrentHealth = 42 }
	playerDataConfig.BackFill(existing)
	record("BackFill preserves existing CurrentHealth", existing.CurrentHealth == 42)
	record("BackFill adds CurrentResource", type(existing.CurrentResource) == "number")
	record("BackFill adds AbilityCooldowns", type(existing.AbilityCooldowns) == "table")
end

local fallbackStats = statsService.CalculateFromData({ Level = 1, SelectedClass = "", SelectedRole = "", Equipment = {} })
for _, key in ipairs({ "MaxHealth", "MaxResource", "AttackPower", "Armor", "HP", "MP", "Attack", "Defense", "Speed" }) do
	record(string.format("StatsService fallback has %s", key), type(fallbackStats[key]) == "number")
end

for _, line in ipairs(results) do
	print("[GhostyRPG Smoke] " .. line)
end

if allPassed then
	print(string.format("[GhostyRPG Smoke] All foundation checks passed (%d assertions).", passCount))
else
	warn(string.format("[GhostyRPG Smoke] %d passed, %d failed.", passCount, failCount))
end
