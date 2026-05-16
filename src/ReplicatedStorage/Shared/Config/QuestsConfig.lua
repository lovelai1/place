--!strict
-- Public quest definitions for GhostyRPG.
-- Keep rewards out of this module; client can require this data.

export type QuestObjectiveDef = {
	id: string,
	objectiveType: string,
	description: string,
	targetId: string,
	required: number,
}

export type QuestDef = {
	id: string,
	name: string,
	description: string,
	levelRequirement: number,
	prerequisiteQuests: { string },
	repeatable: boolean,
	timeLimit: number?,
	objectives: { QuestObjectiveDef },
}

local QuestsConfig = {}

QuestsConfig.Quests = {
	quest_001_first_steps = {
		id = "quest_001_first_steps",
		name = "First Steps",
		description = "Prove yourself by defeating the first creatures haunting the Ghostwood outskirts.",
		levelRequirement = 1,
		prerequisiteQuests = {},
		repeatable = false,
		objectives = {
			{ id = "obj_kill_slimes", objectiveType = "Kill", description = "Defeat Ghost Slimes", targetId = "mob_ghost_slime", required = 5 },
		},
	},

	quest_002_mistleaf_aid = {
		id = "quest_002_mistleaf_aid",
		name = "Mistleaf Aid",
		description = "Gather mistleaf for the village alchemist before the dusk sickness spreads.",
		levelRequirement = 1,
		prerequisiteQuests = {},
		repeatable = false,
		objectives = {
			{ id = "obj_collect_mistleaf", objectiveType = "Collect", description = "Collect Mistleaf", targetId = "item_mistleaf", required = 10 },
		},
	},

	quest_003_goblin_menace = {
		id = "quest_003_goblin_menace",
		name = "Goblin Menace",
		description = "Drive back the grave-goblins and bring proof of their retreat.",
		levelRequirement = 5,
		prerequisiteQuests = { "quest_001_first_steps" },
		repeatable = false,
		objectives = {
			{ id = "obj_kill_goblins", objectiveType = "Kill", description = "Defeat Grave Goblins", targetId = "mob_grave_goblin", required = 10 },
			{ id = "obj_collect_goblin_charms", objectiveType = "Collect", description = "Collect Goblin Bone Charms", targetId = "item_goblin_bone_charm", required = 5 },
		},
	},

	quest_004_dungeon_scout = {
		id = "quest_004_dungeon_scout",
		name = "Dungeon Scout",
		description = "Find the sealed crypt entrance and report its location to the expedition camp.",
		levelRequirement = 8,
		prerequisiteQuests = { "quest_003_goblin_menace" },
		repeatable = false,
		objectives = {
			{ id = "obj_explore_crypt_gate", objectiveType = "Explore", description = "Discover the Sealed Crypt Gate", targetId = "zone_sealed_crypt_gate", required = 1 },
		},
	},

	quest_005_daily_hunt = {
		id = "quest_005_daily_hunt",
		name = "Daily Hunt: Restless Bones",
		description = "Thin the restless undead wandering beyond the safe road.",
		levelRequirement = 10,
		prerequisiteQuests = {},
		repeatable = true,
		objectives = {
			{ id = "obj_kill_skeletons", objectiveType = "Kill", description = "Defeat Restless Skeletons", targetId = "mob_restless_skeleton", required = 15 },
		},
	},
}

return QuestsConfig
