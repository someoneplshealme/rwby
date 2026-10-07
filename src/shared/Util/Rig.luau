--!strict
--[[
	Small helpers for reading character rigs safely.
]]

local Rig = {}

function Rig.root(model: Instance?): BasePart?
	if model == nil then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function Rig.humanoid(model: Instance?): Humanoid?
	if model == nil then
		return nil
	end
	return model:FindFirstChildOfClass("Humanoid")
end

function Rig.isAlive(model: Instance?): boolean
	local humanoid = Rig.humanoid(model)
	return humanoid ~= nil and humanoid.Health > 0 and model ~= nil and model.Parent ~= nil
end

function Rig.part(model: Instance, name: string): BasePart?
	local part = model:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

-- Flat (XZ-plane) unit vector from a to b, or nil if they overlap.
function Rig.flatDirection(from: Vector3, to: Vector3): Vector3?
	local delta = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if delta.Magnitude < 1e-3 then
		return nil
	end
	return delta.Unit
end

return Rig
