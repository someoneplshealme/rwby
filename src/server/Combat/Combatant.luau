--!strict
--[[
	Combatant: server-side combat state for one character (a player, a Grimm, or a shadow clone).

	Resources
	  Health   Humanoid.Health. Players are knocked (not killed) at 0; Grimm die.
	  Aura     shield that absorbs damage first; shatters at 0 and leaves you Exposed.
	  Posture  fills when you block hits; full posture breaks your guard.
	  Fury     Retribution semblance meter.

	Actions run as coroutines guarded by `token`: anything that interrupts the combatant (a hit,
	a stun, a feint) bumps the token and the running action quietly stops at its next step.

	State and timers reach clients through attributes on the model (see `sync`), which drive HUDs
	and every client's animator.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Combat = require(Config.Combat)
local Grimm = require(Config.Grimm)
local Progression = require(Config.Progression)
local Weapons = require(Config.Weapons)

export type Status = {
	kind: string,
	untilTime: number,
	power: number,
	source: Combatant?,
	tickAt: number,
}

export type DamageResult = {
	aura: number,
	health: number,
	auraBroke: boolean,
	knocked: boolean,
	killed: boolean,
}

type Fields = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	player: Player?,
	kind: string, -- "Player" | "Grimm" | "Clone"
	grimm: Grimm.GrimmDef?,
	owner: Combatant?, -- clones belong to their caster
	stats: Progression.CombatStats,

	aura: number,
	posture: number,
	fury: number,
	auraBroken: boolean,

	state: string,
	stateUntil: number,
	token: number,

	iframesUntil: number,
	parryUntil: number,
	parryLockUntil: number,
	hyperArmorUntil: number,
	feintableUntil: number,
	chainOpensAt: number,
	comboIndex: number,
	comboExpires: number,
	comboLockUntil: number,
	blockStartedAt: number,
	lastHurtAt: number,
	lastAuraHitAt: number,
	auraBrokenAt: number,
	lastPostureAt: number,
	lastCombatAt: number,
	knockedAt: number,
	knockedBy: Combatant?,
	grimmNearSince: number,

	cooldowns: { [string]: number },
	statuses: { [string]: Status },
	buffs: { [string]: number }, -- buff name -> expiry (os.clock)
	damageLog: { [Combatant]: number },

	weapon: Weapons.WeaponDef?,
	form: Weapons.FormDef?,
	semblance: string?,
	shotCount: number,
	airDashes: number,
	attributeCache: { [string]: any },
	destroyed: boolean,
}

local Combatant = {}
Combatant.__index = Combatant

export type Combatant = typeof(setmetatable({} :: Fields, Combatant))

local DEFAULT_STATS: Progression.CombatStats = Progression.stats(1, Progression.emptyAttributes(), "Vale", false, nil)

function Combatant.new(model: Model, humanoid: Humanoid, root: BasePart, kind: string): Combatant
	local now = os.clock()
	local self = setmetatable({
		model = model,
		humanoid = humanoid,
		root = root,
		player = nil,
		kind = kind,
		grimm = nil,
		owner = nil,
		stats = table.clone(DEFAULT_STATS),

		aura = DEFAULT_STATS.maxAura,
		posture = 0,
		fury = 0,
		auraBroken = false,

		state = "Idle",
		stateUntil = 0,
		token = 0,

		iframesUntil = 0,
		parryUntil = 0,
		parryLockUntil = 0,
		hyperArmorUntil = 0,
		feintableUntil = 0,
		chainOpensAt = 0,
		comboIndex = 0,
		comboExpires = 0,
		comboLockUntil = 0,
		blockStartedAt = 0,
		lastHurtAt = -math.huge,
		lastAuraHitAt = -math.huge,
		auraBrokenAt = -math.huge,
		lastPostureAt = -math.huge,
		lastCombatAt = -math.huge,
		knockedAt = 0,
		knockedBy = nil,
		grimmNearSince = 0,

		cooldowns = {},
		statuses = {},
		buffs = {},
		damageLog = {},

		weapon = nil,
		form = nil,
		semblance = nil,
		shotCount = 0,
		airDashes = 0,
		attributeCache = {},
		destroyed = false,
	}, Combatant)
	self.lastCombatAt = now - 60
	self:sync()
	return self
end

--[[ ATTRIBUTES ]]

function Combatant.setAttr(self: Combatant, name: string, value: any)
	if self.attributeCache[name] ~= value then
		self.attributeCache[name] = value
		self.model:SetAttribute(name, value)
	end
end

-- Server time (for clients) at which an os.clock()-based moment happens.
local function toServerTime(clockTime: number): number
	return Workspace:GetServerTimeNow() + (clockTime - os.clock())
end

function Combatant.setCooldown(self: Combatant, name: string, seconds: number)
	local ready = os.clock() + seconds
	self.cooldowns[name] = ready
	self:setAttr(`CD_{name}`, toServerTime(ready))
	self:setAttr(`CDLen_{name}`, seconds)
end

function Combatant.ready(self: Combatant, name: string): boolean
	return os.clock() >= (self.cooldowns[name] or 0)
end

function Combatant.sync(self: Combatant)
	local now = os.clock()
	self:setAttr("State", self.state)
	self:setAttr("Aura", math.floor(self.aura + 0.5))
	self:setAttr("MaxAura", math.floor(self.stats.maxAura + 0.5))
	self:setAttr("AuraBroken", self.auraBroken)
	self:setAttr("Posture", math.floor(self.posture + 0.5))
	self:setAttr("MaxPosture", math.floor(self.stats.maxPosture + 0.5))
	self:setAttr("Fury", math.floor(self.fury))
	self:setAttr("Blocking", self.state == "Blocking")
	self:setAttr("Stunned", self.state == "Stunned")
	self:setAttr("GuardBroken", self.state == "GuardBroken")
	self:setAttr("Knocked", self.state == "Knocked")
	self:setAttr("Dead", self.state == "Dead")
	self:setAttr("Burning", self.statuses.Burn ~= nil)
	self:setAttr("Chilled", self.statuses.Chill ~= nil)
	self:setAttr("SlowFactor", self:slowFactor())
	self:setAttr("Buffed", self:hasBuff("Ignite") or self:hasBuff("Harden"))
	self:setAttr("Invulnerable", now < self.iframesUntil)
end

--[[ STATE ]]

function Combatant.now(_self: Combatant): number
	return os.clock()
end

function Combatant.isAlive(self: Combatant): boolean
	return not self.destroyed and self.humanoid.Health > 0 and self.model.Parent ~= nil and self.state ~= "Dead"
end

function Combatant.isIncapacitated(self: Combatant): boolean
	local state = self.state
	return state == "Stunned" or state == "GuardBroken" or state == "Knocked" or state == "Dead"
end

-- Starts a new action, cancelling any running one. Returns the token the action must hold.
function Combatant.begin(self: Combatant, state: string, duration: number?): number
	self.token += 1
	self.state = state
	self.stateUntil = if duration then os.clock() + duration else math.huge
	self.lastCombatAt = os.clock()
	self:sync()
	return self.token
end

-- Ends the action owning `token` (if it is still current).
function Combatant.finish(self: Combatant, token: number)
	if self.token == token and not self:isIncapacitated() then
		self.state = "Idle"
		self.stateUntil = 0
		self.hyperArmorUntil = 0
		self.feintableUntil = 0
		self:sync()
	end
end

-- Cancels whatever the combatant is doing without changing its state.
function Combatant.interrupt(self: Combatant)
	self.token += 1
	self.hyperArmorUntil = 0
	self.feintableUntil = 0
end

function Combatant.stun(self: Combatant, duration: number, state: string?)
	if self.state == "Knocked" or self.state == "Dead" or duration <= 0 then
		return
	end
	local now = os.clock()
	local newState = state or "Stunned"
	local untilTime = now + duration
	if self.state == newState and self.stateUntil > untilTime then
		return
	end
	self:interrupt()
	self.state = newState
	self.stateUntil = untilTime
	self.comboIndex = 0
	self:sync()
end

function Combatant.isInvulnerable(self: Combatant): boolean
	return os.clock() < self.iframesUntil
end

function Combatant.hasHyperArmor(self: Combatant): boolean
	return os.clock() < self.hyperArmorUntil or self:hasBuff("Harden") or self:hasBuff("Ignite")
end

function Combatant.hasBuff(self: Combatant, name: string): boolean
	local expiry = self.buffs[name]
	return expiry ~= nil and os.clock() < expiry
end

function Combatant.addBuff(self: Combatant, name: string, duration: number)
	self.buffs[name] = os.clock() + duration
	self:setAttr(`Buff_{name}`, toServerTime(os.clock() + duration))
	self:sync()
end

-- Can a new action start right now? Recovery windows (after the last hit frame) can be cancelled.
function Combatant.canAct(self: Combatant): boolean
	if not self:isAlive() or self:isIncapacitated() then
		return false
	end
	local state = self.state
	if state == "Idle" or state == "Blocking" then
		return true
	end
	if state == "Attacking" then
		return os.clock() >= self.chainOpensAt - Combat.ChainTolerance
	end
	return false
end

function Combatant.isFacing(self: Combatant, point: Vector3, angle: number): boolean
	local look = self.root.CFrame.LookVector
	local delta = point - self.root.Position
	local flat = Vector3.new(delta.X, 0, delta.Z)
	if flat.Magnitude < 1e-3 then
		return true
	end
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 1e-3 then
		return true
	end
	return flatLook.Unit:Dot(flat.Unit) >= math.cos(math.rad(angle / 2))
end

--[[ RESOURCES ]]

function Combatant.applyStats(self: Combatant, stats: Progression.CombatStats)
	local healthRatio = if self.humanoid.MaxHealth > 0 then self.humanoid.Health / self.humanoid.MaxHealth else 1
	local auraRatio = if self.stats.maxAura > 0 then self.aura / self.stats.maxAura else 1
	self.stats = stats
	self.humanoid.MaxHealth = stats.maxHealth
	if self.humanoid.Health > 0 then
		self.humanoid.Health = math.max(1, stats.maxHealth * healthRatio)
	end
	self.aura = if self.auraBroken then 0 else stats.maxAura * auraRatio
	self:sync()
end

function Combatant.addFury(self: Combatant, amount: number)
	if self.semblance == "Retribution" and amount > 0 then
		self.fury = math.clamp(self.fury + amount, 0, 100)
	end
end

-- Adds posture damage. Returns true if the guard broke.
function Combatant.addPosture(self: Combatant, amount: number): boolean
	local now = os.clock()
	if self:hasBuff("Harden") then
		amount *= 0.1
	end
	self.posture += amount
	self.lastPostureAt = now
	self:addFury(amount * 0.5)
	if self.posture >= self.stats.maxPosture then
		self.posture = 0
		self:stun(Combat.GuardBreakStun, "GuardBroken")
		return true
	end
	self:sync()
	return false
end

--[[
	Applies damage through Aura, then Health. Knocks players down instead of killing them.
	`options.ignoreKnock` lets executions finish a knocked player.
]]
function Combatant.takeDamage(
	self: Combatant,
	amount: number,
	source: Combatant?,
	options: { ignoreKnock: boolean?, projectile: boolean? }?
): DamageResult
	local result: DamageResult = { aura = 0, health = 0, auraBroke = false, knocked = false, killed = false }
	if not self:isAlive() or amount <= 0 then
		return result
	end
	local ignoreKnock = options ~= nil and options.ignoreKnock == true
	local projectile = options ~= nil and options.projectile == true
	if self.state == "Knocked" and not ignoreKnock then
		return result
	end

	local now = os.clock()
	if self:hasBuff("Harden") then
		amount *= 0.65
	end
	if projectile and self.semblance == "Polarity" then
		amount *= 0.85
	end

	self.lastHurtAt = now
	self.lastCombatAt = now
	if source then
		source.lastCombatAt = now
		self.damageLog[source] = (self.damageLog[source] or 0) + amount
	end
	self:addFury(amount * 1.6)

	local remaining = amount
	if self.kind == "Player" and not self.auraBroken and self.aura > 0 then
		local absorbed = math.min(self.aura, remaining)
		self.aura -= absorbed
		result.aura = absorbed
		self.lastAuraHitAt = now
		remaining = (remaining - absorbed) * Combat.AuraOverflowToHealth
		if self.aura <= 0.01 then
			self.aura = 0
			self.auraBroken = true
			self.auraBrokenAt = now
			result.auraBroke = true
		else
			remaining = 0
		end
	elseif self.kind == "Player" then
		remaining *= Combat.ExposedDamageMultiplier
	end

	if remaining > 0 then
		local health = self.humanoid.Health
		local newHealth = health - remaining
		result.health = math.min(health, remaining)
		if newHealth <= 0 then
			if self.kind == "Player" and not ignoreKnock then
				self.humanoid.Health = 1
				self:knock(source)
				result.knocked = true
			else
				self.humanoid.Health = 0
				self.state = "Dead"
				self:interrupt()
				result.killed = true
			end
		else
			self.humanoid.Health = newHealth
		end
	end
	self:sync()
	return result
end

function Combatant.knock(self: Combatant, by: Combatant?)
	self:interrupt()
	self.state = "Knocked"
	self.stateUntil = os.clock() + Combat.KnockedDuration
	self.knockedAt = os.clock()
	self.knockedBy = by
	self.grimmNearSince = 0
	self.posture = 0
	self.statuses = {}
	self:sync()
end

function Combatant.recoverFromKnock(self: Combatant)
	if self.state ~= "Knocked" then
		return
	end
	self.state = "Idle"
	self.stateUntil = 0
	self.knockedBy = nil
	self.humanoid.Health = math.max(1, self.stats.maxHealth * Combat.RecoverHealthFraction)
	self.iframesUntil = os.clock() + 1.5
	self:sync()
end

function Combatant.heal(self: Combatant, health: number, aura: number)
	if not self:isAlive() then
		return
	end
	self.humanoid.Health = math.min(self.stats.maxHealth, self.humanoid.Health + health)
	if aura > 0 then
		self.aura = math.min(self.stats.maxAura, self.aura + aura)
		if self.aura > 0 then
			self.auraBroken = false
		end
	end
	self:sync()
end

function Combatant.restoreFully(self: Combatant)
	self.humanoid.Health = self.stats.maxHealth
	self.aura = self.stats.maxAura
	self.auraBroken = false
	self.posture = 0
	self.fury = 0
	self.statuses = {}
	self.state = "Idle"
	self.stateUntil = 0
	self:sync()
end

--[[ STATUS EFFECTS ]]

function Combatant.addStatus(self: Combatant, kind: string, duration: number, power: number?, source: Combatant?)
	local now = os.clock()
	local existing = self.statuses[kind]
	if existing then
		existing.untilTime = math.max(existing.untilTime, now + duration)
		existing.power = math.max(existing.power, power or 0)
		existing.source = source or existing.source
	else
		self.statuses[kind] =
			{ kind = kind, untilTime = now + duration, power = power or 0, source = source, tickAt = now + 1 }
	end
	if kind == "Shock" then
		self:stun(duration)
	end
	self:sync()
end

function Combatant.slowFactor(self: Combatant): number
	local factor = 1
	local chill = self.statuses.Chill
	if chill then
		factor *= 1 - math.clamp(chill.power, 0, 0.9)
	end
	local slow = self.statuses.Slow
	if slow then
		factor *= 1 - math.clamp(slow.power, 0, 0.9)
	end
	return math.floor(factor * 100 + 0.5) / 100
end

--[[ TICK ]]

-- Called every Heartbeat by CombatService. Returns damage events from damage-over-time.
function Combatant.update(self: Combatant, dt: number): { { source: Combatant?, result: DamageResult, kind: string } }
	local events = {}
	if not self:isAlive() then
		return events
	end
	local now = os.clock()

	-- Timed states run out.
	if self.state ~= "Idle" and self.state ~= "Attacking" and self.state ~= "Blocking" and now >= self.stateUntil then
		if self.state == "Knocked" then
			self:recoverFromKnock()
		elseif self.state ~= "Dead" then
			self.state = "Idle"
			self.stateUntil = 0
		end
	end
	if self.state == "Attacking" and now >= self.stateUntil + 0.5 then
		-- Safety net if an action coroutine was lost.
		self.state = "Idle"
	end

	-- Combo resets after a pause.
	if self.comboIndex > 0 and now > self.comboExpires and self.state ~= "Attacking" then
		self.comboIndex = 0
	end

	-- Posture recovers when not under pressure.
	if self.posture > 0 and now - self.lastPostureAt > Combat.PostureRegenDelay and self.state ~= "Blocking" then
		self.posture = math.max(0, self.posture - Combat.PostureRegen * dt)
	end

	-- Aura regenerates after a delay (longer once shattered).
	if self.kind == "Player" and self.state ~= "Knocked" then
		local delay = if self.auraBroken then Combat.AuraBrokenDelay else Combat.AuraRegenDelay
		if now - math.max(self.lastAuraHitAt, self.lastHurtAt) > delay and self.aura < self.stats.maxAura then
			self.aura = math.min(
				self.stats.maxAura,
				self.aura + self.stats.maxAura * Combat.AuraRegenPercent * self.stats.auraRegen * dt
			)
			if self.auraBroken and self.aura >= self.stats.maxAura * 0.25 then
				self.auraBroken = false
			end
		end
		-- Health only trickles back out of combat.
		if now - self.lastCombatAt > Combat.OutOfCombatTime and self.humanoid.Health < self.stats.maxHealth then
			self.humanoid.Health = math.min(
				self.stats.maxHealth,
				self.humanoid.Health + self.stats.maxHealth * Combat.HealthRegenPercent * dt
			)
		end
	end

	-- Fury slowly cools.
	if self.fury > 0 and now - self.lastHurtAt > 6 then
		self.fury = math.max(0, self.fury - 4 * dt)
	end

	-- Status effects.
	for kind, status in self.statuses do
		if now >= status.untilTime then
			self.statuses[kind] = nil
		elseif kind == "Burn" and now >= status.tickAt then
			status.tickAt = now + 1
			local result = self:takeDamage(status.power, status.source)
			table.insert(events, { source = status.source, result = result, kind = "Burn" })
		end
	end

	self:sync()
	return events
end

function Combatant.destroy(self: Combatant)
	self.destroyed = true
	self:interrupt()
end

return Combatant
