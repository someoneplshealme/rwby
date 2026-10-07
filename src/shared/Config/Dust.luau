--!strict
--[[
	Dust: crystallised elemental energy. Each vial fuels one Dust technique (keys 1-4).
	Vials are bought at the From Dust Till Dawn shop in Vale.
]]

export type DustDef = {
	id: string,
	name: string,
	technique: string,
	description: string,
	key: string, -- default keybind label
	color: Color3,
	cooldown: number,
	clip: string,
	price: number,
	params: { [string]: number },
}

local Dust: { [string]: DustDef } = {
	Fire = {
		id = "Fire",
		name = "Fire Dust",
		technique = "Burning Arc",
		description = "A sweeping cone of flame that sets enemies ablaze.",
		key = "1",
		color = Color3.fromRGB(255, 112, 40),
		cooldown = 6,
		clip = "Common.CastFire",
		price = 30,
		params = { damage = 11, posture = 10, range = 19, angle = 75, burnDuration = 3, burnPower = 3 },
	},
	Ice = {
		id = "Ice",
		name = "Ice Dust",
		technique = "Frost Spire",
		description = "A line of ice spikes erupts from the ground, chilling everything it touches.",
		key = "2",
		color = Color3.fromRGB(140, 214, 255),
		cooldown = 7,
		clip = "Common.CastIce",
		price = 30,
		params = { damage = 10, posture = 12, range = 32, width = 6, slowDuration = 2.6, slow = 0.55 },
	},
	Lightning = {
		id = "Lightning",
		name = "Lightning Dust",
		technique = "Arc Bolt",
		description = "A crackling bolt that stuns its target and leaps to one more enemy.",
		key = "3",
		color = Color3.fromRGB(255, 236, 110),
		cooldown = 6,
		clip = "Common.CastLightning",
		price = 35,
		params = { damage = 11, posture = 8, speed = 230, range = 120, stun = 0.8, chainRange = 15 },
	},
	Gravity = {
		id = "Gravity",
		name = "Gravity Dust",
		technique = "Gravity Burst",
		description = "A violet shockwave that hurls enemies away. Used mid-air, it launches you upward.",
		key = "4",
		color = Color3.fromRGB(172, 110, 255),
		cooldown = 8,
		clip = "Common.CastGravity",
		price = 40,
		params = { damage = 9, posture = 14, radius = 15, knockback = 62, lift = 34, selfLaunch = 72 },
	},
}

local api = {}

api.Definitions = Dust
api.Order = { "Fire", "Ice", "Lightning", "Gravity" }
api.MaxVials = 9

function api.get(id: string): DustDef?
	return Dust[id]
end

return api
