--!strict
--[[
	Easing curves for keyframe interpolation.

	Specs are strings of the form "Style.Direction", e.g. "Quad.Out", "Back.In", "Expo.InOut".
	A bare style ("Linear", "Constant") is also accepted. Everything here is pure math so the same
	curves run on the client, the server (marker timing), and in offline Lune tooling.
]]

export type EasingFn = (number) -> number

local Easing = {}

local PI = math.pi
local sin, cos, sqrt = math.sin, math.cos, math.sqrt

local function bounceOut(t: number): number
	local n1, d1 = 7.5625, 2.75
	if t < 1 / d1 then
		return n1 * t * t
	elseif t < 2 / d1 then
		t -= 1.5 / d1
		return n1 * t * t + 0.75
	elseif t < 2.5 / d1 then
		t -= 2.25 / d1
		return n1 * t * t + 0.9375
	end
	t -= 2.625 / d1
	return n1 * t * t + 0.984375
end

-- "In" variants; Out/InOut are derived from these.
local inCurves: { [string]: EasingFn } = {
	Linear = function(t)
		return t
	end,
	Sine = function(t)
		return 1 - cos(t * PI / 2)
	end,
	Quad = function(t)
		return t * t
	end,
	Cubic = function(t)
		return t * t * t
	end,
	Quart = function(t)
		return t * t * t * t
	end,
	Quint = function(t)
		return t * t * t * t * t
	end,
	Expo = function(t)
		return if t <= 0 then 0 else 2 ^ (10 * t - 10)
	end,
	Circ = function(t)
		return 1 - sqrt(math.max(0, 1 - t * t))
	end,
	Back = function(t)
		local c1 = 1.70158
		return (c1 + 1) * t * t * t - c1 * t * t
	end,
	Elastic = function(t)
		if t <= 0 then
			return 0
		elseif t >= 1 then
			return 1
		end
		return -(2 ^ (10 * t - 10)) * sin((t * 10 - 10.75) * (2 * PI) / 3)
	end,
	Bounce = function(t)
		return 1 - bounceOut(1 - t)
	end,
}

local function constant(t: number): number
	return if t >= 1 then 1 else 0
end

local cache: { [string]: EasingFn } = {}

local function build(style: string, direction: string): EasingFn
	if style == "Constant" then
		return constant
	end
	local curve = inCurves[style]
	assert(curve, `Unknown easing style "{style}"`)
	if style == "Linear" or direction == "In" then
		return curve
	elseif direction == "Out" then
		return function(t)
			return 1 - curve(1 - t)
		end
	elseif direction == "InOut" then
		return function(t)
			if t < 0.5 then
				return curve(2 * t) / 2
			end
			return 1 - curve(2 - 2 * t) / 2
		end
	end
	error(`Unknown easing direction "{direction}"`)
end

--[[
	Returns the easing function for a spec string. Results are cached.
	Defaults to "Quad.InOut", which reads well for most pose-to-pose motion.
]]
function Easing.get(spec: string?): EasingFn
	local key = spec or "Quad.InOut"
	local cached = cache[key]
	if cached then
		return cached
	end
	local style, direction = string.match(key, "^(%a+)%.?(%a*)$")
	assert(style, `Malformed easing spec "{key}"`)
	local fn = build(style, if direction == nil or direction == "" then "Out" else direction)
	cache[key] = fn
	return fn
end

function Easing.apply(spec: string?, t: number): number
	return Easing.get(spec)(math.clamp(t, 0, 1))
end

return Easing
