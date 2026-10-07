--!strict
--[[
	MapBuilder: generates the whole map at server start from terrain fills and parts, so the
	repository needs no binary place file. Layout constants live in Config/World.

	  Beacon Academy   cliff-top campus: plaza, statue, CCT tower, halls, lockers, launch pads
	  Vale             commercial district with the From Dust Till Dawn shop
	  Emerald Forest   dense woods below the cliff with the ruined relic temple and a lake
	  Forever Fall     crimson forest to the west
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Joints = require(Shared.Animation.Joints)
local World = require(Shared.Config.World)

local MapBuilder = {}

local random = Random.new(7) -- fixed seed: every server builds the same map
local terrain = Workspace.Terrain
local H = World.PlateauHeight

type PartProps = {
	size: Vector3,
	cframe: CFrame,
	color: Color3?,
	material: Enum.Material?,
	shape: Enum.PartType?,
	transparency: number?,
	collide: boolean?,
	parent: Instance,
	name: string?,
	reflectance: number?,
	castShadow: boolean?,
}

local function part(props: PartProps): Part
	local p = Instance.new("Part")
	p.Name = props.name or "Part"
	p.Anchored = true
	p.Size = props.size
	p.CFrame = props.cframe
	p.Color = props.color or Color3.fromRGB(160, 160, 160)
	p.Material = props.material or Enum.Material.SmoothPlastic
	if props.shape then
		p.Shape = props.shape
	end
	p.Transparency = props.transparency or 0
	p.Reflectance = props.reflectance or 0
	p.CanCollide = if props.collide == nil then true else props.collide
	p.CastShadow = if props.castShadow == nil then true else props.castShadow
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = props.parent
	return p
end

local function wedge(size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, parent: Instance): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = size
	w.CFrame = cframe
	w.Color = color
	w.Material = material
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Parent = parent
	return w
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Vertical cylinder (Roblox cylinders run along X).
local function column(position: Vector3, height: number, diameter: number): CFrame
	return CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
end

local function groundY(x: number, z: number): number
	local result = Workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0))
	return if result then result.Position.Y else 0
end

--[[ TERRAIN ]]

local function buildTerrain()
	terrain:FillBlock(CFrame.new(0, -6, -200), Vector3.new(1400, 12, 1400), Enum.Material.Grass)
	-- Beacon and Vale plateaus.
	terrain:FillBlock(CFrame.new(0, H / 2, 0), Vector3.new(228, H, 208), Enum.Material.Rock)
	terrain:FillBlock(CFrame.new(0, H - 1, 0), Vector3.new(228, 2, 208), Enum.Material.Grass)
	terrain:FillBlock(CFrame.new(232, H / 2, 0), Vector3.new(240, H, 168), Enum.Material.Rock)
	terrain:FillBlock(CFrame.new(232, H - 1, 0), Vector3.new(240, 2, 168), Enum.Material.Pavement)
	terrain:FillBlock(CFrame.new(232, H - 0.9, 0), Vector3.new(240, 2, 26), Enum.Material.Asphalt)
	terrain:FillCylinder(CFrame.new(0, H - 1, 4), 2, 50, Enum.Material.Cobblestone)
	-- Campus walkways.
	terrain:FillBlock(CFrame.new(0, H - 0.9, -66), Vector3.new(18, 2, 64), Enum.Material.Pavement)
	terrain:FillBlock(CFrame.new(82, H - 0.9, 0), Vector3.new(68, 2, 16), Enum.Material.Pavement)
	terrain:FillBlock(CFrame.new(0, H - 0.9, 64), Vector3.new(16, 2, 40), Enum.Material.Pavement)
	-- Ramps down to the forests.
	terrain:FillWedge(CFrame.new(76, H / 2, -130), Vector3.new(26, H, 64), Enum.Material.Ground)
	terrain:FillWedge(CFrame.new(-144, H / 2, 30) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(26, H, 64), Enum.Material.Ground)
	-- Emerald Forest lake and hills.
	terrain:FillBlock(CFrame.new(-150, -2.5, -380), Vector3.new(76, 5, 54), Enum.Material.Water)
	for _, hill in { Vector3.new(170, -10, -250), Vector3.new(-200, -12, -520), Vector3.new(200, -9, -540), Vector3.new(-90, -14, -180) } do
		terrain:FillBall(hill, 22, Enum.Material.Grass)
	end
	-- Forever Fall's leaf-littered floor.
	terrain:FillBlock(CFrame.new(-360, -0.6, -120), Vector3.new(300, 1.2, 360), Enum.Material.LeafyGrass)

	pcall(function()
		terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(86, 140, 62))
		terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(150, 52, 44))
		terrain:SetMaterialColor(Enum.Material.Cobblestone, Color3.fromRGB(150, 146, 140))
		terrain:SetMaterialColor(Enum.Material.Pavement, Color3.fromRGB(162, 158, 152))
		terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(110, 104, 100))
	end)
	terrain.WaterColor = Color3.fromRGB(46, 104, 120)
	terrain.WaterTransparency = 0.6
	terrain.WaterWaveSize = 0.08
	pcall(function()
		(terrain :: any).Decoration = true
	end)
end

--[[ PROPS ]]

local LEAF_GREENS = {
	Color3.fromRGB(62, 128, 58),
	Color3.fromRGB(74, 140, 66),
	Color3.fromRGB(52, 110, 54),
	Color3.fromRGB(88, 150, 70),
}
local LEAF_REDS = {
	Color3.fromRGB(176, 36, 44),
	Color3.fromRGB(204, 64, 52),
	Color3.fromRGB(150, 22, 38),
	Color3.fromRGB(222, 96, 70),
}
local LEAF_BLOSSOM = { Color3.fromRGB(240, 170, 196), Color3.fromRGB(250, 206, 220) }

local function tree(parent: Instance, base: Vector3, scale: number, leaves: { Color3 }, trunkColor: Color3)
	local height = 10 * scale
	part({
		name = "Trunk",
		size = Vector3.new(height, 1.6 * scale, 1.6 * scale),
		cframe = column(base - Vector3.new(0, 1, 0), height, 1.6 * scale),
		color = trunkColor,
		material = Enum.Material.Wood,
		shape = Enum.PartType.Cylinder,
		parent = parent,
	})
	local count = random:NextInteger(2, 4)
	for i = 1, count do
		local size = random:NextNumber(6, 9) * scale
		local offset = Vector3.new(random:NextNumber(-2.4, 2.4), random:NextNumber(-1, 2.5), random:NextNumber(-2.4, 2.4)) * scale
		part({
			name = "Canopy",
			size = Vector3.new(size, size * 0.86, size),
			cframe = CFrame.new(base + Vector3.new(0, height - 1 + i * 0.6 * scale, 0) + offset),
			color = leaves[random:NextInteger(1, #leaves)],
			material = Enum.Material.Grass,
			shape = Enum.PartType.Ball,
			parent = parent,
			collide = false,
		})
	end
end

local function rock(parent: Instance, base: Vector3, size: number)
	part({
		name = "Rock",
		size = Vector3.new(size * random:NextNumber(1, 1.5), size, size * random:NextNumber(0.9, 1.4)),
		cframe = CFrame.new(base) * CFrame.Angles(random:NextNumber(-0.3, 0.3), random:NextNumber(0, 6.28), random:NextNumber(-0.3, 0.3)),
		color = Color3.fromRGB(116, 112, 108),
		material = Enum.Material.Slate,
		parent = parent,
	})
end

local function lamp(parent: Instance, base: Vector3)
	part({
		name = "LampPost",
		size = Vector3.new(11, 0.5, 0.5),
		cframe = column(base, 11, 0.5),
		color = Color3.fromRGB(40, 40, 46),
		material = Enum.Material.Metal,
		shape = Enum.PartType.Cylinder,
		parent = parent,
	})
	local bulb = part({
		name = "Lamp",
		size = Vector3.new(1.4, 1.4, 1.4),
		cframe = CFrame.new(base + Vector3.new(0, 11.4, 0)),
		color = Color3.fromRGB(255, 214, 150),
		material = Enum.Material.Neon,
		shape = Enum.PartType.Ball,
		parent = parent,
		castShadow = false,
	})
	light(bulb, Color3.fromRGB(255, 196, 130), 24, 1.6)
end

--[[ BEACON ACADEMY ]]

local STONE = Color3.fromRGB(214, 212, 206)
local STONE_DARK = Color3.fromRGB(150, 148, 144)
local ROOF = Color3.fromRGB(46, 70, 64)

local function hall(parent: Instance, center: Vector3, size: Vector3)
	local body = part({
		name = "Hall",
		size = size,
		cframe = CFrame.new(center + Vector3.new(0, size.Y / 2, 0)),
		color = STONE,
		material = Enum.Material.Slate,
		parent = parent,
	})
	local roofHeight = size.Y * 0.45
	local half = Vector3.new(size.X + 2, roofHeight, size.Z / 2 + 1)
	local top = center.Y + size.Y
	wedge(half, CFrame.new(center.X, top + roofHeight / 2, center.Z - half.Z / 2), ROOF, Enum.Material.Slate, parent)
	wedge(
		half,
		CFrame.new(center.X, top + roofHeight / 2, center.Z + half.Z / 2) * CFrame.Angles(0, math.rad(180), 0),
		ROOF,
		Enum.Material.Slate,
		parent
	)
	-- Tall arched windows on both long faces.
	local count = math.floor(size.X / 7)
	for i = 1, count do
		local x = center.X - size.X / 2 + (i - 0.5) * (size.X / count)
		for _, side in { -1, 1 } do
			part({
				name = "Window",
				size = Vector3.new(2.4, size.Y * 0.5, 0.3),
				cframe = CFrame.new(x, center.Y + size.Y * 0.5, center.Z + side * (size.Z / 2 + 0.1)),
				color = Color3.fromRGB(150, 210, 190),
				material = Enum.Material.Neon,
				transparency = 0.35,
				parent = parent,
				castShadow = false,
			})
		end
	end
	return body
end

local function tower(parent: Instance, base: Vector3)
	local sections = {
		{ width = 20, height = 10, color = STONE_DARK },
		{ width = 15, height = 42, color = STONE },
		{ width = 12, height = 30, color = STONE },
		{ width = 9, height = 18, color = STONE },
	}
	local y = base.Y
	for _, section in sections do
		part({
			name = "Tower",
			size = Vector3.new(section.width, section.height, section.width),
			cframe = CFrame.new(base.X, y + section.height / 2, base.Z) * CFrame.Angles(0, math.rad(45), 0),
			color = section.color,
			material = Enum.Material.Slate,
			parent = parent,
		})
		y += section.height
	end
	-- The emerald crown that glows over the campus.
	local crown = part({
		name = "Crown",
		size = Vector3.new(3, 22, 22),
		cframe = CFrame.new(base.X, y + 1, base.Z) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(60, 255, 150),
		material = Enum.Material.Neon,
		shape = Enum.PartType.Cylinder,
		parent = parent,
		castShadow = false,
	})
	light(crown, Color3.fromRGB(80, 255, 160), 60, 3)
	part({
		name = "Spire",
		size = Vector3.new(26, 2.4, 2.4),
		cframe = column(Vector3.new(base.X, y + 2, base.Z), 26, 2.4),
		color = STONE,
		material = Enum.Material.Slate,
		shape = Enum.PartType.Cylinder,
		parent = parent,
	})
	part({
		name = "Beacon",
		size = Vector3.new(3, 3, 3),
		cframe = CFrame.new(base.X, y + 29, base.Z),
		color = Color3.fromRGB(110, 255, 170),
		material = Enum.Material.Neon,
		shape = Enum.PartType.Ball,
		parent = parent,
		castShadow = false,
	})
end

-- A posed statue figure built with forward kinematics from an animation-style pose.
local function statueFigure(parent: Instance, root: CFrame, pose: Joints.Pose, scale: number, color: Color3)
	local frames = Joints.solve(pose, CFrame.identity)
	local sizes: { [string]: Vector3 } = {
		Torso = Vector3.new(2, 2, 1),
		Head = Vector3.new(1.2, 1.2, 1.2),
		["Right Arm"] = Vector3.new(1, 2, 1),
		["Left Arm"] = Vector3.new(1, 2, 1),
		["Right Leg"] = Vector3.new(1, 2, 1),
		["Left Leg"] = Vector3.new(1, 2, 1),
	}
	for name, size in sizes do
		local cf = frames[name]
		local placed = root * CFrame.new(cf.Position * scale) * cf.Rotation
		part({
			name = name,
			size = size * scale,
			cframe = placed,
			color = color,
			material = Enum.Material.Marble,
			shape = if name == "Head" then Enum.PartType.Ball else nil,
			parent = parent,
		})
	end
	return frames
end

local function statue(parent: Instance, center: Vector3)
	local bronze = Color3.fromRGB(122, 140, 126)
	part({
		name = "Plinth",
		size = Vector3.new(4, 22, 22),
		cframe = column(center, 4, 22),
		color = STONE_DARK,
		material = Enum.Material.Slate,
		shape = Enum.PartType.Cylinder,
		parent = parent,
	})
	-- Cliff outcrop.
	for i = 0, 4 do
		local angle = i * 1.25
		wedge(
			Vector3.new(6, 7 + i, 8),
			CFrame.new(center + Vector3.new(math.cos(angle) * 3, 7.5 + i * 0.4, math.sin(angle) * 3))
				* CFrame.Angles(0, angle, 0),
			bronze,
			Enum.Material.Marble,
			parent
		)
	end
	local scale = 1.7
	local T, Hd, RA, LA, RL, LL, RG = Joints.T, Joints.H, Joints.RA, Joints.LA, Joints.RL, Joints.LL, Joints.RG
	-- The huntsman, sword raised to the heavens.
	local manRoot = CFrame.new(center + Vector3.new(-2.2, 13 + 3 * scale, 0)) * CFrame.Angles(0, math.rad(-15), 0)
	local man = statueFigure(parent, manRoot, {
		Root = T(-4, 10, 0),
		Neck = Hd(-25, -10, 0),
		RightArm = RA(172, 12, 0),
		LeftArm = LA(-10, 26, 0),
		RightLeg = RL(18, 4),
		LeftLeg = LL(-14, 6),
		RightGrip = RG(0, 0, 0),
	}, scale, bronze)
	local hand = manRoot * CFrame.new(man.HandleRight.Position * scale) * man.HandleRight.Rotation
	part({
		name = "Sword",
		size = Vector3.new(0.35, 6.5, 0.9) * (scale * 0.7),
		cframe = hand * CFrame.new(0, 3.2 * scale * 0.7, 0),
		color = bronze,
		material = Enum.Material.Marble,
		parent = parent,
	})
	-- The huntress, axe lowered.
	local womanRoot = CFrame.new(center + Vector3.new(2.6, 13 + 3 * scale, 1.2)) * CFrame.Angles(0, math.rad(20), 0)
	local woman = statueFigure(parent, womanRoot, {
		Root = T(4, -16, 0),
		Neck = Hd(8, 14, 0),
		RightArm = RA(20, 30, 0),
		LeftArm = LA(30, 10, 20),
		RightLeg = RL(-10, 10),
		LeftLeg = LL(16, 6),
		RightGrip = RG(-30, 0, 0),
	}, scale, bronze)
	local axeHand = womanRoot * CFrame.new(woman.HandleRight.Position * scale) * woman.HandleRight.Rotation
	part({
		name = "AxeHaft",
		size = Vector3.new(0.4, 6, 0.4) * scale * 0.7,
		cframe = axeHand * CFrame.new(0, 1.2 * scale, 0),
		color = bronze,
		material = Enum.Material.Marble,
		parent = parent,
	})
	part({
		name = "AxeHead",
		size = Vector3.new(0.3, 1.8, 1.6) * scale * 0.7,
		cframe = axeHand * CFrame.new(0, 3 * scale, -0.6 * scale),
		color = bronze,
		material = Enum.Material.Marble,
		parent = parent,
	})
	-- The Beowolf beneath their feet.
	local wolfRoot = CFrame.new(center + Vector3.new(0.5, 9.2, -5.5)) * CFrame.Angles(0, math.rad(180), 0)
	statueFigure(parent, wolfRoot, {
		Root = T(38, 0, 0, 0, -0.6, 0),
		Neck = Hd(-30, 0, 0),
		RightArm = RA(60, 24),
		LeftArm = LA(40, 24),
		RightLeg = RL(30, 10),
		LeftLeg = LL(-10, 10),
	}, 1.5, bronze)
end

local function launchPads(parent: Instance)
	for _, pad in World.LaunchPads do
		local plate = part({
			name = "LaunchPad",
			size = Vector3.new(7, 0.6, 7),
			cframe = CFrame.new(pad.position),
			color = Color3.fromRGB(70, 74, 82),
			material = Enum.Material.DiamondPlate,
			parent = parent,
		})
		plate:SetAttribute("LaunchDirection", pad.direction.Unit)
		plate:SetAttribute("LaunchSpeed", World.LaunchSpeed)
		CollectionService:AddTag(plate, "LaunchPad")
		part({
			name = "PadRing",
			size = Vector3.new(0.2, 5.5, 5.5),
			cframe = CFrame.new(pad.position + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			color = Color3.fromRGB(80, 255, 160),
			material = Enum.Material.Neon,
			shape = Enum.PartType.Cylinder,
			parent = parent,
			collide = false,
			castShadow = false,
		})
	end
end

local function lockers(parent: Instance, base: Vector3)
	for i = 0, 5 do
		local locker = part({
			name = "Locker",
			size = Vector3.new(3, 7, 2.6),
			cframe = CFrame.new(base + Vector3.new(i * 3.2, 3.5, 0)),
			color = Color3.fromRGB(62, 66, 74),
			material = Enum.Material.DiamondPlate,
			parent = parent,
		})
		part({
			name = "Stripe",
			size = Vector3.new(3.05, 0.4, 2.65),
			cframe = locker.CFrame * CFrame.new(0, 2.6, 0),
			color = Color3.fromRGB(80, 255, 160),
			material = Enum.Material.Neon,
			parent = parent,
			castShadow = false,
		})
		if i == 2 then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Change Weapon"
			prompt.ObjectText = "Beacon Lockers"
			prompt.KeyboardKeyCode = Enum.KeyCode.G
			prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Parent = locker
			CollectionService:AddTag(prompt, "WeaponLocker")
		end
	end
end

local function buildBeacon(root: Instance)
	local beacon = folder("Beacon", root)
	statue(beacon, Vector3.new(0, H, 4))
	tower(beacon, Vector3.new(0, H, 86))
	hall(beacon, Vector3.new(-58, H, 72), Vector3.new(46, 20, 26))
	hall(beacon, Vector3.new(58, H, 72), Vector3.new(46, 20, 26))
	lockers(beacon, Vector3.new(-52, H, 18))
	launchPads(beacon)
	for i = -3, 3 do
		lamp(beacon, Vector3.new(-12, H, -40 + i * 9))
		lamp(beacon, Vector3.new(12, H, -40 + i * 9))
	end
	for i = 0, 11 do
		local angle = i / 12 * math.pi * 2
		local position = Vector3.new(math.cos(angle) * 56, H, 4 + math.sin(angle) * 56)
		if math.abs(position.X) > 14 and math.abs(position.Z - 4) > 14 then
			tree(beacon, position, random:NextNumber(0.85, 1.05), if i % 3 == 0 then LEAF_BLOSSOM else LEAF_GREENS, Color3.fromRGB(96, 70, 52))
		end
		lamp(beacon, Vector3.new(math.cos(angle + 0.26) * 46, H, 4 + math.sin(angle + 0.26) * 46))
	end
	-- Hedges framing the plaza.
	for _, x in { -30, 30 } do
		part({
			name = "Hedge",
			size = Vector3.new(4, 3, 30),
			cframe = CFrame.new(x, H + 1.5, -24),
			color = Color3.fromRGB(56, 108, 52),
			material = Enum.Material.Grass,
			parent = beacon,
		})
	end
	-- Cliff-edge outcrops.
	for i = -10, 10 do
		rock(beacon, Vector3.new(i * 11 + random:NextNumber(-3, 3), H - 2, -103 + random:NextNumber(-2, 2)), random:NextNumber(5, 9))
	end
end

--[[ VALE ]]

local BUILDING_COLORS = {
	Color3.fromRGB(176, 128, 104),
	Color3.fromRGB(204, 190, 170),
	Color3.fromRGB(140, 98, 82),
	Color3.fromRGB(118, 124, 136),
	Color3.fromRGB(196, 168, 128),
}

local function building(parent: Instance, center: Vector3, size: Vector3, facing: number)
	part({
		name = "Building",
		size = size,
		cframe = CFrame.new(center + Vector3.new(0, size.Y / 2, 0)),
		color = BUILDING_COLORS[random:NextInteger(1, #BUILDING_COLORS)],
		material = Enum.Material.Brick,
		parent = parent,
	})
	local rows = math.floor((size.Y - 4) / 7)
	local cols = math.floor(size.X / 6)
	for r = 1, rows do
		for c = 1, cols do
			local lit = random:NextNumber() < 0.55
			part({
				name = "Window",
				size = Vector3.new(2.6, 3.2, 0.3),
				cframe = CFrame.new(
					center.X - size.X / 2 + (c - 0.5) * (size.X / cols),
					center.Y + 2 + r * 7 - 3,
					center.Z + facing * (size.Z / 2 + 0.1)
				),
				color = if lit then Color3.fromRGB(255, 214, 140) else Color3.fromRGB(60, 74, 92),
				material = if lit then Enum.Material.Neon else Enum.Material.Glass,
				transparency = if lit then 0.25 else 0.1,
				parent = parent,
				castShadow = false,
			})
		end
	end
end

local function dustShop(parent: Instance)
	local center = World.DustShop
	local shop = folder("FromDustTillDawn", parent)
	local wallColor = Color3.fromRGB(84, 60, 92)
	-- Back and side walls, roof; the street side stays open.
	part({ name = "BackWall", size = Vector3.new(30, 20, 1), cframe = CFrame.new(center.X, H + 10, center.Z - 20), color = wallColor, material = Enum.Material.Brick, parent = shop })
	part({ name = "SideWall", size = Vector3.new(1, 20, 40), cframe = CFrame.new(center.X - 15, H + 10, center.Z), color = wallColor, material = Enum.Material.Brick, parent = shop })
	part({ name = "SideWall", size = Vector3.new(1, 20, 40), cframe = CFrame.new(center.X + 15, H + 10, center.Z), color = wallColor, material = Enum.Material.Brick, parent = shop })
	part({ name = "Roof", size = Vector3.new(32, 1, 42), cframe = CFrame.new(center.X, H + 20.5, center.Z), color = Color3.fromRGB(50, 40, 56), material = Enum.Material.Slate, parent = shop })
	part({ name = "Facade", size = Vector3.new(30, 6, 1), cframe = CFrame.new(center.X, H + 17, center.Z + 20), color = wallColor, material = Enum.Material.Brick, parent = shop })

	local sign = part({
		name = "Sign",
		size = Vector3.new(22, 3.6, 0.4),
		cframe = CFrame.new(center.X, H + 16.5, center.Z + 20.8),
		color = Color3.fromRGB(30, 24, 36),
		material = Enum.Material.Metal,
		parent = shop,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "From Dust Till Dawn"
	label.Font = Enum.Font.Fondamento
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 150)
	label.Parent = gui

	local counter = part({
		name = "Counter",
		size = Vector3.new(16, 3.4, 3),
		cframe = CFrame.new(center.X, H + 1.7, center.Z - 6),
		color = Color3.fromRGB(96, 66, 46),
		material = Enum.Material.Wood,
		parent = shop,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Browse Dust"
	prompt.ObjectText = "From Dust Till Dawn"
	prompt.KeyboardKeyCode = Enum.KeyCode.G
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
	CollectionService:AddTag(prompt, "DustShop")

	-- Glowing Dust crystals on display.
	local crystals = {
		Color3.fromRGB(255, 112, 40),
		Color3.fromRGB(140, 214, 255),
		Color3.fromRGB(255, 236, 110),
		Color3.fromRGB(172, 110, 255),
	}
	for i, color in crystals do
		local crystal = part({
			name = "DustCrystal",
			size = Vector3.new(1.1, 2.2, 1.1),
			cframe = CFrame.new(center.X - 7.5 + i * 3, H + 4.6, center.Z - 6) * CFrame.Angles(0, math.rad(45), math.rad(12)),
			color = color,
			material = Enum.Material.Neon,
			parent = shop,
			collide = false,
			castShadow = false,
		})
		light(crystal, color, 10, 1.2)
		for j = 1, 3 do
			part({
				name = "ShelfCrystal",
				size = Vector3.new(0.7, 1.4, 0.7),
				cframe = CFrame.new(center.X - 12 + i * 4.6 + j * 1.2, H + 8 + j * 0.2, center.Z - 18.8) * CFrame.Angles(0, 0, math.rad(15)),
				color = color,
				material = Enum.Material.Neon,
				parent = shop,
				collide = false,
				castShadow = false,
			})
		end
	end
	lamp(shop, Vector3.new(center.X - 18, H, center.Z + 24))
	lamp(shop, Vector3.new(center.X + 18, H, center.Z + 24))
end

local function buildVale(root: Instance)
	local vale = folder("Vale", root)
	local x = 136
	while x < 340 do
		local width = random:NextNumber(20, 28)
		local center = x + width / 2
		if math.abs(center - World.DustShop.X) > 22 then
			building(vale, Vector3.new(center, H, -34), Vector3.new(width - 2, random:NextNumber(22, 46), 28), 1)
		end
		building(vale, Vector3.new(center, H, 34), Vector3.new(width - 2, random:NextNumber(22, 46), 28), -1)
		lamp(vale, Vector3.new(center, H, -15))
		lamp(vale, Vector3.new(center + width / 2, H, 15))
		x += width
	end
	dustShop(vale)
end

--[[ FORESTS ]]

local function nearTemple(position: Vector3): boolean
	return (Vector3.new(position.X, 0, position.Z) - Vector3.new(0, 0, -470)).Magnitude < 36
end

local function nearLake(position: Vector3): boolean
	return math.abs(position.X + 150) < 44 and math.abs(position.Z + 380) < 32
end

local function nearPath(position: Vector3): boolean
	return math.abs(position.X - 76) < 18 and position.Z > -200
end

local function buildEmeraldForest(root: Instance)
	local forest = folder("EmeraldForest", root)
	local placed = 0
	local attempts = 0
	while placed < 170 and attempts < 2000 do
		attempts += 1
		local position = Vector3.new(random:NextNumber(-250, 250), 0, random:NextNumber(-620, -125))
		if not nearTemple(position) and not nearLake(position) and not nearPath(position) then
			local y = groundY(position.X, position.Z)
			tree(forest, Vector3.new(position.X, y, position.Z), random:NextNumber(0.9, 1.6), LEAF_GREENS, Color3.fromRGB(88, 64, 46))
			placed += 1
		end
	end
	for _ = 1, 40 do
		local position = Vector3.new(random:NextNumber(-250, 250), 0, random:NextNumber(-620, -125))
		if not nearTemple(position) then
			rock(forest, Vector3.new(position.X, groundY(position.X, position.Z), position.Z), random:NextNumber(2, 6))
		end
	end

	-- The ruined temple where students claim their relics.
	local temple = folder("Temple", forest)
	local center = Vector3.new(0, groundY(0, -470), -470)
	part({
		name = "Floor",
		size = Vector3.new(2, 46, 46),
		cframe = column(center - Vector3.new(0, 0.6, 0), 2, 46),
		color = Color3.fromRGB(150, 148, 136),
		material = Enum.Material.Slate,
		shape = Enum.PartType.Cylinder,
		parent = temple,
	})
	for i = 0, 9 do
		local angle = i / 10 * math.pi * 2
		local height = if i % 3 == 1 then random:NextNumber(4, 8) else 16
		part({
			name = "Pillar",
			size = Vector3.new(height, 3, 3),
			cframe = column(center + Vector3.new(math.cos(angle) * 20, 0, math.sin(angle) * 20), height, 3),
			color = Color3.fromRGB(170, 166, 152),
			material = Enum.Material.Marble,
			shape = Enum.PartType.Cylinder,
			parent = temple,
		})
	end
	local relicColors = { Color3.fromRGB(230, 190, 70), Color3.fromRGB(30, 30, 34) }
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2
		local spot = center + Vector3.new(math.cos(angle) * 9, 0, math.sin(angle) * 9)
		part({
			name = "Pedestal",
			size = Vector3.new(2.2, 3, 2.2),
			cframe = CFrame.new(spot + Vector3.new(0, 1.5, 0)),
			color = Color3.fromRGB(140, 136, 126),
			material = Enum.Material.Slate,
			parent = temple,
		})
		local color = relicColors[i % 2 + 1]
		part({
			name = "RelicBase",
			size = Vector3.new(0.4, 1.4, 1.4),
			cframe = column(spot + Vector3.new(0, 3, 0), 0.4, 1.4),
			color = color,
			material = Enum.Material.Foil,
			shape = Enum.PartType.Cylinder,
			parent = temple,
		})
		part({
			name = "RelicBody",
			size = Vector3.new(1.4, 0.7, 0.7),
			cframe = column(spot + Vector3.new(0, 3.4, 0), 1.4, 0.7),
			color = color,
			material = Enum.Material.Foil,
			shape = Enum.PartType.Cylinder,
			parent = temple,
		})
		part({
			name = "RelicHead",
			size = Vector3.new(0.9, 0.9, 0.9),
			cframe = CFrame.new(spot + Vector3.new(0, 5.2, 0)),
			color = color,
			material = Enum.Material.Foil,
			shape = Enum.PartType.Ball,
			parent = temple,
		})
	end
end

local function buildForeverFall(root: Instance)
	local fall = folder("ForeverFall", root)
	local placed = 0
	local attempts = 0
	while placed < 90 and attempts < 1200 do
		attempts += 1
		local position = Vector3.new(random:NextNumber(-500, -215), 0, random:NextNumber(-290, 50))
		local y = groundY(position.X, position.Z)
		if y < 4 then
			tree(fall, Vector3.new(position.X, y, position.Z), random:NextNumber(1, 1.7), LEAF_REDS, Color3.fromRGB(228, 222, 210))
			placed += 1
		end
	end
end

function MapBuilder.build(): Folder
	local root = Instance.new("Folder")
	root.Name = "Map"
	root.Parent = Workspace
	buildTerrain()
	buildBeacon(root)
	buildVale(root)
	buildEmeraldForest(root)
	buildForeverFall(root)
	return root
end

return MapBuilder
