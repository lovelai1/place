--!strict
--------------------------------------------------------------------------------
-- GhostyRPG | GuardianConfig.lua
-- ReplicatedStorage/Shared/Config/GuardianConfig.lua
--------------------------------------------------------------------------------

export type AbilityRef = {
	abilityId : string,
	cooldown  : number,
}

export type GuardianDef = {
	guardianId     : string,
	displayName    : string,
	description    : string,
	icon           : string,
	minTombTier    : number,
	hireCost       : number,
	weeklyUpkeep   : number,
	maxHealth      : number,
	damage         : number,
	armor          : number,
	moveSpeed      : number,
	aggroRange     : number,
	attackRange    : number,
	leashRange     : number,
	abilities      : { AbilityRef },
	patrolRadius   : number,
	patrolSpeed    : number,
	lore           : string,
}

local Guardians: { [string]: GuardianDef } = {

	-- TOMB TIER 1
	SkeletonWarrior = {
		guardianId = "SkeletonWarrior", displayName = "Skeleton Warrior",
		description = "A reanimated soldier loyal to the grave. Slow but relentless.",
		icon = "💀", minTombTier = 1, hireCost = 500, weeklyUpkeep = 50,
		maxHealth = 300, damage = 28, armor = 18, moveSpeed = 12,
		aggroRange = 24, attackRange = 6, leashRange = 50,
		abilities = { { abilityId = "bone_strike", cooldown = 8 } },
		patrolRadius = 20, patrolSpeed = 10,
		lore = "Once a nameless soldier, now bound to serve whoever controls its tomb.",
	},
	PhantomSentry = {
		guardianId = "PhantomSentry", displayName = "Phantom Sentry",
		description = "A translucent spirit that drifts silently through the crypt.",
		icon = "👻", minTombTier = 1, hireCost = 750, weeklyUpkeep = 75,
		maxHealth = 200, damage = 35, armor = 8, moveSpeed = 18,
		aggroRange = 30, attackRange = 8, leashRange = 60,
		abilities = { { abilityId = "soul_drain", cooldown = 12 } },
		patrolRadius = 30, patrolSpeed = 14,
		lore = "No door stops a Phantom Sentry. It passes through stone as if it were smoke.",
	},

	-- TOMB TIER 2
	BoneArcher = {
		guardianId = "BoneArcher", displayName = "Bone Archer",
		description = "A skeletal marksman. Fires bone bolts from a distance.",
		icon = "🏹", minTombTier = 2, hireCost = 1800, weeklyUpkeep = 180,
		maxHealth = 280, damage = 42, armor = 10, moveSpeed = 14,
		aggroRange = 40, attackRange = 30, leashRange = 70,
		abilities = {
			{ abilityId = "bone_bolt",   cooldown = 5  },
			{ abilityId = "bone_volley", cooldown = 20 },
		},
		patrolRadius = 25, patrolSpeed = 12,
		lore = "Its empty sockets aim with uncanny precision. Living archers envy its stillness.",
	},
	LichServant = {
		guardianId = "LichServant", displayName = "Lich Servant",
		description = "A minor lich bound to serve a greater undead lord. Can cast curses.",
		icon = "🧙", minTombTier = 2, hireCost = 3500, weeklyUpkeep = 350,
		maxHealth = 240, damage = 55, armor = 12, moveSpeed = 13,
		aggroRange = 35, attackRange = 20, leashRange = 65,
		abilities = {
			{ abilityId = "necrotic_bolt",  cooldown = 6  },
			{ abilityId = "curse_weakness", cooldown = 18 },
		},
		patrolRadius = 20, patrolSpeed = 11,
		lore = "It whispers dark incantations that have eroded its own memories. Only loyalty to its master remains.",
	},

	-- TOMB TIER 3
	DeathKnightGuard = {
		guardianId = "DeathKnightGuard", displayName = "Death Knight Guard",
		description = "A fallen paladin reforged by dark magic. Fearsome in melee combat.",
		icon = "⚔️", minTombTier = 3, hireCost = 9000, weeklyUpkeep = 900,
		maxHealth = 700, damage = 75, armor = 45, moveSpeed = 14,
		aggroRange = 28, attackRange = 8, leashRange = 55,
		abilities = {
			{ abilityId = "death_grip",  cooldown = 15 },
			{ abilityId = "dark_slash",  cooldown = 8  },
			{ abilityId = "unholy_aura", cooldown = 30 },
		},
		patrolRadius = 22, patrolSpeed = 12,
		lore = "Once a champion of the light, its armour now carries the weight of every soul it condemned.",
	},
	PhantomSentinel = {
		guardianId = "PhantomSentinel", displayName = "Phantom Sentinel",
		description = "An elder phantom with powerful area debuffs. Protects an entire hall.",
		icon = "🌀", minTombTier = 3, hireCost = 12000, weeklyUpkeep = 1200,
		maxHealth = 420, damage = 68, armor = 20, moveSpeed = 16,
		aggroRange = 38, attackRange = 14, leashRange = 75,
		abilities = {
			{ abilityId = "shadow_shroud", cooldown = 10 },
			{ abilityId = "phantom_wail",  cooldown = 22 },
			{ abilityId = "soul_shackle",  cooldown = 35 },
		},
		patrolRadius = 35, patrolSpeed = 15,
		lore = "The Sentinel has haunted these halls for so long it has become part of them.",
	},

	-- TOMB TIER 4
	BoneColossus = {
		guardianId = "BoneColossus", displayName = "Bone Colossus",
		description = "A towering construct assembled from thousands of bones. Hits like a siege engine.",
		icon = "🦴", minTombTier = 4, hireCost = 40000, weeklyUpkeep = 4000,
		maxHealth = 2000, damage = 120, armor = 80, moveSpeed = 9,
		aggroRange = 30, attackRange = 10, leashRange = 45,
		abilities = {
			{ abilityId = "bone_smash",     cooldown = 10 },
			{ abilityId = "bone_shockwave", cooldown = 25 },
			{ abilityId = "reconstruct",    cooldown = 60 },
		},
		patrolRadius = 15, patrolSpeed = 8,
		lore = "Every bone in this construct belonged to a warrior. Their combined strength now serves a single purpose.",
	},
	VoidWatcher = {
		guardianId = "VoidWatcher", displayName = "Void Watcher",
		description = "A creature born from the void between death and unlife. Can teleport.",
		icon = "👁️", minTombTier = 4, hireCost = 55000, weeklyUpkeep = 5500,
		maxHealth = 900, damage = 105, armor = 35, moveSpeed = 20,
		aggroRange = 45, attackRange = 18, leashRange = 90,
		abilities = {
			{ abilityId = "void_ray",   cooldown = 6  },
			{ abilityId = "void_blink", cooldown = 12 },
			{ abilityId = "void_rift",  cooldown = 40 },
		},
		patrolRadius = 40, patrolSpeed = 18,
		lore = "It does not walk through a room — it perceives every corner simultaneously.",
	},

	-- TOMB TIER 5
	SkeletonGeneral = {
		guardianId = "SkeletonGeneral", displayName = "Skeleton General",
		description = "A legendary undead commander. Buffs nearby guardians and decimates intruders.",
		icon = "🎖️", minTombTier = 5, hireCost = 180000, weeklyUpkeep = 18000,
		maxHealth = 3500, damage = 160, armor = 100, moveSpeed = 13,
		aggroRange = 35, attackRange = 10, leashRange = 60,
		abilities = {
			{ abilityId = "war_cry",         cooldown = 20 },
			{ abilityId = "bone_cleave",     cooldown = 8  },
			{ abilityId = "undying_command", cooldown = 90 },
			{ abilityId = "death_march",     cooldown = 45 },
		},
		patrolRadius = 25, patrolSpeed = 12,
		lore = "It led ten thousand dead soldiers into battle. Every one of them would follow it still.",
	},
	NazarickFloorGuardian = {
		guardianId = "NazarickFloorGuardian", displayName = "Nazarick Floor Guardian",
		description = "The legendary guardian of the deepest floor. Only the Overlord commands it.",
		icon = "♛", minTombTier = 5, hireCost = 500000, weeklyUpkeep = 50000,
		maxHealth = 8000, damage = 250, armor = 160, moveSpeed = 15,
		aggroRange = 50, attackRange = 12, leashRange = 80,
		abilities = {
			{ abilityId = "overlord_edict",  cooldown = 30  },
			{ abilityId = "floor_judgment",  cooldown = 15  },
			{ abilityId = "nazarick_wrath",  cooldown = 120 },
			{ abilityId = "absolute_domain", cooldown = 180 },
		},
		patrolRadius = 30, patrolSpeed = 14,
		lore = "To stand before the Nazarick Floor Guardian is to face the will of Overlord itself. None have survived uninvited.",
	},
}

local GuardianConfig = {}
GuardianConfig.Guardians = Guardians

function GuardianConfig.GetAvailableForTier(tombTier: number): { GuardianDef }
	local out: { GuardianDef } = {}
	for _, def in pairs(Guardians) do
		if def.minTombTier <= tombTier then table.insert(out, def) end
	end
	table.sort(out, function(a, b)
		if a.minTombTier ~= b.minTombTier then return a.minTombTier < b.minTombTier end
		return a.hireCost < b.hireCost
	end)
	return out
end

function GuardianConfig.Get(guardianId: string): GuardianDef?
	return Guardians[guardianId]
end

function GuardianConfig.GetScaledHealth(guardianId: string, tombTier: number): number
	local def = Guardians[guardianId]
	if not def then return 0 end
	return math.floor(def.maxHealth * (1 + math.max(0, tombTier - def.minTombTier) * 0.15))
end

function GuardianConfig.GetScaledDamage(guardianId: string, tombTier: number): number
	local def = Guardians[guardianId]
	if not def then return 0 end
	return math.floor(def.damage * (1 + math.max(0, tombTier - def.minTombTier) * 0.12))
end

return GuardianConfig
