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

-- Typed constructor so mixed piece tables (some with shape/material/hiddenIn) check cleanly.
local function piece(def: Piece): Piece
	return def
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

--[[ EMBER GAUNTLETS — armoured forearms with shotgun chambers.
	Handle +Z runs up the forearm and -Z out past the knuckles (the punch direction).
	Fists form: chambers sit along the forearm. Loaded form: chambers slide over the fist,
	barrels extend past the knuckles and the shell drum rotates into place. ]]
local function gauntlet(side: number): { Piece }
	-- side = 1 for the right hand; -1 mirrors pieces onto the left forearm's outer face.
	return {
		{
			name = "Sleeve",
			size = Vector3.new(1.14, 1.14, 1.4),
			color = "Primary",
			forms = { Fists = cf(0, 0, 0.62), Loaded = cf(0, 0, 0.62) },
		},
		{
			name = "Knuckles",
			size = Vector3.new(1.18, 0.34, 0.62),
			color = "Dark",
			forms = { Fists = cf(0, 0.48, 0.02), Loaded = cf(0, 0.48, 0.3) },
		},
		{
			name = "Cuff",
			size = Vector3.new(1.24, 1.24, 0.3),
			color = "Dark",
			forms = { Fists = cf(0, 0, 1.3), Loaded = cf(0, 0, 1.3) },
		},
		{
			name = "Chamber",
			size = Vector3.new(1.0, 0.42, 0.42),
			shape = "Cylinder",
			color = "Metal",
			forms = { Fists = cf(0.62 * side, 0.1, 0.65, 0, 90, 0), Loaded = cf(0.5 * side, 0.12, -0.25, 0, 90, 0) },
		},
		{
			name = "BarrelTop",
			size = Vector3.new(0.9, 0.26, 0.26),
			shape = "Cylinder",
			color = "Dark",
			forms = { Fists = cf(0.15 * side, 0.3, 0.7, 0, 90, 0), Loaded = cf(0.15 * side, 0.3, -0.62, 0, 90, 0) },
		},
		{
			name = "BarrelLow",
			size = Vector3.new(0.9, 0.26, 0.26),
			shape = "Cylinder",
			color = "Dark",
			forms = { Fists = cf(-0.15 * side, 0.3, 0.7, 0, 90, 0), Loaded = cf(-0.15 * side, 0.3, -0.62, 0, 90, 0) },
		},
		{
			name = "Glow",
			size = Vector3.new(1.16, 0.12, 1.0),
			color = "Accent",
			material = "Neon",
			forms = { Fists = cf(0, 0.58, 0.75), Loaded = cf(0, 0.58, 0.75) },
		},
	}
end

WeaponModels.EmberGauntlets = {
	forms = { "Fists", "Loaded" },
	shiftTime = 0.4,
	palette = palette({ Primary = Color3.fromRGB(226, 168, 44) }),
	right = gauntlet(1),
	left = gauntlet(-1),
	trails = {
		{ hand = "Right", a = Vector3.new(0, 0.4, -0.25), b = Vector3.new(0, -0.4, -0.25) },
		{ hand = "Left", a = Vector3.new(0, 0.4, -0.25), b = Vector3.new(0, -0.4, -0.25) },
	},
	muzzles = {
		Loaded = { hand = "Right", offset = Vector3.new(0, 0.3, -1.1) },
	},
}

--[[ AEGIS BLADE — sword and round shield; the shield folds into a bracer while the blade's
	side plates slide out into a broad greatsword with a two-handed hilt. ]]
WeaponModels.AegisBlade = {
	forms = { "SwordShield", "Greatsword" },
	shiftTime = 0.6,
	palette = palette({ Primary = Color3.fromRGB(58, 84, 156), Gold = Color3.fromRGB(222, 182, 82) }),
	right = {
		{
			name = "Hilt",
			size = Vector3.new(0.26, 1.0, 0.26),
			color = "Dark",
			forms = { SwordShield = cf(0, 0, 0), Greatsword = cf(0, -0.2, 0) },
		},
		{
			name = "HiltExtension",
			size = Vector3.new(0.26, 1.1, 0.26),
			color = "Dark",
			forms = { SwordShield = cf(0, 0.1, 0), Greatsword = cf(0, -1.15, 0) },
			hiddenIn = { SwordShield = true },
		},
		{
			name = "Pommel",
			size = Vector3.new(0.4, 0.4, 0.4),
			shape = "Ball",
			color = "Gold",
			forms = { SwordShield = cf(0, -0.55, 0), Greatsword = cf(0, -1.75, 0) },
		},
		{
			name = "Guard",
			size = Vector3.new(0.32, 0.24, 1.5),
			color = "Gold",
			forms = { SwordShield = cf(0, 0.55, 0), Greatsword = cf(0, 0.55, 0) },
		},
		{
			name = "Blade",
			size = Vector3.new(0.12, 4.0, 0.48),
			color = "Steel",
			forms = { SwordShield = cf(0, 2.65, 0), Greatsword = cf(0, 3.2, 0) },
		},
		{
			name = "Fuller",
			size = Vector3.new(0.14, 3.0, 0.1),
			color = "Accent",
			material = "Neon",
			forms = { SwordShield = cf(0, 2.5, 0), Greatsword = cf(0, 3.0, 0) },
		},
		{
			name = "PlateFront",
			size = Vector3.new(0.14, 4.6, 0.42),
			color = "Primary",
			forms = { SwordShield = cf(0, 2.6, 0), Greatsword = cf(0, 3.0, -0.42) },
			hiddenIn = { SwordShield = true },
		},
		{
			name = "PlateBack",
			size = Vector3.new(0.14, 4.6, 0.42),
			color = "Primary",
			forms = { SwordShield = cf(0, 2.6, 0), Greatsword = cf(0, 3.0, 0.42) },
			hiddenIn = { SwordShield = true },
		},
	},
	left = {
		piece({
			name = "Shield",
			size = Vector3.new(0.22, 2.7, 2.7),
			shape = "Cylinder",
			color = "Primary",
			forms = { SwordShield = cf(-0.62, 0.1, 0.65), Greatsword = cf(-0.45, 0, 0.8) },
			hiddenIn = { Greatsword = true },
		}),
		piece({
			name = "Rim",
			size = Vector3.new(0.18, 2.95, 2.95),
			shape = "Cylinder",
			color = "Gold",
			forms = { SwordShield = cf(-0.55, 0.1, 0.65), Greatsword = cf(-0.4, 0, 0.8) },
			hiddenIn = { Greatsword = true },
		}),
		piece({
			name = "Emblem",
			size = Vector3.new(0.12, 1.0, 1.0),
			shape = "Cylinder",
			color = "Accent",
			material = "Neon",
			forms = { SwordShield = cf(-0.75, 0.1, 0.65), Greatsword = cf(-0.62, 0, 0.75) },
		}),
		piece({
			name = "Bracer",
			size = Vector3.new(1.16, 1.16, 1.2),
			color = "Primary",
			forms = { SwordShield = cf(0, 0, 0.7), Greatsword = cf(0, 0, 0.7) },
		}),
	},
	trails = {
		{
			hand = "Right",
			a = Vector3.new(0, 1.0, 0),
			b = Vector3.new(0, 4.6, 0),
			forms = { SwordShield = true },
		},
		{
			hand = "Right",
			a = Vector3.new(0, 1.2, 0),
			b = Vector3.new(0, 5.3, 0),
			forms = { Greatsword = true },
		},
	},
	twoHand = {
		Greatsword = { a = Vector3.new(0, -1.5, 0), b = Vector3.new(0, 0.3, 0), prefer = 0.2 },
	},
}

--[[ THUNDER HAMMER — a long war hammer whose head drops into a grenade launcher;
	the haft folds back into a stock and a fat barrel slides out of the head. ]]
WeaponModels.ThunderHammer = {
	forms = { "Hammer", "Launcher" },
	shiftTime = 0.6,
	palette = palette({ Primary = Color3.fromRGB(206, 76, 136), Dark = Color3.fromRGB(46, 44, 54) }),
	right = {
		{
			name = "Haft",
			size = Vector3.new(0.3, 4.8, 0.3),
			color = "Dark",
			forms = { Hammer = cf(0, 1.0, 0), Launcher = cf(0, 0.15, 1.6, 90) },
		},
		{
			name = "GripWrap",
			size = Vector3.new(0.34, 1.0, 0.34),
			color = "Accent",
			material = "SmoothPlastic",
			forms = { Hammer = cf(0, -0.4, 0), Launcher = cf(0, -0.2, 0.05, -12) },
		},
		{
			name = "Head",
			size = Vector3.new(1.5, 1.35, 2.5),
			color = "Primary",
			forms = { Hammer = cf(0, 3.65, 0), Launcher = cf(0, 0.55, -0.9) },
		},
		{
			name = "FaceFront",
			size = Vector3.new(1.62, 1.47, 0.22),
			color = "Dark",
			forms = { Hammer = cf(0, 3.65, -1.3), Launcher = cf(0, 0.55, -2.2) },
		},
		{
			name = "FaceBack",
			size = Vector3.new(1.62, 1.47, 0.22),
			color = "Dark",
			forms = { Hammer = cf(0, 3.65, 1.3), Launcher = cf(0, 0.55, 0.4) },
		},
		{
			name = "Band",
			size = Vector3.new(1.56, 0.22, 2.55),
			color = "Accent",
			material = "Neon",
			forms = { Hammer = cf(0, 3.65, 0), Launcher = cf(0, 0.55, -0.9) },
		},
		{
			name = "Barrel",
			size = Vector3.new(1.8, 0.85, 0.85),
			shape = "Cylinder",
			color = "Metal",
			forms = { Hammer = cf(0, 3.65, 0, 0, 90, 0), Launcher = cf(0, 0.6, -2.9, 0, 90, 0) },
			hiddenIn = { Hammer = true },
		},
		{
			name = "Drum",
			size = Vector3.new(0.7, 1.1, 1.1),
			shape = "Cylinder",
			color = "Dark",
			forms = { Hammer = cf(0, 3.65, 0), Launcher = cf(0, -0.25, -0.9) },
			hiddenIn = { Hammer = true },
		},
	},
	trails = {
		{ hand = "Right", a = Vector3.new(0, 3.0, 0), b = Vector3.new(0, 4.3, 0), forms = { Hammer = true } },
	},
	muzzles = {
		Launcher = { hand = "Right", offset = Vector3.new(0, 0.6, -3.9) },
	},
	twoHand = {
		Hammer = { a = Vector3.new(0, -1.3, 0), b = Vector3.new(0, 2.2, 0), prefer = 0.25 },
		Launcher = { a = Vector3.new(0, 0.2, -1.2), b = Vector3.new(0, 0.2, -2.8), prefer = 0.4 },
	},
}

return WeaponModels
