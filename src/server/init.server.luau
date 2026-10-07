--!strict
--[[
	Server bootstrap. Services are initialised in dependency order (init sets up state and
	remotes, start connects events), so nothing races another service's setup.
]]

local Combat = script.Combat
local Services = script.Services
local Characters = script.Characters

local order = {
	require(script.World.WorldService),
	require(Services.DataService),
	require(Combat.CombatService),
	require(Combat.Abilities),
	require(Characters.CharacterService),
	require(Services.ProgressionService),
	require(Services.RequestService),
	require(script.Grimm.GrimmService),
} :: { { init: () -> (), start: (() -> ())? } }

local Abilities = require(Combat.Abilities)
local RequestService = require(Services.RequestService)
Abilities.takeDust = RequestService.takeDust

for _, service in order do
	service.init()
end
for _, service in order do
	local start = service.start
	if start then
		start()
	end
end

print("[Grimmfall] server ready")
