--!strict
--[[
	WorldService: builds the map, sets up lighting and post-processing, and runs the day/night
	cycle. Nights are when the shattered moon (drawn by each client) hangs over Remnant.
]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapBuilder = require(script.Parent.MapBuilder)

local WorldService = {}

local DAY_LENGTH = 1200 -- seconds for a full 24h cycle

local function make<T>(className: string, props: { [string]: any }): T
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = Lighting
	return instance :: any
end

local function setupLighting()
	for _, child in Lighting:GetChildren() do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end
	Lighting.Ambient = Color3.fromRGB(62, 56, 72)
	Lighting.OutdoorAmbient = Color3.fromRGB(118, 108, 128)
	Lighting.Brightness = 2.4
	Lighting.EnvironmentDiffuseScale = 0.7
	Lighting.EnvironmentSpecularScale = 0.9
	Lighting.ShadowSoftness = 0.3
	Lighting.ExposureCompensation = 0.1
	Lighting.GeographicLatitude = 32
	Lighting.ClockTime = 16.8

	make("Sky", {
		Name = "RemnantSky",
		StarCount = 3500,
		MoonAngularSize = 0,
		SunAngularSize = 14,
		CelestialBodiesShown = true,
	})
	make("Atmosphere", {
		Name = "RemnantAtmosphere",
		Density = 0.3,
		Offset = 0.18,
		Color = Color3.fromRGB(200, 180, 206),
		Decay = Color3.fromRGB(110, 88, 122),
		Glare = 0.35,
		Haze = 1.4,
	})
	make("BloomEffect", { Name = "Bloom", Intensity = 0.55, Size = 30, Threshold = 1.35 })
	make("ColorCorrectionEffect", {
		Name = "Grade",
		Brightness = 0.02,
		Contrast = 0.12,
		Saturation = 0.12,
		TintColor = Color3.fromRGB(255, 246, 250),
	})
	make("SunRaysEffect", { Name = "SunRays", Intensity = 0.05, Spread = 0.7 })
end

function WorldService.init()
	setupLighting()
	Workspace.Gravity = 196.2
	MapBuilder.build()
	local effects = Instance.new("Folder")
	effects.Name = "Effects"
	effects.Parent = Workspace
end

function WorldService.start()
	RunService.Heartbeat:Connect(function(dt: number)
		Lighting.ClockTime = (Lighting.ClockTime + dt * 24 / DAY_LENGTH) % 24
	end)
end

return WorldService
