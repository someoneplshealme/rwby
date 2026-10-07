--!strict
--[[
	Client bootstrap. Waits for the game to finish loading, then initialises every controller
	(init: build state and UI) before starting them (start: connect events).
]]

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Controllers = script.Controllers

local ProfileStore = require(script.State.ProfileStore)

local order = {
	require(Controllers.InputController),
	require(Controllers.AnimationController),
	require(Controllers.MovementController),
	require(Controllers.CameraController),
	require(Controllers.WeaponVisualController),
	require(Controllers.EffectsController),
	require(Controllers.CombatController),
	require(Controllers.HudController),
	require(Controllers.MenuController),
	require(Controllers.WorldController),
	require(Controllers.OverheadController),
} :: { { init: () -> (), start: () -> () } }

ProfileStore.init()
for _, controller in order do
	controller.init()
end
for _, controller in order do
	controller.start()
end
