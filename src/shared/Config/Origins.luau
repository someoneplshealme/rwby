--!strict
--[[
	Where your Huntsman comes from: kingdom of origin, Human or Faunus heritage, and the
	signature colour that tints your aura, emblem and weapon trim.
]]

export type Kingdom = {
	id: string,
	name: string,
	motto: string,
	bonus: string,
	modifiers: { [string]: number },
}

export type FaunusTrait = {
	id: string,
	name: string,
}

export type SignatureColor = {
	id: string,
	name: string,
	color: Color3,
}

local Origins = {}

Origins.Kingdoms = {
	{
		id = "Vale",
		name = "Vale",
		motto = "The kingdom of balance and Beacon Academy.",
		bonus = "+6% max Aura",
		modifiers = { aura = 0.06 },
	},
	{
		id = "Atlas",
		name = "Atlas",
		motto = "Technology, discipline and the finest Dust.",
		bonus = "+8% Dust damage",
		modifiers = { dust = 0.08 },
	},
	{
		id = "Mistral",
		name = "Mistral",
		motto = "Tournaments, tradition and polished technique.",
		bonus = "+6% posture damage",
		modifiers = { posture = 0.06 },
	},
	{
		id = "Vacuo",
		name = "Vacuo",
		motto = "If you can survive in Vacuo, you can attend.",
		bonus = "+6% max Health",
		modifiers = { health = 0.06 },
	},
} :: { Kingdom }

Origins.FaunusTraits = {
	{ id = "Cat", name = "Cat ears" },
	{ id = "Wolf", name = "Wolf ears & tail" },
	{ id = "Rabbit", name = "Rabbit ears" },
	{ id = "Fox", name = "Fox ears & tail" },
	{ id = "Bull", name = "Bull horns" },
} :: { FaunusTrait }

Origins.FaunusBonus = "+4% movement speed and keen night vision"

Origins.Colors = {
	{ id = "Rose", name = "Rose", color = Color3.fromRGB(204, 28, 58) },
	{ id = "Snow", name = "Snow", color = Color3.fromRGB(226, 238, 255) },
	{ id = "Shadow", name = "Shadow", color = Color3.fromRGB(58, 50, 74) },
	{ id = "Sunflare", name = "Sunflare", color = Color3.fromRGB(255, 194, 40) },
	{ id = "Jade", name = "Jade", color = Color3.fromRGB(48, 168, 96) },
	{ id = "Azure", name = "Azure", color = Color3.fromRGB(44, 116, 228) },
	{ id = "Amethyst", name = "Amethyst", color = Color3.fromRGB(138, 64, 210) },
	{ id = "Bronze", name = "Bronze", color = Color3.fromRGB(196, 124, 52) },
	{ id = "Crimson", name = "Crimson", color = Color3.fromRGB(150, 12, 24) },
	{ id = "Teal", name = "Teal", color = Color3.fromRGB(28, 176, 176) },
	{ id = "Coral", name = "Coral", color = Color3.fromRGB(255, 118, 98) },
	{ id = "Ivory", name = "Ivory", color = Color3.fromRGB(240, 228, 198) },
} :: { SignatureColor }

function Origins.kingdom(id: string): Kingdom
	for _, kingdom in Origins.Kingdoms do
		if kingdom.id == id then
			return kingdom
		end
	end
	return Origins.Kingdoms[1]
end

function Origins.color(id: string): SignatureColor
	for _, entry in Origins.Colors do
		if entry.id == id then
			return entry
		end
	end
	return Origins.Colors[1]
end

function Origins.isTrait(id: string): boolean
	for _, trait in Origins.FaunusTraits do
		if trait.id == id then
			return true
		end
	end
	return false
end

return Origins
