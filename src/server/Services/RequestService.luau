--!strict
--[[
	RequestService: menu requests from clients on the Request RemoteFunction.

	  CreateCharacter { name, kingdom, faunus, color, weapon }
	  Spin                         reroll your Semblance (costs a Semblance Spin)
	  Allocate { attribute }       spend an attribute point
	  BuyDust { id, amount }       at the From Dust Till Dawn counter
	  ChangeWeapon { weapon }      inside a safe zone

	Every request is validated here; the client is never trusted with outcomes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage.Shared
local Dust = require(Shared.Config.Dust)
local Net = require(Shared.Net)
local Origins = require(Shared.Config.Origins)
local Progression = require(Shared.Config.Progression)
local Semblances = require(Shared.Config.Semblances)
local Weapons = require(Shared.Config.Weapons)
local World = require(Shared.Config.World)

local CombatService = require(script.Parent.Parent.Combat.CombatService)
local CharacterService = require(script.Parent.Parent.Characters.CharacterService)
local DataService = require(script.Parent.DataService)

type Result = { ok: boolean, message: string?, [string]: any }

local RequestService = {}

local random = Random.new()
local lastRequest: { [Player]: number } = {}

local function fail(message: string): Result
	return { ok = false, message = message }
end

local function filterName(player: Player, raw: string): string?
	local trimmed = string.gsub(string.gsub(raw, "^%s+", ""), "%s+$", "")
	trimmed = string.gsub(trimmed, "%s+", " ")
	if #trimmed < 2 or #trimmed > 20 or string.find(trimmed, "[^%a ']") then
		return nil
	end
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(trimmed, player.UserId)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or type(result) ~= "string" or string.find(result, "#") then
		return nil
	end
	return result
end

local handlers: { [string]: (Player, { [string]: any }) -> Result } = {}

handlers.CreateCharacter = function(player, data)
	local profile = DataService.get(player)
	if profile == nil then
		return fail("Your profile is still loading.")
	end
	if profile.Created then
		return fail("You already have a Huntsman.")
	end
	local name = if type(data.name) == "string" then filterName(player, data.name) else nil
	if name == nil then
		return fail("Names must be 2-20 letters and pass Roblox's filter.")
	end
	local kingdom = Origins.kingdom(if type(data.kingdom) == "string" then data.kingdom else "Vale")
	local color = Origins.color(if type(data.color) == "string" then data.color else "Rose")
	local faunus = if type(data.faunus) == "string" and Origins.isTrait(data.faunus) then data.faunus else ""
	local weaponId = if type(data.weapon) == "string" and Weapons.get(data.weapon) then data.weapon else "CrescentScythe"

	DataService.update(player, function(p)
		p.Created = true
		p.Name = name
		p.Kingdom = kingdom.id
		p.Color = color.id
		p.Faunus = faunus
		p.Weapon = weaponId
		if p.Semblance == "" then
			p.Semblance = Semblances.roll(random)
		end
	end)
	task.spawn(CharacterService.spawn, player)
	return { ok = true }
end

handlers.Spin = function(player, _data)
	local profile = DataService.get(player)
	if profile == nil then
		return fail("Your profile is still loading.")
	end
	if profile.Semblance ~= "" and profile.Spins <= 0 then
		return fail("You have no Semblance Spins left. Earn one every 5 levels.")
	end
	local previous = if profile.Semblance ~= "" then profile.Semblance else nil
	local rolled = Semblances.roll(random, previous)
	DataService.update(player, function(p)
		if p.Semblance ~= "" then
			p.Spins -= 1
		end
		p.Semblance = rolled
	end)
	CharacterService.refreshStats(player)
	local updated = DataService.get(player)
	return { ok = true, semblance = rolled, spins = if updated then updated.Spins else 0 }
end

handlers.Allocate = function(player, data)
	local profile = DataService.get(player)
	local attribute = data.attribute
	if profile == nil or type(attribute) ~= "string" or (profile.Attributes :: any)[attribute] == nil then
		return fail("Unknown attribute.")
	end
	if profile.Points <= 0 then
		return fail("No attribute points to spend.")
	end
	if (profile.Attributes :: any)[attribute] >= Progression.AttributeCap then
		return fail("That attribute is maxed.")
	end
	DataService.update(player, function(p)
		p.Points -= 1
		local attributes = p.Attributes :: any
		attributes[attribute] += 1
	end)
	CharacterService.refreshStats(player)
	return { ok = true }
end

handlers.BuyDust = function(player, data)
	local profile = DataService.get(player)
	local combatant = CombatService.fromPlayer(player)
	local def = if type(data.id) == "string" then Dust.get(data.id) else nil
	local amount = if type(data.amount) == "number" then math.clamp(math.floor(data.amount), 1, 9) else 1
	if profile == nil or combatant == nil or def == nil then
		return fail("That Dust isn't for sale.")
	end
	if (combatant.root.Position - World.DustShop).Magnitude > 30 then
		return fail("Visit From Dust Till Dawn in Vale to buy Dust.")
	end
	local owned = profile.Dust[def.id] or 0
	amount = math.min(amount, Dust.MaxVials - owned)
	if amount <= 0 then
		return fail(`You can't carry more {def.name}.`)
	end
	local cost = def.price * amount
	if profile.Lien < cost then
		return fail("Not enough Lien.")
	end
	DataService.update(player, function(p)
		p.Lien -= cost
		p.Dust[def.id] = (p.Dust[def.id] or 0) + amount
	end)
	return { ok = true, message = `Bought {amount} {def.name} for {cost} Lien.` }
end

handlers.ChangeWeapon = function(player, data)
	local profile = DataService.get(player)
	local combatant = CombatService.fromPlayer(player)
	local weaponId = data.weapon
	if profile == nil or combatant == nil or type(weaponId) ~= "string" or Weapons.get(weaponId) == nil then
		return fail("Unknown weapon.")
	end
	if not World.isSafe(combatant.root.Position) then
		return fail("Change weapons inside Beacon Academy or Vale.")
	end
	if combatant.state ~= "Idle" then
		return fail("Finish what you're doing first.")
	end
	DataService.update(player, function(p)
		p.Weapon = weaponId
	end)
	CharacterService.equipWeapon(player, weaponId)
	return { ok = true }
end

local function onInvoke(player: Player, kind: any, data: any): Result
	local now = os.clock()
	if now - (lastRequest[player] or 0) < 0.15 then
		return fail("Slow down.")
	end
	lastRequest[player] = now
	local handler = if type(kind) == "string" then handlers[kind] else nil
	if handler == nil then
		return fail("Unknown request.")
	end
	local ok, result = pcall(handler, player, if type(data) == "table" then data else {})
	if not ok then
		warn(`[Request] {kind} failed: {result}`)
		return fail("Something went wrong.")
	end
	return result
end

-- Lets Abilities spend Dust vials from the profile.
function RequestService.takeDust(player: Player, dustId: string): boolean
	local profile = DataService.get(player)
	if profile == nil or (profile.Dust[dustId] or 0) <= 0 then
		return false
	end
	DataService.update(player, function(p)
		p.Dust[dustId] -= 1
	end)
	return true
end

function RequestService.init() end

function RequestService.start()
	Net.func("Request").OnServerInvoke = onInvoke
end

return RequestService
