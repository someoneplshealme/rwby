--!strict
--[[
	Map layout shared by the server (world builder, Grimm spawns, safe zones) and the client
	(zone banners, the shattered moon).

	Beacon Academy sits on a cliff plateau. North (-Z) lies the Emerald Forest with its ruined
	temple, east the Vale commercial district with the Dust shop, west the red Forever Fall.
]]

export type Zone = {
	id: string,
	name: string,
	center: Vector3,
	size: Vector3, -- axis-aligned extents used for "you entered X" banners
	safe: boolean,
}

export type SpawnZone = {
	grimm: string,
	center: Vector3,
	radius: number,
	count: number,
	respawn: number,
}

local World = {}

World.PlateauHeight = 24
World.Spawn = Vector3.new(0, 28, 40)

World.Zones = {
	{
		id = "Beacon",
		name = "Beacon Academy",
		center = Vector3.new(0, 24, 0),
		size = Vector3.new(220, 80, 200),
		safe = true,
	},
	{
		id = "Vale",
		name = "Vale — Commercial District",
		center = Vector3.new(250, 24, 0),
		size = Vector3.new(170, 80, 140),
		safe = true,
	},
	{
		id = "EmeraldForest",
		name = "Emerald Forest",
		center = Vector3.new(0, 0, -380),
		size = Vector3.new(520, 140, 470),
		safe = false,
	},
	{
		id = "ForeverFall",
		name = "Forever Fall",
		center = Vector3.new(-360, 0, -120),
		size = Vector3.new(300, 140, 360),
		safe = false,
	},
} :: { Zone }

World.GrimmSpawns = {
	{ grimm = "Beowolf", center = Vector3.new(-60, 4, -260), radius = 45, count = 4, respawn = 25 },
	{ grimm = "Beowolf", center = Vector3.new(90, 4, -330), radius = 45, count = 4, respawn = 25 },
	{ grimm = "Alpha", center = Vector3.new(0, 4, -470), radius = 25, count = 1, respawn = 90 },
	{ grimm = "Beowolf", center = Vector3.new(0, 4, -430), radius = 40, count = 3, respawn = 30 },
	{ grimm = "Ursa", center = Vector3.new(-380, 4, -180), radius = 50, count = 2, respawn = 60 },
	{ grimm = "Beowolf", center = Vector3.new(-320, 4, -40), radius = 50, count = 3, respawn = 30 },
} :: { SpawnZone }

World.DustShop = Vector3.new(268, 24, -38)
World.LaunchPads = {
	{ position = Vector3.new(-18, 24.6, -96), direction = Vector3.new(-0.1, 0.62, -1) },
	{ position = Vector3.new(0, 24.6, -98), direction = Vector3.new(0, 0.62, -1) },
	{ position = Vector3.new(18, 24.6, -96), direction = Vector3.new(0.1, 0.62, -1) },
}
World.LaunchSpeed = 150

function World.zoneAt(position: Vector3): Zone?
	for _, zone in World.Zones do
		local delta = position - zone.center
		local half = zone.size / 2
		if math.abs(delta.X) <= half.X and math.abs(delta.Y) <= half.Y and math.abs(delta.Z) <= half.Z then
			return zone
		end
	end
	return nil
end

function World.isSafe(position: Vector3): boolean
	local zone = World.zoneAt(position)
	return zone ~= nil and zone.safe
end

return World
