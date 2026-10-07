--!strict
--[[
	Levels, experience and attributes. Every level grants attribute points; attributes scale the
	combat stats computed in `stats`, which the server applies to each Huntsman's Combatant.
]]

local Origins = require(script.Parent.Origins)

export type Attributes = {
	Strength: number,
	Agility: number,
	Willpower: number,
	Vitality: number,
	Affinity: number,
}

export type CombatStats = {
	maxHealth: number,
	maxAura: number,
	maxPosture: number,
	damage: number, -- melee/ranged damage multiplier
	postureDamage: number,
	dustDamage: number,
	dustCooldown: number, -- multiplier (lower is faster)
	moveSpeed: number, -- multiplier
	dodgeCooldown: number, -- multiplier
	auraRegen: number, -- multiplier
}

local Progression = {}

Progression.MaxLevel = 30
Progression.PointsPerLevel = 3
Progression.AttributeCap = 40

Progression.Attributes = {
	{ id = "Strength", name = "Strength", blurb = "+2.5% weapon damage, +1% posture damage" },
	{ id = "Agility", name = "Agility", blurb = "+0.5% move speed, -1% dodge cooldown" },
	{ id = "Willpower", name = "Willpower", blurb = "+5 Aura, +2% Aura regeneration" },
	{ id = "Vitality", name = "Vitality", blurb = "+5 Health" },
	{ id = "Affinity", name = "Dust Affinity", blurb = "+3% Dust damage, -1.5% Dust cooldowns" },
}

function Progression.xpToNext(level: number): number
	return math.floor(60 + 38 * level ^ 1.35)
end

function Progression.emptyAttributes(): Attributes
	return { Strength = 0, Agility = 0, Willpower = 0, Vitality = 0, Affinity = 0 }
end

function Progression.stats(
	level: number,
	attributes: Attributes,
	kingdomId: string,
	isFaunus: boolean,
	semblanceId: string?
): CombatStats
	local kingdom = Origins.kingdom(kingdomId)
	local mods = kingdom.modifiers
	local stats: CombatStats = {
		maxHealth = (100 + (level - 1) * 4 + attributes.Vitality * 5) * (1 + (mods.health or 0)),
		maxAura = (100 + (level - 1) * 4 + attributes.Willpower * 5) * (1 + (mods.aura or 0)),
		maxPosture = 100,
		damage = 1 + attributes.Strength * 0.025,
		postureDamage = 1 + attributes.Strength * 0.01 + (mods.posture or 0),
		dustDamage = 1 + attributes.Affinity * 0.03 + (mods.dust or 0),
		dustCooldown = math.max(0.5, 1 - attributes.Affinity * 0.015),
		moveSpeed = 1 + math.min(attributes.Agility, Progression.AttributeCap) * 0.005 + (if isFaunus then 0.04 else 0),
		dodgeCooldown = math.max(0.6, 1 - attributes.Agility * 0.01),
		auraRegen = 1 + attributes.Willpower * 0.02,
	}
	if semblanceId == "Bulwark" then
		stats.maxPosture *= 1.15
	elseif semblanceId == "Shadow" then
		stats.dodgeCooldown *= 0.85
	end
	return stats
end

return Progression
