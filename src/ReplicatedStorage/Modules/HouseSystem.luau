--[[
	HouseSystem
	Shared layout maths for a player's room.

	The room is a square whose side grows with Brady's stage (24 -> 60 studs).
	Everything is expressed in ROOM-LOCAL studs: origin = centre of the floor,
	the front door is in the +Z wall. The server turns these into world space
	with the plot's CFrame, and the client uses the same numbers to validate
	furniture placement before asking the server.
]]

local HouseSystem = {}

HouseSystem.DoorWidth = 7
HouseSystem.FloorHeight = 1 -- floor top sits this many studs above the plot

-- Rectangles are { minX, maxX, minZ, maxZ } in room-local studs.
local function rect(minX, maxX, minZ, maxZ)
	return { minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ }
end

-- Fixed stations every room has. `rect` = floor area they block,
-- `stand` = where Brady stands to use it, `face` = direction he looks.
function HouseSystem.stations(size)
	local h = size / 2
	return {
		Bed = {
			rect = rect(-h + 0.5, -h + 6.5, -h + 0.5, -h + 8.5),
			center = Vector3.new(-h + 3.5, 0, -h + 4.5),
			stand = Vector3.new(-h + 3.5, 1.9, -h + 5.2), -- on top of the mattress
			face = Vector3.new(0, 0, 1),
		},
		Wardrobe = {
			rect = rect(-h + 8, -h + 12, -h, -h + 3),
			center = Vector3.new(-h + 10, 0, -h + 1.5),
			stand = Vector3.new(-h + 10, 0, -h + 5.5),
			face = Vector3.new(0, 0, 1),
		},
		Mirror = {
			rect = rect(-h + 13, -h + 17, -h, -h + 1.5),
			center = Vector3.new(-h + 15, 0, -h + 0.75),
			stand = Vector3.new(-h + 15, 0, -h + 5),
			face = Vector3.new(0, 0, 1),
		},
		Display = {
			rect = rect(h - 5.5, h - 0.5, -h, -h + 3.5),
			center = Vector3.new(h - 3, 0, -h + 1.75),
			stand = Vector3.new(h - 3, 0, -h + 6),
			face = Vector3.new(0, 0, -1),
		},
		Food = {
			rect = rect(h - 3.5, h - 0.5, -h + 6, -h + 12),
			center = Vector3.new(h - 2, 0, -h + 9),
			stand = Vector3.new(h - 6, 0, -h + 9),
			face = Vector3.new(1, 0, 0),
		},
		Trophy = {
			rect = rect(h - 2, h, h - 11, h - 7),
			center = Vector3.new(h - 1, 0, h - 9),
			stand = Vector3.new(h - 4, 0, h - 9),
			face = Vector3.new(1, 0, 0),
		},
		Podium = {
			rect = rect(h - 7, h - 1, h - 7, h - 1),
			center = Vector3.new(h - 4, 0, h - 4),
			stand = Vector3.new(h - 4, 1, h - 4), -- on top of the podium
			face = Vector3.new(-1, 0, -1),
		},
		Shower = {
			rect = rect(-h + 0.5, -h + 5.5, h - 5.5, h - 0.5),
			center = Vector3.new(-h + 3, 0, h - 3),
			stand = Vector3.new(-h + 3, 0.3, h - 3),
			face = Vector3.new(1, 0, -1),
		},
		Sink = {
			rect = rect(-h, -h + 3, h - 10, h - 7),
			center = Vector3.new(-h + 1.5, 0, h - 8.5),
			stand = Vector3.new(-h + 4.5, 0, h - 8.5),
			face = Vector3.new(-1, 0, 0),
		},
		ShoeMat = {
			rect = rect(-6.5, -3.5, h - 3, h - 1),
			center = Vector3.new(-5, 0, h - 2),
			stand = Vector3.new(-5, 0, h - 2),
			face = Vector3.new(0, 0, -1),
		},
	}
end

-- Floor areas furniture may not cover (stations + the doorway).
function HouseSystem.blockedRects(size)
	local h = size / 2
	local list = {}
	for _, station in pairs(HouseSystem.stations(size)) do
		table.insert(list, station.rect)
	end
	local doorHalf = HouseSystem.DoorWidth / 2
	table.insert(list, rect(-doorHalf, doorHalf, h - 4, h))
	return list
end

function HouseSystem.rectsOverlap(a, b)
	return a.minX < b.maxX and a.maxX > b.minX and a.minZ < b.maxZ and a.maxZ > b.minZ
end

function HouseSystem.pointInRect(x, z, r, margin)
	margin = margin or 0
	return x > r.minX - margin and x < r.maxX + margin and z > r.minZ - margin and z < r.maxZ + margin
end

-- Local CFrame (position + facing) Brady uses at a station.
function HouseSystem.standCFrame(size, stationName)
	local station = HouseSystem.stations(size)[stationName]
	local pos = station.stand
	return CFrame.lookAt(pos, pos + station.face)
end

-- Is a local point inside the room (used for "Brady must be home" checks)?
function HouseSystem.isInside(size, localPosition, margin)
	local h = size / 2 + (margin or 0)
	return math.abs(localPosition.X) <= h and math.abs(localPosition.Z) <= h
end

-- Spot just outside the front door (visitors and "Go Home" land here).
function HouseSystem.doorstep(size)
	local h = size / 2
	return CFrame.lookAt(Vector3.new(0, 0, h + 5), Vector3.new(0, 0, 0))
end

HouseSystem.rect = rect

return HouseSystem
