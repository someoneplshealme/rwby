--!strict
--[[
	CharacterAnimator: animates one R6 rig (player or Grimm) on this client.

	Every frame it runs procedural locomotion from the rig's real velocity, layers the weapon stance,
	replicated state loops (block / aim / stunned / knocked), one-shot action clips and additive
	springs through the shared Composer, then writes Motor6D.Transform in PreSimulation — after
	Roblox's own Animator step, so this system has the final say over the pose.

	Server state reaches it through attributes on the rig model:
	  Stance (string)      stance id, e.g. "Scythe.Scythe"
	  Gait (string)        locomotion style ("Huntsman", "Feral", "Heavy")
	  WeaponModel / WeaponForm  for two-handed reach
	  Blocking, Aiming, Stunned, GuardBroken, Knocked (booleans)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Animation = ReplicatedStorage.Shared.Animation
local Clip = require(Animation.Clip)
local ClipLibrary = require(Animation.ClipLibrary)
local Composer = require(Animation.Composer)
local Joints = require(Animation.Joints)
local Locomotion = require(Animation.Locomotion)
local Pose = require(Animation.Pose)
local Spring = require(Animation.Spring)
local WeaponModels = require(ReplicatedStorage.Shared.Config.WeaponModels)

type Pose = Joints.Pose
type Layer = Composer.Layer

type MotorBinding = {
	motor: Motor6D,
	r0: CFrame,
	r0Inv: CFrame,
	parentSpace: boolean,
}

export type Action = {
	id: string,
	clip: Clip.Clip,
	time: number,
	speed: number,
	weight: number,
	fadeInRate: number,
	fadeOutRate: number,
	stopping: boolean,
	tag: any?,
	layer: Layer,
}

type StateLayer = {
	attribute: string,
	clipName: string, -- looked up as "<stance prefix>.<clipName>" first, then "Common.<clipName>"
	fadeIn: number,
	fadeOut: number,
	weight: number,
	time: number,
	clip: Clip.Clip?,
	layer: Layer,
}

export type MarkerCallback = (animator: CharacterAnimator, action: Action, marker: Clip.MarkerDef) -> ()

-- Lowest priority first; later states override earlier ones.
local STATE_DEFS = {
	{ attribute = "Aiming", clip = "Aim", fadeIn = 0.12, fadeOut = 0.2 },
	{ attribute = "Blocking", clip = "Block", fadeIn = 0.06, fadeOut = 0.14 },
	{ attribute = "Stunned", clip = "Stunned", fadeIn = 0.08, fadeOut = 0.25 },
	{ attribute = "GuardBroken", clip = "GuardBroken", fadeIn = 0.06, fadeOut = 0.3 },
	{ attribute = "Knocked", clip = "Knocked", fadeIn = 0.3, fadeOut = 0.45 },
}

local HITSTOP_SCALE = 0.04
local IDENTITY = CFrame.identity

local CharacterAnimator = {}
CharacterAnimator.__index = CharacterAnimator

export type CharacterAnimator = typeof(setmetatable(
	{} :: {
		model: Model,
		root: BasePart,
		humanoid: Humanoid?,
		motors: { [string]: MotorBinding },
		loco: Locomotion.State,
		pose: Pose,
		actions: { Action },
		actionLayers: { Layer },
		states: { StateLayer },
		stateLayers: { Layer },
		additive: Pose,
		flinch: Spring.Spring,
		landing: Spring.Spring,
		recoilSpring: Spring.Spring,
		hitstopUntil: number,
		wasGrounded: boolean,
		fallSpeed: number,
		hipHeight: number,
		rayParams: RaycastParams,
		groundedCache: boolean,
		groundCheckTimer: number,
		lodAccumulator: number,
		stanceId: string?,
		stance: ClipLibrary.StanceDef?,
		stancePrefix: string,
		twoHand: Composer.TwoHand?,
		destroyed: boolean,
		connections: { RBXScriptConnection },
		onMarker: MarkerCallback?,
		overrides: { [string]: { value: boolean, untilTime: number } },
		cape: Motor6D?,
		cape2: Motor6D?,
		capeSpring: Spring.Spring,
		capeTime: number,
	},
	CharacterAnimator
))

local function findMotor(model: Model, joint: string): Motor6D?
	local rig = Joints.Rig[joint]
	local container = model:FindFirstChild(rig.container)
	if container == nil then
		return nil
	end
	local motor = container:FindFirstChild(rig.motor)
	if motor and motor:IsA("Motor6D") then
		return motor
	end
	return nil
end

function CharacterAnimator.new(model: Model, root: BasePart): CharacterAnimator
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { model }
	rayParams.IgnoreWater = true

	local self = setmetatable({
		model = model,
		root = root,
		humanoid = model:FindFirstChildOfClass("Humanoid"),
		motors = {},
		loco = Locomotion.newState(),
		pose = {},
		actions = {},
		actionLayers = {},
		states = {},
		stateLayers = {},
		additive = {},
		flinch = Spring.new(260, 15),
		landing = Spring.new(220, 18),
		recoilSpring = Spring.new(320, 20),
		hitstopUntil = 0,
		wasGrounded = true,
		fallSpeed = 0,
		hipHeight = 3,
		rayParams = rayParams,
		groundedCache = true,
		groundCheckTimer = 0,
		lodAccumulator = 0,
		stanceId = nil,
		stance = nil,
		stancePrefix = "Common",
		twoHand = nil,
		destroyed = false,
		connections = {},
		onMarker = nil,
		overrides = {},
		cape = nil,
		cape2 = nil,
		capeSpring = Spring.new(90, 9),
		capeTime = 0,
	}, CharacterAnimator)

	for _, def in STATE_DEFS do
		local state: StateLayer = {
			attribute = def.attribute,
			clipName = def.clip,
			fadeIn = def.fadeIn,
			fadeOut = def.fadeOut,
			weight = 0,
			time = 0,
			clip = nil,
			layer = { clip = nil :: any, time = 0, weight = 0 },
		}
		table.insert(self.states, state)
	end

	self:bind()
	table.insert(
		self.connections,
		model.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("Motor6D") then
				self:bind()
			end
		end)
	)
	table.insert(
		self.connections,
		model.DescendantRemoving:Connect(function(descendant)
			if descendant:IsA("Motor6D") then
				task.defer(function()
					if not self.destroyed then
						self:bind()
					end
				end)
			end
		end)
	)
	return self
end

-- (Re)discovers the Motor6Ds for every joint. Grips come and go as weapons are equipped.
function CharacterAnimator.bind(self: CharacterAnimator)
	table.clear(self.motors)
	for _, joint in Joints.Names do
		local motor = findMotor(self.model, joint)
		if motor and motor.Parent then
			local r0 = motor.C0.Rotation
			self.motors[joint] = {
				motor = motor,
				r0 = r0,
				r0Inv = r0:Inverse(),
				parentSpace = Joints.ParentSpace[joint] == true,
			}
		end
	end
	local torso = self.model:FindFirstChild("Torso")
	local cape = if torso then torso:FindFirstChild("CapeJoint") else nil
	self.cape = if cape and cape:IsA("Motor6D") then cape else nil
	local upper = self.model:FindFirstChild("CapeUpper")
	local cape2 = if upper then upper:FindFirstChild("CapeJoint2") else nil
	self.cape2 = if cape2 and cape2:IsA("Motor6D") then cape2 else nil

	-- Hip height: HumanoidRootPart centre to the bottom of the legs (handles scaled Grimm rigs).
	local leg = self.model:FindFirstChild("Right Leg")
	if leg and leg:IsA("BasePart") then
		local offset = self.root.CFrame:PointToObjectSpace(leg.Position)
		self.hipHeight = math.max(1, -offset.Y + leg.Size.Y / 2)
	end
end

--[[ ACTIONS ]]

export type PlayOptions = {
	speed: number?,
	fadeIn: number?,
	startTime: number?, -- seconds already elapsed (late network arrival)
	exclusive: boolean?, -- fade out other actions (default true)
	tag: any?,
}

function CharacterAnimator.play(self: CharacterAnimator, id: string, options: PlayOptions?): Action?
	local clip = ClipLibrary.get(id)
	if clip == nil then
		warn(`[Animation] unknown clip {id}`)
		return nil
	end
	local opts: PlayOptions = options or {}
	local fadeIn = opts.fadeIn or clip.fadeIn
	if opts.exclusive ~= false then
		for _, action in self.actions do
			self:stopAction(action, fadeIn)
		end
	end
	local speed = clip.speed * (opts.speed or 1)
	local action: Action = {
		id = id,
		clip = clip,
		time = (opts.startTime or 0) * speed,
		speed = speed,
		weight = if fadeIn <= 0 then 1 else 0,
		fadeInRate = if fadeIn <= 0 then math.huge else 1 / fadeIn,
		fadeOutRate = 1 / math.max(clip.fadeOut, 1e-3),
		stopping = false,
		tag = opts.tag,
		layer = { clip = clip, time = 0, weight = 0 },
	}
	table.insert(self.actions, action)
	return action
end

function CharacterAnimator.stopAction(self: CharacterAnimator, action: Action, fadeOut: number?)
	if action.stopping then
		return
	end
	action.stopping = true
	local fade = fadeOut or action.clip.fadeOut
	action.fadeOutRate = if fade <= 0 then math.huge else 1 / fade
end

-- Stops every action whose id matches (or all actions when id is nil).
function CharacterAnimator.stop(self: CharacterAnimator, id: string?, fadeOut: number?)
	for _, action in self.actions do
		if id == nil or action.id == id then
			self:stopAction(action, fadeOut)
		end
	end
end

function CharacterAnimator.isPlaying(self: CharacterAnimator, id: string): boolean
	for _, action in self.actions do
		if action.id == id and not action.stopping then
			return true
		end
	end
	return false
end

--[[ JUICE ]]

-- Freezes the animation briefly so hits feel heavy.
function CharacterAnimator.hitstop(self: CharacterAnimator, duration: number)
	self.hitstopUntil = math.max(self.hitstopUntil, os.clock() + duration)
end

-- Spring flinch away from a hit. `fromDirection` points from the victim toward the attacker.
function CharacterAnimator.flinchFrom(self: CharacterAnimator, fromDirection: Vector3, strength: number)
	local flat = Vector3.new(fromDirection.X, 0, fromDirection.Z)
	if flat.Magnitude < 1e-3 then
		flat = self.root.CFrame.LookVector
	end
	local localDir = self.root.CFrame:VectorToObjectSpace(flat.Unit)
	-- From the front (localDir.Z = -1) the pitch goes negative: bend backward. From behind: forward.
	local pitch = localDir.Z * 160 * strength
	local roll = localDir.X * 130 * strength
	local yaw = localDir.X * 80 * strength
	self.flinch:impulse(Vector3.new(pitch, yaw, roll))
end

function CharacterAnimator.recoil(self: CharacterAnimator, strength: number)
	self.recoilSpring:impulse(Vector3.new(strength * 220, 0, 0))
end

--[[ FRAME UPDATE ]]

function CharacterAnimator.refreshStance(self: CharacterAnimator)
	local id = self.model:GetAttribute("Stance")
	local stanceId = if type(id) == "string" then id else nil
	if stanceId ~= self.stanceId then
		self.stanceId = stanceId
		self.stance = if stanceId then ClipLibrary.stance(stanceId) else nil
		self.stancePrefix = if stanceId then (string.match(stanceId, "^([^%.]+)") or "Common") else "Common"
		for _, state in self.states do
			state.clip = nil -- re-resolve weapon-specific state clips
		end
	end

	local modelId = self.model:GetAttribute("WeaponModel")
	local form = self.model:GetAttribute("WeaponForm")
	local twoHand: Composer.TwoHand? = nil
	if type(modelId) == "string" and type(form) == "string" then
		local model = WeaponModels[modelId]
		if model and model.twoHand then
			twoHand = model.twoHand[form]
		end
	end
	self.twoHand = twoHand
end

-- Predicts a replicated state locally for a short time (until the server's attribute catches up).
function CharacterAnimator.overrideState(self: CharacterAnimator, attribute: string, value: boolean, duration: number)
	self.overrides[attribute] = { value = value, untilTime = os.clock() + duration }
end

local function resolveStateClip(prefix: string, clipName: string): Clip.Clip?
	return ClipLibrary.get(`{prefix}.{clipName}`) or ClipLibrary.get(`Common.{clipName}`)
end

function CharacterAnimator.updateStates(self: CharacterAnimator, dt: number)
	table.clear(self.stateLayers)
	local now = os.clock()
	for _, state in self.states do
		local active = self.model:GetAttribute(state.attribute) == true
		local override = self.overrides[state.attribute]
		if override then
			if now < override.untilTime then
				active = override.value
			else
				self.overrides[state.attribute] = nil
			end
		end
		if active and state.clip == nil then
			state.clip = resolveStateClip(self.stancePrefix, state.clipName)
			state.time = 0
		end
		local target = if active and state.clip then 1 else 0
		if state.weight < target then
			state.weight = math.min(target, state.weight + dt / math.max(state.fadeIn, 1e-3))
		elseif state.weight > target then
			state.weight = math.max(target, state.weight - dt / math.max(state.fadeOut, 1e-3))
		end
		local clip = state.clip
		if clip and state.weight > 0 then
			state.time += dt * clip.speed
			state.layer.clip = clip
			state.layer.time = state.time
			state.layer.weight = state.weight
			table.insert(self.stateLayers, state.layer)
		elseif state.weight <= 0 and not active then
			state.clip = nil
		end
	end
end

function CharacterAnimator.updateActions(self: CharacterAnimator, dt: number)
	table.clear(self.actionLayers)
	local index = 1
	while index <= #self.actions do
		local action = self.actions[index]
		local clip = action.clip
		local previous = action.time
		action.time += dt * action.speed

		if self.onMarker and #clip.markers > 0 then
			local callback = self.onMarker
			Clip.forEachMarker(clip, previous, math.min(action.time, if clip.looped then math.huge else clip.length), function(marker)
				callback(self, action, marker)
			end)
		end

		if not clip.looped and action.time >= clip.length then
			self:stopAction(action)
		end

		if action.stopping then
			action.weight -= dt * action.fadeOutRate
		else
			action.weight = math.min(1, action.weight + dt * action.fadeInRate)
		end

		if action.weight <= 0 and action.stopping then
			table.remove(self.actions, index)
		else
			action.layer.time = math.min(action.time, clip.length)
			if clip.looped then
				action.layer.time = action.time
			end
			action.layer.weight = math.clamp(action.weight, 0, 1)
			table.insert(self.actionLayers, action.layer)
			index += 1
		end
	end
end

function CharacterAnimator.checkGrounded(self: CharacterAnimator, dt: number): boolean
	self.groundCheckTimer -= dt
	if self.groundCheckTimer > 0 then
		return self.groundedCache
	end
	self.groundCheckTimer = 1 / 30
	local origin = self.root.Position
	local result = Workspace:Raycast(origin, Vector3.new(0, -(self.hipHeight + 0.6), 0), self.rayParams)
	self.groundedCache = result ~= nil
	return self.groundedCache
end

function CharacterAnimator.updateAdditive(self: CharacterAnimator, dt: number, grounded: boolean, velocityY: number)
	-- Landing: dip proportional to impact speed.
	if grounded and not self.wasGrounded and self.fallSpeed < -30 then
		local impact = math.clamp((-self.fallSpeed - 30) / 90, 0.1, 1)
		self.landing:impulse(Vector3.new(0, -impact * 9, 0))
	end
	self.wasGrounded = grounded
	self.fallSpeed = if grounded then 0 else math.min(self.fallSpeed, velocityY)

	local flinch = self.flinch:update(dt)
	local land = self.landing:update(dt)
	local recoil = self.recoilSpring:update(dt)

	local additive = self.additive
	table.clear(additive)
	local dip = math.min(0, land.Y)
	if math.abs(flinch.X) + math.abs(flinch.Y) + math.abs(flinch.Z) > 0.05 or dip < -0.005 then
		-- flinch.X < 0 bends backward, flinch.Z > 0 means the hit came from the right (tilt left).
		additive.Root = Joints.T(flinch.X * 0.6 - dip * 18, -flinch.Y * 0.4, -flinch.Z * 0.6, 0, dip * 0.35, 0)
		additive.Neck = Joints.H(flinch.X * 0.5, -flinch.Y * 0.3, -flinch.Z * 0.4)
	end
	if math.abs(recoil.X) > 0.05 then
		additive.RightArm = Joints.RA(recoil.X)
	end
end

function CharacterAnimator.update(self: CharacterAnimator, dt: number, cameraPosition: Vector3?)
	if self.destroyed then
		return
	end

	-- Distance LOD: far rigs animate at a lower rate.
	if cameraPosition then
		local distance = (self.root.Position - cameraPosition).Magnitude
		local interval = if distance > 260 then 1 / 12 elseif distance > 140 then 1 / 30 else 0
		self.lodAccumulator += dt
		if self.lodAccumulator < interval then
			return
		end
		dt = self.lodAccumulator
		self.lodAccumulator = 0
	end

	local scaled = if os.clock() < self.hitstopUntil then dt * HITSTOP_SCALE else dt

	self:refreshStance()
	local grounded = self:checkGrounded(dt)
	local velocity = self.root.AssemblyLinearVelocity

	local pose = self.pose
	table.clear(pose)
	local gait = self.model:GetAttribute("Gait")
	local style = Locomotion.Styles[if type(gait) == "string" then gait else "Huntsman"] or Locomotion.Styles.Huntsman
	Locomotion.update(self.loco, {
		dt = scaled,
		velocity = velocity,
		rootCFrame = self.root.CFrame,
		grounded = grounded,
		style = style,
	}, pose)

	self:updateStates(scaled)
	self:updateActions(scaled)
	self:updateAdditive(scaled, grounded, velocity.Y)

	Composer.compose(pose, self.loco, {
		stance = self.stance,
		states = self.stateLayers,
		actions = self.actionLayers,
		additive = self.additive,
		twoHand = self.twoHand,
	})

	self:write(pose)
	self:updateCape(scaled, velocity)
end

-- Capes stream behind with speed, lift when falling and flutter; driven by a soft spring.
function CharacterAnimator.updateCape(self: CharacterAnimator, dt: number, velocity: Vector3)
	local cape = self.cape
	if cape == nil then
		return
	end
	self.capeTime += dt
	local localVelocity = self.root.CFrame:VectorToObjectSpace(velocity)
	local forward = math.max(0, -localVelocity.Z)
	local falling = math.max(0, -localVelocity.Y)
	local speed = Vector3.new(localVelocity.X, 0, localVelocity.Z).Magnitude
	local sway = math.sin(self.capeTime * 1.7) * 3 + math.sin(self.capeTime * 11) * math.min(speed, 30) * 0.12
	local target = math.clamp(forward * 2.1 + falling * 0.7 + speed * 0.4, 0, 78) + sway
	self.capeSpring.target = Vector3.new(target, localVelocity.X * 0.8, 0)
	local value = self.capeSpring:update(dt)
	cape.Transform = CFrame.Angles(math.rad(-math.max(value.X, 2)), 0, math.rad(math.clamp(value.Y, -20, 20)))
	local cape2 = self.cape2
	if cape2 then
		local flutter = math.sin(self.capeTime * 13 + 1) * math.min(speed, 30) * 0.35
		cape2.Transform = CFrame.Angles(math.rad(-(value.X * 0.35 + flutter)), 0, 0)
	end
end

function CharacterAnimator.write(self: CharacterAnimator, pose: Pose)
	for joint, binding in self.motors do
		local value = pose[joint] or IDENTITY
		local motor = binding.motor
		if binding.parentSpace then
			motor.Transform = binding.r0Inv * value * binding.r0
		else
			motor.Transform = value
		end
	end
end

function CharacterAnimator.destroy(self: CharacterAnimator)
	if self.destroyed then
		return
	end
	self.destroyed = true
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
	-- Leave the rig in its rest pose.
	for _, binding in self.motors do
		if binding.motor.Parent then
			binding.motor.Transform = IDENTITY
		end
	end
	Pose.clear(self.pose)
end

return CharacterAnimator
