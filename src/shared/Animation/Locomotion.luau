--!strict
--[[
	Procedural locomotion: idle breathing, walk, sprint, strafing, airborne and turn banking,
	computed every frame from the character's real velocity instead of from canned clips.

	Why procedural: the gait phase advances with distance travelled (stride matched), legs swing
	along the true movement direction (strafing and backpedalling look right for free), and the
	torso leans into acceleration and banks into turns. Weapon stances and action clips are layered
	on top of this by the CharacterAnimator.

	Output is a canonical pose (legs in root space, see Pose.finalize).
]]

local Joints = require(script.Parent.Joints)

type Pose = Joints.Pose

export type GaitStyle = {
	walkSpeed: number, -- speed at which the walk is fully blended in
	runSpeed: number, -- speed at which the sprint is fully blended in
	walkStride: number, -- studs travelled per full gait cycle (two steps) while walking
	runStride: number,
	legWalk: number, -- leg swing amplitude (degrees)
	legRun: number,
	armWalk: number, -- arm swing amplitude (degrees)
	armRun: number,
	leanWalk: number, -- forward lean (degrees)
	leanRun: number,
	bobWalk: number, -- vertical bob (studs)
	bobRun: number,
	twistWalk: number, -- shoulder counter-twist (degrees)
	twistRun: number,
	liftWalk: number, -- swing-leg lift (studs); fakes a knee bend on the knee-less R6 rig
	liftRun: number,
	armOut: number, -- resting arm spread (degrees)
	legOut: number, -- resting leg spread (degrees)
	hunch: number, -- constant forward lean (degrees)
	armsForward: number, -- constant arm pitch (degrees)
	headUp: number, -- head pitch compensation for hunch (degrees)
}

export type State = {
	time: number,
	phase: number,
	move: number,
	run: number,
	air: number,
	rise: number,
	dir: Vector3,
	lean: number,
	bank: number,
	lastVelocity: Vector3,
	lastHeading: number?,
	armSwingR: CFrame,
	armSwingL: CFrame,
}

export type Input = {
	dt: number,
	velocity: Vector3, -- world-space velocity of the root part
	rootCFrame: CFrame,
	grounded: boolean,
	style: GaitStyle,
}

local Locomotion = {}

local T, H, RA, LA, RL, LL = Joints.T, Joints.H, Joints.RA, Joints.LA, Joints.RL, Joints.LL

local TAU = math.pi * 2
local sin, cos, exp, clamp, rad = math.sin, math.cos, math.exp, math.clamp, math.rad

Locomotion.Styles = {
	Huntsman = {
		walkSpeed = 13,
		runSpeed = 24,
		walkStride = 6.5,
		runStride = 10.5,
		legWalk = 32,
		legRun = 58,
		armWalk = 24,
		armRun = 52,
		leanWalk = 3,
		leanRun = 14,
		bobWalk = 0.12,
		bobRun = 0.3,
		twistWalk = 6,
		twistRun = 10,
		liftWalk = 0.15,
		liftRun = 0.45,
		armOut = 5,
		legOut = 2,
		hunch = 0,
		armsForward = 0,
		headUp = 0,
	},
	Feral = { -- Beowolf-style Grimm: hunched, long arms reaching forward, loping gait
		walkSpeed = 12,
		runSpeed = 26,
		walkStride = 7,
		runStride = 12,
		legWalk = 30,
		legRun = 55,
		armWalk = 30,
		armRun = 60,
		leanWalk = 6,
		leanRun = 18,
		bobWalk = 0.2,
		bobRun = 0.4,
		twistWalk = 10,
		twistRun = 14,
		liftWalk = 0.2,
		liftRun = 0.5,
		armOut = 14,
		legOut = 8,
		hunch = 24,
		armsForward = 28,
		headUp = 22,
	},
	Heavy = { -- Ursa-style Grimm: slow, heavy, wide
		walkSpeed = 10,
		runSpeed = 22,
		walkStride = 8,
		runStride = 13,
		legWalk = 24,
		legRun = 40,
		armWalk = 18,
		armRun = 34,
		leanWalk = 4,
		leanRun = 12,
		bobWalk = 0.25,
		bobRun = 0.45,
		twistWalk = 12,
		twistRun = 16,
		liftWalk = 0.15,
		liftRun = 0.35,
		armOut = 18,
		legOut = 10,
		hunch = 16,
		armsForward = 14,
		headUp = 14,
	},
} :: { [string]: GaitStyle }

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Frame-rate independent exponential approach.
local function approach(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * (1 - exp(-rate * dt))
end

function Locomotion.newState(): State
	return {
		time = 0,
		phase = 0,
		move = 0,
		run = 0,
		air = 0,
		rise = 0,
		dir = Vector3.new(0, 0, -1),
		lean = 0,
		bank = 0,
		lastVelocity = Vector3.zero,
		lastHeading = nil,
		armSwingR = CFrame.identity,
		armSwingL = CFrame.identity,
	}
end

function Locomotion.update(state: State, input: Input, out: Pose)
	local dt = math.max(input.dt, 1e-4)
	local style = input.style
	state.time += dt

	local rootCFrame = input.rootCFrame
	local velocity = input.velocity
	local localVelocity = rootCFrame:VectorToObjectSpace(velocity)
	local planar = Vector3.new(localVelocity.X, 0, localVelocity.Z)
	local speed = planar.Magnitude
	local grounded = input.grounded

	-- Blend weights -----------------------------------------------------------------------------
	local moveTarget = if grounded then clamp(speed / style.walkSpeed, 0, 1) else 0
	local runTarget = clamp((speed - style.walkSpeed) / math.max(style.runSpeed - style.walkSpeed, 1), 0, 1)
	state.move = approach(state.move, moveTarget, 10, dt)
	state.run = approach(state.run, runTarget, 6, dt)
	state.air = approach(state.air, if grounded then 0 else 1, if grounded then 16 else 9, dt)
	state.rise = approach(state.rise, clamp(localVelocity.Y / 35, -1, 1), 8, dt)

	if speed > 0.5 then
		local blended = state.dir:Lerp(planar.Unit, 1 - exp(-12 * dt))
		if blended.Magnitude > 1e-3 then
			state.dir = blended.Unit
		end
	end

	-- Gait phase advances with distance travelled, so stride length stays consistent ------------
	local stride = lerp(style.walkStride, style.runStride, state.run)
	if grounded then
		state.phase = (state.phase + (speed / stride) * TAU * dt) % TAU
	end

	local move, run, air = state.move, state.run, state.air
	local idle = 1 - move
	local s, c = sin(state.phase), cos(state.phase)
	local forwardness = -state.dir.Z -- +1 running forward, -1 backpedalling
	local breathe = sin(state.time * 1.9)

	-- Lean into acceleration ----------------------------------------------------------------------
	local accel = (velocity - state.lastVelocity) / dt
	state.lastVelocity = velocity
	local localAccel = rootCFrame:VectorToObjectSpace(accel)
	local leanTarget = clamp(-localAccel.Z * 0.1, -10, 14) * (if grounded then 1 else 0.25)
	state.lean = approach(state.lean, leanTarget, 6, dt)

	-- Bank into turns -----------------------------------------------------------------------------
	local heading: number? = if speed > 2 then math.atan2(-velocity.X, -velocity.Z) else nil
	local turnRate = 0
	if heading and state.lastHeading then
		local delta = (heading - state.lastHeading + math.pi) % TAU - math.pi
		turnRate = delta / dt
	end
	state.lastHeading = heading
	-- turnRate > 0 is a left turn; positive bank leans right, so negate.
	state.bank = approach(state.bank, clamp(-turnRate * speed * 0.22, -16, 16), 7, dt)

	-- Torso -----------------------------------------------------------------------------------------
	local rising = clamp((state.rise + 1) / 2, 0, 1) -- 1 = going up, 0 = falling
	local bob = lerp(style.bobWalk, style.bobRun, run) * move
	local lean = style.hunch
		+ lerp(style.leanWalk, style.leanRun, run) * move * forwardness
		+ state.lean
		+ air * lerp(-7, 6, rising)
	local twist = lerp(style.twistWalk, style.twistRun, run) * move * s * forwardness
	local height = bob * (0.5 - s * s) + breathe * 0.035 * idle * (1 - air)
	out.Root = T(lean, twist, state.bank, 0, height, 0)

	-- Head stays level-ish and keeps facing forward ------------------------------------------------
	out.Neck = H(-(lean - style.hunch) * 0.45 - style.headUp + breathe * 1.2 * idle, -twist * 0.85, -state.bank * 0.5)

	-- Legs (root space) -----------------------------------------------------------------------------
	local axis = state.dir:Cross(Vector3.yAxis)
	local legAmp = rad(lerp(style.legWalk, style.legRun, run)) * move
	local reach = rad(8) * run * move
	local lift = lerp(style.liftWalk, style.liftRun, run) * move
	local spreadR = RL(0, style.legOut)
	local spreadL = LL(0, style.legOut)
	local rightLeg = CFrame.new(0, lift * math.max(0, c), 0) * CFrame.fromAxisAngle(axis, legAmp * s + reach) * spreadR
	local leftLeg = CFrame.new(0, lift * math.max(0, -c), 0) * CFrame.fromAxisAngle(axis, -legAmp * s + reach) * spreadL

	-- Arms swing opposite the same-side leg -------------------------------------------------------------
	local armAmp = lerp(style.armWalk, style.armRun, run) * move
	local direction = if forwardness >= 0 then 1 else -1
	local swing = armAmp * s * math.max(math.abs(forwardness), 0.35) * direction
	local armOut = style.armOut + 4 * run + breathe * 1.5 * idle
	local rightArm = RA(-swing + style.armsForward, armOut)
	local leftArm = LA(swing + style.armsForward, armOut)
	state.armSwingR = RA(-swing)
	state.armSwingL = LA(swing)

	-- Airborne: tuck while rising, arms out for balance while falling ----------------------------------
	if air > 0.01 then
		rightLeg = rightLeg:Lerp(RL(lerp(14, 46, rising), 6), air)
		leftLeg = leftLeg:Lerp(LL(lerp(-18, -10, rising), 6), air)
		rightArm = rightArm:Lerp(RA(lerp(30, -10, rising), lerp(62, 28, rising)), air)
		leftArm = leftArm:Lerp(LA(lerp(22, 10, rising), lerp(56, 30, rising)), air)
	end

	out.RightLeg = rightLeg
	out.LeftLeg = leftLeg
	out.RightArm = rightArm
	out.LeftArm = leftArm
end

return Locomotion
