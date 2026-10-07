--!strict
--[[
	WorldController: client-side atmosphere.

	* The shattered moon: a glowing moon with a trail of broken fragments, rebuilt from parts and
	  kept at a fixed direction relative to the camera so it behaves like part of the sky.
	  It brightens at night and fades by day.
	* Zone banners when you cross into Beacon, Vale, the Emerald Forest or Forever Fall.
	* Faunus night vision: a gentle brightness lift after dark.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Config.World)

local ProfileStore = require(script.Parent.Parent.State.ProfileStore)
local Theme = require(script.Parent.Parent.UI.Theme)
local HudController = require(script.Parent.HudController)

local WorldController = {}

local player = Players.LocalPlayer
local MOON_DISTANCE = 460
local MOON_AZIMUTH = math.rad(-24)
local MOON_ELEVATION = math.rad(30)

type MoonPiece = { part: Part, offset: CFrame }

local moonPieces: { MoonPiece } = {}
local nightVision: ColorCorrectionEffect
local currentZone: string? = nil
local zoneTimer = 0

local function buildMoon(parent: Instance)
	local glow = Color3.fromRGB(232, 234, 244)
	local function piece(size: Vector3, offset: CFrame, shape: Enum.PartType?, color: Color3?)
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = color or glow
		part.Size = size
		if shape then
			part.Shape = shape
		end
		part.Parent = parent
		table.insert(moonPieces, { part = part, offset = offset })
	end
	-- The moon body.
	piece(Vector3.one * 52, CFrame.identity, Enum.PartType.Ball)
	-- Cracks across the face.
	local crack = Color3.fromRGB(150, 150, 165)
	piece(Vector3.new(30, 0.8, 0.5), CFrame.new(6, 4, -25.6) * CFrame.Angles(0, 0, math.rad(-28)), nil, crack)
	piece(Vector3.new(18, 0.6, 0.5), CFrame.new(12, -6, -24.8) * CFrame.Angles(0, 0, math.rad(40)), nil, crack)
	piece(Vector3.new(12, 0.5, 0.5), CFrame.new(-4, -10, -24) * CFrame.Angles(0, 0, math.rad(10)), nil, crack)
	-- The shattered fragments drifting away in an arc.
	local fragments = {
		{ 14, 34, -14 },
		{ 11, 46, -22 },
		{ 9, 56, -31 },
		{ 7.5, 64, -40 },
		{ 6, 70, -48 },
		{ 5, 75, -55 },
		{ 4, 79, -61 },
		{ 3, 82, -66 },
		{ 6, 40, -32 },
		{ 4, 52, -44 },
	}
	for index, data in fragments do
		local size = data[1]
		local spin = CFrame.Angles(index * 0.7, index * 1.3, index * 0.4)
		piece(Vector3.new(size, size * 0.8, size * 0.9), CFrame.new(data[2], data[3], -4) * spin, nil, glow)
	end
end

local function nightFactor(): number
	local t = Lighting.ClockTime
	if t >= 19.5 or t <= 4.5 then
		return 1
	elseif t >= 17.5 then
		return (t - 17.5) / 2
	elseif t <= 6.5 then
		return (6.5 - t) / 2
	end
	return 0
end

local function update(dt: number)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local direction = Vector3.new(
		math.sin(MOON_AZIMUTH) * math.cos(MOON_ELEVATION),
		math.sin(MOON_ELEVATION),
		-math.cos(MOON_AZIMUTH) * math.cos(MOON_ELEVATION)
	)
	local cameraPosition = camera.CFrame.Position
	local center = cameraPosition + direction * MOON_DISTANCE
	local frame = CFrame.lookAt(center, cameraPosition)
	local night = nightFactor()
	local transparency = 0.82 - 0.8 * night
	for _, piece in moonPieces do
		piece.part.CFrame = frame * piece.offset
		piece.part.Transparency = transparency
	end

	local profile = ProfileStore.get()
	local faunus = profile ~= nil and profile.Faunus ~= ""
	nightVision.Brightness = if faunus then 0.07 * night else 0
	nightVision.Contrast = if faunus then -0.04 * night else 0

	zoneTimer -= dt
	if zoneTimer <= 0 then
		zoneTimer = 0.5
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			local zone = World.zoneAt(root.Position)
			local id = if zone then zone.id else nil
			if id ~= currentZone then
				currentZone = id
				if zone then
					HudController.banner(
						string.upper(zone.name),
						if zone.safe
							then "Safe zone — Huntsmen cannot duel here"
							else "Grimm territory — stay alert",
						if zone.safe then Theme.Colors.Good else Theme.Colors.Danger
					)
				end
			end
		end
	end
end

function WorldController.init()
	local folder = Instance.new("Folder")
	folder.Name = "Sky"
	folder.Parent = Workspace
	buildMoon(folder)
	nightVision = Instance.new("ColorCorrectionEffect")
	nightVision.Name = "FaunusNightVision"
	nightVision.Parent = Lighting
end

function WorldController.start()
	RunService:BindToRenderStep("RemnantSky", Enum.RenderPriority.Camera.Value + 2, update)
end

return WorldController
