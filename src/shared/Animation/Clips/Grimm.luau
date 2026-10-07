--!nonstrict
--[[
	Creatures of Grimm. Beowolves rake with their claws and pounce; the Ursa mauls and rears up
	for a ground-shaking slam. Wind-ups are deliberately readable so Huntsmen can parry them;
	moves that cannot be parried flash a red glint first.

	Grimm move on the "Feral"/"Heavy" gaits (hunched, arms forward), which these poses build on.
]]

local Author = require(script.Parent.Parent.Author)

local T, H, RA, LA, RL, LL = Author.T, Author.H, Author.RA, Author.LA, Author.RL, Author.LL

local function prowl(): { [string]: CFrame }
	return {
		Root = T(32, 0, 0, 0, -0.3, 0),
		Neck = H(-30, 0, 0),
		RightArm = RA(38, 16, 0),
		LeftArm = LA(38, 16, 0),
		RightLeg = RL(-10, 10),
		LeftLeg = LL(12, 10),
	}
end

return {
	prefix = "Grimm",
	clips = {
		Swipe = {
			fadeIn = 0.08,
			fadeOut = 0.25,
			keyframes = {
				{ t = 0, pose = prowl() },
				{
					t = 0.26,
					ease = "Quad.Out",
					pose = {
						Root = T(8, 40, 0, 0, -0.1, 0),
						Neck = H(-26, -24, 0),
						RightArm = RA(150, 40, 0),
						LeftArm = LA(40, 30, 0),
						RightLeg = RL(-16, 12),
						LeftLeg = LL(16, 10),
					},
				},
				{
					t = 0.36,
					ease = "Expo.Out",
					pose = {
						Root = T(38, -32, 0, 0, -0.45, -0.3),
						Neck = H(-32, 14, 0),
						RightArm = RA(30, -14, 0),
						LeftArm = LA(20, 30, 0),
						RightLeg = RL(-24, 12),
						LeftLeg = LL(26, 10),
					},
				},
				{ t = 0.75, ease = "Sine.InOut", pose = prowl() },
			},
			markers = {
				{ t = 0.28, name = "Swing", data = "Heavy" },
				{ t = 0.3, name = "Lunge", data = 14 },
				{ t = 0.35, name = "Hit" },
				{ t = 0.5, name = "Chain" },
			},
		},
		DoubleSwipe = {
			fadeIn = 0.08,
			fadeOut = 0.25,
			keyframes = {
				{ t = 0, pose = prowl() },
				{
					t = 0.22,
					ease = "Quad.Out",
					pose = {
						Root = T(10, 36, 0, 0, -0.1, 0),
						Neck = H(-26, -20, 0),
						RightArm = RA(145, 40, 0),
						LeftArm = LA(30, 20, 0),
					},
				},
				{
					t = 0.32,
					ease = "Expo.Out",
					pose = {
						Root = T(34, -26, 0, 0, -0.4, -0.2),
						Neck = H(-30, 12, 0),
						RightArm = RA(30, -12, 0),
						LeftArm = LA(120, 40, 0),
					},
				},
				{
					t = 0.46,
					ease = "Quad.Out",
					pose = {
						Root = T(14, -40, 0, 0, -0.15, 0),
						Neck = H(-26, 24, 0),
						RightArm = RA(20, 20, 0),
						LeftArm = LA(150, 40, 0),
					},
				},
				{
					t = 0.58,
					ease = "Expo.Out",
					pose = {
						Root = T(40, 30, 0, 0, -0.45, -0.3),
						Neck = H(-32, -12, 0),
						RightArm = RA(20, 30, 0),
						LeftArm = LA(30, -12, 0),
						RightLeg = RL(-26, 12),
						LeftLeg = LL(28, 10),
					},
				},
				{ t = 1.0, ease = "Sine.InOut", pose = prowl() },
			},
			markers = {
				{ t = 0.24, name = "Swing" },
				{ t = 0.31, name = "Hit" },
				{ t = 0.48, name = "Swing", data = "Heavy" },
				{ t = 0.5, name = "Lunge", data = 16 },
				{ t = 0.57, name = "Hit" },
				{ t = 0.72, name = "Chain" },
			},
		},
		Pounce = {
			fadeIn = 0.08,
			fadeOut = 0.3,
			keyframes = {
				{ t = 0, pose = prowl() },
				{
					t = 0.28,
					ease = "Quad.Out",
					pose = {
						Root = T(42, 0, 0, 0, -0.9, 0),
						Neck = H(-34, 0, 0),
						RightArm = RA(-30, 20, 0),
						LeftArm = LA(-30, 20, 0),
						RightLeg = RL(-30, 12),
						LeftLeg = LL(30, 12),
					},
				},
				{
					t = 0.42,
					ease = "Quad.Out",
					pose = {
						Root = T(10, 0, 0, 0, 0.6, 0),
						Neck = H(-20, 0, 0),
						RightArm = RA(150, 20, 0),
						LeftArm = LA(150, 20, 0),
						RightLeg = RL(-40, 8),
						LeftLeg = LL(-30, 8),
					},
				},
				{
					t = 0.5,
					ease = "Expo.Out",
					pose = {
						Root = T(46, 0, 0, 0, -0.5, 0),
						Neck = H(-36, 0, 0),
						RightArm = RA(64, 14, 0),
						LeftArm = LA(64, 14, 0),
						RightLeg = RL(-20, 12),
						LeftLeg = LL(24, 12),
					},
				},
				{ t = 1.0, ease = "Sine.InOut", pose = prowl() },
			},
			markers = {
				{ t = 0.3, name = "Sound", data = "GrimmHowl" },
				{ t = 0.32, name = "Lunge", data = 48 },
				{ t = 0.49, name = "Hit" },
				{ t = 0.5, name = "Shake", data = 0.2 },
				{ t = 0.72, name = "Chain" },
			},
		},
		Maul = {
			fadeIn = 0.1,
			fadeOut = 0.3,
			keyframes = {
				{ t = 0, pose = prowl() },
				{
					t = 0.32,
					ease = "Quad.Out",
					pose = {
						Root = T(-15, 0, 0, 0, 0.2, 0),
						Neck = H(-30, 0, 0),
						RightArm = RA(160, 22, 0),
						LeftArm = LA(160, 22, 0),
						RightLeg = RL(-10, 12),
						LeftLeg = LL(14, 12),
					},
				},
				{
					t = 0.44,
					ease = "Expo.Out",
					pose = {
						Root = T(45, 0, 0, 0, -0.4, 0),
						Neck = H(-34, 0, 0),
						RightArm = RA(40, 10, 0),
						LeftArm = LA(40, 10, 0),
						RightLeg = RL(-24, 12),
						LeftLeg = LL(26, 12),
					},
				},
				{ t = 1.0, ease = "Sine.InOut", pose = prowl() },
			},
			markers = {
				{ t = 0.34, name = "Swing", data = "Heavy" },
				{ t = 0.36, name = "Lunge", data = 16 },
				{ t = 0.43, name = "Hit" },
				{ t = 0.44, name = "Shake", data = 0.3 },
				{ t = 0.7, name = "Chain" },
			},
		},
		-- Ursa rears up on its hind legs and slams the ground (unparryable).
		Slam = {
			fadeIn = 0.1,
			fadeOut = 0.35,
			keyframes = {
				{ t = 0, pose = prowl() },
				{
					t = 0.5,
					ease = "Quad.Out",
					pose = {
						Root = T(-25, 0, 0, 0, 0.6, 0),
						Neck = H(-34, 0, 0),
						RightArm = RA(170, 30, 0),
						LeftArm = LA(170, 30, 0),
						RightLeg = RL(-6, 12),
						LeftLeg = LL(8, 12),
					},
				},
				{
					t = 0.62,
					ease = "Expo.Out",
					pose = {
						Root = T(55, 0, 0, 0, -0.8, 0),
						Neck = H(-40, 0, 0),
						RightArm = RA(80, 10, 0),
						LeftArm = LA(80, 10, 0),
						RightLeg = RL(-26, 14),
						LeftLeg = LL(28, 14),
					},
				},
				{ t = 1.3, ease = "Sine.InOut", pose = prowl() },
			},
			markers = {
				{ t = 0.15, name = "Glint", data = "Red" },
				{ t = 0.2, name = "Sound", data = "GrimmHowl" },
				{ t = 0.61, name = "Hit" },
				{ t = 0.62, name = "Shake", data = 0.5 },
				{ t = 0.62, name = "Step" },
				{ t = 0.9, name = "Chain" },
			},
		},
	},
}
