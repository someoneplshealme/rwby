--!strict
--[[
	Server-simulated projectiles (grenades, lightning bolts). Each one steps along its ballistic
	arc every Heartbeat with a raycast per segment. Clients draw their own copy from the same
	launch data, so only launch and impact need to cross the network.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

export type Spec = {
	origin: Vector3,
	velocity: Vector3,
	gravity: number, -- studs/s^2 downward
	lifetime: number,
	ignore: { Instance },
	-- Called once, with the impact point and the part hit (nil when it timed out mid-air).
	onImpact: (position: Vector3, part: BasePart?) -> (),
}

type Live = {
	spec: Spec,
	position: Vector3,
	velocity: Vector3,
	age: number,
	params: RaycastParams,
}

local Projectiles = {}

local live: { Live } = {}

function Projectiles.launch(spec: Spec)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = spec.ignore
	params.IgnoreWater = true
	table.insert(live, {
		spec = spec,
		position = spec.origin,
		velocity = spec.velocity,
		age = 0,
		params = params,
	})
end

local function step(dt: number)
	local index = 1
	while index <= #live do
		local projectile = live[index]
		local spec = projectile.spec
		local gravity = Vector3.new(0, -spec.gravity, 0)
		local displacement = projectile.velocity * dt + gravity * (0.5 * dt * dt)
		local result = Workspace:Raycast(projectile.position, displacement, projectile.params)
		projectile.age += dt
		local done = false
		if result then
			done = true
			local part = result.Instance
			task.spawn(spec.onImpact, result.Position, if part:IsA("BasePart") then part else nil)
		else
			projectile.position += displacement
			projectile.velocity += gravity * dt
			if projectile.age >= spec.lifetime then
				done = true
				task.spawn(spec.onImpact, projectile.position, nil)
			end
		end
		if done then
			table.remove(live, index)
		else
			index += 1
		end
	end
end

function Projectiles.start()
	RunService.Heartbeat:Connect(step)
end

return Projectiles
