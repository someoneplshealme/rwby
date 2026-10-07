--!strict
--[[
	Semblances (E) and Dust techniques (1-4).

	Every ability is a cast: the clip is broadcast immediately, the effect happens at the clip's
	"Cast" marker, and getting hit before then fizzles it. Movement parts of abilities (the
	Velocity dash, the Shadow blink, Glyph launches) run on the caster's client, which owns its
	character physics; the server handles damage, statuses, clones and zones.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local ClipLibrary = require(Shared.Animation.ClipLibrary)
local Dust = require(Shared.Config.Dust)
local Semblances = require(Shared.Config.Semblances)

local CombatService = require(script.Parent.CombatService)
local Projectiles = require(script.Parent.Projectiles)

type Combatant = CombatService.Combatant

local Abilities = {}

-- Supplied by the data layer: consumes one vial of Dust from the player's inventory.
Abilities.takeDust = function(_player: Player, _dustId: string): boolean
	return true
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.new(0, 0, -1)
end

local function lookOf(c: Combatant, payload: { [string]: any }): Vector3
	local look = payload.look
	if typeof(look) == "Vector3" and look.Magnitude > 0.1 and look.Magnitude == look.Magnitude then
		local candidate = flat(look)
		if candidate:Dot(flat(c.root.CFrame.LookVector)) > 0 then
			return candidate
		end
	end
	return flat(c.root.CFrame.LookVector)
end

-- Plays `clipId` and calls `effect` at its "Cast" marker unless interrupted. Returns the token.
local function cast(c: Combatant, clipId: string, seq: number?, effect: () -> ()): number
	local clip = ClipLibrary.expect(clipId)
	local duration = clip.length / clip.speed
	local castAt = (ClipLibrary.markerSeconds(clipId, "Cast") or duration * 0.4)
	local token = c:begin("Casting", duration)
	CombatService.playOn(c, clipId, 1, seq)
	task.delay(castAt, function()
		if c.token == token and c:isAlive() and not c:isIncapacitated() then
			effect()
		end
	end)
	return token
end

local function hostilesNear(c: Combatant, position: Vector3, radius: number): { Combatant }
	local found = {}
	for _, other in CombatService.all() do
		if other ~= c and other:isAlive() and CombatService.hostile(c, other) then
			if (other.root.Position - position).Magnitude <= radius then
				table.insert(found, other)
			end
		end
	end
	return found
end

--[[ SEMBLANCES ]]

local semblanceCasts: { [string]: (Combatant, { [string]: any }, number) -> boolean } = {}

semblanceCasts.Velocity = function(c, payload, cooldown)
	local def = Semblances.get("Velocity")
	if def == nil then
		return false
	end
	local p = def.params
	c:begin("Dodging", p.duration)
	c.iframesUntil = os.clock() + p.duration
	c:setCooldown("Semblance", cooldown)
	CombatService.playOn(c, def.clip, 1, payload.seq)
	CombatService.broadcast("Effect", { name = "PetalBurst", rig = c.model, duration = p.duration })
	-- Everything the dash passes through gets clipped once.
	local struck: { [Combatant]: boolean } = {}
	task.spawn(function()
		local start = os.clock()
		while os.clock() - start < p.duration + 0.05 and c:isAlive() do
			for _, target in hostilesNear(c, c.root.Position, 6) do
				if not struck[target] then
					struck[target] = true
					CombatService.resolve(c, target, {
						damage = p.damage,
						posture = 8,
						hitstun = p.stun,
						knockback = flat(c.root.AssemblyLinearVelocity) * 20 + Vector3.new(0, 14, 0),
						unparryable = true,
						unblockable = false,
					})
				end
			end
			task.wait(0.04)
		end
	end)
	return true
end

local function spawnClone(c: Combatant, duration: number)
	local model = c.model
	local wasArchivable = model.Archivable
	model.Archivable = true
	local ok, clone = pcall(function()
		return model:Clone()
	end)
	model.Archivable = wasArchivable
	if not ok or not clone then
		return
	end
	clone.Name = `{model.Name}'s Shadow`
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("LinearVelocity") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.MaxHealth = 1
		humanoid.Health = 1
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(28, 18, 44)
	highlight.FillTransparency = 0.15
	highlight.OutlineColor = Color3.fromRGB(150, 110, 230)
	highlight.OutlineTransparency = 0.4
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = clone
	clone:SetAttribute("Clone", true)
	clone.Parent = Workspace
	CollectionService:AddTag(clone, "Rig")
	local shadow = CombatService.register(clone, "Clone")
	if shadow then
		shadow.owner = c
	end
	task.delay(duration, function()
		if clone.Parent then
			CombatService.broadcast("Effect", { name = "CloneFade", rig = clone })
			task.wait(0.35)
			clone:Destroy()
		end
	end)
end

semblanceCasts.Shadow = function(c, payload, cooldown)
	local def = Semblances.get("Shadow")
	if def == nil then
		return false
	end
	local p = def.params
	c:setCooldown("Semblance", cooldown)
	c.iframesUntil = os.clock() + p.iframes
	c:begin("Dodging", 0.3)
	spawnClone(c, p.cloneDuration)
	CombatService.playOn(c, def.clip, 1, payload.seq)
	CombatService.broadcast("Effect", { name = "ShadowStep", rig = c.model, position = c.root.Position })
	return true
end

semblanceCasts.Retribution = function(c, payload, cooldown)
	local def = Semblances.get("Retribution")
	if def == nil then
		return false
	end
	local p = def.params
	if c.fury < p.minFury then
		return false
	end
	local duration = p.baseDuration + c.fury * p.durationPerFury
	c:setCooldown("Semblance", cooldown)
	cast(c, def.clip, payload.seq, function()
		c.fury = 0
		c:addBuff("Ignite", duration)
		CombatService.broadcast("Effect", { name = "Ignite", rig = c.model, duration = duration })
	end)
	return true
end

semblanceCasts.Polarity = function(c, payload, cooldown)
	local def = Semblances.get("Polarity")
	if def == nil then
		return false
	end
	local p = def.params
	local look = lookOf(c, payload)
	c:setCooldown("Semblance", cooldown)
	cast(c, def.clip, payload.seq, function()
		local best: Combatant? = nil
		local bestDistance = p.range
		for _, other in hostilesNear(c, c.root.Position, p.range) do
			local offset = other.root.Position - c.root.Position
			local distance = offset.Magnitude
			if distance < bestDistance and flat(offset):Dot(look) >= math.cos(math.rad(p.angle)) then
				best = other
				bestDistance = distance
			end
		end
		local target = best
		if target == nil then
			CombatService.broadcast("Effect", { name = "Magnetize", rig = c.model, direction = look })
			return
		end
		local toCaster = flat(c.root.Position - target.root.Position)
		local speed = math.clamp(bestDistance * 3.2, 45, 115)
		CombatService.broadcast("Effect", { name = "Magnetize", rig = c.model, target = target.model })
		CombatService.resolve(c, target, {
			damage = p.damage,
			posture = 6,
			hitstun = p.stun,
			knockback = toCaster * speed + Vector3.new(0, 10, 0),
			unblockable = true,
			unparryable = true,
		})
	end)
	return true
end

semblanceCasts.Glyph = function(c, payload, cooldown)
	local def = Semblances.get("Glyph")
	if def == nil then
		return false
	end
	local p = def.params
	c:setCooldown("Semblance", cooldown)
	local origin = c.root.Position - Vector3.new(0, 2.8, 0)
	CombatService.playOn(c, def.clip, 1, payload.seq)
	CombatService.broadcast("Effect", {
		name = "Glyph",
		rig = c.model,
		position = origin,
		radius = p.radius,
		duration = p.duration,
	})
	task.spawn(function()
		local start = os.clock()
		while os.clock() - start < p.duration do
			for _, target in hostilesNear(c, origin, p.radius) do
				target:addStatus("Slow", 0.5, p.slow, c)
			end
			task.wait(0.25)
		end
	end)
	return true
end

semblanceCasts.Bulwark = function(c, payload, cooldown)
	local def = Semblances.get("Bulwark")
	if def == nil then
		return false
	end
	local p = def.params
	c:setCooldown("Semblance", cooldown)
	cast(c, def.clip, payload.seq, function()
		c:addBuff("Harden", p.duration)
		CombatService.broadcast("Effect", { name = "Harden", rig = c.model, duration = p.duration })
	end)
	return true
end

CombatService.handlers.Semblance = function(c, payload)
	local id = c.semblance
	local def = if id then Semblances.get(id) else nil
	local castFn = if id then semblanceCasts[id] else nil
	if def == nil or castFn == nil or not c:canAct() or not c:ready("Semblance") then
		return false
	end
	return castFn(c, payload, def.cooldown)
end

--[[ DUST ]]

local dustCasts: { [string]: (Combatant, { [string]: any }, Dust.DustDef) -> () } = {}

dustCasts.Fire = function(c, payload, def)
	local p = def.params
	local look = lookOf(c, payload)
	local origin = c.root.Position
	CombatService.broadcast("Effect", {
		name = "FireArc",
		rig = c.model,
		origin = origin,
		direction = look,
		range = p.range,
		angle = p.angle,
	})
	for _, target in hostilesNear(c, origin, p.range) do
		local offset = flat(target.root.Position - origin)
		if offset:Dot(look) >= math.cos(math.rad(p.angle / 2)) then
			CombatService.resolve(c, target, {
				damage = p.damage,
				posture = p.posture,
				hitstun = 0.45,
				knockback = offset * 22 + Vector3.new(0, 8, 0),
				status = { kind = "Burn", duration = p.burnDuration, power = p.burnPower },
				dust = true,
			})
		end
	end
end

dustCasts.Ice = function(c, payload, def)
	local p = def.params
	local look = lookOf(c, payload)
	local origin = c.root.Position
	CombatService.broadcast("Effect", {
		name = "FrostSpire",
		rig = c.model,
		origin = origin,
		direction = look,
		range = p.range,
	})
	local struck: { [Combatant]: boolean } = {}
	task.spawn(function()
		local steps = math.floor(p.range / 3)
		for step = 1, steps do
			local point = origin + look * (step * 3)
			for _, target in hostilesNear(c, point, p.width / 2 + 1.5) do
				if not struck[target] then
					struck[target] = true
					CombatService.resolve(c, target, {
						damage = p.damage,
						posture = p.posture,
						hitstun = 0.5,
						knockback = Vector3.new(0, 26, 0),
						status = { kind = "Chill", duration = p.slowDuration, power = p.slow },
						dust = true,
					})
				end
			end
			task.wait(0.035)
		end
	end)
end

dustCasts.Lightning = function(c, payload, def)
	local p = def.params
	local aim = payload.aim
	local direction = if typeof(aim) == "Vector3" and aim.Magnitude > 0.1 then aim.Unit else lookOf(c, payload)
	local origin = c.root.Position + Vector3.new(0, 1.4, 0)
	local velocity = direction * p.speed
	CombatService.broadcast(
		"Projectile",
		{ rig = c.model, kind = "Bolt", from = origin, velocity = velocity, gravity = 0 }
	)
	Projectiles.launch({
		origin = origin,
		velocity = velocity,
		gravity = 0,
		lifetime = p.range / p.speed,
		ignore = { c.model },
		onImpact = function(position, part)
			CombatService.broadcast("Effect", { name = "BoltImpact", position = position })
			local target = CombatService.fromPart(part)
			if target == nil or not CombatService.hostile(c, target) then
				return
			end
			local shock = { kind = "Shock", duration = p.stun }
			CombatService.resolve(c, target, {
				damage = p.damage,
				posture = p.posture,
				hitstun = p.stun,
				status = shock,
				projectile = true,
				dust = true,
				position = position,
			})
			-- Leap to the nearest other enemy.
			local best: Combatant? = nil
			local bestDistance = p.chainRange
			for _, other in hostilesNear(c, target.root.Position, p.chainRange) do
				local distance = (other.root.Position - target.root.Position).Magnitude
				if other ~= target and distance < bestDistance then
					best = other
					bestDistance = distance
				end
			end
			local chained = best
			if chained then
				CombatService.broadcast(
					"Effect",
					{ name = "Chain", from = target.root.Position, to = chained.root.Position }
				)
				CombatService.resolve(c, chained, {
					damage = p.damage * 0.6,
					posture = p.posture * 0.6,
					hitstun = p.stun * 0.7,
					status = shock,
					projectile = true,
					dust = true,
				})
			end
		end,
	})
end

dustCasts.Gravity = function(c, payload, def)
	local p = def.params
	local origin = c.root.Position
	CombatService.broadcast("Effect", { name = "GravityBurst", rig = c.model, position = origin, radius = p.radius })
	for _, target in hostilesNear(c, origin, p.radius) do
		local away = flat(target.root.Position - origin)
		CombatService.resolve(c, target, {
			damage = p.damage,
			posture = p.posture,
			hitstun = 0.6,
			knockback = away * p.knockback + Vector3.new(0, p.lift, 0),
			unparryable = true,
			dust = true,
		})
	end
	if payload.air == true and c.player then
		CombatService.push(c, Vector3.new(0, p.selfLaunch, 0), 0.18)
	end
end

CombatService.handlers.Dust = function(c, payload, player)
	local id = payload.id
	local def = if type(id) == "string" then Dust.get(id) else nil
	local castFn = if type(id) == "string" then dustCasts[id] else nil
	if def == nil or castFn == nil or not c:canAct() then
		return false
	end
	local cooldownName = `Dust_{def.id}`
	if not c:ready(cooldownName) then
		return false
	end
	if player and not Abilities.takeDust(player, def.id) then
		return false
	end
	c:setCooldown(cooldownName, def.cooldown * c.stats.dustCooldown)
	cast(c, def.clip, payload.seq, function()
		castFn(c, payload, def)
	end)
	return true
end

function Abilities.init() end

return Abilities
