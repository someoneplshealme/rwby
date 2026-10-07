--[[
	Animation core: easing, joint conversion, clip compilation and sampling, markers,
	the pose composer and two-hand reach.
]]

local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

local Harness = require("../tools/lune/harness")

local shared = Harness.mount("src/shared")
local Easing = Harness.require(shared.Animation.Easing)
local Joints = Harness.require(shared.Animation.Joints)
local Clip = Harness.require(shared.Animation.Clip)
local Composer = Harness.require(shared.Animation.Composer)
local Locomotion = Harness.require(shared.Animation.Locomotion)

local function angleBetween(a, b): number
	return math.deg(math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1)))
end

return function(t)
	t.describe("Easing", function()
		t.it("starts at 0 and ends at 1 for every style", function()
			for _, style in
				{ "Linear", "Sine", "Quad", "Cubic", "Quart", "Quint", "Expo", "Circ", "Back", "Elastic", "Bounce" }
			do
				for _, direction in { "In", "Out", "InOut" } do
					local fn = Easing.get(`{style}.{direction}`)
					t.expect(fn(0)):toBeNear(0, 1e-3)
					t.expect(fn(1)):toBeNear(1, 1e-3)
				end
			end
		end)
		t.it("Back.Out overshoots, Quad.Out does not", function()
			local back, quad = Easing.get("Back.Out"), Easing.get("Quad.Out")
			local maxBack, maxQuad = 0, 0
			for i = 0, 100 do
				maxBack = math.max(maxBack, back(i / 100))
				maxQuad = math.max(maxQuad, quad(i / 100))
			end
			t.expect(maxBack):toBeGreaterThan(1.05)
			t.expect(maxQuad):toBeNear(1, 1e-6)
		end)
	end)

	t.describe("Joints", function()
		t.it("raising the right arm 90 degrees points it forward", function()
			local frames = Joints.solve({ RightArm = Joints.RA(90) }, CFrame.identity)
			local down = -frames["Right Arm"].UpVector
			t.expect(angleBetween(down, Vector3.new(0, 0, -1))):toBeLessThan(0.5)
		end)
		t.it("positive out raises arms away from the body on both sides", function()
			local frames = Joints.solve({ RightArm = Joints.RA(0, 90), LeftArm = Joints.LA(0, 90) }, CFrame.identity)
			t.expect(angleBetween(-frames["Right Arm"].UpVector, Vector3.xAxis)):toBeLessThan(0.5)
			t.expect(angleBetween(-frames["Left Arm"].UpVector, -Vector3.xAxis)):toBeLessThan(0.5)
		end)
		t.it("positive torso pitch leans forward around the hips", function()
			local frames = Joints.solve({ Root = Joints.T(30) }, CFrame.identity)
			local torso = frames.Torso
			t.expect(torso.Position.Z):toBeLessThan(-0.1)
			-- The hip line (bottom of the torso) stays put.
			local hips = torso * Vector3.new(0, -1, 0)
			t.expect(hips.Y):toBeNear(-1, 1e-3)
			t.expect(hips.Z):toBeNear(0, 1e-3)
		end)
		t.it("transform conversion round-trips", function()
			local r0 = Joints.R6.RightArm.c0.Rotation
			local pose = Joints.RA(37, 21, -12)
			local back = Joints.fromTransform(Joints.toTransform(pose, r0, r0:Inverse()), r0, r0:Inverse())
			local x1, y1, z1 = pose:ToEulerAnglesXYZ()
			local x2, y2, z2 = back:ToEulerAnglesXYZ()
			t.expect(x1):toBeNear(x2)
			t.expect(y1):toBeNear(y2)
			t.expect(z1):toBeNear(z2)
		end)
		t.it("mirroring a pose produces the symmetric body", function()
			local pose = { RightArm = Joints.RA(60, 30, 10), Root = Joints.T(10, 25, 5) }
			local mirrored = Joints.mirrorPose(pose)
			local a = Joints.solve(pose, CFrame.identity)
			local b = Joints.solve(mirrored, CFrame.identity)
			local right = a["Right Arm"].Position
			local left = b["Left Arm"].Position
			t.expect(left.X):toBeNear(-right.X)
			t.expect(left.Y):toBeNear(right.Y)
			t.expect(left.Z):toBeNear(right.Z)
		end)
		t.it("gripFor points the weapon where asked", function()
			local arm = Joints.RA(40, 25, 0)
			local shaft = Vector3.new(-0.3, 0.8, -0.5).Unit
			local edge = Vector3.new(0.2, -0.3, -1)
			local grip = Joints.gripFor(arm, shaft, edge)
			local handle = Joints.handleCFrame("Right", arm, grip)
			t.expect(angleBetween(handle.UpVector, shaft)):toBeLessThan(0.5)
			-- The weapon's front (handle -Z, i.e. LookVector) follows the edge direction.
			local perpendicular = (edge - shaft * edge:Dot(shaft)).Unit
			t.expect(angleBetween(handle.LookVector, perpendicular)):toBeLessThan(0.5)
		end)
		t.it("reach points the hand at the target", function()
			local target = Vector3.new(-1.2, 0.4, -1.4)
			local arm = Joints.reach("Left", target)
			local hand = Joints.handleCFrame("Left", arm, CFrame.identity).Position
			local shoulder = Joints.R6.LeftArm.c0.Position
			t.expect(angleBetween(hand - shoulder, target - shoulder)):toBeLessThan(0.5)
		end)
	end)

	t.describe("Clip", function()
		local clip = Clip.compile("test", {
			keyframes = {
				{ t = 0, pose = { RightArm = Joints.RA(0) } },
				{ t = 1, ease = "Linear", pose = { RightArm = Joints.RA(90), Root = Joints.T(20) } },
				{ t = 2, ease = "Linear", pose = { Neck = Joints.H(10) } },
			},
			markers = { { t = 0.5, name = "Hit" }, { t = 1.5, name = "Hit" }, { t = 1.2, name = "Chain" } },
		})

		t.it("forward-fills and back-fills joints", function()
			local out = {}
			Clip.sample(clip, 0, out)
			-- Root is first mentioned at t=1, so it holds that value from the start.
			local x = out.Root:ToEulerAnglesXYZ()
			t.expect(math.deg(x)):toBeNear(-20, 0.01)
			Clip.sample(clip, 2, out)
			local armX = out.RightArm:ToEulerAnglesXYZ()
			t.expect(math.deg(armX)):toBeNear(90, 0.01)
		end)
		t.it("interpolates between keyframes", function()
			local out = {}
			Clip.sample(clip, 0.5, out)
			local x = out.RightArm:ToEulerAnglesXYZ()
			t.expect(math.deg(x)):toBeNear(45, 0.05)
		end)
		t.it("finds markers by name and occurrence", function()
			t.expect(Clip.markerTime(clip, "Hit")):toBe(0.5)
			t.expect(Clip.markerTime(clip, "Hit", 2)):toBe(1.5)
			t.expect(Clip.markerTime(clip, "Nope")):toBe(nil)
		end)
		t.it("reports markers crossed between two times exactly once", function()
			local seen = {}
			Clip.forEachMarker(clip, 0, 0.5, function(marker)
				table.insert(seen, marker.name)
			end)
			Clip.forEachMarker(clip, 0.5, 1.6, function(marker)
				table.insert(seen, marker.name)
			end)
			t.expect(table.concat(seen, ",")):toBe("Hit,Chain,Hit")
		end)
		t.it("wraps looped clips back to the first key", function()
			local loop = Clip.compile("loop", {
				looped = true,
				length = 2,
				keyframes = {
					{ t = 0, pose = { Neck = Joints.H(0) } },
					{ t = 1, ease = "Linear", pose = { Neck = Joints.H(40) } },
				},
			})
			local out = {}
			Clip.sample(loop, 1.5, out)
			local x = out.Neck:ToEulerAnglesXYZ()
			t.expect(math.abs(math.deg(x))):toBeNear(20, 0.1)
			Clip.sample(loop, 2.0, out)
			local x2 = out.Neck:ToEulerAnglesXYZ()
			t.expect(math.deg(x2)):toBeNear(0, 0.1)
		end)
		t.it("converts torso-space legs to root space", function()
			local flip = Clip.compile("flip", {
				legSpace = "Torso",
				keyframes = { { t = 0, pose = { Root = Joints.T(90), RightLeg = Joints.RL(0) } } },
			})
			local out = {}
			Clip.sample(flip, 0, out)
			-- A torso pitched 90 degrees carries the (straight) leg with it.
			local frames = Joints.solve(out, CFrame.identity)
			local legDown = -frames["Right Leg"].UpVector
			t.expect(angleBetween(legDown, Vector3.new(0, 0, 1))):toBeLessThan(1)
		end)
	end)

	t.describe("Composer", function()
		t.it("keeps the off hand on a two-handed weapon", function()
			local state = Locomotion.newState()
			local pose = {}
			Locomotion.update(state, {
				dt = 1 / 60,
				velocity = Vector3.zero,
				rootCFrame = CFrame.identity,
				grounded = true,
				style = Locomotion.Styles.Huntsman,
			}, pose)
			-- Pole held level across the chest in front of the body: within reach of the left hand.
			pose.RightArm = Joints.RA(80, 0)
			pose.RightGrip = Joints.gripFor(pose.RightArm, Vector3.new(-1, 0, 0), Vector3.new(0, 1, 0))
			local twoHand = { a = Vector3.new(0, -1.5, 0), b = Vector3.new(0, 3.5, 0), prefer = 0.5 }
			Composer.applyTwoHand(pose, twoHand, 1)
			local handle = Joints.handleCFrame("Right", pose.RightArm, pose.RightGrip)
			local a, b = handle * twoHand.a, handle * twoHand.b
			local hand = Joints.handleCFrame("Left", pose.LeftArm, CFrame.identity).Position
			-- Distance from the left hand to the shaft segment.
			local d = b - a
			local s = math.clamp((hand - a):Dot(d) / d:Dot(d), 0, 1)
			local gap = (a + d * s - hand).Magnitude
			t.expect(gap):toBeLessThan(0.05)
		end)
		t.it("reaches toward the closest spot when the shaft is out of reach", function()
			local pose = {}
			pose.RightArm = Joints.RA(60, 30)
			pose.RightGrip = Joints.gripFor(pose.RightArm, Vector3.new(1, 0.4, 0.2), Vector3.new(0, 1, 0))
			local twoHand = { a = Vector3.new(0, 0.5, 0), b = Vector3.new(0, 3.5, 0), prefer = 0.5 }
			Composer.applyTwoHand(pose, twoHand, 1)
			local handle = Joints.handleCFrame("Right", pose.RightArm, pose.RightGrip)
			local a, b = handle * twoHand.a, handle * twoHand.b
			local shoulder = Joints.R6.LeftArm.c0.Position
			local d = b - a
			local s = math.clamp((shoulder - a):Dot(d) / d:Dot(d), 0, 1)
			local closest = a + d * s
			local hand = Joints.handleCFrame("Left", pose.LeftArm, CFrame.identity).Position
			t.expect(angleBetween(hand - shoulder, closest - shoulder)):toBeLessThan(1)
		end)
		t.it("locomotion settles to rest when standing still", function()
			local state = Locomotion.newState()
			local pose = {}
			for _ = 1, 120 do
				Locomotion.update(state, {
					dt = 1 / 60,
					velocity = Vector3.zero,
					rootCFrame = CFrame.identity,
					grounded = true,
					style = Locomotion.Styles.Huntsman,
				}, pose)
			end
			t.expect(state.move):toBeLessThan(0.01)
			t.expect(state.air):toBeLessThan(0.01)
		end)
	end)
end
