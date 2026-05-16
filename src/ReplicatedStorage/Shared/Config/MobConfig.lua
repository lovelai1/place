--!strict
-- Client-safe mob metadata for GhostyRPG.
-- Keep secret rewards and drop rates in server-only MobServerConfig.

local MobConfig = {}

export type PublicLootHint = {
	itemId: string,
	displayName: string,
}

export type MobDefinition = {
	mobId: string,
	name: string,
	level: number,
	maxHealth: number,
	armor: number,
	damage: number,
	attackRange: number,
	aggroRange: number,
	tags: { string },
	respawnSeconds: number,
	lootTablePublic: { PublicLootHint }?,
}

local MOBS: { [string]: MobDefinition } = {
	mob_ghost_slime = {
		mobId = "mob_ghost_slime",
		name = "Ghost Slime",
		level = 1,
		maxHealth = 60,
		armor = 0,
		damage = 5,
		attackRange = 4,
		aggroRange = 16,
		tags = { "undead", "slime", "overworld" },
		respawnSeconds = 30,
		lootTablePublic = {
			{ itemId = "item_mistleaf", displayName = "Mistleaf" },
			{ itemId = "item_health_potion", displayName = "Health Potion" },
		},
	},

	mob_grave_goblin = {
		mobId = "mob_grave_goblin",
		name = "Grave Goblin",
		level = 3,
		maxHealth = 120,
		armor = 5,
		damage = 12,
		attackRange = 5,
		aggroRange = 20,
		tags = { "goblin", "undead", "overworld" },
		respawnSeconds = 45,
		lootTablePublic = {
			{ itemId = "item_goblin_dagger", displayName = "Grave Goblin Dagger" },
			{ itemId = "item_health_potion", displayName = "Health Potion" },
		},
	},

	mob_restless_skeleton = {
		mobId = "mob_restless_skeleton",
		name = "Restless Skeleton",
		level = 5,
		maxHealth = 200,
		armor = 15,
		damage = 20,
		attackRange = 6,
		aggroRange = 22,
		tags = { "undead", "skeleton", "overworld" },
		respawnSeconds = 60,
		lootTablePublic = {
			{ itemId = "item_bone_fragment", displayName = "Bone Fragment" },
			{ itemId = "item_iron_guard_vest", displayName = "Iron Guard Vest" },
		},
	},
}

function MobConfig.GetMob(mobId: string): MobDefinition?
	return MOBS[mobId]
end

function MobConfig.IsValidMob(mobId: string): boolean
	return MOBS[mobId] ~= nil
end

function MobConfig.GetMaxHealth(mobId: string): number?
	local mob = MOBS[mobId]
	return if mob then mob.maxHealth else nil
end

function MobConfig.GetLevel(mobId: string): number?
	local mob = MOBS[mobId]
	return if mob then mob.level else nil
end

function MobConfig.GetAllMobIds(): { string }
	local ids = {}
	for mobId in pairs(MOBS) do
		table.insert(ids, mobId)
	end
	return ids
end

function MobConfig.GetAll(): { [string]: MobDefinition }
	return MOBS
end

return MobConfig
