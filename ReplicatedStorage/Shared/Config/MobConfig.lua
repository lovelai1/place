--!strict
-- MobConfig.lua  —  ReplicatedStorage/Shared/Config/MobConfig.lua
-- Client-safe mob metadata for GhostyRPG.
-- Phase 4: 6 new overworld mobs, 4 elite variants, Mistwood dungeon mobs + 2 bosses.

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
	isElite: boolean?,
	isBoss: boolean?,
	lootTablePublic: { PublicLootHint }?,
}

local MOBS: { [string]: MobDefinition } = {

	-- Phase 2/3 originals
	mob_ghost_slime = { mobId="mob_ghost_slime", name="Ghost Slime", level=1, maxHealth=60, armor=0, damage=5, attackRange=4, aggroRange=16, tags={"undead","slime","overworld"}, respawnSeconds=30, lootTablePublic={{ itemId="item_mistleaf", displayName="Mistleaf" },{ itemId="item_health_potion", displayName="Health Potion" }} },
	mob_grave_goblin = { mobId="mob_grave_goblin", name="Grave Goblin", level=3, maxHealth=120, armor=5, damage=12, attackRange=5, aggroRange=20, tags={"goblin","undead","overworld"}, respawnSeconds=45, lootTablePublic={{ itemId="item_goblin_dagger", displayName="Grave Goblin Dagger" },{ itemId="item_health_potion", displayName="Health Potion" }} },
	mob_restless_skeleton = { mobId="mob_restless_skeleton", name="Restless Skeleton", level=5, maxHealth=200, armor=15, damage=20, attackRange=6, aggroRange=22, tags={"undead","skeleton","overworld"}, respawnSeconds=60, lootTablePublic={{ itemId="item_bone_fragment", displayName="Bone Fragment" },{ itemId="item_iron_guard_vest", displayName="Iron Guard Vest" }} },

	-- Phase 4: new overworld mobs
	mob_phantom_wolf = { mobId="mob_phantom_wolf", name="Phantom Wolf", level=7, maxHealth=280, armor=8, damage=28, attackRange=5, aggroRange=28, tags={"beast","spectral","overworld"}, respawnSeconds=55, lootTablePublic={{ itemId="item_spectral_fang", displayName="Spectral Fang" },{ itemId="item_ghost_pelt", displayName="Ghost Pelt" }} },
	mob_crypt_revenant = { mobId="mob_crypt_revenant", name="Crypt Revenant", level=10, maxHealth=420, armor=20, damage=38, attackRange=6, aggroRange=24, tags={"undead","revenant","overworld"}, respawnSeconds=75, lootTablePublic={{ itemId="item_revenant_shard", displayName="Revenant Shard" },{ itemId="item_bone_fragment", displayName="Bone Fragment" },{ itemId="item_shadow_cloth_wrap", displayName="Shadow Cloth Wrap" }} },
	mob_mist_sprite = { mobId="mob_mist_sprite", name="Mist Sprite", level=9, maxHealth=180, armor=5, damage=45, attackRange=12, aggroRange=20, tags={"elemental","mist","overworld"}, respawnSeconds=50, lootTablePublic={{ itemId="item_mist_essence", displayName="Mist Essence" },{ itemId="item_mana_potion", displayName="Mana Potion" }} },
	mob_bone_archer = { mobId="mob_bone_archer", name="Bone Archer", level=8, maxHealth=240, armor=10, damage=32, attackRange=20, aggroRange=30, tags={"undead","skeleton","overworld"}, respawnSeconds=65, lootTablePublic={{ itemId="item_bone_arrow", displayName="Bone Arrow" },{ itemId="item_bone_fragment", displayName="Bone Fragment" }} },
	mob_cursed_treant = { mobId="mob_cursed_treant", name="Cursed Treant", level=12, maxHealth=700, armor=30, damage=44, attackRange=7, aggroRange=18, tags={"plant","cursed","overworld"}, respawnSeconds=120, lootTablePublic={{ itemId="item_cursed_bark", displayName="Cursed Bark" },{ itemId="item_mistleaf", displayName="Mistleaf" }} },
	mob_wraith = { mobId="mob_wraith", name="Wraith", level=14, maxHealth=380, armor=12, damage=55, attackRange=8, aggroRange=26, tags={"undead","spectral","overworld"}, respawnSeconds=90, lootTablePublic={{ itemId="item_wraith_essence", displayName="Wraith Essence" },{ itemId="item_mana_potion", displayName="Mana Potion" },{ itemId="item_spectral_binding", displayName="Spectral Binding" }} },

	-- Phase 4: elite overworld variants
	mob_elite_grave_goblin_shaman = { mobId="mob_elite_grave_goblin_shaman", name="⚡ Goblin Shaman (Elite)", level=6, maxHealth=600, armor=12, damage=40, attackRange=10, aggroRange=26, tags={"goblin","undead","overworld","elite"}, respawnSeconds=180, isElite=true, lootTablePublic={{ itemId="item_shaman_totem", displayName="Shaman Totem" },{ itemId="item_mana_potion", displayName="Mana Potion" }} },
	mob_elite_skeleton_knight = { mobId="mob_elite_skeleton_knight", name="⚡ Skeleton Knight (Elite)", level=10, maxHealth=1100, armor=45, damage=58, attackRange=6, aggroRange=24, tags={"undead","skeleton","overworld","elite"}, respawnSeconds=240, isElite=true, lootTablePublic={{ itemId="item_knight_pauldrons", displayName="Knight Pauldrons" },{ itemId="item_iron_guard_vest", displayName="Iron Guard Vest" }} },
	mob_elite_phantom_alpha = { mobId="mob_elite_phantom_alpha", name="⚡ Phantom Alpha (Elite)", level=13, maxHealth=1400, armor=22, damage=75, attackRange=6, aggroRange=32, tags={"beast","spectral","overworld","elite"}, respawnSeconds=300, isElite=true, lootTablePublic={{ itemId="item_alpha_fang", displayName="Alpha Fang" },{ itemId="item_ghost_pelt", displayName="Ghost Pelt" }} },
	mob_elite_crypt_lich = { mobId="mob_elite_crypt_lich", name="⚡ Crypt Lich (Elite)", level=16, maxHealth=2200, armor=30, damage=90, attackRange=14, aggroRange=28, tags={"undead","lich","overworld","elite"}, respawnSeconds=360, isElite=true, lootTablePublic={{ itemId="item_lich_phylactery", displayName="Lich Phylactery" },{ itemId="item_wraith_essence", displayName="Wraith Essence" }} },

	-- Phase 4: Mistwood Depths dungeon mobs
	mob_mistwood_shambler = { mobId="mob_mistwood_shambler", name="Mistwood Shambler", level=11, maxHealth=500, armor=18, damage=36, attackRange=5, aggroRange=20, tags={"plant","mist","dungeon_mistwood"}, respawnSeconds=0, lootTablePublic={{ itemId="item_cursed_bark", displayName="Cursed Bark" },{ itemId="item_mist_essence", displayName="Mist Essence" }} },
	mob_root_snare = { mobId="mob_root_snare", name="Root Snare", level=10, maxHealth=300, armor=0, damage=25, attackRange=7, aggroRange=14, tags={"plant","trap","dungeon_mistwood"}, respawnSeconds=0, lootTablePublic={{ itemId="item_mistleaf", displayName="Mistleaf" },{ itemId="item_cursed_bark", displayName="Cursed Bark" }} },
	mob_mistwood_dryad = { mobId="mob_mistwood_dryad", name="Corrupted Dryad", level=12, maxHealth=620, armor=15, damage=48, attackRange=8, aggroRange=22, tags={"fae","plant","dungeon_mistwood"}, respawnSeconds=0, lootTablePublic={{ itemId="item_dryad_tear", displayName="Dryad's Tear" },{ itemId="item_mist_essence", displayName="Mist Essence" }} },
	mob_root_guardian = { mobId="mob_root_guardian", name="Root Guardian", level=13, maxHealth=3800, armor=40, damage=65, attackRange=8, aggroRange=35, tags={"plant","boss","dungeon_mistwood"}, respawnSeconds=0, isBoss=true, lootTablePublic={{ itemId="item_guardian_heartwood", displayName="Guardian Heartwood" },{ itemId="item_mistwood_staff", displayName="Mistwood Staff" }} },
	mob_heart_of_mistwood = { mobId="mob_heart_of_mistwood", name="Heart of the Mistwood", level=15, maxHealth=9500, armor=55, damage=95, attackRange=12, aggroRange=40, tags={"plant","boss","dungeon_mistwood"}, respawnSeconds=0, isBoss=true, lootTablePublic={{ itemId="item_mistwood_crown", displayName="Mistwood Crown" },{ itemId="item_heartwood_core", displayName="Heartwood Core" },{ itemId="item_sturdy_helmet", displayName="Sturdy Helmet" }} },
}

function MobConfig.GetMob(mobId: string): MobDefinition?  return MOBS[mobId] end
function MobConfig.IsValidMob(mobId: string): boolean       return MOBS[mobId] ~= nil end
function MobConfig.GetMaxHealth(mobId: string): number?     local m = MOBS[mobId]; return if m then m.maxHealth else nil end
function MobConfig.GetLevel(mobId: string): number?         local m = MOBS[mobId]; return if m then m.level else nil end
function MobConfig.GetAll(): { [string]: MobDefinition }    return MOBS end
function MobConfig.GetAllMobIds(): { string }
	local ids = {}; for id in pairs(MOBS) do table.insert(ids, id) end; return ids
end
function MobConfig.GetMobsByTag(tag: string): { MobDefinition }
	local r = {}
	for _, mob in pairs(MOBS) do for _, t in ipairs(mob.tags) do if t == tag then table.insert(r, mob); break end end end
	return r
end

return MobConfig
