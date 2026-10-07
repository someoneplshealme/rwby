--!strict
--[[
	WeaponVisualController: makes weapons look alive on this client.

	* Shows every weapon in its current form by offsetting each piece's Motor6D.Transform.
	* When a rig's WeaponForm changes, plays the mecha-shift: pieces cascade from one form to
	  the other (see Animation/WeaponShift) with a mechanical click.
	* Creates swing trails in the wielder's accent colour and switches them on/off from the
	  "TrailOn"/"TrailOff" markers in attack clips.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local WeaponModels = require(Shared.Config.WeaponModels)
local WeaponShift = require(Shared.Animation.WeaponShift)

local AnimationController = require(script.Parent.AnimationController)
local Audio = require(script.Parent.Parent.Util.Audio)

type PieceBinding = {
	piece: WeaponModels.Piece,
	motor: Motor6D,
	part: BasePart,
	index: number,
	count: number,
}

type TrailBinding = {
	trail: Trail,
	forms: { [string]: boolean }?,
}

type WeaponState = {
	rig: Model,
	container: Instance,
	spec: WeaponModels.WeaponModel,
	pieces: { PieceBinding },
	trails: { TrailBinding },
	form: string,
	fromForm: string?,
	shiftStart: number,
	trailsOn: boolean,
}

local WeaponVisualController = {}

local states: { [Model]: WeaponState } = {}

local function bindWeapon(rig: Model): WeaponState?
	local container = rig:FindFirstChild("Weapon")
	local modelId = rig:GetAttribute("WeaponModel")
	local spec = if type(modelId) == "string" then WeaponModels[modelId] else nil
	if container == nil or spec == nil then
		return nil
	end
	local pieces: { PieceBinding } = {}
	local trails: { TrailBinding } = {}
	local accent = rig:GetAttribute("WeaponAccent")
	local color = if typeof(accent) == "Color3" then accent else Color3.fromRGB(220, 40, 60)

	local hands: { { side: string, list: { WeaponModels.Piece }? } } = {
		{ side = "Right", list = spec.right },
		{ side = "Left", list = spec.left },
	}
	for _, hand in hands do
		local handle = container:FindFirstChild(`Handle{hand.side}`)
		local list = hand.list
		if handle and list then
			for index, piece in list do
				local motor = handle:FindFirstChild(piece.name)
				local part = container:FindFirstChild(piece.name)
				if motor and motor:IsA("Motor6D") and motor.Part1 then
					local partInstance = motor.Part1 :: BasePart
					table.insert(pieces, {
						piece = piece,
						motor = motor,
						part = partInstance,
						index = index,
						count = #list,
					})
				elseif part then
					warn(`[WeaponVisual] piece {piece.name} has no motor`)
				end
			end
			for index, trailSpec in spec.trails do
				if trailSpec.hand == hand.side then
					local a = handle:FindFirstChild(`Trail{index}A`)
					local b = handle:FindFirstChild(`Trail{index}B`)
					if a and b and a:IsA("Attachment") and b:IsA("Attachment") then
						local trail = Instance.new("Trail")
						trail.Attachment0 = a
						trail.Attachment1 = b
						trail.Lifetime = 0.2
						trail.MinLength = 0.05
						trail.FaceCamera = false
						trail.LightEmission = 0.8
						trail.LightInfluence = 0
						trail.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
						trail.Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0.15),
							NumberSequenceKeypoint.new(0.6, 0.6),
							NumberSequenceKeypoint.new(1, 1),
						})
						trail.WidthScale = NumberSequence.new(1, 0.3)
						trail.Enabled = false
						trail.Parent = handle
						table.insert(trails, { trail = trail, forms = trailSpec.forms })
					end
				end
			end
		end
	end

	local form = rig:GetAttribute("WeaponForm")
	return {
		rig = rig,
		container = container,
		spec = spec,
		pieces = pieces,
		trails = trails,
		form = if type(form) == "string" then form else spec.forms[1],
		fromForm = nil,
		shiftStart = 0,
		trailsOn = false,
	}
end

local function setTrails(state: WeaponState, on: boolean)
	state.trailsOn = on
	for _, binding in state.trails do
		local forms = binding.forms
		binding.trail.Enabled = on and (forms == nil or forms[state.form] == true)
	end
end

local function update()
	for rig, state in states do
		if rig.Parent == nil or state.container.Parent ~= rig then
			states[rig] = nil
			continue
		end
		local form = rig:GetAttribute("WeaponForm")
		if type(form) == "string" and form ~= state.form and state.spec.forms[1] ~= nil then
			state.fromForm = state.form
			state.form = form
			state.shiftStart = os.clock()
			setTrails(state, false)
			local root = rig:FindFirstChild("HumanoidRootPart")
			if root then
				Audio.playOn("Shift", root)
			end
		end

		local fromForm = state.fromForm
		local elapsed = os.clock() - state.shiftStart
		local duration = state.spec.shiftTime
		if fromForm and elapsed >= duration then
			state.fromForm = nil
			fromForm = nil
		end

		for _, binding in state.pieces do
			local piece = binding.piece
			local target: CFrame
			local transparency: number
			if fromForm then
				target, transparency = WeaponShift.sample(piece, binding.index, binding.count, fromForm, state.form, elapsed, duration)
			else
				target = piece.forms[state.form] or binding.motor.C0
				local hidden = piece.hiddenIn
				transparency = if hidden and hidden[state.form] then 1 else 0
			end
			binding.motor.Transform = binding.motor.C0:Inverse() * target
			if binding.part.Transparency ~= transparency then
				binding.part.Transparency = transparency
			end
		end
	end
end

local function track(rig: Instance)
	if not rig:IsA("Model") then
		return
	end
	local function refresh()
		task.defer(function()
			local state = bindWeapon(rig)
			if state then
				states[rig] = state
			else
				states[rig] = nil
			end
		end)
	end
	refresh()
	rig.ChildAdded:Connect(function(child)
		if child.Name == "Weapon" then
			refresh()
		end
	end)
	rig:GetAttributeChangedSignal("WeaponModel"):Connect(refresh)
end

function WeaponVisualController.init() end

function WeaponVisualController.start()
	for _, rig in CollectionService:GetTagged("Rig") do
		track(rig)
	end
	CollectionService:GetInstanceAddedSignal("Rig"):Connect(track)

	AnimationController.Marker:Connect(function(rig, _clipId, name)
		local state = states[rig]
		if state == nil then
			return
		end
		if name == "TrailOn" then
			setTrails(state, true)
		elseif name == "TrailOff" then
			setTrails(state, false)
		end
	end)
	-- Any new action ends lingering trails from the previous one.
	AnimationController.Played:Connect(function(rig)
		local state = states[rig]
		if state and state.trailsOn then
			setTrails(state, false)
		end
	end)

	RunService.PreSimulation:Connect(update)
end

return WeaponVisualController
