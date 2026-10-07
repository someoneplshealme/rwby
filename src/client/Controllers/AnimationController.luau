--!strict
--[[
	AnimationController: one CharacterAnimator per rig (every model tagged "Rig": players,
	Grimm, shadow clones), all updated in PreSimulation.

	Server "Action" broadcasts are replayed here, skipping actions this client already predicted
	(matched by sequence number). Clip markers are re-published on the Marker signal so effects,
	sounds and lunges can hook into animation timing without this module knowing about them.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Clip = require(Shared.Animation.Clip)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local CharacterAnimator = require(script.Parent.Parent.Animation.CharacterAnimator)

type CharacterAnimator = CharacterAnimator.CharacterAnimator

local AnimationController = {}

-- (rig, clipId, markerName, markerData)
AnimationController.Marker = Signal.new() :: Signal.Signal<Model, string, string, any>
-- (rig, clipId) fired when a clip starts on a rig
AnimationController.Played = Signal.new() :: Signal.Signal<Model, string>

local animators: { [Model]: CharacterAnimator } = {}
local predicted: { [number]: number } = {} -- seq -> os.clock() when predicted
local player = Players.LocalPlayer

local function onMarker(animator: CharacterAnimator, action: CharacterAnimator.Action, marker: Clip.MarkerDef)
	AnimationController.Marker:Fire(animator.model, action.id, marker.name, marker.data)
end

local function track(model: Instance)
	if not model:IsA("Model") or animators[model] then
		return
	end
	task.spawn(function()
		local root = model:WaitForChild("HumanoidRootPart", 10)
		if not (root and root:IsA("BasePart")) or animators[model] or model.Parent == nil then
			return
		end
		local animator = CharacterAnimator.new(model, root)
		animator.onMarker = onMarker
		animators[model] = animator
	end)
end

local function untrack(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local animator = animators[model]
	if animator then
		animator:destroy()
		animators[model] = nil
	end
end

function AnimationController.get(model: Instance?): CharacterAnimator?
	if model == nil or not model:IsA("Model") then
		return nil
	end
	return animators[model]
end

export type PlayOptions = CharacterAnimator.PlayOptions

function AnimationController.play(model: Model, clipId: string, options: PlayOptions?): CharacterAnimator.Action?
	local animator = animators[model]
	if not animator then
		return nil
	end
	local action = animator:play(clipId, options)
	if action then
		AnimationController.Played:Fire(model, clipId)
	end
	return action
end

-- Marks an action as predicted locally so the server's echo is ignored.
function AnimationController.predict(seq: number)
	predicted[seq] = os.clock()
end

function AnimationController.forget(seq: number)
	predicted[seq] = nil
end

local function onEffects(kind: string, payload: any)
	if type(payload) ~= "table" then
		return
	end
	if kind == "Action" then
		local rig = payload.rig
		if typeof(rig) ~= "Instance" or not rig:IsA("Model") or type(payload.clip) ~= "string" then
			return
		end
		local seq = payload.seq
		if rig == player.Character and type(seq) == "number" and predicted[seq] then
			predicted[seq] = nil
			return
		end
		local elapsed = if type(payload.t) == "number" then Workspace:GetServerTimeNow() - payload.t else 0
		AnimationController.play(rig, payload.clip, {
			speed = if type(payload.speed) == "number" then payload.speed else 1,
			startTime = math.clamp(elapsed, 0, 0.2),
		})
	elseif kind == "Stop" then
		local animator = AnimationController.get(payload.rig)
		if animator then
			animator:stop(nil, if type(payload.fade) == "number" then payload.fade else 0.1)
		end
	end
end

function AnimationController.init() end

function AnimationController.start()
	for _, model in CollectionService:GetTagged("Rig") do
		track(model)
	end
	CollectionService:GetInstanceAddedSignal("Rig"):Connect(track)
	CollectionService:GetInstanceRemovedSignal("Rig"):Connect(untrack)

	Net.event("Effects").OnClientEvent:Connect(onEffects)

	RunService.PreSimulation:Connect(function(dt: number)
		local camera = Workspace.CurrentCamera
		local cameraPosition = if camera then camera.CFrame.Position else nil
		local character = player.Character
		for model, animator in animators do
			if model.Parent == nil then
				animator:destroy()
				animators[model] = nil
			else
				animator:update(dt, if model == character then nil else cameraPosition)
			end
		end
		-- Drop stale predictions (server never echoed them).
		local now = os.clock()
		for seq, at in predicted do
			if now - at > 3 then
				predicted[seq] = nil
			end
		end
	end)
end

return AnimationController
