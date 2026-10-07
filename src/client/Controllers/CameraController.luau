--!strict
--[[
	CameraController: screen shake (trauma model: shake = trauma^2, so small hits barely register and
	heavy blows really land), field-of-view punches for dashes and launches, sprint FOV, and an
	over-the-shoulder zoom while aiming a ranged form.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Spring = require(ReplicatedStorage.Shared.Animation.Spring)

local MovementController = require(script.Parent.MovementController)

local CameraController = {}

local BASE_FOV = 70
local SPRINT_FOV = 78
local AIM_FOV = 52
local SNIPER_FOV = 34

local player = Players.LocalPlayer
local trauma = 0
local fovPunch = Spring.new(140, 14)
local currentFov = BASE_FOV
local aiming = false
local aimFov = AIM_FOV
local offset = Vector3.zero
local time = 0

-- Adds screen shake. 0.15 = light hit, 0.4 = heavy hit, 0.8 = explosion at your feet.
function CameraController.shake(amount: number)
	trauma = math.min(1, trauma + amount)
end

-- Shake that falls off with distance from the camera.
function CameraController.shakeAt(position: Vector3, amount: number, radius: number)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local distance = (camera.CFrame.Position - position).Magnitude
	local falloff = math.clamp(1 - distance / radius, 0, 1)
	if falloff > 0 then
		CameraController.shake(amount * falloff)
	end
end

-- Briefly widens the field of view (dashes, launches).
function CameraController.punch(degrees: number)
	fovPunch:impulse(Vector3.new(degrees * 14, 0, 0))
end

function CameraController.setAiming(on: boolean, sniper: boolean?)
	aiming = on
	aimFov = if sniper then SNIPER_FOV else AIM_FOV
	UserInputService.MouseBehavior = if on then Enum.MouseBehavior.LockCenter else Enum.MouseBehavior.Default
end

function CameraController.isAiming(): boolean
	return aiming
end

local function update(dt: number)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	time += dt

	-- Field of view.
	local target = if aiming then aimFov elseif MovementController.isSprinting() then SPRINT_FOV else BASE_FOV
	currentFov += (target - currentFov) * (1 - math.exp(-10 * dt))
	local punch = fovPunch:update(dt)
	camera.FieldOfView = math.clamp(currentFov + punch.X, 20, 110)

	-- Over-the-shoulder offset while aiming.
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local wantOffset = if aiming then Vector3.new(1.8, 0.6, 0) else Vector3.zero
	offset = offset:Lerp(wantOffset, 1 - math.exp(-12 * dt))
	if humanoid then
		humanoid.CameraOffset = offset
	end
	if aiming then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end

	-- Shake.
	if trauma > 0 then
		local shake = trauma * trauma
		local pitch = math.noise(time * 18, 0.1) * 2.6 * shake
		local yaw = math.noise(time * 18, 4.7) * 2.6 * shake
		local roll = math.noise(time * 18, 9.3) * 1.8 * shake
		camera.CFrame *= CFrame.Angles(math.rad(pitch), math.rad(yaw), math.rad(roll))
		trauma = math.max(0, trauma - dt * 1.6)
	end
end

function CameraController.init() end

function CameraController.start()
	RunService:BindToRenderStep("RemnantCamera", Enum.RenderPriority.Camera.Value + 1, update)
	MovementController.Dashed:Connect(function()
		CameraController.punch(7)
	end)
	MovementController.Launched:Connect(function()
		CameraController.punch(12)
		CameraController.shake(0.25)
	end)
	player.CharacterAdded:Connect(function()
		trauma = 0
		CameraController.setAiming(false)
	end)
end

return CameraController
