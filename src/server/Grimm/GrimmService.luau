--!strict
--[[
	GrimmService: spawns Creatures of Grimm in their zones and drives their behaviour.

	Grimm are R6 rigs (so the same animation system brings them to life) dressed in bone armour.
	Their attacks go through CombatService.performMove exactly like a Huntsman's, so every swipe
	has a readable wind-up and can be dodged, blocked or parried. Their eyes flare right before an
	attack lands. Knocked Huntsmen left alone near Grimm get mauled.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local ClipLibrary = require(Shared.Animation.ClipLibrary)
local Combat = require(Shared.Config.Combat)
local Grimm = require(Shared.Config.Grimm)
local World = require(Shared.Config.World)

local CombatService = require(script.Parent.Parent.Combat.CombatService)
local RigBuilder = require(script.Parent.Parent.Characters.RigBuilder)

type Combatant = CombatService.Combatant

type Brain = {
	def: Grimm.GrimmDef,
	zone: World.SpawnZone,
	combatant: Combatant,
	humanoid: Humanoid,
	home: Vector3,
	target: Combatant?,
	nextAttack: number,
	nextThink: number,
	wander: Vector3?,
	nextWander: number,
	strafe: number,
	returning: boolean,
	lastPosition: Vector3,
	stuckSince: number,
}

local GrimmService = {}

local brains: { [Model]: Brain } = {}
local population: { [World.SpawnZone]: number } = {}
local random = Random.new()
local folder: Folder

local THINK_INTERVAL = 0.12

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function decorate(model: Model, def: Grimm.GrimmDef)
	local function piece(
		parentName: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		neon: boolean?,
		wedge: boolean?
	)
		local parent = model:FindFirstChild(parentName)
		if not (parent and parent:IsA("BasePart")) then
			return
		end
		local part: BasePart = if wedge then Instance.new("WedgePart") else Instance.new("Part")
		part.Size = size
		part.Color = color
		part.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Massless = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CFrame = parent.CFrame * offset
		local weld = Instance.new("Weld")
		weld.Part0 = parent
		weld.Part1 = part
		weld.C0 = offset
		weld.Parent = part
		part.Parent = model
	end

	local bone, eye = def.boneColor, def.eyeColor
	-- Bone mask with glowing red eyes and markings.
	piece("Head", Vector3.new(1.35, 0.95, 0.3), CFrame.new(0, 0.05, -0.55), bone)
	piece(
		"Head",
		Vector3.new(0.3, 0.1, 0.06),
		CFrame.new(-0.3, 0.12, -0.72) * CFrame.Angles(0, 0, math.rad(-12)),
		eye,
		true
	)
	piece(
		"Head",
		Vector3.new(0.3, 0.1, 0.06),
		CFrame.new(0.3, 0.12, -0.72) * CFrame.Angles(0, 0, math.rad(12)),
		eye,
		true
	)
	piece("Head", Vector3.new(0.08, 0.5, 0.05), CFrame.new(-0.42, 0.25, -0.72), eye, true)
	piece("Head", Vector3.new(0.08, 0.5, 0.05), CFrame.new(0.42, 0.25, -0.72), eye, true)
	piece("Head", Vector3.new(0.7, 0.4, 0.7), CFrame.new(0, -0.25, -0.8), def.bodyColor)
	piece("Head", Vector3.new(0.6, 0.12, 0.4), CFrame.new(0, -0.42, -0.95), bone)
	-- Ears / horns.
	for _, side in { -1, 1 } do
		piece(
			"Head",
			Vector3.new(0.18, 0.6, 0.4),
			CFrame.new(0.42 * side, 0.7, 0.05) * CFrame.Angles(math.rad(-15), 0, math.rad(-12 * side)),
			bone,
			false,
			true
		)
	end
	-- Spine spikes.
	for index = 0, 3 do
		piece(
			"Torso",
			Vector3.new(0.25, 0.7 - index * 0.08, 0.55),
			CFrame.new(0, 0.8 - index * 0.5, 0.65) * CFrame.Angles(math.rad(-30), 0, 0),
			bone,
			false,
			true
		)
	end
	-- Shoulder and forearm plates, claws.
	for _, side in { "Right", "Left" } do
		local sign = if side == "Right" then 1 else -1
		piece(`{side} Arm`, Vector3.new(1.15, 0.5, 1.1), CFrame.new(0.05 * sign, 0.75, 0), bone)
		piece(
			`{side} Arm`,
			Vector3.new(0.3, 0.7, 0.4),
			CFrame.new(0.45 * sign, 0.95, 0) * CFrame.Angles(0, 0, math.rad(-25 * sign)),
			bone,
			false,
			true
		)
		for claw = -1, 1 do
			piece(
				`{side} Arm`,
				Vector3.new(0.12, 0.7, 0.12),
				CFrame.new(claw * 0.3, -1.25, -0.2) * CFrame.Angles(math.rad(-25), 0, 0),
				bone
			)
		end
		piece(`{side} Leg`, Vector3.new(1.1, 0.4, 1.1), CFrame.new(0, 0.3, -0.05), bone)
	end
	if def.id == "Ursa" then
		for index = 0, 2 do
			piece("Torso", Vector3.new(1.6 - index * 0.3, 0.35, 0.5), CFrame.new(0, 0.6 - index * 0.55, 0.62), bone)
		end
	end
end

local function groundAt(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	local result = Workspace:Raycast(position + Vector3.new(0, 120, 0), Vector3.new(0, -260, 0), params)
	return if result then result.Position else position
end

local function spawnOne(zone: World.SpawnZone)
	local def = Grimm.get(zone.grimm)
	if def == nil then
		return
	end
	local model = RigBuilder.build(def.name, {
		head = def.bodyColor,
		torso = def.bodyColor,
		arms = def.bodyColor,
		legs = def.bodyColor,
	}, false)
	decorate(model, def)
	model:ScaleTo(def.scale)

	local angle = random:NextNumber() * math.pi * 2
	local distance = random:NextNumber() * zone.radius
	local spot = groundAt(zone.center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance))
	model:PivotTo(
		CFrame.new(spot + Vector3.new(0, 3 * def.scale + 0.5, 0)) * CFrame.Angles(0, random:NextNumber() * 6.28, 0)
	)

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.MaxHealth = def.health
	humanoid.Health = def.health
	humanoid.WalkSpeed = def.walkSpeed
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	model:SetAttribute("Gait", def.gait)
	model:SetAttribute("IsGrimm", true)
	model:SetAttribute("GrimmType", def.id)
	model:SetAttribute("DisplayName", def.name)
	model.Parent = folder

	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	CollectionService:AddTag(model, "Rig")

	local combatant = CombatService.register(model, "Grimm")
	if combatant == nil then
		model:Destroy()
		return
	end
	combatant.grimm = def
	combatant.stats.maxHealth = def.health
	combatant.stats.maxPosture = 100
	combatant:sync()

	population[zone] = (population[zone] or 0) + 1
	brains[model] = {
		def = def,
		zone = zone,
		combatant = combatant,
		humanoid = humanoid,
		home = spot,
		target = nil,
		nextAttack = os.clock() + 1,
		nextThink = os.clock() + random:NextNumber() * THINK_INTERVAL,
		wander = nil,
		nextWander = os.clock() + random:NextNumber(1, 4),
		strafe = if random:NextNumber() < 0.5 then -1 else 1,
		returning = false,
		lastPosition = spot,
		stuckSince = 0,
	}
end

local function validTarget(brain: Brain, target: Combatant?): boolean
	if target == nil or not target:isAlive() or not CombatService.hostile(brain.combatant, target) then
		return false
	end
	local distance = (target.root.Position - brain.combatant.root.Position).Magnitude
	return distance <= brain.def.aggroRange * 1.6
		and (target.root.Position - brain.home).Magnitude <= brain.def.leashRange
end

local function findTarget(brain: Brain): Combatant?
	local root = brain.combatant.root
	local best: Combatant? = nil
	local bestScore = math.huge
	for _, other in CombatService.all() do
		if other.kind ~= "Grimm" and other:isAlive() and CombatService.hostile(brain.combatant, other) then
			local distance = (other.root.Position - root.Position).Magnitude
			if
				distance <= brain.def.aggroRange
				and (other.root.Position - brain.home).Magnitude <= brain.def.leashRange
			then
				-- Shadow clones are irresistible bait.
				local score = if other.kind == "Clone" then distance * 0.3 else distance
				if score < bestScore then
					best = other
					bestScore = score
				end
			end
		end
	end
	return best
end

local function pickMove(def: Grimm.GrimmDef, distance: number): Grimm.GrimmMove?
	local total = 0
	for _, move in def.moves do
		if distance <= move.range * def.scale then
			total += move.weight
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = random:NextNumber() * total
	for _, move in def.moves do
		if distance <= move.range * def.scale then
			roll -= move.weight
			if roll <= 0 then
				return move
			end
		end
	end
	return nil
end

local function face(root: BasePart, point: Vector3)
	local position = root.Position
	local flatPoint = Vector3.new(point.X, position.Y, point.Z)
	if (flatPoint - position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(position, flatPoint)
	end
end

local function think(brain: Brain, now: number)
	local c = brain.combatant
	local humanoid = brain.humanoid
	local root = c.root
	local def = brain.def

	humanoid.WalkSpeed = def.chaseSpeed * c:slowFactor()

	if c:isIncapacitated() or c.state == "Attacking" or c.state == "Casting" then
		humanoid:Move(Vector3.zero)
		return
	end

	if (root.Position - brain.home).Magnitude > def.leashRange then
		brain.returning = true
		brain.target = nil
	end
	if brain.returning then
		humanoid.WalkSpeed = def.walkSpeed * 1.5
		humanoid:MoveTo(brain.home)
		if (flat(root.Position - brain.home)).Magnitude < 8 then
			brain.returning = false
			c:heal(def.health, 0)
		end
		return
	end

	if not validTarget(brain, brain.target) then
		brain.target = findTarget(brain)
	end
	local target = brain.target
	if target == nil then
		-- Prowl around the den.
		humanoid.WalkSpeed = def.walkSpeed * c:slowFactor()
		if brain.wander == nil or now >= brain.nextWander then
			local angle = random:NextNumber() * math.pi * 2
			local radius = random:NextNumber() * brain.zone.radius
			brain.wander = brain.zone.center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			brain.nextWander = now + random:NextNumber(4, 9)
		end
		local wander = brain.wander
		if wander then
			humanoid:MoveTo(wander)
		end
		return
	end

	local offset = target.root.Position - root.Position
	local distance = flat(offset).Magnitude

	-- A knocked Huntsman with nobody around gets mauled.
	if target.state == "Knocked" then
		if distance <= 6 * def.scale then
			humanoid:Move(Vector3.zero)
			if target.grimmNearSince == 0 then
				target.grimmNearSince = now
			elseif now - target.grimmNearSince >= Combat.GrimmExecuteDelay and c:canAct() then
				face(root, target.root.Position)
				CombatService.performMove(c, def.moves[1].move, { kind = "Grimm" })
				task.delay(0.35, function()
					if target.state == "Knocked" and c:isAlive() then
						CombatService.kill(target, c)
					end
				end)
				brain.target = nil
			end
		else
			target.grimmNearSince = 0
			humanoid:MoveTo(target.root.Position)
		end
		return
	end

	if c:canAct() and now >= brain.nextAttack then
		local move = pickMove(def, distance)
		if move then
			face(root, target.root.Position)
			humanoid:Move(Vector3.zero)
			local look = flat(offset)
			CombatService.broadcast("Effect", { name = "GrimmTell", rig = c.model })
			CombatService.performMove(
				c,
				move.move,
				{ kind = "Grimm", look = if look.Magnitude > 0.01 then look.Unit else nil }
			)
			local duration = ClipLibrary.duration(move.move.clip)
			brain.nextAttack = now + duration + random:NextNumber(def.attackCooldown[1], def.attackCooldown[2])
			return
		end
	end

	local closeRange = 6 * def.scale
	if distance > closeRange then
		humanoid:MoveTo(target.root.Position - flat(offset).Unit * (closeRange * 0.6))
		-- Straight-line chasing can snag on trunks and rocks: hop when we stop making progress.
		if (flat(root.Position - brain.lastPosition)).Magnitude < 0.6 then
			if brain.stuckSince == 0 then
				brain.stuckSince = now
			elseif now - brain.stuckSince > 1.2 then
				humanoid.Jump = true
				brain.stuckSince = 0
			end
		else
			brain.stuckSince = 0
		end
		brain.lastPosition = root.Position
	else
		-- Circle the prey while waiting for an opening.
		local side = Vector3.new(-offset.Z, 0, offset.X)
		if side.Magnitude > 0.01 then
			humanoid.WalkSpeed = def.walkSpeed
			humanoid:MoveTo(root.Position + side.Unit * 6 * brain.strafe - flat(offset).Unit * 1.5)
		end
		if random:NextNumber() < 0.02 then
			brain.strafe = -brain.strafe
		end
	end
end

local function onKilled(victim: Combatant, _killer: Combatant?)
	local brain = brains[victim.model]
	if brain == nil then
		return
	end
	brains[victim.model] = nil
	population[brain.zone] = math.max(0, (population[brain.zone] or 1) - 1)
	CombatService.broadcast("Effect", { name = "GrimmDissolve", rig = victim.model })
	task.delay(1.8, function()
		victim.model:Destroy()
	end)
	task.delay(brain.zone.respawn, function()
		if (population[brain.zone] or 0) < brain.zone.count then
			spawnOne(brain.zone)
		end
	end)
end

function GrimmService.init()
	folder = Instance.new("Folder")
	folder.Name = "Grimm"
	folder.Parent = Workspace
end

function GrimmService.start()
	CombatService.Killed:Connect(onKilled)
	for _, zone in World.GrimmSpawns do
		population[zone] = 0
		for _ = 1, zone.count do
			spawnOne(zone)
		end
	end
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for model, brain in brains do
			if model.Parent == nil then
				brains[model] = nil
			elseif now >= brain.nextThink then
				brain.nextThink = now + THINK_INTERVAL
				local ok, err = pcall(function()
					think(brain, now)
					return nil
				end)
				if not ok then
					warn(`[Grimm] AI error: {err}`)
				end
			end
		end
	end)
end

return GrimmService
