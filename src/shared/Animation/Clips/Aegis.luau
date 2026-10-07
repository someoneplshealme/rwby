--!nonstrict
--[[
	Aegis Blade: disciplined sword-and-shield work (slash, backhand, thrust, shield bash, and the
	Bulwark Charge critical), and a crushing two-handed greatsword after the mecha-shift.

	Sword poses use Author.armed (blade = shaft, cutting edge = edge). The shield is posed with
	Author.armedLeft so it always faces the enemy: shaft up, edge to the right.
]]

local Author = require(script.Parent.Parent.Author)

local T, H, RL, LL = Author.T, Author.H, Author.RL, Author.LL
local v, armed, armedLeft, swing, merge = Author.v, Author.armed, Author.armedLeft, Author.swing, Author.merge

local UP = v(0, 1, 0)
local DOWN = v(0, -1, 0)
local CHOP = v(-1, 0, 0)
local RIGHT = v(1, 0, 0)

local function shield(pose: { [string]: CFrame }, reach: Vector3): { [string]: CFrame }
	return armedLeft(pose, reach, UP, RIGHT)
end

local function swordReady(): { [string]: CFrame }
	local pose = armed({
		Root = T(6, 18, 0, 0, -0.15, 0),
		Neck = H(2, -16, 0),
		RightLeg = RL(-12, 10),
		LeftLeg = LL(14, 8),
	}, v(0.35, -0.65, -0.75), v(0.05, 0.7, -0.75), v(0, -0.7, -0.7))
	return shield(pose, v(0.15, -0.25, -1))
end

local function greatReady(): { [string]: CFrame }
	return armed({
		Root = T(8, 16, 0, 0, -0.22, 0),
		Neck = H(4, -12, 0),
		RightLeg = RL(-16, 14),
		LeftLeg = LL(18, 12),
	}, v(-0.05, -0.75, -0.65), v(0.05, 0.85, -0.5), v(0, -0.5, -0.85))
end

-- Edge for a diagonal swing that travels from `from` to `to`.
local function diagonal(shaft: Vector3, from: Vector3, to: Vector3): Vector3
	return swing(shaft, from:Cross(to).Unit)
end

local GS_FROM = v(-0.6, -0.5, -0.6)
local GS_TO = v(0.6, 0.7, -0.4)

return {
	prefix = "Aegis",
	stances = {
		SwordShield = {
			idle = swordReady(),
			run = shield(armed({}, v(0.3, -1, 0.4), v(0.1, -0.3, 1), DOWN), v(0.1, -1, -0.3)),
			armSwing = 0.25,
		},
		Greatsword = {
			idle = greatReady(),
			run = armed({}, v(0.3, -1, 0.5), v(0.1, 0.5, 0.85), UP),
			armSwing = 0.15,
			twoHand = 1,
			twoHandRun = 0,
		},
	},
	clips = {
		-- Horizontal slash, right to left.
		M1_1 = {
			fadeIn = 0.04,
			fadeOut = 0.2,
			keyframes = {
				{
					t = 0.1,
					ease = "Quad.Out",
					pose = armed(
						{ Root = T(8, 45, 0, 0, -0.2, 0), Neck = H(0, -30, 0) },
						v(0.95, 0.1, 0.2),
						v(0.85, 0.15, 0.5),
						swing(v(0.85, 0.15, 0.5), UP)
					),
				},
				{
					t = 0.2,
					ease = "Expo.Out",
					pose = armed({
						Root = T(14, -30, 0, 0, -0.3, -0.2),
						Neck = H(4, 20, 0),
						RightLeg = RL(-22, 10),
						LeftLeg = LL(26, 8),
					}, v(-0.2, 0, -1), v(-0.3, 0.05, -1), swing(v(-0.3, 0.05, -1), UP)),
				},
				{
					t = 0.3,
					ease = "Quad.Out",
					pose = armed(
						{ Root = T(10, -55, 0, 0, -0.25, 0), Neck = H(4, 36, 0) },
						v(-0.8, -0.2, -0.4),
						v(-0.95, 0, 0.2),
						swing(v(-0.95, 0, 0.2), UP)
					),
				},
				{ t = 0.5, ease = "Sine.InOut", pose = swordReady() },
			},
			markers = {
				{ t = 0.09, name = "TrailOn" },
				{ t = 0.1, name = "Swing" },
				{ t = 0.14, name = "Lunge", data = 14 },
				{ t = 0.19, name = "Hit" },
				{ t = 0.28, name = "TrailOff" },
				{ t = 0.3, name = "Chain" },
			},
		},
		-- Backhand, left to right.
		M1_2 = {
			fadeIn = 0.04,
			fadeOut = 0.2,
			keyframes = {
				{
					t = 0.1,
					ease = "Quad.Out",
					pose = armed(
						{ Root = T(10, -45, 0, 0, -0.25, 0), Neck = H(2, 30, 0) },
						v(-0.7, 0, -0.6),
						v(-0.9, 0.1, -0.2),
						swing(v(-0.9, 0.1, -0.2), DOWN)
					),
				},
				{
					t = 0.2,
					ease = "Expo.Out",
					pose = armed({
						Root = T(12, 30, 0, 0, -0.3, 0),
						Neck = H(4, -20, 0),
						RightLeg = RL(-20, 12),
						LeftLeg = LL(24, 8),
					}, v(0.4, 0.15, -1), v(0.4, 0.3, -0.9), swing(v(0.4, 0.3, -0.9), DOWN)),
				},
				{
					t = 0.3,
					ease = "Quad.Out",
					pose = armed(
						{ Root = T(8, 50, 0, 0, -0.2, 0), Neck = H(2, -32, 0) },
						v(0.95, 0.2, 0),
						v(0.9, 0.35, 0.3),
						swing(v(0.9, 0.35, 0.3), DOWN)
					),
				},
				{ t = 0.5, ease = "Sine.InOut", pose = swordReady() },
			},
			markers = {
				{ t = 0.09, name = "TrailOn" },
				{ t = 0.1, name = "Swing" },
				{ t = 0.14, name = "Lunge", data = 14 },
				{ t = 0.19, name = "Hit" },
				{ t = 0.28, name = "TrailOff" },
				{ t = 0.3, name = "Chain" },
			},
		},
		-- Lunging thrust.
		M1_3 = {
			fadeIn = 0.04,
			fadeOut = 0.2,
			keyframes = {
				{
					t = 0.12,
					ease = "Quad.Out",
					pose = armed(
						{ Root = T(4, 32, 0, 0, -0.25, 0), Neck = H(0, -24, 0) },
						v(0.6, -0.4, 0.5),
						v(0, 0.1, -1),
						DOWN
					),
				},
				{
					t = 0.22,
					ease = "Expo.Out",
					pose = armed({
						Root = T(22, 6, 0, 0, -0.45, -0.4),
						Neck = H(4, -4, 0),
						RightLeg = RL(-32, 10),
						LeftLeg = LL(38, 8),
					}, v(0.05, 0.05, -1), v(0, 0.05, -1), DOWN),
				},
				{ t = 0.52, ease = "Sine.InOut", pose = swordReady() },
			},
			markers = {
				{ t = 0.12, name = "TrailOn" },
				{ t = 0.13, name = "Swing" },
				{ t = 0.17, name = "Lunge", data = 26 },
				{ t = 0.21, name = "Hit" },
				{ t = 0.3, name = "TrailOff" },
				{ t = 0.32, name = "Chain" },
			},
		},
		-- Shield bash (posture breaker, ends the string).
		M1_4 = {
			fadeIn = 0.04,
			fadeOut = 0.24,
			keyframes = {
				{
					t = 0.12,
					ease = "Quad.Out",
					pose = shield(
						armed(
							{ Root = T(-4, 36, 0, 0, -0.1, 0), Neck = H(0, -26, 0) },
							v(0.5, -0.8, 0.3),
							v(0.1, 0.6, -0.8),
							v(0, -0.7, -0.6)
						),
						v(0.35, -0.3, -0.5)
					),
				},
				{
					t = 0.22,
					ease = "Expo.Out",
					pose = shield({
						Root = T(20, -12, 0, 0, -0.35, -0.5),
						Neck = H(8, 6, 0),
						RightLeg = RL(-30, 10),
						LeftLeg = LL(36, 8),
					}, v(0.05, 0, -1)),
				},
				{ t = 0.56, ease = "Sine.InOut", pose = swordReady() },
			},
			markers = {
				{ t = 0.12, name = "Swing", data = "Heavy" },
				{ t = 0.16, name = "Lunge", data = 34 },
				{ t = 0.21, name = "Hit" },
				{ t = 0.22, name = "Shake", data = 0.25 },
				{ t = 0.4, name = "Chain" },
			},
		},
		-- Bulwark Charge: brace behind the shield and charge through the guard.
		Critical = {
			fadeIn = 0.05,
			fadeOut = 0.28,
			keyframes = {
				{
					t = 0.15,
					ease = "Quad.Out",
					pose = shield(
						armed({
							Root = T(24, 12, 0, 0, -0.6, 0),
							Neck = H(14, -8, 0),
							RightLeg = RL(-26, 12),
							LeftLeg = LL(26, 10),
						}, v(0.5, -0.8, 0.4), v(0.1, 0.5, -0.85), v(0, -0.7, -0.6)),
						v(0.1, 0.1, -1)
					),
				},
				{
					t = 0.3,
					ease = "Linear",
					pose = { Root = T(30, 4, 0, 0, -0.5, 0), RightLeg = RL(-34, 10), LeftLeg = LL(30, 8) },
				},
				{
					t = 0.42,
					ease = "Expo.Out",
					pose = shield(
						{ Root = T(16, -12, 0, 0, -0.35, -0.4), RightLeg = RL(-30, 10), LeftLeg = LL(38, 8) },
						v(0.05, 0.05, -1)
					),
				},
				{ t = 0.8, ease = "Sine.InOut", pose = swordReady() },
			},
			markers = {
				{ t = 0.06, name = "Glint" },
				{ t = 0.22, name = "Lunge", data = 72 },
				{ t = 0.23, name = "Step" },
				{ t = 0.41, name = "Hit" },
				{ t = 0.42, name = "Shake", data = 0.4 },
				{ t = 0.62, name = "Chain" },
			},
		},
		SwordShield_Block = {
			looped = true,
			fadeIn = 0.05,
			keyframes = {
				{
					t = 0,
					pose = shield(
						armed({
							Root = T(12, 10, 0, 0, -0.35, 0),
							Neck = H(12, -6, 0),
							RightLeg = RL(-16, 12),
							LeftLeg = LL(18, 10),
						}, v(0.5, -0.8, 0.2), v(0.2, 0.5, -0.8), v(0, -0.7, -0.6)),
						v(0.35, 0.25, -1)
					),
				},
				{ t = 0.8, ease = "Sine.InOut", pose = { Root = T(13, 10, 0, 0, -0.38, 0) } },
				{ t = 1.6, ease = "Sine.InOut", pose = { Root = T(12, 10, 0, 0, -0.35, 0) } },
			},
		},

		--[[ GREATSWORD ]]

		GS_M1_1 = {
			fadeIn = 0.05,
			fadeOut = 0.24,
			keyframes = {
				{
					t = 0.22,
					ease = "Back.Out",
					pose = armed({
						Root = T(4, 60, 0, 0, -0.3, 0),
						Neck = H(0, -40, 0),
						RightLeg = RL(-20, 14),
						LeftLeg = LL(22, 12),
					}, v(0.9, 0.2, 0.4), v(0.7, 0.3, 0.7), swing(v(0.7, 0.3, 0.7), UP)),
				},
				{
					t = 0.34,
					ease = "Expo.Out",
					pose = armed({
						Root = T(18, -35, 0, 0, -0.4, -0.3),
						Neck = H(6, 25, 0),
						RightLeg = RL(-28, 12),
						LeftLeg = LL(32, 10),
					}, v(-0.3, 0, -1), v(-0.35, 0.1, -1), swing(v(-0.35, 0.1, -1), UP)),
				},
				{
					t = 0.48,
					ease = "Quad.Out",
					pose = armed(
						{ Root = T(14, -70, 0, 0, -0.35, -0.2), Neck = H(4, 45, 0) },
						v(-0.85, -0.2, -0.2),
						v(-0.9, 0.05, 0.4),
						swing(v(-0.9, 0.05, 0.4), UP)
					),
				},
				{ t = 0.82, ease = "Sine.InOut", pose = greatReady() },
			},
			markers = {
				{ t = 0.22, name = "TrailOn" },
				{ t = 0.25, name = "Swing", data = "Heavy" },
				{ t = 0.27, name = "Lunge", data = 20 },
				{ t = 0.33, name = "Hit" },
				{ t = 0.46, name = "TrailOff" },
				{ t = 0.52, name = "Chain" },
			},
		},
		GS_M1_2 = {
			fadeIn = 0.05,
			fadeOut = 0.24,
			keyframes = {
				{
					t = 0.2,
					ease = "Back.Out",
					pose = armed({
						Root = T(16, -45, 0, 0, -0.4, 0),
						Neck = H(4, 30, 0),
						RightLeg = RL(-18, 12),
						LeftLeg = LL(24, 10),
					}, v(-0.6, -0.8, -0.2), GS_FROM, diagonal(GS_FROM, GS_FROM, GS_TO)),
				},
				{
					t = 0.32,
					ease = "Expo.Out",
					pose = armed({
						Root = T(-6, 30, 0, 0, -0.1, 0),
						Neck = H(-10, -20, 0),
						RightLeg = RL(-12, 14),
						LeftLeg = LL(16, 10),
					}, v(0.6, 0.6, -0.6), GS_TO, diagonal(GS_TO, GS_FROM, GS_TO)),
				},
				{
					t = 0.46,
					ease = "Quad.Out",
					pose = armed(
						{ Root = T(-8, 45, 0, 0, -0.1, 0), Neck = H(-6, -30, 0) },
						v(0.8, 0.7, 0.1),
						v(0.4, 0.85, 0.35),
						diagonal(v(0.4, 0.85, 0.35), GS_FROM, GS_TO)
					),
				},
				{ t = 0.8, ease = "Sine.InOut", pose = greatReady() },
			},
			markers = {
				{ t = 0.2, name = "TrailOn" },
				{ t = 0.23, name = "Swing", data = "Heavy" },
				{ t = 0.26, name = "Lunge", data = 18 },
				{ t = 0.31, name = "Hit" },
				{ t = 0.44, name = "TrailOff" },
				{ t = 0.5, name = "Chain" },
			},
		},
		-- Overhead slam, cannot be interrupted.
		GS_M1_3 = {
			fadeIn = 0.05,
			fadeOut = 0.28,
			keyframes = {
				{
					t = 0.28,
					ease = "Back.Out",
					pose = armed({
						Root = T(-18, 8, 0, 0, 0.1, 0),
						Neck = H(-14, -6, 0),
						RightLeg = RL(-8, 10),
						LeftLeg = LL(16, 8),
					}, v(0.2, 1, 0.2), v(0.05, 0.4, 0.9), swing(v(0.05, 0.4, 0.9), CHOP)),
				},
				{
					t = 0.4,
					ease = "Expo.Out",
					pose = armed({
						Root = T(34, 0, 0, 0, -0.7, -0.4),
						Neck = H(-16, 0, 0),
						RightLeg = RL(-32, 12),
						LeftLeg = LL(38, 8),
					}, v(0.05, -0.4, -1), v(0, -0.45, -1), swing(v(0, -0.45, -1), CHOP)),
				},
				{ t = 0.56, ease = "Quad.Out", pose = { Root = T(30, 0, 0, 0, -0.65, -0.35) } },
				{ t = 0.96, ease = "Sine.InOut", pose = greatReady() },
			},
			markers = {
				{ t = 0.24, name = "TrailOn" },
				{ t = 0.28, name = "Swing", data = "Heavy" },
				{ t = 0.32, name = "Lunge", data = 28 },
				{ t = 0.39, name = "Hit" },
				{ t = 0.4, name = "Shake", data = 0.3 },
				{ t = 0.5, name = "TrailOff" },
				{ t = 0.66, name = "Chain" },
			},
		},
		-- Judgement: leap and cleave straight down.
		GS_Critical = {
			fadeIn = 0.05,
			fadeOut = 0.3,
			keyframes = {
				{
					t = 0.15,
					ease = "Quad.Out",
					pose = armed({
						Root = T(24, 10, 0, 0, -0.8, 0),
						Neck = H(-16, -6, 0),
						RightLeg = RL(-30, 12),
						LeftLeg = LL(30, 10),
					}, v(0.4, -0.5, 0.6), v(0.1, 0.3, 1), UP),
				},
				{
					t = 0.35,
					ease = "Quad.Out",
					pose = armed({
						Root = T(-20, 0, 0, 0, 0.8, 0),
						Neck = H(-20, 0, 0),
						RightLeg = RL(40, 8),
						LeftLeg = LL(10, 8),
					}, v(0.1, 1, 0.1), v(0, 0.3, 0.95), swing(v(0, 0.3, 0.95), CHOP)),
				},
				{
					t = 0.55,
					ease = "Expo.Out",
					pose = armed({
						Root = T(40, 0, 0, 0, -0.8, -0.6),
						Neck = H(-20, 0, 0),
						RightLeg = RL(-34, 12),
						LeftLeg = LL(40, 8),
					}, v(0.05, -0.45, -1), v(0, -0.5, -1), swing(v(0, -0.5, -1), CHOP)),
				},
				{ t = 1.0, ease = "Sine.InOut", pose = greatReady() },
			},
			markers = {
				{ t = 0.05, name = "Glint" },
				{ t = 0.3, name = "Lunge", data = 40 },
				{ t = 0.4, name = "TrailOn" },
				{ t = 0.46, name = "Swing", data = "Heavy" },
				{ t = 0.54, name = "Hit" },
				{ t = 0.55, name = "Shake", data = 0.45 },
				{ t = 0.66, name = "TrailOff" },
				{ t = 0.8, name = "Chain" },
			},
		},
		-- Blade held upright in front, flat toward the enemy.
		Greatsword_Block = {
			looped = true,
			fadeIn = 0.06,
			keyframes = {
				{
					t = 0,
					pose = armed({
						Root = T(10, 0, 0, 0, -0.3, 0),
						Neck = H(8, 0, 0),
						RightLeg = RL(-16, 12),
						LeftLeg = LL(18, 10),
					}, v(0, -0.3, -1), v(0, 1, -0.1), RIGHT, -0.4),
				},
				{ t = 0.9, ease = "Sine.InOut", pose = merge({}, { Root = T(11, 0, 0, 0, -0.33, 0) }) },
				{ t = 1.8, ease = "Sine.InOut", pose = { Root = T(10, 0, 0, 0, -0.3, 0) } },
			},
		},
	},
}
