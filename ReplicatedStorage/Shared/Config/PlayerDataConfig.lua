--!strict
-- Shared canonical player-data schema for GhostyRPG.
-- Safe for server and client reads. Do not put DataStore keys or secrets here.

local PlayerDataConfig = {}

PlayerDataConfig.CURRENT_VERSION = 3

export type InventoryItemData = {
	itemId: string,
	amount: number,
	metadata: { [string]: any }?,
}

export type EquipmentData = {
	Head: InventoryItemData?,
	Shoulders: InventoryItemData?,
	Chest: InventoryItemData?,
	Legs: InventoryItemData?,
	Feet: InventoryItemData?,
	Hands: InventoryItemData?,
	Waist: InventoryItemData?,
	Wrist: InventoryItemData?,
	Back: InventoryItemData?,
	MainHand: InventoryItemData?,
	OffHand: InventoryItemData?,
	Ranged: InventoryItemData?,
	Necklace: InventoryItemData?,
	Ring1: InventoryItemData?,
	Ring2: InventoryItemData?,
	Trinket1: InventoryItemData?,
	Trinket2: InventoryItemData?,
}

export type QuestObjectiveProgress = {
	current: number,
	required: number,
}

export type ActiveQuestData = {
	questId: string,
	startedAt: number,
	objectives: { [string]: QuestObjectiveProgress },
}

export type CompletedQuestsMap = { [string]: number }

export type ProfessionData = {
	Level: number,
	XP: number,
}

export type DungeonProgressData = {
	bestClearSeconds: number?,
	lockoutExpires: number?,
	totalClears: number,
}

export type ArenaProfileData = {
	rating: number,
	wins: number,
	losses: number,
	season: number,
}

export type PlayerData = {
	Version: number,
	Level: number,
	Exp: number,
	Gold: number,
	SelectedClass: string,
	SelectedRole: string,
	Stats: { [string]: any },
	Inventory: { [string]: InventoryItemData },
	Equipment: EquipmentData,
	ActiveQuests: { [string]: ActiveQuestData },
	CompletedQuests: CompletedQuestsMap,
	Professions: { [string]: ProfessionData },
	DungeonProgress: { [string]: DungeonProgressData },
	ArenaProfile: ArenaProfileData,
	CurrentHealth: number,
	CurrentResource: number,
	ResourceType: string,
	AbilityCooldowns: { [string]: number },
	Settings: { [string]: any },
	-- ── Phase 5: Overlord systems ─────────────────────────────────────────
	MagicTier: number,
	ArcaneMasteryPoints: number,
	TombData: {
		Tier: number,
		Guardians: { [number]: string },
		UnlockedRooms: { [string]: boolean },
		UpgradeLog: { { timestamp: number, fromTier: number, toTier: number } },
	},
}

local DEFAULT_DATA: PlayerData = {
	Version = PlayerDataConfig.CURRENT_VERSION,
	Level = 1,
	Exp = 0,
	Gold = 0,
	SelectedClass = "",
	SelectedRole = "",
	CurrentHealth = 100,
	CurrentResource = 100,
	ResourceType = "Mana",
	Stats = {
		Strength = 1,
		Agility = 1,
		Intellect = 1,
		Stamina = 1,
		Spirit = 1,
		MaxHealth = 100,
		MaxResource = 100,
		Resource = 0,
		ResourceType = "",
		Armor = 0,
		AttackPower = 0,
		SpellPower = 0,
		HP = 100,
		MP = 100,
		Attack = 10,
		Defense = 0,
		Speed = 10,
	},
	Inventory = {},
	Equipment = {},
	ActiveQuests = {},
	CompletedQuests = {},
	Professions = {
		Mining = { Level = 1, XP = 0 },
		Alchemy = { Level = 1, XP = 0 },
	},
	DungeonProgress = {},
	ArenaProfile = {
		rating = 1500,
		wins = 0,
		losses = 0,
		season = 1,
	},
	-- CombatService owns these timestamps during a session; PlayerDataService resets them after load.
	AbilityCooldowns = {},
	Settings = {
		musicVolume = 0.8,
		sfxVolume = 1.0,
		showDamageNumbers = true,
		autoLoot = false,
		ResetClassAllowed = false,
	},
	-- ── Phase 5: Overlord systems ──────────────────────────────────────────
	MagicTier            = 1,
	ArcaneMasteryPoints  = 0,
	TombData = {
		Tier          = 0,
		Guardians     = {},
		UnlockedRooms = {},
		UpgradeLog    = {},
	},
}

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, child in pairs(value) do
		copy[deepCopy(key)] = deepCopy(child)
	end
	return copy
end

function PlayerDataConfig.DeepCopy(value: any): any
	return deepCopy(value)
end

function PlayerDataConfig.DeepCopyDefault(): PlayerData
	return deepCopy(DEFAULT_DATA) :: PlayerData
end

function PlayerDataConfig.MergeDefaults(target: { [any]: any }, defaults: { [any]: any })
	for key, defaultValue in pairs(defaults) do
		if target[key] == nil then
			target[key] = deepCopy(defaultValue)
		elseif type(target[key]) == "table" and type(defaultValue) == "table" then
			PlayerDataConfig.MergeDefaults(target[key], defaultValue)
		end
	end
	return target
end

function PlayerDataConfig.Reconcile(existing: { [any]: any }, template: { [any]: any }?): { [any]: any }
	return PlayerDataConfig.MergeDefaults(existing, template or DEFAULT_DATA)
end

-- BackFill is a compatibility alias for services/tests that use this schema term.
function PlayerDataConfig.BackFill(existing: { [any]: any }): { [any]: any }
	return PlayerDataConfig.Reconcile(existing, DEFAULT_DATA)
end

PlayerDataConfig.Defaults = DEFAULT_DATA

return PlayerDataConfig
