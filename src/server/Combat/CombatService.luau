--!strict
--[[
	CombatService: the authority on every fight.

	Clients send intents over the Action remote (M1, Critical, Block, Dodge, Shift, ...). The
	server validates them against the Combatant's state and cooldowns, then runs the move's
	timeline from its animation clip: each "Hit" marker queries the hitbox and resolves the
	result in this order:

	    i-frames (dodged) -> parry window -> guard (posture) -> hit (Aura, Health, hitstun)

	Results are broadcast on the Effects remote so every client plays the same animations,
	impact effects and hitstop. Players predict their own actions; broadcasts carry the
	client's sequence number so the owner does not play them twice.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Clip = require(Shared.Animation.Clip)
local ClipLibrary = require(Shared.Animation.ClipLibrary)
local Combat = require(Shared.Config.Combat)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Impulse = require(Shared.Util.Impulse)
local Weapons = require(Shared.Config.Weapons)
local WeaponModels = require(Shared.Config.WeaponModels)
local World = require(Shared.Config.World)

local Combatant = require(script.Parent.Combatant)
local Hitbox = require(script.Parent.Hitbox)
local Projectiles = require(script.Parent.Projectiles)

export type Combatant = Combatant.Combatant
type MoveDef = Weapons.MoveDef
type HitDef = Weapons.HitDef
type ShotDef = Weapons.ShotDef

export type MoveContext = {
	kind: string, -- "M1" | "Critical" | "Shoot" | "Grimm" | ...
	seq: number?,
	look: Vector3?,
	aim: Vector3?,
	final: boolean?,
}

export type Outcome = "Hit" | "Block" | "GuardBreak" | "Parry" | "Dodge" | "Immune"

local CombatService = {}

CombatService.Hit = Signal.new() :: Signal.Signal<Combatant, Combatant, Outcome>
CombatService.Knocked = Signal.new() :: Signal.Signal<Combatant, Combatant?>
CombatService.Killed = Signal.new() :: Signal.Signal<Combatant, Combatant?>

-- Extra action handlers registered by other modules (Abilities, Grimm...). Signature (combatant, payload, player).
CombatService.handlers = {} :: { [string]: (Combatant, { [string]: any }, Player?) -> boolean }

local combatants: { [Model]: Combatant } = {}
local modelList: { Model } = {}
local random = Random.new()

local effects: RemoteEvent
local motion: RemoteEvent

--[[ REGISTRY ]]

local function rebuildModelList()
	table.clear(modelList)
	for model in combatants do
		table.insert(modelList, model)
	end
end

function CombatService.register(model: Model, kind: string): Combatant?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		warn(`[Combat] cannot register {model:GetFullName()}: missing Humanoid or HumanoidRootPart`)
		return nil
	end
	local existing = combatants[model]
	if existing then
		return existing
	end
	local combatant = Combatant.new(model, humanoid, root, kind)
	combatants[model] = combatant
	rebuildModelList()
	model.Destroying:Connect(function()
		CombatService.unregister(model)
	end)
	return combatant
end

function CombatService.unregister(model: Model)
	local combatant = combatants[model]
	if combatant then
		combatant:destroy()
		combatants[model] = nil
		rebuildModelList()
	end
end

function CombatService.get(model: Instance?): Combatant?
	if model == nil or not model:IsA("Model") then
		return nil
	end
	return combatants[model]
end

function CombatService.fromPlayer(player: Player): Combatant?
	return CombatService.get(player.Character)
end

-- Walks up from a part to the combatant that owns it.
function CombatService.fromPart(part: Instance?): Combatant?
	local node = part
	while node and node ~= Workspace do
		if node:IsA("Model") then
			local combatant = combatants[node]
			if combatant then
				return combatant
			end
		end
		node = node.Parent
	end
	return nil
end

function CombatService.all(): { [Model]: Combatant }
	return combatants
end

--[[ REPLICATION ]]

function CombatService.broadcast(kind: string, payload: { [string]: any })
	effects:FireAllClients(kind, payload)
end

-- Plays a clip on a rig for every client. `seq` marks it as the owner's predicted action.
function CombatService.playOn(combatant: Combatant, clipId: string, speed: number?, seq: number?)
	effects:FireAllClients("Action", {
		rig = combatant.model,
		clip = clipId,
		speed = speed or 1,
		seq = seq,
		t = Workspace:GetServerTimeNow(),
	})
end

function CombatService.stopOn(combatant: Combatant, fade: number?)
	effects:FireAllClients("Stop", { rig = combatant.model, fade = fade or 0.1 })
end

function CombatService.reject(player: Player?, seq: number?)
	if player then
		effects:FireClient(player, "Reject", { seq = seq })
	end
end

-- Pushes a combatant. Players are pushed by their own client (they own their physics).
function CombatService.push(target: Combatant, velocity: Vector3, duration: number)
	if velocity.Magnitude < 0.5 then
		return
	end
	if target.player then
		motion:FireClient(target.player, "Impulse", { velocity = velocity, duration = duration })
	else
		Impulse.apply(target.root, velocity, { duration = duration, name = "Knockback" })
	end
end

--[[ RELATIONSHIPS ]]

local function hostile(attacker: Combatant, target: Combatant): boolean
	if attacker == target then
		return false
	end
	if target.owner == attacker or attacker.owner == target then
		return false
	end
	local attackerGrimm = attacker.kind == "Grimm"
	local targetGrimm = target.kind == "Grimm"
	if attackerGrimm and targetGrimm then
		return false
	end
	if attacker.kind ~= "Grimm" and target.kind ~= "Grimm" then
		-- Huntsman vs Huntsman: no fighting inside safe zones.
		if World.isSafe(attacker.root.Position) or World.isSafe(target.root.Position) then
			return false
		end
	end
	return true
end
CombatService.hostile = hostile

--[[ HIT RESOLUTION ]]

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.zero
end

local function damageMultiplier(attacker: Combatant): number
	local mult = attacker.stats.damage
	if attacker:hasBuff("Ignite") then
		mult *= 1.35
	end
	return mult
end

local function postureMultiplier(attacker: Combatant): number
	local mult = attacker.stats.postureDamage
	if attacker:hasBuff("Ignite") then
		mult *= 1.4
	end
	return mult
end

export type Strike = {
	damage: number,
	posture: number?,
	hitstun: number?,
	knockback: Vector3?, -- world-space velocity
	heavy: boolean?,
	status: Weapons.Status?,
	unblockable: boolean?,
	unparryable: boolean?,
	projectile: boolean?,
	dust: boolean?,
	position: Vector3?, -- impact point for effects
}

--[[
	Resolves one strike from `attacker` on `target`. Returns the outcome (or nil if ignored).
]]
function CombatService.resolve(attacker: Combatant, target: Combatant, strike: Strike): Outcome?
	if not target:isAlive() or target.state == "Knocked" or not hostile(attacker, target) then
		return nil
	end
	local now = os.clock()
	local attackerPos = attacker.root.Position
	local direction = flat(target.root.Position - attackerPos)
	local impact = strike.position or target.root.Position:Lerp(attackerPos, 0.3) + Vector3.new(0, 0.6, 0)

	local payload: { [string]: any } = {
		attacker = attacker.model,
		victim = target.model,
		position = impact,
		direction = direction,
		heavy = strike.heavy == true,
	}

	if target.kind == "Clone" then
		target.humanoid.Health = 0
		payload.result = "Clone"
		CombatService.broadcast("Hit", payload)
		return "Immune"
	end

	if target:isInvulnerable() then
		payload.result = "Dodge"
		CombatService.broadcast("Hit", payload)
		return "Dodge"
	end

	local guardAngle = (target.form and target.form.blockAngle) or Combat.BlockAngle
	local facing = target:isFacing(attackerPos, guardAngle)
	local behind = not target:isFacing(attackerPos, 200)

	-- Parry: guard raised within the window turns the attack back on the attacker.
	if target.state == "Blocking" and now <= target.parryUntil and facing and not strike.unparryable then
		target.parryUntil = 0
		target.parryLockUntil = now
		target.posture = math.max(0, target.posture - Combat.ParryPostureReward)
		target:sync()
		if not strike.projectile then
			attacker:stun(Combat.ParryStun)
			CombatService.playOn(attacker, "Common.Parried")
		end
		CombatService.playOn(target, "Common.Parry")
		payload.result = "Parry"
		CombatService.broadcast("Hit", payload)
		CombatService.Hit:Fire(attacker, target, "Parry")
		return "Parry"
	end

	-- Guard: posture absorbs the blow.
	if target.state == "Blocking" and facing and not strike.unblockable then
		local shield = (target.form and target.form.blockPosture) or 1
		local posture = (strike.posture or strike.damage) * shield * postureMultiplier(attacker)
		local broke = target:addPosture(posture)
		target.lastCombatAt = now
		if broke then
			CombatService.playOn(target, "Common.GuardBreak")
			payload.result = "GuardBreak"
		else
			payload.result = "Block"
			CombatService.push(target, direction * 14, 0.12)
		end
		CombatService.broadcast("Hit", payload)
		CombatService.Hit:Fire(attacker, target, payload.result)
		return payload.result
	end

	-- Clean hit.
	local damage = strike.damage * (if strike.dust then attacker.stats.dustDamage else damageMultiplier(attacker))
	if behind then
		damage *= Combat.BackstabMultiplier
	end
	local result = target:takeDamage(damage, attacker, { projectile = strike.projectile })
	payload.result = "Hit"
	payload.damage = math.floor(damage * 10 + 0.5) / 10
	payload.aura = result.aura > 0 and result.health <= 0
	payload.auraBroke = result.auraBroke
	payload.knocked = result.knocked
	payload.killed = result.killed

	if not result.knocked and not result.killed then
		if not target:hasHyperArmor() then
			local stun = (strike.hitstun or 0.4) * (if target.grimm then target.grimm.hitstunMultiplier else 1)
			if result.auraBroke then
				stun = math.max(stun, Combat.AuraBreakStun)
			end
			target:stun(stun)
			local knockback = strike.knockback
			if knockback and knockback.Magnitude > 1 then
				CombatService.push(target, knockback, if knockback.Y > 20 then 0.22 else 0.16)
			else
				CombatService.push(target, direction * 6, 0.1)
			end
			payload.stagger = true
		end
		local status = strike.status
		if status then
			target:addStatus(status.kind, status.duration, status.power, attacker)
		end
	end

	CombatService.broadcast("Hit", payload)
	CombatService.Hit:Fire(attacker, target, "Hit")
	if result.knocked then
		CombatService.Knocked:Fire(target, attacker)
	elseif result.killed then
		CombatService.Killed:Fire(target, attacker)
	end
	return "Hit"
end

-- Converts a weapon HitDef into a world-space strike from the attacker's frame.
local function strikeFromHit(hit: HitDef, move: MoveDef, frame: CFrame): Strike
	local knockback: Vector3? = nil
	local local_ = hit.knockback
	if local_ then
		knockback = frame:VectorToWorldSpace(Vector3.new(local_.X, local_.Y, -local_.Z))
	end
	return {
		damage = hit.damage,
		posture = hit.posture,
		hitstun = hit.hitstun,
		knockback = knockback,
		heavy = hit.heavy,
		status = hit.status,
		unblockable = move.unblockable,
		unparryable = move.unparryable,
	}
end

-- Combatants (other than `attacker`) inside a hitbox.
function CombatService.query(attacker: Combatant, box: Weapons.Hitbox, frame: CFrame): { Combatant }
	local include: { Instance } = {}
	for _, model in modelList do
		if model ~= attacker.model then
			table.insert(include, model)
		end
	end
	if #include == 0 then
		return {}
	end
	local scale = if attacker.grimm then attacker.grimm.scale else 1
	local found: { Combatant } = {}
	local seen: { [Combatant]: boolean } = {}
	for _, part in Hitbox.query(frame, box, scale, include) do
		local target = CombatService.fromPart(part)
		if target and not seen[target] and target ~= attacker then
			seen[target] = true
			table.insert(found, target)
		end
	end
	return found
end

function CombatService.strike(attacker: Combatant, move: MoveDef, index: number, look: Vector3?)
	local hit = move.hits[index] or move.hits[#move.hits]
	if hit == nil then
		return
	end
	local frame = Hitbox.frame(attacker.root, look)
	for _, target in CombatService.query(attacker, hit.hitbox or move.hitbox, frame) do
		CombatService.resolve(attacker, target, strikeFromHit(hit, move, frame))
	end
end

--[[ SHOTS ]]

local function shotParams(attacker: Combatant): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { attacker.model }
	local effectsFolder = Workspace:FindFirstChild("Effects")
	if effectsFolder then
		table.insert(ignore, effectsFolder)
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	return params
end

local function muzzleOrigin(attacker: Combatant): Vector3
	return attacker.root.Position + Vector3.new(0, 1.4, 0)
end

function CombatService.explode(attacker: Combatant, position: Vector3, shot: ShotDef)
	local radius = shot.radius or 10
	CombatService.broadcast("Explosion", { position = position, radius = radius, rig = attacker.model })
	for _, target in CombatService.query(attacker, { shape = "Sphere", radius = radius }, CFrame.new(position)) do
		local offset = target.root.Position - position
		local falloff = math.clamp(1 - offset.Magnitude / (radius * 1.3), 0.35, 1)
		local away = flat(offset)
		if away.Magnitude < 0.5 then
			away = flat(target.root.Position - attacker.root.Position)
		end
		CombatService.resolve(attacker, target, {
			damage = shot.damage * falloff,
			posture = (shot.posture or shot.damage) * falloff,
			hitstun = shot.hitstun,
			knockback = away * (shot.knockback or 30) + Vector3.new(0, (shot.knockback or 30) * 0.7, 0),
			heavy = true,
			projectile = true,
			unparryable = true,
			status = shot.status,
			position = target.root.Position,
		})
	end
end

function CombatService.fireShot(attacker: Combatant, shot: ShotDef, aim: Vector3?)
	local origin = muzzleOrigin(attacker)
	local direction = if aim and aim.Magnitude > 0.1 then aim.Unit else attacker.root.CFrame.LookVector
	local params = shotParams(attacker)

	if shot.kind == "Hitscan" then
		local result = Workspace:Raycast(origin, direction * shot.range, params)
		local finish = if result then result.Position else origin + direction * shot.range
		CombatService.broadcast("Shot", { rig = attacker.model, kind = "Hitscan", from = origin, to = finish })
		local target = if result then CombatService.fromPart(result.Instance) else nil
		if target then
			CombatService.resolve(attacker, target, {
				damage = shot.damage,
				posture = shot.posture,
				hitstun = shot.hitstun,
				knockback = direction * (shot.knockback or 0),
				projectile = true,
				status = shot.status,
				position = finish,
			})
		end
	elseif shot.kind == "Pellets" then
		local totals: { [Combatant]: { damage: number, point: Vector3 } } = {}
		local ends = {}
		for _ = 1, shot.pellets or 6 do
			local pelletDir = Hitbox.spread(direction, shot.spread or 6, random)
			local result = Workspace:Raycast(origin, pelletDir * shot.range, params)
			local finish = if result then result.Position else origin + pelletDir * shot.range
			table.insert(ends, finish)
			local target = if result then CombatService.fromPart(result.Instance) else nil
			if target then
				local entry = totals[target]
				if entry then
					entry.damage += shot.damage
				else
					totals[target] = { damage = shot.damage, point = finish }
				end
			end
		end
		CombatService.broadcast("Shot", { rig = attacker.model, kind = "Pellets", from = origin, ends = ends })
		for target, entry in totals do
			local share = entry.damage / (shot.damage * (shot.pellets or 6))
			CombatService.resolve(attacker, target, {
				damage = entry.damage,
				posture = (shot.posture or 0) * share * (shot.pellets or 6),
				hitstun = shot.hitstun,
				knockback = direction * (shot.knockback or 0) * (0.4 + share),
				projectile = true,
				status = shot.status,
				position = entry.point,
			})
		end
	elseif shot.kind == "Grenade" then
		local speed = shot.speed or 100
		local velocity = (direction + Vector3.new(0, 0.18, 0)).Unit * speed
		local gravity = 120
		CombatService.broadcast("Projectile", {
			rig = attacker.model,
			kind = "Grenade",
			from = origin,
			velocity = velocity,
			gravity = gravity,
		})
		Projectiles.launch({
			origin = origin,
			velocity = velocity,
			gravity = gravity,
			lifetime = 3,
			ignore = { attacker.model },
			onImpact = function(position)
				if attacker.model.Parent then
					CombatService.explode(attacker, position, shot)
				end
			end,
		})
	end
end

--[[ MOVES ]]

local function markerTimes(clip: Clip.Clip, name: string, rate: number): { number }
	local times = {}
	for _, marker in Clip.markersNamed(clip, name) do
		table.insert(times, marker.t / rate)
	end
	return times
end

--[[
	Runs a move's full timeline: broadcast the clip, then strike/shoot at its markers.
	Returns false if the clip is missing.
]]
function CombatService.performMove(c: Combatant, move: MoveDef, ctx: MoveContext): boolean
	local clip = ClipLibrary.get(move.clip)
	if clip == nil then
		warn(`[Combat] move uses unknown clip {move.clip}`)
		return false
	end
	local playback = move.speed or 1
	local rate = clip.speed * playback
	local duration = clip.length / rate
	local token = c:begin("Attacking", duration)
	local now = os.clock()

	local hits = markerTimes(clip, "Hit", rate)
	local shots = markerTimes(clip, "Shoot", rate)
	local first = hits[1] or shots[1] or duration * 0.4
	local last = math.max(hits[#hits] or 0, shots[#shots] or 0, first)
	local chain = Clip.markerTime(clip, "Chain")

	c.chainOpensAt = now + (if chain then chain / rate else last + 0.06)
	c.feintableUntil = if move.feintable then now + first - Combat.FeintWindowPadding else 0
	c.hyperArmorUntil = if move.hyperArmor then now + first + 0.05 else 0
	c.comboExpires = now + duration + Combat.ComboResetTime
	if ctx.final then
		c.comboLockUntil = now + duration + Combat.ComboEndLag
	end

	CombatService.playOn(c, move.clip, playback, ctx.seq)

	type Event = { t: number, kind: string, index: number, data: any? }
	local events: { Event } = {}
	for i, t in hits do
		table.insert(events, { t = t, kind = "Hit", index = i })
	end
	for i, t in shots do
		table.insert(events, { t = t, kind = "Shoot", index = i })
	end
	if c.player == nil then
		-- Grimm lunge on the server (players lunge on their own client from the same markers).
		for _, marker in Clip.markersNamed(clip, "Lunge") do
			table.insert(events, { t = marker.t / rate, kind = "Lunge", index = 0, data = marker.data })
		end
	end
	table.sort(events, function(a, b)
		return a.t < b.t
	end)

	task.spawn(function()
		local start = os.clock()
		for _, event in events do
			local delay = event.t - (os.clock() - start)
			if delay > 0 then
				task.wait(delay)
			end
			if c.token ~= token or not c:isAlive() then
				return
			end
			if event.kind == "Hit" then
				CombatService.strike(c, move, event.index, ctx.look)
			elseif event.kind == "Shoot" then
				local shot = move.shot
				if shot then
					CombatService.fireShot(c, shot, ctx.aim or ctx.look)
				end
			elseif event.kind == "Lunge" then
				local speed = if type(event.data) == "number" then event.data else 30
				local look = Hitbox.frame(c.root, ctx.look).LookVector
				Impulse.apply(c.root, look * speed, { duration = 0.18, planar = true, decay = true, name = "Lunge" })
			end
		end
		local remaining = duration - (os.clock() - start)
		if remaining > 0 then
			task.wait(remaining)
		end
		c:finish(token)
	end)
	return true
end

--[[ FORMS ]]

function CombatService.setWeapon(c: Combatant, weaponId: string, formName: string?)
	local weapon = Weapons.get(weaponId)
	if weapon == nil then
		return
	end
	c.weapon = weapon
	local form = Weapons.form(weapon, formName or weapon.forms[1].name)
	CombatService.setForm(c, form.name)
	c:setAttr("Weapon", weapon.id)
	c:setAttr("WeaponModel", weapon.model)
end

function CombatService.setForm(c: Combatant, formName: string)
	local weapon = c.weapon
	if weapon == nil then
		return
	end
	local form = Weapons.form(weapon, formName)
	c.form = form
	c.comboIndex = 0
	c:setAttr("WeaponForm", form.name)
	c:setAttr("Stance", form.stance)
	c:setAttr("Ranged", form.ranged)
	if not form.ranged then
		c:setAttr("Aiming", false)
	end
end

--[[ PLAYER ACTIONS ]]

local handlers = CombatService.handlers

local function lookFrom(c: Combatant, payload: { [string]: any }): Vector3?
	return Hitbox.validateLook(c.root, payload.look, Combat.MaxHitAngleCorrection)
end

local function aimFrom(c: Combatant, payload: { [string]: any }): Vector3?
	local aim = payload.aim
	if typeof(aim) == "Vector3" and aim.Magnitude > 0.1 and aim.Magnitude == aim.Magnitude then
		local look = c.root.CFrame.LookVector
		if aim.Unit:Dot(look) > -0.2 then
			return aim.Unit
		end
	end
	return nil
end

handlers.M1 = function(c, payload)
	local form = c.form
	if form == nil then
		return false
	end
	if form.ranged then
		return handlers.Shoot(c, payload)
	end
	local chain = form.m1
	if chain == nil or #chain == 0 or not c:canAct() or os.clock() < c.comboLockUntil then
		return false
	end
	local index = (c.comboIndex % #chain) + 1
	c.comboIndex = index
	return CombatService.performMove(c, chain[index], {
		kind = "M1",
		seq = payload.seq,
		look = lookFrom(c, payload),
		final = index == #chain,
	})
end

handlers.Shoot = function(c, payload)
	local form = c.form
	local shoot = form and form.shoot
	if shoot == nil or not c:canAct() or not c:ready("Shoot") then
		return false
	end
	local clipId = if shoot.altClip and c.shotCount % 2 == 1 then shoot.altClip else shoot.clip
	c.shotCount += 1
	c:setCooldown("Shoot", shoot.cooldown)
	local aim = aimFrom(c, payload)
	return CombatService.performMove(c, {
		clip = clipId,
		hitbox = { size = Vector3.one },
		hits = {},
		shot = shoot.shot,
	}, { kind = "Shoot", seq = payload.seq, look = lookFrom(c, payload), aim = aim })
end

handlers.Critical = function(c, payload)
	local form = c.form
	local move = form and form.critical
	if move == nil or not c:canAct() or not c:ready("Critical") then
		return false
	end
	c:setCooldown("Critical", move.cooldown or Combat.CriticalCooldown)
	c.comboIndex = 0
	return CombatService.performMove(c, move, {
		kind = "Critical",
		seq = payload.seq,
		look = lookFrom(c, payload),
		aim = aimFrom(c, payload),
	})
end

handlers.Feint = function(c, payload)
	if c.state ~= "Attacking" or os.clock() > c.feintableUntil or not c:ready("Feint") then
		return false
	end
	c:interrupt()
	c.state = "Idle"
	c.comboIndex = 0
	c:sync()
	c:setCooldown("Feint", Combat.FeintCooldown)
	CombatService.playOn(c, "Common.Feint", 1, payload.seq)
	return true
end

handlers.BlockStart = function(c, _payload)
	if c.state == "Blocking" then
		return true
	end
	if not c:canAct() then
		return false
	end
	c:begin("Blocking")
	local now = os.clock()
	c.blockStartedAt = now
	if now >= c.parryLockUntil then
		c.parryUntil = now + Combat.ParryWindow
		c.parryLockUntil = now + Combat.ParryWindow + Combat.ParryFailCooldown
	end
	c:setAttr("Aiming", false)
	c:sync()
	return true
end

handlers.BlockEnd = function(c, _payload)
	if c.state == "Blocking" then
		c:finish(c.token)
	end
	return true
end

local DODGE_CLIPS = {
	Forward = "Common.DodgeForward",
	Back = "Common.DodgeBack",
	Left = "Common.DodgeLeft",
	Right = "Common.DodgeRight",
	Air = "Common.AirDash",
}

handlers.Dodge = function(c, payload)
	if not c:isAlive() or c:isIncapacitated() or not c:ready("Dodge") then
		return false
	end
	if c.state == "Dodging" or c.state == "Casting" then
		return false
	end
	if c.state == "Attacking" and os.clock() < c.chainOpensAt - Combat.ChainTolerance then
		return false
	end
	local direction = if type(payload.dir) == "string" and DODGE_CLIPS[payload.dir] then payload.dir else "Back"
	c:begin("Dodging", Combat.DodgeDuration)
	c.iframesUntil = os.clock() + Combat.DodgeIFrames
	c:setCooldown("Dodge", Combat.DodgeCooldown * c.stats.dodgeCooldown)
	c:sync()
	CombatService.playOn(c, DODGE_CLIPS[direction], 1, payload.seq)
	return true
end

handlers.Slide = function(c, payload)
	if not c:canAct() or not c:ready("Slide") then
		return false
	end
	c:begin("Dodging", Combat.SlideDuration)
	c:setCooldown("Slide", Combat.SlideCooldown)
	CombatService.playOn(c, "Common.Slide", 1, payload.seq)
	return true
end

handlers.Shift = function(c, payload)
	local weapon = c.weapon
	local form = c.form
	if weapon == nil or form == nil or #weapon.forms < 2 or not c:canAct() or not c:ready("Shift") then
		return false
	end
	local model = WeaponModels[weapon.model]
	local duration = if model then model.shiftTime else 0.5
	local nextForm = Weapons.nextForm(weapon, form.name)
	c:begin("Casting", duration)
	c:setCooldown("Shift", duration + 0.35)
	CombatService.setForm(c, nextForm.name)
	CombatService.playOn(c, "Common.Shift", 1, payload.seq)
	return true
end

handlers.Aim = function(c, payload)
	local on = payload.on == true and c.form ~= nil and c.form.ranged and c:isAlive()
	c:setAttr("Aiming", on)
	return true
end

handlers.Execute = function(c, payload)
	if not c:canAct() then
		return false
	end
	local best: Combatant? = nil
	local bestDistance = Combat.ExecuteRange
	for _, other in combatants do
		if other ~= c and other.state == "Knocked" and other:isAlive() and hostile(c, other) then
			local distance = (other.root.Position - c.root.Position).Magnitude
			if distance <= bestDistance then
				best = other
				bestDistance = distance
			end
		end
	end
	local target = best
	if target == nil then
		return false
	end
	local token = c:begin("Casting", Combat.ExecuteDuration)
	target.stateUntil = math.huge
	CombatService.playOn(c, "Common.Execute", 1, payload.seq)
	CombatService.playOn(target, "Common.Executed")
	task.delay(Combat.ExecuteDuration * 0.72, function()
		if c.token == token and c:isAlive() and target.state == "Knocked" and target:isAlive() then
			CombatService.kill(target, c)
		elseif target.state == "Knocked" then
			target.stateUntil = os.clock() + 4
		end
	end)
	return true
end

-- Finishes a combatant regardless of knock protection.
function CombatService.kill(target: Combatant, killer: Combatant?)
	if not target:isAlive() then
		return
	end
	target:takeDamage(math.huge, killer, { ignoreKnock = true })
	target.state = "Dead"
	target:sync()
	CombatService.broadcast("Hit", {
		attacker = if killer then killer.model else nil,
		victim = target.model,
		position = target.root.Position,
		direction = Vector3.zero,
		result = "Hit",
		killed = true,
		heavy = true,
	})
	CombatService.Killed:Fire(target, killer)
end

--[[ INPUT ROUTING ]]

local RATE_LIMIT = 24 -- actions per second per player
local budgets: { [Player]: { tokens: number, last: number } } = {}

local function allow(player: Player): boolean
	local now = os.clock()
	local budget = budgets[player]
	if budget == nil then
		budget = { tokens = RATE_LIMIT, last = now }
		budgets[player] = budget
	end
	budget.tokens = math.min(RATE_LIMIT, budget.tokens + (now - budget.last) * RATE_LIMIT)
	budget.last = now
	if budget.tokens < 1 then
		return false
	end
	budget.tokens -= 1
	return true
end

local function onAction(player: Player, kind: any, payload: any)
	if type(kind) ~= "string" or not allow(player) then
		return
	end
	local data: { [string]: any } = if type(payload) == "table" then payload else {}
	if data.seq ~= nil and type(data.seq) ~= "number" then
		data.seq = nil
	end
	local c = CombatService.fromPlayer(player)
	local handler = handlers[kind]
	if c == nil or handler == nil then
		return
	end
	local ok, accepted = pcall(handler, c, data, player)
	if not ok then
		warn(`[Combat] {kind} handler error: {accepted}`)
		CombatService.reject(player, data.seq)
	elseif not accepted then
		CombatService.reject(player, data.seq)
	end
end

local function onAim(player: Player, pitch: any)
	if type(pitch) ~= "number" or pitch ~= pitch then
		return
	end
	local c = CombatService.fromPlayer(player)
	if c then
		c:setAttr("AimPitch", math.floor(math.clamp(pitch, -80, 80) / 2 + 0.5) * 2)
	end
end

--[[ LIFECYCLE ]]

local function heartbeat(dt: number)
	for _, c in combatants do
		if c:isAlive() then
			for _, event in c:update(dt) do
				local result = event.result
				if result.aura > 0 or result.health > 0 then
					CombatService.broadcast("Hit", {
						attacker = if event.source then event.source.model else nil,
						victim = c.model,
						position = c.root.Position + Vector3.new(0, 1, 0),
						direction = Vector3.zero,
						result = event.kind,
						damage = math.floor((result.aura + result.health) * 10 + 0.5) / 10,
						aura = result.aura > 0,
						auraBroke = result.auraBroke,
						knocked = result.knocked,
						killed = result.killed,
					})
				end
				if result.knocked then
					CombatService.Knocked:Fire(c, event.source)
				elseif result.killed then
					CombatService.Killed:Fire(c, event.source)
				end
			end
		end
	end
end

function CombatService.init()
	effects = Net.event("Effects")
	motion = Net.event("Motion")
	ClipLibrary.load()
end

function CombatService.start()
	Net.event("Action").OnServerEvent:Connect(onAction)
	Net.unreliable("Aim").OnServerEvent:Connect(onAim)
	Players.PlayerRemoving:Connect(function(player)
		budgets[player] = nil
	end)
	Projectiles.start()
	RunService.Heartbeat:Connect(heartbeat)
end

return CombatService
