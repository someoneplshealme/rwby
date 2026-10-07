--!strict
--[[
	OverheadController: name plates over other Huntsmen and Grimm, drawn locally.
	Huntsmen show name, level and thin Aura/Health bars; Grimm show their name in red and health.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Parent.UI.Theme)

local New = Theme.New

local OverheadController = {}

type Plate = {
	gui: BillboardGui,
	name: TextLabel,
	aura: Frame,
	health: Frame,
	auraHolder: Frame,
}

local player = Players.LocalPlayer
local plates: { [Model]: Plate } = {}
local timer = 0

local function thinBar(parent: Instance, y: number, color: Color3): (Frame, Frame)
	local holder = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, y),
		Size = UDim2.new(0.8, 0, 0, 5),
		BackgroundColor3 = Color3.fromRGB(20, 18, 26),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Parent = parent,
	}, { Theme.corner(3) })
	local fill = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = holder,
	}, { Theme.corner(3) })
	return holder, fill
end

local function attach(model: Instance)
	if not model:IsA("Model") or model == player.Character or plates[model] then
		return
	end
	task.spawn(function()
		local head = model:WaitForChild("Head", 10)
		if head == nil or not head:IsA("BasePart") or plates[model] or model == player.Character then
			return
		end
		local isGrimm = model:GetAttribute("IsGrimm") == true
		local gui = New("BillboardGui", {
			Name = "Overhead",
			Adornee = head,
			Size = UDim2.fromOffset(160, 44),
			StudsOffsetWorldSpace = Vector3.new(0, if isGrimm then 3.2 else 2.6, 0),
			MaxDistance = 80,
			LightInfluence = 0,
			AlwaysOnTop = false,
			ResetOnSpawn = false,
			Parent = player:WaitForChild("PlayerGui"),
		})
		local name = New("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			Font = Theme.Fonts.Heading,
			TextSize = 14,
			TextColor3 = if isGrimm then Color3.fromRGB(255, 90, 80) else Theme.Colors.Text,
			TextStrokeTransparency = 0.4,
			Text = "",
			Parent = gui,
		})
		local auraHolder, aura = thinBar(gui, 22, Theme.Colors.Aura)
		local _, health = thinBar(gui, 30, Theme.Colors.Health)
		auraHolder.Visible = not isGrimm
		plates[model] = { gui = gui, name = name, aura = aura, health = health, auraHolder = auraHolder }
	end)
end

local function detach(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local plate = plates[model]
	if plate then
		plate.gui:Destroy()
		plates[model] = nil
	end
end

local function update(dt: number)
	timer -= dt
	if timer > 0 then
		return
	end
	timer = 0.1
	for model, plate in plates do
		if model.Parent == nil then
			detach(model)
			continue
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local displayName = model:GetAttribute("DisplayName")
		local level = model:GetAttribute("Level")
		local label = if type(displayName) == "string" then displayName else model.Name
		plate.name.Text = if type(level) == "number" then `{label}  Lv{level}` else label
		if model:GetAttribute("Clone") then
			plate.gui.Enabled = false
			continue
		end
		if humanoid then
			plate.health.Size = UDim2.fromScale(math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1), 1)
			plate.gui.Enabled = humanoid.Health > 0
		end
		local aura = tonumber(model:GetAttribute("Aura")) or 0
		local maxAura = tonumber(model:GetAttribute("MaxAura")) or 100
		plate.aura.Size = UDim2.fromScale(math.clamp(aura / math.max(maxAura, 1), 0, 1), 1)
		local color = model:GetAttribute("SignatureColor")
		if typeof(color) == "Color3" then
			plate.aura.BackgroundColor3 = color
		end
	end
end

function OverheadController.init() end

function OverheadController.start()
	for _, model in CollectionService:GetTagged("Rig") do
		attach(model)
	end
	CollectionService:GetInstanceAddedSignal("Rig"):Connect(attach)
	CollectionService:GetInstanceRemovedSignal("Rig"):Connect(detach)
	player.CharacterAdded:Connect(function(character)
		detach(character)
	end)
	RunService.Heartbeat:Connect(update)
end

return OverheadController
