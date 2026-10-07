--!strict
--[[
	Procedural weapon models. Every weapon is built from simple parts at runtime, so the game needs
	no uploaded meshes. Each piece stores a CFrame for EVERY form of the weapon; switching forms
	("mecha-shift") animates each piece from one CFrame to the other on the client.

	HANDLE SPACE
	Pieces are positioned relative to the hand's grip point (see Joints.GripC0):
	  +Y  along the weapon (the direction a sword blade points)
	  -Z  away from the wielder in natural holds (scythe blade, rifle barrel)
	  +X  to the wielder's right (for the right hand)

	Colors are palette keys ("Primary", "Dark", "Metal", "Steel", "Accent") resolved at build
	time; "Accent" is the player's signature colour, so every Huntsman's weapon is personal.
]]

export type Piece = {
	name: string,
	size: Vector3,
	shape: string?, -- "Block" (default), "Wedge", "Cylinder", "Ball"
	color: string,
	material: string?, -- Enum.Material name, default "Metal"
	forms: { [string]: CFrame },
	hiddenIn: { [string]: boolean }?,
}

export type Trail = {
	hand: string, -- "Right" | "Left"
	a: Vector3, -- trail edge points in handle space
	b: Vector3,
	forms: { [string]: boolean }?, -- forms that show this trail (all if nil)
}

export type Muzzle = {
	hand: string,
	offset: Vector3,
}

-- Segment (in right-handle space) the off hand holds on two-handed forms; see Composer.applyTwoHand.
export type TwoHand = {
	a: Vector3,
	b: Vector3,
	prefer: number?,
}

export type WeaponModel = {
	forms: { string },
	palette: { [string]: Color3 },
	right: { Piece },
	left: { Piece }?,
	trails: { Trail },
	muzzles: { [string]: Muzzle }?, -- per form
	twoHand: { [string]: TwoHand }?, -- per form
	shiftTime: number, -- seconds the mecha-shift takes
}

local rad = math.rad

local function cf(x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(rad(rx or 0), rad(ry or 0), rad(rz or 0))
end

local DEFAULT_PALETTE = {
	Dark = Color3.fromRGB(32, 32, 38),
	Metal = Color3.fromRGB(96, 98, 108),
	Steel = Color3.fromRGB(205, 208, 218),
	Gold = Color3.fromRGB(214, 170, 72),
}

local function palette(overrides: { [string]: Color3 }): { [string]: Color3 }
	local result = table.clone(DEFAULT_PALETTE)
	for key, value in overrides do
		result[key] = value
	end
	return result
end

local WeaponModels: { [string]: WeaponModel } = {}

--[[ CRESCENT SCYTHE — high-impact sniper-scythe.
	Scythe form: long shaft along +Y, curved blade sweeping out along -Z from the head.
	Rifle form: the upper shaft swings down to become the barrel (-Z), the lower shaft folds back
	into a stock (+Z), the blade tucks under the barrel and a scope rises from the receiver. ]]
WeaponModels.CrescentScythe = {
	forms = { "Scythe", "Rifle" },
	shiftTime = 0.55,
	palette = palette({ Primary = Color3.fromRGB(150, 22, 34) }),
	right = {
		{
			name = "ShaftLow",
			size = Vector3.new(0.26, 2.6, 0.26),
			color = "Dark",
			forms = { Scythe = cf(0, -0.7, 0), Rifle = cf(0, 0.2, 1.45, 90) },
		},
		{
			name = "Grip",
			size = Vector3.new(0.32, 0.9, 0.32),
			color = "Accent",
			material = "SmoothPlastic",
			forms = { Scythe = cf(0, 0, 0), Rifle = cf(0, -0.1, 0.05, -12) },
		},
		{
			name = "ShaftHigh",
			size = Vector3.new(0.26, 4.2, 0.26),
			color = "Primary",
			forms = { Scythe = cf(0, 2.7, 0), Rifle = cf(0, 0.48, -3.0, -90) },
		},
		{
			name = "Head",
			size = Vector3.new(0.46, 1.1, 0.78),
			color = "Dark",
			forms = { Scythe = cf(0, 5.3, 0), Rifle = cf(0, 0.45, -0.45, -90) },
		},
		{
			name = "Blade1",
			size = Vector3.new(0.14, 0.72, 1.9),
			color = "Steel",
			forms = { Scythe = cf(0, 5.6, -1.25), Rifle = cf(0, 0.02, -1.75) },
		},
		{
			name = "Blade2",
			size = Vector3.new(0.12, 0.56, 1.6),
			color = "Steel",
			forms = { Scythe = cf(0, 5.3, -2.85, -16), Rifle = cf(0, 0.06, -3.35) },
		},
		{
			name = "Blade3",
			size = Vector3.new(0.1, 0.42, 1.5),
			shape = "Wedge",
			color = "Steel",
			forms = { Scythe = cf(0, 4.68, -4.2, -38), Rifle = cf(0, 0.1, -4.75) },
		},
		{
			name = "Edge",
			size = Vector3.new(0.05, 0.08, 3.4),
			color = "Accent",
			material = "Neon",
			forms = { Scythe = cf(0, 5.17, -2.2, -8), Rifle = cf(0, -0.32, -3.0) },
		},
		{
			name = "Scope",
			size = Vector3.new(1.1, 0.22, 0.22),
			shape = "Cylinder",
			color = "Dark",
			forms = { Scythe = cf(0, 5.3, 0.1, 0, 90, 0), Rifle = cf(0, 0.98, -0.75, 0, 90, 0) },
			hiddenIn = { Scythe = true },
		},
	},
	trails = {
		{ hand = "Right", a = Vector3.new(0, 5.6, -1.0), b = Vector3.new(0, 4.7, -4.4), forms = { Scythe = true } },
	},
	muzzles = {
		Rifle = { hand = "Right", offset = Vector3.new(0, 0.48, -5.2) },
	},
	twoHand = {
		Scythe = { a = Vector3.new(0, -1.7, 0), b = Vector3.new(0, 3.4, 0), prefer = 0.55 },
		Rifle = { a = Vector3.new(0, 0.3, -1.2), b = Vector3.new(0, 0.3, -3.2), prefer = 0.4 },
	},
}

return WeaponModels
