--!strict
--[[
	Registry of every animation clip and weapon stance in the game.

	Each ModuleScript under Animation/Clips returns:
		{ prefix = "Scythe", clips = { M1_1 = ClipDef, ... }, stances = { Melee = StanceDef, ... } }
	and is addressed as "<prefix>.<name>" (e.g. "Scythe.M1_1", stance "Scythe.Melee").

	The server reads marker times from the same data the client animates with, so hit frames and
	animations can never drift apart.
]]

local Clip = require(script.Parent.Clip)
local Joints = require(script.Parent.Joints)

type Pose = Joints.Pose

export type StanceDef = {
	idle: Pose, -- arms/grips/neck hold; Root is applied as an offset; legs only while standing still
	walk: Pose?, -- upper body while walking (defaults to idle)
	run: Pose?, -- upper body while sprinting (defaults to walk)
	air: Pose?, -- upper body while airborne (defaults to walk)
	armSwing: number?, -- 0..1 share of the procedural arm swing layered on top of the hold
	twoHand: number?, -- 0..1 off-hand grip strength while standing/walking (two-handed weapons)
	twoHandRun: number?, -- 0..1 off-hand grip strength while sprinting (defaults to twoHand)
}

export type ClipModule = {
	prefix: string,
	clips: { [string]: Clip.ClipDef }?,
	stances: { [string]: StanceDef }?,
}

local ClipLibrary = {}

local definitions: { [string]: Clip.ClipDef } = {}
local compiled: { [string]: Clip.Clip } = {}
local stances: { [string]: StanceDef } = {}
local loaded = false

function ClipLibrary.register(module: ClipModule)
	local prefix = module.prefix
	if module.clips then
		for name, def in module.clips do
			local id = `{prefix}.{name}`
			assert(definitions[id] == nil, `Duplicate clip id "{id}"`)
			definitions[id] = def
		end
	end
	if module.stances then
		for name, stance in module.stances do
			stances[`{prefix}.{name}`] = stance
		end
	end
end

-- Loads every clip module under Animation/Clips. Safe to call repeatedly.
function ClipLibrary.load()
	if loaded then
		return
	end
	loaded = true
	local folder = script.Parent:FindFirstChild("Clips")
	assert(folder, "Animation/Clips folder is missing")
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			ClipLibrary.register(require(child) :: any)
		end
	end
end

function ClipLibrary.get(id: string): Clip.Clip?
	local clip = compiled[id]
	if clip then
		return clip
	end
	ClipLibrary.load()
	local def = definitions[id]
	if def == nil then
		return nil
	end
	clip = Clip.compile(id, def)
	compiled[id] = clip
	return clip
end

function ClipLibrary.expect(id: string): Clip.Clip
	local clip = ClipLibrary.get(id)
	assert(clip, `Unknown clip "{id}"`)
	return clip
end

function ClipLibrary.has(id: string): boolean
	ClipLibrary.load()
	return definitions[id] ~= nil
end

function ClipLibrary.stance(id: string): StanceDef?
	ClipLibrary.load()
	return stances[id]
end

-- Seconds into the clip (at its own playback speed) where the nth marker named `name` fires.
function ClipLibrary.markerSeconds(id: string, name: string, occurrence: number?): number?
	local clip = ClipLibrary.get(id)
	if clip == nil then
		return nil
	end
	local t = Clip.markerTime(clip, name, occurrence)
	return if t then t / clip.speed else nil
end

-- Duration of the clip in seconds at its own playback speed.
function ClipLibrary.duration(id: string): number
	local clip = ClipLibrary.expect(id)
	return clip.length / clip.speed
end

function ClipLibrary.ids(): { string }
	ClipLibrary.load()
	local ids = {}
	for id in definitions do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

function ClipLibrary.stanceIds(): { string }
	ClipLibrary.load()
	local ids = {}
	for id in stances do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

return ClipLibrary
