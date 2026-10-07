--!strict
--[[
	Client mirror of the local player's saved profile, kept in sync by the Profile remote.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

export type Profile = {
	Created: boolean,
	Name: string,
	Kingdom: string,
	Faunus: string,
	Color: string,
	Weapon: string,
	Semblance: string,
	Spins: number,
	Level: number,
	XP: number,
	Points: number,
	Attributes: { [string]: number },
	Lien: number,
	Dust: { [string]: number },
	Stats: { [string]: number },
}

local ProfileStore = {}

ProfileStore.Changed = Signal.new() :: Signal.Signal<Profile>

local current: Profile? = nil

function ProfileStore.get(): Profile?
	return current
end

function ProfileStore.init()
	Net.event("Profile").OnClientEvent:Connect(function(profile: any)
		if type(profile) == "table" then
			current = profile
			ProfileStore.Changed:Fire(profile)
		end
	end)
end

return ProfileStore
