--!strict
--[[
	Sound table. Defaults use sounds that ship inside the Roblox client (rbxasset://) so the game
	makes noise out of the box; replace any id with your own uploaded "rbxassetid://123..." audio.
	Missing or failed sounds are skipped silently.
]]

export type SoundDef = {
	id: string,
	volume: number?,
	pitch: { number }?, -- random pitch range {min, max}
}

local Sounds: { [string]: SoundDef } = {
	Swing = { id = "rbxasset://sounds/swordslash.wav", volume = 0.55, pitch = { 1.05, 1.25 } },
	SwingHeavy = { id = "rbxasset://sounds/swordslash.wav", volume = 0.7, pitch = { 0.7, 0.82 } },
	Whoosh = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.5, pitch = { 1.1, 1.3 } },
	Hit = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.7, pitch = { 0.55, 0.7 } },
	HitHeavy = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.9, pitch = { 0.4, 0.5 } },
	AuraHit = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.35, pitch = { 0.55, 0.7 } },
	AuraBreak = { id = "rbxasset://sounds/glassbreak.wav", volume = 0.9, pitch = { 0.9, 1.05 } },
	Block = { id = "rbxasset://sounds/unsheath.wav", volume = 0.6, pitch = { 0.6, 0.75 } },
	Parry = { id = "rbxasset://sounds/unsheath.wav", volume = 1, pitch = { 1.35, 1.5 } },
	GuardBreak = { id = "rbxasset://sounds/glassbreak.wav", volume = 0.8, pitch = { 0.6, 0.7 } },
	Dodge = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.35, pitch = { 1.4, 1.6 } },
	Shift = { id = "rbxasset://sounds/unsheath.wav", volume = 0.8, pitch = { 0.85, 0.95 } },
	Sniper = { id = "rbxasset://sounds/Rocket shot.wav", volume = 0.9, pitch = { 1.35, 1.45 } },
	Shotgun = { id = "rbxasset://sounds/Rocket shot.wav", volume = 0.8, pitch = { 1.7, 1.9 } },
	Launcher = { id = "rbxasset://sounds/Rocket shot.wav", volume = 0.7, pitch = { 0.9, 1 } },
	Explosion = { id = "rbxasset://sounds/Rocket whoosh 01.wav", volume = 1, pitch = { 0.5, 0.6 } },
	Fire = { id = "rbxasset://sounds/Rocket whoosh 01.wav", volume = 0.8, pitch = { 1.1, 1.2 } },
	Ice = { id = "rbxasset://sounds/glassbreak.wav", volume = 0.6, pitch = { 1.4, 1.6 } },
	Lightning = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.9, pitch = { 0.35, 0.45 } },
	Gravity = { id = "rbxasset://sounds/Rocket whoosh 01.wav", volume = 0.9, pitch = { 0.35, 0.45 } },
	Semblance = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.8, pitch = { 0.8, 0.9 } },
	Jump = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.35 },
	Land = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.5 },
	Knocked = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 1, pitch = { 0.5, 0.55 } },
	GrimmHowl = { id = "rbxasset://sounds/Rocket whoosh 01.wav", volume = 0.6, pitch = { 0.25, 0.3 } },
	GrimmDeath = { id = "rbxasset://sounds/Rocket whoosh 01.wav", volume = 0.5, pitch = { 0.2, 0.25 } },
	LevelUp = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.8, pitch = { 1.2, 1.2 } },
	UIClick = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.25, pitch = { 1.6, 1.7 } },
	UIConfirm = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.4, pitch = { 1.1, 1.1 } },
	SpinTick = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.15, pitch = { 2, 2.2 } },
}

return Sounds
