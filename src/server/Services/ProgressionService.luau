--!strict
--[[
	ProgressionService: rewards for slaying Grimm, levelling, attribute points and Semblance spins.
	Everyone who dealt a meaningful share of damage to a Grimm earns its XP; Lien is split by share.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Progression = require(Shared.Config.Progression)

local CombatService = require(script.Parent.Parent.Combat.CombatService)
local CharacterService = require(script.Parent.Parent.Characters.CharacterService)
local DataService = require(script.Parent.DataService)

type Combatant = CombatService.Combatant

local ProgressionService = {}

local notify: RemoteEvent
local random = Random.new()

function ProgressionService.notify(player: Player, text: string, style: string?)
	notify:FireClient(player, text, style or "Info")
end

function ProgressionService.addXP(player: Player, amount: number)
	local leveled = 0
	DataService.update(player, function(profile)
		profile.XP += math.floor(amount)
		while profile.Level < Progression.MaxLevel and profile.XP >= Progression.xpToNext(profile.Level) do
			profile.XP -= Progression.xpToNext(profile.Level)
			profile.Level += 1
			profile.Points += Progression.PointsPerLevel
			if profile.Level % 5 == 0 then
				profile.Spins += 1
			end
			leveled += 1
		end
		if profile.Level >= Progression.MaxLevel then
			profile.XP = 0
		end
	end)
	if leveled > 0 then
		local profile = DataService.get(player)
		CharacterService.refreshStats(player)
		local combatant = CombatService.fromPlayer(player)
		if combatant and profile then
			combatant:heal(combatant.stats.maxHealth, combatant.stats.maxAura)
			CombatService.broadcast("Effect", { name = "LevelUp", rig = combatant.model, level = profile.Level })
			ProgressionService.notify(player, `Level {profile.Level}! +{Progression.PointsPerLevel * leveled} attribute points`, "Level")
			if profile.Level % 5 == 0 then
				ProgressionService.notify(player, "You earned a Semblance Spin.", "Level")
			end
		end
	end
end

function ProgressionService.addLien(player: Player, amount: number)
	DataService.update(player, function(profile)
		profile.Lien += math.floor(amount)
	end)
end

local function onKilled(victim: Combatant, _killer: Combatant?)
	local grimm = victim.grimm
	if victim.kind ~= "Grimm" or grimm == nil then
		return
	end
	local total = 0
	for _, amount in victim.damageLog do
		total += amount
	end
	if total <= 0 then
		return
	end
	local lien = random:NextInteger(grimm.lien[1], grimm.lien[2])
	for source, amount in victim.damageLog do
		local share = amount / total
		local player = source.player
		if player and player.Parent and share >= 0.1 then
			ProgressionService.addXP(player, grimm.xp)
			local earned = math.max(1, math.floor(lien * share + 0.5))
			ProgressionService.addLien(player, earned)
			DataService.update(player, function(profile)
				profile.Stats.GrimmSlain = (profile.Stats.GrimmSlain or 0) + 1
			end)
			ProgressionService.notify(player, `{grimm.name} slain  +{grimm.xp} XP  +{earned} Lien`, "Reward")
		end
	end
end

local function onKnocked(victim: Combatant, by: Combatant?)
	local player = if by then by.player else nil
	if player and victim.kind == "Player" then
		DataService.update(player, function(profile)
			profile.Stats.Knockouts = (profile.Stats.Knockouts or 0) + 1
		end)
	end
	local victimPlayer = victim.player
	if victimPlayer then
		ProgressionService.notify(victimPlayer, "Your Aura is spent. You are knocked down!", "Danger")
	end
end

function ProgressionService.init()
	notify = Net.event("Notify")
end

function ProgressionService.start()
	CombatService.Killed:Connect(onKilled)
	CombatService.Knocked:Connect(onKnocked)
end

return ProgressionService
