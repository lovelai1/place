--!strict

local GameEnums = {}

export type Role = "Tank" | "Healer" | "DPS"
export type Class = "Warrior" | "Paladin" | "Mage" | "Priest" | "Rogue" | "Hunter"
export type DamageType = "Physical" | "Magic" | "Fire" | "Frost" | "Nature" | "Shadow" | "Holy"
export type ResourceType = "Mana" | "Rage" | "Energy" | "HolyPower" | "Focus"
export type Profession = "Mining" | "Alchemy"
export type DungeonDifficulty = "Normal" | "Heroic" | "Mythic"
export type ItemRarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Artifact"
export type StatType = "Strength" | "Agility" | "Intellect" | "Stamina" | "Spirit"
export type EquipmentSlot = "Head" | "Shoulders" | "Chest" | "Legs" | "Feet" | "Hands" | "Waist" | "Wrist" | "Back" | "MainHand" | "OffHand" | "Ranged" | "Necklace" | "Ring1" | "Ring2" | "Trinket1" | "Trinket2"

GameEnums.Role = { Tank = "Tank" :: Role, Healer = "Healer" :: Role, DPS = "DPS" :: Role }
GameEnums.Class = { Warrior = "Warrior" :: Class, Paladin = "Paladin" :: Class, Mage = "Mage" :: Class, Priest = "Priest" :: Class, Rogue = "Rogue" :: Class, Hunter = "Hunter" :: Class }
GameEnums.DamageType = { Physical = "Physical" :: DamageType, Magic = "Magic" :: DamageType, Fire = "Fire" :: DamageType, Frost = "Frost" :: DamageType, Nature = "Nature" :: DamageType, Shadow = "Shadow" :: DamageType, Holy = "Holy" :: DamageType }
GameEnums.ResourceType = { Mana = "Mana" :: ResourceType, Rage = "Rage" :: ResourceType, Energy = "Energy" :: ResourceType, HolyPower = "HolyPower" :: ResourceType, Focus = "Focus" :: ResourceType }
GameEnums.Profession = { Mining = "Mining" :: Profession, Alchemy = "Alchemy" :: Profession }
GameEnums.DungeonDifficulty = { Normal = "Normal" :: DungeonDifficulty, Heroic = "Heroic" :: DungeonDifficulty, Mythic = "Mythic" :: DungeonDifficulty }
GameEnums.ItemRarity = { Common = "Common" :: ItemRarity, Uncommon = "Uncommon" :: ItemRarity, Rare = "Rare" :: ItemRarity, Epic = "Epic" :: ItemRarity, Legendary = "Legendary" :: ItemRarity, Artifact = "Artifact" :: ItemRarity }
GameEnums.StatType = { Strength = "Strength" :: StatType, Agility = "Agility" :: StatType, Intellect = "Intellect" :: StatType, Stamina = "Stamina" :: StatType, Spirit = "Spirit" :: StatType }
GameEnums.EquipmentSlot = { Head = "Head" :: EquipmentSlot, Shoulders = "Shoulders" :: EquipmentSlot, Chest = "Chest" :: EquipmentSlot, Legs = "Legs" :: EquipmentSlot, Feet = "Feet" :: EquipmentSlot, Hands = "Hands" :: EquipmentSlot, Waist = "Waist" :: EquipmentSlot, Wrist = "Wrist" :: EquipmentSlot, Back = "Back" :: EquipmentSlot, MainHand = "MainHand" :: EquipmentSlot, OffHand = "OffHand" :: EquipmentSlot, Ranged = "Ranged" :: EquipmentSlot, Necklace = "Necklace" :: EquipmentSlot, Ring1 = "Ring1" :: EquipmentSlot, Ring2 = "Ring2" :: EquipmentSlot, Trinket1 = "Trinket1" :: EquipmentSlot, Trinket2 = "Trinket2" :: EquipmentSlot }

GameEnums.QuestStatus = { Active = "Active", ReadyToTurnIn = "ReadyToTurnIn", TurnedIn = "TurnedIn", Abandoned = "Abandoned", Failed = "Failed" }
GameEnums.QuestObjectiveType = { Kill = "Kill", Collect = "Collect", Talk = "Talk", Explore = "Explore", Craft = "Craft", Escort = "Escort" }

return GameEnums
