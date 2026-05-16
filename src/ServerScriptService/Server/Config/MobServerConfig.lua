--!strict
-- Server-only mob reward data for GhostyRPG.
-- Do not require this module from client code; public mob metadata lives in MobConfig.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ItemConfig"))

local MobServerConfig = {}

export type LootEntry = {
	itemId: string,
	minAmount: number,
	maxAmount: number,
	chance: number,
}

export type ServerMobDefinition = {
	mobId: string,
	exp: number,
	gold: number,
	loot: { LootEntry },
}

local SERVER_MOBS: { [string]: ServerMobDefinition } = {
	mob_ghost_slime = {
		mobId = "mob_ghost_slime",
		exp = 25,
		gold = 5,
		loot = {
			{ itemId = "item_mistleaf", minAmount = 1, maxAmount = 2, chance = 0.60 },
			{ itemId = "item_health_potion", minAmount = 1, maxAmount = 1, chance = 0.20 },
		},
	},

	mob_grave_goblin = {
		mobId = "mob_grave_goblin",
		exp = 75,
		gold = 15,
		loot = {
			{ itemId = "item_goblin_dagger", minAmount = 1, maxAmount = 1, chance = 0.10 },
			{ itemId = "item_health_potion", minAmount = 1, maxAmount = 2, chance = 0.30 },
		},
	},

	mob_restless_skeleton = {
		mobId = "mob_restless_skeleton",
		exp = 150,
		gold = 30,
		loot = {
			{ itemId = "item_bone_fragment", minAmount = 1, maxAmount = 3, chance = 0.75 },
			{ itemId = "item_mana_potion", minAmount = 1, maxAmount = 1, chance = 0.35 },
			{ itemId = "item_iron_guard_vest", minAmount = 1, maxAmount = 1, chance = 0.05 },
		},
	},
}

local errors = {}
for mobId, entry in pairs(SERVER_MOBS) do
	for _, lootEntry in ipairs(entry.loot) do
		if not ItemConfig.IsValidItem(lootEntry.itemId) then
			table.insert(errors, string.format("[MobServerConfig] mob '%s' references unknown itemId '%s'", mobId, lootEntry.itemId))
		end
		if lootEntry.minAmount > lootEntry.maxAmount then
			table.insert(errors, string.format("[MobServerConfig] mob '%s' item '%s': minAmount(%d) > maxAmount(%d)", mobId, lootEntry.itemId, lootEntry.minAmount, lootEntry.maxAmount))
		end
		if lootEntry.chance < 0 or lootEntry.chance > 1 then
			table.insert(errors, string.format("[MobServerConfig] mob '%s' item '%s': chance(%.2f) out of [0,1]", mobId, lootEntry.itemId, lootEntry.chance))
		end
	end
end
if #errors > 0 then
	error(table.concat(errors, "\n"), 2)
end

function MobServerConfig.GetServerMob(mobId: string): ServerMobDefinition?
	return SERVER_MOBS[mobId]
end

function MobServerConfig.GetExp(mobId: string): number
	local entry = SERVER_MOBS[mobId]
	return if entry then entry.exp else 0
end

function MobServerConfig.GetGold(mobId: string): number
	local entry = SERVER_MOBS[mobId]
	return if entry then entry.gold else 0
end

function MobServerConfig.GetLootTable(mobId: string): { LootEntry }
	local entry = SERVER_MOBS[mobId]
	return if entry then entry.loot else {}
end

function MobServerConfig.GetAll(): { [string]: ServerMobDefinition }
	return SERVER_MOBS
end

return MobServerConfig
