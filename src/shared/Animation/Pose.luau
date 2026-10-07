--!strict
--[[
	Pose blending helpers. A pose maps joint names to parent-space CFrames (see Joints).

	Canonical form: while layers are being blended, leg poses are kept in ROOT space (relative to the
	HumanoidRootPart). That keeps feet planted while the torso leans or blends between layers.
	`finalize` converts the legs to torso space once, right before the pose is written to the rig.
]]

local Joints = require(script.Parent.Joints)

export type Pose = Joints.Pose

local Pose = {}

local IDENTITY = CFrame.identity

function Pose.new(): Pose
	return {}
end

function Pose.clear(pose: Pose)
	table.clear(pose)
end

function Pose.copyInto(out: Pose, source: Pose)
	for name, cf in source do
		out[name] = cf
	end
end

-- out[j] = lerp(out[j], layer[j], weight) for every joint the layer defines (optionally masked).
function Pose.blendInto(out: Pose, layer: Pose, weight: number, mask: { [string]: boolean }?)
	if weight <= 0 then
		return
	end
	for name, cf in layer do
		if mask == nil or mask[name] then
			if weight >= 1 then
				out[name] = cf
			else
				out[name] = (out[name] or IDENTITY):Lerp(cf, weight)
			end
		end
	end
end

-- Applies an additive layer: out[j] = additive[j] * out[j] (rotation about the joint pivot in parent axes).
function Pose.addInto(out: Pose, additive: Pose, weight: number?)
	local w = weight or 1
	if w <= 0 then
		return
	end
	for name, cf in additive do
		local delta = if w >= 1 then cf else IDENTITY:Lerp(cf, w)
		out[name] = delta * (out[name] or IDENTITY)
	end
end

-- Root-space legs -> torso-space legs. Call once on the final blended pose.
function Pose.finalize(pose: Pose)
	local root = pose.Root
	if not root then
		return
	end
	local inv = root.Rotation:Inverse()
	local right = pose.RightLeg
	if right then
		pose.RightLeg = inv * right
	end
	local left = pose.LeftLeg
	if left then
		pose.LeftLeg = inv * left
	end
end

-- Builds a mask lookup from a list of joint names.
function Pose.mask(names: { string }): { [string]: boolean }
	local mask = {}
	for _, name in names do
		mask[name] = true
	end
	return mask
end

return Pose
