--[[
	FurnitureBuilder
	Builds every furniture / decoration / toy model out of parts.

	Each model has an invisible PrimaryPart called "Base" that exactly matches
	the item's footprint and sits on the floor, so placing a piece is just
	model:PivotTo(floorCFrame). The client uses the same builder for the
	translucent "ghost" you see while placing furniture.

	Models are built facing -Z (their "front").
]]

local Modules = script.Parent.Parent
local FurnitureSystem = require(Modules.FurnitureSystem)
local PartUtil = require(script.Parent.PartUtil)

local FurnitureBuilder = {}

local rgb = Color3.fromRGB
local v3 = Vector3.new
local rad = math.rad
local UP = PartUtil.UP

local WHITE = rgb(245, 245, 245)
local BLACK = rgb(30, 30, 34)
local WOOD = rgb(140, 100, 64)
local GOLD = rgb(255, 205, 60)
local GOO = rgb(126, 232, 74)

-- Each recipe receives p(name, size, position, color, opts) where position is
-- relative to the centre of the footprint with y measured up from the floor.
local RECIPES = {}

function RECIPES.couch(p, def)
	local c = def.color
	p("Seat", v3(5.6, 1.1, 3), v3(0, 0.75, -0.2), c, { material = "Fabric" })
	p("Back", v3(5.6, 2.4, 0.8), v3(0, 1.6, 1.5), PartUtil.shade(c, 0.9), { material = "Fabric" })
	p("ArmL", v3(0.7, 1.8, 3.4), v3(-2.6, 1.1, 0), PartUtil.shade(c, 0.85), { material = "Fabric" })
	p("ArmR", v3(0.7, 1.8, 3.4), v3(2.6, 1.1, 0), PartUtil.shade(c, 0.85), { material = "Fabric" })
	p("Pillow", v3(1.2, 1, 0.5), v3(-1.6, 1.7, 0.9), GOO, { material = "Fabric", rot = CFrame.Angles(rad(-15), 0, 0), collide = false })
end

function RECIPES.beanbag(p, def)
	p("Bag", v3(1.5, 3.4, 3.4), v3(0, 0.75, 0), def.color, { shape = "Cylinder", rot = UP, material = "Fabric" })
	p("Top", v3(2.4, 2.4, 2.4), v3(0, 1.3, 0.3), PartUtil.shade(def.color, 0.92), { shape = "Ball", material = "Fabric" })
end

function RECIPES.coffee_table(p, def)
	p("Top", v3(3.6, 0.3, 1.8), v3(0, 1.3, 0), def.color, { material = "Wood" })
	for _, x in ipairs({ -1.5, 1.5 }) do
		for _, z in ipairs({ -0.6, 0.6 }) do
			p("Leg", v3(0.3, 1.15, 0.3), v3(x, 0.58, z), PartUtil.shade(def.color, 0.8), { material = "Wood" })
		end
	end
	p("Magazine", v3(0.9, 0.08, 0.7), v3(0.6, 1.5, 0), rgb(240, 90, 160), { rot = CFrame.Angles(0, rad(20), 0), collide = false })
end

function RECIPES.bookshelf(p, def)
	p("Frame", v3(3.8, 5, 1.4), v3(0, 2.5, 0.2), def.color, { material = "Wood" })
	local colors = { rgb(230, 70, 70), rgb(70, 140, 230), GOO, GOLD, rgb(170, 90, 255) }
	for row = 0, 2 do
		p("Shelf", v3(3.5, 0.12, 1.5), v3(0, 0.9 + row * 1.5, 0.1), PartUtil.shade(def.color, 1.2), { material = "Wood", collide = false })
		for i = 1, 5 do
			p("Book", v3(0.4, 1 + (i % 2) * 0.2, 0.9), v3(-1.6 + i * 0.5, 1.5 + row * 1.5, -0.45), colors[(i + row) % 5 + 1], { collide = false })
		end
	end
end

function RECIPES.tv_stand(p, def)
	p("Cabinet", v3(5.6, 1.4, 1.6), v3(0, 0.7, 0.1), WOOD, { material = "Wood" })
	p("Screen", v3(5, 2.8, 0.25), v3(0, 3, 0.2), def.color)
	p("Picture", v3(4.6, 2.4, 0.05), v3(0, 3, 0.06), rgb(90, 190, 255), { material = "Neon", collide = false })
	p("Neck", v3(0.5, 0.4, 0.4), v3(0, 1.55, 0.2), def.color, { collide = false })
end

function RECIPES.gaming_setup(p, def)
	p("Desk", v3(5.6, 0.3, 2), v3(0, 2.4, 0.9), rgb(60, 60, 70), { material = "Wood" })
	p("LegL", v3(0.3, 2.3, 1.8), v3(-2.6, 1.15, 0.9), BLACK)
	p("LegR", v3(0.3, 2.3, 1.8), v3(2.6, 1.15, 0.9), BLACK)
	p("Monitor", v3(3, 1.7, 0.2), v3(0, 3.7, 1.4), BLACK)
	p("Display", v3(2.8, 1.5, 0.05), v3(0, 3.7, 1.28), rgb(120, 255, 170), { material = "Neon", collide = false })
	p("Tower", v3(0.8, 1.6, 1.4), v3(2, 3.35, 1), BLACK)
	p("RGB", v3(0.1, 1.4, 1.2), v3(1.58, 3.35, 1), rgb(255, 80, 200), { material = "Neon", collide = false })
	p("Keyboard", v3(1.6, 0.1, 0.5), v3(0, 2.6, 0.5), rgb(200, 200, 205), { collide = false })
	p("ChairSeat", v3(1.6, 0.4, 1.6), v3(0, 1.5, -1), rgb(220, 50, 60), { material = "Fabric" })
	p("ChairBack", v3(1.6, 2.2, 0.3), v3(0, 2.7, -1.7), rgb(220, 50, 60), { material = "Fabric" })
	p("ChairPole", v3(0.3, 1.3, 0.3), v3(0, 0.65, -1), BLACK, { collide = false })
end

function RECIPES.clothing_rack(p, def)
	p("PoleL", v3(0.2, 5, 0.2), v3(-1.7, 2.5, 0), def.color, { material = "Metal" })
	p("PoleR", v3(0.2, 5, 0.2), v3(1.7, 2.5, 0), def.color, { material = "Metal" })
	p("Bar", v3(3.6, 0.2, 0.2), v3(0, 4.9, 0), def.color, { material = "Metal" })
	p("Foot", v3(3.8, 0.2, 1.6), v3(0, 0.1, 0), PartUtil.shade(def.color, 0.8), { material = "Metal" })
	local colors = { rgb(232, 66, 78), BLACK, rgb(236, 226, 200), rgb(72, 110, 170), GOO }
	for i = 1, 5 do
		p("Garment", v3(0.25, 2.4, 1.3), v3(-1.5 + i * 0.5, 3.5, 0), colors[i], { material = "Fabric", collide = false })
	end
end

function RECIPES.sneaker_wall(p, def)
	p("Panel", v3(5.8, 6, 0.4), v3(0, 3, 0.7), def.color)
	local colors = { rgb(232, 66, 78), GOLD, rgb(72, 150, 255), WHITE, GOO, rgb(178, 92, 255), BLACK, rgb(255, 150, 60), rgb(255, 110, 225) }
	for row = 0, 2 do
		p("Shelf", v3(5.6, 0.15, 1.4), v3(0, 1.3 + row * 1.7, 0.1), rgb(210, 210, 215), { collide = false })
		p("Glow", v3(5.6, 0.06, 0.1), v3(0, 1.22 + row * 1.7, -0.55), rgb(255, 255, 220), { material = "Neon", collide = false })
		for i = 1, 3 do
			local color = colors[row * 3 + i]
			p("Shoe", v3(1.2, 0.5, 0.6), v3(-1.9 + (i - 1) * 1.9, 1.65 + row * 1.7, 0), color, { collide = false })
			p("Sole", v3(1.26, 0.14, 0.66), v3(-1.9 + (i - 1) * 1.9, 1.44 + row * 1.7, 0), WHITE, { collide = false })
		end
	end
end

function RECIPES.mannequin(p, def)
	p("Stand", v3(0.3, 1.6, 1.6), v3(0, 0.15, 0), BLACK, { shape = "Cylinder", rot = UP })
	p("Pole", v3(0.2, 2.2, 0.2), v3(0, 1.3, 0), BLACK, { collide = false })
	p("Torso", v3(1.6, 1.9, 0.9), v3(0, 3.3, 0), def.color)
	p("Head", v3(1, 1, 1), v3(0, 4.8, 0), def.color, { shape = "Ball" })
	p("Jacket", v3(1.8, 1.5, 1.05), v3(0, 3.4, 0), rgb(52, 70, 46), { material = "Fabric", collide = false })
end

function RECIPES.fishtank(p, def)
	p("Stand", v3(3.8, 1.6, 1.6), v3(0, 0.8, 0), WOOD, { material = "Wood" })
	p("Water", v3(3.5, 1.8, 1.3), v3(0, 2.5, 0), def.color, { material = "Glass", transparency = 0.45 })
	p("Sand", v3(3.5, 0.2, 1.3), v3(0, 1.7, 0), rgb(240, 220, 160), { material = "Sand", collide = false })
	p("Fish", v3(0.5, 0.3, 0.15), v3(-0.8, 2.6, 0), rgb(255, 140, 40), { material = "Neon", collide = false })
	p("Fish", v3(0.4, 0.25, 0.15), v3(0.9, 2.9, 0.2), GOO, { material = "Neon", collide = false })
	p("Lid", v3(3.6, 0.15, 1.4), v3(0, 3.45, 0), BLACK, { collide = false })
end

function RECIPES.vinyl_player(p, def)
	p("Cabinet", v3(1.8, 2, 1.6), v3(0, 1, 0), def.color, { material = "Wood" })
	p("Deck", v3(1.7, 0.15, 1.5), v3(0, 2.05, 0), BLACK, { collide = false })
	p("Record", v3(0.08, 1.2, 1.2), v3(-0.1, 2.18, 0), rgb(20, 20, 20), { shape = "Cylinder", rot = UP, collide = false })
	p("Label", v3(0.09, 0.4, 0.4), v3(-0.1, 2.19, 0), GOO, { shape = "Cylinder", rot = UP, collide = false })
	p("Arm", v3(0.08, 0.08, 0.8), v3(0.65, 2.25, 0.1), rgb(200, 200, 205), { rot = CFrame.Angles(0, rad(-20), 0), collide = false })
end

function RECIPES.throne(p, def)
	local c = def.color
	local gold = { material = "Glass", reflectance = 0.3 }
	p("Seat", v3(3.2, 1.4, 3), v3(0, 0.7, -0.1), c, gold)
	p("Cushion", v3(2.6, 0.4, 2.4), v3(0, 1.55, -0.2), rgb(190, 30, 40), { material = "Fabric" })
	p("Back", v3(3.2, 5.2, 0.7), v3(0, 3.3, 1.45), c, gold)
	p("BackPad", v3(2.4, 3.6, 0.2), v3(0, 3.4, 1.05), rgb(190, 30, 40), { material = "Fabric", collide = false })
	p("ArmL", v3(0.6, 1.6, 3), v3(-1.6, 2, -0.1), c, gold)
	p("ArmR", v3(0.6, 1.6, 3), v3(1.6, 2, -0.1), c, gold)
	for _, x in ipairs({ -1.2, 0, 1.2 }) do
		p("Spike", v3(0.5, x == 0 and 1.2 or 0.8, 0.5), v3(x, 6.2 + (x == 0 and 0.2 or 0), 1.45), c, gold)
		p("Gem", v3(0.4, 0.4, 0.4), v3(x, 5.4, 1.05), GOO, { shape = "Ball", material = "Neon", collide = false })
	end
end

local function rug(p, def, tiles)
	p("Rug", v3(def.w - 0.2, 0.12, def.d - 0.2), v3(0, 0.06, 0), def.color, { material = "Carpet", collide = false })
	if tiles then
		local nx, nz = def.w / 2, def.d / 2
		for ix = 0, nx - 1 do
			for iz = 0, nz - 1 do
				if (ix + iz) % 2 == 0 then
					p("Tile", v3(1.8, 0.14, 1.8), v3(-def.w / 2 + 1 + ix * 2, 0.07, -def.d / 2 + 1 + iz * 2), WHITE, { material = "Carpet", collide = false })
				end
			end
		end
	end
end

function RECIPES.rug_goo(p, def)
	p("Splat", v3(0.12, 3.6, 3.6), v3(0, 0.06, 0), def.color, { shape = "Cylinder", rot = UP, material = "Carpet", collide = false })
	p("Blob", v3(0.13, 1.4, 1.4), v3(1.2, 0.065, 1.1), def.color, { shape = "Cylinder", rot = UP, material = "Fabric", collide = false })
	p("Blob", v3(0.13, 1.1, 1.1), v3(-1.3, 0.065, -1), def.color, { shape = "Cylinder", rot = UP, material = "Fabric", collide = false })
	p("Shine", v3(0.14, 0.8, 0.8), v3(-0.5, 0.07, 0.5), PartUtil.shade(def.color, 1.25), { shape = "Cylinder", rot = UP, collide = false })
end

function RECIPES.rug_checker(p, def)
	rug(p, def, true)
end

function RECIPES.rug_red(p, def)
	rug(p, def, false)
	p("TrimL", v3(0.15, 0.14, def.d - 0.2), v3(-0.85, 0.07, 0), GOLD, { collide = false })
	p("TrimR", v3(0.15, 0.14, def.d - 0.2), v3(0.85, 0.07, 0), GOLD, { collide = false })
end

function RECIPES.plant(p, def)
	p("Pot", v3(1.2, 1.3, 1.3), v3(0, 0.6, 0), rgb(200, 110, 70), { shape = "Cylinder", rot = UP })
	p("Stem", v3(0.2, 1.6, 0.2), v3(0, 1.9, 0), rgb(110, 80, 50), { collide = false })
	p("Leaves", v3(1.8, 1.8, 1.8), v3(0, 3.1, 0), def.color, { shape = "Ball", material = "Grass", collide = false })
	p("Leaves", v3(1.2, 1.2, 1.2), v3(0.6, 2.5, 0.3), PartUtil.shade(def.color, 0.85), { shape = "Ball", material = "Grass", collide = false })
	p("Leaves", v3(1.1, 1.1, 1.1), v3(-0.6, 2.6, -0.2), PartUtil.shade(def.color, 1.1), { shape = "Ball", material = "Grass", collide = false })
end

function RECIPES.lamp(p, def)
	p("Base", v3(0.25, 1.4, 1.4), v3(0, 0.12, 0), BLACK, { shape = "Cylinder", rot = UP })
	p("Pole", v3(0.18, 4.6, 0.18), v3(0, 2.5, 0), BLACK, { collide = false })
	local shade = p("Shade", v3(1.2, 1.5, 1.5), v3(0, 5.2, 0), def.color, { shape = "Cylinder", rot = UP, material = "Neon", collide = false })
	local light = Instance.new("PointLight")
	light.Color = def.color
	light.Range = 14
	light.Brightness = 1
	light.Shadows = false
	light.Parent = shade
end

function RECIPES.lava_lamp(p, def)
	p("Base", v3(0.6, 1.1, 1.1), v3(0, 0.3, 0), rgb(200, 200, 205), { shape = "Cylinder", rot = UP, material = "Metal" })
	local glass = p("Glass", v3(2.4, 0.9, 0.9), v3(0, 1.8, 0), def.color, { shape = "Cylinder", rot = UP, material = "Neon", transparency = 0.2 })
	p("Blob", v3(0.5, 0.5, 0.5), v3(0.05, 1.5, 0), rgb(255, 220, 80), { shape = "Ball", material = "Neon", collide = false })
	p("Blob", v3(0.35, 0.35, 0.35), v3(-0.1, 2.3, 0.05), rgb(255, 220, 80), { shape = "Ball", material = "Neon", collide = false })
	p("Cap", v3(0.4, 0.8, 0.8), v3(0, 3.2, 0), rgb(200, 200, 205), { shape = "Cylinder", rot = UP, material = "Metal", collide = false })
	local light = Instance.new("PointLight")
	light.Color = def.color
	light.Range = 8
	light.Brightness = 0.8
	light.Shadows = false
	light.Parent = glass
end

function RECIPES.speaker(p, def)
	p("Box", v3(1.7, 3.6, 1.6), v3(0, 1.8, 0), def.color)
	p("Cone", v3(0.2, 1.2, 1.2), v3(0, 1.2, -0.75), rgb(70, 70, 76), { shape = "Cylinder", rot = PartUtil.FWD, collide = false })
	p("Cone", v3(0.2, 0.8, 0.8), v3(0, 2.7, -0.75), rgb(70, 70, 76), { shape = "Cylinder", rot = PartUtil.FWD, collide = false })
	p("Glow", v3(0.22, 0.4, 0.4), v3(0, 1.2, -0.76), GOO, { shape = "Cylinder", rot = PartUtil.FWD, material = "Neon", collide = false })
end

function RECIPES.neon_sign(p, def)
	p("PoleL", v3(0.2, 3, 0.2), v3(-1.5, 1.5, 0.4), BLACK, { collide = false })
	p("PoleR", v3(0.2, 3, 0.2), v3(1.5, 1.5, 0.4), BLACK, { collide = false })
	p("Foot", v3(3.6, 0.2, 1.2), v3(0, 0.1, 0.3), BLACK)
	local board = p("Board", v3(3.6, 2, 0.25), v3(0, 3.6, 0.4), rgb(24, 24, 30))
	local _, label = PartUtil.label(board, "GOO", { color = def.color })
	label.Font = Enum.Font.Bangers
	p("Tube", v3(3.7, 0.1, 0.1), v3(0, 4.65, 0.3), def.color, { material = "Neon", collide = false })
	p("Tube", v3(3.7, 0.1, 0.1), v3(0, 2.55, 0.3), def.color, { material = "Neon", collide = false })
end

function RECIPES.poster(p, def)
	p("LegL", v3(0.15, 4, 0.15), v3(-0.6, 2, 0.3), WOOD, { rot = CFrame.Angles(rad(8), 0, 0), collide = false })
	p("LegR", v3(0.15, 4, 0.15), v3(0.6, 2, 0.3), WOOD, { rot = CFrame.Angles(rad(8), 0, 0), collide = false })
	local board = p("Board", v3(1.8, 2.4, 0.15), v3(0, 2.9, 0.1), def.color, { rot = CFrame.Angles(rad(8), 0, 0) })
	PartUtil.label(board, "FIT\nPIC\n😎", { color = BLACK, stroke = false })
end

function RECIPES.arcade(p, def)
	p("Cabinet", v3(1.8, 4.6, 1.7), v3(0, 2.3, 0.1), def.color)
	p("Screen", v3(1.4, 1.2, 0.1), v3(0, 3.4, -0.78), rgb(90, 255, 200), { material = "Neon", collide = false })
	p("Panel", v3(1.7, 0.3, 0.9), v3(0, 2.3, -0.9), BLACK, { rot = CFrame.Angles(rad(-15), 0, 0), collide = false })
	p("Stick", v3(0.12, 0.4, 0.12), v3(-0.4, 2.6, -0.95), rgb(230, 50, 60), { collide = false })
	p("Button", v3(0.2, 0.1, 0.2), v3(0.3, 2.45, -1), GOLD, { material = "Neon", collide = false })
	p("Marquee", v3(1.8, 0.6, 0.2), v3(0, 4.3, -0.8), GOLD, { material = "Neon", collide = false })
end

function RECIPES.disco_ball(p, def)
	p("Base", v3(0.25, 1.4, 1.4), v3(0, 0.12, 0), BLACK, { shape = "Cylinder", rot = UP })
	p("Pole", v3(0.16, 5.2, 0.16), v3(0, 2.8, 0), rgb(200, 200, 205), { material = "Metal", collide = false })
	local ball = p("Ball", v3(1.7, 1.7, 1.7), v3(0, 6, 0), def.color, { shape = "Ball", material = "Glass", reflectance = 0.6, collide = false })
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 120, 230)
	light.Range = 16
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = ball
end

function RECIPES.goo_fountain(p, def)
	p("Basin", v3(1, 3.8, 3.8), v3(0, 0.5, 0), rgb(200, 200, 205), { shape = "Cylinder", rot = UP, material = "Marble" })
	p("Goo", v3(0.3, 3.3, 3.3), v3(0, 0.95, 0), def.color, { shape = "Cylinder", rot = UP, material = "Neon", collide = false })
	p("Pillar", v3(2.4, 0.8, 0.8), v3(0, 2, 0), rgb(200, 200, 205), { shape = "Cylinder", rot = UP, material = "Marble" })
	local top = p("Top", v3(1.3, 1.3, 1.3), v3(0, 3.5, 0), def.color, { shape = "Ball", material = "Neon", collide = false })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 10
	emitter.Lifetime = NumberRange.new(0.8, 1.2)
	emitter.Speed = NumberRange.new(3, 5)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.Acceleration = v3(0, -14, 0)
	emitter.Color = ColorSequence.new(def.color)
	emitter.Size = NumberSequence.new(0.35, 0.1)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = top
end

function RECIPES.gold_statue(p, def)
	local gold = { material = "Glass", reflectance = 0.35, collide = false }
	p("Pedestal", v3(1.8, 1.2, 1.8), v3(0, 0.6, 0), rgb(230, 230, 235), { material = "Marble" })
	p("LegL", v3(0.4, 0.9, 0.4), v3(-0.25, 1.65, 0), def.color, gold)
	p("LegR", v3(0.4, 0.9, 0.4), v3(0.25, 1.65, 0), def.color, gold)
	p("Torso", v3(1, 1, 0.5), v3(0, 2.6, 0), def.color, gold)
	p("ArmL", v3(0.35, 1, 0.35), v3(-0.7, 3.2, 0), def.color, gold)
	p("ArmR", v3(0.35, 1, 0.35), v3(0.7, 2.6, 0), def.color, gold)
	p("Head", v3(0.8, 0.8, 0.8), v3(0, 3.5, 0), def.color, gold)
	p("Hair", v3(0.86, 0.25, 0.86), v3(0, 3.95, 0), def.color, gold)
end

function RECIPES.trophy_lamp(p, def)
	local gold = { material = "Glass", reflectance = 0.35, collide = false }
	p("Base", v3(1.4, 0.5, 1.4), v3(0, 0.25, 0), BLACK)
	p("Stem", v3(0.3, 1, 0.3), v3(0, 1, 0), def.color, gold)
	local cup = p("Cup", v3(1.3, 1.3, 1.3), v3(0, 2.1, 0), def.color, { shape = "Cylinder", rot = UP, material = "Neon", collide = false })
	p("HandleL", v3(0.2, 0.8, 0.2), v3(-0.8, 2.1, 0), def.color, gold)
	p("HandleR", v3(0.2, 0.8, 0.2), v3(0.8, 2.1, 0), def.color, gold)
	local light = Instance.new("PointLight")
	light.Color = def.color
	light.Range = 12
	light.Brightness = 1
	light.Shadows = false
	light.Parent = cup
end

function RECIPES.vip_rope(p, def)
	for _, x in ipairs({ -1.6, 1.6 }) do
		p("Post", v3(2.8, 0.4, 0.4), v3(x, 1.4, 0), GOLD, { shape = "Cylinder", rot = UP, material = "Glass", reflectance = 0.3 })
		p("Foot", v3(0.2, 1, 1), v3(x, 0.1, 0), GOLD, { shape = "Cylinder", rot = UP, material = "Glass", reflectance = 0.3 })
		p("Knob", v3(0.6, 0.6, 0.6), v3(x, 2.9, 0), GOLD, { shape = "Ball", material = "Glass", reflectance = 0.3, collide = false })
	end
	p("Rope", v3(3.2, 0.3, 0.3), v3(0, 2.3, 0), def.color, { material = "Fabric" })
end

function RECIPES.vip_hottub(p, def)
	p("Tub", v3(2, 5.6, 5.6), v3(0, 1, 0), rgb(120, 84, 56), { shape = "Cylinder", rot = UP, material = "Wood" })
	p("Goo", v3(0.4, 4.9, 4.9), v3(0, 1.85, 0), def.color, { shape = "Cylinder", rot = UP, material = "Neon", transparency = 0.15, collide = false })
	p("Step", v3(2, 0.8, 1), v3(0, 0.4, -2.6), rgb(120, 84, 56), { material = "Wood" })
	p("Bubble", v3(0.5, 0.5, 0.5), v3(1, 2.2, 0.6), WHITE, { shape = "Ball", material = "Glass", transparency = 0.4, collide = false })
	p("Bubble", v3(0.35, 0.35, 0.35), v3(-1.2, 2.15, -0.4), WHITE, { shape = "Ball", material = "Glass", transparency = 0.4, collide = false })
end

function RECIPES.vip_dj(p, def)
	p("Booth", v3(5.6, 3, 1.6), v3(0, 1.5, -0.6), def.color)
	p("Front", v3(5.6, 0.3, 0.1), v3(0, 2.2, -1.45), rgb(255, 80, 200), { material = "Neon", collide = false })
	p("Front", v3(5.6, 0.3, 0.1), v3(0, 1, -1.45), rgb(90, 255, 200), { material = "Neon", collide = false })
	for _, x in ipairs({ -1.6, 1.6 }) do
		p("Deck", v3(0.12, 1.5, 1.5), v3(x, 3.08, -0.6), BLACK, { shape = "Cylinder", rot = UP, collide = false })
		p("Label", v3(0.13, 0.5, 0.5), v3(x, 3.09, -0.6), GOO, { shape = "Cylinder", rot = UP, material = "Neon", collide = false })
	end
	p("Mixer", v3(1.2, 0.25, 1.2), v3(0, 3.12, -0.6), rgb(60, 60, 70), { collide = false })
	p("SpeakerL", v3(1.2, 3.6, 1.2), v3(-2.1, 1.8, 1.2), BLACK)
	p("SpeakerR", v3(1.2, 3.6, 1.2), v3(2.1, 1.8, 1.2), BLACK)
end

function RECIPES.vip_pillar(p, def)
	local gold = { shape = "Cylinder", rot = UP, material = "Glass", reflectance = 0.3 }
	p("Base", v3(0.6, 1.9, 1.9), v3(0, 0.3, 0), def.color, gold)
	p("Column", v3(6, 1.3, 1.3), v3(0, 3.6, 0), def.color, gold)
	p("Cap", v3(0.6, 1.9, 1.9), v3(0, 6.9, 0), def.color, gold)
end

function RECIPES.toy_blocks(p, def)
	p("Block", v3(1, 1, 1), v3(-0.3, 0.5, 0.2), def.color)
	p("Block", v3(1, 1, 1), v3(0.6, 0.5, -0.3), rgb(70, 140, 230), { rot = CFrame.Angles(0, rad(25), 0) })
	p("Block", v3(0.9, 0.9, 0.9), v3(0, 1.45, 0), GOLD, { rot = CFrame.Angles(0, rad(-15), 0) })
	p("Block", v3(0.7, 0.7, 0.7), v3(0.05, 2.25, 0), GOO, { rot = CFrame.Angles(0, rad(30), 0), collide = false })
end

function RECIPES.toy_ball(p, def)
	p("Ball", v3(1.6, 1.6, 1.6), v3(0, 0.8, 0), def.color, { shape = "Ball" })
	p("Stripe", v3(0.3, 1.63, 1.63), v3(0, 0.8, 0), rgb(230, 60, 60), { shape = "Cylinder", collide = false })
end

function RECIPES.toy_dino(p, def)
	local c = def.color
	p("Body", v3(1.4, 1.2, 1.2), v3(0, 0.9, 0.1), c, { material = "Fabric" })
	p("Head", v3(0.9, 0.9, 0.9), v3(0, 1.8, -0.5), c, { material = "Fabric", collide = false })
	p("Snout", v3(0.6, 0.45, 0.5), v3(0, 1.65, -1), PartUtil.shade(c, 0.9), { material = "Fabric", collide = false })
	p("Tail", v3(0.5, 0.5, 1), v3(0, 0.7, 0.95), c, { material = "Fabric", rot = CFrame.Angles(rad(-15), 0, 0), collide = false })
	for i = 0, 2 do
		p("Spike", v3(0.2, 0.35, 0.3), v3(0, 1.65 - i * 0.12, 0 + i * 0.4), rgb(255, 160, 60), { collide = false })
	end
	p("EyeL", v3(0.14, 0.14, 0.1), v3(-0.25, 1.95, -0.95), BLACK, { collide = false })
	p("EyeR", v3(0.14, 0.14, 0.1), v3(0.25, 1.95, -0.95), BLACK, { collide = false })
	p("LegL", v3(0.4, 0.4, 0.4), v3(-0.45, 0.2, -0.1), c, { material = "Fabric", collide = false })
	p("LegR", v3(0.4, 0.4, 0.4), v3(0.45, 0.2, -0.1), c, { material = "Fabric", collide = false })
end

function RECIPES.toy_car(p, def)
	p("Body", v3(3.2, 0.7, 1.5), v3(0, 0.75, 0), def.color)
	p("Cabin", v3(1.5, 0.6, 1.3), v3(-0.2, 1.4, 0), rgb(150, 210, 255), { material = "Glass", transparency = 0.3, collide = false })
	p("Spoiler", v3(0.2, 0.5, 1.5), v3(-1.5, 1.3, 0), BLACK, { collide = false })
	for _, x in ipairs({ -1.05, 1.05 }) do
		for _, z in ipairs({ -0.75, 0.75 }) do
			p("Wheel", v3(0.3, 0.8, 0.8), v3(x, 0.4, z), BLACK, { shape = "Cylinder", rot = PartUtil.FWD, collide = false })
		end
	end
end

function RECIPES.toy_boombox(p, def)
	p("Box", v3(1.8, 1.1, 0.8), v3(0, 0.55, 0), def.color)
	p("SpeakerL", v3(0.1, 0.7, 0.7), v3(-0.5, 0.55, -0.4), BLACK, { shape = "Cylinder", rot = PartUtil.FWD, collide = false })
	p("SpeakerR", v3(0.1, 0.7, 0.7), v3(0.5, 0.55, -0.4), BLACK, { shape = "Cylinder", rot = PartUtil.FWD, collide = false })
	p("Handle", v3(1.4, 0.12, 0.12), v3(0, 1.4, 0), rgb(200, 200, 205), { collide = false })
	p("Light", v3(0.3, 0.12, 0.05), v3(0, 0.95, -0.41), GOO, { material = "Neon", collide = false })
end

function RECIPES.toy_trampoline(p, def)
	p("Frame", v3(0.5, 3.8, 3.8), v3(0, 1.2, 0), def.color, { shape = "Cylinder", rot = UP })
	p("Mat", v3(0.2, 3.1, 3.1), v3(0, 1.4, 0), BLACK, { shape = "Cylinder", rot = UP, material = "Fabric", collide = false })
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		p("Leg", v3(0.25, 1, 0.25), v3(math.cos(a) * 1.5, 0.5, math.sin(a) * 1.5), rgb(200, 200, 205), { material = "Metal", collide = false })
	end
end

----------------------------------------------------------------------
-- build(id) -> Model (PrimaryPart = Base)
----------------------------------------------------------------------
function FurnitureBuilder.build(id)
	local def = FurnitureSystem.get(id)
	if not def then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = id

	local base = PartUtil.block(model, {
		name = "Base",
		size = v3(def.w, 0.1, def.d),
		cframe = CFrame.new(0, 0.05, 0),
		color = def.color,
		transparency = 1,
		collide = false,
	})
	model.PrimaryPart = base

	local function p(name, size, position, color, opts)
		opts = opts or {}
		local cframe = CFrame.new(position)
		if opts.rot then
			cframe = cframe * opts.rot
		end
		return PartUtil.block(model, {
			name = name,
			size = size,
			cframe = cframe,
			color = color,
			material = opts.material,
			shape = opts.shape,
			transparency = opts.transparency,
			reflectance = opts.reflectance,
			collide = opts.collide,
			shadow = opts.collide ~= false,
		})
	end

	local recipe = RECIPES[id]
	if recipe then
		recipe(p, def)
	else
		-- Fallback so a new catalog row is never invisible.
		p("Box", v3(def.w - 0.4, 2, def.d - 0.4), v3(0, 1, 0), def.color)
	end
	model:SetAttribute("FurnitureId", id)
	return model
end

-- Turns a built model into a translucent, non-colliding placement ghost.
function FurnitureBuilder.makeGhost(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			if descendant.Name ~= "Base" then
				descendant.Transparency = math.max(descendant.Transparency, 0.45)
			else
				descendant.Transparency = 0.6
				descendant.Material = Enum.Material.Neon
			end
		elseif descendant:IsA("PointLight") or descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
		end
	end
	return model
end

return FurnitureBuilder
