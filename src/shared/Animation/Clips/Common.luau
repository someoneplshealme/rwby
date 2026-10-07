--!nonstrict
--[[
	Animations shared by every rig: guarding, parries, staggers, hit reactions, knock-downs,
	executions, movement (dodges, air dash, slide), the mecha-shift flourish, Semblance and
	Dust casts. Weapon files can override any of these by name (see CharacterAnimator).

	Clips that only animate some joints leave the rest to the layers below, e.g. hit reactions
	keep the weapon hold and the procedural legs.
]]

local Author = require(script.Parent.Parent.Author)

local T, H, RA, LA, RL, LL, RG = Author.T, Author.H, Author.RA, Author.LA, Author.RL, Author.LL, Author.RG
local v, point = Author.v, Author.point

local function kneel(lean: number, y: number): { [string]: CFrame }
	return {
		Root = T(lean, 0, 0, 0, y, 0),
		RightLeg = RL(-82, 8),
		LeftLeg = LL(-78, 8),
	}
end

return {
	prefix = "Common",
	clips = {
		--[[ GUARDING ]]

		Block = {
			looped = true,
			fadeIn = 0.06,
			keyframes = {
				{
					t = 0,
					pose = {
						Root = T(10, 4, 0, 0, -0.3, 0),
						Neck = H(10, 0, 0),
						RightArm = point("Right", v(-0.55, 0.35, -0.8)),
						LeftArm = point("Left", v(0.55, 0.3, -0.8)),
						RightLeg = RL(-14, 12),
						LeftLeg = LL(16, 10),
					},
				},
				{ t = 0.9, ease = "Sine.InOut", pose = { Root = T(12, 4, 0, 0, -0.34, 0) } },
				{ t = 1.8, ease = "Sine.InOut", pose = { Root = T(10, 4, 0, 0, -0.3, 0) } },
			},
		},
		-- Deflect: a sharp outward sweep of the weapon arm.
		Parry = {
			fadeIn = 0.03,
			fadeOut = 0.2,
			keyframes = {
				{ t = 0, pose = { Root = T(6, 10, 0), RightArm = RA(70, 20), Neck = H(4, 0, 0) } },
				{
					t = 0.07,
					ease = "Expo.Out",
					pose = { Root = T(-8, -24, 0, 0, 0.05, 0), RightArm = RA(120, 55, -20), Neck = H(-6, 14, 0) },
				},
				{ t = 0.35, ease = "Quad.Out", pose = { Root = T(4, 6, 0), RightArm = RA(60, 20), Neck = H(2, 0, 0) } },
			},
		},
		-- Getting parried: weapon knocked away, staggering back.
		Parried = {
			fadeIn = 0.04,
			fadeOut = 0.3,
			keyframes = {
				{
					t = 0.08,
					ease = "Expo.Out",
					pose = {
						Root = T(-20, 18, 0, 0, 0.05, 0.4),
						Neck = H(-22, 12, 0),
						RightArm = RA(150, 45, 0),
						LeftArm = LA(50, 60, 0),
						RightLeg = RL(-22, 12),
						LeftLeg = LL(16, 12),
					},
				},
				{
					t = 0.55,
					ease = "Quad.Out",
					pose = {
						Root = T(-8, 10, 0, 0, -0.05, 0.2),
						Neck = H(-6, 6, 0),
						RightArm = RA(100, 40, 0),
						LeftArm = LA(30, 40, 0),
					},
				},
				{
					t = 0.9,
					ease = "Sine.InOut",
					pose = { Root = T(4, 0, 0), Neck = H(0, 0, 0), RightArm = RA(30, 15), LeftArm = LA(15, 15) },
				},
			},
		},
		GuardBreak = {
			fadeIn = 0.03,
			fadeOut = 0.15,
			keyframes = {
				{
					t = 0.1,
					ease = "Expo.Out",
					pose = {
						Root = T(-22, 0, 0, 0, -0.1, 0.35),
						Neck = H(-26, 0, 0),
						RightArm = RA(70, 72, 0),
						LeftArm = LA(70, 72, 0),
						RightLeg = RL(-18, 12),
						LeftLeg = LL(20, 12),
					},
				},
				{
					t = 0.55,
					ease = "Quad.InOut",
					pose = {
						Root = T(24, 0, -6, 0, -0.35, 0),
						Neck = H(20, 0, 8),
						RightArm = RA(10, 14, 0),
						LeftArm = LA(5, 14, 0),
						RightLeg = RL(-8, 14),
						LeftLeg = LL(10, 14),
					},
				},
			},
		},
		-- Dazed after a guard break: hunched, arms limp, swaying.
		GuardBroken = {
			looped = true,
			fadeIn = 0.15,
			keyframes = {
				{
					t = 0,
					pose = {
						Root = T(24, 0, -6, 0, -0.35, 0),
						Neck = H(20, 0, 8),
						RightArm = RA(10, 14, 0),
						LeftArm = LA(5, 14, 0),
						RightLeg = RL(-8, 14),
						LeftLeg = LL(10, 14),
					},
				},
				{
					t = 0.6,
					ease = "Sine.InOut",
					pose = {
						Root = T(26, 0, 6, 0, -0.4, 0),
						Neck = H(24, 0, -8),
						RightArm = RA(5, 14),
						LeftArm = LA(12, 14),
					},
				},
				{
					t = 1.2,
					ease = "Sine.InOut",
					pose = {
						Root = T(24, 0, -6, 0, -0.35, 0),
						Neck = H(20, 0, 8),
						RightArm = RA(10, 14),
						LeftArm = LA(5, 14),
					},
				},
			},
		},
		-- Held through hitstun after the reaction clip finishes.
		Stunned = {
			looped = true,
			fadeIn = 0.1,
			keyframes = {
				{
					t = 0,
					pose = {
						Root = T(12, 0, 0, 0, -0.2, 0),
						Neck = H(12, 0, 0),
						RightArm = RA(18, 18),
						LeftArm = LA(18, 18),
					},
				},
				{ t = 0.5, ease = "Sine.InOut", pose = { Root = T(14, 0, 3, 0, -0.22, 0), Neck = H(14, 0, -4) } },
				{ t = 1, ease = "Sine.InOut", pose = { Root = T(12, 0, 0, 0, -0.2, 0), Neck = H(12, 0, 0) } },
			},
		},
		Aim = {
			looped = true,
			fadeIn = 0.12,
			keyframes = {
				{
					t = 0,
					pose = {
						Root = T(4, 12, 0),
						Neck = H(4, -12, 0),
						RightArm = RA(90, -4, 0),
						LeftArm = point("Left", v(0.75, -0.05, -1)),
					},
				},
			},
		},

		--[[ HIT REACTIONS ]]

		HitLight1 = {
			fadeIn = 0.02,
			fadeOut = 0.22,
			keyframes = {
				{
					t = 0.06,
					ease = "Expo.Out",
					pose = {
						Root = T(-14, 16, -8, 0, -0.05, 0),
						Neck = H(-22, 16, -10),
						RightArm = RA(32, 26),
						LeftArm = LA(12, 20),
					},
				},
				{
					t = 0.34,
					ease = "Quad.InOut",
					pose = { Root = T(6, 2, 0), Neck = H(4, 0, 0), RightArm = RA(18, 16), LeftArm = LA(14, 16) },
				},
			},
		},
		HitLight2 = {
			fadeIn = 0.02,
			fadeOut = 0.22,
			keyframes = {
				{
					t = 0.06,
					ease = "Expo.Out",
					pose = {
						Root = T(-12, -18, 8, 0, -0.05, 0),
						Neck = H(-20, -16, 10),
						RightArm = RA(14, 20),
						LeftArm = LA(30, 26),
					},
				},
				{
					t = 0.34,
					ease = "Quad.InOut",
					pose = { Root = T(6, -2, 0), Neck = H(4, 0, 0), RightArm = RA(16, 16), LeftArm = LA(18, 16) },
				},
			},
		},
		HitBack = {
			fadeIn = 0.02,
			fadeOut = 0.25,
			keyframes = {
				{
					t = 0.07,
					ease = "Expo.Out",
					pose = {
						Root = T(24, 0, 0, 0, -0.12, 0),
						Neck = H(22, 0, 0),
						RightArm = RA(-32, 16),
						LeftArm = LA(-32, 16),
					},
				},
				{
					t = 0.4,
					ease = "Quad.InOut",
					pose = { Root = T(8, 0, 0), Neck = H(6, 0, 0), RightArm = RA(10, 12), LeftArm = LA(10, 12) },
				},
			},
		},
		HitHeavy = {
			fadeIn = 0.02,
			fadeOut = 0.3,
			keyframes = {
				{
					t = 0.08,
					ease = "Expo.Out",
					pose = {
						Root = T(-30, 0, 0, 0, 0.1, 0.3),
						Neck = H(-32, 0, 0),
						RightArm = RA(72, 34),
						LeftArm = LA(66, 34),
						RightLeg = RL(28, 10),
						LeftLeg = LL(-4, 10),
					},
				},
				{
					t = 0.32,
					ease = "Quad.Out",
					pose = {
						Root = T(-12, 0, 0, 0, -0.1, 0),
						Neck = H(-12, 0, 0),
						RightArm = RA(40, 30),
						LeftArm = LA(36, 30),
						RightLeg = RL(10, 10),
						LeftLeg = LL(-10, 10),
					},
				},
				{
					t = 0.7,
					ease = "Sine.InOut",
					pose = {
						Root = T(10, 0, 0, 0, -0.15, 0),
						Neck = H(8, 0, 0),
						RightArm = RA(16, 16),
						LeftArm = LA(16, 16),
						RightLeg = RL(-8, 10),
						LeftLeg = LL(10, 10),
					},
				},
			},
		},
		KnockDown = {
			fadeIn = 0.04,
			fadeOut = 0.4,
			keyframes = {
				{
					t = 0.12,
					ease = "Quad.Out",
					pose = {
						Root = T(-18, 0, 10, 0, 0, 0.2),
						Neck = H(-24, 0, 0),
						RightArm = RA(40, 40),
						LeftArm = LA(30, 40),
						RightLeg = RL(10, 10),
						LeftLeg = LL(-14, 10),
					},
				},
				{
					t = 0.45,
					ease = "Bounce.Out",
					pose = Author.merge(
						kneel(34, -1.55),
						{ Neck = H(26, 0, 0), RightArm = RA(58, 10), LeftArm = LA(26, 22) }
					),
				},
			},
		},
		-- Down on both knees, one hand on the ground, breathing hard.
		Knocked = {
			looped = true,
			fadeIn = 0.3,
			keyframes = {
				{
					t = 0,
					pose = Author.merge(
						kneel(34, -1.55),
						{ Neck = H(26, 0, 0), RightArm = RA(58, 10), LeftArm = LA(26, 22) }
					),
				},
				{
					t = 0.7,
					ease = "Sine.InOut",
					pose = { Root = T(30, 0, 0, 0, -1.5, 0), Neck = H(18, 0, 0), LeftArm = LA(22, 24) },
				},
				{
					t = 1.4,
					ease = "Sine.InOut",
					pose = { Root = T(34, 0, 0, 0, -1.55, 0), Neck = H(26, 0, 0), LeftArm = LA(26, 22) },
				},
			},
		},
		-- Finishing blow on a knocked enemy.
		Execute = {
			fadeIn = 0.1,
			fadeOut = 0.35,
			keyframes = {
				{
					t = 0.45,
					ease = "Quad.Out",
					pose = {
						Root = T(-12, 0, 0, 0, 0.05, 0),
						Neck = H(-10, 0, 0),
						RightArm = RA(172, 6),
						LeftArm = LA(150, 10),
					},
				},
				{
					t = 0.62,
					ease = "Back.In",
					pose = {
						Root = T(-16, 0, 0, 0, 0.08, 0),
						RightArm = RA(178, 4),
						LeftArm = LA(160, 8),
					},
				},
				{
					t = 0.82,
					ease = "Expo.Out",
					pose = {
						Root = T(42, 0, 0, 0, -0.9, 0),
						Neck = H(20, 0, 0),
						RightArm = RA(20, 8),
						LeftArm = LA(26, 10),
						RightLeg = RL(-30, 10),
						LeftLeg = LL(40, 8),
					},
				},
				{
					t = 1.4,
					ease = "Sine.InOut",
					pose = {
						Root = T(6, 0, 0),
						Neck = H(0, 0, 0),
						RightArm = RA(20, 14),
						LeftArm = LA(14, 14),
						RightLeg = RL(-6, 6),
						LeftLeg = LL(8, 6),
					},
				},
			},
			markers = {
				{ t = 0.4, name = "Glint", data = "Red" },
				{ t = 0.66, name = "Swing", data = "Heavy" },
				{ t = 0.8, name = "Shake", data = 0.4 },
			},
		},
		Executed = {
			fadeIn = 0.1,
			fadeOut = 0.5,
			keyframes = {
				{
					t = 0,
					pose = Author.merge(
						kneel(34, -1.55),
						{ Neck = H(26, 0, 0), RightArm = RA(58, 10), LeftArm = LA(26, 22) }
					),
				},
				{ t = 0.55, ease = "Sine.InOut", pose = { Root = T(10, 0, 0, 0, -1.5, 0), Neck = H(-20, 0, 0) } },
				{
					t = 0.85,
					ease = "Quad.In",
					pose = {
						Root = T(84, 0, 0, 0, -2.5, -0.6),
						Neck = H(-10, 30, 0),
						RightArm = RA(150, 30),
						LeftArm = LA(120, 40),
						RightLeg = RL(-86, 6),
						LeftLeg = LL(-90, 10),
					},
				},
				{ t = 1.4, ease = "Quad.Out", pose = { Root = T(88, 0, 0, 0, -2.55, -0.6) } },
			},
		},

		-- Held after death (executions, Grimm finishing a Huntsman, slain Grimm before they dissolve).
		Dead = {
			looped = true,
			fadeIn = 0.35,
			keyframes = {
				{
					t = 0,
					pose = {
						Root = T(86, 0, 0, 0, -2.5, -0.6),
						Neck = H(-10, 30, 0),
						RightArm = RA(150, 30),
						LeftArm = LA(120, 40),
						RightLeg = RL(-86, 6),
						LeftLeg = LL(-90, 10),
					},
				},
			},
		},

		--[[ MOVEMENT ]]

		DodgeForward = {
			fadeIn = 0.03,
			fadeOut = 0.16,
			keyframes = {
				{
					t = 0.06,
					ease = "Quad.Out",
					pose = {
						Root = T(30, 0, 0, 0, -0.5, 0),
						Neck = H(-18, 0, 0),
						RightArm = RA(-44, 16),
						LeftArm = LA(-44, 16),
						RightLeg = RL(34, 6),
						LeftLeg = LL(-36, 6),
					},
				},
				{
					t = 0.24,
					ease = "Linear",
					pose = { Root = T(26, 0, 0, 0, -0.45, 0), RightLeg = RL(30, 6), LeftLeg = LL(-30, 6) },
				},
				{
					t = 0.34,
					ease = "Quad.Out",
					pose = {
						Root = T(8, 0, 0, 0, -0.1, 0),
						Neck = H(0, 0, 0),
						RightArm = RA(10, 14),
						LeftArm = LA(10, 14),
						RightLeg = RL(8, 6),
						LeftLeg = LL(-8, 6),
					},
				},
			},
			markers = { { t = 0.02, name = "Step" } },
		},
		DodgeBack = {
			fadeIn = 0.03,
			fadeOut = 0.16,
			keyframes = {
				{
					t = 0.07,
					ease = "Quad.Out",
					pose = {
						Root = T(-22, 0, 0, 0, 0.1, 0),
						Neck = H(-4, 0, 0),
						RightArm = RA(46, 22),
						LeftArm = LA(42, 22),
						RightLeg = RL(28, 8),
						LeftLeg = LL(-8, 8),
					},
				},
				{
					t = 0.24,
					ease = "Linear",
					pose = { Root = T(-18, 0, 0, 0, 0.05, 0), RightLeg = RL(24, 8), LeftLeg = LL(-12, 8) },
				},
				{
					t = 0.34,
					ease = "Quad.Out",
					pose = {
						Root = T(4, 0, 0),
						Neck = H(0, 0, 0),
						RightArm = RA(14, 14),
						LeftArm = LA(14, 14),
						RightLeg = RL(-6, 8),
						LeftLeg = LL(8, 8),
					},
				},
			},
			markers = { { t = 0.02, name = "Step" } },
		},
		DodgeLeft = {
			fadeIn = 0.03,
			fadeOut = 0.16,
			keyframes = {
				{
					t = 0.07,
					ease = "Quad.Out",
					pose = {
						Root = T(8, 0, -24, 0, -0.25, 0),
						Neck = H(0, 0, 14),
						RightArm = RA(20, 50),
						LeftArm = LA(-10, 30),
						RightLeg = RL(0, 34),
						LeftLeg = LL(0, 6),
					},
				},
				{ t = 0.24, ease = "Linear", pose = { Root = T(6, 0, -20, 0, -0.2, 0) } },
				{
					t = 0.34,
					ease = "Quad.Out",
					pose = {
						Root = T(4, 0, 0),
						Neck = H(0, 0, 0),
						RightArm = RA(10, 14),
						LeftArm = LA(10, 14),
						RightLeg = RL(0, 6),
						LeftLeg = LL(0, 6),
					},
				},
			},
			markers = { { t = 0.02, name = "Step" } },
		},
		DodgeRight = {
			fadeIn = 0.03,
			fadeOut = 0.16,
			keyframes = {
				{
					t = 0.07,
					ease = "Quad.Out",
					pose = {
						Root = T(8, 0, 24, 0, -0.25, 0),
						Neck = H(0, 0, -14),
						RightArm = RA(-10, 30),
						LeftArm = LA(20, 50),
						RightLeg = RL(0, 6),
						LeftLeg = LL(0, 34),
					},
				},
				{ t = 0.24, ease = "Linear", pose = { Root = T(6, 0, 20, 0, -0.2, 0) } },
				{
					t = 0.34,
					ease = "Quad.Out",
					pose = {
						Root = T(4, 0, 0),
						Neck = H(0, 0, 0),
						RightArm = RA(10, 14),
						LeftArm = LA(10, 14),
						RightLeg = RL(0, 6),
						LeftLeg = LL(0, 6),
					},
				},
			},
			markers = { { t = 0.02, name = "Step" } },
		},
		-- Tucked front flip.
		AirDash = {
			fadeIn = 0.03,
			fadeOut = 0.12,
			legSpace = "Torso",
			keyframes = {
				{
					t = 0,
					pose = {
						Root = T(0, 0, 0),
						RightLeg = RL(0, 4),
						LeftLeg = LL(0, 4),
						RightArm = RA(30, 30),
						LeftArm = LA(30, 30),
					},
				},
				{
					t = 0.08,
					ease = "Linear",
					pose = {
						Root = T(120, 0, 0),
						RightLeg = RL(80, 6),
						LeftLeg = LL(80, 6),
						RightArm = RA(60, 20),
						LeftArm = LA(60, 20),
					},
				},
				{ t = 0.16, ease = "Linear", pose = { Root = T(240, 0, 0) } },
				{
					t = 0.26,
					ease = "Quad.Out",
					pose = {
						Root = T(360, 0, 0),
						RightLeg = RL(10, 4),
						LeftLeg = LL(-10, 4),
						RightArm = RA(30, 40),
						LeftArm = LA(30, 40),
					},
				},
			},
		},
		Slide = {
			fadeIn = 0.05,
			fadeOut = 0.2,
			keyframes = {
				{
					t = 0.1,
					ease = "Quad.Out",
					pose = {
						Root = T(-52, 0, 0, 0, -1.3, 0),
						Neck = H(-36, 0, 0),
						RightArm = RA(-20, 34),
						LeftArm = LA(46, 30),
						RightLeg = RL(68, 4),
						LeftLeg = LL(30, 4),
					},
				},
				{ t = 0.5, ease = "Linear", pose = { Root = T(-48, 0, 0, 0, -1.25, 0) } },
				{
					t = 0.65,
					ease = "Quad.Out",
					pose = {
						Root = T(6, 0, 0, 0, -0.2, 0),
						Neck = H(0, 0, 0),
						RightArm = RA(10, 14),
						LeftArm = LA(10, 14),
						RightLeg = RL(8, 4),
						LeftLeg = LL(-8, 4),
					},
				},
			},
			markers = { { t = 0.05, name = "Step" } },
		},
		-- Cancelled attack: snap back to guard.
		Feint = {
			fadeIn = 0.02,
			fadeOut = 0.15,
			keyframes = {
				{ t = 0.06, ease = "Expo.Out", pose = { Root = T(-6, -8, 0, 0, 0.05, 0), Neck = H(-4, 6, 0) } },
				{ t = 0.28, ease = "Quad.Out", pose = { Root = T(4, 0, 0), Neck = H(0, 0, 0) } },
			},
			markers = { { t = 0.02, name = "Sound", data = "Whoosh" } },
		},
		-- Mecha-shift flourish: raise the weapon and twirl it around the wrist while it transforms.
		Shift = {
			fadeIn = 0.06,
			fadeOut = 0.2,
			keyframes = {
				{
					t = 0.08,
					ease = "Quad.Out",
					pose = {
						Root = T(-4, 10, 0),
						RightArm = RA(105, 18, 0),
						RightGrip = RG(0, 0, 0),
						LeftArm = LA(15, 26, 0),
						Neck = H(-6, -6, 0),
					},
				},
				{ t = 0.18, ease = "Linear", pose = { RightGrip = RG(0, 120, 0) } },
				{ t = 0.28, ease = "Linear", pose = { RightGrip = RG(0, 240, 0) } },
				{ t = 0.4, ease = "Quad.Out", pose = { RightGrip = RG(0, 360, 0), RightArm = RA(80, 16, 0) } },
				{
					t = 0.55,
					ease = "Sine.InOut",
					pose = { Root = T(4, 0, 0), RightArm = RA(30, 14, 0), LeftArm = LA(14, 14, 0), Neck = H(0, 0, 0) },
				},
			},
			markers = { { t = 0.05, name = "Sound", data = "Shift" } },
		},

		--[[ SEMBLANCES ]]

		SemblanceDash = {
			fadeIn = 0.03,
			fadeOut = 0.15,
			keyframes = {
				{
					t = 0.06,
					ease = "Quad.Out",
					pose = {
						Root = T(42, 0, 0, 0, -0.4, 0),
						Neck = H(-30, 0, 0),
						RightArm = RA(-62, 20),
						LeftArm = LA(-62, 20),
						RightLeg = RL(22, 6),
						LeftLeg = LL(-42, 6),
					},
				},
				{ t = 0.4, ease = "Linear", pose = { Root = T(38, 0, 0, 0, -0.35, 0) } },
				{
					t = 0.5,
					ease = "Quad.Out",
					pose = {
						Root = T(6, 0, 0),
						Neck = H(0, 0, 0),
						RightArm = RA(10, 14),
						LeftArm = LA(10, 14),
						RightLeg = RL(6, 4),
						LeftLeg = LL(-6, 4),
					},
				},
			},
		},
		SemblanceBlink = {
			fadeIn = 0.02,
			fadeOut = 0.15,
			keyframes = {
				{
					t = 0.05,
					ease = "Quad.Out",
					pose = {
						Root = T(22, 0, 0, 0, -0.6, 0),
						Neck = H(16, 0, 0),
						RightArm = RA(30, 6),
						LeftArm = LA(30, 6),
						RightLeg = RL(20, 4),
						LeftLeg = LL(-10, 4),
					},
				},
				{
					t = 0.3,
					ease = "Back.Out",
					pose = {
						Root = T(4, 0, 0),
						Neck = H(0, 0, 0),
						RightArm = RA(12, 16),
						LeftArm = LA(12, 16),
						RightLeg = RL(0, 4),
						LeftLeg = LL(0, 4),
					},
				},
			},
		},
		SemblanceIgnite = {
			fadeIn = 0.05,
			fadeOut = 0.3,
			keyframes = {
				{
					t = 0.18,
					ease = "Quad.Out",
					pose = {
						Root = T(28, 0, 0, 0, -0.5, 0),
						Neck = H(30, 0, 0),
						RightArm = RA(20, -10, 30),
						LeftArm = LA(20, -10, 30),
						RightLeg = RL(-10, 16),
						LeftLeg = LL(10, 16),
					},
				},
				{
					t = 0.32,
					ease = "Expo.Out",
					pose = {
						Root = T(-16, 0, 0, 0, 0.1, 0),
						Neck = H(-34, 0, 0),
						RightArm = RA(30, 80, 0),
						LeftArm = LA(30, 80, 0),
						RightLeg = RL(-8, 18),
						LeftLeg = LL(8, 18),
					},
				},
				{
					t = 0.6,
					ease = "Sine.InOut",
					pose = {
						Root = T(4, 0, 0),
						Neck = H(0, 0, 0),
						RightArm = RA(14, 16),
						LeftArm = LA(14, 16),
						RightLeg = RL(0, 6),
						LeftLeg = LL(0, 6),
					},
				},
			},
			markers = { { t = 0.3, name = "Cast" }, { t = 0.31, name = "Shake", data = 0.3 } },
		},
		SemblancePull = {
			fadeIn = 0.04,
			fadeOut = 0.25,
			keyframes = {
				{
					t = 0.14,
					ease = "Quad.Out",
					pose = {
						Root = T(4, 30, 0),
						Neck = H(0, -28, 0),
						LeftArm = LA(95, -10, 0),
						RightLeg = RL(-12, 10),
						LeftLeg = LL(16, 10),
					},
				},
				{ t = 0.22, ease = "Expo.Out", pose = { Root = T(8, 36, 0), LeftArm = LA(100, -14, 0) } },
				{ t = 0.4, ease = "Back.In", pose = { Root = T(-6, 10, 0), LeftArm = LA(40, 20, 0) } },
				{
					t = 0.55,
					ease = "Sine.InOut",
					pose = {
						Root = T(4, 0, 0),
						Neck = H(0, 0, 0),
						LeftArm = LA(14, 14),
						RightLeg = RL(0, 6),
						LeftLeg = LL(0, 6),
					},
				},
			},
			markers = { { t = 0.2, name = "Cast" } },
		},
		SemblanceGlyph = {
			fadeIn = 0.03,
			fadeOut = 0.2,
			keyframes = {
				{
					t = 0.06,
					ease = "Quad.Out",
					pose = {
						Root = T(20, 0, 0, 0, -0.6, 0),
						Neck = H(-10, 0, 0),
						RightArm = RA(-20, 20),
						LeftArm = LA(-20, 20),
						RightLeg = RL(20, 8),
						LeftLeg = LL(-10, 8),
					},
				},
				{
					t = 0.2,
					ease = "Expo.Out",
					pose = {
						Root = T(-8, 0, 0, 0, 0.2, 0),
						Neck = H(-24, 0, 0),
						RightArm = RA(160, 20),
						LeftArm = LA(140, 30),
						RightLeg = RL(-10, 6),
						LeftLeg = LL(-30, 6),
					},
				},
				{
					t = 0.45,
					ease = "Quad.Out",
					pose = {
						Root = T(0, 0, 0),
						Neck = H(0, 0, 0),
						RightArm = RA(30, 40),
						LeftArm = LA(30, 40),
						RightLeg = RL(14, 6),
						LeftLeg = LL(-14, 6),
					},
				},
			},
		},
		SemblanceHarden = {
			fadeIn = 0.04,
			fadeOut = 0.3,
			keyframes = {
				{
					t = 0.15,
					ease = "Quad.Out",
					pose = {
						Root = T(14, 0, 0, 0, -0.5, 0),
						Neck = H(14, 0, 0),
						RightArm = point("Right", v(-0.6, 0.2, -0.75)),
						LeftArm = point("Left", v(0.6, 0.25, -0.75)),
						RightLeg = RL(-6, 22),
						LeftLeg = LL(6, 22),
					},
				},
				{ t = 0.26, ease = "Expo.Out", pose = { Root = T(18, 0, 0, 0, -0.75, 0) } },
				{
					t = 0.6,
					ease = "Sine.InOut",
					pose = {
						Root = T(4, 0, 0),
						Neck = H(0, 0, 0),
						RightArm = RA(14, 14),
						LeftArm = LA(14, 14),
						RightLeg = RL(0, 6),
						LeftLeg = LL(0, 6),
					},
				},
			},
			markers = { { t = 0.25, name = "Cast" }, { t = 0.26, name = "Shake", data = 0.25 } },
		},

		--[[ DUST ]]

		CastFire = {
			fadeIn = 0.04,
			fadeOut = 0.25,
			keyframes = {
				{
					t = 0.14,
					ease = "Quad.Out",
					pose = {
						Root = T(4, -30, 0),
						Neck = H(0, 24, 0),
						LeftArm = LA(70, 70, 0),
						RightLeg = RL(-10, 12),
						LeftLeg = LL(14, 10),
					},
				},
				{
					t = 0.26,
					ease = "Expo.Out",
					pose = { Root = T(12, 30, 0, 0, -0.2, 0), Neck = H(4, -22, 0), LeftArm = LA(88, -24, 0) },
				},
				{
					t = 0.55,
					ease = "Sine.InOut",
					pose = {
						Root = T(4, 0, 0),
						Neck = H(0, 0, 0),
						LeftArm = LA(14, 14),
						RightLeg = RL(0, 6),
						LeftLeg = LL(0, 6),
					},
				},
			},
			markers = { { t = 0.24, name = "Cast" } },
		},
		CastIce = {
			fadeIn = 0.04,
			fadeOut = 0.25,
			keyframes = {
				{
					t = 0.16,
					ease = "Quad.Out",
					pose = {
						Root = T(-10, 0, 0, 0, 0.1, 0),
						Neck = H(-10, 0, 0),
						LeftArm = LA(150, 20),
						RightLeg = RL(40, 8),
						LeftLeg = LL(-4, 8),
					},
				},
				{
					t = 0.28,
					ease = "Expo.Out",
					pose = {
						Root = T(30, 0, 0, 0, -0.7, 0),
						Neck = H(20, 0, 0),
						LeftArm = LA(40, 10),
						RightLeg = RL(-6, 14),
						LeftLeg = LL(20, 10),
					},
				},
				{
					t = 0.6,
					ease = "Sine.InOut",
					pose = {
						Root = T(4, 0, 0),
						Neck = H(0, 0, 0),
						LeftArm = LA(14, 14),
						RightLeg = RL(0, 6),
						LeftLeg = LL(0, 6),
					},
				},
			},
			markers = { { t = 0.27, name = "Cast" }, { t = 0.28, name = "Shake", data = 0.2 } },
		},
		CastLightning = {
			fadeIn = 0.04,
			fadeOut = 0.22,
			keyframes = {
				{
					t = 0.12,
					ease = "Quad.Out",
					pose = {
						Root = T(-6, 40, 0),
						Neck = H(0, -34, 0),
						LeftArm = LA(-30, 30, 0),
						RightLeg = RL(-14, 10),
						LeftLeg = LL(18, 10),
					},
				},
				{
					t = 0.22,
					ease = "Expo.Out",
					pose = { Root = T(14, -16, 0, 0, -0.2, 0), Neck = H(0, 10, 0), LeftArm = LA(95, -6, 0) },
				},
				{
					t = 0.5,
					ease = "Sine.InOut",
					pose = {
						Root = T(4, 0, 0),
						Neck = H(0, 0, 0),
						LeftArm = LA(14, 14),
						RightLeg = RL(0, 6),
						LeftLeg = LL(0, 6),
					},
				},
			},
			markers = { { t = 0.2, name = "Cast" } },
		},
		CastGravity = {
			fadeIn = 0.04,
			fadeOut = 0.25,
			keyframes = {
				{
					t = 0.14,
					ease = "Quad.Out",
					pose = {
						Root = T(-12, 0, 0, 0, 0.15, 0),
						Neck = H(-24, 0, 0),
						RightArm = RA(165, 20),
						LeftArm = LA(165, 20),
					},
				},
				{
					t = 0.26,
					ease = "Expo.Out",
					pose = {
						Root = T(26, 0, 0, 0, -0.6, 0),
						Neck = H(20, 0, 0),
						RightArm = RA(40, 70),
						LeftArm = LA(40, 70),
						RightLeg = RL(-10, 20),
						LeftLeg = LL(10, 20),
					},
				},
				{
					t = 0.55,
					ease = "Sine.InOut",
					pose = {
						Root = T(4, 0, 0),
						Neck = H(0, 0, 0),
						RightArm = RA(14, 14),
						LeftArm = LA(14, 14),
						RightLeg = RL(0, 6),
						LeftLeg = LL(0, 6),
					},
				},
			},
			markers = { { t = 0.25, name = "Cast" }, { t = 0.26, name = "Shake", data = 0.3 } },
		},
	},
}
