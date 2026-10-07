--[[
	Exports animation frames as oriented boxes for tools/preview/render.py.
	It runs the game's real animation code (Locomotion, Composer, Clip) through the Lune harness.

	lune run tools/preview/export.luau <out.json> <mode> [options]

	Modes:
	  clip  <ClipId>                 frames at every keyframe (and midpoints)
	  pose  <ClipId>                 only the keyframes
	  sheet <ClipId> <ClipId> ...    one row of keyframes per clip (a whole moveset on one image)
	  loco  <speed>                  one gait cycle at a constant forward speed
	  stance                         idle and run poses of a stance
	  shift <fromForm> <toForm>      mecha-shift between weapon forms
	Options (key=value):
	  stance=Scythe.Scythe  weapon=CrescentScythe  form=Scythe  style=Huntsman  frames=8
	  title="..."  strafe=1 (move sideways in loco mode)  mid=1 (sheet: add midpoints)
	  views=front,side,top (which camera angles render.py draws)
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

local Harness = require("../lune/harness")
local shared = Harness.mount("src/shared")
local Animation = shared.Animation
local Joints = Harness.require(Animation.Joints)
local ClipLibrary = Harness.require(Animation.ClipLibrary)
local Composer = Harness.require(Animation.Composer)
local Locomotion = Harness.require(Animation.Locomotion)
local WeaponModels = Harness.require(shared.Config.WeaponModels)
local WeaponShift = Harness.require(Animation.WeaponShift)

local args = process.args
local outPath = args[1]
local mode = args[2]
assert(outPath and mode, "usage: export.luau <out.json> <mode> [arg] [key=value...]")

local positional = {}
local options = {}
for i = 3, #args do
	local key, value = string.match(args[i], "^(%w+)=(.*)$")
	if key then
		options[key] = value
	else
		table.insert(positional, args[i])
	end
end

local style = Locomotion.Styles[options.style or "Huntsman"]
local stance = if options.stance then ClipLibrary.stance(options.stance) else nil
if options.stance then
	assert(stance, `unknown stance {options.stance}`)
end
local weapon = if options.weapon then WeaponModels[options.weapon] else nil
local accent = { 214, 40, 64 }

local PREVIEW_COLORS = {
	Torso = { 150, 28, 40 },
	Head = { 236, 200, 170 },
	["Right Arm"] = { 225, 120, 110 },
	["Left Arm"] = { 120, 150, 215 },
	["Right Leg"] = { 70, 64, 72 },
	["Left Leg"] = { 52, 60, 92 },
}

local function colorOf(model, key: string)
	if key == "Accent" then
		return accent
	end
	local c = model.palette[key]
	if c then
		return { math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255) }
	end
	return { 200, 200, 200 }
end

local function encodeCF(cf)
	return { cf:GetComponents() }
end

local R6 = Joints.R6

local function transformFor(joint: string, pose)
	local value = pose[joint] or CFrame.identity
	if Joints.ParentSpace[joint] then
		local r0 = R6[joint].c0.Rotation
		return Joints.toTransform(value, r0, r0:Inverse())
	end
	return value
end

-- pieceCFrames: optional override map piece name -> CFrame (for mecha-shift previews)
local function solve(pose, form: string?, pieceCFrames, hidden)
	local parts = {}
	local hrp = CFrame.identity
	local function limb(joint: string, parent)
		return parent * R6[joint].c0 * transformFor(joint, pose) * R6[joint].c1:Inverse()
	end
	local torso = limb("Root", hrp)
	local head = limb("Neck", torso)
	local rightArm = limb("RightArm", torso)
	local leftArm = limb("LeftArm", torso)
	local rightLeg = limb("RightLeg", torso)
	local leftLeg = limb("LeftLeg", torso)

	local function add(name, cf, size, color, shape, transparency)
		table.insert(parts, {
			name = name,
			cf = encodeCF(cf),
			size = { size.X, size.Y, size.Z },
			color = color,
			shape = shape or "Block",
			transparency = transparency or 0,
		})
	end
	add("Torso", torso, Vector3.new(2, 2, 1), PREVIEW_COLORS.Torso)
	add("Head", head, Vector3.new(1.25, 1.2, 1.2), PREVIEW_COLORS.Head)
	add("Eyes", head * CFrame.new(0, 0.12, -0.6), Vector3.new(0.7, 0.16, 0.05), { 20, 20, 25 })
	add("Right Arm", rightArm, Vector3.new(1, 2, 1), PREVIEW_COLORS["Right Arm"])
	add("Left Arm", leftArm, Vector3.new(1, 2, 1), PREVIEW_COLORS["Left Arm"])
	add("Right Leg", rightLeg, Vector3.new(1, 2, 1), PREVIEW_COLORS["Right Leg"])
	add("Left Leg", leftLeg, Vector3.new(1, 2, 1), PREVIEW_COLORS["Left Leg"])

	if weapon then
		local handles = {
			Right = rightArm * Joints.GripC0 * transformFor("RightGrip", pose),
			Left = leftArm * Joints.GripC0 * transformFor("LeftGrip", pose),
		}
		local function addPieces(list, hand)
			if list == nil then
				return
			end
			for _, piece in list do
				local local_ = (pieceCFrames and pieceCFrames[piece.name]) or piece.forms[form]
				local transparency = 0
				if hidden then
					transparency = hidden[piece.name] or 0
				elseif piece.hiddenIn and piece.hiddenIn[form] then
					transparency = 1
				end
				add(
					piece.name,
					handles[hand] * local_,
					piece.size,
					colorOf(weapon, piece.color),
					piece.shape,
					transparency
				)
			end
		end
		addPieces(weapon.right, "Right")
		addPieces(weapon.left, "Left")
	end
	return parts
end

-- Runs locomotion until it settles at a constant velocity.
local function settle(velocity, seconds)
	local state = Locomotion.newState()
	local pose = {}
	local steps = math.floor(seconds * 60)
	for _ = 1, steps do
		table.clear(pose)
		Locomotion.update(state, {
			dt = 1 / 60,
			velocity = velocity,
			rootCFrame = CFrame.identity,
			grounded = true,
			style = style,
		}, pose)
	end
	return state, pose
end

local function composed(state, locoPose, actions)
	local pose = table.clone(locoPose)
	local twoHand = if weapon and weapon.twoHand and options.form then weapon.twoHand[options.form] else nil
	Composer.compose(pose, state, { stance = stance, actions = actions, twoHand = twoHand })
	return pose
end

local frames = {}
local rows = {}
local title = options.title

local function clipFrames(id: string, withMidpoints: boolean)
	local clip = ClipLibrary.expect(id)
	local state, locoPose = settle(Vector3.zero, 1)
	local times = {}
	if options.frames then
		local n = tonumber(options.frames) :: number
		for i = 0, n - 1 do
			table.insert(times, clip.length * i / math.max(n - 1, 1))
		end
	else
		for i, t in clip.times do
			table.insert(times, t)
			local nextT = clip.times[i + 1]
			if withMidpoints and nextT and nextT - t > 0.06 then
				table.insert(times, (t + nextT) / 2)
			end
		end
	end
	local result = {}
	for _, t in times do
		local pose = composed(state, locoPose, { { clip = clip, time = t, weight = 1 } })
		local label = string.format("%.2f", t)
		for _, marker in clip.markers do
			if math.abs(marker.t - t) < 0.02 then
				label ..= " " .. marker.name
			end
		end
		table.insert(result, { label = label, parts = solve(pose, options.form) })
	end
	return result
end

if mode == "sheet" then
	for _, id in positional do
		table.insert(rows, { title = id, frames = clipFrames(id, options.mid == "1") })
	end
	title = title or `moveset ({#rows} clips)`
elseif mode == "clip" or mode == "pose" then
	local id = positional[1]
	local clip = ClipLibrary.expect(id)
	local state, locoPose = settle(Vector3.zero, 1)
	local times = {}
	if options.frames then
		local n = tonumber(options.frames) :: number
		for i = 0, n - 1 do
			table.insert(times, clip.length * i / math.max(n - 1, 1))
		end
	else
		for i, t in clip.times do
			table.insert(times, t)
			local nextT = clip.times[i + 1]
			if mode == "clip" and nextT and nextT - t > 0.06 then
				table.insert(times, (t + nextT) / 2)
			end
		end
	end
	for _, t in times do
		local pose = composed(state, locoPose, { { clip = clip, time = t, weight = 1 } })
		local label = string.format("t=%.2f", t)
		for _, marker in clip.markers do
			if math.abs(marker.t - t) < 0.02 then
				label ..= " " .. marker.name
			end
		end
		table.insert(frames, { label = label, parts = solve(pose, options.form) })
	end
	title = title or id
elseif mode == "loco" then
	local speed = tonumber(positional[1]) or 14
	local direction = if options.strafe then Vector3.new(1, 0, 0) else Vector3.new(0, 0, -1)
	local velocity = direction * speed
	local state = settle(velocity, 2)
	local stride = style.walkStride + (style.runStride - style.walkStride) * state.run
	local cycle = stride / math.max(speed, 0.01)
	local n = tonumber(options.frames) or 6
	local step = cycle / n
	local substeps = 8
	for _ = 1, n do
		local pose = {}
		for _ = 1, substeps do
			table.clear(pose)
			Locomotion.update(state, {
				dt = step / substeps,
				velocity = velocity,
				rootCFrame = CFrame.identity,
				grounded = true,
				style = style,
			}, pose)
		end
		local final = composed(state, pose, nil)
		table.insert(
			frames,
			{ label = string.format("phase %.0f°", math.deg(state.phase)), parts = solve(final, options.form) }
		)
	end
	title = title or `locomotion {options.style or "Huntsman"} @ {speed}`
elseif mode == "stance" then
	local state, locoPose = settle(Vector3.zero, 1)
	table.insert(frames, { label = "idle", parts = solve(composed(state, locoPose, nil), options.form) })
	local runState, runPose = settle(Vector3.new(0, 0, -26), 2)
	table.insert(frames, { label = "run", parts = solve(composed(runState, runPose, nil), options.form) })
	title = title or `stance {options.stance}`
elseif mode == "shift" then
	assert(weapon, "shift mode needs weapon=")
	local fromForm, toForm = positional[1], positional[2]
	local state, locoPose = settle(Vector3.zero, 1)
	local n = tonumber(options.frames) or 7
	local duration = weapon.shiftTime
	for i = 0, n - 1 do
		local t = duration * i / (n - 1)
		local pieceCFrames, hidden = {}, {}
		for _, list in { weapon.right, weapon.left or {} } do
			for index, piece in list do
				local cframe, transparency = WeaponShift.sample(piece, index, #list, fromForm, toForm, t, duration)
				pieceCFrames[piece.name] = cframe
				hidden[piece.name] = transparency
			end
		end
		local pose = composed(state, locoPose, nil)
		table.insert(
			frames,
			{ label = string.format("t=%.2f", t), parts = solve(pose, fromForm, pieceCFrames, hidden) }
		)
	end
	title = title or `mecha-shift {options.weapon} {fromForm} -> {toForm}`
else
	error(`unknown mode {mode}`)
end

local views = if options.views then string.split(options.views, ",") else nil
fs.writeFile(
	outPath,
	serde.encode("json", { title = title, frames = frames, rows = rows, groundY = -3, views = views })
)
print(`exported {#frames} frames, {#rows} rows to {outPath}`)
