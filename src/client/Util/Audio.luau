--!strict
--[[
	Fire-and-forget sound playback from the Sounds config, positional or UI (2D).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local Audio = {}

local random = Random.new()
local anchor: Part? = nil

local function soundAnchor(): Part
	local existing = anchor
	if existing and existing.Parent then
		return existing
	end
	local part = Instance.new("Part")
	part.Name = "AudioAnchor"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Parent = Workspace.CurrentCamera or Workspace
	anchor = part
	return part
end

local function make(key: string): Sound?
	local def = Sounds[key]
	if def == nil or def.id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = def.id
	sound.Volume = def.volume or 0.5
	local pitch = def.pitch
	if pitch then
		sound.PlaybackSpeed = random:NextNumber(pitch[1], pitch[2])
	end
	return sound
end

-- Plays a sound attached to a part (3D).
function Audio.playOn(key: string, parent: Instance?, volumeScale: number?)
	if parent == nil then
		return
	end
	local sound = make(key)
	if sound == nil then
		return
	end
	sound.Volume *= volumeScale or 1
	sound.RollOffMaxDistance = 160
	sound.RollOffMinDistance = 12
	sound.Parent = parent
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(8, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

-- Plays a sound at a world position (3D).
function Audio.playAt(key: string, position: Vector3, volumeScale: number?)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = soundAnchor()
	attachment.WorldPosition = position
	Audio.playOn(key, attachment, volumeScale)
	task.delay(8, function()
		attachment:Destroy()
	end)
end

-- Plays a non-positional UI sound.
function Audio.ui(key: string)
	local sound = make(key)
	if sound == nil then
		return
	end
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

return Audio
