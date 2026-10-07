--!strict
--[[
	Authoring helpers for clip files.

	Weapon poses are described by intent instead of raw joint angles:
	    armed(pose, reach, shaft, edge, slide)
	  reach  direction from the right shoulder toward where the hand should be (torso space)
	  shaft  where the weapon's main axis points (blade / shaft / barrel along handle +Y)
	  edge   where the weapon's "front" points (scythe blade, rifle muzzle, cutting edge: handle -Z)
	The arm rotation and the wrist (grip) rotation are solved for you. On two-handed weapons the
	off hand then grips the shaft automatically (Composer.applyTwoHand).

	Directions are torso space: +X right, +Y up, -Z forward.
]]

local Joints = require(script.Parent.Joints)

type Pose = Joints.Pose

local Author = {}

Author.T = Joints.T
Author.H = Joints.H
Author.RA = Joints.RA
Author.LA = Joints.LA
Author.RL = Joints.RL
Author.LL = Joints.LL
Author.RG = Joints.RG
Author.LG = Joints.LG

function Author.v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

-- Right hand reaches along `reach` while the weapon points along shaft/edge.
function Author.armed(pose: Pose, reach: Vector3, shaft: Vector3, edge: Vector3, slide: number?): Pose
	local shoulder = Joints.R6.RightArm.c0.Position
	local arm = Joints.reach("Right", shoulder + reach.Unit * 3)
	pose.RightArm = arm
	pose.RightGrip = Joints.gripFor(arm, shaft, edge, slide)
	return pose
end

-- Same for the left hand (shields, off-hand weapons).
function Author.armedLeft(pose: Pose, reach: Vector3, shaft: Vector3, edge: Vector3, slide: number?): Pose
	local shoulder = Joints.R6.LeftArm.c0.Position
	local arm = Joints.reach("Left", shoulder + reach.Unit * 3)
	pose.LeftArm = arm
	pose.LeftGrip = Joints.gripFor(arm, shaft, edge, slide)
	return pose
end

-- Points an arm without touching the grip.
function Author.point(side: string, reach: Vector3): CFrame
	local shoulder = Joints.R6[if side == "Left" then "LeftArm" else "RightArm"].c0.Position
	return Joints.reach(side, shoulder + reach.Unit * 3)
end

--[[
	Edge direction for a swing: a blade sweeping around `axis` leads with its edge, i.e. it points
	along axis x shaft. Horizontal right-to-left sweep: axis = +Y. Overhead chop: axis = -X.
]]
function Author.swing(shaft: Vector3, axis: Vector3): Vector3
	local edge = axis:Cross(shaft)
	if edge.Magnitude < 1e-4 then
		return Vector3.new(0, 0, -1)
	end
	return edge.Unit
end

-- Rotates a direction around the vertical axis by `degrees` (positive turns it to the right).
function Author.yaw(direction: Vector3, degrees: number): Vector3
	return CFrame.Angles(0, math.rad(-degrees), 0) * direction
end

-- Merges poses left to right (later ones win).
function Author.merge(...: Pose): Pose
	local result: Pose = {}
	for i = 1, select("#", ...) do
		local pose = select(i, ...)
		for name, cf in pose do
			result[name] = cf
		end
	end
	return result
end

return Author
