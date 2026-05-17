--!strict
-- Public item catalog for GhostyRPG. Safe to require on client and server.
-- Contains item metadata only; drop rates and reward rules stay server-side.

local ItemConfig = {}

ItemConfig.ItemType = {
	Consumable = "Consumable",
	Material = "Material",
	Weapon = "Weapon",
	Armor = "Armor",
	Trinket = "Trinket",
	Quest = "Quest",
	Currency = "Currency",
}

ItemConfig.Rarity = {
	Common = "Common",
	Uncommon = "Uncommon",
	Rare = "Rare",
	Epic = "Epic",
	Legendary = "Legendary",
	Artifact = "Artifact",
}

ItemConfig.EquipmentSlot = {
	Head = "Head",
	Shoulders = "Shoulders",
	Chest = "Chest",
	Legs = "Legs",
	Feet = "Feet",
	Hands = "Hands",
	Waist = "Waist",
	Wrist = "Wrist",
	Back = "Back",
	MainHand = "MainHand",
	OffHand = "OffHand",
	Ranged = "Ranged",
	Necklace = "Necklace",
	Ring1 = "Ring1",
	Ring2 = "Ring2",
	Trinket1 = "Trinket1",
	Trinket2 = "Trinket2",
}

export type ItemDef = {
	itemId: string,
	name: string,
	description: string,
	itemType: string,
	rarity: string,
	stackable: boolean,
	maxStack: number,
	tradable: boolean,
	bindOnPickup: boolean,
	vendorPrice: number,
	requiredLevel: number,
	itemLevel: number,
	equipSlot: string?,
	statBonuses: { [string]: number }?,
}

local CATALOG: { [string]: ItemDef } = {
	item_health_potion = { itemId = "item_health_potion", name = "Health Potion", description = "Restores a modest amount of health.", itemType = "Consumable", rarity = "Common", stackable = true, maxStack = 99, tradable = true, bindOnPickup = false, vendorPrice = 10, requiredLevel = 1, itemLevel = 1, equipSlot = nil, statBonuses = nil },
	item_mana_potion = { itemId = "item_mana_potion", name = "Mana Potion", description = "Restores a modest amount of mana or class resource.", itemType = "Consumable", rarity = "Common", stackable = true, maxStack = 99, tradable = true, bindOnPickup = false, vendorPrice = 10, requiredLevel = 1, itemLevel = 1, equipSlot = nil, statBonuses = nil },
	item_mistleaf = { itemId = "item_mistleaf", name = "Mistleaf", description = "A pale herb gathered from fog-soaked groves.", itemType = "Material", rarity = "Common", stackable = true, maxStack = 200, tradable = true, bindOnPickup = false, vendorPrice = 3, requiredLevel = 1, itemLevel = 1, equipSlot = nil, statBonuses = nil },
	item_bone_fragment = { itemId = "item_bone_fragment", name = "Bone Fragment", description = "Brittle remains from restless undead.", itemType = "Material", rarity = "Common", stackable = true, maxStack = 200, tradable = true, bindOnPickup = false, vendorPrice = 2, requiredLevel = 1, itemLevel = 1, equipSlot = nil, statBonuses = nil },
	copper_ore = { itemId = "copper_ore", name = "Copper Ore", description = "Rough ore used by beginner miners and smiths.", itemType = "Material", rarity = "Common", stackable = true, maxStack = 200, tradable = true, bindOnPickup = false, vendorPrice = 5, requiredLevel = 1, itemLevel = 1, equipSlot = nil, statBonuses = nil },
	empty_vial = { itemId = "empty_vial", name = "Empty Vial", description = "A simple vial used in alchemy recipes.", itemType = "Material", rarity = "Common", stackable = true, maxStack = 50, tradable = true, bindOnPickup = false, vendorPrice = 2, requiredLevel = 1, itemLevel = 1, equipSlot = nil, statBonuses = nil },

	item_goblin_dagger = { itemId = "item_goblin_dagger", name = "Grave Goblin Dagger", description = "A crude but sharp dagger chipped from grave-flint.", itemType = "Weapon", rarity = "Common", stackable = false, maxStack = 1, tradable = true, bindOnPickup = false, vendorPrice = 25, requiredLevel = 1, itemLevel = 2, equipSlot = "MainHand", statBonuses = { AttackPower = 4, Agility = 1 } },
	starter_sword = { itemId = "starter_sword", name = "Starter Sword", description = "A reliable blade issued to new adventurers.", itemType = "Weapon", rarity = "Common", stackable = false, maxStack = 1, tradable = false, bindOnPickup = true, vendorPrice = 0, requiredLevel = 1, itemLevel = 1, equipSlot = "MainHand", statBonuses = { AttackPower = 3 } },
	starter_staff = { itemId = "starter_staff", name = "Starter Staff", description = "A spirit-carved staff for novice casters and healers.", itemType = "Weapon", rarity = "Common", stackable = false, maxStack = 1, tradable = false, bindOnPickup = true, vendorPrice = 0, requiredLevel = 1, itemLevel = 1, equipSlot = "MainHand", statBonuses = { SpellPower = 3, Intellect = 1 } },
	starter_shield = { itemId = "starter_shield", name = "Starter Shield", description = "A battered wooden buckler for new tanks.", itemType = "Armor", rarity = "Common", stackable = false, maxStack = 1, tradable = false, bindOnPickup = true, vendorPrice = 0, requiredLevel = 1, itemLevel = 1, equipSlot = "OffHand", statBonuses = { Armor = 8, Stamina = 1 } },
	item_iron_guard_vest = { itemId = "item_iron_guard_vest", name = "Iron Guard Vest", description = "Dented iron plating once worn by a crypt guard.", itemType = "Armor", rarity = "Uncommon", stackable = false, maxStack = 1, tradable = true, bindOnPickup = false, vendorPrice = 80, requiredLevel = 3, itemLevel = 5, equipSlot = "Chest", statBonuses = { Armor = 30, Stamina = 3 } },
	item_crypt_key = { itemId = "item_crypt_key", name = "Crypt Key", description = "A cold iron key etched with a warning not to open the crypt at night.", itemType = "Quest", rarity = "Common", stackable = false, maxStack = 1, tradable = false, bindOnPickup = true, vendorPrice = 0, requiredLevel = 1, itemLevel = 1, equipSlot = nil, statBonuses = nil },

	-- ── Phase 4 materials ─────────────────────────────────────────────────
	item_spectral_fang    = { itemId="item_spectral_fang",    name="Spectral Fang",       description="A ghostly fang that phases in and out of solidity.",         itemType="Material", rarity="Common",   stackable=true,  maxStack=200, tradable=true, bindOnPickup=false, vendorPrice=8,   requiredLevel=1, itemLevel=1, equipSlot=nil, statBonuses=nil },
	item_ghost_pelt       = { itemId="item_ghost_pelt",       name="Ghost Pelt",           description="Translucent fur that shimmers in moonlight.",                 itemType="Material", rarity="Common",   stackable=true,  maxStack=200, tradable=true, bindOnPickup=false, vendorPrice=12,  requiredLevel=1, itemLevel=1, equipSlot=nil, statBonuses=nil },
	item_revenant_shard   = { itemId="item_revenant_shard",   name="Revenant Shard",       description="A crystallised fragment of bound undead energy.",             itemType="Material", rarity="Uncommon", stackable=true,  maxStack=200, tradable=true, bindOnPickup=false, vendorPrice=18,  requiredLevel=1, itemLevel=1, equipSlot=nil, statBonuses=nil },
	item_mist_essence     = { itemId="item_mist_essence",     name="Mist Essence",         description="Bottled fog that hums with faint elemental power.",           itemType="Material", rarity="Common",   stackable=true,  maxStack=200, tradable=true, bindOnPickup=false, vendorPrice=10,  requiredLevel=1, itemLevel=1, equipSlot=nil, statBonuses=nil },
	item_bone_arrow       = { itemId="item_bone_arrow",       name="Bone Arrow",           description="Arrows fashioned from skeletal remains. Sharp despite age.",   itemType="Material", rarity="Common",   stackable=true,  maxStack=500, tradable=true, bindOnPickup=false, vendorPrice=1,   requiredLevel=1, itemLevel=1, equipSlot=nil, statBonuses=nil },
	item_cursed_bark      = { itemId="item_cursed_bark",      name="Cursed Bark",          description="Dark bark seeping with blight-energy.",                       itemType="Material", rarity="Common",   stackable=true,  maxStack=200, tradable=true, bindOnPickup=false, vendorPrice=7,   requiredLevel=1, itemLevel=1, equipSlot=nil, statBonuses=nil },
	item_wraith_essence   = { itemId="item_wraith_essence",   name="Wraith Essence",       description="A swirling vial of compressed wraith-life force.",            itemType="Material", rarity="Uncommon", stackable=true,  maxStack=200, tradable=true, bindOnPickup=false, vendorPrice=22,  requiredLevel=1, itemLevel=1, equipSlot=nil, statBonuses=nil },
	item_spectral_binding = { itemId="item_spectral_binding", name="Spectral Binding",     description="A strand of condensed spectral energy used in enchanting.",   itemType="Material", rarity="Uncommon", stackable=true,  maxStack=100, tradable=true, bindOnPickup=false, vendorPrice=30,  requiredLevel=1, itemLevel=1, equipSlot=nil, statBonuses=nil },
	item_dryad_tear       = { itemId="item_dryad_tear",       name="Dryad's Tear",         description="A crystallised teardrop from a corrupted forest dryad.",      itemType="Material", rarity="Uncommon", stackable=true,  maxStack=100, tradable=true, bindOnPickup=false, vendorPrice=25,  requiredLevel=1, itemLevel=1, equipSlot=nil, statBonuses=nil },
	item_guardian_heartwood={ itemId="item_guardian_heartwood",name="Guardian Heartwood",  description="The pulsing core ripped from a Root Guardian.",               itemType="Material", rarity="Rare",     stackable=true,  maxStack=10,  tradable=true, bindOnPickup=false, vendorPrice=120, requiredLevel=1, itemLevel=1, equipSlot=nil, statBonuses=nil },
	item_heartwood_core   = { itemId="item_heartwood_core",   name="Heartwood Core",       description="A legendary core pulsing with the heart of the Mistwood.",   itemType="Material", rarity="Epic",     stackable=true,  maxStack=5,   tradable=true, bindOnPickup=false, vendorPrice=300, requiredLevel=1, itemLevel=1, equipSlot=nil, statBonuses=nil },
	item_shaman_totem     = { itemId="item_shaman_totem",     name="Shaman Totem",         description="A fetish of power carved by the Goblin Shaman.",             itemType="Material", rarity="Uncommon", stackable=true,  maxStack=20,  tradable=true, bindOnPickup=false, vendorPrice=40,  requiredLevel=1, itemLevel=1, equipSlot=nil, statBonuses=nil },
	item_lich_phylactery  = { itemId="item_lich_phylactery",  name="Lich Phylactery",      description="A shard of the lich's life vessel. Still faintly warm.",      itemType="Material", rarity="Rare",     stackable=true,  maxStack=5,   tradable=true, bindOnPickup=false, vendorPrice=200, requiredLevel=1, itemLevel=1, equipSlot=nil, statBonuses=nil },
	item_alpha_fang       = { itemId="item_alpha_fang",       name="Alpha Fang",           description="The massive fang of a Phantom Alpha. Radiates cold light.",   itemType="Material", rarity="Rare",     stackable=false, maxStack=1,   tradable=true, bindOnPickup=false, vendorPrice=150, requiredLevel=1, itemLevel=1, equipSlot=nil, statBonuses=nil },
	item_shadow_cloth_wrap= { itemId="item_shadow_cloth_wrap",name="Shadow Cloth Wrap",    description="Cloth woven from shadow-thread dropped by revenants.",        itemType="Material", rarity="Uncommon", stackable=true,  maxStack=50,  tradable=true, bindOnPickup=false, vendorPrice=35,  requiredLevel=1, itemLevel=1, equipSlot=nil, statBonuses=nil },

	-- ── Phase 4 equipment ─────────────────────────────────────────────────
	item_sturdy_helmet      = { itemId="item_sturdy_helmet",      name="Sturdy Helmet",         description="A battered but solid iron helm from the Mistwood mine.",  itemType="Armor",  rarity="Uncommon", stackable=false, maxStack=1, tradable=true, bindOnPickup=false, vendorPrice=90,  requiredLevel=5,  itemLevel=7,  equipSlot="Head",     statBonuses={ Armor=22, Stamina=4 } },
	item_knight_pauldrons   = { itemId="item_knight_pauldrons",   name="Knight Pauldrons",      description="Heavy shoulder plates from a fallen Skeleton Knight.",     itemType="Armor",  rarity="Rare",     stackable=false, maxStack=1, tradable=true, bindOnPickup=false, vendorPrice=180, requiredLevel=10, itemLevel=12, equipSlot="Shoulders",statBonuses={ Armor=55, Stamina=8, Strength=4 } },
	item_mistwood_staff     = { itemId="item_mistwood_staff",     name="Mistwood Staff",        description="A staff carved from living Mistwood, warm to the touch.", itemType="Weapon", rarity="Rare",     stackable=false, maxStack=1, tradable=true, bindOnPickup=false, vendorPrice=220, requiredLevel=12, itemLevel=14, equipSlot="MainHand", statBonuses={ SpellPower=35, Intellect=8, Spirit=5 } },
	item_mistwood_crown     = { itemId="item_mistwood_crown",     name="Mistwood Crown",        description="A circlet of living wood and mist, pulsing with power.",  itemType="Armor",  rarity="Epic",     stackable=false, maxStack=1, tradable=true, bindOnPickup=false, vendorPrice=450, requiredLevel=15, itemLevel=18, equipSlot="Head",     statBonuses={ Armor=35, Intellect=15, SpellPower=20, Spirit=10 } },
}

function ItemConfig.GetItem(itemId: string): ItemDef?
	return CATALOG[itemId]
end

function ItemConfig.IsValidItem(itemId: string): boolean
	return CATALOG[itemId] ~= nil
end

function ItemConfig.IsStackable(itemId: string): boolean
	local item = CATALOG[itemId]
	return item ~= nil and item.stackable
end

function ItemConfig.GetMaxStack(itemId: string): number
	local item = CATALOG[itemId]
	if not item then
		return 1
	end
	return math.max(1, item.maxStack)
end

function ItemConfig.CanEquip(itemId: string): boolean
	local item = CATALOG[itemId]
	return item ~= nil and item.equipSlot ~= nil
end

function ItemConfig.GetEquipmentSlot(itemId: string): string?
	local item = CATALOG[itemId]
	if not item then
		return nil
	end
	return item.equipSlot
end

return ItemConfig
