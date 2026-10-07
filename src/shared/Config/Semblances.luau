--!strict
--[[
	Semblances: every Huntsman's unique aura power. Rolled at character creation with rarity
	weights (spend Semblance Spins to reroll), activated with E, each with a passive perk.
]]

export type SemblanceDef = {
	id: string,
	name: string,
	rarity: string,
	weight: number,
	color: Color3,
	description: string,
	passive: string,
	cooldown: number,
	clip: string,
	params: { [string]: number },
}

local Semblances: { [string]: SemblanceDef } = {
	Velocity = {
		id = "Velocity",
		name = "Velocity",
		rarity = "Rare",
		weight = 7,
		color = Color3.fromRGB(220, 36, 64),
		description = "Burst into a storm of petals and tear through everything in your path, untouchable.",
		passive = "Sprint 8% faster.",
		cooldown = 6,
		clip = "Common.SemblanceDash",
		params = { speed = 118, duration = 0.42, damage = 6, stun = 0.35, sprintBonus = 0.08 },
	},
	Shadow = {
		id = "Shadow",
		name = "Shadow",
		rarity = "Uncommon",
		weight = 14,
		color = Color3.fromRGB(78, 64, 120),
		description = "Blink backward and leave a shadow clone behind that draws the Grimm's fury.",
		passive = "Dodge cooldown reduced by 15%.",
		cooldown = 7,
		clip = "Common.SemblanceBlink",
		params = { distance = 15, cloneDuration = 3, iframes = 0.35, dodgeCooldown = 0.15 },
	},
	Retribution = {
		id = "Retribution",
		name = "Retribution",
		rarity = "Rare",
		weight = 7,
		color = Color3.fromRGB(255, 170, 40),
		description = "Every blow you take feeds your Fury. Ignite it to hit harder and refuse to flinch.",
		passive = "Taking damage or blocking builds Fury (shown on your HUD).",
		cooldown = 10,
		clip = "Common.SemblanceIgnite",
		params = { minFury = 35, baseDuration = 3, durationPerFury = 0.07, damage = 0.35, posture = 0.4 },
	},
	Polarity = {
		id = "Polarity",
		name = "Polarity",
		rarity = "Uncommon",
		weight = 14,
		color = Color3.fromRGB(226, 186, 70),
		description = "Seize an enemy with magnetism and yank them straight onto your weapon.",
		passive = "Take 15% less damage from projectiles.",
		cooldown = 9,
		clip = "Common.SemblancePull",
		params = { range = 38, angle = 40, stun = 0.75, damage = 4, projectileResist = 0.15 },
	},
	Glyph = {
		id = "Glyph",
		name = "Glyph",
		rarity = "Common",
		weight = 24,
		color = Color3.fromRGB(196, 226, 255),
		description = "Summon a glyph that launches you skyward and leaves a time glyph that slows enemies.",
		passive = "One extra air dash.",
		cooldown = 7,
		clip = "Common.SemblanceGlyph",
		params = { launch = 96, radius = 11, slow = 0.45, duration = 4, airDashes = 1 },
	},
	Bulwark = {
		id = "Bulwark",
		name = "Bulwark",
		rarity = "Common",
		weight = 24,
		color = Color3.fromRGB(168, 156, 136),
		description = "Harden your aura like stone: no flinching, less damage, and an unshakable guard.",
		passive = "Maximum posture increased by 15%.",
		cooldown = 14,
		clip = "Common.SemblanceHarden",
		params = { duration = 4, reduction = 0.35, posture = 0.15 },
	},
}

local RARITY_COLORS = {
	Common = Color3.fromRGB(200, 200, 205),
	Uncommon = Color3.fromRGB(90, 200, 120),
	Rare = Color3.fromRGB(80, 150, 255),
	Legendary = Color3.fromRGB(255, 190, 60),
}

local api = {}

api.Definitions = Semblances
api.RarityColors = RARITY_COLORS

function api.get(id: string): SemblanceDef?
	return Semblances[id]
end

function api.ids(): { string }
	local ids = {}
	for id in Semblances do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

-- Weighted roll. `random` lets the server pass its own Random object.
function api.roll(random: Random, exclude: string?): string
	local total = 0
	for id, def in Semblances do
		if id ~= exclude then
			total += def.weight
		end
	end
	local pick = random:NextNumber() * total
	local ids = api.ids()
	for _, id in ids do
		if id ~= exclude then
			pick -= Semblances[id].weight
			if pick <= 0 then
				return id
			end
		end
	end
	return ids[#ids]
end

return api
