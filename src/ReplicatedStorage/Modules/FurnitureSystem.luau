--[[
	FurnitureSystem
	Furniture / decoration / toy catalog and the grid placement rules.

	Placement format (saved in data.furniture.placed):
	    { id = "couch", x = -3, z = 2, r = 1 }
	x / z are GRID CELLS (Config.GridSize studs each) of the piece's minimum
	corner, r is the rotation in quarter turns. Because everything snaps to the
	same grid, validating a placement is a handful of rectangle checks that
	the server and client share.
]]

local Modules = script.Parent
local Config = require(Modules.Config)
local HouseSystem = require(Modules.HouseSystem)

local FurnitureSystem = {}

local rgb = Color3.fromRGB
local GRID = Config.GridSize

-- w / d are the footprint in studs (multiples of the grid size).
-- layer = "rug" pieces lie flat and other furniture may sit on top of them.
FurnitureSystem.List = {
	-- FURNITURE
	{ id = "couch", name = "Comfy Couch", category = "Furniture", price = 450, w = 6, d = 4, color = rgb(90, 140, 220), desc = "brady-sized. you can sit too, i guess." },
	{ id = "beanbag", name = "Bean Bag", category = "Furniture", price = 220, w = 4, d = 4, color = rgb(240, 110, 70), desc = "once he sits, he is not getting up." },
	{ id = "coffee_table", name = "Coffee Table", category = "Furniture", price = 180, w = 4, d = 2, color = rgb(150, 110, 70), desc = "for putting things on. revolutionary." },
	{ id = "bookshelf", name = "Bookshelf", category = "Furniture", price = 320, w = 4, d = 2, color = rgb(130, 90, 60), desc = "full of fashion magazines." },
	{ id = "tv_stand", name = "Big TV", category = "Furniture", price = 700, w = 6, d = 2, color = rgb(40, 40, 46), desc = "only plays runway shows." },
	{ id = "gaming_setup", name = "Gaming Setup", category = "Furniture", price = 1500, minAge = 13, w = 6, d = 4, color = rgb(50, 50, 60), desc = "RGB adds at least 30 FPS." },
	{ id = "clothing_rack", name = "Clothing Rack", category = "Furniture", price = 900, minAge = 10, w = 4, d = 2, color = rgb(200, 200, 205), desc = "the overflow rack. he has too many pieces." },
	{ id = "sneaker_wall", name = "Sneaker Wall", category = "Furniture", price = 2800, minAge = 16, w = 6, d = 2, color = rgb(240, 240, 240), desc = "every pair is deadstock. nobody may touch." },
	{ id = "mannequin", name = "Mannequin", category = "Furniture", price = 1200, minAge = 10, w = 2, d = 2, color = rgb(230, 225, 215), desc = "better dressed than most people." },
	{ id = "fishtank", name = "Goo Fish Tank", category = "Furniture", price = 1100, w = 4, d = 2, color = rgb(90, 200, 230), desc = "the fish are also dripped out." },
	{ id = "vinyl_player", name = "Vinyl Player", category = "Furniture", price = 2000, minAge = 16, w = 2, d = 2, color = rgb(120, 70, 40), desc = "sounds worse. costs more. he loves it." },
	{ id = "throne", name = "Golden Throne", category = "Furniture", price = 12000, minAge = 21, w = 4, d = 4, color = rgb(255, 205, 60), desc = "for the most archive person on roblox." },
	-- DECOR
	{ id = "rug_goo", name = "Goo Splat Rug", category = "Decor", price = 80, w = 4, d = 4, layer = "rug", color = rgb(126, 232, 74), desc = "it's supposed to look like that." },
	{ id = "rug_checker", name = "Checker Rug", category = "Decor", price = 250, w = 6, d = 6, layer = "rug", color = rgb(30, 30, 30), desc = "very skater. very cool." },
	{ id = "rug_red", name = "Red Carpet", category = "Decor", price = 400, minAge = 8, w = 2, d = 8, layer = "rug", color = rgb(190, 30, 40), desc = "he insists on entering every room this way." },
	{ id = "plant", name = "Leafy Plant", category = "Decor", price = 90, w = 2, d = 2, color = rgb(70, 170, 80), desc = "it's fake. he still waters it." },
	{ id = "lamp", name = "Floor Lamp", category = "Decor", price = 140, w = 2, d = 2, color = rgb(255, 230, 160), desc = "mood lighting for fit pics." },
	{ id = "lava_lamp", name = "Lava Lamp", category = "Decor", price = 350, w = 2, d = 2, color = rgb(255, 90, 160), desc = "hypnotising. he has been staring for an hour." },
	{ id = "speaker", name = "Big Speaker", category = "Decor", price = 500, w = 2, d = 2, color = rgb(40, 40, 46), desc = "the neighbours also get to enjoy it." },
	{ id = "neon_sign", name = "GOO Neon Sign", category = "Decor", price = 650, w = 4, d = 2, color = rgb(126, 232, 74), desc = "so everyone knows whose room this is." },
	{ id = "poster", name = "Fit Pic Poster", category = "Decor", price = 200, w = 2, d = 2, color = rgb(255, 200, 60), desc = "a poster of himself. obviously." },
	{ id = "arcade", name = "Arcade Cabinet", category = "Decor", price = 1300, minAge = 8, w = 2, d = 2, color = rgb(200, 50, 200), desc = "high score: BDY 999999." },
	{ id = "disco_ball", name = "Disco Ball", category = "Decor", price = 1800, minAge = 10, w = 2, d = 2, color = rgb(220, 220, 235), desc = "every night is a fashion show after-party." },
	{ id = "goo_fountain", name = "Goo Fountain", category = "Decor", price = 4500, minAge = 16, w = 4, d = 4, color = rgb(126, 232, 74), desc = "an indoor fountain of goo. classy." },
	{ id = "gold_statue", name = "Golden Brady Statue", category = "Decor", price = 8000, minAge = 18, w = 2, d = 2, color = rgb(255, 205, 60), desc = "humble." },
	{ id = "trophy_lamp", name = "Golden Trophy Lamp", category = "Decor", w = 2, d = 2, color = rgb(255, 205, 60), special = true, desc = "a daily login exclusive. flex responsibly." },
	-- VIP DECOR (needs the VIP Room Decorations gamepass - purely cosmetic)
	{ id = "vip_rope", name = "VIP Velvet Rope", category = "Decor", price = 500, vip = true, w = 4, d = 2, color = rgb(190, 30, 40), desc = "you're on the list." },
	{ id = "vip_hottub", name = "VIP Goo Hot Tub", category = "Decor", price = 3000, vip = true, w = 6, d = 6, color = rgb(126, 232, 74), desc = "warm goo. surprisingly relaxing." },
	{ id = "vip_dj", name = "VIP DJ Booth", category = "Decor", price = 2500, vip = true, w = 6, d = 4, color = rgb(60, 40, 120), desc = "DJ Goo on the ones and twos." },
	{ id = "vip_pillar", name = "VIP Gold Pillar", category = "Decor", price = 1200, vip = true, w = 2, d = 2, color = rgb(255, 205, 60), desc = "holds up nothing. looks rich." },
	-- TOYS (Brady can play with these in his room)
	{ id = "toy_blocks", name = "Goo Blocks", category = "Toys", price = 120, toy = true, w = 2, d = 2, color = rgb(240, 90, 90), desc = "he builds a tower. he destroys the tower." },
	{ id = "toy_ball", name = "Bouncy Ball", category = "Toys", price = 100, toy = true, w = 2, d = 2, color = rgb(255, 200, 60), desc = "boing." },
	{ id = "toy_dino", name = "Plush Dino", category = "Toys", price = 280, toy = true, w = 2, d = 2, color = rgb(90, 200, 120), desc = "his name is Gerald." },
	{ id = "toy_car", name = "Toy Race Car", category = "Toys", price = 450, toy = true, w = 4, d = 2, color = rgb(230, 50, 60), desc = "vroom. beep beep." },
	{ id = "toy_boombox", name = "Boombox", category = "Toys", price = 700, minAge = 5, toy = true, w = 2, d = 2, color = rgb(60, 60, 70), desc = "instant dance party." },
	{ id = "toy_trampoline", name = "Mini Trampoline", category = "Toys", price = 950, minAge = 5, toy = true, w = 4, d = 4, color = rgb(60, 120, 240), desc = "he has hit the ceiling twice." },
}

FurnitureSystem.ById = {}
for _, def in ipairs(FurnitureSystem.List) do
	FurnitureSystem.ById[def.id] = def
end

FurnitureSystem.Categories = { "Furniture", "Decor", "Toys" }

function FurnitureSystem.get(id)
	return FurnitureSystem.ById[id]
end

-- Footprint (studs) after rotation.
function FurnitureSystem.footprint(def, r)
	if r % 2 == 1 then
		return def.d, def.w
	end
	return def.w, def.d
end

-- Room-local rectangle a placement covers.
function FurnitureSystem.rectOf(placement)
	local def = FurnitureSystem.ById[placement.id]
	local w, d = FurnitureSystem.footprint(def, placement.r)
	local minX, minZ = placement.x * GRID, placement.z * GRID
	return HouseSystem.rect(minX, minX + w, minZ, minZ + d)
end

-- Room-local CFrame for the model (centre of the footprint, on the floor).
function FurnitureSystem.localCFrame(placement)
	local r = FurnitureSystem.rectOf(placement)
	local center = Vector3.new((r.minX + r.maxX) / 2, 0, (r.minZ + r.maxZ) / 2)
	return CFrame.new(center) * CFrame.Angles(0, math.rad(90 * placement.r), 0)
end

-- Converts a desired room-local centre point into snapped grid coordinates.
function FurnitureSystem.snap(id, localX, localZ, r)
	local def = FurnitureSystem.ById[id]
	local w, d = FurnitureSystem.footprint(def, r)
	local x = math.floor((localX - w / 2) / GRID + 0.5)
	local z = math.floor((localZ - d / 2) / GRID + 0.5)
	return x, z
end

local function isInt(value)
	return type(value) == "number" and value == value and value % 1 == 0 and math.abs(value) < 1000
end

-- The single source of truth for "is this placement allowed?".
-- `placed` is the list of existing placements, `ignoreIndex` skips one of them.
function FurnitureSystem.canPlace(placed, id, x, z, r, houseSize, ignoreIndex)
	local def = FurnitureSystem.ById[id]
	if not def then
		return false, "unknown furniture"
	end
	if not (isInt(x) and isInt(z) and isInt(r)) or r < 0 or r > 3 then
		return false, "bad position"
	end
	local candidate = { id = id, x = x, z = z, r = r }
	local area = FurnitureSystem.rectOf(candidate)
	local h = houseSize / 2
	if area.minX < -h or area.maxX > h or area.minZ < -h or area.maxZ > h then
		return false, "that's outside the room"
	end
	for _, blocked in ipairs(HouseSystem.blockedRects(houseSize)) do
		if HouseSystem.rectsOverlap(area, blocked) then
			return false, "something is already there"
		end
	end
	for index, other in ipairs(placed) do
		if index ~= ignoreIndex then
			local otherDef = FurnitureSystem.ById[other.id]
			-- Rugs only block other rugs; normal furniture ignores rugs.
			if otherDef and (otherDef.layer == "rug") == (def.layer == "rug") then
				if HouseSystem.rectsOverlap(area, FurnitureSystem.rectOf(other)) then
					return false, "overlaps other furniture"
				end
			end
		end
	end
	return true
end

-- How many copies of `id` are currently placed.
function FurnitureSystem.placedCount(placed, id)
	local n = 0
	for _, placement in ipairs(placed) do
		if placement.id == id then
			n += 1
		end
	end
	return n
end

return FurnitureSystem
