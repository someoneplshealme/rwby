--!strict
--[[
	Damped spring on a Vector3, integrated with fixed sub-steps so it stays stable at any frame rate.
	Used for additive "juice": hit flinches, landing dips, recoil, camera shake.

	stiffness: how hard it pulls toward the target (higher = faster)
	damping:   2 * sqrt(stiffness) is critical damping; lower values overshoot and wobble
]]

local Spring = {}
Spring.__index = Spring

export type Spring = typeof(setmetatable(
	{} :: {
		position: Vector3,
		velocity: Vector3,
		target: Vector3,
		stiffness: number,
		damping: number,
	},
	Spring
))

local SUBSTEP = 1 / 240

function Spring.new(stiffness: number, damping: number, initial: Vector3?): Spring
	local start = initial or Vector3.zero
	return setmetatable({
		position = start,
		velocity = Vector3.zero,
		target = start,
		stiffness = stiffness,
		damping = damping,
	}, Spring)
end

function Spring.impulse(self: Spring, velocity: Vector3)
	self.velocity += velocity
end

function Spring.reset(self: Spring, position: Vector3?)
	local p = position or self.target
	self.position = p
	self.velocity = Vector3.zero
end

function Spring.update(self: Spring, dt: number): Vector3
	local remaining = math.min(dt, 0.1)
	local position, velocity = self.position, self.velocity
	local target, k, c = self.target, self.stiffness, self.damping
	while remaining > 0 do
		local h = math.min(remaining, SUBSTEP)
		local accel = (target - position) * k - velocity * c
		velocity += accel * h
		position += velocity * h
		remaining -= h
	end
	self.position, self.velocity = position, velocity
	return position
end

-- True once the spring has effectively come to rest at its target.
function Spring.isResting(self: Spring, epsilon: number?): boolean
	local e = epsilon or 1e-3
	return (self.position - self.target).Magnitude < e and self.velocity.Magnitude < e
end

return Spring
