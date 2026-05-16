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
