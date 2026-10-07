--!strict
--[[
	Short-lived velocity impulses on a root part (dashes, knockback, launches, pulls).

	Movement physics runs wherever the part is network-owned: the server applies impulses to Grimm,
	and each client applies them to its own character (the server asks via the Motion remote).

	`planar` impulses only drive horizontal velocity so gravity keeps working (dashes along slopes);
	full impulses drive all three axes for their duration (launches, knockback arcs).
]]

local Impulse = {}

export type Options = {
	duration: number,
	planar: boolean?,
	decay: boolean?, -- ease the speed down over the duration
	name: string?,
}

local ATTACHMENT_NAME = "ImpulseAttachment"

local function attachment(root: BasePart): Attachment
	local existing = root:FindFirstChild(ATTACHMENT_NAME)
	if existing and existing:IsA("Attachment") then
		return existing
	end
	local created = Instance.new("Attachment")
	created.Name = ATTACHMENT_NAME
	created.Parent = root
	return created
end

-- Removes any running impulse with this name (or all impulses).
function Impulse.clear(root: BasePart, name: string?)
	for _, child in root:GetChildren() do
		if child:IsA("LinearVelocity") and (name == nil or child.Name == name) then
			child:Destroy()
		end
	end
end

function Impulse.apply(root: BasePart, velocity: Vector3, options: Options): LinearVelocity
	local name = options.name or "Impulse"
	Impulse.clear(root, name)

	local constraint = Instance.new("LinearVelocity")
	constraint.Name = name
	constraint.Attachment0 = attachment(root)
	constraint.RelativeTo = Enum.ActuatorRelativeTo.World
	constraint.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	constraint.MaxForce = math.max(root.AssemblyMass, 1) * 4000
	if options.planar then
		constraint.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		constraint.PrimaryTangentAxis = Vector3.xAxis
		constraint.SecondaryTangentAxis = Vector3.zAxis
		constraint.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)
	else
		constraint.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		constraint.VectorVelocity = velocity
	end
	constraint.Parent = root

	local duration = math.max(options.duration, 0.01)
	if options.decay then
		task.spawn(function()
			local start = os.clock()
			while constraint.Parent do
				local alpha = math.clamp((os.clock() - start) / duration, 0, 1)
				local scale = 1 - alpha * alpha
				if options.planar then
					constraint.PlaneVelocity = Vector2.new(velocity.X * scale, velocity.Z * scale)
				else
					constraint.VectorVelocity = velocity * scale
				end
				if alpha >= 1 then
					break
				end
				task.wait()
			end
		end)
	end
	task.delay(duration, function()
		if constraint.Parent then
			constraint:Destroy()
		end
	end)
	return constraint
end

return Impulse
