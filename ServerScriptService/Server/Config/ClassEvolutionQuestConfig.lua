--!strict
--------------------------------------------------------------------------------
-- GhostyRPG | ClassEvolutionQuestConfig.lua
-- ServerScriptService/Server/Config/ClassEvolutionQuestConfig.lua
--
-- Определяет квестовые требования для каждого перехода между Overlord-классами.
-- Читается ClassEvolutionService.lua через GetRequirements(fromClass, toClass).
--
-- Типы требований:
--   { type="quest",    questId,                         label }
--   { type="dungeon",  dungeonId, difficulty, minClears, label }
--   { type="kill",     mobType, count,                  label }
--   { type="item",     itemId,  amount,                 label }
--
-- ЭВОЛЮЦИОННОЕ ДЕРЕВО:
--
--   [Любой обычный класс]
--          ↓
--   PhantomSoul ──────→ PhantomMage ──→ Lich ──→ TrueOverlord
--   SkeletonWarrior ──→ DeathKnight ──→ AbyssalKnight
--                    ╲→ BoneColossus   ╲→ UndeadLord
--                       PhantomMage ──→ AbyssalSorcerer
--------------------------------------------------------------------------------

local ClassEvolutionQuestConfig = {}

--------------------------------------------------------------------------------
-- ТАБЛИЦА ТРЕБОВАНИЙ
-- Ключ: "FromClass→ToClass"
--------------------------------------------------------------------------------

local REQUIREMENTS: { [string]: { any } } = {

    ---------------------------------------------------------------------------
    -- ВХОД В OVERLORD-СИСТЕМУ (обычный класс → Tier 1)
    -- Любой стандартный класс (Warrior, Mage …) → PhantomSoul или SkeletonWarrior
    ---------------------------------------------------------------------------

    ["*->PhantomSoul"] = {
        { type = "quest",
          questId = "quest_001_first_steps",
          label   = "Complete: First Steps" },
        { type = "kill",
          mobType = "mob_ghost_slime",
          count   = 20,
          label   = "Slay 20 Ghost Slimes" },
        { type = "dungeon",
          dungeonId  = "dungeon_sealed_crypt",
          difficulty = "Normal",
          minClears  = 1,
          label      = "Clear Sealed Crypt (Normal)" },
    },

    ["*->SkeletonWarrior"] = {
        { type = "quest",
          questId = "quest_003_goblin_menace",
          label   = "Complete: Goblin Menace" },
        { type = "kill",
          mobType = "mob_restless_skeleton",
          count   = 30,
          label   = "Slay 30 Restless Skeletons" },
        { type = "item",
          itemId = "BoneFragment",
          amount = 50,
          label  = "Collect 50 Bone Fragments" },
    },

    ---------------------------------------------------------------------------
    -- TIER 1 → TIER 3
    -- PhantomSoul → PhantomMage  (мистический путь заклинателя)
    ---------------------------------------------------------------------------

    ["PhantomSoul->PhantomMage"] = {
        { type = "quest",
          questId = "quest_008_revenant_rising",
          label   = "Complete: Revenant Rising" },
        { type = "kill",
          mobType = "mob_wraith",
          count   = 50,
          label   = "Slay 50 Wraithss" },
        { type = "dungeon",
          dungeonId  = "dungeon_sealed_crypt",
          difficulty = "Normal",
          minClears  = 3,
          label      = "Clear Sealed Crypt ×3 (Normal)" },
        { type = "item",
          itemId = "SoulCrystal_T1",
          amount = 10,
          label  = "Collect 10 Soul Crystals (T1)" },
    },

    ---------------------------------------------------------------------------
    -- PhantomSoul → DeathKnight  (воинский путь из духа)
    ---------------------------------------------------------------------------

    ["PhantomSoul->DeathKnight"] = {
        { type = "quest",
          questId = "quest_010_elite_bounty_knight",
          label   = "Complete: Bounty: Skeleton Knight" },
        { type = "kill",
          mobType = "mob_elite_skeleton_knight",
          count   = 3,
          label   = "Slay 3 Skeleton Knights (Elite)" },
        { type = "dungeon",
          dungeonId  = "dungeon_sealed_crypt",
          difficulty = "Normal",
          minClears  = 2,
          label      = "Clear Sealed Crypt ×2 (Normal)" },
        { type = "item",
          itemId = "RuneStone",
          amount = 15,
          label  = "Collect 15 RuneStones" },
    },

    ---------------------------------------------------------------------------
    -- SkeletonWarrior → DeathKnight  (воинский путь нежити)
    ---------------------------------------------------------------------------

    ["SkeletonWarrior->DeathKnight"] = {
        { type = "kill",
          mobType = "mob_elite_skeleton_knight",
          count   = 5,
          label   = "Slay 5 Skeleton Knights (Elite)" },
        { type = "kill",
          mobType = "mob_crypt_revenant",
          count   = 40,
          label   = "Slay 40 Crypt Revenants" },
        { type = "dungeon",
          dungeonId  = "dungeon_sealed_crypt",
          difficulty = "Normal",
          minClears  = 2,
          label      = "Clear Sealed Crypt ×2 (Normal)" },
        { type = "item",
          itemId = "RuneStone",
          amount = 20,
          label  = "Collect 20 RuneStones" },
        { type = "item",
          itemId = "BoneFragment",
          amount = 100,
          label  = "Collect 100 Bone Fragments" },
    },

    ---------------------------------------------------------------------------
    -- SkeletonWarrior → BoneColossus  (путь конструкта)
    ---------------------------------------------------------------------------

    ["SkeletonWarrior->BoneColossus"] = {
        { type = "kill",
          mobType = "mob_restless_skeleton",
          count   = 100,
          label   = "Slay 100 Restless Skeletons" },
        { type = "kill",
          mobType = "mob_bone_archer",
          count   = 50,
          label   = "Slay 50 Bone Archers" },
        { type = "dungeon",
          dungeonId  = "dungeon_sealed_crypt",
          difficulty = "Heroic",
          minClears  = 1,
          label      = "Clear Sealed Crypt (Heroic)" },
        { type = "item",
          itemId = "BoneFragment",
          amount = 300,
          label  = "Collect 300 Bone Fragments" },
        { type = "item",
          itemId = "SoulCrystal_T1",
          amount = 5,
          label  = "Collect 5 Soul Crystals (T1)" },
    },

    ---------------------------------------------------------------------------
    -- TIER 3 → TIER 4
    -- PhantomMage → Lich  (путь высшего мага смерти)
    ---------------------------------------------------------------------------

    ["PhantomMage->Lich"] = {
        { type = "quest",
          questId = "quest_015_guardian_slain",
          label   = "Complete: Guardian's End" },
        { type = "kill",
          mobType = "mob_elite_crypt_lich",
          count   = 1,
          label   = "Slay the Crypt Lich (Elite)" },
        { type = "dungeon",
          dungeonId  = "dungeon_sealed_crypt",
          difficulty = "Heroic",
          minClears  = 3,
          label      = "Clear Sealed Crypt ×3 (Heroic)" },
        { type = "item",
          itemId = "SoulCrystal_T2",
          amount = 20,
          label  = "Collect 20 Soul Crystals (T2)" },
        { type = "item",
          itemId = "NecroticEssence",
          amount = 10,
          label  = "Collect 10 Necrotic Essences" },
    },

    ---------------------------------------------------------------------------
    -- PhantomMage → AbyssalSorcerer  (путь через Бездну)
    ---------------------------------------------------------------------------

    ["PhantomMage->AbyssalSorcerer"] = {
        { type = "kill",
          mobType = "mob_elite_crypt_lich",
          count   = 2,
          label   = "Slay 2 Crypt Liches (Elite)" },
        { type = "dungeon",
          dungeonId  = "dungeon_mistwood_depths",
          difficulty = "Heroic",
          minClears  = 2,
          label      = "Clear Mistwood Depths ×2 (Heroic)" },
        { type = "item",
          itemId = "VoidShard",
          amount = 5,
          label  = "Collect 5 Void Shards" },
        { type = "item",
          itemId = "SoulCrystal_T2",
          amount = 15,
          label  = "Collect 15 Soul Crystals (T2)" },
    },

    ---------------------------------------------------------------------------
    -- DeathKnight → AbyssalKnight  (путь рыцаря Бездны)
    ---------------------------------------------------------------------------

    ["DeathKnight->AbyssalKnight"] = {
        { type = "kill",
          mobType = "mob_elite_phantom_alpha",
          count   = 5,
          label   = "Slay 5 Phantom Alphas (Elite)" },
        { type = "dungeon",
          dungeonId  = "dungeon_sealed_crypt",
          difficulty = "Heroic",
          minClears  = 2,
          label      = "Clear Sealed Crypt ×2 (Heroic)" },
        { type = "dungeon",
          dungeonId  = "dungeon_mistwood_depths",
          difficulty = "Normal",
          minClears  = 3,
          label      = "Clear Mistwood Depths ×3 (Normal)" },
        { type = "item",
          itemId = "VoidShard",
          amount = 5,
          label  = "Collect 5 Void Shards" },
        { type = "item",
          itemId = "ShadowStone",
          amount = 50,
          label  = "Collect 50 Shadow Stones" },
    },

    ---------------------------------------------------------------------------
    -- DeathKnight → UndeadLord  (путь полководца нежити)
    ---------------------------------------------------------------------------

    ["DeathKnight->UndeadLord"] = {
        { type = "kill",
          mobType = "mob_restless_skeleton",
          count   = 200,
          label   = "Slay 200 Restless Skeletons (total)" },
        { type = "kill",
          mobType = "mob_elite_skeleton_knight",
          count   = 10,
          label   = "Slay 10 Skeleton Knights (Elite)" },
        { type = "dungeon",
          dungeonId  = "dungeon_sealed_crypt",
          difficulty = "Heroic",
          minClears  = 5,
          label      = "Clear Sealed Crypt ×5 (Heroic)" },
        { type = "item",
          itemId = "RuneStone",
          amount = 100,
          label  = "Collect 100 RuneStones" },
        { type = "item",
          itemId = "SoulCrystal_T2",
          amount = 30,
          label  = "Collect 30 Soul Crystals (T2)" },
    },

    ---------------------------------------------------------------------------
    -- TIER 7 → TIER 9 (PRESTIGE)
    -- Lich → TrueOverlord  (финальная эволюция)
    ---------------------------------------------------------------------------

    ["Lich->TrueOverlord"] = {
        -- Необходимо пройти все три рейда хотя бы на Normal
        { type = "dungeon",
          dungeonId  = "raid_sealed_crypt",
          difficulty = "Normal",
          minClears  = 1,
          label      = "Clear Raid: Sealed Crypt (Normal)" },
        { type = "dungeon",
          dungeonId  = "raid_bone_kingdom",
          difficulty = "Normal",
          minClears  = 1,
          label      = "Clear Raid: Bone Kingdom (Normal)" },
        { type = "dungeon",
          dungeonId  = "raid_nazarick_throne",
          difficulty = "Normal",
          minClears  = 1,
          label      = "Clear Raid: Nazarick Throne (Normal)" },
        -- Убить финального босса рейда
        { type = "kill",
          mobType = "boss_throne_guardian",
          count   = 1,
          label   = "Slay the Guardian of the Nazarick Throne" },
        -- Материалы для Tomb Tier 5
        { type = "item",
          itemId = "AbyssalStone",
          amount = 100,
          label  = "Collect 100 Abyssal Stones" },
        { type = "item",
          itemId = "SoulCrystal_T4",
          amount = 20,
          label  = "Collect 20 Soul Crystals (T4)" },
        { type = "item",
          itemId = "DragonBone",
          amount = 1,
          label  = "Collect 1 Dragon Bone (Rare)" },
    },

}

--------------------------------------------------------------------------------
-- DISPLAY LABELS PER TRANSITION (для ClassEvolutionUI)
--------------------------------------------------------------------------------

local TRANSITION_LORE: { [string]: string } = {
    ["*->PhantomSoul"]            = "Your spirit has just left its mortal vessel. You are newly born into undeath.",
    ["*->SkeletonWarrior"]        = "The bones remember the battles. Let them fight again.",
    ["PhantomSoul->PhantomMage"]  = "You have learned to channel death-magic through your spectral form.",
    ["PhantomSoul->DeathKnight"]  = "A warrior's soul in a ghost's form — forge yourself into the blade of death.",
    ["SkeletonWarrior->DeathKnight"] = "Your bones have earned their armour. The runes of death await.",
    ["SkeletonWarrior->BoneColossus"] = "You have consumed the essence of a hundred soldiers. Become the colossus.",
    ["PhantomMage->Lich"]         = "Transcend mortality. Let your phylactery hold what your body cannot.",
    ["PhantomMage->AbyssalSorcerer"] = "The void has chosen you as its conduit. Do not resist.",
    ["DeathKnight->AbyssalKnight"] = "Your death-runed plate has been tempered by void energy.",
    ["DeathKnight->UndeadLord"]   = "A hundred skeletons march behind you. Ten thousand more await your command.",
    ["Lich->TrueOverlord"]        = "You have proven yourself worthy of the Nazarick Throne. All shall kneel.",
}

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Возвращает список требований для перехода fromClass → toClass.
--- Если нет точного совпадения, ищет wildcard "*→toClass".
function ClassEvolutionQuestConfig.GetRequirements(fromClass: string, toClass: string): { any }
    local key      = fromClass .. "->" .. toClass
    local wildcard = "*->" .. toClass

    local reqs = REQUIREMENTS[key] or REQUIREMENTS[wildcard]
    if type(reqs) == "table" then
        -- Возвращаем shallow-copy чтобы никто не мутировал конфиг
        local out: { any } = {}
        for _, r in ipairs(reqs) do table.insert(out, r) end
        return out
    end
    return {}
end

--- Проверяет есть ли вообще квестовые требования для этого перехода.
function ClassEvolutionQuestConfig.HasRequirements(fromClass: string, toClass: string): boolean
    local key      = fromClass .. "->" .. toClass
    local wildcard = "*->" .. toClass
    local reqs = REQUIREMENTS[key] or REQUIREMENTS[wildcard]
    return type(reqs) == "table" and #reqs > 0
end

--- Возвращает лорный текст для экрана эволюции.
function ClassEvolutionQuestConfig.GetLore(fromClass: string, toClass: string): string
    local key  = fromClass .. "->" .. toClass
    return TRANSITION_LORE[key]
        or TRANSITION_LORE["*->" .. toClass]
        or "A new chapter of your undead existence begins."
end

--- Список всех зарегистрированных переходов (для дебага / тестов).
function ClassEvolutionQuestConfig.GetAllKeys(): { string }
    local out: { string } = {}
    for k in pairs(REQUIREMENTS) do table.insert(out, k) end
    table.sort(out)
    return out
end

return ClassEvolutionQuestConfig
