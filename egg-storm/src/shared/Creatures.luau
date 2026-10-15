--!strict
-- Creatures: el catálogo de mascotas que pueden salir de cada huevo.
-- Cuando sale un huevo de cierta rareza, se elige una de sus mascotas al azar (todas con la misma chance).
-- La plata por segundo NO va acá: la define la rareza en Config.Rarities.
-- Style elige la forma del modelo placeholder: "Blob", "Bunny", "Cat", "Bird" o "Dragon".

export type Style = "Blob" | "Bunny" | "Cat" | "Bird" | "Dragon"

export type Creature = {
	Id: string, -- identificador interno (no cambiar una vez que haya datos guardados)
	DisplayName: string,
	RarityId: string,
	Color: Color3,
	Style: Style,
}

local Creatures = {}

Creatures.List = {
	-- Common
	{ Id = "SandBunny", DisplayName = "Sand Bunny", RarityId = "Common", Color = Color3.fromRGB(235, 205, 150), Style = "Bunny" },
	{ Id = "PuddleBlob", DisplayName = "Puddle Blob", RarityId = "Common", Color = Color3.fromRGB(150, 210, 255), Style = "Blob" },
	{ Id = "BeachChick", DisplayName = "Beach Chick", RarityId = "Common", Color = Color3.fromRGB(255, 230, 90), Style = "Bird" },
	-- Rare
	{ Id = "CoralCat", DisplayName = "Coral Cat", RarityId = "Rare", Color = Color3.fromRGB(255, 120, 110), Style = "Cat" },
	{ Id = "WaveBunny", DisplayName = "Wave Bunny", RarityId = "Rare", Color = Color3.fromRGB(70, 140, 255), Style = "Bunny" },
	{ Id = "BubbleBlob", DisplayName = "Bubble Blob", RarityId = "Rare", Color = Color3.fromRGB(90, 230, 220), Style = "Blob" },
	-- Epic
	{ Id = "StormOwl", DisplayName = "Storm Owl", RarityId = "Epic", Color = Color3.fromRGB(150, 90, 230), Style = "Bird" },
	{ Id = "ThunderCat", DisplayName = "Thunder Cat", RarityId = "Epic", Color = Color3.fromRGB(110, 80, 200), Style = "Cat" },
	{ Id = "MistDragon", DisplayName = "Mist Dragon", RarityId = "Epic", Color = Color3.fromRGB(200, 170, 255), Style = "Dragon" },
	-- Legendary
	{ Id = "GoldenDragon", DisplayName = "Golden Dragon", RarityId = "Legendary", Color = Color3.fromRGB(255, 200, 40), Style = "Dragon" },
	{ Id = "SunPhoenix", DisplayName = "Sun Phoenix", RarityId = "Legendary", Color = Color3.fromRGB(255, 120, 30), Style = "Bird" },
	-- Secret
	{ Id = "RainbowLeviathan", DisplayName = "Rainbow Leviathan", RarityId = "Secret", Color = Color3.fromRGB(25, 25, 35), Style = "Dragon" },
	{ Id = "VoidCat", DisplayName = "Void Cat", RarityId = "Secret", Color = Color3.fromRGB(15, 10, 25), Style = "Cat" },
} :: { Creature }

local byId: { [string]: Creature } = {}
for _, creature in Creatures.List do
	byId[creature.Id] = creature
end

function Creatures.Get(id: string): Creature?
	return byId[id]
end

function Creatures.ForRarity(rarityId: string): { Creature }
	local result = {}
	for _, creature in Creatures.List do
		if creature.RarityId == rarityId then
			table.insert(result, creature)
		end
	end
	return result
end

return Creatures
