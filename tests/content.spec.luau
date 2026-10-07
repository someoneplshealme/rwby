--[[
	Content integrity: every move, stance, state clip, weapon model, Semblance, Dust technique
	and Grimm attack must line up with the animation data, because gameplay timing is read from
	clip markers. These tests catch a renamed clip or a missing "Hit" marker before Studio does.
]]

local Harness = require("../tools/lune/harness")

local shared = Harness.mount("src/shared")
local Clip = Harness.require(shared.Animation.Clip)
local ClipLibrary = Harness.require(shared.Animation.ClipLibrary)
local Combat = Harness.require(shared.Config.Combat)
local Dust = Harness.require(shared.Config.Dust)
local Grimm = Harness.require(shared.Config.Grimm)
local Semblances = Harness.require(shared.Config.Semblances)
local WeaponModels = Harness.require(shared.Config.WeaponModels)
local Weapons = Harness.require(shared.Config.Weapons)

local function resolveState(stanceId: string, clipName: string)
	local prefix = string.match(stanceId, "^([^%.]+)")
	return ClipLibrary.get(`{stanceId}_{clipName}`)
		or ClipLibrary.get(`{prefix}.{clipName}`)
		or ClipLibrary.get(`Common.{clipName}`)
end

local function hitCount(clip): number
	return #Clip.markersNamed(clip, "Hit")
end

return function(t)
	t.describe("Clip library", function()
		t.it("compiles every clip with sane keyframes and markers", function()
			local ids = ClipLibrary.ids()
			t.expect(#ids):toBeGreaterThan(60)
			for _, id in ids do
				local clip = ClipLibrary.expect(id)
				for i = 2, #clip.times do
					if clip.times[i] < clip.times[i - 1] then
						error(`{id}: keyframes out of order`)
					end
				end
				for _, marker in clip.markers do
					if marker.t < 0 or marker.t > clip.length + 1e-6 then
						error(`{id}: marker {marker.name} at {marker.t} outside 0..{clip.length}`)
					end
				end
				local chain = Clip.markerTime(clip, "Chain")
				local hits = Clip.markersNamed(clip, "Hit")
				if chain and #hits > 0 and chain < hits[#hits].t then
					error(`{id}: Chain opens before the last Hit`)
				end
			end
		end)
		t.it("has every shared clip the game plays by name", function()
			for _, name in
				{
					"Block",
					"Aim",
					"Parry",
					"Parried",
					"GuardBreak",
					"GuardBroken",
					"Stunned",
					"HitLight1",
					"HitLight2",
					"HitBack",
					"HitHeavy",
					"KnockDown",
					"Knocked",
					"Execute",
					"Executed",
					"Dead",
					"DodgeForward",
					"DodgeBack",
					"DodgeLeft",
					"DodgeRight",
					"AirDash",
					"Slide",
					"Feint",
					"Shift",
				}
			do
				if not ClipLibrary.has(`Common.{name}`) then
					error(`missing Common.{name}`)
				end
			end
		end)
	end)

	t.describe("Weapons", function()
		for _, id in Weapons.order() do
			local weapon = Weapons.get(id)
			t.it(`{id}: forms, stances and moves line up with animations`, function()
				local model = WeaponModels[weapon.model]
				if model == nil then
					error(`{id}: missing weapon model {weapon.model}`)
				end
				t.expect(#weapon.forms):toBe(#model.forms)
				for index, form in weapon.forms do
					t.expect(form.name):toBe(model.forms[index])
					if ClipLibrary.stance(form.stance) == nil then
						error(`{id}: missing stance {form.stance}`)
					end
					if resolveState(form.stance, "Block") == nil then
						error(`{id}: no block clip for {form.name}`)
					end
					local moves = {}
					for _, move in form.m1 or {} do
						table.insert(moves, move)
					end
					if form.critical then
						table.insert(moves, form.critical)
					end
					for _, move in moves do
						local clip = ClipLibrary.get(move.clip)
						if clip == nil then
							error(`{id}: missing clip {move.clip}`)
						end
						if #move.hits > 0 and hitCount(clip) ~= #move.hits then
							error(`{move.clip}: {hitCount(clip)} Hit markers but {#move.hits} hits defined`)
						end
						if move.shot and #Clip.markersNamed(clip, "Shoot") == 0 then
							error(`{move.clip}: shot move without Shoot markers`)
						end
						if #move.hits == 0 and move.shot == nil then
							error(`{move.clip}: move does nothing`)
						end
						local firstHit = Clip.markerTime(clip, "Hit")
						if move.feintable and (firstHit == nil or firstHit <= Combat.FeintWindowPadding + 0.05) then
							error(`{move.clip}: feintable but lands too early to feint`)
						end
					end
					local shoot = form.shoot
					if form.ranged then
						if shoot == nil then
							error(`{id}: ranged form {form.name} cannot shoot`)
						end
						for _, clipId in { shoot.clip, shoot.altClip } do
							if clipId then
								local clip = ClipLibrary.get(clipId)
								if clip == nil or Clip.markerTime(clip, "Shoot") == nil then
									error(`{clipId}: missing or has no Shoot marker`)
								end
							end
						end
						if resolveState(form.stance, "Aim") == nil then
							error(`{id}: no aim clip for {form.name}`)
						end
					end
				end
			end)
			t.it(`{id}: every model piece is placed in every form`, function()
				local model = WeaponModels[weapon.model]
				for _, list in { model.right, model.left or {} } do
					for _, piece in list do
						for _, form in model.forms do
							if piece.forms[form] == nil then
								error(`{weapon.model}.{piece.name} has no placement for {form}`)
							end
						end
					end
				end
				for form in model.twoHand or {} do
					if not table.find(model.forms, form) then
						error(`{weapon.model}: twoHand for unknown form {form}`)
					end
				end
				for _, trail in model.trails do
					for form in trail.forms or {} do
						if not table.find(model.forms, form) then
							error(`{weapon.model}: trail for unknown form {form}`)
						end
					end
				end
			end)
		end
	end)

	t.describe("Abilities", function()
		t.it("every Semblance has its clip (with a Cast marker when it is a cast)", function()
			local casts = { Retribution = true, Polarity = true, Bulwark = true }
			for _, id in Semblances.ids() do
				local def = Semblances.get(id)
				local clip = ClipLibrary.get(def.clip)
				if clip == nil then
					error(`{id}: missing clip {def.clip}`)
				end
				if casts[id] and Clip.markerTime(clip, "Cast") == nil then
					error(`{id}: {def.clip} needs a Cast marker`)
				end
			end
		end)
		t.it("every Dust technique has a cast clip with a Cast marker", function()
			for _, id in Dust.Order do
				local def = Dust.get(id)
				local clip = ClipLibrary.get(def.clip)
				if clip == nil or Clip.markerTime(clip, "Cast") == nil then
					error(`{id}: {def.clip} missing or has no Cast marker`)
				end
			end
		end)
	end)

	t.describe("Grimm", function()
		t.it("every Grimm attack has a clip whose Hit markers match its hits", function()
			for id, def in Grimm.Definitions do
				for _, attack in def.moves do
					local clip = ClipLibrary.get(attack.move.clip)
					if clip == nil then
						error(`{id}: missing clip {attack.move.clip}`)
					end
					if hitCount(clip) ~= #attack.move.hits then
						error(`{attack.move.clip}: {hitCount(clip)} Hit markers but {#attack.move.hits} hits`)
					end
				end
			end
		end)
	end)
end
