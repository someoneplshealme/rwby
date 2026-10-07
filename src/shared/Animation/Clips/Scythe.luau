--!strict
local Joints = require(script.Parent.Parent.Joints)
local T, H, RA, LA, RL, LL = Joints.T, Joints.H, Joints.RA, Joints.LA, Joints.RL, Joints.LL
local grip = Joints.gripFor

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local idleArm = RA(22, 20, 0)
local runArm = RA(-38, 12, 0)

return {
	prefix = "Scythe",
	stances = {
		Scythe = {
			idle = {
				Root = T(6, 22, 0, 0, -0.15, 0),
				Neck = H(-4, -18, 0),
				RightArm = idleArm,
				RightGrip = grip(idleArm, v(-0.35, 0.8, -0.5), v(0.3, -0.35, -1)),
				RightLeg = RL(-14, 10),
				LeftLeg = LL(16, 8),
			},
			run = {
				RightArm = runArm,
				RightGrip = grip(runArm, v(0.15, 0.45, 1), v(0, -1, 0.2)),
			},
			armSwing = 0.15,
			twoHand = 1,
			twoHandRun = 0,
		},
	},
	clips = {},
}
