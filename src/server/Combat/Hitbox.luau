--!strict
--[[
	Server-side hit queries. Hitboxes are boxes or spheres placed relative to the attacker's root
	(see Weapons.Hitbox), resolved with spatial queries against registered combatant models only.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local Hitbox = {}

-- Attack frame: the root position facing `look` (flattened), or the root's own facing.
function Hitbox.frame(root: BasePart, look: Vector3?): CFrame
	local position = root.Position
	local direction = if look then Vector3.new(look.X, 0, look.Z) else Vector3.zero
	if direction.Magnitude < 1e-3 then
		local rootLook = root.CFrame.LookVector
		direction = Vector3.new(rootLook.X, 0, rootLook.Z)
	end
	if direction.Magnitude < 1e-3 then
		direction = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(position, position + direction.Unit)
end

-- Finds the parts inside a hitbox. `include` limits the query to these models.
function Hitbox.query(frame: CFrame, box: Weapons.Hitbox, scale: number, include: { Instance }): { BasePart }
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	params.MaxParts = 200

	local center = frame * CFrame.new(0, (box.up or 0) * scale, -(box.forward or 0) * scale)
	if box.shape == "Sphere" then
		return Workspace:GetPartBoundsInRadius(center.Position, (box.radius or 6) * scale, params)
	end
	local size = (box.size or Vector3.new(6, 6, 6)) * scale
	return Workspace:GetPartBoundsInBox(center, size, params)
end

-- Clamps a client-provided look direction to within `maxAngle` degrees of the server's facing.
function Hitbox.validateLook(root: BasePart, look: any, maxAngle: number): Vector3?
	if typeof(look) ~= "Vector3" then
		return nil
	end
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 or flat.Magnitude ~= flat.Magnitude then
		return nil
	end
	local rootLook = root.CFrame.LookVector
	local serverFlat = Vector3.new(rootLook.X, 0, rootLook.Z)
	if serverFlat.Magnitude < 1e-3 then
		return flat.Unit
	end
	if serverFlat.Unit:Dot(flat.Unit) < math.cos(math.rad(maxAngle)) then
		return nil
	end
	return flat.Unit
end

-- Random direction inside a cone around `direction` (degrees).
function Hitbox.spread(direction: Vector3, degrees: number, random: Random): Vector3
	if degrees <= 0 then
		return direction
	end
	local frame = CFrame.lookAt(Vector3.zero, direction)
	local angle = math.rad(degrees) * math.sqrt(random:NextNumber())
	local spin = random:NextNumber() * math.pi * 2
	local offset = CFrame.Angles(0, 0, spin) * CFrame.Angles(angle, 0, 0)
	return (frame * offset).LookVector
end

return Hitbox
