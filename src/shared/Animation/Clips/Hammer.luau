--!nonstrict
--[[
	Thunder Hammer: wide, heavy two-handed swings with real weight (long anticipation, fast
	impact, slow recovery), an overhead area smash, the leaping Thunderclap critical, and a
	grenade launcher with a three-shot barrage.

	The off hand grips the haft automatically through two-hand reach.
]]

local Author = require(script.Parent.Parent.Author)

local T, H, RL, LL = Author.T, Author.H, Author.RL, Author.LL
local v, armed, swing = Author.v, Author.armed, Author.swing

local UP = v(0, 1, 0)
local DOWN = v(0, -1, 0)
local CHOP = v(-1, 0, 0)

-- Shouldered carry: haft over the right shoulder, head behind.
local function ready(): { [string]: CFrame }
	return armed({
		Root = T(6, 14, 0, 0, -0.15, 0),
		Neck = H(2, -12, 0),
		RightLeg = RL(-12, 12),
		LeftLeg = LL(14, 10),
	}, v(0.35, -0.45, -0.8), v(0.2, 0.55, 0.8), v(0, 0.6, -0.8))
end

local function launcherReady(): { [string]: CFrame }
	return armed({
		Root = T(4, 12, 0, 0, -0.1, 0),
		Neck = H(0, -10, 0),
		RightLeg = RL(-10, 10),
		LeftLeg = LL(12, 8),
	}, v(0.25, -1, -0.35), UP, v(0, -0.1, -1))
end

local function launcherAim(): { [string]: CFrame }
	return armed({
		Root = T(4, 14, 0, 0, -0.1, 0),
		Neck = H(6, -12, 8),
		RightLeg = RL(-12, 10),
		LeftLeg = LL(14, 8),
	}, v(0.1, -0.35, -1), UP, v(0, 0.05, -1), -0.2)
end

local function kick(time: number): { [string]: any }
	return {
		t = time,
		ease = "Expo.Out",
		pose = armed(
			{ Root = T(-8, 16, 0, 0, 0, 0.15), Neck = H(-4, -12, 6) },
			v(0.1, -0.1, -1),
			v(0, 1, 0.4),
			v(0, 0.45, -0.9),
			-0.3
		),
	}
end

return {
	prefix = "Hammer",
	stances = {
		Hammer = {
			idle = ready(),
			run = ready(),
			armSwing = 0.2,
			twoHand = 1,
			twoHandRun = 0,
		},
		Launcher = {
			idle = launcherReady(),
			run = armed({}, v(-0.1, -0.7, -0.7), v(0.2, 0.7, 0.6), v(-0.5, 0.6, -0.6)),
			armSwing = 0.15,
			twoHand = 1,
			twoHandRun = 0.5,
		},
	},
	clips = {
		-- Side swing, right to left.
		M1_1 = {
			fadeIn = 0.06,
			fadeOut = 0.26,
			keyframes = {
				{
					t = 0.22,
					ease = "Back.Out",
					pose = armed({
						Root = T(6, 60, 0, 0, -0.3, 0),
						Neck = H(0, -40, 0),
						RightLeg = RL(-22, 14),
						LeftLeg = LL(22, 12),
					}, v(0.95, -0.1, 0.35), v(0.7, 0.2, 0.7), swing(v(0.7, 0.2, 0.7), UP)),
				},
				{
					t = 0.34,
					ease = "Expo.Out",
					pose = armed({
						Root = T(16, -30, 0, 0, -0.45, -0.3),
						Neck = H(6, 22, 0),
						RightLeg = RL(-30, 12),
						LeftLeg = LL(32, 10),
					}, v(-0.2, 0.05, -1), v(-0.25, 0.1, -1), swing(v(-0.25, 0.1, -1), UP)),
				},
				{
					t = 0.48,
					ease = "Quad.Out",
					pose = armed(
						{ Root = T(12, -65, 0, 0, -0.4, -0.2), Neck = H(4, 42, 0) },
						v(-0.85, -0.3, -0.3),
						v(-0.9, 0, 0.4),
						swing(v(-0.9, 0, 0.4), UP)
					),
				},
				{ t = 0.84, ease = "Sine.InOut", pose = ready() },
			},
			markers = {
				{ t = 0.22, name = "TrailOn" },
				{ t = 0.26, name = "Swing", data = "Heavy" },
				{ t = 0.28, name = "Lunge", data = 18 },
				{ t = 0.33, name = "Hit" },
				{ t = 0.34, name = "Shake", data = 0.15 },
				{ t = 0.46, name = "TrailOff" },
				{ t = 0.55, name = "Chain" },
			},
		},
		-- Backswing, left to right.
		M1_2 = {
			fadeIn = 0.06,
			fadeOut = 0.26,
			keyframes = {
				{
					t = 0.2,
					ease = "Back.Out",
					pose = armed({
						Root = T(10, -50, 0, 0, -0.35, 0),
						Neck = H(2, 34, 0),
						RightLeg = RL(-18, 12),
						LeftLeg = LL(24, 12),
					}, v(-0.85, -0.1, -0.3), v(-0.9, 0.15, -0.1), swing(v(-0.9, 0.15, -0.1), DOWN)),
				},
				{
					t = 0.32,
					ease = "Expo.Out",
					pose = armed({
						Root = T(14, 30, 0, 0, -0.4, -0.2),
						Neck = H(4, -22, 0),
						RightLeg = RL(-26, 12),
						LeftLeg = LL(28, 10),
					}, v(0.3, 0.1, -1), v(0.35, 0.2, -1), swing(v(0.35, 0.2, -1), DOWN)),
				},
				{
					t = 0.46,
					ease = "Quad.Out",
					pose = armed(
						{ Root = T(10, 60, 0, 0, -0.35, 0), Neck = H(2, -40, 0) },
						v(0.9, 0, 0.2),
						v(0.9, 0.2, 0.4),
						swing(v(0.9, 0.2, 0.4), DOWN)
					),
				},
				{ t = 0.82, ease = "Sine.InOut", pose = ready() },
			},
			markers = {
				{ t = 0.2, name = "TrailOn" },
				{ t = 0.24, name = "Swing", data = "Heavy" },
				{ t = 0.26, name = "Lunge", data = 16 },
				{ t = 0.31, name = "Hit" },
				{ t = 0.32, name = "Shake", data = 0.15 },
				{ t = 0.44, name = "TrailOff" },
				{ t = 0.53, name = "Chain" },
			},
		},
		-- Overhead smash that shakes the ground (cannot be interrupted).
		M1_3 = {
			fadeIn = 0.06,
			fadeOut = 0.3,
			keyframes = {
				{
					t = 0.3,
					ease = "Back.Out",
					pose = armed({
						Root = T(-20, 8, 0, 0, 0.12, 0),
						Neck = H(-16, -6, 0),
						RightLeg = RL(-8, 10),
						LeftLeg = LL(16, 8),
					}, v(0.15, 1, 0.25), v(0, 0.35, 0.95), swing(v(0, 0.35, 0.95), CHOP)),
				},
				{
					t = 0.43,
					ease = "Expo.Out",
					pose = armed({
						Root = T(36, 0, 0, 0, -0.8, -0.4),
						Neck = H(-18, 0, 0),
						RightLeg = RL(-32, 14),
						LeftLeg = LL(38, 10),
					}, v(0.05, -0.5, -1), v(0, -0.55, -1), swing(v(0, -0.55, -1), CHOP)),
				},
				{ t = 0.6, ease = "Quad.Out", pose = { Root = T(32, 0, 0, 0, -0.75, -0.35) } },
				{ t = 1.0, ease = "Sine.InOut", pose = ready() },
			},
			markers = {
				{ t = 0.26, name = "TrailOn" },
				{ t = 0.3, name = "Swing", data = "Heavy" },
				{ t = 0.36, name = "Lunge", data = 22 },
				{ t = 0.42, name = "Hit" },
				{ t = 0.43, name = "Shake", data = 0.35 },
				{ t = 0.43, name = "Step" },
				{ t = 0.54, name = "TrailOff" },
				{ t = 0.7, name = "Chain" },
			},
		},
		-- Thunderclap: crouch, leap, and drive the hammer into the earth.
		Critical = {
			fadeIn = 0.06,
			fadeOut = 0.32,
			keyframes = {
				{
					t = 0.15,
					ease = "Quad.Out",
					pose = armed({
						Root = T(28, 0, 0, 0, -0.9, 0),
						Neck = H(-18, 0, 0),
						RightLeg = RL(-30, 14),
						LeftLeg = LL(30, 12),
					}, v(0.3, -0.6, 0.6), v(0.1, 0.2, 1), UP),
				},
				{
					t = 0.38,
					ease = "Quad.Out",
					pose = armed({
						Root = T(-22, 0, 0, 0, 1.2, 0),
						Neck = H(-22, 0, 0),
						RightLeg = RL(40, 8),
						LeftLeg = LL(30, 8),
					}, v(0.1, 1, 0.15), v(0, 0.5, 0.85), swing(v(0, 0.5, 0.85), CHOP)),
				},
				{
					t = 0.56,
					ease = "Expo.Out",
					pose = armed({
						Root = T(40, 0, 0, 0, -0.9, -0.5),
						Neck = H(-20, 0, 0),
						RightLeg = RL(-34, 14),
						LeftLeg = LL(40, 10),
					}, v(0.05, -0.55, -1), v(0, -0.6, -1), swing(v(0, -0.6, -1), CHOP)),
				},
				{ t = 0.75, ease = "Quad.Out", pose = { Root = T(36, 0, 0, 0, -0.85, -0.45) } },
				{ t = 1.05, ease = "Sine.InOut", pose = ready() },
			},
			markers = {
				{ t = 0.05, name = "Glint" },
				{ t = 0.3, name = "Lunge", data = 30 },
				{ t = 0.42, name = "TrailOn" },
				{ t = 0.46, name = "Swing", data = "Heavy" },
				{ t = 0.55, name = "Hit" },
				{ t = 0.55, name = "Sound", data = "Lightning" },
				{ t = 0.56, name = "Shake", data = 0.5 },
				{ t = 0.56, name = "Step" },
				{ t = 0.66, name = "TrailOff" },
				{ t = 0.85, name = "Chain" },
			},
		},
		-- Haft braced horizontally.
		Block = {
			looped = true,
			fadeIn = 0.06,
			keyframes = {
				{
					t = 0,
					pose = armed({
						Root = T(10, 8, 0, 0, -0.35, 0),
						Neck = H(8, -4, 0),
						RightLeg = RL(-16, 12),
						LeftLeg = LL(18, 10),
					}, v(0.4, -0.3, -1), v(-1, 0.2, 0), UP, -1.0),
				},
				{ t = 0.8, ease = "Sine.InOut", pose = { Root = T(11, 8, 0, 0, -0.38, 0) } },
				{ t = 1.6, ease = "Sine.InOut", pose = { Root = T(10, 8, 0, 0, -0.35, 0) } },
			},
		},

		--[[ LAUNCHER ]]

		Launcher_Aim = {
			looped = true,
			fadeIn = 0.12,
			keyframes = { { t = 0, pose = launcherAim() } },
		},
		Launcher_Block = {
			looped = true,
			fadeIn = 0.06,
			keyframes = {
				{
					t = 0,
					pose = armed({
						Root = T(10, 6, 0, 0, -0.3, 0),
						Neck = H(6, 0, 0),
						RightLeg = RL(-14, 12),
						LeftLeg = LL(16, 10),
					}, v(0.4, -0.3, -1), v(0, 1, 0.3), v(-1, 0.3, 0)),
				},
			},
		},
		Lob = {
			fadeIn = 0.04,
			fadeOut = 0.22,
			keyframes = {
				{ t = 0, pose = launcherAim() },
				kick(0.08),
				{ t = 0.45, ease = "Quad.Out", pose = launcherAim() },
			},
			markers = { { t = 0.06, name = "Shoot" }, { t = 0.3, name = "Chain" } },
		},
		-- Three grenades fanned across the field.
		Barrage = {
			fadeIn = 0.05,
			fadeOut = 0.25,
			keyframes = {
				{ t = 0, pose = launcherAim() },
				kick(0.12),
				{ t = 0.28, ease = "Quad.Out", pose = launcherAim() },
				kick(0.34),
				{ t = 0.5, ease = "Quad.Out", pose = launcherAim() },
				kick(0.56),
				{ t = 0.9, ease = "Sine.InOut", pose = launcherReady() },
			},
			markers = {
				{ t = 0.04, name = "Glint" },
				{ t = 0.1, name = "Shoot" },
				{ t = 0.32, name = "Shoot" },
				{ t = 0.54, name = "Shoot" },
				{ t = 0.7, name = "Chain" },
			},
		},
	},
}
