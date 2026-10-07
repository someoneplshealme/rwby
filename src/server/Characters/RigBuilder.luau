--!strict
--[[
	Builds a standard R6 rig from parts, with the same joint names and frames as Roblox's own R6
	characters, so the animation system drives it identically. Used for Grimm and as a fallback
	when a player's avatar cannot be loaded.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Joints = require(ReplicatedStorage.Shared.Animation.Joints)

export type Colors = {
	head: Color3,
	torso: Color3,
	arms: Color3,
	legs: Color3,
}

local RigBuilder = {}

local function makePart(name: string, size: Vector3, color: Color3, cframe: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = cframe
	part.CanCollide = false
	return part
end

local function motor(
	name: string,
	parent: BasePart,
	part0: BasePart,
	part1: BasePart,
	frames: { c0: CFrame, c1: CFrame }
)
	local joint = Instance.new("Motor6D")
	joint.Name = name
	joint.Part0 = part0
	joint.Part1 = part1
	joint.C0 = frames.c0
	joint.C1 = frames.c1
	joint.MaxVelocity = 0.1
	joint.Parent = parent
end

function RigBuilder.build(name: string, colors: Colors, withFace: boolean?): Model
	local model = Instance.new("Model")
	model.Name = name

	local origin = CFrame.new(0, 3, 0)
	local root = makePart("HumanoidRootPart", Vector3.new(2, 2, 1), colors.torso, origin)
	root.Transparency = 1
	local torso = makePart("Torso", Vector3.new(2, 2, 1), colors.torso, origin)
	torso.CanCollide = true
	local head = makePart("Head", Vector3.new(2, 1, 1), colors.head, origin * CFrame.new(0, 1.5, 0))
	head.CanCollide = true
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local rightArm = makePart("Right Arm", Vector3.new(1, 2, 1), colors.arms, origin * CFrame.new(1.5, 0, 0))
	local leftArm = makePart("Left Arm", Vector3.new(1, 2, 1), colors.arms, origin * CFrame.new(-1.5, 0, 0))
	local rightLeg = makePart("Right Leg", Vector3.new(1, 2, 1), colors.legs, origin * CFrame.new(0.5, -2, 0))
	local leftLeg = makePart("Left Leg", Vector3.new(1, 2, 1), colors.legs, origin * CFrame.new(-0.5, -2, 0))

	for _, part in { root, torso, head, rightArm, leftArm, rightLeg, leftLeg } do
		part.Parent = model
	end

	motor("RootJoint", root, root, torso, Joints.R6.Root)
	motor("Neck", torso, torso, head, Joints.R6.Neck)
	motor("Right Shoulder", torso, torso, rightArm, Joints.R6.RightArm)
	motor("Left Shoulder", torso, torso, leftArm, Joints.R6.LeftArm)
	motor("Right Hip", torso, torso, rightLeg, Joints.R6.RightLeg)
	motor("Left Hip", torso, torso, leftLeg, Joints.R6.LeftLeg)

	if withFace ~= false then
		local face = Instance.new("Decal")
		face.Name = "face"
		face.Texture = "rbxasset://textures/face.png"
		face.Face = Enum.NormalId.Front
		face.Parent = head
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.Parent = model

	model.PrimaryPart = root
	return model
end

return RigBuilder
