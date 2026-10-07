--!strict
--[[
	Mecha-shift choreography: how each weapon piece travels from one form to another.

	Pieces start one after another (a mechanical cascade), arrive with a small overshoot that reads
	as parts clicking into place, and pieces that only exist in one form fade in or out. Shared so
	the client animation and the offline preview show the exact same motion.
]]

local Easing = require(script.Parent.Easing)

export type ShiftPiece = {
	forms: { [string]: CFrame },
	hiddenIn: { [string]: boolean }?,
}

local WeaponShift = {}

local STAGGER_SHARE = 0.45 -- portion of the shift spent cascading piece start times

function WeaponShift.sample(
	piece: ShiftPiece,
	index: number,
	count: number,
	fromForm: string,
	toForm: string,
	t: number,
	duration: number
): (CFrame, number)
	local from = piece.forms[fromForm]
	local to = piece.forms[toForm]
	assert(from and to, `Weapon piece is missing form "{fromForm}" or "{toForm}"`)

	local stagger = duration * STAGGER_SHARE
	local start = if count > 1 then stagger * (index - 1) / (count - 1) else 0
	local travel = math.max(duration - stagger, 1e-3)
	local alpha = math.clamp((t - start) / travel, 0, 1)
	local cframe = from:Lerp(to, Easing.apply("Back.Out", alpha))

	local hidden = piece.hiddenIn
	local hiddenFrom = hidden ~= nil and hidden[fromForm] == true
	local hiddenTo = hidden ~= nil and hidden[toForm] == true
	local transparency = 0
	if hiddenFrom and hiddenTo then
		transparency = 1
	elseif hiddenTo then
		transparency = math.clamp(alpha * 2, 0, 1)
	elseif hiddenFrom then
		transparency = 1 - math.clamp(alpha * 2 - 1, 0, 1)
	end
	return cframe, transparency
end

return WeaponShift
