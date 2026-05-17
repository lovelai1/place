--!strict
-- QuestsServerConfig.lua  —  ServerScriptService/Server/Config/QuestsServerConfig.lua
-- Server-only quest rewards. Phase 4: 10 new quest reward entries.

export type ItemRewardDef = { itemId:string, amount:number, chance:number }
export type QuestRewardDef = { exp:number, gold:number, items:{ItemRewardDef} }

local QuestsServerConfig = {}
QuestsServerConfig.MaxActiveQuests            = 20
QuestsServerConfig.RepeatableCooldownSeconds  = 86400

QuestsServerConfig.Rewards = {
	-- Original
	quest_001_first_steps  = { exp=150,  gold=25,  items={ {itemId="item_health_potion",  amount=2,  chance=1.00} } },
	quest_002_mistleaf_aid = { exp=120,  gold=30,  items={ {itemId="item_mana_potion",    amount=2,  chance=0.80}, {itemId="item_mistleaf",          amount=3,  chance=1.00} } },
	quest_003_goblin_menace= { exp=600,  gold=120, items={ {itemId="item_goblin_dagger",  amount=1,  chance=0.35}, {itemId="item_health_potion",     amount=3,  chance=1.00} } },
	quest_004_dungeon_scout= { exp=900,  gold=200, items={ {itemId="item_crypt_key",      amount=1,  chance=1.00}, {itemId="item_iron_guard_vest",   amount=1,  chance=0.20} } },
	quest_005_daily_hunt   = { exp=300,  gold=75,  items={ {itemId="item_bone_fragment",  amount=5,  chance=1.00}, {itemId="item_health_potion",     amount=1,  chance=0.50} } },
	-- Phase 4
	quest_006_wolf_pack              = { exp=700,   gold=130, items={ {itemId="item_ghost_pelt",          amount=2, chance=1.00}, {itemId="item_health_potion",     amount=2, chance=1.00} } },
	quest_007_mist_sprites           = { exp=650,   gold=110, items={ {itemId="item_mana_potion",         amount=3, chance=1.00}, {itemId="item_mist_essence",      amount=2, chance=0.50} } },
	quest_008_revenant_rising        = { exp=1100,  gold=200, items={ {itemId="item_shadow_cloth_wrap",   amount=1, chance=0.40}, {itemId="item_health_potion",     amount=3, chance=1.00} } },
	quest_009_elite_bounty_shaman    = { exp=1500,  gold=300, items={ {itemId="item_shaman_totem",        amount=1, chance=1.00}, {itemId="item_mana_potion",       amount=3, chance=1.00} } },
	quest_010_elite_bounty_knight    = { exp=2000,  gold=400, items={ {itemId="item_knight_pauldrons",    amount=1, chance=1.00}, {itemId="item_health_potion",     amount=4, chance=1.00} } },
	quest_011_mistwood_access        = { exp=800,   gold=150, items={ {itemId="item_health_potion",       amount=2, chance=1.00} } },
	quest_012_treant_problem         = { exp=1400,  gold=260, items={ {itemId="item_cursed_bark",         amount=5, chance=1.00}, {itemId="item_mana_potion",       amount=2, chance=1.00} } },
	quest_013_wraith_hunters         = { exp=1800,  gold=330, items={ {itemId="item_spectral_binding",    amount=2, chance=0.60}, {itemId="item_mana_potion",       amount=3, chance=1.00} } },
	quest_014_daily_mistwood         = { exp=500,   gold=100, items={ {itemId="item_mist_essence",        amount=3, chance=1.00}, {itemId="item_health_potion",     amount=1, chance=0.60} } },
	quest_015_guardian_slain         = { exp=3500,  gold=600, items={ {itemId="item_guardian_heartwood",  amount=1, chance=1.00}, {itemId="item_mistwood_staff",    amount=1, chance=0.50}, {itemId="item_health_potion", amount=5, chance=1.00} } },
}

return QuestsServerConfig
