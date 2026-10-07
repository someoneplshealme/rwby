--!strict
--[[
	Creatures of Grimm. They share the player combat pipeline (same hitboxes, parries, posture),
	so a Beowolf's swipe can be parried exactly like a Huntsman's blade. When slain they dissolve
	into black smoke.
]]

local Weapons = require(script.Parent.Weapons)

export type GrimmMove = {
	range: number, -- AI uses this move when the target is within this distance (scaled by Grimm size)
	weight: number,
	move: Weapons.MoveDef,
}

export type GrimmDef = {
	id: string,
	name: string,
	health: number,
	scale: number,
	gait: string,
	walkSpeed: number,
	chaseSpeed: number,
	aggroRange: number,
	leashRange: number,
	attackCooldown: { number }, -- min, max seconds between attacks
	hitstunMultiplier: number, -- < 1 shrugs off flinches
	xp: number,
	lien: { number },
	bodyColor: Color3,
	boneColor: Color3,
	eyeColor: Color3,
	moves: { GrimmMove },
}

local box, sphere, kb, hit, move = Weapons.box, Weapons.sphere, Weapons.kb, Weapons.hit, Weapons.move

local function attack(range: number, weight: number, def: Weapons.MoveDef): GrimmMove
	return { range = range, weight = weight, move = def }
end

local Grimm: { [string]: GrimmDef } = {
	Beowolf = {
		id = "Beowolf",
		name = "Beowolf",
		health = 85,
		scale = 1.15,
		gait = "Feral",
		walkSpeed = 11,
		chaseSpeed = 21,
		aggroRange = 75,
		leashRange = 160,
		attackCooldown = { 0.9, 1.8 },
		hitstunMultiplier = 1,
		xp = 24,
		lien = { 5, 11 },
		bodyColor = Color3.fromRGB(22, 20, 24),
		boneColor = Color3.fromRGB(232, 228, 216),
		eyeColor = Color3.fromRGB(255, 30, 30),
		moves = {
			attack(
				7,
				3,
				move({
					clip = "Grimm.Swipe",
					hitbox = box(8, 7, 8, 4),
					hits = { hit({ damage = 9, posture = 14, hitstun = 0.5 }) },
				})
			),
			attack(
				7,
				2,
				move({
					clip = "Grimm.DoubleSwipe",
					hitbox = box(8, 7, 8, 4),
					hits = {
						hit({ damage = 6, posture = 10, hitstun = 0.45 }),
						hit({ damage = 8, posture = 12, hitstun = 0.6, knockback = kb(0, 10, 30) }),
					},
				})
			),
			attack(
				18,
				2,
				move({
					clip = "Grimm.Pounce",
					hitbox = box(7, 7, 8, 4),
					hits = {
						hit({ damage = 12, posture = 18, hitstun = 0.7, knockback = kb(0, 16, 36), heavy = true }),
					},
				})
			),
		},
	},
	Alpha = {
		id = "Alpha",
		name = "Alpha Beowolf",
		health = 210,
		scale = 1.45,
		gait = "Feral",
		walkSpeed = 11,
		chaseSpeed = 22,
		aggroRange = 85,
		leashRange = 180,
		attackCooldown = { 0.7, 1.4 },
		hitstunMultiplier = 0.6,
		xp = 90,
		lien = { 25, 40 },
		bodyColor = Color3.fromRGB(16, 14, 18),
		boneColor = Color3.fromRGB(245, 240, 228),
		eyeColor = Color3.fromRGB(255, 40, 20),
		moves = {
			attack(
				8,
				2,
				move({
					clip = "Grimm.Swipe",
					hitbox = box(10, 8, 10, 5),
					hits = { hit({ damage = 13, posture = 20, hitstun = 0.55 }) },
				})
			),
			attack(
				8,
				2,
				move({
					clip = "Grimm.DoubleSwipe",
					hitbox = box(10, 8, 10, 5),
					hits = {
						hit({ damage = 9, posture = 14, hitstun = 0.45 }),
						hit({ damage = 12, posture = 18, hitstun = 0.7, knockback = kb(0, 12, 38) }),
					},
				})
			),
			attack(
				22,
				2,
				move({
					clip = "Grimm.Pounce",
					unparryable = true,
					hitbox = box(9, 8, 10, 5),
					hits = {
						hit({ damage = 16, posture = 24, hitstun = 0.8, knockback = kb(0, 20, 44), heavy = true }),
					},
				})
			),
		},
	},
	Ursa = {
		id = "Ursa",
		name = "Ursa",
		health = 300,
		scale = 1.75,
		gait = "Heavy",
		walkSpeed = 9,
		chaseSpeed = 17,
		aggroRange = 70,
		leashRange = 150,
		attackCooldown = { 1.2, 2.2 },
		hitstunMultiplier = 0.35,
		xp = 120,
		lien = { 30, 55 },
		bodyColor = Color3.fromRGB(26, 22, 22),
		boneColor = Color3.fromRGB(236, 230, 218),
		eyeColor = Color3.fromRGB(255, 50, 30),
		moves = {
			attack(
				9,
				3,
				move({
					clip = "Grimm.Maul",
					hitbox = box(11, 9, 11, 5.5),
					hits = { hit({ damage = 16, posture = 26, hitstun = 0.7, knockback = kb(0, 8, 34), heavy = true }) },
				})
			),
			attack(
				10,
				2,
				move({
					clip = "Grimm.Slam",
					hyperArmor = true,
					unparryable = true,
					hitbox = sphere(11, 5),
					hits = { hit({ damage = 22, posture = 40, hitstun = 1, knockback = kb(0, 40, 30), heavy = true }) },
				})
			),
		},
	},
}

local api = {}

api.Definitions = Grimm

function api.get(id: string): GrimmDef?
	return Grimm[id]
end

return api
