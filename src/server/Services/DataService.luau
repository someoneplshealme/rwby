--!strict
--[[
	DataService: player profiles in DataStores.

	* Session locking: a profile is claimed by one server at a time (UpdateAsync), so joining a
	  new server while the old one is still saving cannot duplicate or roll back progress.
	* Autosave every 90 seconds, on leave and on shutdown.
	* Falls back to a temporary in-memory profile when DataStores are unavailable (for example
	  an unpublished place in Studio), so the game is always playable.
	* Every change is pushed to the owning client on the Profile remote.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Progression = require(Shared.Config.Progression)
local Signal = require(Shared.Util.Signal)

export type Profile = {
	Version: number,
	Created: boolean,
	Name: string,
	Kingdom: string,
	Faunus: string, -- trait id, "" for Human
	Color: string,
	Weapon: string,
	Semblance: string,
	Spins: number,
	Level: number,
	XP: number,
	Points: number,
	Attributes: Progression.Attributes,
	Lien: number,
	Dust: { [string]: number },
	Stats: { [string]: number },
}

local STORE_NAME = "RemnantProfiles_v1"
local LOCK_EXPIRY = 600
local AUTOSAVE_INTERVAL = 90

local DataService = {}

DataService.Loaded = Signal.new() :: Signal.Signal<Player, Profile>
DataService.Changed = Signal.new() :: Signal.Signal<Player, Profile>

local profiles: { [Player]: Profile } = {}
local persistent: { [Player]: boolean } = {}
local dirty: { [Player]: boolean } = {}
local loading: { [Player]: boolean } = {}
local store: DataStore? = nil
local profileRemote: RemoteEvent

local function template(): Profile
	return {
		Version = 1,
		Created = false,
		Name = "",
		Kingdom = "Vale",
		Faunus = "",
		Color = "Rose",
		Weapon = "CrescentScythe",
		Semblance = "",
		Spins = 3,
		Level = 1,
		XP = 0,
		Points = 0,
		Attributes = Progression.emptyAttributes(),
		Lien = 120,
		Dust = { Fire = 3, Ice = 3, Lightning = 2, Gravity = 2 },
		Stats = { GrimmSlain = 0, Knockouts = 0, Deaths = 0 },
	}
end

-- Fills in any fields missing from older saves.
local function reconcile(data: any, defaults: any): any
	if type(data) ~= "table" then
		return defaults
	end
	for key, value in defaults do
		if data[key] == nil then
			data[key] = value
		elseif type(value) == "table" and type(data[key]) == "table" then
			reconcile(data[key], value)
		end
	end
	return data
end

local function key(player: Player): string
	return `player_{player.UserId}`
end

local function lockFree(lock: any): boolean
	return type(lock) ~= "table" or lock.job == game.JobId or os.time() - (tonumber(lock.time) or 0) > LOCK_EXPIRY
end

local function loadFromStore(player: Player): (Profile?, boolean)
	local dataStore = store
	if dataStore == nil then
		return nil, false
	end
	for attempt = 1, 6 do
		local force = attempt >= 5 -- the previous server most likely crashed without releasing
		local ok, result = pcall(function()
			return dataStore:UpdateAsync(key(player), function(current: any)
				local record = if type(current) == "table" then current else {}
				if not force and not lockFree(record.lock) then
					return nil
				end
				record.lock = { job = game.JobId, time = os.time() }
				return record
			end)
		end)
		if ok and type(result) == "table" then
			return reconcile(result.data, template()), true
		elseif not ok then
			warn(`[Data] load attempt {attempt} for {player.Name} failed: {result}`)
		end
		if not player.Parent then
			return nil, false
		end
		task.wait(attempt * 1.5)
	end
	return nil, false
end

local function save(player: Player, release: boolean): boolean
	local dataStore = store
	local profile = profiles[player]
	if dataStore == nil or profile == nil or not persistent[player] then
		return false
	end
	local snapshot = HttpService:JSONDecode(HttpService:JSONEncode(profile))
	local ok, err = pcall(function()
		dataStore:UpdateAsync(key(player), function(current: any)
			local record = if type(current) == "table" then current else {}
			if type(record.lock) == "table" and record.lock.job ~= game.JobId then
				return nil -- another server owns this profile now
			end
			record.data = snapshot
			record.lock = if release then nil else { job = game.JobId, time = os.time() }
			return record
		end)
	end)
	if not ok then
		warn(`[Data] save for {player.Name} failed: {err}`)
		return false
	end
	dirty[player] = nil
	return true
end

function DataService.get(player: Player): Profile?
	return profiles[player]
end

-- Waits until the player's profile is ready (or they leave).
function DataService.await(player: Player): Profile?
	while player.Parent and profiles[player] == nil do
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService.push(player: Player)
	local profile = profiles[player]
	if profile then
		profileRemote:FireClient(player, profile)
	end
end

-- Mutates a profile, marks it for saving and syncs it to the client.
function DataService.update(player: Player, mutate: (Profile) -> ())
	local profile = profiles[player]
	if profile == nil then
		return
	end
	mutate(profile)
	dirty[player] = true
	DataService.push(player)
	DataService.Changed:Fire(player, profile)
end

function DataService.isPersistent(player: Player): boolean
	return persistent[player] == true
end

local function onPlayerAdded(player: Player)
	if loading[player] or profiles[player] then
		return
	end
	loading[player] = true
	local profile, fromStore = loadFromStore(player)
	loading[player] = nil
	if not player.Parent then
		return
	end
	if profile == nil then
		if store ~= nil then
			warn(`[Data] could not load {player.Name}'s profile; using a temporary one this session`)
		end
		profile = template()
	end
	local ready = profile :: Profile
	profiles[player] = ready
	persistent[player] = fromStore
	DataService.push(player)
	DataService.Loaded:Fire(player, ready)
end

local function onPlayerRemoving(player: Player)
	if profiles[player] then
		save(player, true)
	end
	profiles[player] = nil
	persistent[player] = nil
	dirty[player] = nil
end

function DataService.init()
	profileRemote = Net.event("Profile")
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn(`[Data] DataStores unavailable ({result}); progress will not be saved this session`)
	end
	-- Studio without API access: probe once so we fail fast instead of retrying per player.
	if RunService:IsStudio() and store then
		local probe = store
		local probeOk = pcall(function()
			probe:GetAsync("__probe")
		end)
		if not probeOk then
			warn(
				"[Data] Studio has no DataStore access (enable 'Studio Access to API Services'); using temporary profiles"
			)
			store = nil
		end
	end
end

function DataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in dirty do
				task.spawn(save, player, false)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				save(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
