--!strict
--[[
	Joint definitions for the R6 rig (plus two weapon grips) and the pose-authoring helpers.

	POSE SPACE
	Every joint pose is a CFrame describing how the child part moves *around its joint pivot*,
	expressed in the parent part's axes:
	  * Root      HumanoidRootPart -> Torso   (pivot moved to the hip line by Joints.T)
	  * Neck      Torso -> Head
	  * RightArm / LeftArm   Torso -> arm, pivot at the shoulder
	  * RightLeg / LeftLeg   legs are authored relative to the HumanoidRootPart (ground frame) by
	                         default; Clip compiles them into torso space so leaning never swings legs.
	  * RightGrip / LeftGrip hand -> weapon handle, expressed in the grip frame (see below).

	Parent-space poses are converted to Motor6D.Transform by conjugating with the C0 rotation:
	    Transform = R0⁻¹ · Pose · R0
	which is what lets us write intuitive angles despite R6's rotated joint frames.

	AUTHORING CONVENTIONS (all angles in degrees)
	  T(pitch, yaw, roll, x, y, z)   torso: +pitch leans forward, +yaw turns right, +roll tilts right,
	                                  x/y/z shift the body in root space (y < 0 crouches)
	  H(pitch, yaw, roll)            head:  +pitch looks down, +yaw looks right, +roll tilts right
	  RA/LA(pitch, out, twist)       arms:  +pitch raises forward, +out raises sideways away from the
	                                  body, +twist rotates the arm inward
	  RL/LL(pitch, out, twist)       legs:  +pitch kicks forward, +out spreads outward
	  RG/LG(pitch, roll, spin, x, y, z)
	                                  grips: the weapon points along grip +Y. +pitch tilts the tip up
	                                  toward the forearm, +roll turns the tip toward the body's midline,
	                                  +spin rotates the weapon around its own length.
	Left-side helpers mirror the right-side ones, so the same numbers give a mirrored pose.
]]

export type JointName = "Root" | "Neck" | "RightArm" | "LeftArm" | "RightLeg" | "LeftLeg" | "RightGrip" | "LeftGrip"
export type Pose = { [string]: CFrame }

export type JointRig = {
	container: string, -- name of the part that holds the Motor6D
	motor: string, -- Motor6D name
	part0: string,
	part1: string?, -- nil for grips (the handle is a weapon part)
}

local Joints = {}

Joints.Names = {
	"Root",
	"Neck",
	"RightArm",
	"LeftArm",
	"RightLeg",
	"LeftLeg",
	"RightGrip",
	"LeftGrip",
} :: { JointName }

Joints.Body = { "Root", "Neck", "RightArm", "LeftArm", "RightLeg", "LeftLeg" } :: { JointName }
Joints.UpperBody = { "Root", "Neck", "RightArm", "LeftArm", "RightGrip", "LeftGrip" } :: { JointName }
Joints.Arms = { "RightArm", "LeftArm", "RightGrip", "LeftGrip" } :: { JointName }
Joints.Legs = { "RightLeg", "LeftLeg" } :: { JointName }

Joints.Rig = {
	Root = { container = "HumanoidRootPart", motor = "RootJoint", part0 = "HumanoidRootPart", part1 = "Torso" },
	Neck = { container = "Torso", motor = "Neck", part0 = "Torso", part1 = "Head" },
	RightArm = { container = "Torso", motor = "Right Shoulder", part0 = "Torso", part1 = "Right Arm" },
	LeftArm = { container = "Torso", motor = "Left Shoulder", part0 = "Torso", part1 = "Left Arm" },
	RightLeg = { container = "Torso", motor = "Right Hip", part0 = "Torso", part1 = "Right Leg" },
	LeftLeg = { container = "Torso", motor = "Left Hip", part0 = "Torso", part1 = "Left Leg" },
	RightGrip = { container = "Right Arm", motor = "WeaponGripR", part0 = "Right Arm" },
	LeftGrip = { container = "Left Arm", motor = "WeaponGripL", part0 = "Left Arm" },
} :: { [string]: JointRig }

-- Joints whose poses are authored in parent space and must be conjugated by C0's rotation.
Joints.ParentSpace = {
	Root = true,
	Neck = true,
	RightArm = true,
	LeftArm = true,
	RightLeg = true,
	LeftLeg = true,
} :: { [string]: boolean }

Joints.MirrorOf = {
	Root = "Root",
	Neck = "Neck",
	RightArm = "LeftArm",
	LeftArm = "RightArm",
	RightLeg = "LeftLeg",
	LeftLeg = "RightLeg",
	RightGrip = "LeftGrip",
	LeftGrip = "RightGrip",
} :: { [string]: string }

-- Standard R6 joint frames (identical to Roblox's default R6 rig).
Joints.R6 = {
	Root = {
		c0 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		c1 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	},
	Neck = {
		c0 = CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		c1 = CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	},
	RightArm = {
		c0 = CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
		c1 = CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	},
	LeftArm = {
		c0 = CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
		c1 = CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	},
	RightLeg = {
		c0 = CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
		c1 = CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	},
	LeftLeg = {
		c0 = CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
		c1 = CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	},
} :: { [string]: { c0: CFrame, c1: CFrame } }

-- Grip frame inside each hand: same orientation as Roblox's R6 Right/LeftGripAttachment.
-- With the arm hanging, grip +Y points forward and grip +Z points up the forearm.
Joints.GripC0 = CFrame.new(0, -1, 0) * CFrame.Angles(-math.pi / 2, 0, 0)

local rad = math.rad
local Angles = CFrame.Angles
local IDENTITY = CFrame.identity
local HIP_PIVOT = CFrame.new(0, -1, 0)
local HIP_PIVOT_INV = CFrame.new(0, 1, 0)

Joints.Identity = IDENTITY

-- Torso relative to the root, pivoting at the hip line.
function Joints.T(pitch: number?, yaw: number?, roll: number?, x: number?, y: number?, z: number?): CFrame
	local r = Angles(0, rad(-(yaw or 0)), 0) * Angles(rad(-(pitch or 0)), 0, 0) * Angles(0, 0, rad(-(roll or 0)))
	return CFrame.new(x or 0, y or 0, z or 0) * HIP_PIVOT * r * HIP_PIVOT_INV
end

-- Head relative to the torso, pivoting at the base of the neck.
function Joints.H(pitch: number?, yaw: number?, roll: number?): CFrame
	return Angles(0, rad(-(yaw or 0)), 0) * Angles(rad(-(pitch or 0)), 0, 0) * Angles(0, 0, rad(-(roll or 0)))
end

local function limb(
	pitch: number?,
	out: number?,
	twist: number?,
	side: number,
	x: number?,
	y: number?,
	z: number?
): CFrame
	local r = Angles(rad(pitch or 0), 0, 0)
		* Angles(0, 0, rad((out or 0) * side))
		* Angles(0, rad((twist or 0) * side), 0)
	if x or y or z then
		return CFrame.new((x or 0) * side, y or 0, z or 0) * r
	end
	return r
end

function Joints.RA(pitch: number?, out: number?, twist: number?, x: number?, y: number?, z: number?): CFrame
	return limb(pitch, out, twist, 1, x, y, z)
end

function Joints.LA(pitch: number?, out: number?, twist: number?, x: number?, y: number?, z: number?): CFrame
	return limb(pitch, out, twist, -1, x, y, z)
end

function Joints.RL(pitch: number?, out: number?, twist: number?, x: number?, y: number?, z: number?): CFrame
	return limb(pitch, out, twist, 1, x, y, z)
end

function Joints.LL(pitch: number?, out: number?, twist: number?, x: number?, y: number?, z: number?): CFrame
	return limb(pitch, out, twist, -1, x, y, z)
end

local function grip(
	pitch: number?,
	roll: number?,
	spin: number?,
	side: number,
	x: number?,
	y: number?,
	z: number?
): CFrame
	local r = Angles(0, 0, rad((roll or 0) * side))
		* Angles(rad(pitch or 0), 0, 0)
		* Angles(0, rad((spin or 0) * side), 0)
	return CFrame.new((x or 0) * side, y or 0, z or 0) * r
end

function Joints.RG(pitch: number?, roll: number?, spin: number?, x: number?, y: number?, z: number?): CFrame
	return grip(pitch, roll, spin, 1, x, y, z)
end

function Joints.LG(pitch: number?, roll: number?, spin: number?, x: number?, y: number?, z: number?): CFrame
	return grip(pitch, roll, spin, -1, x, y, z)
end

-- Reflects a CFrame across the character's YZ plane (left <-> right).
function Joints.mirrorCFrame(cf: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

-- Mirrors a whole pose: swaps sides and reflects every joint.
function Joints.mirrorPose(pose: Pose): Pose
	local out: Pose = {}
	for name, cf in pose do
		out[Joints.MirrorOf[name] or name] = Joints.mirrorCFrame(cf)
	end
	return out
end

--[[ KINEMATICS HELPERS (standard R6 proportions, torso space) ]]

local function armRig(side: string): { c0: CFrame, c1: CFrame }
	return Joints.R6[if side == "Left" then "LeftArm" else "RightArm"]
end

-- CFrame of an arm part in torso space for the given arm pose.
function Joints.armCFrame(side: string, pose: CFrame): CFrame
	local rig = armRig(side)
	return CFrame.new(rig.c0.Position) * pose * CFrame.new(-rig.c1.Position)
end

-- CFrame of a hand's weapon handle in torso space.
function Joints.handleCFrame(side: string, armPose: CFrame, gripPose: CFrame): CFrame
	return Joints.armCFrame(side, armPose) * Joints.GripC0 * gripPose
end

-- Distance from the shoulder pivot to the grip point; how far a rigid R6 arm can reach.
function Joints.reachLength(side: string): number
	return (Joints.GripC0.Position - armRig(side).c1.Position).Magnitude
end

-- Arm pose (about the shoulder) that points the hand at `target` (torso space).
function Joints.reach(side: string, target: Vector3): CFrame
	local rig = armRig(side)
	local direction = target - rig.c0.Position
	if direction.Magnitude < 1e-4 then
		return IDENTITY
	end
	local from = (Joints.GripC0.Position - rig.c1.Position).Unit
	local to = direction.Unit
	local axis = from:Cross(to)
	local dot = math.clamp(from:Dot(to), -1, 1)
	if axis.Magnitude < 1e-6 then
		return if dot > 0 then IDENTITY else CFrame.fromAxisAngle(Vector3.xAxis, math.pi)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(dot))
end

--[[
	Grip pose that makes the weapon point where you want, given the arm pose holding it.
	  shaft  direction (torso space) for the weapon's +Y axis (blade / shaft)
	  edge   direction (torso space) for the weapon's -Z axis (scythe blade, barrel, cutting edge)
	  slide  shifts the weapon along its own +Y relative to the hand (studs)
]]
function Joints.gripFor(armPose: CFrame, shaft: Vector3, edge: Vector3, slide: number?): CFrame
	local up = shaft.Unit
	local edgePerp = edge - up * edge:Dot(up)
	if edgePerp.Magnitude < 1e-4 then
		-- Edge parallel to the shaft: fall back to "forward", then "down".
		edgePerp = Vector3.new(0, 0, -1) - up * -up.Z
		if edgePerp.Magnitude < 1e-4 then
			edgePerp = Vector3.new(0, -1, 0) - up * -up.Y
		end
	end
	local back = -edgePerp.Unit
	local right = up:Cross(back)
	local desired = CFrame.fromMatrix(Vector3.zero, right, up, back)
	local gripFrame = armPose.Rotation * Joints.GripC0.Rotation
	return gripFrame:Inverse() * desired * CFrame.new(0, slide or 0, 0)
end

--[[
	Forward kinematics for a standard R6 rig: world CFrames of every body part (and both weapon
	handles) for a canonical pose. Used to build statues and by the offline preview.
]]
function Joints.solve(pose: Pose, root: CFrame): { [string]: CFrame }
	local finalPose = table.clone(pose)
	local rootPose = finalPose.Root
	if rootPose then
		local inv = rootPose.Rotation:Inverse()
		for _, leg in { "RightLeg", "LeftLeg" } do
			local cf = finalPose[leg]
			if cf then
				finalPose[leg] = inv * cf
			end
		end
	end
	local function transform(joint: string): CFrame
		local value = finalPose[joint] or IDENTITY
		if Joints.ParentSpace[joint] then
			local r0 = Joints.R6[joint].c0.Rotation
			return r0:Inverse() * value * r0
		end
		return value
	end
	local function child(joint: string, parent: CFrame): CFrame
		local frames = Joints.R6[joint]
		return parent * frames.c0 * transform(joint) * frames.c1:Inverse()
	end
	local torso = child("Root", root)
	local rightArm = child("RightArm", torso)
	local leftArm = child("LeftArm", torso)
	return {
		HumanoidRootPart = root,
		Torso = torso,
		Head = child("Neck", torso),
		["Right Arm"] = rightArm,
		["Left Arm"] = leftArm,
		["Right Leg"] = child("RightLeg", torso),
		["Left Leg"] = child("LeftLeg", torso),
		HandleRight = rightArm * Joints.GripC0 * transform("RightGrip"),
		HandleLeft = leftArm * Joints.GripC0 * transform("LeftGrip"),
	}
end

-- Converts a parent-space pose into the value Motor6D.Transform expects, given the joint's C0 rotation.
function Joints.toTransform(pose: CFrame, r0: CFrame, r0Inv: CFrame): CFrame
	return r0Inv * pose * r0
end

-- Inverse of toTransform; used to read poses written by Roblox's own Animator.
function Joints.fromTransform(transform: CFrame, r0: CFrame, r0Inv: CFrame): CFrame
	return r0 * transform * r0Inv
end

return Joints
