--!strict
--[[
	Every remote the game uses, created by the server at startup and awaited by clients.

	Client -> Server
	  Action   (RemoteEvent)           combat and ability input: (kind, payload)
	  Aim      (UnreliableRemoteEvent) aim pitch while aiming a ranged form
	  Request  (RemoteFunction)        menus: character creation, semblance spin, shop, stats

	Server -> Client
	  Effects  (RemoteEvent)  animation, hit and VFX broadcasts: (kind, payload)
	  Motion   (RemoteEvent)  impulses for the receiving player's own character (knockback, pulls)
	  Profile  (RemoteEvent)  the receiving player's saved profile snapshot
	  Notify   (RemoteEvent)  toast messages
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = { "Action", "Effects", "Motion", "Profile", "Notify" }
local UNRELIABLE = { "Aim" }
local FUNCTIONS = { "Request" }

local Net = {}

local folder: Instance
if RunService:IsServer() then
	local created = Instance.new("Folder")
	created.Name = "Remotes"
	for _, name in EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = created
	end
	for _, name in UNRELIABLE do
		local remote = Instance.new("UnreliableRemoteEvent")
		remote.Name = name
		remote.Parent = created
	end
	for _, name in FUNCTIONS do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = created
	end
	created.Parent = ReplicatedStorage
	folder = created
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

function Net.event(name: string): RemoteEvent
	local remote = folder:WaitForChild(name)
	assert(remote:IsA("RemoteEvent"), `{name} is not a RemoteEvent`)
	return remote
end

function Net.unreliable(name: string): UnreliableRemoteEvent
	local remote = folder:WaitForChild(name)
	assert(remote:IsA("UnreliableRemoteEvent"), `{name} is not an UnreliableRemoteEvent`)
	return remote
end

function Net.func(name: string): RemoteFunction
	local remote = folder:WaitForChild(name)
	assert(remote:IsA("RemoteFunction"), `{name} is not a RemoteFunction`)
	return remote
end

return Net
