--!strict
--------------------------------------------------------------------------------
-- GhostyRPG | RaidConfig.lua
-- ServerScriptService/Server/Config/RaidConfig.lua
-- Phase 8: полный конфиг рейдов, боссов, сложностей.
--------------------------------------------------------------------------------

export type BossPhase = {
	phaseIndex   : number,
	label        : string,
	hpThreshold  : number,   -- переход когда HP < этого значения (0.0–1.0)
	dialogue     : string,
	newAbilities : { string },
	mechanics    : { string },
}

export type BossConf = {
	id          : string,
	name        : string,
	size        : string,   -- "Normal" | "Large" | "Colossal"
	baseHealth  : number,
	baseDamage  : number,
	enrageTimer : number,
	abilities   : { string },   -- фаза 1
	phases      : { BossPhase },
	lootTable   : { string },
}

export type RaidDef = {
	id          : string,
	displayName : string,
	description : string,
	minLevel    : number,
	minTombTier : number,
	minRaidSize : number,
	bosses      : { BossConf },
}

export type DifficultyDef = {
	Label                 : string,
	EnemyHealthMultiplier : number,
	EnemyDamageMultiplier : number,
	ItemLevelBonus        : number,
	PersonalLoot          : boolean,
	VotingRequired        : boolean,
	MaxWipes              : number,
	LockedRosterSize      : number?,
	LockoutDuration       : number,
}

--------------------------------------------------------------------------------
-- DIFFICULTY TABLE
--------------------------------------------------------------------------------

local DifficultyTiers: { [string]: DifficultyDef } = {
	LFR = {
		Label = "Spirit Finder", EnemyHealthMultiplier = 0.75, EnemyDamageMultiplier = 0.60,
		ItemLevelBonus = -10, PersonalLoot = true, VotingRequired = false,
		MaxWipes = -1, LockoutDuration = 86400,
	},
	Normal = {
		Label = "Normal", EnemyHealthMultiplier = 1.0, EnemyDamageMultiplier = 1.0,
		ItemLevelBonus = 0, PersonalLoot = false, VotingRequired = true,
		MaxWipes = -1, LockoutDuration = 604800,
	},
	Heroic = {
		Label = "Heroic", EnemyHealthMultiplier = 2.0, EnemyDamageMultiplier = 1.6,
		ItemLevelBonus = 15, PersonalLoot = false, VotingRequired = true,
		MaxWipes = -1, LockoutDuration = 604800,
	},
	Mythic = {
		Label = "Mythic", EnemyHealthMultiplier = 4.0, EnemyDamageMultiplier = 2.8,
		ItemLevelBonus = 30, PersonalLoot = false, VotingRequired = true,
		MaxWipes = -1, LockedRosterSize = 20, LockoutDuration = 604800,
	},
}

--------------------------------------------------------------------------------
-- RAID DEFINITIONS
--------------------------------------------------------------------------------

local Raids: { [string]: RaidDef } = {

	raid_tomb_of_the_first_overlord = {
		id = "raid_tomb_of_the_first_overlord",
		displayName = "Tomb of the First Overlord",
		description = "Delve into the ruins of the original Overlord's sanctum. Three guardians stand between you and ancient power.",
		minLevel    = 30,
		minTombTier = 2,
		minRaidSize = 5,
		bosses = {
			-- BOSS 1: Skeleton General (undead vanguard)
			{
				id = "BOSS_SKELGEN", name = "General Ossrik the Eternal",
				size = "Large", baseHealth = 800000, baseDamage = 600,
				enrageTimer = 540,
				abilities = { "SKELWAR_RATTLE", "SKELWAR_MARROW_STRIKE", "SKELWAR_BONE_SHIELD" },
				phases = {
					{
						phaseIndex = 1, label = "The March of Bones",
						hpThreshold = 1.0,
						dialogue = "You dare defile this tomb? My soldiers will grind your bones to dust!",
						newAbilities = {}, mechanics = { "Bone Wall — blocks movement every 45s." },
					},
					{
						phaseIndex = 2, label = "Reassembled",
						hpThreshold = 0.60,
						dialogue = "Flesh tears. Bone endures. I cannot be stopped!",
						newAbilities = { "SKELWAR_REASSEMBLE", "SKELWAR_OSSIFY" },
						mechanics = { "Ossify — targets random player, reduces move speed by 60%." },
					},
					{
						phaseIndex = 3, label = "Undying Fury",
						hpThreshold = 0.30,
						dialogue = "Every bone in this chamber will fight you!",
						newAbilities = {},
						mechanics = {
							"Summons 4 Skeleton Warriors every 20s.",
							"Ossify now hits 3 targets simultaneously.",
						},
					},
				},
				lootTable = { "ancient_bone_plate", "ossified_ring", "skull_talisman" },
			},

			-- BOSS 2: Phantom Mage (caster boss)
			{
				id = "BOSS_PHANTOMMAGE", name = "Specter Veldris",
				size = "Normal", baseHealth = 650000, baseDamage = 750,
				enrageTimer = 480,
				abilities = { "PHANTOMMAGE_VOID_BOLT", "PHANTOMMAGE_MIND_FLAY" },
				phases = {
					{
						phaseIndex = 1, label = "Veil of Shadows",
						hpThreshold = 1.0,
						dialogue = "Your minds are open books to me. Every fear you hide, I will use against you.",
						newAbilities = {}, mechanics = { "Mind Flay — channelled DoT on random player." },
					},
					{
						phaseIndex = 2, label = "Echo of the Void",
						hpThreshold = 0.55,
						dialogue = "The void echoes your screams back at you!",
						newAbilities = { "PHANTOMMAGE_ECHO_NOVA", "PHANTOMMAGE_SOUL_BURST" },
						mechanics = {
							"Echo Nova — AoE silence + damage in 18-stud radius.",
							"Soul Burst — detonates a marked player after 4 seconds.",
						},
					},
					{
						phaseIndex = 3, label = "Ethereal Ascension",
						hpThreshold = 0.25,
						dialogue = "I shed this form entirely. You cannot hurt what you cannot touch!",
						newAbilities = { "PHANTOMMAGE_ETHEREAL_FORM" },
						mechanics = {
							"Ethereal Form — immune 8s, healers must keep raid alive.",
							"Soul Burst now marks 3 players simultaneously.",
						},
					},
				},
				lootTable = { "void_silk_robe", "mage_echo_staff", "phantom_focus_gem" },
			},

			-- BOSS 3: The Overlord Warden (final, multi-phase)
			{
				id = "BOSS_OVERLORD_WARDEN", name = "Warden Malachar",
				size = "Colossal", baseHealth = 2000000, baseDamage = 950,
				enrageTimer = 720,
				abilities = { "OVERLORD_SOUL_HARVEST", "OVERLORD_DOMINATE" },
				phases = {
					{
						phaseIndex = 1, label = "Dominion's Hand",
						hpThreshold = 1.0,
						dialogue = "I am the Warden of this tomb. Every Overlord who came before me bows to my law. And so will you.",
						newAbilities = {},
						mechanics = {
							"Dominate — takes control of a random DPS for 10 seconds.",
							"Soul Harvest — AoE drain around boss.",
						},
					},
					{
						phaseIndex = 2, label = "Void Rift",
						hpThreshold = 0.65,
						dialogue = "You chip at stone. I will crack the world!",
						newAbilities = { "OVERLORD_VOID_RUPTURE" },
						mechanics = {
							"Void Rupture — 25-stud AoE, leaves 15s void zone.",
							"Dominate now lasts 15 seconds.",
						},
					},
					{
						phaseIndex = 3, label = "Undying Will",
						hpThreshold = 0.35,
						dialogue = "I have outlasted a thousand heroes. A thousand more will follow you here.",
						newAbilities = { "OVERLORD_UNDYING_WILL", "OVERLORD_NECROMANTIC_AURA" },
						mechanics = {
							"Undying Will — self-heals 5% max HP, interruptible.",
							"Necromantic Aura — all nearby dead mobs reanimate as adds.",
							"Dominate now targets healers preferentially.",
						},
					},
				},
				lootTable = {
					"warden_sigil_cloak", "overlord_scepter_fragment",
					"malachar_seal_ring", "tome_of_dominion",
				},
			},
		},
	},

	raid_crypt_of_phantom_souls = {
		id = "raid_crypt_of_phantom_souls",
		displayName = "Crypt of Phantom Souls",
		description = "An ancient crypt where lost souls fester. Two wraith lords and a Death Knight champion await.",
		minLevel    = 45,
		minTombTier = 3,
		minRaidSize = 10,
		bosses = {
			{
				id = "BOSS_PHANTOMSOUL_TWIN_A", name = "Soul-Wraith Kareth",
				size = "Normal", baseHealth = 1200000, baseDamage = 900,
				enrageTimer = 480,
				abilities = { "PHANTOMSOUL_HAUNT", "PHANTOMSOUL_SOUL_DRAIN" },
				phases = {
					{
						phaseIndex = 1, label = "The Binding Wail",
						hpThreshold = 1.0,
						dialogue = "Our chains bind all who breathe.",
						newAbilities = {}, mechanics = { "Haunt — random player DoT, stackable." },
					},
					{
						phaseIndex = 2, label = "Phase Shift",
						hpThreshold = 0.50,
						dialogue = "We are everywhere at once!",
						newAbilities = { "PHANTOMSOUL_WAIL", "PHANTOMSOUL_PHASE_SHIFT" },
						mechanics = {
							"Phase Shift — teleports to random raider.",
							"Wail — AoE fear, 3s duration.",
						},
					},
				},
				lootTable = { "wraith_chain_bracers", "soul_weave_hood" },
			},
			{
				id = "BOSS_DK_CHAMPION", name = "Death Knight Valdrath",
				size = "Large", baseHealth = 2500000, baseDamage = 1100,
				enrageTimer = 600,
				abilities = { "DK_DEATH_STRIKE", "DK_DEATH_GRIP" },
				phases = {
					{
						phaseIndex = 1, label = "Iron Resolve",
						hpThreshold = 1.0,
						dialogue = "You face the last champion of the dead. This floor is mine.",
						newAbilities = {}, mechanics = { "Death Grip — pulls tank to boss, stun 1s." },
					},
					{
						phaseIndex = 2, label = "Blood Boil",
						hpThreshold = 0.60,
						dialogue = "Feel your blood turn against you!",
						newAbilities = { "DK_BLOOD_BOIL", "DK_ANTI_MAGIC_SHELL" },
						mechanics = {
							"Blood Boil — 15-stud AoE every 12s.",
							"Anti-Magic Shell — immune to magic 8s, 45s CD.",
						},
					},
					{
						phaseIndex = 3, label = "Army of the Dead",
						hpThreshold = 0.25,
						dialogue = "Rise, my soldiers! RISE!",
						newAbilities = { "DK_ARMY_OF_THE_DEAD" },
						mechanics = {
							"Army of the Dead — spawns 8 skeleton warriors.",
							"Blood Boil now pulses every 8s.",
						},
					},
				},
				lootTable = {
					"death_knight_pauldrons", "valdrath_great_sword",
					"anti_magic_pendant", "blood_rune_belt",
				},
			},
		},
	},

	raid_nazarick_sanctum = {
		id = "raid_nazarick_sanctum",
		displayName = "Nazarick Sanctum",
		description = "The inner sanctum of Nazarick. A Lich lord and the Supreme Overlord's avatar guard the deepest secrets.",
		minLevel    = 55,
		minTombTier = 5,
		minRaidSize = 20,
		bosses = {
			{
				id = "BOSS_LICH_LORD", name = "Archlich Serathas",
				size = "Large", baseHealth = 4000000, baseDamage = 1400,
				enrageTimer = 540,
				abilities = { "LICH_FROST_LANCE", "LICH_DEATH_COIL" },
				phases = {
					{
						phaseIndex = 1, label = "Frost Dominion",
						hpThreshold = 1.0,
						dialogue = "My phylactery renders me eternal. You are wasting what little life you have.",
						newAbilities = {}, mechanics = { "Frost Lance — targeted spell, 5s CD." },
					},
					{
						phaseIndex = 2, label = "Blizzard's Eye",
						hpThreshold = 0.60,
						dialogue = "The cold does not discriminate!",
						newAbilities = { "LICH_BLIZZARD", "LICH_FROZEN_ORB" },
						mechanics = {
							"Blizzard — persistent AoE zone, 15s duration.",
							"Frozen Orb — travels across room, 20-stud AoE on impact.",
						},
					},
					{
						phaseIndex = 3, label = "Phylactery's Return",
						hpThreshold = 0.20,
						dialogue = "Destroy me and I simply begin again. Can you afford to wait?",
						newAbilities = { "LICH_PHYLACTERY_RECALL" },
						mechanics = {
							"Phylactery Recall — heals 15% HP; destroyable object spawns at room edge.",
							"Blizzard covers 70% of arena at Phase 3.",
						},
					},
				},
				lootTable = {
					"archlich_crown", "phylactery_shard_ring",
					"frost_rune_staff", "serathas_eternal_cloak",
				},
			},
		},
	},
}

--------------------------------------------------------------------------------
-- CONFIG MODULE
--------------------------------------------------------------------------------

local RaidConfig = {}
RaidConfig.Raids          = Raids
RaidConfig.DifficultyTiers = DifficultyTiers
RaidConfig.RaidSizes      = { 10, 25, 40 }
RaidConfig.LockoutDuration = 604800

RaidConfig.BonusRollCurrency = {
	Name = "Spectral Coins", MaxPerLockout = 3,
	AcquiredFrom = { "World Quests", "Daily Dungeons", "Weekly Cache" },
}

function RaidConfig.GetRaid(raidId: string): RaidDef?
	return Raids[raidId]
end

function RaidConfig.GetDifficulty(difficulty: string): DifficultyDef?
	return DifficultyTiers[difficulty]
end

function RaidConfig.GetBoss(raidId: string, bossId: string): BossConf?
	local raidDef = Raids[raidId]
	if not raidDef then return nil end
	for _, boss in ipairs(raidDef.bosses) do
		if boss.id == bossId then return boss end
	end
	return nil
end

--- Возвращает фазу для текущего значения HP (hpFraction = 0.0–1.0).
--- Переходит в следующую фазу когда HP опускается ниже hpThreshold.
--- Возвращает фазу с наименьшим phaseIndex, чей порог ещё не достигнут.
function RaidConfig.GetBossPhase(bossConf: BossConf, hpFraction: number): BossPhase?
	if type(bossConf.phases) ~= "table" then return nil end
	local result: BossPhase? = nil
	for _, phase in ipairs(bossConf.phases) do
		if hpFraction <= phase.hpThreshold then
			-- Берём фазу с наибольшим phaseIndex среди прошедших порог
			if not result or phase.phaseIndex > result.phaseIndex then
				result = phase
			end
		end
	end
	-- Фаза 1 всегда активна (порог 1.0), возвращаем её как базовую
	if not result and #bossConf.phases > 0 then
		return bossConf.phases[1]
	end
	return result
end

function RaidConfig.GetAllRaids(): { RaidDef }
	local out: { RaidDef } = {}
	for _, def in pairs(Raids) do table.insert(out, def) end
	table.sort(out, function(a, b) return a.minLevel < b.minLevel end)
	return out
end

return RaidConfig
