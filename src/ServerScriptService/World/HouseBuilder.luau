--[[
	HouseBuilder
	Builds a player's house out of parts. The house is fully parametric:
	  * its SIZE comes from Brady's stage (24 studs -> 60 studs)
	  * its STYLE (materials / colours / wall height) changes every 2 stages
	so every stage-up visibly upgrades the home.

	Layout numbers come from HouseSystem so the furniture rules, Brady's
	wander area and the physical stations always line up.

	Everything is positioned in room-local space (origin = centre of the
	floor, +Z = front door) and converted with the plot CFrame.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local AgeSystem = require(Modules.AgeSystem)
local ClothingSystem = require(Modules.ClothingSystem)
local HouseSystem = require(Modules.HouseSystem)
local Config = require(Modules.Config)
local PartUtil = require(Modules.Builders.PartUtil)
local Environment = require(script.Parent.Environment)

local HouseBuilder = {}

local rgb = Color3.fromRGB
local v3 = Vector3.new
local rad = math.rad
local UP = PartUtil.UP

local WHITE = rgb(245, 245, 245)
local GOLD = rgb(255, 205, 60)
local GOO = rgb(126, 232, 74)
local DARK = rgb(34, 34, 40)

HouseBuilder.RoofZoneTag = "RoofZone"
HouseBuilder.OwnerPromptTag = "OwnerPrompt"

-- One style per two stages. inside = interior plaster colour, base = the
-- baseboard / crown moulding colour, roofType = "gable" or "flat".
local STYLES = {
	{ -- Starter Shack: wooden cabin, shingle roof
		wall = rgb(150, 108, 70), wallMat = "WoodPlanks", inside = rgb(236, 222, 196), base = rgb(110, 78, 50),
		floor = rgb(184, 146, 102), floorMat = "WoodPlanks", trim = rgb(242, 234, 216), door = rgb(170, 64, 52),
		roof = rgb(150, 72, 58), roofMat = "RoofShingles", roofType = "gable", pitch = 0.6, chimney = true, flowerBoxes = true,
		height = 11, accent = GOO,
	},
	{ -- Cozy Crib: red brick, clay tile roof
		wall = rgb(186, 96, 74), wallMat = "Brick", inside = rgb(244, 234, 214), base = rgb(250, 248, 242),
		floor = rgb(206, 172, 128), floorMat = "WoodPlanks", trim = WHITE, door = rgb(40, 74, 120),
		roof = rgb(180, 86, 58), roofMat = "ClayRoofTiles", roofType = "gable", pitch = 0.5, chimney = true, flowerBoxes = true,
		height = 12, accent = rgb(255, 200, 80),
	},
	{ -- Drip Den: white modern plaster, flat roof, teal accents
		wall = rgb(238, 238, 240), wallMat = "Plaster", inside = rgb(246, 246, 248), base = rgb(60, 190, 190),
		floor = rgb(200, 200, 206), floorMat = "Concrete", trim = rgb(60, 190, 190), door = rgb(60, 190, 190),
		roof = rgb(150, 152, 160), roofMat = "Concrete", roofType = "flat",
		height = 13, accent = rgb(60, 190, 190),
	},
	{ -- Fashion Loft: dark basalt, flat roof with skylight, red accents
		wall = rgb(62, 62, 70), wallMat = "Basalt", inside = rgb(222, 216, 210), base = rgb(30, 30, 34),
		floor = rgb(60, 58, 64), floorMat = "Marble", trim = rgb(232, 66, 78), door = rgb(232, 66, 78),
		roof = rgb(46, 46, 52), roofMat = "Slate", roofType = "flat",
		height = 15, accent = rgb(232, 66, 78),
	},
	{ -- Archive Mansion: marble, dark shingle roof, gold everything
		wall = rgb(244, 238, 228), wallMat = "Marble", inside = rgb(250, 246, 238), base = GOLD,
		floor = rgb(248, 248, 250), floorMat = "Marble", trim = GOLD, door = rgb(30, 30, 36),
		roof = rgb(56, 60, 76), roofMat = "RoofShingles", roofType = "gable", pitch = 0.42, flowerBoxes = true,
		height = 17, accent = GOLD,
	},
}

-- opts = { age, ownerName, ownerUserId, showcase = { item, ... }, trophies = { achievements, wins } }
-- Returns model, info
function HouseBuilder.build(parent, plotCFrame, opts)
	local size = AgeSystem.houseSize(opts.age)
	local tier = AgeSystem.houseTier(opts.age)
	local style = STYLES[tier]
	local h = size / 2
	local H = style.height
	local origin = plotCFrame * CFrame.new(0, HouseSystem.FloorHeight, 0)
	local stations = HouseSystem.stations(size)

	local model = Instance.new("Model")
	model.Name = "House_" .. tostring(opts.ownerUserId)
	model:SetAttribute("OwnerUserId", opts.ownerUserId)
	model:SetAttribute("Size", size)

	local function p(name, partSize, position, color, o)
		o = o or {}
		local cframe = origin * CFrame.new(position)
		if o.rot then
			cframe = cframe * o.rot
		end
		return PartUtil.block(o.parent or model, {
			name = name,
			size = partSize,
			cframe = cframe,
			color = color,
			material = o.material,
			shape = o.shape,
			transparency = o.transparency,
			reflectance = o.reflectance,
			collide = o.collide,
			shadow = o.shadow,
			class = o.class,
		})
	end

	local prompts = {}
	local function prompt(part, station, actionText, objectText, ownerOnly)
		local pr = PartUtil.prompt(part, actionText, objectText, { distance = 10, name = "StationPrompt" })
		pr:SetAttribute("Station", station)
		pr:SetAttribute("OwnerUserId", opts.ownerUserId)
		if ownerOnly then
			CollectionService:AddTag(pr, HouseBuilder.OwnerPromptTag)
		end
		prompts[station] = pr
		return pr
	end

	-- FLOOR ------------------------------------------------------------
	local floor = p("Floor", v3(size + 2, 1, size + 2), v3(0, -0.5, 0), style.floor, { material = style.floorMat })
	floor:SetAttribute("IsFloor", true)
	p("Step", v3(HouseSystem.DoorWidth + 1, 0.5, 2.5), v3(0, -0.75, h + 2.2), style.trim, { material = "Concrete" })
	p("Foundation", v3(size + 2.6, 0.8, size + 2.6), v3(0, -0.6, 0), rgb(150, 146, 140), { material = "Concrete", shadow = false })

	-- terrain under the house + a paved walkway out to the street
	local plotHalf = Config.PlotSize / 2
	Environment.paint(plotCFrame, v3(Config.PlotSize - 4, 4, Config.PlotSize - 4), Enum.Material.Grass)
	Environment.paint(plotCFrame, v3(size + 6, 4, size + 6), Enum.Material.Ground)
	local walkStart, walkEnd = h + 3.5, plotHalf + 2
	if walkEnd > walkStart then
		local walkMid, walkLen = (walkStart + walkEnd) / 2, walkEnd - walkStart
		p("Walkway", v3(5, 0.25, walkLen), v3(0, -0.87, walkMid), rgb(200, 192, 180), { material = "Pavement", shadow = false })
		Environment.paint(plotCFrame * CFrame.new(0, 0, walkMid), v3(6, 4, walkLen), Enum.Material.Pavement)
	end

	-- WALLS (door gap, framed windows, interior lining + trim) ------------
	-- Each wall is built from segments around its openings. Every segment
	-- gets a thin interior lining (so outside can be brick while inside is
	-- cosy plaster), a baseboard and crown moulding.
	local function wall(alongX, fixed, length, openings)
		local outward = fixed > 0 and 1 or -1
		local cursor = -length / 2
		local function at(c, y, depth)
			return alongX and v3(c, y, fixed + depth * outward) or v3(fixed + depth * outward, y, c)
		end
		local function span(width, height, depth)
			return alongX and v3(width, height, depth) or v3(depth, height, width)
		end
		local function seg(c0, c1, y0, y1)
			if c1 - c0 < 0.05 or y1 - y0 < 0.05 then
				return
			end
			local mid, midY, width = (c0 + c1) / 2, (y0 + y1) / 2, c1 - c0
			p("Wall", span(width, y1 - y0, 1), at(mid, midY, 0), style.wall, { material = style.wallMat })
			-- interior lining (inside face of the wall)
			local liningBottom = math.max(y0, 0)
			if y1 - liningBottom > 0.1 then
				p("WallLining", span(width, y1 - liningBottom, 0.12), at(mid, (liningBottom + y1) / 2, -0.56), style.inside, { material = "Plaster", collide = false, shadow = false })
			end
			if y0 <= 0 and y1 > 1 then
				p("Baseboard", span(width, 0.7, 0.24), at(mid, 0.35, -0.68), style.base, { material = "Wood", collide = false, shadow = false })
			end
			if y1 >= H - 0.01 then
				p("Crown", span(width, 0.45, 0.3), at(mid, H - 0.3, -0.7), style.base, { material = "Wood", collide = false, shadow = false })
			end
		end
		for _, opening in ipairs(openings) do
			local c0, c1 = opening.center - opening.width / 2, opening.center + opening.width / 2
			seg(cursor, c0, -1, H)
			seg(c0, c1, opening.top, H)
			seg(c0, c1, -1, opening.bottom)
			if opening.glass then
				local midY = (opening.bottom + opening.top) / 2
				local glass = p("Window", span(opening.width, opening.top - opening.bottom, 0.25), at(opening.center, midY, 0), rgb(176, 214, 245), { material = "Glass", transparency = 0.55, shadow = false })
				CollectionService:AddTag(glass, Environment.NightWindowTag)
				-- frame, sill and a cross mullion on the outside
				local frameColor = style.trim
				p("WindowFrame", span(opening.width + 0.8, 0.4, 0.5), at(opening.center, opening.top + 0.2, 0.3), frameColor, { collide = false, shadow = false })
				p("WindowSill", span(opening.width + 1.4, 0.35, 1), at(opening.center, opening.bottom - 0.15, 0.5), frameColor, { collide = false })
				p("WindowFrame", span(0.4, opening.top - opening.bottom, 0.5), at(c0 - 0.2, midY, 0.3), frameColor, { collide = false, shadow = false })
				p("WindowFrame", span(0.4, opening.top - opening.bottom, 0.5), at(c1 + 0.2, midY, 0.3), frameColor, { collide = false, shadow = false })
				p("Mullion", span(0.25, opening.top - opening.bottom, 0.35), at(opening.center, midY, 0.1), frameColor, { collide = false, shadow = false })
				p("Mullion", span(opening.width, 0.25, 0.35), at(opening.center, midY, 0.1), frameColor, { collide = false, shadow = false })
				if style.flowerBoxes then
					p("FlowerBox", span(opening.width + 0.6, 0.9, 1.2), at(opening.center, opening.bottom - 0.9, 0.9), style.trim, { material = "Wood", collide = false })
					local count = math.max(2, math.floor(opening.width / 1.5))
					for i = 1, count do
						local c = c0 + (i - 0.5) * opening.width / count
						p("BoxFlower", v3(0.8, 0.8, 0.8), at(c, opening.bottom - 0.2, 0.9), i % 2 == 0 and rgb(255, 110, 180) or rgb(255, 220, 80), { shape = "Ball", collide = false, shadow = false })
					end
				end
			end
			cursor = c1
		end
		seg(cursor, length / 2, -1, H)
	end

	local sideWindows
	if size >= 36 then
		sideWindows = {
			{ center = -size / 4, width = 6, bottom = 3.5, top = 8.5, glass = true },
			{ center = size / 4, width = 6, bottom = 3.5, top = 8.5, glass = true },
		}
	else
		sideWindows = { { center = 0, width = 6, bottom = 3.5, top = 8.5, glass = true } }
	end
	local frontOpenings = { { center = 0, width = HouseSystem.DoorWidth, bottom = 0, top = 9 } }
	if size >= 36 then
		local x = HouseSystem.DoorWidth / 2 + 5
		frontOpenings = {
			{ center = -x, width = 4.5, bottom = 3.5, top = 8, glass = true },
			{ center = 0, width = HouseSystem.DoorWidth, bottom = 0, top = 9 },
			{ center = x, width = 4.5, bottom = 3.5, top = 8, glass = true },
		}
	end
	wall(true, h + 0.5, size + 2, frontOpenings) -- front
	wall(true, -h - 0.5, size + 2, {}) -- back
	wall(false, -h - 0.5, size, sideWindows) -- left
	wall(false, h + 0.5, size, sideWindows) -- right

	-- corner posts
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			p("Post", v3(1.4, H + 1.4, 1.4), v3(sx * (h + 0.5), (H - 1) / 2 + 0.2, sz * (h + 0.5)), style.trim, { material = tier >= 5 and "Marble" or "Wood" })
		end
	end

	-- FRONT DOOR: frame, an open door panel, porch light, mat and plants
	local door = HouseSystem.DoorWidth
	p("DoorFrame", v3(door + 1.2, 0.6, 1.3), v3(0, 9.3, h + 0.5), style.trim)
	p("DoorJamb", v3(0.5, 9, 1.3), v3(-door / 2 - 0.25, 4.5, h + 0.5), style.trim, { collide = false })
	p("DoorJamb", v3(0.5, 9, 1.3), v3(door / 2 + 0.25, 4.5, h + 0.5), style.trim, { collide = false })
	local hinge = CFrame.new(-door / 2, 0, h + 1.1) * CFrame.Angles(0, rad(100), 0)
	p("Door", v3(door - 0.6, 8.6, 0.3), (hinge * CFrame.new((door - 0.6) / 2, 4.3, 0)).Position, style.door, { rot = CFrame.Angles(0, rad(100), 0), material = "Wood", collide = false })
	p("DoorKnob", v3(0.35, 0.35, 0.35), (hinge * CFrame.new(door - 1.4, 4.2, 0.25)).Position, GOLD, { shape = "Ball", collide = false, shadow = false })
	p("DoorMat", v3(4, 0.08, 2), v3(0, -0.46, h + 2.4), rgb(120, 84, 60), { material = "Carpet", collide = false, shadow = false })
	local lantern = p("PorchLantern", v3(0.8, 1.2, 0.8), v3(door / 2 + 1.4, 7.2, h + 1.4), style.base, { material = "Metal", collide = false })
	local bulb = p("PorchBulb", v3(0.55, 0.7, 0.55), v3(door / 2 + 1.4, 7.1, h + 1.4), rgb(255, 228, 170), { material = "Neon", collide = false, shadow = false })
	local porchLight = Instance.new("PointLight")
	porchLight.Range = 16
	porchLight.Brightness = 1.6
	porchLight.Color = rgb(255, 210, 150)
	porchLight.Shadows = false
	porchLight.Enabled = false
	porchLight.Parent = bulb
	CollectionService:AddTag(porchLight, Environment.NightLightTag)
	local _ = lantern
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * (door / 2 + 2.6)
		p("Planter", v3(1.6, 1.8, 1.8), v3(x, 0.4, h + 2.6), rgb(196, 110, 80), { shape = "Cylinder", rot = UP, material = "Brick" })
		p("PlanterLeaves", v3(2.2, 2.2, 2.2), v3(x, 2, h + 2.6), rgb(82, 168, 72), { shape = "Ball", material = "LeafyGrass", collide = false, shadow = false })
	end

	-- ROOF (no collisions so it never traps the camera; it fades out on the
	-- client while you are inside - see the RoofZone part below)
	local roofParts = {}
	local function roofPart(name, partSize, position, color, o)
		local part = p(name, partSize, position, color, o)
		table.insert(roofParts, part)
		return part
	end
	local eave = h + 3 -- half-width of the roof including the overhang
	if style.roofType == "gable" then
		local rise = eave * style.pitch
		local angle = math.atan2(rise, eave)
		local slope = math.sqrt(eave * eave + rise * rise) + 0.6
		for _, side in ipairs({ -1, 1 }) do
			-- the two roof planes, sloping down to the front and the back
			local plane = CFrame.new(0, H + rise / 2, side * eave / 2) * CFrame.Angles(side * angle, 0, 0) * CFrame.new(0, 0.45, 0)
			roofPart("RoofPlane", v3(size + 6, 0.9, slope), plane.Position, style.roof, { rot = plane - plane.Position, material = style.roofMat, collide = false })
			-- fascia board along each eave
			local fascia = plane * CFrame.new(0, -0.3, side * slope / 2)
			roofPart("Fascia", v3(size + 6.2, 0.7, 0.4), fascia.Position, style.trim, { rot = fascia - fascia.Position, collide = false, shadow = false })
		end
		-- gable triangles above the side walls (two wedges each)
		local wallHalf = h + 1
		local gableRise = rise * wallHalf / eave
		for _, sx in ipairs({ -1, 1 }) do
			local x = sx * (h + 0.5)
			roofPart("Gable", v3(1, gableRise, wallHalf), v3(x, H + gableRise / 2, wallHalf / 2), style.wall, { class = "WedgePart", rot = CFrame.Angles(0, math.pi, 0), material = style.wallMat, collide = false })
			roofPart("Gable", v3(1, gableRise, wallHalf), v3(x, H + gableRise / 2, -wallHalf / 2), style.wall, { class = "WedgePart", material = style.wallMat, collide = false })
			-- a little round attic window
			local attic = roofPart("AtticWindow", v3(0.4, 2.2, 2.2), v3(x + sx * 0.4, H + gableRise * 0.38, 0), rgb(176, 214, 245), { shape = "Cylinder", material = "Glass", collide = false, shadow = false })
			CollectionService:AddTag(attic, Environment.NightWindowTag)
			roofPart("AtticRim", v3(0.35, 2.8, 2.8), v3(x + sx * 0.3, H + gableRise * 0.38, 0), style.trim, { shape = "Cylinder", collide = false, shadow = false })
		end
		roofPart("RidgeCap", v3(size + 6.4, 0.6, 1.4), v3(0, H + rise + 0.45, 0), PartUtil.shade(style.roof, 0.8), { material = style.roofMat, collide = false })
		if style.chimney then
			local cx, cz = h * 0.45, -eave * 0.42
			local roofY = H + rise * (1 - math.abs(cz) / eave)
			roofPart("Chimney", v3(2.8, rise * 0.5 + 4, 2.8), v3(cx, roofY + 1, cz), rgb(170, 84, 64), { material = "Brick", collide = false })
			roofPart("ChimneyCap", v3(3.4, 0.5, 3.4), v3(cx, roofY + rise * 0.25 + 3.25, cz), rgb(90, 90, 96), { material = "Concrete", collide = false, shadow = false })
		end
	else
		-- flat modern roof with a parapet, accent light strip and rooftop bits
		roofPart("Roof", v3(size + 3, 1, size + 3), v3(0, H + 0.5, 0), style.roof, { material = style.roofMat, collide = false })
		local edge = size / 2 + 1.25
		for _, sz in ipairs({ -1, 1 }) do
			roofPart("Parapet", v3(size + 3, 1.8, 0.5), v3(0, H + 1.9, sz * edge), style.wall, { material = style.wallMat, collide = false })
			roofPart("Parapet", v3(0.5, 1.8, size + 3), v3(sz * edge, H + 1.9, 0), style.wall, { material = style.wallMat, collide = false })
			roofPart("RoofStrip", v3(size + 3.2, 0.25, 0.6), v3(0, H + 2.9, sz * edge), style.accent, { material = "Neon", collide = false, shadow = false })
			roofPart("RoofStrip", v3(0.6, 0.25, size + 3.2), v3(sz * edge, H + 2.9, 0), style.accent, { material = "Neon", collide = false, shadow = false })
		end
		if tier == 4 then
			local sky = roofPart("Skylight", v3(size * 0.35, 0.4, size * 0.35), v3(0, H + 1.1, 0), rgb(160, 200, 240), { material = "Glass", collide = false, shadow = false })
			sky.Transparency = 0.4
		else
			roofPart("ACUnit", v3(4, 2.6, 3), v3(-size * 0.25, H + 2.3, -size * 0.2), rgb(190, 192, 198), { material = "Metal", collide = false })
			roofPart("ACFan", v3(0.3, 2.2, 2.2), v3(-size * 0.25, H + 3.65, -size * 0.2), rgb(70, 72, 80), { shape = "Cylinder", rot = UP, material = "Metal", collide = false, shadow = false })
		end
	end
	if tier >= 5 then
		-- mansion pillars + a glowing gold roof edge
		for _, x in ipairs({ -6.5, 6.5 }) do
			p("Pillar", v3(H, 1.6, 1.6), v3(x, H / 2 - 0.5, h + 2.6), WHITE, { shape = "Cylinder", rot = UP, material = "Marble" })
			p("PillarCap", v3(2.4, 0.6, 2.4), v3(x, H - 0.4, h + 2.6), GOLD, { material = "Glass", reflectance = 0.3 })
			p("PillarBase", v3(2.4, 0.6, 2.4), v3(x, 0.3, h + 2.6), WHITE, { material = "Marble" })
		end
		p("Portico", v3(16, 0.8, 4.5), v3(0, H - 0.1, h + 2.6), WHITE, { material = "Marble", collide = false })
		roofPart("RoofGlow", v3(size + 6.3, 0.25, 0.4), v3(0, H + 0.1, eave), GOLD, { material = "Neon", collide = false, shadow = false })
		roofPart("RoofGlow", v3(size + 6.3, 0.25, 0.4), v3(0, H + 0.1, -eave), GOLD, { material = "Neon", collide = false, shadow = false })
	end
	local roofModel = Instance.new("Model")
	roofModel.Name = "Roof"
	for _, part in ipairs(roofParts) do
		part.Parent = roofModel
	end
	local zone = p("RoofZone", v3(size + 1, H + 2, size + 1), v3(0, H / 2, 0), WHITE, { transparency = 1, collide = false, shadow = false })
	zone.Parent = roofModel
	CollectionService:AddTag(zone, HouseBuilder.RoofZoneTag)
	roofModel.Parent = model

	-- Sign over the door.
	local sign = p("Sign", v3(math.min(16, size * 0.5), 2.2, 0.4), v3(0, 10.9, h + 1.1), DARK, { collide = false })
	PartUtil.label(sign, (opts.ownerName or "?") .. "'s " .. AgeSystem.HouseNames[tier], { face = Enum.NormalId.Back, color = style.accent })
	-- Ceiling light.
	local lamp = p("CeilingLight", v3(0.5, 3, 3), v3(0, H - 0.4, 0), rgb(255, 244, 214), { shape = "Cylinder", rot = UP, material = "Neon", collide = false, shadow = false })
	local light = Instance.new("PointLight")
	light.Range = math.min(60, size + 8)
	light.Brightness = 1.1
	light.Color = rgb(255, 244, 214)
	light.Shadows = false
	light.Parent = lamp

	----------------------------------------------------------------------
	-- STATIONS
	----------------------------------------------------------------------
	local accent = style.accent

	-- BED
	do
		local c = stations.Bed.center
		p("BedFrame", v3(6, 1, 8), v3(c.X, 0.5, c.Z), style.trim, { material = "Wood" })
		local mattress = p("Mattress", v3(5.6, 0.8, 7.6), v3(c.X, 1.4, c.Z), WHITE, { material = "Fabric" })
		p("Pillow", v3(4, 0.6, 1.6), v3(c.X, 2.05, c.Z - 2.9), rgb(250, 250, 255), { material = "Fabric", collide = false })
		p("Blanket", v3(5.7, 0.3, 4.4), v3(c.X, 1.92, c.Z + 1.5), accent, { material = "Fabric", collide = false })
		p("Headboard", v3(6, 3.6, 0.5), v3(c.X, 1.8, c.Z - 3.75), style.trim, { material = "Wood" })
		prompt(mattress, "Bed", "Bedtime", "Brady's Bed", true)
	end

	-- WARDROBE
	do
		local c = stations.Wardrobe.center
		local cabinet = p("Wardrobe", v3(4, 7.4, 2.4), v3(c.X, 3.7, c.Z - 0.2), rgb(120, 84, 56), { material = "Wood" })
		p("DoorL", v3(1.9, 6.6, 0.2), v3(c.X - 0.98, 3.7, c.Z + 1.05), rgb(150, 108, 72), { material = "Wood", collide = false })
		p("DoorR", v3(1.9, 6.6, 0.2), v3(c.X + 0.98, 3.7, c.Z + 1.05), rgb(150, 108, 72), { material = "Wood", collide = false })
		p("KnobL", v3(0.3, 0.3, 0.3), v3(c.X - 0.25, 3.7, c.Z + 1.25), GOLD, { shape = "Ball", collide = false })
		p("KnobR", v3(0.3, 0.3, 0.3), v3(c.X + 0.25, 3.7, c.Z + 1.25), GOLD, { shape = "Ball", collide = false })
		prompt(cabinet, "Wardrobe", "Open Wardrobe", "Brady's Closet", true)
	end

	-- MIRROR
	do
		local c = stations.Mirror.center
		p("MirrorFrame", v3(4, 7.2, 0.5), v3(c.X, 3.7, c.Z - 0.35), accent)
		local glass = p("MirrorGlass", v3(3.4, 6.6, 0.2), v3(c.X, 3.7, c.Z - 0.05), rgb(200, 230, 255), { material = "Glass", reflectance = 0.65, collide = false })
		prompt(glass, "Mirror", "Use Mirror", "Fit Check", true)
	end

	-- CLOTHING DISPLAY: shows off the three rarest pieces the player owns.
	do
		local c = stations.Display.center
		local back = p("DisplayBack", v3(5, 6, 0.4), v3(c.X, 3, c.Z - 1.4), DARK)
		for i = 1, 3 do
			local x = c.X - 1.6 + (i - 1) * 1.6
			p("Pedestal", v3(1.2, 1.4, 1.2), v3(x, 0.7, c.Z), WHITE, { material = "Marble" })
			local item = opts.showcase and opts.showcase[i]
			if item then
				local color = ClothingSystem.rarityColor(item.rarity)
				local piece = p("Showcase", v3(0.9, 1.1, 0.5), v3(x, 2.3, c.Z), ClothingSystem.swatch(item), { material = "Fabric", collide = false })
				p("ShowcaseGlow", v3(1.3, 0.12, 1.3), v3(x, 1.46, c.Z), color, { material = "Neon", collide = false, shadow = false })
				local gui = Instance.new("BillboardGui")
				gui.Size = UDim2.fromScale(3.2, 0.9)
				gui.StudsOffsetWorldSpace = v3(0, 1.3, 0)
				gui.MaxDistance = 40
				gui.LightInfluence = 0
				local label = Instance.new("TextLabel")
				label.BackgroundTransparency = 1
				label.Size = UDim2.fromScale(1, 1)
				label.Font = Enum.Font.FredokaOne
				label.TextScaled = true
				label.TextColor3 = color
				label.TextStrokeTransparency = 0.3
				label.Text = item.name
				label.Parent = gui
				gui.Parent = piece
			end
		end
		prompt(back, "Display", "View Collection", "Clothing Display", false)
	end

	-- FOOD STATION
	do
		local c = stations.Food.center
		local counter = p("Counter", v3(3, 3, 4), v3(c.X, 1.5, c.Z - 1), rgb(230, 230, 235), { material = "Marble" })
		p("CounterTop", v3(3.2, 0.3, 4.2), v3(c.X, 3.1, c.Z - 1), accent, { collide = false })
		p("Fridge", v3(2.8, 6.4, 2), v3(c.X + 0.1, 3.2, c.Z + 2), rgb(210, 215, 222), { material = "Metal" })
		p("FridgeHandle", v3(0.2, 2, 0.2), v3(c.X - 1.4, 3.6, c.Z + 1.4), DARK, { collide = false })
		p("Bowl", v3(0.6, 1.2, 1.2), v3(c.X - 0.3, 3.55, c.Z - 1.4), rgb(255, 120, 90), { shape = "Cylinder", rot = UP, collide = false })
		p("Cereal", v3(0.2, 1, 1), v3(c.X - 0.3, 3.8, c.Z - 1.4), rgb(240, 220, 150), { shape = "Cylinder", rot = UP, collide = false })
		prompt(counter, "Food", "Feed Brady", "Kitchen", true)
	end

	-- TROPHY SHELF
	do
		local c = stations.Trophy.center
		local trophies = opts.trophies or {}
		local shelf = p("TrophyShelf", v3(1.4, 0.3, 4), v3(c.X + 0.2, 4, c.Z), style.trim, { material = "Wood" })
		p("TrophyShelf2", v3(1.4, 0.3, 4), v3(c.X + 0.2, 6.2, c.Z), style.trim, { material = "Wood", collide = false })
		local cups = math.clamp(math.floor((trophies.achievements or 0) / 3), 0, 4)
		for i = 1, cups do
			local z = c.Z - 1.5 + (i - 1) * 1
			p("Cup", v3(0.7, 0.6, 0.6), v3(c.X + 0.2, 4.7, z), GOLD, { shape = "Cylinder", rot = UP, material = "Glass", reflectance = 0.35, collide = false })
			p("CupBase", v3(0.5, 0.2, 0.5), v3(c.X + 0.2, 4.25, z), DARK, { collide = false })
		end
		local wins = math.clamp(trophies.wins or 0, 0, 4)
		for i = 1, wins do
			local z = c.Z - 1.5 + (i - 1) * 1
			p("Star", v3(0.6, 0.6, 0.2), v3(c.X + 0.2, 6.9, z), rgb(255, 110, 225), { material = "Neon", rot = CFrame.Angles(0, rad(90), rad(45)), collide = false })
		end
		local plaque = p("Plaque", v3(0.2, 1.3, 3.6), v3(c.X + 0.75, 2.4, c.Z), DARK, { collide = false })
		PartUtil.label(plaque, "🏆 " .. (trophies.achievements or 0) .. " achievements\n⭐ " .. (trophies.wins or 0) .. " show wins", { face = Enum.NormalId.Left, color = GOLD })
		prompt(shelf, "Trophy", "View Trophies", "Trophy Shelf", false)
	end

	-- FASHION DISPLAY PODIUM
	do
		local c = stations.Podium.center
		local podium = p("Podium", v3(1, 6, 6), v3(c.X, 0.5, c.Z), WHITE, { shape = "Cylinder", rot = UP, material = "Marble" })
		p("PodiumRing", v3(0.2, 6.3, 6.3), v3(c.X, 0.12, c.Z), accent, { shape = "Cylinder", rot = UP, material = "Neon", collide = false, shadow = false })
		p("BackdropA", v3(6, 8, 0.3), v3(c.X, 4, h - 0.3), accent, { material = "Fabric", collide = false })
		p("BackdropB", v3(0.3, 8, 6), v3(h - 0.3, 4, c.Z), accent, { material = "Fabric", collide = false })
		local spot = p("SpotHolder", v3(0.8, 0.8, 0.8), v3(c.X - 2.5, H - 1.2, c.Z - 2.5), DARK, { collide = false })
		local spotLight = Instance.new("SpotLight")
		spotLight.Face = Enum.NormalId.Bottom
		spotLight.Angle = 50
		spotLight.Range = 26
		spotLight.Brightness = 3
		spotLight.Color = rgb(255, 240, 220)
		spotLight.Shadows = false
		spotLight.Parent = spot
		prompt(podium, "Podium", "Strike a Pose", "Fashion Display", true)
	end

	-- BATHROOM: shower
	local showerEmitter
	do
		local c = stations.Shower.center
		local tray = p("ShowerTray", v3(5, 0.3, 5), v3(c.X, 0.15, c.Z), rgb(225, 235, 240), { material = "Marble" })
		p("ShowerGlassA", v3(0.2, 7.5, 5), v3(c.X + 2.4, 3.75, c.Z), rgb(190, 230, 255), { material = "Glass", transparency = 0.65, collide = false, shadow = false })
		p("ShowerPipe", v3(0.3, 8, 0.3), v3(c.X - 2.1, 4, c.Z + 2.1), rgb(200, 200, 205), { material = "Metal", collide = false })
		local head = p("ShowerHead", v3(0.3, 1.4, 1.4), v3(c.X - 1, 7.8, c.Z + 1), rgb(200, 200, 205), { shape = "Cylinder", rot = UP, material = "Metal", collide = false })
		p("Duck", v3(0.6, 0.6, 0.6), v3(c.X + 1.6, 0.6, c.Z + 1.6), rgb(255, 220, 60), { shape = "Ball", collide = false })
		showerEmitter = Instance.new("ParticleEmitter")
		showerEmitter.Name = "Water"
		showerEmitter.Enabled = false
		showerEmitter.Rate = 60
		showerEmitter.Lifetime = NumberRange.new(0.5, 0.7)
		showerEmitter.Speed = NumberRange.new(12, 15)
		showerEmitter.SpreadAngle = Vector2.new(14, 14)
		showerEmitter.EmissionDirection = Enum.NormalId.Left -- the head is a Cylinder stood upright
		showerEmitter.Color = ColorSequence.new(rgb(160, 220, 255))
		showerEmitter.Size = NumberSequence.new(0.25, 0.1)
		showerEmitter.Transparency = NumberSequence.new(0.3, 0.8)
		showerEmitter.Parent = head
		prompt(tray, "Shower", "Shower Brady", "Bathroom", true)
	end

	-- BATHROOM: sink (brush hair)
	do
		local c = stations.Sink.center
		local sink = p("SinkCabinet", v3(2.4, 3, 3), v3(c.X - 0.2, 1.5, c.Z), WHITE, { material = "Marble" })
		p("Basin", v3(0.4, 1.8, 1.8), v3(c.X - 0.1, 3.05, c.Z), rgb(190, 225, 245), { shape = "Cylinder", rot = UP, collide = false })
		p("Faucet", v3(0.25, 0.8, 0.25), v3(c.X - 1, 3.5, c.Z), rgb(200, 200, 205), { material = "Metal", collide = false })
		p("SinkMirror", v3(0.2, 2.6, 2.4), v3(c.X - 1.3, 6, c.Z), rgb(200, 230, 255), { material = "Glass", reflectance = 0.6, collide = false })
		p("Brush", v3(0.25, 0.25, 1), v3(c.X + 0.5, 3.15, c.Z + 0.9), rgb(255, 110, 225), { collide = false })
		prompt(sink, "Sink", "Brush Hair", "Sink", true)
	end

	-- SHOE MAT (clean shoes)
	do
		local c = stations.ShoeMat.center
		local mat = p("ShoeMat", v3(3, 0.15, 2), v3(c.X, 0.08, c.Z), rgb(90, 70, 50), { material = "Fabric", collide = false })
		p("ShoeBrush", v3(0.9, 0.4, 0.4), v3(c.X + 0.8, 0.35, c.Z), rgb(240, 200, 80), { collide = false })
		prompt(mat, "ShoeMat", "Clean Shoes", "Shoe Mat", true)
	end

	local furniture = Instance.new("Folder")
	furniture.Name = "Furniture"
	furniture.Parent = model

	model.Parent = parent
	return model, {
		size = size,
		tier = tier,
		origin = origin,
		height = H,
		prompts = prompts,
		showerEmitter = showerEmitter,
		furniture = furniture,
	}
end

return HouseBuilder
