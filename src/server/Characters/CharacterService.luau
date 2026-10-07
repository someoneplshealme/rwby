--!strict
--[[
	CharacterService: spawns every Huntsman as an R6 rig (regardless of the place's avatar
	settings) wearing the player's own avatar, plus their cape, Faunus traits and weapon.

	Roblox auto-loading is disabled; this service owns spawning and respawning. Knocked players
	are handled by combat; when a Huntsman actually dies (executed) they respawn at Beacon.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Combat = require(Shared.Config.Combat)
local Origins = require(Shared.Config.Origins)
local Progression = require(Shared.Config.Progression)
local Weapons = require(Shared.Config.Weapons)
local World = require(Shared.Config.World)

local CombatService = require(script.Parent.Parent.Combat.CombatService)
local DataService = require(script.Parent.Parent.Services.DataService)
local Appearance = require(script.Parent.Appearance)
local RigBuilder = require(script.Parent.RigBuilder)
local WeaponService = require(script.Parent.WeaponService)

local CharacterService = {}

local descriptions: { [Player]: HumanoidDescription } = {}
local spawning: { [Player]: boolean } = {}
local random = Random.new()

local function avatarDescription(player: Player): HumanoidDescription
	local cached = descriptions[player]
	if cached then
		return cached
	end
	local ok, result = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(math.max(player.UserId, 1))
	end)
	local description = if ok and result then result else Instance.new("HumanoidDescription")
	descriptions[player] = description
	return description
end

local function buildRig(player: Player, color: Color3): Model
	local description = avatarDescription(player)
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	end)
	if ok and result then
		return result
	end
	warn(`[Character] avatar load failed for {player.Name} ({result}); using a default rig`)
	return RigBuilder.build(player.Name, {
		head = Color3.fromRGB(234, 196, 160),
		torso = color,
		arms = Color3.fromRGB(234, 196, 160),
		legs = Color3.fromRGB(40, 36, 44),
	})
end

local function spawnPoint(): CFrame
	local offset = Vector3.new(random:NextNumber(-14, 14), 0, random:NextNumber(-8, 8))
	local position = World.Spawn + offset
	return CFrame.lookAt(position, position + Vector3.new(0, 0, -1))
end

-- Recomputes stats from the profile and applies them to the live combatant.
function CharacterService.refreshStats(player: Player)
	local profile = DataService.get(player)
	local combatant = CombatService.fromPlayer(player)
	if profile == nil or combatant == nil then
		return
	end
	local semblance = if profile.Semblance ~= "" then profile.Semblance else nil
	combatant.semblance = semblance
	combatant:applyStats(
		Progression.stats(profile.Level, profile.Attributes, profile.Kingdom, profile.Faunus ~= "", semblance)
	)
	local character = combatant.model
	character:SetAttribute("Level", profile.Level)
	character:SetAttribute("Semblance", semblance or "")
	character:SetAttribute("MoveSpeed", combatant.stats.moveSpeed)
end

function CharacterService.spawn(player: Player)
	if spawning[player] or not player.Parent then
		return
	end
	spawning[player] = true
	local profile = DataService.await(player)
	if profile == nil or not player.Parent then
		spawning[player] = nil
		return
	end

	local color = Origins.color(profile.Color).color
	local character = buildRig(player, color)
	character.Name = player.Name
	for _, child in character:GetChildren() do
		if
			(child:IsA("Script") or child:IsA("LocalScript")) and (child.Name == "Animate" or child.Name == "Health")
		then
			child:Destroy()
		end
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		warn(`[Character] rig for {player.Name} is missing parts`)
		character:Destroy()
		spawning[player] = nil
		return
	end

	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Combat.JumpPower
	humanoid.WalkSpeed = Combat.WalkSpeed

	if profile.Faunus ~= "" and Origins.isTrait(profile.Faunus) then
		Appearance.applyFaunus(character, profile.Faunus)
	end
	Appearance.applyCape(character, color)

	local displayName = if profile.Created and profile.Name ~= "" then profile.Name else player.DisplayName
	character:SetAttribute("DisplayName", displayName)
	character:SetAttribute("Kingdom", profile.Kingdom)
	character:SetAttribute("SignatureColor", color)
	character:SetAttribute("Gait", "Huntsman")
	character:SetAttribute("IsPlayer", true)

	character:PivotTo(spawnPoint())
	local previous = player.Character
	player.Character = character
	character.Parent = Workspace
	if previous and previous ~= character then
		previous:Destroy()
	end
	pcall(function()
		root:SetNetworkOwner(player)
	end)
	CollectionService:AddTag(character, "Rig")

	local combatant = CombatService.register(character, "Player")
	if combatant then
		combatant.player = player
		CharacterService.refreshStats(player)
		combatant:restoreFully()
		local weaponId = if Weapons.get(profile.Weapon) then profile.Weapon else Weapons.order()[1]
		local weapon = Weapons.get(weaponId)
		if weapon then
			WeaponService.equip(character, weapon.model, color)
			CombatService.setWeapon(combatant, weaponId)
		end
	end

	humanoid.Died:Connect(function()
		DataService.update(player, function(p)
			p.Stats.Deaths = (p.Stats.Deaths or 0) + 1
			p.Lien = math.floor(p.Lien * 0.9)
		end)
		task.delay(Combat.RespawnDelay, function()
			if player.Parent and player.Character == character then
				CharacterService.spawn(player)
			end
		end)
	end)

	spawning[player] = nil
end

-- Swaps the equipped weapon on the live character.
function CharacterService.equipWeapon(player: Player, weaponId: string)
	local profile = DataService.get(player)
	local combatant = CombatService.fromPlayer(player)
	local weapon = Weapons.get(weaponId)
	if profile == nil or combatant == nil or weapon == nil then
		return
	end
	local color = Origins.color(profile.Color).color
	WeaponService.equip(combatant.model, weapon.model, color)
	CombatService.setWeapon(combatant, weaponId)
end

function CharacterService.init()
	Players.CharacterAutoLoads = false
end

function CharacterService.start()
	local function onPlayer(player: Player)
		task.spawn(CharacterService.spawn, player)
		player.CharacterRemoving:Connect(function(character)
			CombatService.unregister(character)
			-- Fell out of the world or was removed without dying: respawn.
			task.delay(Combat.RespawnDelay, function()
				if player.Parent and (player.Character == nil or player.Character == character) then
					CharacterService.spawn(player)
				end
			end)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		descriptions[player] = nil
		spawning[player] = nil
		local character = player.Character
		if character then
			character:Destroy()
		end
	end)
end

return CharacterService
