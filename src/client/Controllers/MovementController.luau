--!strict
--[[
	MovementController: everything that moves the local character. The client owns its character's
	physics, so dashes, lunges, slides, recoil and server-requested knockback are applied here.

	Walk speed is derived every frame from the replicated combat state (blocking, attacking,
	stunned, chilled...) plus local prediction, so movement responds instantly to input.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Combat = require(Shared.Config.Combat)
local Impulse = require(Shared.Util.Impulse)
local Net = require(Shared.Net)
local Semblances = require(Shared.Config.Semblances)
local Signal = require(Shared.Util.Signal)
local Weapons = require(Shared.Config.Weapons)

local InputController = require(script.Parent.InputController)

local MovementController = {}

MovementController.Launched = Signal.new() :: Signal.Signal<Vector3>
MovementController.Dashed = Signal.new() :: Signal.Signal<Vector3>

local player = Players.LocalPlayer

local sprinting = false
local airDashesUsed = 0
local localBusyUntil = 0 -- predicted attack/cast lock
local localBusySpeed = Combat.AttackWalkSpeed
local faceCamera = false
local padCooldownUntil = 0

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function character(): (Model?, Humanoid?, BasePart?)
	local model = player.Character
	if model == nil then
		return nil, nil, nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid and root and root:IsA("BasePart") then
		return model, humanoid, root
	end
	return model, nil, nil
end

function MovementController.isGrounded(): boolean
	local _, humanoid = character()
	return humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air
end

function MovementController.isSprinting(): boolean
	return sprinting
end

function MovementController.setSprinting(on: boolean)
	sprinting = on
end

-- Locks walk speed while a predicted action plays (server state arrives a ping later).
function MovementController.busy(duration: number, speed: number?)
	localBusyUntil = math.max(localBusyUntil, os.clock() + duration)
	localBusySpeed = speed or Combat.AttackWalkSpeed
end

function MovementController.clearBusy()
	localBusyUntil = 0
end

function MovementController.setFaceCamera(on: boolean)
	faceCamera = on
	local _, humanoid = character()
	if humanoid then
		humanoid.AutoRotate = not on
	end
end

-- Instantly turns the character toward the camera's flat look direction.
function MovementController.turnToCamera()
	local _, _, root = character()
	local camera = Workspace.CurrentCamera
	if root == nil or camera == nil then
		return
	end
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.01 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
	end
end

function MovementController.cameraFlatLook(): Vector3
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return Vector3.new(0, 0, -1)
	end
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
end

-- Direction keys relative to the character -> "Forward" | "Back" | "Left" | "Right" and world vector.
function MovementController.dodgeDirection(): (string, Vector3)
	local _, humanoid, root = character()
	if humanoid == nil or root == nil then
		return "Back", Vector3.new(0, 0, 1)
	end
	local move = humanoid.MoveDirection
	local look = root.CFrame.LookVector
	local right = root.CFrame.RightVector
	if move.Magnitude < 0.1 then
		return "Back", -Vector3.new(look.X, 0, look.Z).Unit
	end
	local forwardAmount = move:Dot(look)
	local rightAmount = move:Dot(right)
	local name = if math.abs(forwardAmount) >= math.abs(rightAmount)
		then (if forwardAmount > 0 then "Forward" else "Back")
		else (if rightAmount > 0 then "Right" else "Left")
	return name, Vector3.new(move.X, 0, move.Z).Unit
end

function MovementController.airDashesLeft(): number
	local model = player.Character
	local semblance = if model then model:GetAttribute("Semblance") else nil
	local extra = 0
	if semblance == "Glyph" then
		local def = Semblances.get("Glyph")
		extra = if def then def.params.airDashes else 0
	end
	return Combat.AirDashes + extra - airDashesUsed
end

function MovementController.dash(direction: Vector3, airborne: boolean)
	local _, humanoid, root = character()
	if humanoid == nil or root == nil then
		return
	end
	if airborne then
		airDashesUsed += 1
		Impulse.apply(root, direction * Combat.AirDashSpeed + Vector3.new(0, 10, 0), {
			duration = 0.24,
			decay = true,
			name = "Dash",
		})
	else
		Impulse.apply(root, direction * Combat.DodgeSpeed, {
			duration = Combat.DodgeDuration,
			planar = true,
			decay = true,
			name = "Dash",
		})
	end
	MovementController.Dashed:Fire(direction)
end

function MovementController.lunge(speed: number)
	local _, _, root = character()
	if root == nil then
		return
	end
	local look = root.CFrame.LookVector
	Impulse.apply(root, Vector3.new(look.X, 0, look.Z).Unit * speed, {
		duration = 0.16,
		planar = true,
		decay = true,
		name = "Lunge",
	})
end

-- A strong launch (glyphs, launch pads, gravity dust).
function MovementController.launch(velocity: Vector3, duration: number?)
	local _, humanoid, root = character()
	if humanoid == nil or root == nil then
		return
	end
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	Impulse.apply(root, velocity, { duration = duration or 0.3, decay = true, name = "Launch" })
	airDashesUsed = 0
	MovementController.Launched:Fire(velocity)
end

-- Firearm recoil: propels you while airborne, nudges you on the ground.
function MovementController.recoil(aim: Vector3, airStrength: number, groundStrength: number)
	local _, humanoid, root = character()
	if humanoid == nil or root == nil then
		return
	end
	if humanoid.FloorMaterial == Enum.Material.Air then
		Impulse.apply(root, -aim * airStrength + Vector3.new(0, airStrength * 0.25, 0), {
			duration = 0.18,
			decay = true,
			name = "Recoil",
		})
	elseif groundStrength > 0 then
		local flat = Vector3.new(aim.X, 0, aim.Z)
		if flat.Magnitude > 0.01 then
			Impulse.apply(
				root,
				-flat.Unit * groundStrength,
				{ duration = 0.12, planar = true, decay = true, name = "Recoil" }
			)
		end
	end
end

function MovementController.slide()
	local _, humanoid, root = character()
	if humanoid == nil or root == nil then
		return
	end
	local look = root.CFrame.LookVector
	Impulse.apply(root, Vector3.new(look.X, 0, look.Z).Unit * Combat.SlideSpeed, {
		duration = Combat.SlideDuration,
		planar = true,
		decay = true,
		name = "Dash",
	})
	MovementController.busy(Combat.SlideDuration, 0)
end

-- Short teleport (Shadow semblance), stopping short of walls.
function MovementController.blink(direction: Vector3, distance: number)
	local model, _, root = character()
	if model == nil or root == nil then
		return
	end
	rayParams.FilterDescendantsInstances = { model }
	local result = Workspace:Raycast(root.Position, direction * distance, rayParams)
	local travel = if result then math.max(0, (result.Position - root.Position).Magnitude - 2) else distance
	root.CFrame = root.CFrame + direction * travel
end

local function walkSpeed(model: Model, humanoid: Humanoid): number
	local state = model:GetAttribute("State")
	local slow = model:GetAttribute("SlowFactor")
	local speedStat = model:GetAttribute("MoveSpeed")
	local multiplier = (if type(slow) == "number" then slow else 1)
		* (if type(speedStat) == "number" then speedStat else 1)

	local weapon = Weapons.get(tostring(model:GetAttribute("Weapon") or ""))
	local formName = model:GetAttribute("WeaponForm")
	if weapon and type(formName) == "string" then
		multiplier *= Weapons.form(weapon, formName).speedMultiplier or 1
	end

	if model:GetAttribute("Dead") then
		return 0
	elseif model:GetAttribute("Knocked") then
		return 1.5
	elseif model:GetAttribute("Stunned") or model:GetAttribute("GuardBroken") then
		return 3
	elseif os.clock() < localBusyUntil then
		return localBusySpeed * multiplier
	elseif state == "Blocking" or InputController.isDown("Block") then
		return Combat.BlockWalkSpeed * multiplier
	elseif state == "Attacking" then
		return Combat.AttackWalkSpeed * multiplier
	elseif state == "Casting" then
		return Combat.CastWalkSpeed * multiplier
	elseif model:GetAttribute("Aiming") then
		return Combat.AimWalkSpeed * multiplier
	end

	local base = Combat.WalkSpeed
	if sprinting and humanoid.MoveDirection.Magnitude > 0.1 then
		base = Combat.SprintSpeed
		if model:GetAttribute("Semblance") == "Velocity" then
			local def = Semblances.get("Velocity")
			base *= 1 + (if def then def.params.sprintBonus else 0)
		end
	end
	return base * multiplier
end

local function checkLaunchPad(model: Model, root: BasePart)
	if os.clock() < padCooldownUntil then
		return
	end
	rayParams.FilterDescendantsInstances = { model }
	local result = Workspace:Raycast(root.Position, Vector3.new(0, -4, 0), rayParams)
	if result and CollectionService:HasTag(result.Instance, "LaunchPad") then
		local direction = result.Instance:GetAttribute("LaunchDirection")
		local speed = result.Instance:GetAttribute("LaunchSpeed")
		if typeof(direction) == "Vector3" and type(speed) == "number" then
			padCooldownUntil = os.clock() + 1.5
			MovementController.launch(direction * speed, 0.45)
		end
	end
end

local function step()
	local model, humanoid, root = character()
	if model == nil or humanoid == nil or root == nil then
		return
	end
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		airDashesUsed = 0
	end
	if sprinting and humanoid.MoveDirection.Magnitude < 0.1 and not InputController.isDown("Sprint") then
		sprinting = false
	end

	humanoid.WalkSpeed = walkSpeed(model, humanoid)
	local locked = model:GetAttribute("Knocked")
		or model:GetAttribute("Stunned")
		or model:GetAttribute("GuardBroken")
		or os.clock() < localBusyUntil
	humanoid.JumpPower = if locked then 0 else Combat.JumpPower

	if faceCamera then
		local look = MovementController.cameraFlatLook()
		root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
	end
	checkLaunchPad(model, root)
end

function MovementController.init() end

function MovementController.start()
	InputController.Began:Connect(function(action)
		if action == "Sprint" or action == "SprintTap" then
			sprinting = true
		end
	end)
	InputController.Ended:Connect(function(action)
		if action == "Sprint" then
			sprinting = false
		end
	end)

	Net.event("Motion").OnClientEvent:Connect(function(kind: any, payload: any)
		local _, humanoid, root = character()
		if humanoid == nil or root == nil or type(payload) ~= "table" then
			return
		end
		if kind == "Impulse" and typeof(payload.velocity) == "Vector3" then
			local velocity: Vector3 = payload.velocity
			if velocity.Y > 12 then
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
			Impulse.apply(root, velocity, {
				duration = if type(payload.duration) == "number" then payload.duration else 0.15,
				decay = true,
				name = "Knockback",
			})
		end
	end)

	RunService.Heartbeat:Connect(step)
	player.CharacterAdded:Connect(function()
		sprinting = false
		airDashesUsed = 0
		localBusyUntil = 0
		faceCamera = false
	end)
end

return MovementController
