--!strict
--[[
	Assembles a weapon from its WeaponModels spec onto a character.

	Each hand gets an invisible Handle attached by a Motor6D grip (WeaponGripR / WeaponGripL) that
	the animation system rotates for weapon flourishes. Every piece hangs off the handle with its
	own Motor6D whose C0 is the piece's first-form placement; clients offset the pieces through
	Motor6D.Transform to show the current form and to animate mecha-shifts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Joints = require(Shared.Animation.Joints)
local WeaponModels = require(Shared.Config.WeaponModels)

local WeaponService = {}

local function newPiecePart(piece: WeaponModels.Piece): BasePart
	local part: BasePart
	if piece.shape == "Wedge" then
		part = Instance.new("WedgePart")
	else
		local block = Instance.new("Part")
		if piece.shape == "Cylinder" then
			block.Shape = Enum.PartType.Cylinder
		elseif piece.shape == "Ball" then
			block.Shape = Enum.PartType.Ball
		end
		part = block
	end
	part.Name = piece.name
	part.Size = piece.size
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function configure(part: BasePart)
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	part.Anchored = false
end

local function resolveColor(model: WeaponModels.WeaponModel, key: string, accent: Color3): Color3
	if key == "Accent" then
		return accent
	end
	return model.palette[key] or Color3.fromRGB(200, 200, 200)
end

local function material(name: string?): Enum.Material
	local ok, value = pcall(function()
		return (Enum.Material :: any)[name or "Metal"]
	end)
	if ok and typeof(value) == "EnumItem" then
		return value :: any
	end
	return Enum.Material.Metal
end

function WeaponService.unequip(character: Model)
	local existing = character:FindFirstChild("Weapon")
	if existing then
		existing:Destroy()
	end
	for _, armName in { "Right Arm", "Left Arm" } do
		local arm = character:FindFirstChild(armName)
		if arm then
			for _, child in arm:GetChildren() do
				if child:IsA("Motor6D") and (child.Name == "WeaponGripR" or child.Name == "WeaponGripL") then
					child:Destroy()
				end
			end
		end
	end
end

function WeaponService.equip(character: Model, modelId: string, accent: Color3): Model?
	local spec = WeaponModels[modelId]
	if spec == nil then
		warn(`[Weapon] unknown weapon model {modelId}`)
		return nil
	end
	WeaponService.unequip(character)

	local container = Instance.new("Model")
	container.Name = "Weapon"
	local firstForm = spec.forms[1]

	local hands: { { side: string, pieces: { WeaponModels.Piece }? } } = {
		{ side = "Right", pieces = spec.right },
		{ side = "Left", pieces = spec.left },
	}
	for _, hand in hands do
		local pieces = hand.pieces
		local arm = character:FindFirstChild(`{hand.side} Arm`)
		if pieces and arm and arm:IsA("BasePart") then
			local handle = Instance.new("Part")
			handle.Name = `Handle{hand.side}`
			handle.Size = Vector3.new(0.2, 0.2, 0.2)
			handle.Transparency = 1
			configure(handle)
			handle.CFrame = arm.CFrame * Joints.GripC0
			handle.Parent = container

			local grip = Instance.new("Motor6D")
			grip.Name = if hand.side == "Right" then "WeaponGripR" else "WeaponGripL"
			grip.Part0 = arm
			grip.Part1 = handle
			grip.C0 = Joints.GripC0
			grip.Parent = arm

			for _, piece in pieces do
				local part = newPiecePart(piece)
				part.Color = resolveColor(spec, piece.color, accent)
				part.Material = material(piece.material)
				configure(part)
				local placement = piece.forms[firstForm] or CFrame.identity
				part.CFrame = handle.CFrame * placement
				part.Parent = container

				local joint = Instance.new("Motor6D")
				joint.Name = piece.name
				joint.Part0 = handle
				joint.Part1 = part
				joint.C0 = placement
				joint.Parent = handle
			end

			for index, trail in spec.trails do
				if trail.hand == hand.side then
					local a = Instance.new("Attachment")
					a.Name = `Trail{index}A`
					a.Position = trail.a
					a.Parent = handle
					local b = Instance.new("Attachment")
					b.Name = `Trail{index}B`
					b.Position = trail.b
					b.Parent = handle
				end
			end
			local muzzles = spec.muzzles
			if muzzles then
				for form, muzzle in muzzles do
					if muzzle.hand == hand.side then
						local attachment = Instance.new("Attachment")
						attachment.Name = `Muzzle_{form}`
						attachment.Position = muzzle.offset
						attachment.Parent = handle
					end
				end
			end
		end
	end

	container.Parent = character
	character:SetAttribute("WeaponModel", modelId)
	character:SetAttribute("WeaponAccent", accent)
	return container
end

return WeaponService
