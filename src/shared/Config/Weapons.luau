--!strict
--[[
	Weapon gameplay definitions. Every Huntsman weapon is a mecha-shift weapon with two forms;
	pressing the form key (T) transforms it mid-fight.

	TIMING COMES FROM THE ANIMATIONS: a move's hit frames are the "Hit" markers inside its clip
	(see Animation/Clips), one HitDef per marker, so gameplay and visuals cannot drift apart.

	Hitbox space is the attacker's root: `forward` is the distance of the box centre in front of
	the character, `up` its height offset. Knockback is local to the attacker: Z+ pushes away from
	the attacker, Y+ lifts, X+ pushes to the attacker's right.
]]

export type Hitbox = {
	shape: string?, -- "Box" (default) | "Sphere"
	size: Vector3?, -- box (width, height, depth)
	radius: number?, -- sphere radius
	forward: number?,
	up: number?,
}

export type Status = {
	kind: string, -- "Burn" | "Chill" | "Shock" | "Slow"
	duration: number,
	power: number?,
}

export type HitDef = {
	damage: number,
	posture: number?,
	hitstun: number?,
	knockback: Vector3?,
	hitbox: Hitbox?,
	heavy: boolean?,
	status: Status?,
}

export type ShotDef = {
	kind: string, -- "Hitscan" | "Pellets" | "Grenade"
	damage: number,
	posture: number?,
	range: number,
	pellets: number?,
	spread: number?, -- degrees
	speed: number?, -- grenade launch speed
	radius: number?, -- grenade blast radius
	hitstun: number?,
	knockback: number?,
	recoil: number?, -- self-propulsion away from the aim direction while airborne
	groundRecoil: number?,
	status: Status?,
}

export type MoveDef = {
	clip: string,
	hitbox: Hitbox,
	hits: { HitDef },
	shot: ShotDef?, -- fired at every "Shoot" marker in the clip
	speed: number?,
	hyperArmor: boolean?,
	unblockable: boolean?,
	unparryable: boolean?,
	feintable: boolean?,
	cooldown: number?,
}

export type ShootDef = {
	clip: string,
	altClip: string?, -- alternate clip for every other shot (left/right hands)
	cooldown: number,
	shot: ShotDef,
}

export type FormDef = {
	name: string,
	label: string,
	stance: string,
	ranged: boolean,
	icon: string,
	m1: { MoveDef }?,
	shoot: ShootDef?,
	critical: MoveDef?,
	blockPosture: number?, -- posture multiplier while blocking (shields < 1)
	blockAngle: number?,
	speedMultiplier: number?,
}

export type WeaponDef = {
	id: string,
	name: string,
	tagline: string,
	description: string,
	model: string,
	animPrefix: string,
	forms: { FormDef },
}

-- Typed constructors keep the tables below concise and fully type-checked.
local function box(width: number, height: number, depth: number, forward: number?, up: number?): Hitbox
	return { size = Vector3.new(width, height, depth), forward = forward, up = up }
end

local function sphere(radius: number, forward: number?): Hitbox
	return { shape = "Sphere", radius = radius, forward = forward }
end

local function kb(right: number, up: number, away: number): Vector3
	return Vector3.new(right, up, away)
end

local function status(kind: string, duration: number, power: number?): Status
	return { kind = kind, duration = duration, power = power }
end

local function hit(def: HitDef): HitDef
	return def
end

local function move(def: MoveDef): MoveDef
	return def
end

local function chain(moves: { MoveDef }): { MoveDef }
	return moves
end

local function shot(def: ShotDef): ShotDef
	return def
end

local function form(def: FormDef): FormDef
	return def
end

local Weapons: { [string]: WeaponDef } = {}

----------------------------------------------------------------------------------------------------
-- CRESCENT SCYTHE: wide reaping arcs up close, a recoil-heavy sniper rifle at range.
----------------------------------------------------------------------------------------------------
Weapons.CrescentScythe = {
	id = "CrescentScythe",
	name = "Crescent Scythe",
	tagline = "High-impact sniper-scythe",
	description = "Huge sweeping reach and spinning combos. Shift into a sniper rifle whose recoil can launch you through the air.",
	model = "CrescentScythe",
	animPrefix = "Scythe",
	forms = {
		form({
			name = "Scythe",
			label = "Scythe",
			stance = "Scythe.Scythe",
			ranged = false,
			icon = "☾",
			speedMultiplier = 0.97,
			m1 = chain({
				move({
					clip = "Scythe.M1_1",
					hitbox = box(13, 6, 9, 4.5),
					hits = { hit({ damage = 8, posture = 10, hitstun = 0.5 }) },
				}),
				move({
					clip = "Scythe.M1_2",
					hitbox = box(13, 7, 9, 4.5),
					hits = { hit({ damage = 8, posture = 10, hitstun = 0.5 }) },
				}),
				move({
					clip = "Scythe.M1_3",
					hitbox = sphere(8.5),
					hits = { hit({ damage = 9, posture = 11, hitstun = 0.5 }) },
				}),
				move({
					clip = "Scythe.M1_4",
					hitbox = box(9, 8, 10, 5),
					hits = { hit({ damage = 12, posture = 16, hitstun = 0.85, knockback = kb(0, 22, 48), heavy = true }) },
				}),
			}),
			critical = move({
				clip = "Scythe.Critical",
				feintable = true,
				cooldown = 4.5,
				hitbox = sphere(9),
				hits = {
					hit({ damage = 9, posture = 18, hitstun = 0.6, knockback = kb(0, 30, 6) }),
					hit({
						damage = 16,
						posture = 32,
						hitstun = 0.9,
						knockback = kb(0, -20, 40),
						heavy = true,
						hitbox = box(9, 9, 11, 5),
					}),
				},
			}),
		}),
		form({
			name = "Rifle",
			label = "Sniper",
			stance = "Scythe.Rifle",
			ranged = true,
			icon = "⌖",
			speedMultiplier = 0.92,
			shoot = {
				clip = "Scythe.Shoot",
				cooldown = 1.05,
				shot = shot({
					kind = "Hitscan",
					damage = 19,
					posture = 14,
					range = 340,
					hitstun = 0.35,
					knockback = 18,
					recoil = 58,
					groundRecoil = 8,
				}),
			},
			critical = move({
				clip = "Scythe.RecoilRush",
				cooldown = 5,
				hitbox = box(9, 7, 10, 4.5),
				hits = { hit({ damage = 15, posture = 22, hitstun = 0.7, knockback = kb(0, 12, 40), heavy = true }) },
			}),
		}),
	},
}

----------------------------------------------------------------------------------------------------
-- EMBER GAUNTLETS: relentless boxing strings; load shells to blast at range or fly.
----------------------------------------------------------------------------------------------------
Weapons.EmberGauntlets = {
	id = "EmberGauntlets",
	name = "Ember Gauntlets",
	tagline = "Shotgun gauntlets",
	description = "The fastest strings in Remnant. Load the shells to turn every punch into a shotgun blast that also propels you.",
	model = "EmberGauntlets",
	animPrefix = "Gauntlets",
	forms = {
		form({
			name = "Fists",
			label = "Gauntlets",
			stance = "Gauntlets.Fists",
			ranged = false,
			icon = "✊",
			speedMultiplier = 1.04,
			m1 = chain({
				move({
					clip = "Gauntlets.M1_1",
					hitbox = box(6, 6, 7, 3.5),
					hits = { hit({ damage = 5, posture = 7, hitstun = 0.42 }) },
				}),
				move({
					clip = "Gauntlets.M1_2",
					hitbox = box(6, 6, 7, 3.5),
					hits = { hit({ damage = 5, posture = 7, hitstun = 0.42 }) },
				}),
				move({
					clip = "Gauntlets.M1_3",
					hitbox = box(7, 6, 7, 3.5),
					hits = { hit({ damage = 6, posture = 8, hitstun = 0.42 }) },
				}),
				move({
					clip = "Gauntlets.M1_4",
					hitbox = box(6, 7, 7, 3.5),
					hits = { hit({ damage = 6, posture = 9, hitstun = 0.45 }) },
				}),
				move({
					clip = "Gauntlets.M1_5",
					hitbox = box(7, 7, 8, 4),
					hits = { hit({ damage = 10, posture = 14, hitstun = 0.8, knockback = kb(0, 14, 55), heavy = true }) },
				}),
			}),
			critical = move({
				clip = "Gauntlets.Critical",
				feintable = true,
				cooldown = 4,
				hitbox = box(7, 9, 8, 4),
				hits = {
					hit({
						damage = 15,
						posture = 34,
						hitstun = 0.9,
						knockback = kb(0, 62, 12),
						heavy = true,
						status = status("Burn", 3, 3),
					}),
				},
			}),
		}),
		form({
			name = "Loaded",
			label = "Shotgun",
			stance = "Gauntlets.Loaded",
			ranged = true,
			icon = "✸",
			speedMultiplier = 1,
			shoot = {
				clip = "Gauntlets.BlastR",
				altClip = "Gauntlets.BlastL",
				cooldown = 0.42,
				shot = shot({
					kind = "Pellets",
					damage = 3.2,
					posture = 3,
					range = 42,
					pellets = 7,
					spread = 8,
					hitstun = 0.25,
					knockback = 10,
					recoil = 46,
					groundRecoil = 10,
				}),
			},
			critical = move({
				clip = "Gauntlets.EmberRush",
				cooldown = 5,
				hitbox = box(8, 7, 9, 4),
				hits = {
					hit({
						damage = 14,
						posture = 26,
						hitstun = 0.8,
						knockback = kb(0, 18, 60),
						heavy = true,
						status = status("Burn", 3, 3),
					}),
				},
			}),
		}),
	},
}

----------------------------------------------------------------------------------------------------
-- AEGIS BLADE: sword and shield with a superb guard; the shield sheathes the blade into a greatsword.
----------------------------------------------------------------------------------------------------
Weapons.AegisBlade = {
	id = "AegisBlade",
	name = "Aegis Blade",
	tagline = "Sword, shield and greatsword",
	description = "A steady sword with a shield that soaks posture damage. Lock the shield over the blade for a slow, crushing greatsword.",
	model = "AegisBlade",
	animPrefix = "Aegis",
	forms = {
		form({
			name = "SwordShield",
			label = "Sword & Shield",
			stance = "Aegis.SwordShield",
			ranged = false,
			icon = "⛨",
			blockPosture = 0.55,
			blockAngle = 150,
			speedMultiplier = 1,
			m1 = chain({
				move({
					clip = "Aegis.M1_1",
					hitbox = box(9, 6, 8, 4),
					hits = { hit({ damage = 7, posture = 9, hitstun = 0.48 }) },
				}),
				move({
					clip = "Aegis.M1_2",
					hitbox = box(9, 6, 8, 4),
					hits = { hit({ damage = 7, posture = 9, hitstun = 0.48 }) },
				}),
				move({
					clip = "Aegis.M1_3",
					hitbox = box(5, 6, 10, 5),
					hits = { hit({ damage = 8, posture = 10, hitstun = 0.5 }) },
				}),
				move({
					clip = "Aegis.M1_4",
					hitbox = box(7, 7, 7, 3.5),
					hits = { hit({ damage = 9, posture = 22, hitstun = 0.8, knockback = kb(0, 10, 40), heavy = true }) },
				}),
			}),
			critical = move({
				clip = "Aegis.Critical",
				feintable = true,
				cooldown = 4.5,
				hitbox = box(8, 7, 9, 4),
				hits = { hit({ damage = 11, posture = 45, hitstun = 0.8, knockback = kb(0, 8, 52), heavy = true }) },
			}),
		}),
		form({
			name = "Greatsword",
			label = "Greatsword",
			stance = "Aegis.Greatsword",
			ranged = false,
			icon = "⚔",
			speedMultiplier = 0.9,
			m1 = chain({
				move({
					clip = "Aegis.GS_M1_1",
					hitbox = box(14, 6, 10, 5),
					hits = { hit({ damage = 13, posture = 16, hitstun = 0.6 }) },
				}),
				move({
					clip = "Aegis.GS_M1_2",
					hitbox = box(14, 8, 10, 5),
					hits = { hit({ damage = 13, posture = 16, hitstun = 0.6 }) },
				}),
				move({
					clip = "Aegis.GS_M1_3",
					hyperArmor = true,
					hitbox = box(8, 10, 12, 5.5),
					hits = { hit({ damage = 18, posture = 28, hitstun = 0.95, knockback = kb(0, 16, 38), heavy = true }) },
				}),
			}),
			critical = move({
				clip = "Aegis.GS_Critical",
				feintable = true,
				hyperArmor = true,
				cooldown = 5,
				hitbox = box(9, 10, 13, 6),
				hits = { hit({ damage = 23, posture = 42, hitstun = 1, knockback = kb(0, -10, 30), heavy = true }) },
			}),
		}),
	},
}

----------------------------------------------------------------------------------------------------
-- THUNDER HAMMER: slow, heavy, area-of-effect slams; a grenade launcher for zoning.
----------------------------------------------------------------------------------------------------
Weapons.ThunderHammer = {
	id = "ThunderHammer",
	name = "Thunder Hammer",
	tagline = "War hammer and grenade launcher",
	description = "Every swing is a wall of posture damage. Shift to lob arcing grenades that blast groups apart.",
	model = "ThunderHammer",
	animPrefix = "Hammer",
	forms = {
		form({
			name = "Hammer",
			label = "Hammer",
			stance = "Hammer.Hammer",
			ranged = false,
			icon = "⚒",
			speedMultiplier = 0.9,
			m1 = chain({
				move({
					clip = "Hammer.M1_1",
					hitbox = box(12, 7, 9, 4.5),
					hits = { hit({ damage = 11, posture = 17, hitstun = 0.6 }) },
				}),
				move({
					clip = "Hammer.M1_2",
					hitbox = box(12, 7, 9, 4.5),
					hits = { hit({ damage = 11, posture = 17, hitstun = 0.6 }) },
				}),
				move({
					clip = "Hammer.M1_3",
					hyperArmor = true,
					hitbox = sphere(9, 5),
					hits = {
						hit({
							damage = 16,
							posture = 30,
							hitstun = 0.95,
							knockback = kb(0, 45, 22),
							heavy = true,
							status = status("Shock", 0.6),
						}),
					},
				}),
			}),
			critical = move({
				clip = "Hammer.Critical",
				feintable = true,
				hyperArmor = true,
				cooldown = 5.5,
				hitbox = sphere(13, 4),
				hits = {
					hit({
						damage = 20,
						posture = 40,
						hitstun = 1,
						knockback = kb(0, 55, 30),
						heavy = true,
						status = status("Shock", 0.9),
					}),
				},
			}),
		}),
		form({
			name = "Launcher",
			label = "Launcher",
			stance = "Hammer.Launcher",
			ranged = true,
			icon = "◉",
			speedMultiplier = 0.92,
			shoot = {
				clip = "Hammer.Lob",
				cooldown = 1.25,
				shot = shot({
					kind = "Grenade",
					damage = 16,
					posture = 18,
					range = 200,
					speed = 105,
					radius = 11,
					hitstun = 0.6,
					knockback = 42,
					recoil = 30,
					groundRecoil = 0,
				}),
			},
			critical = move({
				clip = "Hammer.Barrage",
				cooldown = 6,
				hitbox = box(1, 1, 1),
				hits = {},
				shot = shot({
					kind = "Grenade",
					damage = 12,
					posture = 14,
					range = 200,
					speed = 95,
					radius = 10,
					hitstun = 0.55,
					knockback = 36,
				}),
			}),
		}),
	},
}

local ORDER = { "CrescentScythe", "EmberGauntlets", "AegisBlade", "ThunderHammer" }

local api = {}

api.Definitions = Weapons

function api.get(id: string): WeaponDef?
	return Weapons[id]
end

function api.order(): { string }
	return table.clone(ORDER)
end

-- Looks up a form by name (falls back to the first form).
function api.form(weapon: WeaponDef, formName: string): FormDef
	for _, candidate in weapon.forms do
		if candidate.name == formName then
			return candidate
		end
	end
	return weapon.forms[1]
end

function api.nextForm(weapon: WeaponDef, formName: string): FormDef
	for index, candidate in weapon.forms do
		if candidate.name == formName then
			return weapon.forms[(index % #weapon.forms) + 1]
		end
	end
	return weapon.forms[1]
end

-- Hitbox helpers for other configs (Grimm).
api.box = box
api.sphere = sphere
api.kb = kb
api.status = status
api.hit = hit
api.move = move

return api
