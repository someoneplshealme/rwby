--!strict
--[[
	Composer: the layering rules that turn every animation source into one final pose.

	Order (bottom to top):
	  1. Locomotion        procedural walk/run/air, from real velocity
	  2. Stance            weapon hold for the current weapon form; arms/grips override,
	                       Root and Neck add on top of locomotion, legs only while standing still
	  3. State loops       block, aim, stunned, knocked... (weights driven by replicated attributes)
	  4. Actions           one-shot clips (attacks, dodges, casts) with fade in/out
	  5. Additive          springs for flinches, landing dips, recoil
	  6. Finalize          root-space legs -> torso space

	This module is pure so the client animator and the offline preview share the exact same rules.
]]

local Clip = require(script.Parent.Clip)
local ClipLibrary = require(script.Parent.ClipLibrary)
local Joints = require(script.Parent.Joints)
local Locomotion = require(script.Parent.Locomotion)
local Pose = require(script.Parent.Pose)

type Pose = Joints.Pose

export type Layer = {
	clip: Clip.Clip,
	time: number, -- seconds into the clip (unscaled clip time)
	weight: number,
}

local Composer = {}

local IDENTITY = CFrame.identity
local HOLD_JOINTS = { "RightArm", "LeftArm", "RightGrip", "LeftGrip" }
local OFFSET_JOINTS = { "Root", "Neck" }
local LEG_JOINTS = { "RightLeg", "LeftLeg" }

local scratch: Pose = {}

-- Value of `joint` blended across the stance's idle -> walk -> run -> air variants.
local function stanceValue(stance: ClipLibrary.StanceDef, joint: string, loco: Locomotion.State): CFrame?
	local idle = stance.idle[joint]
	local walkPose = stance.walk
	local walk = if walkPose then walkPose[joint] or idle else idle
	local runPose = stance.run
	local run = if runPose then runPose[joint] or walk else walk
	local airPose = stance.air
	local air = if airPose then airPose[joint] or walk else walk

	local value = idle
	if walk and loco.move > 0 then
		value = if value then value:Lerp(walk, loco.move) else walk
	end
	if run and loco.run > 0 then
		value = if value then value:Lerp(run, loco.run * loco.move) else run
	end
	if air and loco.air > 0 then
		value = if value then value:Lerp(air, loco.air) else air
	end
	return value
end

function Composer.applyStance(out: Pose, stance: ClipLibrary.StanceDef, loco: Locomotion.State)
	local swing = stance.armSwing or 0.25

	for _, joint in HOLD_JOINTS do
		local value = stanceValue(stance, joint, loco)
		if value then
			out[joint] = value
		end
	end
	if swing > 0 then
		local right = out.RightArm
		if right then
			out.RightArm = IDENTITY:Lerp(loco.armSwingR, swing) * right
		end
		local left = out.LeftArm
		if left then
			out.LeftArm = IDENTITY:Lerp(loco.armSwingL, swing) * left
		end
	end

	for _, joint in OFFSET_JOINTS do
		local value = stanceValue(stance, joint, loco)
		if value then
			out[joint] = value * (out[joint] or IDENTITY)
		end
	end

	-- Fighting-stance footwork only while planted and still.
	local plant = (1 - loco.move) * (1 - loco.air)
	if plant > 0.001 then
		for _, joint in LEG_JOINTS do
			local value = stance.idle[joint]
			if value then
				out[joint] = (out[joint] or IDENTITY):Lerp(value, plant)
			end
		end
	end
end

-- Samples each layer and blends it over `out` by its weight.
function Composer.applyLayers(out: Pose, layers: { Layer })
	for _, layer in layers do
		if layer.weight > 0.001 then
			table.clear(scratch)
			Clip.sample(layer.clip, layer.time, scratch)
			Pose.blendInto(out, scratch, math.min(layer.weight, 1))
		end
	end
end

-- A segment on a two-handed weapon (in right-handle space) where the off hand may hold it.
export type TwoHand = {
	a: Vector3,
	b: Vector3,
	prefer: number?, -- 0..1 preferred spot along the segment when several are reachable
}

export type Frame = {
	stance: ClipLibrary.StanceDef?,
	states: { Layer }?,
	actions: { Layer }?,
	additive: Pose?,
	twoHand: TwoHand?,
}

-- Highest weight among layers that animate the left arm themselves.
local function leftArmOwnership(layers: { Layer }?): number
	local owned = 0
	if layers then
		for _, layer in layers do
			if layer.clip.mask.LeftArm then
				owned = math.max(owned, math.min(layer.weight, 1))
			end
		end
	end
	return owned
end

--[[
	Two-hand reach: points the left arm at the spot on the weapon (within the hold segment) that a
	rigid R6 arm can actually touch, so two-handed weapons stay gripped through every swing without
	hand-authoring the off arm. Clips that animate LeftArm explicitly take over from this.
]]
function Composer.applyTwoHand(out: Pose, twoHand: TwoHand, weight: number)
	if weight <= 0.001 then
		return
	end
	local handle = Joints.handleCFrame("Right", out.RightArm or IDENTITY, out.RightGrip or IDENTITY)
	local a, b = handle * twoHand.a, handle * twoHand.b
	local pivot = Joints.R6.LeftArm.c0.Position
	local reach = Joints.reachLength("Left")

	local d = b - a
	local f = a - pivot
	local lengthSq = d:Dot(d)
	local target = a
	if lengthSq > 1e-6 then
		-- Points on the segment exactly one arm's length from the shoulder: |f + s*d| = reach.
		local bq = 2 * d:Dot(f)
		local cq = f:Dot(f) - reach * reach
		local disc = bq * bq - 4 * lengthSq * cq
		local prefer = twoHand.prefer or 0.5
		local best: number? = nil
		if disc >= 0 then
			local root = math.sqrt(disc)
			for _, s in { (-bq - root) / (2 * lengthSq), (-bq + root) / (2 * lengthSq) } do
				if s >= 0 and s <= 1 and (best == nil or math.abs(s - prefer) < math.abs(best - prefer)) then
					best = s
				end
			end
		end
		local s = best or math.clamp(-f:Dot(d) / lengthSq, 0, 1)
		target = a + d * s
	end
	out.LeftArm = (out.LeftArm or IDENTITY):Lerp(Joints.reach("Left", target), weight)
end

-- Builds the final pose. `out` must already contain the locomotion pose for this frame.
function Composer.compose(out: Pose, loco: Locomotion.State, frame: Frame)
	if frame.stance then
		Composer.applyStance(out, frame.stance, loco)
	end
	if frame.states then
		Composer.applyLayers(out, frame.states)
	end
	if frame.actions then
		Composer.applyLayers(out, frame.actions)
	end
	if frame.twoHand then
		local grip = 1
		local stance = frame.stance
		if stance then
			local still = stance.twoHand or 1
			local running = stance.twoHandRun or still
			grip = still + (running - still) * loco.run * loco.move
		end
		local owned = math.max(leftArmOwnership(frame.states), leftArmOwnership(frame.actions))
		Composer.applyTwoHand(out, frame.twoHand, grip * (1 - owned))
	end
	if frame.additive then
		Pose.addInto(out, frame.additive)
	end
	Pose.finalize(out)
end

return Composer
