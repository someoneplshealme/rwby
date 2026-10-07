--!strict
--[[
	CombatController: the local Huntsman's fighting input.

	Every action is PREDICTED: the animation and any movement play the instant you press the key,
	then the request goes to the server with a sequence number. The server either confirms
	(its broadcast is skipped here because we already played it) or rejects (we cancel).
	Inputs pressed slightly early are buffered and fire as soon as the current move allows.

	Local timing mirrors the server: combo index, chain windows (the clip's "Chain" marker or
	just after its last hit), feint windows, cooldowns (server cooldown attributes plus local
	guards against double presses).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Clip = require(Shared.Animation.Clip)
local ClipLibrary = require(Shared.Animation.ClipLibrary)
local Combat = require(Shared.Config.Combat)
local Dust = require(Shared.Config.Dust)
local Impulse = require(Shared.Util.Impulse)
local Net = require(Shared.Net)
local Semblances = require(Shared.Config.Semblances)
local Signal = require(Shared.Util.Signal)
local WeaponModels = require(Shared.Config.WeaponModels)
local Weapons = require(Shared.Config.Weapons)

local ProfileStore = require(script.Parent.Parent.State.ProfileStore)
local AnimationController = require(script.Parent.AnimationController)
local CameraController = require(script.Parent.CameraController)
local InputController = require(script.Parent.InputController)
local MovementController = require(script.Parent.MovementController)

local CombatController = {}

-- Short messages for the HUD ("Not enough Fury", "No Fire Dust"...).
CombatController.Hint = Signal.new() :: Signal.Signal<string>

type Current = {
	seq: number,
	kind: string,
	clip: string,
	startedAt: number,
	busyUntil: number,
	chainAt: number,
	feintUntil: number,
}

local DODGE_CLIPS = {
	Forward = "Common.DodgeForward",
	Back = "Common.DodgeBack",
	Left = "Common.DodgeLeft",
	Right = "Common.DodgeRight",
	Air = "Common.AirDash",
}

local player = Players.LocalPlayer
local actionRemote: RemoteEvent
local aimRemote: UnreliableRemoteEvent

local seq = 0
local current: Current? = nil
local combo = 0
local comboExpires = 0
local comboLockUntil = 0
local shotCount = 0
local buffered: { action: string, expires: number }? = nil
local localReady: { [string]: number } = {}
local aiming = false
local blocking = false
local lastAimSend = 0
local pendingRecoil: { aim: Vector3, air: number, ground: number }? = nil

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

--[[ STATE ]]

local function characterParts(): (Model?, Humanoid?, BasePart?)
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

local function weaponForm(model: Model): Weapons.FormDef?
	local weapon = Weapons.get(tostring(model:GetAttribute("Weapon") or ""))
	local formName = model:GetAttribute("WeaponForm")
	if weapon == nil or type(formName) ~= "string" then
		return nil
	end
	return Weapons.form(weapon, formName)
end

local function incapacitated(model: Model, humanoid: Humanoid): boolean
	return humanoid.Health <= 0
		or model:GetAttribute("Stunned") == true
		or model:GetAttribute("GuardBroken") == true
		or model:GetAttribute("Knocked") == true
end

-- Cooldown readiness from the server attribute plus our own guard.
function CombatController.ready(name: string): boolean
	local model = player.Character
	if model == nil then
		return false
	end
	if os.clock() < (localReady[name] or 0) then
		return false
	end
	local readyAt = model:GetAttribute(`CD_{name}`)
	return type(readyAt) ~= "number" or Workspace:GetServerTimeNow() >= readyAt - 0.08
end

-- Remaining and total cooldown seconds (for the HUD).
function CombatController.cooldown(name: string): (number, number)
	local model = player.Character
	if model == nil then
		return 0, 1
	end
	local readyAt = model:GetAttribute(`CD_{name}`)
	local length = model:GetAttribute(`CDLen_{name}`)
	local serverRemaining = if type(readyAt) == "number" then readyAt - Workspace:GetServerTimeNow() else 0
	local localRemaining = (localReady[name] or 0) - os.clock()
	local remaining = math.max(serverRemaining, localRemaining, 0)
	return remaining, if type(length) == "number" and length > 0 then length else math.max(remaining, 1)
end

local function canAct(): boolean
	local model, humanoid = characterParts()
	if model == nil or humanoid == nil or incapacitated(model, humanoid) then
		return false
	end
	local active = current
	return active == nil or os.clock() >= active.chainAt
end

local function bufferInput(action: string)
	buffered = { action = action, expires = os.clock() + 0.35 }
end

--[[ AIMING ]]

local function muzzleOrigin(root: BasePart): Vector3
	return root.Position + Vector3.new(0, 1.4, 0)
end

-- World direction from the character toward whatever is under the crosshair / mouse.
local function aimDirection(): Vector3
	local model, _, root = characterParts()
	local camera = Workspace.CurrentCamera
	if model == nil or root == nil or camera == nil then
		return Vector3.new(0, 0, -1)
	end
	local screen: Vector2
	if aiming or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		screen = camera.ViewportSize / 2
	else
		screen = UserInputService:GetMouseLocation()
	end
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	rayParams.FilterDescendantsInstances = { model }
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 600, rayParams)
	local target = if result then result.Position else ray.Origin + ray.Direction * 600
	local direction = target - muzzleOrigin(root)
	return if direction.Magnitude > 0.1 then direction.Unit else camera.CFrame.LookVector
end

local function setAiming(on: boolean)
	if aiming == on then
		return
	end
	aiming = on
	local model = player.Character
	local form = if model then weaponForm(model) else nil
	local sniper = model ~= nil
		and model:GetAttribute("WeaponModel") == "CrescentScythe"
		and form ~= nil
		and form.ranged
	CameraController.setAiming(on, sniper)
	MovementController.setFaceCamera(on)
	actionRemote:FireServer("Aim", { on = on })
end

--[[ PREDICTED ACTIONS ]]

local function clipTiming(clip: Clip.Clip, speed: number): (number, number, number?)
	local rate = clip.speed * speed
	local duration = clip.length / rate
	local hits = Clip.markersNamed(clip, "Hit")
	local shots = Clip.markersNamed(clip, "Shoot")
	local first = if hits[1] then hits[1].t / rate elseif shots[1] then shots[1].t / rate else nil
	local last = 0
	for _, marker in hits do
		last = math.max(last, marker.t / rate)
	end
	for _, marker in shots do
		last = math.max(last, marker.t / rate)
	end
	local chain = Clip.markerTime(clip, "Chain")
	local chainAt = if chain then chain / rate elseif last > 0 then last + 0.06 else duration
	return duration, chainAt, first
end

-- Plays an action locally and sends it to the server. Returns the new sequence number.
local function predict(kind: string, clipId: string, payload: { [string]: any }, walkSpeed: number?): number?
	local model = player.Character
	local clip = ClipLibrary.get(clipId)
	if model == nil or clip == nil then
		return nil
	end
	seq += 1
	local id = seq
	payload.seq = id
	AnimationController.predict(id)
	AnimationController.play(model, clipId, { tag = id })

	local now = os.clock()
	local duration, chainAt, firstHit = clipTiming(clip, 1)
	current = {
		seq = id,
		kind = kind,
		clip = clipId,
		startedAt = now,
		busyUntil = now + duration,
		chainAt = now + chainAt,
		feintUntil = if firstHit then now + firstHit - Combat.FeintWindowPadding else 0,
	}
	MovementController.busy(chainAt, walkSpeed)
	actionRemote:FireServer(kind, payload)
	return id
end

local function cancelPredicted(id: number?)
	local active = current
	if active == nil or (id ~= nil and active.seq ~= id) then
		return
	end
	local model = player.Character
	local animator = AnimationController.get(model)
	if animator then
		animator:stop(active.clip, 0.12)
	end
	if active.kind == "M1" then
		combo = math.max(0, combo - 1)
	end
	current = nil
	MovementController.clearBusy()
end

--[[ ACTIONS ]]

local function attack()
	local model, _, root = characterParts()
	if model == nil or root == nil then
		return
	end
	local form = weaponForm(model)
	if form == nil then
		return
	end
	if not canAct() then
		bufferInput("Attack")
		return
	end
	local now = os.clock()

	local shoot = form.shoot
	if form.ranged and shoot then
		if not CombatController.ready("Shoot") then
			return
		end
		local clipId = if shoot.altClip and shotCount % 2 == 1 then shoot.altClip else shoot.clip
		shotCount += 1
		localReady.Shoot = now + shoot.cooldown
		local aim = aimDirection()
		if not aiming then
			MovementController.turnToCamera()
		end
		local flat = Vector3.new(aim.X, 0, aim.Z)
		predict(
			"M1",
			clipId,
			{ look = if flat.Magnitude > 0.01 then flat.Unit else nil, aim = aim },
			Combat.AimWalkSpeed
		)
		pendingRecoil = { aim = aim, air = shoot.shot.recoil or 0, ground = shoot.shot.groundRecoil or 0 }
		return
	end

	local chain = form.m1
	if chain == nil or #chain == 0 or now < comboLockUntil then
		return
	end
	if now > comboExpires then
		combo = 0
	end
	local index = (combo % #chain) + 1
	combo = index
	local move = chain[index]
	MovementController.turnToCamera()
	predict("M1", move.clip, { look = MovementController.cameraFlatLook() })
	local clip = ClipLibrary.get(move.clip)
	local duration = if clip then clip.length / clip.speed else 0.6
	comboExpires = now + duration + Combat.ComboResetTime
	if index == #chain then
		comboLockUntil = now + duration + Combat.ComboEndLag
	end
	local active = current
	if active then
		active.feintUntil = if move.feintable then active.feintUntil else 0
	end
end

local function critical()
	local model = player.Character
	local form = if model then weaponForm(model) else nil
	local move = if form then form.critical else nil
	if move == nil then
		return
	end
	if not canAct() then
		bufferInput("Critical")
		return
	end
	if not CombatController.ready("Critical") then
		CombatController.Hint:Fire("Critical is recharging")
		return
	end
	localReady.Critical = os.clock() + 0.5
	combo = 0
	local aim = aimDirection()
	MovementController.turnToCamera()
	predict(
		"Critical",
		move.clip,
		{ look = MovementController.cameraFlatLook(), aim = aim },
		Combat.AttackWalkSpeed * 0.6
	)
	local active = current
	if active and not move.feintable then
		active.feintUntil = 0
	end
end

local function feint()
	local active = current
	if active == nil or os.clock() > active.feintUntil or not CombatController.ready("Feint") then
		return
	end
	localReady.Feint = os.clock() + Combat.FeintCooldown
	cancelPredicted(nil)
	combo = 0
	predict("Feint", "Common.Feint", {})
end

local function dodge()
	local model, humanoid = characterParts()
	if model == nil or humanoid == nil or incapacitated(model, humanoid) then
		return
	end
	local active = current
	if active and os.clock() < active.chainAt then
		bufferInput("Dodge")
		return
	end
	if not CombatController.ready("Dodge") then
		return
	end
	local grounded = MovementController.isGrounded()
	local name, direction = MovementController.dodgeDirection()
	if not grounded then
		if MovementController.airDashesLeft() <= 0 then
			return
		end
		name = "Air"
		local move = humanoid.MoveDirection
		direction = if move.Magnitude > 0.1
			then Vector3.new(move.X, 0, move.Z).Unit
			else MovementController.cameraFlatLook()
	end
	localReady.Dodge = os.clock() + 0.3
	predict("Dodge", DODGE_CLIPS[name], { dir = name, air = not grounded }, 0)
	MovementController.dash(direction, not grounded)
end

local function shift()
	local model = player.Character
	if model == nil or not canAct() or not CombatController.ready("Shift") then
		return
	end
	local spec = WeaponModels[tostring(model:GetAttribute("WeaponModel") or "")]
	localReady.Shift = os.clock() + (if spec then spec.shiftTime else 0.5) + 0.3
	setAiming(false)
	predict("Shift", "Common.Shift", {}, Combat.CastWalkSpeed)
end

local function semblance()
	local model, _, root = characterParts()
	if model == nil or root == nil then
		return
	end
	local id = model:GetAttribute("Semblance")
	local def = if type(id) == "string" then Semblances.get(id) else nil
	if def == nil then
		CombatController.Hint:Fire("You haven't unlocked your Semblance yet")
		return
	end
	if not canAct() then
		bufferInput("Semblance")
		return
	end
	if not CombatController.ready("Semblance") then
		CombatController.Hint:Fire(`{def.name} is recharging`)
		return
	end
	local p = def.params
	local look = MovementController.cameraFlatLook()
	if def.id == "Retribution" then
		local fury = model:GetAttribute("Fury")
		if type(fury) ~= "number" or fury < p.minFury then
			CombatController.Hint:Fire(`Need {p.minFury} Fury to ignite`)
			return
		end
	end
	localReady.Semblance = os.clock() + 0.5
	MovementController.turnToCamera()
	if def.id == "Velocity" then
		predict("Semblance", def.clip, { look = look }, 0)
		local _, _, rootPart = characterParts()
		if rootPart then
			Impulse.apply(rootPart, look * p.speed, { duration = p.duration, planar = true, name = "Dash" })
			CameraController.punch(14)
		end
	elseif def.id == "Shadow" then
		predict("Semblance", def.clip, { look = look }, 0)
		MovementController.blink(-look, p.distance)
	elseif def.id == "Glyph" then
		predict("Semblance", def.clip, { look = look }, 0)
		local camera = Workspace.CurrentCamera
		local direction = if camera then camera.CFrame.LookVector else look
		local launch = (Vector3.new(direction.X, 0, direction.Z) * 0.75 + Vector3.new(0, 1, 0)).Unit
		MovementController.launch(launch * p.launch, 0.32)
	else
		predict("Semblance", def.clip, { look = look, aim = aimDirection() }, Combat.CastWalkSpeed)
	end
end

local function castDust(slot: number)
	local model = player.Character
	local id = Dust.Order[slot]
	local def = if id then Dust.get(id) else nil
	if model == nil or def == nil then
		return
	end
	local profile = ProfileStore.get()
	local vials = if profile then profile.Dust[def.id] or 0 else 0
	if vials <= 0 then
		CombatController.Hint:Fire(`No {def.name} — buy more at From Dust Till Dawn`)
		return
	end
	if not canAct() then
		bufferInput(`Dust{slot}`)
		return
	end
	if not CombatController.ready(`Dust_{def.id}`) then
		return
	end
	localReady[`Dust_{def.id}`] = os.clock() + 0.5
	MovementController.turnToCamera()
	predict("Dust", def.clip, {
		id = def.id,
		look = MovementController.cameraFlatLook(),
		aim = aimDirection(),
		air = not MovementController.isGrounded(),
	}, Combat.CastWalkSpeed)
end

local function slide()
	if not MovementController.isSprinting() or not MovementController.isGrounded() then
		return
	end
	if not canAct() or not CombatController.ready("Slide") then
		return
	end
	localReady.Slide = os.clock() + Combat.SlideCooldown
	predict("Slide", "Common.Slide", {}, 0)
	MovementController.slide()
end

local function blockStart()
	local model, humanoid = characterParts()
	if model == nil or humanoid == nil or incapacitated(model, humanoid) then
		return
	end
	local active = current
	if active and os.clock() < active.chainAt then
		bufferInput("Block")
		return
	end
	blocking = true
	setAiming(false)
	actionRemote:FireServer("BlockStart", {})
	local animator = AnimationController.get(model)
	if animator then
		animator:overrideState("Blocking", true, 0.45)
	end
end

local function blockEnd()
	if not blocking then
		return
	end
	blocking = false
	actionRemote:FireServer("BlockEnd", {})
	local animator = AnimationController.get(player.Character)
	if animator then
		animator:overrideState("Blocking", false, 0.3)
	end
end

local handlers: { [string]: () -> () } = {
	Attack = attack,
	Critical = critical,
	Dodge = dodge,
	Shift = shift,
	Semblance = semblance,
	Dust1 = function()
		castDust(1)
	end,
	Dust2 = function()
		castDust(2)
	end,
	Dust3 = function()
		castDust(3)
	end,
	Dust4 = function()
		castDust(4)
	end,
	Slide = slide,
	Block = blockStart,
	Execute = function()
		actionRemote:FireServer("Execute", {})
	end,
}

local function onBegan(action: string)
	if action == "Alt" then
		local model = player.Character
		local form = if model then weaponForm(model) else nil
		if form and form.ranged then
			setAiming(true)
		else
			feint()
		end
		return
	end
	local handler = handlers[action]
	if handler then
		handler()
	end
end

local function onEnded(action: string)
	if action == "Block" then
		blockEnd()
	elseif action == "Alt" then
		setAiming(false)
	end
end

local function step()
	local now = os.clock()
	local active = current
	if active and now >= active.busyUntil then
		current = nil
	end
	local pending = buffered
	if pending then
		if now > pending.expires then
			buffered = nil
		elseif canAct() then
			buffered = nil
			local handler = handlers[pending.action]
			if handler then
				handler()
			end
		end
	end

	local model = player.Character
	if aiming then
		local form = if model then weaponForm(model) else nil
		if form == nil or not form.ranged or (model and model:GetAttribute("Knocked")) then
			setAiming(false)
		elseif now - lastAimSend > 0.1 then
			lastAimSend = now
			local camera = Workspace.CurrentCamera
			if camera then
				aimRemote:FireServer(math.deg(math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1))))
			end
		end
	end
	if blocking and not InputController.isDown("Block") then
		blockEnd()
	end
end

function CombatController.isAiming(): boolean
	return aiming
end

function CombatController.init()
	actionRemote = Net.event("Action")
	aimRemote = Net.unreliable("Aim")
end

function CombatController.start()
	InputController.Began:Connect(onBegan)
	InputController.Ended:Connect(onEnded)
	RunService.Heartbeat:Connect(step)

	Net.event("Effects").OnClientEvent:Connect(function(kind: any, payload: any)
		if kind == "Reject" and type(payload) == "table" then
			local id = payload.seq
			if type(id) == "number" then
				AnimationController.forget(id)
				cancelPredicted(id)
			end
		end
	end)

	-- Lunges and recoil follow the animation's own markers so they line up with the motion.
	AnimationController.Marker:Connect(function(rig, _clipId, name, data)
		if rig ~= player.Character then
			return
		end
		if name == "Lunge" then
			MovementController.lunge(if type(data) == "number" then data else 30)
		elseif name == "Shoot" then
			local recoil = pendingRecoil
			if recoil then
				pendingRecoil = nil
				MovementController.recoil(recoil.aim, recoil.air, recoil.ground)
				CameraController.shake(0.12)
			end
		end
	end)

	player.CharacterAdded:Connect(function()
		current = nil
		combo = 0
		buffered = nil
		blocking = false
		aiming = false
		CameraController.setAiming(false)
	end)
end

return CombatController
