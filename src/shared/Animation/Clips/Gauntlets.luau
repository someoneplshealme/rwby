--!nonstrict
--[[
	Ember Gauntlets: a boxer's toolkit. Jab, cross, hook, uppercut, then a haymaker that fires
	a shell on impact; the Dragon Breaker critical dashes in and rockets the target skyward.
	Loaded form punches fire shotgun blasts (left and right alternate).

	Punches are posed by pointing the arm (Author.point): the gauntlet follows the fist.
]]

local Author = require(script.Parent.Parent.Author)

local T, H, RL, LL = Author.T, Author.H, Author.RL, Author.LL
local v, point, merge = Author.v, Author.point, Author.merge

local function guard(): { [string]: CFrame }
	return {
		Root = T(8, 22, 0, 0, -0.18, 0),
		Neck = H(8, -20, 0),
		RightArm = point("Right", v(-0.42, 0.25, -1)),
		LeftArm = point("Left", v(0.3, 0.3, -1)),
		RightLeg = RL(-14, 12),
		LeftLeg = LL(16, 10),
	}
end

local function loadedGuard(): { [string]: CFrame }
	return {
		Root = T(6, 16, 0, 0, -0.12, 0),
		Neck = H(4, -14, 0),
		RightArm = point("Right", v(-0.2, 0, -1)),
		LeftArm = point("Left", v(0.25, 0.05, -1)),
		RightLeg = RL(-12, 12),
		LeftLeg = LL(14, 10),
	}
end

local function blast(side: string): any
	local isRight = side == "Right"
	local arm = if isRight then "RightArm" else "LeftArm"
	local x = if isRight then -0.05 else 0.08
	local strike: { [string]: CFrame } = {
		Root = T(8, if isRight then -12 else 26, 0, 0, -0.12, 0),
		Neck = H(4, if isRight then 8 else -22, 0),
	}
	strike[arm] = point(side, v(x, 0.1, -1))
	local kick: { [string]: CFrame } = { Root = T(-8, if isRight then -6 else 20, 0, 0, -0.05, 0) }
	kick[arm] = point(side, v(x, 0.45, -0.8))
	return {
		fadeIn = 0.03,
		fadeOut = 0.18,
		keyframes = {
			{ t = 0.04, ease = "Expo.Out", pose = strike },
			{ t = 0.12, ease = "Quad.Out", pose = kick },
			{ t = 0.38, ease = "Sine.InOut", pose = loadedGuard() },
		},
		markers = { { t = 0.04, name = "Shoot" }, { t = 0.2, name = "Chain" } },
	}
end

return {
	prefix = "Gauntlets",
	stances = {
		Fists = {
			idle = guard(),
			run = { RightArm = point("Right", v(-0.15, -0.35, -1)), LeftArm = point("Left", v(0.15, -0.35, -1)) },
			armSwing = 0.45,
		},
		Loaded = {
			idle = loadedGuard(),
			run = { RightArm = point("Right", v(-0.1, -0.4, -1)), LeftArm = point("Left", v(0.1, -0.4, -1)) },
			armSwing = 0.4,
		},
	},
	clips = {
		-- Lead-hand jab.
		M1_1 = {
			fadeIn = 0.03,
			fadeOut = 0.16,
			keyframes = {
				{
					t = 0.04,
					ease = "Quad.Out",
					pose = merge(
						guard(),
						{ LeftArm = point("Left", v(0.4, 0.15, -0.7)), Root = T(8, 26, 0, 0, -0.18, 0) }
					),
				},
				{
					t = 0.1,
					ease = "Expo.Out",
					pose = {
						Root = T(12, 34, 0, 0, -0.22, 0),
						Neck = H(6, -30, 0),
						LeftArm = point("Left", v(0.06, 0.15, -1)),
						RightLeg = RL(-20, 12),
						LeftLeg = LL(24, 10),
					},
				},
				{ t = 0.3, ease = "Quad.InOut", pose = guard() },
			},
			markers = {
				{ t = 0.04, name = "TrailOn" },
				{ t = 0.05, name = "Swing" },
				{ t = 0.06, name = "Lunge", data = 10 },
				{ t = 0.1, name = "Hit" },
				{ t = 0.15, name = "TrailOff" },
				{ t = 0.16, name = "Chain" },
			},
		},
		-- Rear cross.
		M1_2 = {
			fadeIn = 0.03,
			fadeOut = 0.16,
			keyframes = {
				{
					t = 0.05,
					ease = "Quad.Out",
					pose = merge(
						guard(),
						{ RightArm = point("Right", v(-0.1, 0, -0.6)), Root = T(8, 30, 0, 0, -0.18, 0) }
					),
				},
				{
					t = 0.12,
					ease = "Expo.Out",
					pose = {
						Root = T(14, -22, 0, 0, -0.25, 0),
						Neck = H(6, 16, 0),
						RightArm = point("Right", v(-0.08, 0.12, -1)),
						LeftArm = point("Left", v(0.4, 0.2, -0.8)),
						RightLeg = RL(-26, 10),
						LeftLeg = LL(22, 10),
					},
				},
				{ t = 0.34, ease = "Quad.InOut", pose = guard() },
			},
			markers = {
				{ t = 0.05, name = "TrailOn" },
				{ t = 0.06, name = "Swing" },
				{ t = 0.07, name = "Lunge", data = 12 },
				{ t = 0.11, name = "Hit" },
				{ t = 0.17, name = "TrailOff" },
				{ t = 0.18, name = "Chain" },
			},
		},
		-- Lead hook.
		M1_3 = {
			fadeIn = 0.03,
			fadeOut = 0.16,
			keyframes = {
				{
					t = 0.06,
					ease = "Quad.Out",
					pose = merge(
						guard(),
						{ LeftArm = point("Left", v(-0.9, 0.15, -0.4)), Root = T(6, 42, 0, 0, -0.2, 0) }
					),
				},
				{
					t = 0.14,
					ease = "Expo.Out",
					pose = {
						Root = T(12, -22, 0, 0, -0.25, 0),
						Neck = H(4, 12, 0),
						LeftArm = point("Left", v(0.5, 0.2, -0.85)),
						RightLeg = RL(-16, 12),
						LeftLeg = LL(20, 10),
					},
				},
				{ t = 0.36, ease = "Quad.InOut", pose = guard() },
			},
			markers = {
				{ t = 0.06, name = "TrailOn" },
				{ t = 0.07, name = "Swing" },
				{ t = 0.13, name = "Hit" },
				{ t = 0.19, name = "TrailOff" },
				{ t = 0.2, name = "Chain" },
			},
		},
		-- Rear uppercut from a crouch.
		M1_4 = {
			fadeIn = 0.03,
			fadeOut = 0.18,
			keyframes = {
				{
					t = 0.07,
					ease = "Quad.Out",
					pose = merge(guard(), {
						Root = T(22, 12, 0, 0, -0.5, 0),
						RightArm = point("Right", v(0.15, -1, -0.25)),
						RightLeg = RL(-22, 14),
						LeftLeg = LL(26, 12),
					}),
				},
				{
					t = 0.15,
					ease = "Expo.Out",
					pose = {
						Root = T(-10, -16, 0, 0, 0.05, 0),
						Neck = H(-12, 10, 0),
						RightArm = point("Right", v(-0.15, 0.9, -0.5)),
						RightLeg = RL(-12, 12),
						LeftLeg = LL(14, 10),
					},
				},
				{ t = 0.38, ease = "Quad.InOut", pose = guard() },
			},
			markers = {
				{ t = 0.07, name = "TrailOn" },
				{ t = 0.08, name = "Swing" },
				{ t = 0.14, name = "Hit" },
				{ t = 0.2, name = "TrailOff" },
				{ t = 0.22, name = "Chain" },
			},
		},
		-- Haymaker that fires a shell on impact.
		M1_5 = {
			fadeIn = 0.04,
			fadeOut = 0.25,
			keyframes = {
				{
					t = 0.14,
					ease = "Back.Out",
					pose = {
						Root = T(-6, 52, 0, 0, -0.08, 0),
						Neck = H(0, -36, 0),
						RightArm = point("Right", v(0.7, 0.6, 0.5)),
						LeftArm = point("Left", v(0.4, 0.1, -1)),
						RightLeg = RL(-16, 12),
						LeftLeg = LL(20, 10),
					},
				},
				{
					t = 0.24,
					ease = "Expo.Out",
					pose = {
						Root = T(26, -40, 0, 0, -0.35, -0.4),
						Neck = H(10, 26, 0),
						RightArm = point("Right", v(-0.15, 0, -1)),
						LeftArm = point("Left", v(0.3, -0.6, 0.4)),
						RightLeg = RL(-32, 12),
						LeftLeg = LL(34, 8),
					},
				},
				{ t = 0.62, ease = "Sine.InOut", pose = guard() },
			},
			markers = {
				{ t = 0.12, name = "TrailOn" },
				{ t = 0.15, name = "Swing", data = "Heavy" },
				{ t = 0.18, name = "Lunge", data = 30 },
				{ t = 0.23, name = "Hit" },
				{ t = 0.23, name = "Sound", data = "Shotgun" },
				{ t = 0.24, name = "Shake", data = 0.3 },
				{ t = 0.32, name = "TrailOff" },
				{ t = 0.42, name = "Chain" },
			},
		},
		-- Dragon Breaker: coil, dash in, rising blast uppercut that launches.
		Critical = {
			fadeIn = 0.04,
			fadeOut = 0.28,
			keyframes = {
				{
					t = 0.12,
					ease = "Quad.Out",
					pose = {
						Root = T(30, 30, 0, 0, -0.8, 0),
						Neck = H(-14, -26, 0),
						RightArm = point("Right", v(0.3, -1, 0.2)),
						LeftArm = point("Left", v(0.3, 0.2, -1)),
						RightLeg = RL(-30, 14),
						LeftLeg = LL(30, 10),
					},
				},
				{
					t = 0.26,
					ease = "Quad.In",
					pose = { Root = T(34, 10, 0, 0, -0.55, 0), RightLeg = RL(-36, 10), LeftLeg = LL(36, 8) },
				},
				{
					t = 0.38,
					ease = "Expo.Out",
					pose = {
						Root = T(-18, -20, 0, 0, 0.5, 0),
						Neck = H(-24, 12, 0),
						RightArm = point("Right", v(-0.1, 1, -0.25)),
						LeftArm = point("Left", v(0.4, -0.6, 0.3)),
						RightLeg = RL(34, 8),
						LeftLeg = LL(-20, 8),
					},
				},
				{ t = 0.78, ease = "Sine.InOut", pose = guard() },
			},
			markers = {
				{ t = 0.04, name = "Glint" },
				{ t = 0.22, name = "Lunge", data = 70 },
				{ t = 0.3, name = "TrailOn" },
				{ t = 0.31, name = "Swing", data = "Heavy" },
				{ t = 0.37, name = "Hit" },
				{ t = 0.37, name = "Sound", data = "Shotgun" },
				{ t = 0.38, name = "Shake", data = 0.4 },
				{ t = 0.48, name = "TrailOff" },
				{ t = 0.6, name = "Chain" },
			},
		},
		BlastR = blast("Right"),
		BlastL = blast("Left"),
		-- Ember Rush: blast backward to rocket forward into a straight.
		EmberRush = {
			fadeIn = 0.04,
			fadeOut = 0.25,
			keyframes = {
				{
					t = 0.08,
					ease = "Quad.Out",
					pose = {
						Root = T(16, 0, 0, 0, -0.4, 0),
						Neck = H(-10, 0, 0),
						RightArm = point("Right", v(0.3, -0.5, 0.9)),
						LeftArm = point("Left", v(-0.3, -0.5, 0.9)),
						RightLeg = RL(-24, 10),
						LeftLeg = LL(24, 10),
					},
				},
				{
					t = 0.22,
					ease = "Expo.Out",
					pose = {
						Root = T(22, -26, 0, 0, -0.4, -0.3),
						Neck = H(6, 18, 0),
						RightArm = point("Right", v(-0.05, 0.1, -1)),
						LeftArm = point("Left", v(0.3, -0.4, 0.5)),
						RightLeg = RL(-30, 12),
						LeftLeg = LL(32, 8),
					},
				},
				{ t = 0.58, ease = "Sine.InOut", pose = loadedGuard() },
			},
			markers = {
				{ t = 0.09, name = "Sound", data = "Shotgun" },
				{ t = 0.1, name = "Lunge", data = 80 },
				{ t = 0.12, name = "TrailOn" },
				{ t = 0.21, name = "Hit" },
				{ t = 0.21, name = "Sound", data = "Shotgun" },
				{ t = 0.22, name = "Shake", data = 0.3 },
				{ t = 0.3, name = "TrailOff" },
				{ t = 0.42, name = "Chain" },
			},
		},
		-- Peek-a-boo guard.
		Block = {
			looped = true,
			fadeIn = 0.05,
			keyframes = {
				{
					t = 0,
					pose = {
						Root = T(14, 0, 0, 0, -0.3, 0),
						Neck = H(14, 0, 0),
						RightArm = point("Right", v(-0.45, 0.55, -0.75)),
						LeftArm = point("Left", v(0.45, 0.55, -0.75)),
						RightLeg = RL(-14, 12),
						LeftLeg = LL(16, 10),
					},
				},
				{ t = 0.6, ease = "Sine.InOut", pose = { Root = T(16, 0, 0, 0, -0.36, 0) } },
				{ t = 1.2, ease = "Sine.InOut", pose = { Root = T(14, 0, 0, 0, -0.3, 0) } },
			},
		},
		Loaded_Aim = {
			looped = true,
			fadeIn = 0.1,
			keyframes = {
				{
					t = 0,
					pose = {
						Root = T(6, 8, 0, 0, -0.12, 0),
						Neck = H(2, -8, 0),
						RightArm = point("Right", v(-0.1, 0.05, -1)),
						LeftArm = point("Left", v(0.25, 0, -1)),
						RightLeg = RL(-12, 12),
						LeftLeg = LL(14, 10),
					},
				},
			},
		},
	},
}
