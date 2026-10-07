--!nonstrict
--[[
	Crescent Scythe animations: reaping sweeps, a spinning third hit, an overhead finisher,
	the leaping "Reaper's Waltz" critical, and the sniper form's aim, shot and Recoil Rush.

	Weapon poses use Author.armed(pose, reach, shaft, edge): `shaft` is where the scythe's pole
	points (toward the blade head), `edge` where the blade points. Two-hand reach keeps the off
	hand on the pole. In Rifle form, `edge` is the barrel and `shaft` is "up" for the rifle.
]]

local Author = require(script.Parent.Parent.Author)

local T, H, RL, LL = Author.T, Author.H, Author.RL, Author.LL
local v, armed, swing = Author.v, Author.armed, Author.swing

local UP = v(0, 1, 0)
local CHOP = v(-1, 0, 0)

-- Ready stance: pole angled up across the body, blade hanging forward like a reaper.
local function ready(): { [string]: CFrame }
	return armed({
		Root = T(6, 25, 0, 0, -0.15, 0),
		Neck = H(-4, -22, 0),
		RightLeg = RL(-14, 10),
		LeftLeg = LL(16, 8),
	}, v(0.25, -1, -0.5), v(-0.35, 0.85, -0.45), v(0.2, -0.3, -1))
end

local function rifleReady(): { [string]: CFrame }
	return armed({
		Root = T(4, 12, 0),
		Neck = H(0, -10, 0),
		RightLeg = RL(-8, 6),
		LeftLeg = LL(10, 6),
	}, v(0.2, -1, -0.45), v(0, 1, 0.2), v(0.05, -0.45, -1))
end

local function rifleAim(): { [string]: CFrame }
	return armed({
		Root = T(4, 14, 0),
		Neck = H(6, -12, 8),
		RightLeg = RL(-12, 8),
		LeftLeg = LL(14, 8),
	}, v(0.05, -0.35, -1), v(0, 1, 0.05), v(0, 0.02, -1), -0.3)
end

return {
	prefix = "Scythe",
	stances = {
		Scythe = {
			idle = ready(),
			run = armed({ Root = T(0, 0, 0), Neck = H(0, 0, 0) }, v(0.25, -1, 0.65), v(0.1, 0.45, 1), v(0, -1, 0.25)),
			armSwing = 0.15,
			twoHand = 1,
			twoHandRun = 0,
		},
		Rifle = {
			idle = rifleReady(),
			run = armed({ Root = T(0, 0, 0) }, v(-0.2, -0.6, -0.8), v(0.3, 0.6, 0.6), v(-0.6, 0.55, -0.55)),
			armSwing = 0.1,
			twoHand = 1,
			twoHandRun = 0.4,
		},
	},
	clips = {
		-- Right-to-left reaping sweep at chest height.
		M1_1 = {
			fadeIn = 0.06,
			fadeOut = 0.22,
			keyframes = {
				{ t = 0, pose = ready() },
				{
					t = 0.13,
					ease = "Quad.Out",
					pose = armed({
						Root = T(10, 55, -4, 0, -0.2, 0),
						Neck = H(0, -40, 0),
						RightLeg = RL(-22, 14),
						LeftLeg = LL(20, 10),
					}, v(0.9, -0.3, 0.45), v(0.6, 0.12, 0.8), swing(v(0.6, 0.12, 0.8), UP)),
				},
				{
					t = 0.24,
					ease = "Expo.Out",
					pose = armed({
						Root = T(16, -35, 6, 0, -0.3, -0.3),
						Neck = H(6, 25, 0),
						RightLeg = RL(-26, 12),
						LeftLeg = LL(30, 8),
					}, v(-0.35, 0.05, -1), v(-0.2, 0.1, -1), swing(v(-0.2, 0.1, -1), UP)),
				},
				{
					t = 0.36,
					ease = "Quad.Out",
					pose = armed({
						Root = T(12, -68, 4, 0, -0.25, -0.2),
						Neck = H(4, 45, 0),
					}, v(-0.9, -0.35, 0.25), v(-0.85, 0.1, 0.45), swing(v(-0.85, 0.1, 0.45), UP)),
				},
				{ t = 0.58, ease = "Sine.InOut", pose = ready() },
			},
			markers = {
				{ t = 0.12, name = "TrailOn" },
				{ t = 0.14, name = "Swing" },
				{ t = 0.2, name = "Lunge", data = 18 },
				{ t = 0.23, name = "Hit" },
				{ t = 0.34, name = "TrailOff" },
				{ t = 0.35, name = "Chain" },
			},
		},
		-- Rising backhand from low left to high right.
		M1_2 = {
			fadeIn = 0.05,
			fadeOut = 0.22,
			keyframes = {
				{
					t = 0.12,
					ease = "Quad.Out",
					pose = armed({
						Root = T(14, -45, 6, 0, -0.35, 0),
						Neck = H(4, 30, 0),
						RightLeg = RL(-18, 12),
						LeftLeg = LL(24, 8),
					}, v(-0.7, -0.8, -0.3), v(-0.75, -0.35, -0.4), v(0.3, -0.5, -0.8)),
				},
				{
					t = 0.23,
					ease = "Expo.Out",
					pose = armed({
						Root = T(-6, 30, -8, 0, -0.1, 0),
						Neck = H(-10, -20, 0),
						RightLeg = RL(-10, 16),
						LeftLeg = LL(14, 8),
					}, v(0.7, 0.45, -0.6), v(0.55, 0.65, -0.5), v(0.5, -0.1, 0.85)),
				},
				{
					t = 0.35,
					ease = "Quad.Out",
					pose = armed({
						Root = T(-8, 48, -6, 0, -0.1, 0),
						Neck = H(-6, -30, 0),
					}, v(0.85, 0.6, 0.2), v(0.45, 0.75, 0.45), v(0.4, -0.5, 0.8)),
				},
				{ t = 0.56, ease = "Sine.InOut", pose = ready() },
			},
			markers = {
				{ t = 0.1, name = "TrailOn" },
				{ t = 0.13, name = "Swing" },
				{ t = 0.18, name = "Lunge", data = 16 },
				{ t = 0.22, name = "Hit" },
				{ t = 0.33, name = "TrailOff" },
				{ t = 0.34, name = "Chain" },
			},
		},
		-- Full spin with the blade held wide: hits all around.
		M1_3 = {
			fadeIn = 0.05,
			fadeOut = 0.22,
			legSpace = "Torso",
			keyframes = {
				{
					t = 0.1,
					ease = "Quad.Out",
					pose = armed({
						Root = T(8, 40, 0, 0, -0.3, 0),
						Neck = H(0, 0, 0),
						RightLeg = RL(-10, 14),
						LeftLeg = LL(10, 14),
					}, v(1, -0.1, 0.2), v(1, 0.05, 0.3), v(0, 0, -1)),
				},
				{
					t = 0.2,
					ease = "Linear",
					pose = armed({ Root = T(14, -60, 0, 0, -0.45, 0) }, v(1, -0.05, 0), v(1, 0, 0), v(0, 0, -1)),
				},
				{
					t = 0.28,
					ease = "Linear",
					pose = armed({ Root = T(14, -170, 0, 0, -0.45, 0) }, v(1, -0.05, 0), v(1, 0, 0), v(0, 0, -1)),
				},
				{
					t = 0.36,
					ease = "Linear",
					pose = armed({ Root = T(14, -280, 0, 0, -0.45, 0) }, v(1, -0.05, 0), v(1, 0, 0), v(0, 0, -1)),
				},
				{
					t = 0.44,
					ease = "Quad.Out",
					pose = armed(
						{ Root = T(10, -350, 0, 0, -0.3, 0) },
						v(1, -0.2, -0.2),
						v(0.9, 0.1, -0.3),
						v(-0.3, 0, -1)
					),
				},
				{ t = 0.62, ease = "Sine.InOut", pose = ready() },
			},
			markers = {
				{ t = 0.1, name = "TrailOn" },
				{ t = 0.12, name = "Swing" },
				{ t = 0.27, name = "Hit" },
				{ t = 0.42, name = "TrailOff" },
				{ t = 0.43, name = "Chain" },
			},
		},
		-- Overhead reap that slams the blade into the ground (combo finisher).
		M1_4 = {
			fadeIn = 0.06,
			fadeOut = 0.25,
			keyframes = {
				{
					t = 0.2,
					ease = "Back.Out",
					pose = armed({
						Root = T(-16, 12, 0, 0, 0.05, 0),
						Neck = H(-14, -8, 0),
						RightLeg = RL(-8, 8),
						LeftLeg = LL(18, 6),
					}, v(0.3, 1, 0.15), v(0.05, 0.55, 0.85), swing(v(0.05, 0.55, 0.85), CHOP)),
				},
				{
					t = 0.32,
					ease = "Expo.Out",
					pose = armed({
						Root = T(32, 0, 0, 0, -0.55, -0.4),
						Neck = H(-18, 0, 0),
						RightLeg = RL(-30, 12),
						LeftLeg = LL(36, 6),
					}, v(0.1, -0.35, -1), v(0, -0.35, -1), swing(v(0, -0.35, -1), CHOP)),
				},
				{
					t = 0.46,
					ease = "Quad.Out",
					pose = armed({
						Root = T(26, 0, 0, 0, -0.5, -0.3),
						Neck = H(-14, 0, 0),
					}, v(0.1, -0.45, -1), v(0, -0.45, -1), swing(v(0, -0.45, -1), CHOP)),
				},
				{ t = 0.8, ease = "Sine.InOut", pose = ready() },
			},
			markers = {
				{ t = 0.16, name = "TrailOn" },
				{ t = 0.2, name = "Swing", data = "Heavy" },
				{ t = 0.24, name = "Lunge", data = 34 },
				{ t = 0.31, name = "Hit" },
				{ t = 0.32, name = "Shake", data = 0.25 },
				{ t = 0.4, name = "TrailOff" },
				{ t = 0.5, name = "Chain" },
			},
		},
		-- Reaper's Waltz: crouch, leaping spin (launches), then an overhead slam.
		Critical = {
			fadeIn = 0.06,
			fadeOut = 0.3,
			legSpace = "Torso",
			keyframes = {
				{
					t = 0.14,
					ease = "Quad.Out",
					pose = armed({
						Root = T(26, 30, 0, 0, -0.9, 0),
						Neck = H(-20, -20, 0),
						RightLeg = RL(40, 10),
						LeftLeg = LL(-30, 10),
					}, v(0.8, -0.6, 0.4), v(0.7, 0.2, 0.7), v(0.6, 0, -0.8)),
				},
				{
					t = 0.3,
					ease = "Quad.In",
					pose = armed({
						Root = T(4, -60, 0, 0, 0.4, 0),
						RightLeg = RL(30, 6),
						LeftLeg = LL(-10, 6),
					}, v(1, 0.1, 0), v(1, 0.05, 0), v(0, 0, -1)),
				},
				{
					t = 0.38,
					ease = "Linear",
					pose = armed({ Root = T(4, -180, 0, 0, 0.6, 0) }, v(1, 0.1, 0), v(1, 0.05, 0), v(0, 0, -1)),
				},
				{
					t = 0.46,
					ease = "Linear",
					pose = armed({ Root = T(4, -300, 0, 0, 0.6, 0) }, v(1, 0.1, 0), v(1, 0.05, 0), v(0, 0, -1)),
				},
				{
					t = 0.6,
					ease = "Quad.Out",
					pose = armed({
						Root = T(-20, -360, 0, 0, 0.5, 0),
						Neck = H(-16, 0, 0),
						RightLeg = RL(10, 6),
						LeftLeg = LL(-14, 6),
					}, v(0.3, 1, 0.1), v(0.05, 0.6, 0.8), swing(v(0.05, 0.6, 0.8), CHOP)),
				},
				{
					t = 0.75,
					ease = "Expo.Out",
					pose = armed({
						Root = T(34, -360, 0, 0, -0.6, 0),
						Neck = H(-20, 0, 0),
						RightLeg = RL(36, 10),
						LeftLeg = LL(-30, 10),
					}, v(0.1, -0.35, -1), v(0, -0.4, -1), swing(v(0, -0.4, -1), CHOP)),
				},
				{ t = 1.08, ease = "Sine.InOut", pose = ready() },
			},
			markers = {
				{ t = 0.05, name = "Glint" },
				{ t = 0.28, name = "TrailOn" },
				{ t = 0.3, name = "Swing" },
				{ t = 0.42, name = "Hit" },
				{ t = 0.58, name = "Swing", data = "Heavy" },
				{ t = 0.62, name = "Lunge", data = 30 },
				{ t = 0.74, name = "Hit" },
				{ t = 0.76, name = "Shake", data = 0.35 },
				{ t = 0.86, name = "TrailOff" },
				{ t = 0.9, name = "Chain" },
			},
		},
		-- Sniper shot: snap to the shoulder, fire, recoil.
		Shoot = {
			fadeIn = 0.04,
			fadeOut = 0.2,
			keyframes = {
				{ t = 0, pose = rifleAim() },
				{
					t = 0.08,
					ease = "Expo.Out",
					pose = armed({
						Root = T(-8, 18, 0, 0, 0, 0.2),
						Neck = H(-4, -14, 6),
						RightLeg = RL(-12, 8),
						LeftLeg = LL(14, 8),
					}, v(0.05, -0.1, -1), v(0, 1, 0.3), v(0, 0.3, -1), -0.5),
				},
				{ t = 0.4, ease = "Quad.Out", pose = rifleAim() },
			},
			markers = {
				{ t = 0.05, name = "Shoot" },
				{ t = 0.3, name = "Chain" },
			},
		},
		-- Recoil Rush: fire behind you to rocket forward into a slash with the folded blade.
		RecoilRush = {
			fadeIn = 0.05,
			fadeOut = 0.25,
			keyframes = {
				{
					t = 0.1,
					ease = "Quad.Out",
					pose = armed({
						Root = T(20, -20, 0, 0, -0.4, 0),
						Neck = H(-10, 16, 0),
						RightLeg = RL(-30, 10),
						LeftLeg = LL(30, 10),
					}, v(0.3, -0.6, 0.8), v(0, 1, 0), v(0.1, -0.3, 1)),
				},
				{
					t = 0.3,
					ease = "Expo.Out",
					pose = armed({
						Root = T(24, -40, 0, 0, -0.4, 0),
						Neck = H(-6, 30, 0),
						RightLeg = RL(-34, 14),
						LeftLeg = LL(36, 8),
					}, v(-0.6, -0.2, -0.8), v(0.4, 1, 0), v(-0.8, 0, -0.6)),
				},
				{ t = 0.7, ease = "Sine.InOut", pose = rifleReady() },
			},
			markers = {
				{ t = 0.05, name = "Glint" },
				{ t = 0.12, name = "Sound", data = "Sniper" },
				{ t = 0.13, name = "Lunge", data = 95 },
				{ t = 0.14, name = "Shake", data = 0.3 },
				{ t = 0.22, name = "TrailOn" },
				{ t = 0.28, name = "Hit" },
				{ t = 0.4, name = "TrailOff" },
				{ t = 0.5, name = "Chain" },
			},
		},
		-- Guard: the pole braced horizontally in front of the body.
		Block = {
			looped = true,
			fadeIn = 0.06,
			keyframes = {
				{
					t = 0,
					pose = armed({
						Root = T(8, 10, 0, 0, -0.3, 0),
						Neck = H(4, -8, 0),
						RightLeg = RL(-16, 12),
						LeftLeg = LL(18, 10),
					}, v(0.5, -0.4, -1), v(-1, 0.25, -0.1), v(0, 1, 0.2), -1.4),
				},
				{
					t = 0.8,
					ease = "Sine.InOut",
					pose = armed({
						Root = T(9, 10, 0, 0, -0.34, 0),
					}, v(0.5, -0.42, -1), v(-1, 0.27, -0.1), v(0, 1, 0.2), -1.4),
				},
				{
					t = 1.6,
					ease = "Sine.InOut",
					pose = armed(
						{ Root = T(8, 10, 0, 0, -0.3, 0) },
						v(0.5, -0.4, -1),
						v(-1, 0.25, -0.1),
						v(0, 1, 0.2),
						-1.4
					),
				},
			},
		},
		Rifle_Block = {
			looped = true,
			fadeIn = 0.06,
			keyframes = {
				{
					t = 0,
					pose = armed({
						Root = T(8, 6, 0, 0, -0.3, 0),
						Neck = H(4, 0, 0),
						RightLeg = RL(-14, 12),
						LeftLeg = LL(16, 10),
					}, v(0.4, -0.3, -1), v(0, 1, 0.3), v(-1, 0.3, 0)),
				},
			},
		},
		Rifle_Aim = {
			looped = true,
			fadeIn = 0.12,
			keyframes = {
				{ t = 0, pose = rifleAim() },
				{
					t = 1.2,
					ease = "Sine.InOut",
					pose = armed({ Root = T(5, 14, 0) }, v(0.05, -0.33, -1), v(0, 1, 0.05), v(0, 0.03, -1), -0.3),
				},
				{ t = 2.4, ease = "Sine.InOut", pose = rifleAim() },
			},
		},
	},
}
