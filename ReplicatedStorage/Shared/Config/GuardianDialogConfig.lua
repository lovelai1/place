--!strict
--------------------------------------------------------------------------------
-- GhostyRPG | GuardianDialogConfig.lua
-- ReplicatedStorage/Shared/Config/GuardianDialogConfig.lua
--------------------------------------------------------------------------------

export type DialogSet = {
	GreetMaster : { string },
	WarnEnemy   : { string },
	OnHit       : { string },
	OnVictory   : { string },
}

local Dialogs: { [string]: DialogSet } = {
	SkeletonWarrior = {
		GreetMaster = { "My lord. The entrance is secure.", "Your servant stands ready, master.", "None shall pass without your permission." },
		WarnEnemy   = { "Halt. You are not welcome here.", "Intruder detected. Engaging.", "This tomb belongs to the Overlord. Turn back." },
		OnHit       = { "These bones have endured worse.", "Pain means nothing to the dead.", "Strike all you like — I do not fall." },
		OnVictory   = { "The tomb is secure, my lord.", "Another intruder laid to rest.", "Threat eliminated. Returning to post." },
	},
	PhantomSentry = {
		GreetMaster = { "Overlord... I have been awaiting you.", "The halls are silent. As they should be.", "Your presence honours these shadows, my lord." },
		WarnEnemy   = { "Your soul will join the rest.", "There is no escape from a ghost you cannot touch.", "You have walked into the wrong tomb, mortal." },
		OnHit       = { "You cannot wound what has no body.", "Try harder. You'll need to.", "How amusing. You fight what you cannot see." },
		OnVictory   = { "Their screams make fine company.", "Another soul for the master's collection.", "The living always underestimate the dead." },
	},
	BoneArcher = {
		GreetMaster = { "My aim is yours, master.", "Every arrow flies in your name, my lord.", "The corridor is watched. Nothing moves unseen." },
		WarnEnemy   = { "Step closer. My aim improves at this range.", "Target acquired. You won't hear the arrow.", "I have never missed. I do not intend to start." },
		OnHit       = { "A lucky shot. It won't happen again.", "You only slowed me down.", "My bones splinter. My aim does not." },
		OnVictory   = { "The range was good today.", "Back to post. The quiver is restocked.", "A clean kill. As expected." },
	},
	LichServant = {
		GreetMaster = { "Great Overlord. Your libraries are undisturbed.", "I have prepared fresh reagents, master. Shall I begin?", "The dark arts serve your will, my lord." },
		WarnEnemy   = { "Mortal flesh rots. Your flesh rots faster.", "You dare enter a place of power you cannot comprehend?", "I will curse your bloodline three generations deep." },
		OnHit       = { "That disrupted my concentration. You will regret it.", "Flesh wound. My concentration holds.", "Fool. Pain sharpens my focus." },
		OnVictory   = { "Their life force has been... catalogued.", "A new specimen for study. Excellent.", "The Overlord's knowledge grows with each defeat." },
	},
	DeathKnightGuard = {
		GreetMaster = { "My Overlord. I am your sword and your shield.", "The throne room is protected with my life — and my unlife.", "Command me, master. I hunger for worthy opponents." },
		WarnEnemy   = { "You walk into the darkness willingly. I respect that. Briefly.", "Draw your blade. I will give you a warrior's death.", "The last hero who entered here became part of my armour." },
		OnHit       = { "Good. I was getting bored.", "You fight with conviction. It won't save you.", "That would have killed me once. Not anymore." },
		OnVictory   = { "A worthy duel. They will make a fine ghost.", "The Overlord's halls remain unbreached.", "I add their memory to my ledger of victories." },
	},
	PhantomSentinel = {
		GreetMaster = { "My Overlord. The spectral ward is intact.", "Your dominion over death is... inspiring, master.", "I have haunted this hall for centuries. You are the first worthy master." },
		WarnEnemy   = { "You feel the cold? That is my warning. The next sensation is worse.", "Every shadow in this corridor is my eye. You were seen the moment you entered.", "The Sentinel does not sleep. It does not tire. You do." },
		OnHit       = { "You wounded the air.", "A phantom cannot be killed twice.", "Strike stone. Strike air. Strike me. The result is the same." },
		OnVictory   = { "The hall is quiet again. As I prefer.", "Their echoes will haunt this corridor. They will serve us well.", "The Overlord's domain expands with every soul taken." },
	},
	BoneColossus = {
		GreetMaster = { "MASTER. HALL SECURE.", "COLOSSUS READY. NO INTRUDERS.", "YOUR WILL. MY PURPOSE." },
		WarnEnemy   = { "SMALL CREATURE DETECTED. ENGAGING.", "YOU STAND BEFORE THE COLOSSUS. THIS IS YOUR FINAL MOMENT.", "RESISTANCE IS RECORDED AS AMUSING." },
		OnHit       = { "INEFFECTIVE.", "STRUCTURAL INTEGRITY: 97%. CONTINUE IF YOU WISH.", "NOTED." },
		OnVictory   = { "THREAT LEVEL ZERO. RESUMING PATROL.", "STRUCTURAL INTEGRITY SUFFICIENT. MISSION COMPLETE.", "MASTER'S TOMB SECURE. AS ALWAYS." },
	},
	VoidWatcher = {
		GreetMaster = { "Overlord. I perceive you from all angles simultaneously.", "Your return has been... anticipated, master. From eleven directions.", "The void between life and death whispers your name, my lord." },
		WarnEnemy   = { "I see you. All of you. Every version across every angle.", "You cannot hide. Space itself reports to me.", "From where I stand, you are already defeated." },
		OnHit       = { "You struck a shadow.", "This dimension or the adjacent one? Either way, irrelevant.", "Your weapon met my echo. I am elsewhere." },
		OnVictory   = { "The probability of your survival was... zero point zero.", "Their light has blinked out. The void absorbs all.", "Another point of data collected for the Overlord." },
	},
	SkeletonGeneral = {
		GreetMaster = { "My Overlord. Ten thousand dead soldiers salute you through me.", "Your army of the undead awaits your command, master.", "The General reports: all floors secured, all guardians at post." },
		WarnEnemy   = { "I have routed living armies. You are one person.", "You face a general who has never known defeat — because I cannot die twice.", "Sound the alarm. Let them feel the weight of an undead legion." },
		OnHit       = { "A scratch. My soldiers endured far worse.", "You land blows well. Pity your strategy is lacking.", "Wound the General? History records no such thing." },
		OnVictory   = { "Victory secured. As expected. As always.", "The Overlord's tomb has never fallen. It never will.", "I add this engagement to the annals. Another footnote." },
	},
	NazarickFloorGuardian = {
		GreetMaster = { "Supreme Overlord. Your absolute dominion is acknowledged and honoured.", "My existence is your will made manifest, master. Command, and it is done.", "The deepest floor of Nazarick bows to you alone, great Overlord." },
		WarnEnemy   = { "You have breached the final floor of Nazarick. This is not an achievement. It is a sentence.", "There is no hierarchy of threat you could summon that equals what you face now.", "The Supreme Overlord built this tomb as a statement. You are the punctuation." },
		OnHit       = { "You have my full attention now. That is a privilege I rarely grant.", "A commendable attempt. Your epitaph will include the word 'brave'.", "So you have some power. Curious. Futile, but curious." },
		OnVictory   = { "Nazarick endures. As it always has. As it always will.", "The Supreme Overlord's dominion is absolute. This was never in question.", "Their name will be inscribed in the hall of those who dared. A short hall." },
	},
}

local GuardianDialogConfig = {}
GuardianDialogConfig.Dialogs = Dialogs

function GuardianDialogConfig.GetLine(
	guardianId : string,
	category   : "GreetMaster" | "WarnEnemy" | "OnHit" | "OnVictory"
): string
	local set = Dialogs[guardianId]
	if not set then
		if category == "GreetMaster" then return "The guardian stands ready." end
		if category == "WarnEnemy"   then return "Intruder detected." end
		if category == "OnHit"       then return "..." end
		return "Threat eliminated."
	end
	local lines: { string } = (set :: any)[category] or {}
	if #lines == 0 then return "..." end
	return lines[math.random(1, #lines)]
end

function GuardianDialogConfig.GetAll(guardianId: string): DialogSet?
	return Dialogs[guardianId]
end

return GuardianDialogConfig
