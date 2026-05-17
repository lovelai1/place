--!strict
--------------------------------------------------------------------------------
-- GhostyRPG | ClassEvolutionService.lua
-- ServerScriptService/Server/Services/ClassEvolutionService.lua
--
-- Логика смены Overlord-класса (эволюция).
-- Проверяет RequiredLevel + MagicTier + TombTier + квест эволюции.
-- При успехе — меняет SelectedClass, пересчитывает статы, выдаёт новые умения.
-- TrueOverlord — prestige-класс: только один игрок на сервере.
--
-- INIT:
--   ClassEvolutionService.Init(
--     playerDataService, classService, magicTierService,
--     statsService, questService, abilityService
--   )
--
-- PUBLIC API:
--   ClassEvolutionService.GetOptions(player)
--     → { { targetClass, met, requirements: { label, ok }[] }[] }
--   ClassEvolutionService.Evolve(player, targetClass)
--     → (ok: boolean, reason: string?)
--   ClassEvolutionService.CanEvolve(player, targetClass)
--     → (ok: boolean, failedReqs: { string })
--   ClassEvolutionService.GetPrestigeHolder() → Player?
--------------------------------------------------------------------------------

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SharedConfig         = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local OverlordClassConfig  = require(SharedConfig:WaitForChild("OverlordClassConfig"))

local ClassEvolutionService = {}

--------------------------------------------------------------------------------
-- TYPES
--------------------------------------------------------------------------------

export type Requirement = {
    label : string,
    ok    : boolean,
    have  : string,
    need  : string,
}

export type EvolutionOption = {
    targetClass  : string,
    displayName  : string,
    met          : boolean,
    requirements : { Requirement },
}

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local playerDataService : any = nil
local classService      : any = nil
local magicTierService  : any = nil
local statsService      : any = nil
local questService      : any = nil
local abilityService    : any = nil

local evolutionQuestConfig: any = nil   -- lazy-loaded from ClassEvolutionQuestConfig

local initialized     = false
local prestigeHolder: Player? = nil    -- только один TrueOverlord на сервере

--------------------------------------------------------------------------------
-- LAZY-LOAD QuestConfig
--------------------------------------------------------------------------------

local function getQuestConfig(): any
    if evolutionQuestConfig then return evolutionQuestConfig end
    local ok, cfg = pcall(function()
        local srv = ServerScriptService:WaitForChild("Server")
        return require(srv:WaitForChild("Config"):WaitForChild("ClassEvolutionQuestConfig"))
    end)
    if ok and cfg then
        evolutionQuestConfig = cfg
    else
        -- Фоллбэк: пустая таблица чтобы не сломать логику
        evolutionQuestConfig = { GetRequirements = function() return {} end }
    end
    return evolutionQuestConfig
end

--------------------------------------------------------------------------------
-- PRIVATE HELPERS
--------------------------------------------------------------------------------

local function assertInit()
    assert(initialized, "[ClassEvolutionService] Must call Init() before use.")
end

local function getOverlordDef(className: string): any?
    return (OverlordClassConfig :: any)[className]
end

--- Возвращает TombTier из данных игрока.
local function getTombTier(data: any): number
    if type(data.TombData) == "table" then
        return tonumber(data.TombData.Tier) or 0
    end
    return 0
end

--- Проверяет, выполнен ли квест эволюции (через QuestService или DungeonProgress).
local function isEvolutionQuestDone(player: Player, data: any, fromClass: string, toClass: string): boolean
    local cfg = getQuestConfig()
    local reqs: { any } = {}
    if type(cfg.GetRequirements) == "function" then
        reqs = cfg.GetRequirements(fromClass, toClass) or {}
    end
    if #reqs == 0 then return true end   -- квестов нет → считается пройденным

    for _, req in ipairs(reqs) do
        if req.type == "quest" then
            -- Проверяем CompletedQuests
            local completed = data.CompletedQuests or {}
            if not completed[req.questId] then return false end

        elseif req.type == "dungeon" then
            -- Проверяем DungeonProgress[dungeonId][difficulty].completions >= 1
            local dp = data.DungeonProgress or {}
            local entry = dp[req.dungeonId]
            if type(entry) ~= "table" then return false end
            local diffEntry = entry[req.difficulty or "Normal"]
            if type(diffEntry) ~= "table" then return false end
            if (diffEntry.completions or 0) < (req.minClears or 1) then return false end

        elseif req.type == "kill" then
            -- QuestService хранит прогресс Kill-квестов в ActiveQuests/CompletedQuests
            -- Упрощённо: проверяем через специальное поле EvoKills в PlayerData
            local kills = data.EvoKills or {}
            if (kills[req.mobType] or 0) < (req.count or 1) then return false end

        elseif req.type == "item" then
            -- Проверяем наличие предмета в инвентаре
            local inv = data.Inventory or {}
            local slot = inv[req.itemId]
            local have = slot and (slot.amount or 0) or 0
            if have < (req.amount or 1) then return false end
        end
    end

    return true
end

--- Строит список требований с галочками для одного перехода.
local function buildRequirements(
    player: Player,
    data: any,
    fromClass: string,
    targetClass: string,
    targetDef: any
): { Requirement }

    local reqs: { Requirement } = {}
    local level    = data.Level or 1
    local magicTier = data.MagicTier or 1
    local tombTier = getTombTier(data)

    -- Уровень
    local needLevel = targetDef.RequiredLevel or 1
    table.insert(reqs, {
        label = "Player Level",
        ok    = level >= needLevel,
        have  = tostring(level),
        need  = tostring(needLevel),
    })

    -- Magic Tier
    local needMagic = targetDef.MinMagicTier or 1
    table.insert(reqs, {
        label = "Magic Tier",
        ok    = magicTier >= needMagic,
        have  = tostring(magicTier),
        need  = tostring(needMagic),
    })

    -- Tomb Tier
    local needTomb = targetDef.RequiredTombTier or 0
    if needTomb > 0 then
        table.insert(reqs, {
            label = "Tomb Tier",
            ok    = tombTier >= needTomb,
            have  = tostring(tombTier),
            need  = tostring(needTomb),
        })
    end

    -- Prestige (только один TrueOverlord)
    if targetDef.IsPrestigeClass then
        local slot = (prestigeHolder == nil or prestigeHolder == player)
        table.insert(reqs, {
            label = "Prestige Slot Available",
            ok    = slot,
            have  = if slot then "Free" else "Taken",
            need  = "Free",
        })
    end

    -- Квестовые требования из ClassEvolutionQuestConfig
    local cfg = getQuestConfig()
    if type(cfg.GetRequirements) == "function" then
        local questReqs = cfg.GetRequirements(fromClass, targetClass) or {}
        for _, req in ipairs(questReqs) do
            if req.type == "dungeon" then
                local dp = data.DungeonProgress or {}
                local entry = dp[req.dungeonId]
                local diffE = type(entry) == "table" and entry[req.difficulty or "Normal"] or nil
                local clears = type(diffE) == "table" and (diffE.completions or 0) or 0
                local need   = req.minClears or 1
                table.insert(reqs, {
                    label = req.label or ("Clear " .. tostring(req.dungeonId)),
                    ok    = clears >= need,
                    have  = tostring(clears),
                    need  = tostring(need) .. "x",
                })

            elseif req.type == "kill" then
                local kills = data.EvoKills or {}
                local have  = kills[req.mobType] or 0
                local need  = req.count or 1
                table.insert(reqs, {
                    label = req.label or ("Kill " .. tostring(req.mobType)),
                    ok    = have >= need,
                    have  = tostring(have),
                    need  = tostring(need),
                })

            elseif req.type == "item" then
                local inv  = data.Inventory or {}
                local slot = inv[req.itemId]
                local have = slot and (slot.amount or 0) or 0
                local need = req.amount or 1
                table.insert(reqs, {
                    label = req.label or ("Collect " .. tostring(req.itemId)),
                    ok    = have >= need,
                    have  = tostring(have),
                    need  = tostring(need),
                })

            elseif req.type == "quest" then
                local done = (data.CompletedQuests or {})[req.questId] ~= nil
                table.insert(reqs, {
                    label = req.label or ("Quest: " .. tostring(req.questId)),
                    ok    = done,
                    have  = if done then "Done" else "Incomplete",
                    need  = "Done",
                })
            end
        end
    end

    return reqs
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Возвращает все доступные варианты эволюции для игрока с детальными требованиями.
function ClassEvolutionService.GetOptions(player: Player): { EvolutionOption }
    assertInit()
    local data = playerDataService.GetData(player)
    if not data then return {} end

    local currentClass = data.SelectedClass or ""
    if currentClass == "" then return {} end

    local currentDef = getOverlordDef(currentClass)
    if not currentDef or not currentDef.EvolvesInto then
        -- Обычный класс (Warrior/Mage/…) — предлагаем PhantomSoul или SkeletonWarrior как старт
        if not OverlordClassConfig.IsOverlordClass(currentClass) then
            local starterOptions: { EvolutionOption } = {}
            for _, startClass in ipairs({ "PhantomSoul", "SkeletonWarrior" }) do
                local def = getOverlordDef(startClass)
                if def then
                    local reqs = buildRequirements(player, data, currentClass, startClass, def)
                    local met  = true
                    for _, r in ipairs(reqs) do if not r.ok then met = false end end
                    table.insert(starterOptions, {
                        targetClass  = startClass,
                        displayName  = def.DisplayName or startClass,
                        met          = met,
                        requirements = reqs,
                    })
                end
            end
            return starterOptions
        end
        return {}
    end

    local options: { EvolutionOption } = {}
    for _, targetClass in ipairs(currentDef.EvolvesInto) do
        local targetDef = getOverlordDef(targetClass)
        if not targetDef then continue end

        local reqs = buildRequirements(player, data, currentClass, targetClass, targetDef)
        local met  = true
        for _, r in ipairs(reqs) do if not r.ok then met = false end end

        table.insert(options, {
            targetClass  = targetClass,
            displayName  = targetDef.DisplayName or targetClass,
            met          = met,
            requirements = reqs,
        })
    end

    return options
end

--- Быстрая проверка без деталей. Возвращает (ok, failedLabels).
function ClassEvolutionService.CanEvolve(player: Player, targetClass: string): (boolean, { string })
    assertInit()
    local data = playerDataService.GetData(player)
    if not data then return false, { "Player data unavailable." } end

    local currentClass = data.SelectedClass or ""
    local targetDef    = getOverlordDef(targetClass)
    if not targetDef then return false, { "Unknown class: " .. targetClass } end

    local reqs   = buildRequirements(player, data, currentClass, targetClass, targetDef)
    local failed: { string } = {}
    for _, r in ipairs(reqs) do
        if not r.ok then table.insert(failed, r.label) end
    end
    return #failed == 0, failed
end

--- Проводит эволюцию. При успехе возвращает (true, nil).
--- При ошибке — (false, причина).
function ClassEvolutionService.Evolve(player: Player, targetClass: string): (boolean, string?)
    assertInit()

    local ok, failed = ClassEvolutionService.CanEvolve(player, targetClass)
    if not ok then
        return false, "Requirements not met: " .. table.concat(failed, "; ")
    end

    local data = playerDataService.GetData(player)
    if not data then return false, "Player data unavailable." end

    local prevClass = data.SelectedClass or ""
    local targetDef = getOverlordDef(targetClass)

    -- Prestige-класс: занять слот
    if targetDef and targetDef.IsPrestigeClass then
        if prestigeHolder and prestigeHolder ~= player and prestigeHolder.Parent == Players then
            return false, "A True Overlord already walks this world."
        end
        prestigeHolder = player
    end

    -- Применяем смену класса через ClassService (минуя ResetClassAllowed-защиту)
    if type(data.Settings) ~= "table" then data.Settings = {} end
    local prev = data.Settings.ResetClassAllowed
    data.Settings.ResetClassAllowed = true
    local switchOk, switchReason = classService.SelectClass(player, targetClass)
    data.Settings.ResetClassAllowed = prev

    if not switchOk then
        return false, switchReason or "Class switch failed."
    end

    -- Пересчёт статов под новый класс
    if statsService and type(statsService.Recalculate) == "function" then
        pcall(statsService.Recalculate, player)
    end

    -- Разблокировать Magic Tier если нужно
    if magicTierService and targetDef and targetDef.MinMagicTier then
        local currentTier = magicTierService.GetTier(player)
        if currentTier < targetDef.MinMagicTier then
            pcall(magicTierService.GrantTier, player, targetDef.MinMagicTier)
        end
    end

    -- Записать эволюцию в PlayerData
    if type(data.ClassEvolutionLog) ~= "table" then
        data.ClassEvolutionLog = {}
    end
    table.insert(data.ClassEvolutionLog, {
        from      = prevClass,
        to        = targetClass,
        timestamp = os.time(),
    })

    playerDataService.ScheduleSave(player)

    print(string.format("[ClassEvolution] %s evolved: %s → %s.", player.Name, prevClass, targetClass))
    return true, nil
end

--- Возвращает текущего держателя prestige-класса TrueOverlord.
function ClassEvolutionService.GetPrestigeHolder(): Player?
    return prestigeHolder
end

--------------------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------------

function ClassEvolutionService.Init(
    pds: any, cs: any, mts: any, ss: any, qs: any, as: any
)
    if initialized then
        warn("[ClassEvolutionService] Init called more than once; ignoring.")
        return
    end
    assert(pds, "[ClassEvolutionService] PlayerDataService required.")
    assert(cs,  "[ClassEvolutionService] ClassService required.")

    playerDataService = pds
    classService      = cs
    magicTierService  = mts
    statsService      = ss
    questService      = qs
    abilityService    = as

    -- Освободить prestige-слот если TrueOverlord покинул сервер
    Players.PlayerRemoving:Connect(function(player)
        if prestigeHolder == player then
            prestigeHolder = nil
            print("[ClassEvolutionService] Prestige slot freed — TrueOverlord left.")
        end
    end)

    initialized = true
    print("[ClassEvolutionService] Initialized.")
end

return ClassEvolutionService
