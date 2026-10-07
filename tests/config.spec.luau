--[[
	Configuration sanity: Semblance rolls, progression curves, origins and map zones.
]]

local roblox = require("@lune/roblox")

local Harness = require("../tools/lune/harness")

local shared = Harness.mount("src/shared")
local Origins = Harness.require(shared.Config.Origins)
local Progression = Harness.require(shared.Config.Progression)
local Semblances = Harness.require(shared.Config.Semblances)
local World = Harness.require(shared.Config.World)

-- Lune has no Roblox Random, so emulate the bits Semblances.roll uses.
local function fakeRandom(seed: number)
	local state = seed
	return {
		NextNumber = function(_self)
			state = (state * 1103515245 + 12345) % 2147483648
			return state / 2147483648
		end,
	}
end

return function(t)
	t.describe("Semblances", function()
		t.it("rolls only real Semblances, weighted by rarity", function()
			local random = fakeRandom(42)
			local counts = {}
			for _ = 1, 4000 do
				local id = Semblances.roll(random)
				if Semblances.get(id) == nil then
					error(`rolled unknown semblance {id}`)
				end
				counts[id] = (counts[id] or 0) + 1
			end
			t.expect(counts.Glyph):toBeGreaterThan(counts.Velocity)
			t.expect(counts.Bulwark):toBeGreaterThan(counts.Retribution)
		end)
		t.it("never rerolls into the same Semblance", function()
			local random = fakeRandom(7)
			for _ = 1, 200 do
				t.expect(Semblances.roll(random, "Glyph") ~= "Glyph"):toBeTruthy()
			end
		end)
	end)

	t.describe("Progression", function()
		t.it("needs more experience every level", function()
			for level = 1, Progression.MaxLevel - 1 do
				t.expect(Progression.xpToNext(level + 1)):toBeGreaterThan(Progression.xpToNext(level))
			end
		end)
		t.it("attributes improve the stats they describe", function()
			local base = Progression.stats(1, Progression.emptyAttributes(), "Vale", false, nil)
			local attributes = Progression.emptyAttributes()
			attributes.Strength = 10
			attributes.Willpower = 10
			attributes.Vitality = 10
			local trained = Progression.stats(1, attributes, "Vale", false, nil)
			t.expect(trained.damage):toBeGreaterThan(base.damage)
			t.expect(trained.maxAura):toBeGreaterThan(base.maxAura)
			t.expect(trained.maxHealth):toBeGreaterThan(base.maxHealth)
		end)
		t.it("applies kingdom, Faunus and Semblance bonuses", function()
			local vale = Progression.stats(1, Progression.emptyAttributes(), "Vale", false, nil)
			local vacuo = Progression.stats(1, Progression.emptyAttributes(), "Vacuo", true, "Bulwark")
			t.expect(vacuo.maxHealth):toBeGreaterThan(vale.maxHealth)
			t.expect(vacuo.moveSpeed):toBeGreaterThan(vale.moveSpeed)
			t.expect(vacuo.maxPosture):toBeGreaterThan(vale.maxPosture)
		end)
	end)

	t.describe("Origins and world", function()
		t.it("falls back to defaults for unknown ids", function()
			t.expect(Origins.kingdom("Nowhere").id):toBe("Vale")
			t.expect(Origins.color("Plaid").id):toBe("Rose")
			t.expect(Origins.isTrait("Cat")):toBeTruthy()
			t.expect(Origins.isTrait("Dragon")):toBeFalsy()
		end)
		t.it("spawns players inside a safe zone and keeps Grimm outside them", function()
			t.expect(World.isSafe(World.Spawn)):toBeTruthy()
			for _, zone in World.GrimmSpawns do
				if World.isSafe(zone.center) then
					error(`Grimm spawn at {zone.center} is inside a safe zone`)
				end
			end
			t.expect(World.isSafe(roblox.Vector3.new(0, 0, -400))):toBeFalsy()
		end)
	end)
end
