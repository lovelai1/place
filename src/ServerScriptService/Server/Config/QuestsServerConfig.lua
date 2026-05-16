--!strict
-- Server-only quest rewards and limits. Never replicate this module to clients.

export type ItemRewardDef = {
	itemId: string,
	amount: number,
	chance: number,
}

export type QuestRewardDef = {
	exp: number,
	gold: number,
	items: { ItemRewardDef },
}

local QuestsServerConfig = {}

QuestsServerConfig.MaxActiveQuests = 20
QuestsServerConfig.RepeatableCooldownSeconds = 86400

QuestsServerConfig.Rewards = {
	quest_001_first_steps = {
		exp = 150,
		gold = 25,
		items = { { itemId = "item_health_potion", amount = 2, chance = 1.0 } },
	},

	quest_002_mistleaf_aid = {
		exp = 120,
		gold = 30,
		items = {
			{ itemId = "item_mana_potion", amount = 2, chance = 0.8 },
			{ itemId = "item_mistleaf", amount = 3, chance = 1.0 },
		},
	},

	quest_003_goblin_menace = {
		exp = 600,
		gold = 120,
		items = {
			{ itemId = "item_goblin_dagger", amount = 1, chance = 0.35 },
			{ itemId = "item_health_potion", amount = 3, chance = 1.0 },
		},
	},

	quest_004_dungeon_scout = {
		exp = 900,
		gold = 200,
		items = {
			{ itemId = "item_crypt_key", amount = 1, chance = 1.0 },
			{ itemId = "item_iron_guard_vest", amount = 1, chance = 0.2 },
		},
	},

	quest_005_daily_hunt = {
		exp = 300,
		gold = 75,
		items = {
			{ itemId = "item_bone_fragment", amount = 5, chance = 1.0 },
			{ itemId = "item_health_potion", amount = 1, chance = 0.5 },
		},
	},
}

return QuestsServerConfig
