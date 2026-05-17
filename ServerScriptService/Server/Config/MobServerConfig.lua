--!strict
-- MobServerConfig.lua  —  ServerScriptService/Server/Config/MobServerConfig.lua
-- Server-only mob reward data. Phase 4: new overworld, elites, Mistwood dungeon mobs.

local MobServerConfig = {}

export type LootEntry = { itemId:string, minAmount:number, maxAmount:number, chance:number }
export type ServerMobDefinition = { mobId:string, exp:number, gold:number, loot:{ LootEntry } }

local SERVER_MOBS: { [string]: ServerMobDefinition } = {
	-- Phase 2/3 originals
	mob_ghost_slime          = { mobId="mob_ghost_slime",          exp=25,   gold=5,   loot={ {itemId="item_mistleaf",         minAmount=1,maxAmount=2,chance=0.60}, {itemId="item_health_potion",      minAmount=1,maxAmount=1,chance=0.20} } },
	mob_grave_goblin         = { mobId="mob_grave_goblin",         exp=75,   gold=15,  loot={ {itemId="item_goblin_dagger",    minAmount=1,maxAmount=1,chance=0.10}, {itemId="item_health_potion",      minAmount=1,maxAmount=2,chance=0.30} } },
	mob_restless_skeleton    = { mobId="mob_restless_skeleton",    exp=150,  gold=30,  loot={ {itemId="item_bone_fragment",    minAmount=1,maxAmount=3,chance=0.75}, {itemId="item_mana_potion",        minAmount=1,maxAmount=1,chance=0.35}, {itemId="item_iron_guard_vest",minAmount=1,maxAmount=1,chance=0.05} } },
	-- Phase 4 overworld
	mob_phantom_wolf         = { mobId="mob_phantom_wolf",         exp=200,  gold=35,  loot={ {itemId="item_spectral_fang",   minAmount=1,maxAmount=1,chance=0.40}, {itemId="item_ghost_pelt",         minAmount=1,maxAmount=1,chance=0.25}, {itemId="item_health_potion",minAmount=1,maxAmount=1,chance=0.20} } },
	mob_crypt_revenant       = { mobId="mob_crypt_revenant",       exp=320,  gold=60,  loot={ {itemId="item_revenant_shard",  minAmount=1,maxAmount=2,chance=0.55}, {itemId="item_bone_fragment",      minAmount=1,maxAmount=3,chance=0.70}, {itemId="item_shadow_cloth_wrap",minAmount=1,maxAmount=1,chance=0.08} } },
	mob_mist_sprite          = { mobId="mob_mist_sprite",          exp=260,  gold=45,  loot={ {itemId="item_mist_essence",    minAmount=1,maxAmount=2,chance=0.65}, {itemId="item_mana_potion",        minAmount=1,maxAmount=2,chance=0.30} } },
	mob_bone_archer          = { mobId="mob_bone_archer",          exp=230,  gold=40,  loot={ {itemId="item_bone_arrow",      minAmount=3,maxAmount=8,chance=0.80}, {itemId="item_bone_fragment",      minAmount=1,maxAmount=2,chance=0.55} } },
	mob_cursed_treant        = { mobId="mob_cursed_treant",        exp=480,  gold=80,  loot={ {itemId="item_cursed_bark",     minAmount=1,maxAmount=3,chance=0.75}, {itemId="item_mistleaf",           minAmount=2,maxAmount=4,chance=0.50}, {itemId="item_health_potion",minAmount=1,maxAmount=1,chance=0.25} } },
	mob_wraith               = { mobId="mob_wraith",               exp=550,  gold=95,  loot={ {itemId="item_wraith_essence",  minAmount=1,maxAmount=2,chance=0.60}, {itemId="item_spectral_binding",   minAmount=1,maxAmount=1,chance=0.15}, {itemId="item_mana_potion",minAmount=1,maxAmount=2,chance=0.35} } },
	-- Phase 4 elites
	mob_elite_grave_goblin_shaman = { mobId="mob_elite_grave_goblin_shaman", exp=600,  gold=120, loot={ {itemId="item_shaman_totem",     minAmount=1,maxAmount=1,chance=0.30}, {itemId="item_goblin_dagger",    minAmount=1,maxAmount=1,chance=0.20}, {itemId="item_mana_potion",minAmount=2,maxAmount=3,chance=0.60}, {itemId="item_health_potion",minAmount=2,maxAmount=3,chance=0.60} } },
	mob_elite_skeleton_knight     = { mobId="mob_elite_skeleton_knight",     exp=900,  gold=180, loot={ {itemId="item_knight_pauldrons", minAmount=1,maxAmount=1,chance=0.25}, {itemId="item_iron_guard_vest",  minAmount=1,maxAmount=1,chance=0.15}, {itemId="item_bone_fragment",minAmount=3,maxAmount=6,chance=0.80}, {itemId="item_health_potion",minAmount=2,maxAmount=4,chance=0.70} } },
	mob_elite_phantom_alpha       = { mobId="mob_elite_phantom_alpha",       exp=1200, gold=230, loot={ {itemId="item_alpha_fang",       minAmount=1,maxAmount=1,chance=0.35}, {itemId="item_ghost_pelt",       minAmount=1,maxAmount=2,chance=0.45}, {itemId="item_spectral_fang",minAmount=1,maxAmount=2,chance=0.55} } },
	mob_elite_crypt_lich          = { mobId="mob_elite_crypt_lich",          exp=1800, gold=350, loot={ {itemId="item_lich_phylactery",   minAmount=1,maxAmount=1,chance=0.40}, {itemId="item_wraith_essence",   minAmount=2,maxAmount=3,chance=0.65}, {itemId="item_spectral_binding",minAmount=1,maxAmount=2,chance=0.50}, {itemId="item_mana_potion",minAmount=3,maxAmount=5,chance=0.80} } },
	-- Phase 4 Mistwood Depths dungeon
	mob_mistwood_shambler    = { mobId="mob_mistwood_shambler",    exp=380,  gold=65,  loot={ {itemId="item_cursed_bark",     minAmount=1,maxAmount=2,chance=0.70}, {itemId="item_mist_essence",       minAmount=1,maxAmount=1,chance=0.45} } },
	mob_root_snare           = { mobId="mob_root_snare",           exp=220,  gold=30,  loot={ {itemId="item_mistleaf",        minAmount=2,maxAmount=4,chance=0.85}, {itemId="item_cursed_bark",        minAmount=1,maxAmount=1,chance=0.30} } },
	mob_mistwood_dryad       = { mobId="mob_mistwood_dryad",       exp=440,  gold=75,  loot={ {itemId="item_dryad_tear",      minAmount=1,maxAmount=1,chance=0.50}, {itemId="item_mist_essence",       minAmount=1,maxAmount=2,chance=0.60} } },
	mob_root_guardian        = { mobId="mob_root_guardian",        exp=2400, gold=400, loot={ {itemId="item_guardian_heartwood",minAmount=1,maxAmount=1,chance=1.00},{itemId="item_mistwood_staff",    minAmount=1,maxAmount=1,chance=0.30}, {itemId="item_health_potion",minAmount=3,maxAmount=5,chance=1.00} } },
	mob_heart_of_mistwood    = { mobId="mob_heart_of_mistwood",    exp=6000, gold=900, loot={ {itemId="item_heartwood_core",  minAmount=1,maxAmount=1,chance=1.00}, {itemId="item_mistwood_crown",     minAmount=1,maxAmount=1,chance=0.45}, {itemId="item_sturdy_helmet",minAmount=1,maxAmount=1,chance=0.35}, {itemId="item_mana_potion",minAmount=3,maxAmount=5,chance=1.00} } },
}

for mobId, entry in pairs(SERVER_MOBS) do
	for _, le in ipairs(entry.loot) do
		if le.minAmount > le.maxAmount then error(string.format("[MobServerConfig] '%s'/'%s': minAmount>maxAmount",mobId,le.itemId),2) end
		if le.chance<0 or le.chance>1   then error(string.format("[MobServerConfig] '%s'/'%s': chance out of [0,1]",mobId,le.itemId),2) end
	end
end

function MobServerConfig.GetServerMob(mobId:string): ServerMobDefinition? return SERVER_MOBS[mobId] end
function MobServerConfig.GetExp(mobId:string):number   local e=SERVER_MOBS[mobId]; return if e then e.exp  else 0 end
function MobServerConfig.GetGold(mobId:string):number  local e=SERVER_MOBS[mobId]; return if e then e.gold else 0 end
function MobServerConfig.GetLootTable(mobId:string):{LootEntry} local e=SERVER_MOBS[mobId]; return if e then e.loot else {} end
function MobServerConfig.GetAll():{[string]:ServerMobDefinition} return SERVER_MOBS end
return MobServerConfig
