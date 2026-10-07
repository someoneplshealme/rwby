--!strict
--[[
	InputController: maps keyboard, mouse and gamepad input to game actions.

	  Attack       LMB            R2      (shoot in ranged forms)
	  Alt          RMB            L2      feint (melee) / aim (ranged)
	  Critical     R              X
	  Block        F (hold)       L1      tap at the right moment to parry
	  Dodge        Q              B       air dash when airborne
	  Shift        T              DPadUp  mecha-shift your weapon
	  Semblance    E              R1
	  Dust1-4      1 2 3 4        DPad Left/Down/Right, R3
	  Execute      B              DPadDown (hold Y)
	  Slide        C              ...
	  Sprint       hold Shift or double-tap W, L3
	  Menu         M              Select
]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)

local InputController = {}

InputController.Began = Signal.new() :: Signal.Signal<string>
InputController.Ended = Signal.new() :: Signal.Signal<string>

-- Set while a text box or menu captures input.
InputController.blocked = false

local BINDINGS: { [Enum.KeyCode | Enum.UserInputType]: string } = {
	[Enum.UserInputType.MouseButton1] = "Attack",
	[Enum.UserInputType.MouseButton2] = "Alt",
	[Enum.KeyCode.R] = "Critical",
	[Enum.KeyCode.F] = "Block",
	[Enum.KeyCode.Q] = "Dodge",
	[Enum.KeyCode.T] = "Shift",
	[Enum.KeyCode.E] = "Semblance",
	[Enum.KeyCode.One] = "Dust1",
	[Enum.KeyCode.Two] = "Dust2",
	[Enum.KeyCode.Three] = "Dust3",
	[Enum.KeyCode.Four] = "Dust4",
	[Enum.KeyCode.B] = "Execute",
	[Enum.KeyCode.C] = "Slide",
	[Enum.KeyCode.LeftShift] = "Sprint",
	[Enum.KeyCode.M] = "Menu",
	[Enum.KeyCode.ButtonR2] = "Attack",
	[Enum.KeyCode.ButtonL2] = "Alt",
	[Enum.KeyCode.ButtonX] = "Critical",
	[Enum.KeyCode.ButtonL1] = "Block",
	[Enum.KeyCode.ButtonB] = "Dodge",
	[Enum.KeyCode.DPadUp] = "Shift",
	[Enum.KeyCode.ButtonR1] = "Semblance",
	[Enum.KeyCode.DPadLeft] = "Dust1",
	[Enum.KeyCode.DPadDown] = "Dust2",
	[Enum.KeyCode.DPadRight] = "Dust3",
	[Enum.KeyCode.ButtonR3] = "Dust4",
	[Enum.KeyCode.ButtonL3] = "Sprint",
	[Enum.KeyCode.ButtonSelect] = "Menu",
}

local down: { [string]: boolean } = {}
local lastForwardTap = 0

function InputController.isDown(action: string): boolean
	return down[action] == true
end

local function actionFor(input: InputObject): string?
	local byKey = BINDINGS[input.KeyCode]
	if byKey then
		return byKey
	end
	return BINDINGS[input.UserInputType]
end

local function began(input: InputObject, processed: boolean)
	if input.KeyCode == Enum.KeyCode.W and not processed then
		local now = os.clock()
		if now - lastForwardTap <= Combat.DoubleTapWindow then
			InputController.Began:Fire("SprintTap")
		end
		lastForwardTap = now
	end
	if processed or InputController.blocked then
		return
	end
	local action = actionFor(input)
	if action and not down[action] then
		down[action] = true
		InputController.Began:Fire(action)
	end
end

local function ended(input: InputObject, _processed: boolean)
	local action = actionFor(input)
	if action and down[action] then
		down[action] = nil
		InputController.Ended:Fire(action)
	end
end

function InputController.init() end

function InputController.start()
	UserInputService.InputBegan:Connect(began)
	UserInputService.InputEnded:Connect(ended)
	UserInputService.WindowFocusReleased:Connect(function()
		for action in down do
			InputController.Ended:Fire(action)
		end
		table.clear(down)
	end)
end

return InputController
