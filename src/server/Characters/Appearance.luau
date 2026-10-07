--!strict
--[[
	Cosmetic additions built from parts: Faunus ears/tails/horns and a two-segment cape in the
	Huntsman's signature colour. The cape hangs from Motor6Ds ("CapeJoint", "CapeJoint2") that
	each client swings procedurally from the character's motion.
]]

local Appearance = {}

local TRAIT_COLOR = Color3.fromRGB(58, 42, 36)
local HORN_COLOR = Color3.fromRGB(226, 214, 186)

local function cosmetic(part: BasePart)
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
end

local function attach(parent: BasePart, part: BasePart, offset: CFrame)
	cosmetic(part)
	part.CFrame = parent.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = parent
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
end

local function block(name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	if shape then
		part.Shape = shape
	end
	return part
end

local function tail(torso: BasePart, folder: Instance, bushy: boolean)
	local size = if bushy then Vector3.new(0.75, 0.75, 1.7) else Vector3.new(0.38, 0.38, 1.6)
	local part = block("Tail", size, TRAIT_COLOR, if bushy then Enum.PartType.Ball else nil)
	part.Parent = folder
	attach(torso, part, CFrame.new(0, -0.75, 0.95) * CFrame.Angles(math.rad(-38), 0, 0))
	if bushy then
		local tip = block("TailTip", Vector3.new(0.45, 0.45, 0.6), Color3.fromRGB(236, 232, 224), Enum.PartType.Ball)
		tip.Parent = folder
		attach(torso, tip, CFrame.new(0, -1.25, 1.7) * CFrame.Angles(math.rad(-38), 0, 0))
	end
end

function Appearance.applyFaunus(character: Model, trait: string)
	local head = character:FindFirstChild("Head")
	local torso = character:FindFirstChild("Torso")
	if not (head and head:IsA("BasePart") and torso and torso:IsA("BasePart")) then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "FaunusTraits"
	folder.Parent = character

	if trait == "Cat" or trait == "Wolf" or trait == "Fox" then
		local size = if trait == "Cat" then Vector3.new(0.4, 0.4, 0.14) else Vector3.new(0.44, 0.5, 0.16)
		for _, side in { -1, 1 } do
			local ear = block("Ear", size, TRAIT_COLOR)
			ear.Parent = folder
			attach(head, ear, CFrame.new(0.36 * side, 0.66, 0.05) * CFrame.Angles(0, 0, math.rad(45 + 8 * side)))
		end
		if trait ~= "Cat" then
			tail(torso, folder, trait == "Fox")
		end
	elseif trait == "Rabbit" then
		for _, side in { -1, 1 } do
			local ear = block("Ear", Vector3.new(0.24, 1.1, 0.12), TRAIT_COLOR)
			ear.Parent = folder
			attach(head, ear, CFrame.new(0.26 * side, 1.1, 0.08) * CFrame.Angles(math.rad(-8), 0, math.rad(-9 * side)))
		end
	elseif trait == "Bull" then
		for _, side in { -1, 1 } do
			local horn = block("Horn", Vector3.new(0.75, 0.2, 0.2), HORN_COLOR, Enum.PartType.Cylinder)
			horn.Parent = folder
			attach(head, horn, CFrame.new(0.72 * side, 0.42, -0.05) * CFrame.Angles(0, 0, math.rad(28 * side)))
		end
	end
end

function Appearance.applyCape(character: Model, color: Color3)
	local torso = character:FindFirstChild("Torso")
	if not (torso and torso:IsA("BasePart")) then
		return
	end
	local upper = block("CapeUpper", Vector3.new(2.15, 1.5, 0.08), color)
	cosmetic(upper)
	upper.Material = Enum.Material.Fabric
	upper.CFrame = torso.CFrame * CFrame.new(0, 0.2, 0.56)
	upper.Parent = character

	local lower = block("CapeLower", Vector3.new(2.25, 1.7, 0.08), color)
	cosmetic(lower)
	lower.Material = Enum.Material.Fabric
	lower.CFrame = upper.CFrame * CFrame.new(0, -1.6, 0)
	lower.Parent = character

	local joint = Instance.new("Motor6D")
	joint.Name = "CapeJoint"
	joint.Part0 = torso
	joint.Part1 = upper
	joint.C0 = CFrame.new(0, 0.95, 0.56)
	joint.C1 = CFrame.new(0, 0.75, 0)
	joint.Parent = torso

	local joint2 = Instance.new("Motor6D")
	joint2.Name = "CapeJoint2"
	joint2.Part0 = upper
	joint2.Part1 = lower
	joint2.C0 = CFrame.new(0, -0.75, 0)
	joint2.C1 = CFrame.new(0, 0.85, 0)
	joint2.Parent = upper
end

return Appearance
