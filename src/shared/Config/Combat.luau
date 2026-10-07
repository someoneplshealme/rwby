--!strict
--[[
	Global combat tuning. Every number that shapes how a fight feels lives here.
	Times are seconds, speeds studs/second, angles degrees.
]]

local Combat = {
	-- Movement
	WalkSpeed = 14,
	SprintSpeed = 25,
	BlockWalkSpeed = 7,
	AttackWalkSpeed = 5,
	AimWalkSpeed = 9,
	CastWalkSpeed = 4,
	JumpPower = 52,
	DoubleTapWindow = 0.28, -- double-tap W to sprint

	-- Dodge / dash
	DodgeSpeed = 64,
	DodgeDuration = 0.34,
	DodgeIFrames = 0.24, -- invulnerable for this long after the dodge starts
	DodgeCooldown = 1.35,
	AirDashSpeed = 70,
	AirDashes = 1, -- dashes allowed per airtime
	SlideSpeed = 46,
	SlideDuration = 0.65,
	SlideCooldown = 1.2,

	-- Guarding
	ParryWindow = 0.2, -- the first moments of raising guard deflect attacks
	ParryFailCooldown = 0.55, -- whiffing a parry locks the next parry this long
	ParryStun = 0.95, -- attacker stagger after being parried
	ParryPostureReward = 22, -- posture the parrier recovers
	BlockAngle = 115, -- frontal cone that guards
	PostureMax = 100,
	PostureRegen = 16, -- per second
	PostureRegenDelay = 1.6,
	GuardBreakStun = 1.6,
	BlockStun = 0.18,

	-- Aura (RWBY's soul shield): absorbs damage before health
	AuraRegenPercent = 0.07, -- of max aura per second
	AuraRegenDelay = 7,
	AuraBrokenDelay = 14, -- regen delay after the aura shatters
	AuraBreakStun = 0.55,
	AuraOverflowToHealth = 0.5, -- share of damage beyond remaining aura that reaches health
	ExposedDamageMultiplier = 1.15, -- health damage taken while aura is broken
	HealthRegenPercent = 0.006, -- per second, only out of combat
	OutOfCombatTime = 12,

	-- Offense
	ComboResetTime = 0.8, -- chain window after a hit before the combo resets
	ComboEndLag = 0.5, -- extra recovery after a full M1 string
	CriticalCooldown = 4,
	FeintCooldown = 2.2,
	FeintWindowPadding = 0.05, -- cannot feint this close to the hit frame
	BackstabMultiplier = 1.2,
	ChainTolerance = 0.12, -- server accepts chained inputs this early
	MaxHitAngleCorrection = 100, -- client facing hints beyond this from the server facing are ignored

	-- Knocked / death
	KnockedDuration = 15,
	RecoverHealthFraction = 0.2,
	ExecuteRange = 7,
	ExecuteDuration = 1.4,
	RespawnDelay = 5,
	GrimmExecuteDelay = 2.5,

	-- Feel
	HitstopLight = 0.055,
	HitstopHeavy = 0.1,
	HitstopParry = 0.12,
} :: { [string]: number }

return Combat
