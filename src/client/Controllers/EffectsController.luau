--!strict
--[[
	EffectsController: everything you see and hear when something happens in a fight.

	Server broadcasts (Effects remote): Hit, Shot, Projectile, Explosion, Effect.
	Animation markers: Glint (critical tell), Swing, Step, Shake, Sound.

	Hits drive the "feel": hitstop freezes attacker and victim for a few frames, the victim
	flinches on a spring and plays a reaction clip, the camera shakes when you're involved, and an
	aura-coloured shimmer shows Aura soaking the blow (or shattering when it breaks).
	All effect parts are client-only and live in Workspace.ClientEffects.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Combat = require(Shared.Config.Combat)
local Dust = require(Shared.Config.Dust)
local Net = require(Shared.Net)
local Semblances = require(Shared.Config.Semblances)

local Audio = require(script.Parent.Parent.Util.Audio)
local AnimationController = require(script.Parent.AnimationController)
local CameraController = require(script.Parent.CameraController)

local EffectsController = {}

local player = Players.LocalPlayer
local random = Random.new()
local folder: Folder

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local WHITE = Color3.new(1, 1, 1)
local GRIMM_RED = Color3.fromRGB(255, 40, 30)

--[[ PRIMITIVES ]]

local function fxPart(
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.Neon
	if shape then
		part.Shape = shape
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = folder
	return part
end

local function tween(
	instance: Instance,
	duration: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	local info = TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local t = TweenService:Create(instance, info, goal)
	t:Play()
	return t
end

local function fadeAway(part: BasePart, duration: number, goal: { [string]: any }?)
	local properties: { [string]: any } = { Transparency = 1 }
	if goal then
		for key, value in goal do
			properties[key] = value
		end
	end
	tween(part, duration, properties)
	Debris:AddItem(part, duration + 0.05)
end

-- Expanding, fading sphere.
local function sphere(
	position: Vector3,
	color: Color3,
	from: number,
	to: number,
	duration: number,
	material: Enum.Material?
)
	local ball = fxPart(Vector3.one * from, CFrame.new(position), color, material, Enum.PartType.Ball)
	ball.Transparency = 0.15
	fadeAway(ball, duration, { Size = Vector3.one * to })
end

-- Expanding, fading flat disc (a shockwave) facing `up`.
local function shockwave(position: Vector3, color: Color3, from: number, to: number, duration: number, up: Vector3?)
	local normal = up or Vector3.yAxis
	local frame = CFrame.lookAt(position, position + normal) * CFrame.Angles(0, math.rad(90), 0)
	local disc = fxPart(Vector3.new(0.2, from, from), frame, color, Enum.Material.Neon, Enum.PartType.Cylinder)
	disc.Transparency = 0.2
	fadeAway(disc, duration, { Size = Vector3.new(0.05, to, to) })
end

-- A glowing line between two points.
local function beam(from: Vector3, to: Vector3, color: Color3, width: number, duration: number)
	local length = (to - from).Magnitude
	if length < 0.05 then
		return
	end
	local part = fxPart(Vector3.new(width, width, length), CFrame.lookAt((from + to) / 2, to), color)
	part.Transparency = 0.05
	fadeAway(part, duration, { Size = Vector3.new(0, 0, length) })
end

local function particles(parent: Instance, props: { [string]: any }): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.LightEmission = 0.6
	emitter.LockedToPart = false
	for key, value in props do
		(emitter :: any)[key] = value
	end
	emitter.Parent = parent
	return emitter
end

-- One-shot particle burst at a point.
local function burst(
	position: Vector3,
	color: Color3,
	count: number,
	speed: number,
	size: number,
	texture: string?,
	lifetime: number?
)
	local holder = fxPart(Vector3.new(0.1, 0.1, 0.1), CFrame.new(position), color)
	holder.Transparency = 1
	local emitter = particles(holder, {
		Texture = texture or SPARKLE,
		Color = ColorSequence.new(color),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0.1, 1),
		Lifetime = NumberRange.new((lifetime or 0.5) * 0.6, lifetime or 0.5),
		Speed = NumberRange.new(speed * 0.5, speed),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-200, 200),
	})
	emitter:Emit(count)
	Debris:AddItem(holder, (lifetime or 0.5) + 0.3)
end

-- Little neon shards flying outward (aura shatter, guard break).
local function shatter(position: Vector3, color: Color3, count: number, radius: number, material: Enum.Material?)
	for _ = 1, count do
		local direction = random:NextUnitVector()
		local size = random:NextNumber(0.25, 0.7)
		local shard = Instance.new("WedgePart")
		shard.Anchored = true
		shard.CanCollide = false
		shard.CanQuery = false
		shard.CanTouch = false
		shard.CastShadow = false
		shard.Material = material or Enum.Material.Neon
		shard.Color = color
		shard.Size = Vector3.new(0.05, size, size * 0.8)
		shard.CFrame = CFrame.new(position) * CFrame.Angles(random:NextNumber(0, 6.28), random:NextNumber(0, 6.28), 0)
		shard.Transparency = 0.1
		shard.Parent = folder
		local goal = CFrame.new(position + direction * radius * random:NextNumber(0.6, 1.2))
			* CFrame.Angles(random:NextNumber(0, 6.28), random:NextNumber(0, 6.28), 0)
		fadeAway(shard, random:NextNumber(0.4, 0.7), { CFrame = goal })
	end
end

local function rootOf(rig: Instance?): BasePart?
	if rig == nil then
		return nil
	end
	local root = rig:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function partOf(rig: Instance?, name: string): BasePart?
	if rig == nil then
		return nil
	end
	local part = rig:FindFirstChild(name)
	return if part and part:IsA("BasePart") then part else nil
end

local function auraColor(rig: Instance?): Color3
	if rig then
		local color = rig:GetAttribute("SignatureColor")
		if typeof(color) == "Color3" then
			return color
		end
	end
	return Color3.fromRGB(255, 200, 80)
end

-- Brief silhouette flash (hits, aura shimmer, buffs).
local function flashRig(rig: Instance?, color: Color3, duration: number, fill: number?)
	if rig == nil or not rig:IsA("Model") then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = fill or 0.3
	highlight.OutlineTransparency = 0.1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = rig
	highlight.Parent = folder
	tween(highlight, duration, { FillTransparency = 1, OutlineTransparency = 1 })
	Debris:AddItem(highlight, duration + 0.05)
end

local function popupText(position: Vector3, text: string, color: Color3, size: number, rise: number?)
	local holder = fxPart(Vector3.new(0.1, 0.1, 0.1), CFrame.new(position), color)
	holder.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 50)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Adornee = holder
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = size
	label.Parent = gui
	local offset = Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1))
	tween(
		holder,
		0.8,
		{ CFrame = CFrame.new(position + offset + Vector3.new(0, rise or 2.5, 0)) },
		Enum.EasingStyle.Quart
	)
	tween(
		label,
		0.8,
		{ TextTransparency = 1, TextStrokeTransparency = 1 },
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.In
	)
	label.TextSize = size * 1.5
	tween(label, 0.18, { TextSize = size }, Enum.EasingStyle.Back)
	Debris:AddItem(holder, 0.85)
end

local function involvesMe(...: Instance?): boolean
	local character = player.Character
	if character == nil then
		return false
	end
	for i = 1, select("#", ...) do
		if select(i, ...) == character then
			return true
		end
	end
	return false
end

--[[ HIT REACTIONS ]]

local lightToggle: { [Model]: boolean } = {}

local function playReaction(victim: Model, direction: Vector3, heavy: boolean)
	local root = rootOf(victim)
	if root == nil then
		return
	end
	local clip: string
	if heavy then
		clip = "Common.HitHeavy"
	else
		local fromDirection = -direction
		local localDir = root.CFrame:VectorToObjectSpace(fromDirection)
		if localDir.Z > 0.55 then
			clip = "Common.HitBack"
		else
			lightToggle[victim] = not lightToggle[victim]
			clip = if lightToggle[victim] then "Common.HitLight1" else "Common.HitLight2"
		end
	end
	AnimationController.play(victim, clip)
end

local function onHit(payload: { [string]: any })
	local attacker: Instance? = payload.attacker
	local victim: Instance? = payload.victim
	local position: Vector3 = if typeof(payload.position) == "Vector3" then payload.position else Vector3.zero
	local direction: Vector3 = if typeof(payload.direction) == "Vector3" then payload.direction else Vector3.zero
	local result = payload.result
	local heavy = payload.heavy == true
	local mine = involvesMe(attacker, victim)
	local victimModel = if victim and victim:IsA("Model") then victim else nil
	local attackerAnimator = AnimationController.get(attacker)
	local victimAnimator = AnimationController.get(victim)
	local victimRoot = rootOf(victim)

	if result == "Dodge" then
		if victimRoot then
			popupText(victimRoot.Position + Vector3.new(0, 3, 0), "DODGE", Color3.fromRGB(180, 220, 255), 18, 2)
			Audio.playOn("Dodge", victimRoot)
		end
		return
	elseif result == "Clone" then
		if victimRoot then
			burst(victimRoot.Position, Color3.fromRGB(40, 20, 60), 24, 12, 1.6, SMOKE, 0.8)
		end
		return
	elseif result == "Parry" then
		sphere(position, WHITE, 1, 7, 0.25)
		burst(position, Color3.fromRGB(255, 240, 200), 30, 40, 0.8, SPARKLE, 0.35)
		shockwave(position, WHITE, 1, 10, 0.3, direction.Magnitude > 0.1 and direction or nil)
		Audio.playAt("Parry", position)
		for _, animator in { attackerAnimator, victimAnimator } do
			if animator then
				animator:hitstop(Combat.HitstopParry)
			end
		end
		if mine then
			CameraController.shake(0.3)
			popupText(position + Vector3.new(0, 2, 0), "PARRY", WHITE, 22, 2)
		end
		return
	elseif result == "Block" then
		burst(position, Color3.fromRGB(255, 210, 120), 12, 22, 0.5, SPARKLE, 0.25)
		sphere(position, Color3.fromRGB(255, 220, 160), 0.5, 3, 0.15)
		Audio.playAt("Block", position)
		if victimAnimator then
			victimAnimator:hitstop(0.04)
			victimAnimator:flinchFrom(-direction, 0.25)
		end
		if attackerAnimator then
			attackerAnimator:hitstop(0.04)
		end
		if mine then
			CameraController.shake(0.08)
		end
		return
	elseif result == "GuardBreak" then
		if victimRoot then
			shatter(victimRoot.Position + Vector3.new(0, 1, 0), WHITE, 16, 7)
			popupText(victimRoot.Position + Vector3.new(0, 3.5, 0), "GUARD BROKEN", Color3.fromRGB(255, 120, 90), 22, 2)
		end
		Audio.playAt("GuardBreak", position)
		if mine then
			CameraController.shake(0.4)
		end
		return
	end

	-- A landed hit (or damage over time).
	local isTick = result == "Burn"
	local damage = if type(payload.damage) == "number" then payload.damage else 0
	local auraAbsorbed = payload.aura == true
	local color = auraColor(victim)

	if not isTick then
		if auraAbsorbed and victimRoot then
			-- Aura shimmer: a translucent force-field shell flashes around the victim.
			local shell = fxPart(
				Vector3.one * 7,
				CFrame.new(victimRoot.Position),
				color,
				Enum.Material.ForceField,
				Enum.PartType.Ball
			)
			shell.Transparency = 0.2
			fadeAway(shell, 0.35, { Size = Vector3.one * 8 })
			flashRig(victim, color, 0.25, 0.45)
			Audio.playAt("AuraHit", position)
		else
			flashRig(victim, WHITE, 0.16, 0.25)
		end
		burst(
			position,
			if auraAbsorbed then color else Color3.fromRGB(255, 236, 210),
			if heavy then 26 else 14,
			if heavy then 38 else 26,
			0.7,
			SPARKLE,
			0.3
		)
		sphere(position, WHITE, 0.6, if heavy then 4.5 else 2.8, 0.14)
		Audio.playAt(if heavy then "HitHeavy" else "Hit", position)

		local stop = if heavy then Combat.HitstopHeavy else Combat.HitstopLight
		if attackerAnimator then
			attackerAnimator:hitstop(stop)
		end
		if victimAnimator then
			victimAnimator:hitstop(stop)
			if direction.Magnitude > 0.1 then
				victimAnimator:flinchFrom(-direction, if heavy then 1 else 0.6)
			end
		end
		if victimModel and payload.stagger == true and not payload.knocked and not payload.killed then
			playReaction(victimModel, direction, heavy)
		end
		if mine then
			CameraController.shake(if heavy then 0.32 else 0.13)
		end
	else
		burst(position, Color3.fromRGB(255, 140, 40), 6, 8, 0.8, FIRE, 0.5)
	end

	if damage > 0 and victimRoot then
		local text = if damage >= 10 then tostring(math.floor(damage + 0.5)) else string.format("%.1f", damage)
		local numberColor = if isTick then Color3.fromRGB(255, 150, 60) elseif auraAbsorbed then color else WHITE
		popupText(victimRoot.Position + Vector3.new(0, 2.5, 0), text, numberColor, if heavy then 26 else 19)
	end

	if payload.auraBroke and victimRoot then
		shatter(victimRoot.Position + Vector3.new(0, 0.5, 0), color, 26, 9, Enum.Material.ForceField)
		sphere(victimRoot.Position, color, 4, 12, 0.4, Enum.Material.ForceField)
		flashRig(victim, color, 0.6, 0)
		Audio.playAt("AuraBreak", victimRoot.Position)
		if victim == player.Character then
			popupText(victimRoot.Position + Vector3.new(0, 4, 0), "AURA BROKEN", color, 26, 3)
			CameraController.shake(0.45)
		end
	end

	if payload.knocked and victimModel then
		AnimationController.play(victimModel, "Common.KnockDown")
		if victimRoot then
			Audio.playOn("Knocked", victimRoot)
		end
		if victim == player.Character then
			CameraController.shake(0.5)
		end
	end
end

--[[ SHOTS & PROJECTILES ]]

local function muzzlePosition(rig: Instance?, fallback: Vector3): Vector3
	if rig then
		local weapon = rig:FindFirstChild("Weapon")
		local form = rig:GetAttribute("WeaponForm")
		if weapon and type(form) == "string" then
			for _, handleName in { "HandleRight", "HandleLeft" } do
				local handle = weapon:FindFirstChild(handleName)
				local muzzle = if handle then handle:FindFirstChild(`Muzzle_{form}`) else nil
				if muzzle and muzzle:IsA("Attachment") then
					return muzzle.WorldPosition
				end
			end
		end
	end
	return fallback
end

local function onShot(payload: { [string]: any })
	local rig: Instance? = payload.rig
	local from = muzzlePosition(rig, if typeof(payload.from) == "Vector3" then payload.from else Vector3.zero)
	local color = auraColor(rig)
	sphere(from, Color3.fromRGB(255, 220, 150), 0.6, 2.4, 0.08)
	if payload.kind == "Hitscan" and typeof(payload.to) == "Vector3" then
		beam(from, payload.to, Color3.fromRGB(255, 240, 220), 0.32, 0.16)
		beam(from, payload.to, color, 0.7, 0.22)
		burst(payload.to, Color3.fromRGB(255, 230, 190), 10, 20, 0.6, SPARKLE, 0.25)
		Audio.playAt("Sniper", from)
		CameraController.shakeAt(from, 0.18, 30)
	elseif payload.kind == "Pellets" and type(payload.ends) == "table" then
		for _, finish in payload.ends do
			if typeof(finish) == "Vector3" then
				beam(from, finish, Color3.fromRGB(255, 200, 120), 0.12, 0.1)
			end
		end
		burst(from, Color3.fromRGB(255, 160, 60), 14, 30, 0.9, FIRE, 0.2)
		Audio.playAt("Shotgun", from)
		CameraController.shakeAt(from, 0.15, 25)
	end
end

local function simulateProjectile(payload: { [string]: any })
	local rig: Instance? = payload.rig
	local origin: Vector3 = if typeof(payload.from) == "Vector3" then payload.from else Vector3.zero
	local velocity: Vector3 = if typeof(payload.velocity) == "Vector3" then payload.velocity else Vector3.zero
	local gravity: number = if type(payload.gravity) == "number" then payload.gravity else 0
	local bolt = payload.kind == "Bolt"
	local color = if bolt then Color3.fromRGB(255, 240, 120) else Color3.fromRGB(255, 110, 190)
	local body = fxPart(
		Vector3.one * (if bolt then 0.7 else 0.9),
		CFrame.new(origin),
		color,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.3, 0)
	a0.Parent = body
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.3, 0)
	a1.Parent = body
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = if bolt then 0.12 else 0.35
	trail.Color = ColorSequence.new(color)
	trail.LightEmission = 1
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = body
	if not bolt then
		Audio.playAt("Launcher", origin)
	else
		Audio.playAt("Lightning", origin)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if rig then { rig, folder } else { folder }
	local position = origin
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		local g = Vector3.new(0, -gravity, 0)
		local step = velocity * dt + g * (0.5 * dt * dt)
		local result = Workspace:Raycast(position, step, params)
		velocity += g * dt
		if result or elapsed > 3 then
			connection:Disconnect()
			body:Destroy()
			return
		end
		position += step
		body.CFrame = CFrame.new(position)
	end)
end

local function onExplosion(payload: { [string]: any })
	local position: Vector3 = if typeof(payload.position) == "Vector3" then payload.position else Vector3.zero
	local radius: number = if type(payload.radius) == "number" then payload.radius else 10
	sphere(position, Color3.fromRGB(255, 150, 200), 2, radius * 1.6, 0.35)
	sphere(position, Color3.fromRGB(255, 240, 220), 1, radius * 0.9, 0.18)
	shockwave(position - Vector3.new(0, 1, 0), Color3.fromRGB(255, 120, 180), 2, radius * 2.4, 0.45)
	burst(position, Color3.fromRGB(80, 60, 70), 26, 18, 3, SMOKE, 1.2)
	burst(position, Color3.fromRGB(255, 170, 80), 30, 40, 1.4, FIRE, 0.45)
	Audio.playAt("Explosion", position)
	CameraController.shakeAt(position, 0.55, radius * 4)
end

--[[ NAMED EFFECTS ]]

local function attachEmitter(rig: Instance?, partName: string, duration: number, props: { [string]: any })
	local part = partOf(rig, partName)
	if part == nil then
		return
	end
	local emitter = particles(part, props)
	emitter.Enabled = true
	task.delay(duration, function()
		emitter.Enabled = false
		Debris:AddItem(emitter, 1.5)
	end)
end

local function glyphDisc(position: Vector3, color: Color3, radius: number, duration: number)
	local frame = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local disc = fxPart(Vector3.new(0.12, 2, 2), frame, color, Enum.Material.Neon, Enum.PartType.Cylinder)
	disc.Transparency = 0.45
	tween(disc, 0.25, { Size = Vector3.new(0.12, radius * 2, radius * 2) }, Enum.EasingStyle.Back)
	local spokes = {}
	for i = 0, 5 do
		local spoke = fxPart(
			Vector3.new(radius * 1.9, 0.15, 0.35),
			CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, i * math.pi / 3, 0),
			color
		)
		spoke.Transparency = 0.3
		table.insert(spokes, spoke)
	end
	local inner = fxPart(Vector3.new(0.14, radius, radius), frame, WHITE, Enum.Material.Neon, Enum.PartType.Cylinder)
	inner.Transparency = 0.6
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - start
		if t > duration then
			connection:Disconnect()
			for _, part in { disc, inner, table.unpack(spokes) } do
				fadeAway(part, 0.3)
			end
			return
		end
		for i, spoke in spokes do
			spoke.CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0))
				* CFrame.Angles(0, t * 0.8 + (i - 1) * math.pi / 3, 0)
		end
	end)
end

local function frostSpire(origin: Vector3, direction: Vector3, range: number)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	local dir = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	task.spawn(function()
		for step = 1, math.floor(range / 3) do
			local point = origin + dir * (step * 3)
			local ground = Workspace:Raycast(point + Vector3.new(0, 6, 0), Vector3.new(0, -14, 0), params)
			local base = if ground then ground.Position else point - Vector3.new(0, 3, 0)
			for _ = 1, 2 do
				local height = random:NextNumber(3, 6.5)
				local spike = Instance.new("WedgePart")
				spike.Anchored = true
				spike.CanCollide = false
				spike.CanQuery = false
				spike.CastShadow = false
				spike.Material = Enum.Material.Glass
				spike.Color = Color3.fromRGB(170, 225, 255)
				spike.Transparency = 0.15
				spike.Size = Vector3.new(random:NextNumber(0.8, 1.6), height, random:NextNumber(1, 2))
				local tilt = CFrame.Angles(
					random:NextNumber(-0.4, 0.4),
					random:NextNumber(0, 6.28),
					random:NextNumber(-0.4, 0.4)
				)
				local goal = CFrame.new(
					base + Vector3.new(random:NextNumber(-1.2, 1.2), height / 2 - 0.3, random:NextNumber(-1.2, 1.2))
				) * tilt
				spike.CFrame = goal - Vector3.new(0, height, 0)
				spike.Parent = folder
				tween(spike, 0.12, { CFrame = goal }, Enum.EasingStyle.Back)
				task.delay(1.1 + random:NextNumber(0, 0.3), function()
					fadeAway(spike, 0.35, { Size = spike.Size * 0.6 })
				end)
			end
			burst(base + Vector3.new(0, 1, 0), Color3.fromRGB(200, 240, 255), 4, 10, 0.8, SPARKLE, 0.4)
			task.wait(0.035)
		end
	end)
	Audio.playAt("Ice", origin)
end

local function fireArc(origin: Vector3, direction: Vector3, range: number, angle: number)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	local dir = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	for i = -3, 3 do
		local rotated = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(angle / 2 * i / 3)) * dir
		local length = range * random:NextNumber(0.75, 1)
		local tongue = fxPart(
			Vector3.new(1.2, 1.2, 2),
			CFrame.lookAt(origin, origin + rotated) * CFrame.new(0, 0, -1),
			Color3.fromRGB(255, 130 + i * 6, 40)
		)
		tongue.Transparency = 0.15
		fadeAway(tongue, 0.3, {
			CFrame = CFrame.lookAt(origin, origin + rotated) * CFrame.new(0, 0, -length / 2),
			Size = Vector3.new(4, 3, length),
		})
		burst(origin + rotated * length * 0.7, Color3.fromRGB(255, 150, 50), 8, 10, 2.2, FIRE, 0.6)
	end
	local flashPart = fxPart(Vector3.one, CFrame.new(origin + dir * 4), Color3.fromRGB(255, 140, 40))
	flashPart.Transparency = 1
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 140, 40)
	glow.Range = 30
	glow.Brightness = 4
	glow.Parent = flashPart
	tween(glow, 0.5, { Brightness = 0 })
	Debris:AddItem(flashPart, 0.55)
	Audio.playAt("Fire", origin)
end

local function lightningChain(from: Vector3, to: Vector3)
	local color = Color3.fromRGB(255, 240, 130)
	local segments = 7
	local previous = from
	for i = 1, segments do
		local t = i / segments
		local point = from:Lerp(to, t)
		if i < segments then
			point += random:NextUnitVector() * 1.2
		end
		beam(previous, point, color, 0.3, 0.25)
		previous = point
	end
	burst(to, color, 12, 20, 0.6, SPARKLE, 0.3)
end

local function dissolve(rig: Instance?)
	if rig == nil then
		return
	end
	local torso = partOf(rig, "Torso")
	if torso then
		local emitter = particles(torso, {
			Texture = SMOKE,
			Color = ColorSequence.new(Color3.fromRGB(10, 8, 12)),
			Size = NumberSequence.new(1.5, 3.5),
			Transparency = NumberSequence.new(0.2, 1),
			Lifetime = NumberRange.new(1, 1.6),
			Speed = NumberRange.new(2, 6),
			Acceleration = Vector3.new(0, 6, 0),
			SpreadAngle = Vector2.new(60, 60),
			LightEmission = 0,
			Rate = 40,
		})
		emitter.Enabled = true
		task.delay(1.2, function()
			emitter.Enabled = false
		end)
	end
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Transparency < 1 then
			tween(descendant, 1.5, { Transparency = 1, Color = Color3.fromRGB(8, 6, 10) }, Enum.EasingStyle.Sine)
		elseif descendant:IsA("Decal") then
			tween(descendant, 1, { Transparency = 1 })
		end
	end
	local root = rootOf(rig)
	if root then
		Audio.playOn("GrimmDeath", root)
	end
end

local function onEffect(payload: { [string]: any })
	local name = payload.name
	local rig: Instance? = payload.rig
	local root = rootOf(rig)

	if name == "PetalBurst" and root then
		local color = auraColor(rig)
		local duration = if type(payload.duration) == "number" then payload.duration else 0.4
		attachEmitter(rig, "Torso", duration + 0.1, {
			Texture = SPARKLE,
			Color = ColorSequence.new(color, Color3.fromRGB(255, 220, 230)),
			Size = NumberSequence.new(0.5, 0.2),
			Transparency = NumberSequence.new(0, 1),
			Lifetime = NumberRange.new(0.6, 1.2),
			Speed = NumberRange.new(1, 4),
			SpreadAngle = Vector2.new(180, 180),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-300, 300),
			Drag = 2,
			Acceleration = Vector3.new(0, -4, 0),
			Rate = 140,
		})
		burst(root.Position, color, 30, 26, 0.7, SPARKLE, 0.8)
		Audio.playOn("Whoosh", root)
	elseif name == "ShadowStep" then
		local position: Vector3 = if typeof(payload.position) == "Vector3"
			then payload.position
			elseif root then root.Position
			else Vector3.zero
		burst(position, Color3.fromRGB(30, 20, 46), 28, 10, 2.4, SMOKE, 0.9)
		Audio.playAt("Dodge", position)
	elseif name == "CloneFade" and rig then
		for _, descendant in rig:GetDescendants() do
			if descendant:IsA("BasePart") then
				tween(descendant, 0.35, { Transparency = 1 })
			elseif descendant:IsA("Highlight") then
				tween(descendant, 0.35, { FillTransparency = 1, OutlineTransparency = 1 })
			end
		end
		if root then
			burst(root.Position, Color3.fromRGB(40, 24, 60), 20, 8, 2, SMOKE, 0.8)
		end
	elseif name == "Ignite" and root then
		local duration = if type(payload.duration) == "number" then payload.duration else 4
		for _, part in { "Right Arm", "Left Arm", "Torso" } do
			attachEmitter(rig, part, duration, {
				Texture = FIRE,
				Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 80, 20)),
				Size = NumberSequence.new(1.2, 0.2),
				Transparency = NumberSequence.new(0.2, 1),
				Lifetime = NumberRange.new(0.3, 0.6),
				Speed = NumberRange.new(2, 5),
				Acceleration = Vector3.new(0, 10, 0),
				LightEmission = 1,
				Rate = 30,
			})
		end
		flashRig(rig, Color3.fromRGB(255, 170, 40), 0.8, 0.2)
		sphere(root.Position, Color3.fromRGB(255, 160, 40), 2, 12, 0.4)
		Audio.playOn("Fire", root)
	elseif name == "Magnetize" and root then
		local color = Color3.fromRGB(226, 186, 70)
		local target = rootOf(payload.target)
		if target then
			lightningChain(root.Position, target.Position)
			shockwave(target.Position, color, 1, 8, 0.3)
		else
			local direction: Vector3 = if typeof(payload.direction) == "Vector3"
				then payload.direction
				else root.CFrame.LookVector
			shockwave(root.Position + direction * 4, color, 2, 14, 0.4, direction)
		end
		Audio.playOn("Semblance", root)
	elseif name == "Glyph" then
		local position: Vector3 = if typeof(payload.position) == "Vector3"
			then payload.position
			elseif root then root.Position
			else Vector3.zero
		local def = Semblances.get("Glyph")
		local color = if def then def.color else WHITE
		glyphDisc(
			position,
			color,
			if type(payload.radius) == "number" then payload.radius else 10,
			if type(payload.duration) == "number" then payload.duration else 4
		)
		shockwave(position + Vector3.new(0, 0.3, 0), WHITE, 2, 18, 0.35)
		Audio.playAt("Semblance", position)
	elseif name == "Harden" and root then
		local duration = if type(payload.duration) == "number" then payload.duration else 4
		local highlight = Instance.new("Highlight")
		highlight.FillColor = Color3.fromRGB(150, 140, 120)
		highlight.FillTransparency = 0.55
		highlight.OutlineColor = Color3.fromRGB(230, 220, 200)
		highlight.OutlineTransparency = 0.3
		highlight.Adornee = rig
		highlight.Parent = folder
		task.delay(duration, function()
			tween(highlight, 0.3, { FillTransparency = 1, OutlineTransparency = 1 })
			Debris:AddItem(highlight, 0.35)
		end)
		burst(root.Position - Vector3.new(0, 2.5, 0), Color3.fromRGB(160, 150, 130), 24, 14, 1.4, SMOKE, 0.7)
		Audio.playOn("GuardBreak", root, 0.6)
	elseif name == "FireArc" then
		fireArc(
			if typeof(payload.origin) == "Vector3" then payload.origin else Vector3.zero,
			if typeof(payload.direction) == "Vector3" then payload.direction else Vector3.new(0, 0, -1),
			if type(payload.range) == "number" then payload.range else 18,
			if type(payload.angle) == "number" then payload.angle else 70
		)
	elseif name == "FrostSpire" then
		frostSpire(
			if typeof(payload.origin) == "Vector3" then payload.origin else Vector3.zero,
			if typeof(payload.direction) == "Vector3" then payload.direction else Vector3.new(0, 0, -1),
			if type(payload.range) == "number" then payload.range else 30
		)
	elseif name == "BoltImpact" and typeof(payload.position) == "Vector3" then
		burst(payload.position, Color3.fromRGB(255, 240, 130), 18, 26, 0.7, SPARKLE, 0.3)
		sphere(payload.position, Color3.fromRGB(255, 250, 200), 1, 5, 0.15)
	elseif name == "Chain" and typeof(payload.from) == "Vector3" and typeof(payload.to) == "Vector3" then
		lightningChain(payload.from, payload.to)
	elseif name == "GravityBurst" then
		local position: Vector3 = if typeof(payload.position) == "Vector3" then payload.position else Vector3.zero
		local radius: number = if type(payload.radius) == "number" then payload.radius else 14
		local def = Dust.get("Gravity")
		local color = if def then def.color else Color3.fromRGB(170, 110, 255)
		sphere(position, color, 2, radius * 2, 0.4, Enum.Material.ForceField)
		shockwave(position - Vector3.new(0, 2.5, 0), color, 2, radius * 2.2, 0.45)
		burst(position, color, 30, 30, 1, SPARKLE, 0.6)
		Audio.playAt("Gravity", position)
		CameraController.shakeAt(position, 0.3, 40)
	elseif name == "GrimmTell" and rig then
		local head = partOf(rig, "Head")
		if head then
			local glint = fxPart(
				Vector3.one * 0.4,
				head.CFrame * CFrame.new(0, 0.2, -0.8),
				GRIMM_RED,
				Enum.Material.Neon,
				Enum.PartType.Ball
			)
			fadeAway(glint, 0.35, { Size = Vector3.one * 3 })
		end
	elseif name == "GrimmDissolve" then
		dissolve(rig)
	elseif name == "LevelUp" and root then
		local pillar = fxPart(
			Vector3.new(40, 6, 6),
			CFrame.new(root.Position + Vector3.new(0, 17, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(255, 220, 120),
			Enum.Material.Neon,
			Enum.PartType.Cylinder
		)
		pillar.Transparency = 0.4
		fadeAway(pillar, 1.2, { Size = Vector3.new(40, 0.5, 0.5) })
		burst(root.Position, Color3.fromRGB(255, 220, 120), 40, 20, 0.8, SPARKLE, 1.2)
		Audio.playOn("LevelUp", root)
	end
end

--[[ MARKERS ]]

local function onMarker(rig: Model, _clipId: string, name: string, data: any)
	local root = rootOf(rig)
	if root == nil then
		return
	end
	if name == "Glint" then
		local weapon = rig:FindFirstChild("Weapon")
		local handle = if weapon then weapon:FindFirstChild("HandleRight") else nil
		local anchor = if handle and handle:IsA("BasePart")
			then handle.Position
			else root.Position + Vector3.new(0, 2, 0)
		local color = if data == "Red" then Color3.fromRGB(255, 60, 60) else WHITE
		local star = fxPart(Vector3.one * 0.5, CFrame.new(anchor), color, Enum.Material.Neon, Enum.PartType.Ball)
		fadeAway(star, 0.3, { Size = Vector3.one * 4 })
		burst(anchor, color, 10, 12, 0.6, SPARKLE, 0.3)
		Audio.playOn("UIConfirm", root, 0.6)
	elseif name == "Swing" then
		Audio.playOn(if data == "Heavy" then "SwingHeavy" else "Swing", root)
	elseif name == "Step" then
		burst(root.Position - Vector3.new(0, 2.8, 0), Color3.fromRGB(170, 160, 150), 6, 6, 1.2, SMOKE, 0.5)
	elseif name == "Shake" and rig == player.Character then
		CameraController.shake(if type(data) == "number" then data else 0.2)
	elseif name == "Sound" and type(data) == "string" then
		Audio.playOn(data, root)
	end
end

function EffectsController.init()
	local existing = Workspace:FindFirstChild("ClientEffects")
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = "ClientEffects"
		folder.Parent = Workspace
	end
end

function EffectsController.start()
	Net.event("Effects").OnClientEvent:Connect(function(kind: any, payload: any)
		if type(payload) ~= "table" then
			return
		end
		if kind == "Hit" then
			onHit(payload)
		elseif kind == "Shot" then
			onShot(payload)
		elseif kind == "Projectile" then
			simulateProjectile(payload)
		elseif kind == "Explosion" then
			onExplosion(payload)
		elseif kind == "Effect" then
			onEffect(payload)
		end
	end)
	AnimationController.Marker:Connect(onMarker)
end

return EffectsController
