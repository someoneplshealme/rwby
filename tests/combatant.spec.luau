--[[
	Server combat rules on the real Combatant class: Aura absorbing damage and shattering,
	knock-downs, posture and guard breaks, buffs, action windows and regeneration.
]]

local Harness = require("../tools/lune/harness")

local shared = Harness.mount("src/shared", "Shared")
Harness.installGame({
	ReplicatedStorage = Harness.container("ReplicatedStorage", { shared }),
	Workspace = {
		GetServerTimeNow = function()
			return os.clock()
		end,
	},
})
local server = Harness.mount("src/server", "Server")
local Combatant = Harness.require(server.Combat.Combatant)
local Combat = Harness.require(shared.Config.Combat)

local function player()
	local model, humanoid, root = Harness.fakeRig()
	local c = Combatant.new(model, humanoid, root, "Player")
	c:restoreFully()
	return c, model, humanoid
end

return function(t)
	t.describe("Aura", function()
		t.it("absorbs damage completely while it holds", function()
			local c, _, humanoid = player()
			local maxAura = c.stats.maxAura
			local result = c:takeDamage(30)
			t.expect(result.aura):toBeNear(30)
			t.expect(result.health):toBe(0)
			t.expect(humanoid.Health):toBe(100)
			t.expect(c.aura):toBeNear(maxAura - 30)
		end)
		t.it("shatters and lets part of the overflow through", function()
			local c, model, humanoid = player()
			c:takeDamage(c.stats.maxAura - 10)
			local result = c:takeDamage(30)
			t.expect(result.auraBroke):toBeTruthy()
			t.expect(c.auraBroken):toBeTruthy()
			t.expect(model:GetAttribute("AuraBroken")):toBe(true)
			-- 10 absorbed, 20 overflow at 50% reaches health.
			t.expect(humanoid.Health):toBeNear(100 - 20 * Combat.AuraOverflowToHealth)
		end)
		t.it("exposed Huntsmen take extra health damage", function()
			local c, _, humanoid = player()
			c.aura = 0
			c.auraBroken = true
			c:takeDamage(10)
			t.expect(humanoid.Health):toBeNear(100 - 10 * Combat.ExposedDamageMultiplier)
		end)
		t.it("regenerates after the delay", function()
			local c = player()
			c:takeDamage(50)
			c.lastAuraHitAt = os.clock() - Combat.AuraRegenDelay - 1
			c.lastHurtAt = c.lastAuraHitAt
			c:update(1)
			t.expect(c.aura):toBeGreaterThan(50)
		end)
	end)

	t.describe("Knocked", function()
		t.it("players are knocked instead of killed and ignore further hits", function()
			local c, model, humanoid = player()
			c.aura = 0
			c.auraBroken = true
			local result = c:takeDamage(500)
			t.expect(result.knocked):toBeTruthy()
			t.expect(humanoid.Health):toBe(1)
			t.expect(c.state):toBe("Knocked")
			t.expect(model:GetAttribute("Knocked")):toBe(true)
			local again = c:takeDamage(50)
			t.expect(again.health):toBe(0)
		end)
		t.it("executions finish a knocked player", function()
			local c, _, humanoid = player()
			c.aura = 0
			c.auraBroken = true
			c:takeDamage(500)
			local result = c:takeDamage(math.huge, nil, { ignoreKnock = true })
			t.expect(result.killed):toBeTruthy()
			t.expect(humanoid.Health):toBe(0)
		end)
		t.it("recovers with a sliver of health when the timer runs out", function()
			local c, _, humanoid = player()
			c.aura = 0
			c.auraBroken = true
			c:takeDamage(500)
			c.stateUntil = os.clock() - 0.01
			c:update(0.016)
			t.expect(c.state):toBe("Idle")
			t.expect(humanoid.Health):toBeNear(100 * Combat.RecoverHealthFraction, 1)
		end)
		t.it("Grimm die outright", function()
			local model, humanoid, root = Harness.fakeRig()
			local grimm = Combatant.new(model, humanoid, root, "Grimm")
			local result = grimm:takeDamage(150)
			t.expect(result.killed):toBeTruthy()
			t.expect(grimm.state):toBe("Dead")
		end)
	end)

	t.describe("Posture", function()
		t.it("breaks the guard when full", function()
			local c, model = player()
			c.state = "Blocking"
			local broke = c:addPosture(60)
			t.expect(broke):toBeFalsy()
			broke = c:addPosture(60)
			t.expect(broke):toBeTruthy()
			t.expect(c.state):toBe("GuardBroken")
			t.expect(c.posture):toBe(0)
			t.expect(model:GetAttribute("GuardBroken")):toBe(true)
		end)
		t.it("Harden shrugs off posture and damage", function()
			local c, _, humanoid = player()
			c.aura = 0
			c.auraBroken = true
			c:addBuff("Harden", 4)
			c:addPosture(100)
			t.expect(c.posture):toBeLessThan(20)
			c:takeDamage(20)
			t.expect(humanoid.Health):toBeGreaterThan(100 - 20 * Combat.ExposedDamageMultiplier + 1)
			t.expect(c:hasHyperArmor()):toBeTruthy()
		end)
		t.it("recovers after a pause", function()
			local c = player()
			c.posture = 50
			c.lastPostureAt = os.clock() - Combat.PostureRegenDelay - 1
			c:update(1)
			t.expect(c.posture):toBeNear(50 - Combat.PostureRegen, 0.5)
		end)
	end)

	t.describe("Actions", function()
		t.it("an attack cannot be cancelled before its chain window", function()
			local c = player()
			local token = c:begin("Attacking", 0.6)
			c.chainOpensAt = os.clock() + 0.3
			t.expect(c:canAct()):toBeFalsy()
			c.chainOpensAt = os.clock() - 0.01
			t.expect(c:canAct()):toBeTruthy()
			c:finish(token)
			t.expect(c.state):toBe("Idle")
		end)
		t.it("interrupting invalidates the running action", function()
			local c = player()
			local token = c:begin("Attacking", 0.6)
			c:stun(0.5)
			t.expect(c.token ~= token):toBeTruthy()
			c:finish(token)
			t.expect(c.state):toBe("Stunned")
		end)
		t.it("stuns never shorten an existing stun", function()
			local c = player()
			c:stun(1)
			local untilTime = c.stateUntil
			c:stun(0.2)
			t.expect(c.stateUntil):toBe(untilTime)
		end)
		t.it("statuses slow and burn", function()
			local c = player()
			c:addStatus("Chill", 2, 0.5)
			t.expect(c:slowFactor()):toBeNear(0.5)
			c:addStatus("Burn", 3, 4)
			c.statuses.Burn.tickAt = os.clock() - 0.01
			local events = c:update(0.016)
			t.expect(#events):toBe(1)
			t.expect(events[1].kind):toBe("Burn")
		end)
	end)
end
