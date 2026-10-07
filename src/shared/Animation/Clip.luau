--!strict
--[[
	Keyframe clips: authored as plain tables, compiled once into flat arrays for fast sampling.

	AUTHORING FORMAT
	{
		looped = false,          -- loop forever (stances, block, knocked...)
		fadeIn = 0.06,           -- seconds to blend in over whatever is playing
		fadeOut = 0.18,          -- seconds to blend back out after the last keyframe
		speed = 1,               -- playback rate
		legSpace = "Root",       -- "Root" (default) or "Torso" for flips where legs follow the torso
		lag = { RightGrip = 0.02 }, -- per-joint delay in seconds for follow-through
		keyframes = {
			{ t = 0,    pose = { Root = T(...), RightArm = RA(...) } },
			{ t = 0.12, ease = "Back.In",  pose = {...} },  -- `ease` is how we ARRIVE at this key
			{ t = 0.2,  ease = "Expo.Out", pose = {...} },
		},
		markers = { { t = 0.18, name = "Hit" }, { t = 0.1, name = "TrailOn" } },
	}

	A joint holds its most recent value until a later keyframe changes it; before its first mention
	it holds that first value. Joints a clip never mentions are left to the layers underneath, so an
	upper-body slash can play over the procedural walk cycle.
]]

local Easing = require(script.Parent.Easing)
local Joints = require(script.Parent.Joints)

type Pose = Joints.Pose
type EasingFn = Easing.EasingFn

export type KeyframeDef = {
	t: number,
	ease: string?,
	pose: Pose,
}

export type MarkerDef = {
	t: number,
	name: string,
	data: any?,
}

export type ClipDef = {
	looped: boolean?,
	fadeIn: number?,
	fadeOut: number?,
	speed: number?,
	length: number?,
	legSpace: string?,
	lag: { [string]: number }?,
	keyframes: { KeyframeDef },
	markers: { MarkerDef }?,
}

export type Clip = {
	id: string,
	length: number,
	looped: boolean,
	fadeIn: number,
	fadeOut: number,
	speed: number,
	joints: { string },
	mask: { [string]: boolean },
	times: { number },
	eases: { EasingFn },
	poses: { Pose },
	markers: { MarkerDef },
	lag: { [string]: number },
}

local Clip = {}

local IDENTITY = CFrame.identity
local LEGS = { "RightLeg", "LeftLeg" }

function Clip.compile(id: string, def: ClipDef): Clip
	local source = def.keyframes
	assert(#source > 0, `Clip "{id}" has no keyframes`)

	local keyframes = table.clone(source)
	table.sort(keyframes, function(a, b)
		return a.t < b.t
	end)

	-- Which joints does this clip own?
	local jointSet: { [string]: boolean } = {}
	for _, kf in keyframes do
		for name in kf.pose do
			assert(Joints.Rig[name], `Clip "{id}" uses unknown joint "{name}"`)
			jointSet[name] = true
		end
	end

	-- Forward fill: a joint keeps its last value until changed.
	local poses: { Pose } = {}
	local previous: Pose = {}
	for i, kf in keyframes do
		local pose = table.clone(previous)
		for name, cf in kf.pose do
			pose[name] = cf
		end
		poses[i] = pose
		previous = pose
	end

	-- Back fill: before a joint's first mention, hold that first value.
	for name in jointSet do
		local first: CFrame? = nil
		for _, pose in poses do
			if pose[name] then
				first = pose[name]
				break
			end
		end
		if first then
			for _, pose in poses do
				if pose[name] then
					break
				end
				pose[name] = first
			end
		end
	end

	-- Canonical form keeps legs in root space; clips authored with torso-space legs get converted.
	if def.legSpace == "Torso" then
		for _, pose in poses do
			local root = pose.Root
			if root then
				for _, leg in LEGS do
					local cf = pose[leg]
					if cf then
						pose[leg] = root.Rotation * cf
					end
				end
			end
		end
	end

	local times: { number } = {}
	local eases: { EasingFn } = {}
	for i, kf in keyframes do
		times[i] = kf.t
		eases[i] = Easing.get(kf.ease)
	end

	local markers: { MarkerDef } = {}
	if def.markers then
		for _, marker in def.markers do
			table.insert(markers, marker)
		end
		table.sort(markers, function(a, b)
			return a.t < b.t
		end)
	end

	local joints: { string } = {}
	for _, name in Joints.Names do
		if jointSet[name] then
			table.insert(joints, name)
		end
	end

	local lastTime = times[#times]
	local length = def.length or lastTime
	if markers[#markers] and markers[#markers].t > length then
		length = markers[#markers].t
	end

	return {
		id = id,
		length = math.max(length, 1e-3),
		looped = def.looped == true,
		fadeIn = def.fadeIn or 0.08,
		fadeOut = def.fadeOut or 0.2,
		speed = def.speed or 1,
		joints = joints,
		mask = jointSet,
		times = times,
		eases = eases,
		poses = poses,
		markers = markers,
		lag = def.lag or {},
	}
end

-- Index of the last keyframe whose time is <= t (1 if t is before the first key).
local function findSegment(times: { number }, t: number): number
	local lo, hi = 1, #times
	if t <= times[1] then
		return 1
	end
	if t >= times[hi] then
		return hi
	end
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if times[mid] <= t then
			lo = mid
		else
			hi = mid
		end
	end
	return lo
end

local function sampleJoint(clip: Clip, name: string, t: number): CFrame
	local times, poses = clip.times, clip.poses
	local count = #times
	if count == 1 then
		return poses[1][name] or IDENTITY
	end

	if clip.looped then
		local length = clip.length
		t %= length
		if t >= times[count] then
			-- Wrap segment: last key -> first key (shifted by one loop length).
			local span = (length - times[count]) + times[1]
			if span <= 1e-6 then
				return poses[1][name] or IDENTITY
			end
			local alpha = clip.eases[1]((t - times[count]) / span)
			return (poses[count][name] or IDENTITY):Lerp(poses[1][name] or IDENTITY, alpha)
		elseif t < times[1] then
			local span = (length - times[count]) + times[1]
			if span <= 1e-6 then
				return poses[1][name] or IDENTITY
			end
			local alpha = clip.eases[1]((t + length - times[count]) / span)
			return (poses[count][name] or IDENTITY):Lerp(poses[1][name] or IDENTITY, alpha)
		end
	end

	local i = findSegment(times, t)
	if i >= count then
		return poses[count][name] or IDENTITY
	end
	if t <= times[1] then
		return poses[1][name] or IDENTITY
	end
	local t0, t1 = times[i], times[i + 1]
	local span = t1 - t0
	if span <= 1e-6 then
		return poses[i + 1][name] or IDENTITY
	end
	local alpha = clip.eases[i + 1]((t - t0) / span)
	return (poses[i][name] or IDENTITY):Lerp(poses[i + 1][name] or IDENTITY, alpha)
end

-- Samples every joint the clip owns at time `t` (seconds, unscaled) into `out`.
function Clip.sample(clip: Clip, t: number, out: Pose)
	local lag = clip.lag
	for _, name in clip.joints do
		local delay = lag[name]
		local jt = if delay then t - delay else t
		if not clip.looped and jt < 0 then
			jt = 0
		end
		out[name] = sampleJoint(clip, name, jt)
	end
end

-- Calls `callback(marker)` for every marker crossed moving from t0 (exclusive) to t1 (inclusive).
function Clip.forEachMarker(clip: Clip, t0: number, t1: number, callback: (MarkerDef) -> ())
	local markers = clip.markers
	if #markers == 0 or t1 <= t0 then
		return
	end
	if clip.looped then
		local length = clip.length
		local loops = math.floor(t1 / length) - math.floor(t0 / length)
		local a, b = t0 % length, t1 % length
		if loops == 0 then
			for _, marker in markers do
				if marker.t > a and marker.t <= b then
					callback(marker)
				end
			end
		else
			for _, marker in markers do
				if marker.t > a then
					callback(marker)
				end
			end
			for _ = 2, loops do
				for _, marker in markers do
					callback(marker)
				end
			end
			for _, marker in markers do
				if marker.t <= b then
					callback(marker)
				end
			end
		end
		return
	end
	for _, marker in markers do
		if marker.t > t0 and marker.t <= t1 then
			callback(marker)
		elseif marker.t > t1 then
			break
		end
	end
end

-- Time (seconds, unscaled) of the nth marker with the given name, or nil.
function Clip.markerTime(clip: Clip, name: string, occurrence: number?): number?
	local wanted = occurrence or 1
	local seen = 0
	for _, marker in clip.markers do
		if marker.name == name then
			seen += 1
			if seen == wanted then
				return marker.t
			end
		end
	end
	return nil
end

-- All markers with the given name, in time order.
function Clip.markersNamed(clip: Clip, name: string): { MarkerDef }
	local found = {}
	for _, marker in clip.markers do
		if marker.name == name then
			table.insert(found, marker)
		end
	end
	return found
end

return Clip
