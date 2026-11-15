--[[
	MapBuilder
	Builds the whole world out of parts when the server starts: the central
	plaza, clothing store, fashion runway, mini-game arcade + obby, park, food
	court, the street of player plots and the secret Goo Cave.

	Building the map in code keeps the project 100% text (no binary place
	file to merge) and guarantees gameplay positions - runway path, obby
	checkpoints, hidden spots - always match the scenery. If you would rather
	hand-edit the map in Studio: press Play, copy Workspace.Map out of the
	running game, paste it into Edit mode, and delete the MapBuilder call in
	Main (keep the MapInfo positions it returns).

	build() returns a MapInfo table the services use for positions.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage.Modules
local Config = require(Modules.Config)
local MinigameSystem = require(Modules.MinigameSystem)
local ShopSystem = require(Modules.ShopSystem)
local PartUtil = require(Modules.Builders.PartUtil)

local MapBuilder = {}

local rgb = Color3.fromRGB
local v3 = Vector3.new
local rad = math.rad
local UP = PartUtil.UP

local GOO = rgb(126, 232, 74)
local WHITE = rgb(245, 245, 245)
local DARK = rgb(34, 34, 40)
local GOLD = rgb(255, 205, 60)
local PATH = rgb(214, 202, 178)
local WOOD = rgb(140, 100, 64)

-- World position / facing of plot number `index` (1-based).
-- Plots line both sides of the street that runs south from the plaza.
function MapBuilder.plotCFrame(index)
	local row = math.floor((index - 1) / 2)
	local left = (index - 1) % 2 == 0
	local x = left and -50 or 50
	local z = 110 + row * 80
	-- Local +Z of a plot (its front door) always points at the street.
	return CFrame.new(x, 0, z) * CFrame.Angles(0, rad(left and 90 or -90), 0)
end

function MapBuilder.build()
	local map = Instance.new("Folder")
	map.Name = "Map"

	local function B(name, size, position, color, o)
		o = o or {}
		local cframe = typeof(position) == "CFrame" and position or CFrame.new(position)
		if o.rot then
			cframe = cframe * o.rot
		end
		return PartUtil.block(o.parent or map, {
			name = name,
			size = size,
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

	-- A prompt that simply opens a UI panel on the client (see WorldClient).
	local function uiPrompt(part, action, object, panel, arg)
		local prompt = PartUtil.prompt(part, action, object, { distance = 11, name = "PanelPrompt" })
		prompt:SetAttribute("Panel", panel)
		if arg then
			prompt:SetAttribute("PanelArg", arg)
		end
		return prompt
	end

	local function sign(text, size, cframe, color, textColor, face)
		local board = B("Sign", size, cframe, color or DARK, { collide = false })
		PartUtil.label(board, text, { color = textColor or WHITE, face = face or Enum.NormalId.Back })
		return board
	end

	local function tree(x, z, scale)
		scale = scale or 1
		B("Trunk", v3(7 * scale, 1.6 * scale, 1.6 * scale), v3(x, 3.5 * scale, z), rgb(110, 78, 50), { shape = "Cylinder", rot = UP, material = "Wood" })
		B("Leaves", v3(8, 8, 8) * scale, v3(x, 9 * scale, z), rgb(70, 170, 80), { shape = "Ball", material = "Grass", collide = false })
		B("Leaves", v3(5.5, 5.5, 5.5) * scale, v3(x + 2.4 * scale, 7 * scale, z + 1.5 * scale), rgb(90, 190, 90), { shape = "Ball", material = "Grass", collide = false })
		B("Leaves", v3(5, 5, 5) * scale, v3(x - 2.2 * scale, 7.4 * scale, z - 1.6 * scale), rgb(60, 150, 70), { shape = "Ball", material = "Grass", collide = false })
	end

	local function bench(x, z, yaw)
		local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, rad(yaw), 0)
		B("BenchSeat", v3(6, 0.4, 1.8), cf * CFrame.new(0, 1.5, 0), WOOD, { material = "Wood" })
		B("BenchBack", v3(6, 1.6, 0.4), cf * CFrame.new(0, 2.5, 0.8), WOOD, { material = "Wood" })
		B("BenchLeg", v3(0.4, 1.4, 1.6), cf * CFrame.new(-2.5, 0.7, 0), DARK)
		B("BenchLeg", v3(0.4, 1.4, 1.6), cf * CFrame.new(2.5, 0.7, 0), DARK)
	end

	local function lampPost(x, z)
		B("LampPost", v3(11, 0.5, 0.5), v3(x, 5.5, z), DARK, { shape = "Cylinder", rot = UP, material = "Metal" })
		B("LampBulb", v3(1.4, 1.4, 1.4), v3(x, 11.4, z), rgb(255, 244, 200), { shape = "Ball", material = "Neon", collide = false, shadow = false })
	end

	----------------------------------------------------------------------
	-- GROUND + LIGHTING
	----------------------------------------------------------------------
	B("Ground", v3(700, 4, 960), v3(0, -2, 150), rgb(104, 196, 96), { material = "Grass" })

	Lighting.ClockTime = 14
	Lighting.Brightness = 2.4
	Lighting.Ambient = rgb(96, 96, 108)
	Lighting.OutdoorAmbient = rgb(150, 150, 160)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.26
	atmosphere.Haze = 0.8
	atmosphere.Color = rgb(210, 230, 255)
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.25
	bloom.Size = 18
	bloom.Threshold = 1.7
	bloom.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Saturation = 0.14
	grade.Contrast = 0.05
	grade.Parent = Lighting

	----------------------------------------------------------------------
	-- CENTRAL PLAZA
	----------------------------------------------------------------------
	B("Plaza", v3(0.5, 116, 116), v3(0, 0.1, 0), rgb(232, 222, 200), { shape = "Cylinder", rot = UP, material = "Concrete" })
	B("PlazaRing", v3(0.55, 122, 122), v3(0, 0.05, 0), GOO, { shape = "Cylinder", rot = UP, collide = false })
	-- Goo fountain
	B("FountainBasin", v3(2.4, 24, 24), v3(0, 1.2, 0), rgb(200, 200, 208), { shape = "Cylinder", rot = UP, material = "Marble" })
	B("FountainGoo", v3(0.5, 21, 21), v3(0, 2.3, 0), GOO, { shape = "Cylinder", rot = UP, material = "Neon", collide = false, shadow = false })
	B("FountainPillar", v3(9, 3.4, 3.4), v3(0, 5.5, 0), rgb(200, 200, 208), { shape = "Cylinder", rot = UP, material = "Marble" })
	local fountainTop = B("FountainTop", v3(5, 5, 5), v3(0, 11.5, 0), GOO, { shape = "Ball", material = "Neon", collide = false })
	local spray = Instance.new("ParticleEmitter")
	spray.Rate = 14
	spray.Lifetime = NumberRange.new(1, 1.5)
	spray.Speed = NumberRange.new(6, 9)
	spray.SpreadAngle = Vector2.new(40, 40)
	spray.Acceleration = v3(0, -18, 0)
	spray.Color = ColorSequence.new(GOO)
	spray.Size = NumberSequence.new(0.7, 0.2)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = fountainTop

	-- Welcome arch on the south side (towards the houses)
	B("ArchL", v3(16, 2, 2), v3(-13, 8, 52), GOO, { shape = "Cylinder", rot = UP })
	B("ArchR", v3(16, 2, 2), v3(13, 8, 52), GOO, { shape = "Cylinder", rot = UP })
	sign("RAISE BRADY GOO", v3(30, 5, 1.2), CFrame.new(0, 18, 52), DARK, GOO, Enum.NormalId.Front)
	sign("RAISE BRADY GOO", v3(30, 5, 1.2), CFrame.new(0, 18, 52.1), DARK, GOO, Enum.NormalId.Back)

	-- Spawn pads
	for i = 0, 3 do
		local angle = rad(45 + i * 90)
		local spawnPad = Instance.new("SpawnLocation")
		spawnPad.Name = "Spawn"
		spawnPad.Size = v3(8, 0.6, 8)
		spawnPad.Anchored = true
		spawnPad.Neutral = true
		spawnPad.Duration = 0
		spawnPad.Color = GOLD
		spawnPad.Material = Enum.Material.Neon
		spawnPad.Transparency = 0.4
		spawnPad.TopSurface = Enum.SurfaceType.Smooth
		spawnPad.CFrame = CFrame.new(math.cos(angle) * 32, 0.5, math.sin(angle) * 32)
		spawnPad.Parent = map
	end
	for i = 0, 7 do
		local angle = rad(22.5 + i * 45)
		if i % 2 == 0 then
			bench(math.cos(angle) * 46, math.sin(angle) * 46, math.deg(math.atan2(math.cos(angle), math.sin(angle))) + 180)
		else
			lampPost(math.cos(angle) * 52, math.sin(angle) * 52)
		end
	end

	-- Paths to every area
	B("PathNorth", v3(16, 0.3, 50), v3(0, 0.15, -78), PATH, { material = "Concrete" })
	B("PathEast", v3(46, 0.3, 16), v3(77, 0.15, 0), PATH, { material = "Concrete" })
	B("PathWest", v3(50, 0.3, 16), v3(-80, 0.15, 0), PATH, { material = "Concrete" })
	B("PathNE", v3(14, 0.3, 46), CFrame.new(57, 0.15, -57) * CFrame.Angles(0, rad(-45), 0), PATH, { material = "Concrete" })
	B("PathNW", v3(14, 0.3, 46), CFrame.new(-57, 0.15, -57) * CFrame.Angles(0, rad(45), 0), PATH, { material = "Concrete" })

	local function directionSign(text, x, z, yaw)
		local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, rad(yaw), 0)
		B("SignPost", v3(0.6, 6, 0.6), cf * CFrame.new(0, 3, 0), WOOD, { material = "Wood" })
		sign(text, v3(9, 2.2, 0.4), cf * CFrame.new(0, 6.6, 0), DARK, GOLD, Enum.NormalId.Front)
		sign(text, v3(9, 2.2, 0.4), cf * CFrame.new(0, 6.6, 0.05), DARK, GOLD, Enum.NormalId.Back)
	end
	directionSign("👕 CLOTHING STORE", 12, -56, 0)
	directionSign("🌟 FASHION RUNWAY", 56, -12, 90)
	directionSign("🎮 MINI-GAMES", -56, 12, 90)
	directionSign("🏠 HOUSES", -12, 56, 0)
	directionSign("🌳 PARK", 46, -34, -45)
	directionSign("🍔 FOOD COURT", -46, -34, 45)

	----------------------------------------------------------------------
	-- CLOTHING STORE (north)
	----------------------------------------------------------------------
	local store = Instance.new("Folder")
	store.Name = "Store"
	store.Parent = map
	local so = { parent = store }
	B("StoreFloor", v3(60, 0.6, 44), v3(0, 0.3, -126), rgb(236, 232, 224), { parent = store, material = "Marble" })
	B("StoreBack", v3(60, 20, 1.5), v3(0, 10, -147.2), rgb(40, 40, 48), so)
	B("StoreWallL", v3(1.5, 20, 44), v3(-29.2, 10, -126), rgb(40, 40, 48), so)
	B("StoreWallR", v3(1.5, 20, 44), v3(29.2, 10, -126), rgb(40, 40, 48), so)
	local storeRoof = B("StoreRoof", v3(64, 1.5, 48), v3(0, 20.7, -126), rgb(232, 66, 78), { parent = store, collide = false })
	CollectionService:AddTag(storeRoof, "HouseRoof")
	sign("GOO THRIFT & ARCHIVE", v3(44, 6, 1), CFrame.new(0, 25, -103.5), DARK, rgb(232, 66, 78))
	B("StoreStripe", v3(60, 0.8, 0.6), v3(0, 19.6, -104.2), GOO, { parent = store, material = "Neon", collide = false })

	-- Clothing racks along the left wall
	local rackColors = { rgb(232, 66, 78), rgb(72, 150, 255), GOO, GOLD, rgb(178, 92, 255), WHITE, DARK }
	for rack = 0, 2 do
		local z = -114 - rack * 11
		B("RackBar", v3(0.3, 0.3, 8), v3(-24, 6, z), rgb(200, 200, 205), { parent = store, material = "Metal", collide = false })
		B("RackPole", v3(0.3, 6, 0.3), v3(-24, 3, z - 4), rgb(200, 200, 205), { parent = store, material = "Metal" })
		B("RackPole", v3(0.3, 6, 0.3), v3(-24, 3, z + 4), rgb(200, 200, 205), { parent = store, material = "Metal" })
		for i = 0, 6 do
			B("Garment", v3(1.8, 3, 0.4), v3(-24, 4.3, z - 3.3 + i * 1.1), rackColors[(i + rack) % #rackColors + 1], { parent = store, material = "Fabric", collide = false })
		end
	end
	-- Counter + shopkeeper
	local counter = B("StoreCounter", v3(12, 3.4, 3), v3(0, 2.3, -140), rgb(120, 84, 56), { parent = store, material = "Wood" })
	B("Keeper", v3(2, 2.2, 1), v3(0, 5.3, -143), rgb(232, 66, 78), so)
	B("KeeperHead", v3(1.6, 1.6, 1.6), v3(0, 7.2, -143), rgb(255, 214, 92), so)
	B("KeeperShades", v3(1.5, 0.35, 0.2), v3(0, 7.35, -142.2), DARK, { parent = store, collide = false })
	uiPrompt(counter, "Shop", "Goo Thrift", "Shop", "Clothing")
	-- Hair chair
	local chair = B("SalonChair", v3(3, 1, 3), v3(-10, 1.6, -141), rgb(255, 110, 225), { parent = store, material = "Fabric" })
	B("SalonChairBack", v3(3, 3.4, 0.6), v3(-10, 3.6, -142.4), rgb(255, 110, 225), { parent = store, material = "Fabric" })
	sign("HAIR", v3(5, 1.8, 0.3), CFrame.new(-10, 8, -146.2), DARK, rgb(255, 110, 225))
	uiPrompt(chair, "Hairstyles", "Goo Salon", "Shop", "Hair")
	-- Furniture corner
	local sofa = B("DisplaySofa", v3(7, 1.6, 3), v3(13, 1.4, -141), rgb(90, 140, 220), { parent = store, material = "Fabric" })
	B("DisplaySofaBack", v3(7, 2.4, 0.8), v3(13, 2.8, -142.6), rgb(80, 124, 200), { parent = store, material = "Fabric" })
	sign("HOME", v3(5, 1.8, 0.3), CFrame.new(13, 8, -146.2), DARK, rgb(90, 190, 255))
	uiPrompt(sofa, "Furniture", "Room Shop", "Shop", "Furniture")
	-- Crate machines along the right wall
	for i, crate in ipairs(ShopSystem.Crates) do
		local z = -110 - (i - 1) * 9
		local machine = B("CrateMachine", v3(4, 8, 5), v3(25, 4.6, z), crate.color, so)
		B("CrateWindow", v3(0.3, 3.4, 3.6), v3(22.9, 6, z), rgb(200, 235, 255), { parent = store, material = "Glass", transparency = 0.4, collide = false })
		B("CrateGlow", v3(0.3, 0.6, 5), v3(22.9, 1.2, z), WHITE, { parent = store, material = "Neon", collide = false })
		sign(crate.icon .. " " .. crate.name, v3(0.3, 1.6, 5), CFrame.new(22.8, 9.4, z), DARK, crate.color, Enum.NormalId.Left)
		uiPrompt(machine, "Open Crates", crate.name, "Shop", "Crates")
	end
	-- Crates stacked behind the store: a staircase up to a hidden ledge
	for step = 1, 5 do
		B("BackCrate", v3(6, 4, 6), v3(-30 + step * 6, step * 4 - 2, -152), rgb(150 + step * 8, 110, 70), { parent = store, material = "WoodPlanks" })
	end
	B("SecretLedge", v3(22, 1, 7), v3(11, 20.5, -152.5), rgb(60, 60, 68), so)

	----------------------------------------------------------------------
	-- FASHION RUNWAY (east)
	----------------------------------------------------------------------
	local runwayFolder = Instance.new("Folder")
	runwayFolder.Name = "Runway"
	runwayFolder.Parent = map
	local ro = { parent = runwayFolder }
	B("Stage", v3(34, 3, 44), v3(165, 1.5, 0), rgb(40, 40, 48), ro)
	B("Catwalk", v3(50, 3, 10), v3(123, 1.5, 0), WHITE, { parent = runwayFolder, material = "Marble" })
	B("CatwalkGlowL", v3(50, 0.3, 0.5), v3(123, 3.1, -4.8), rgb(255, 110, 225), { parent = runwayFolder, material = "Neon", collide = false, shadow = false })
	B("CatwalkGlowR", v3(50, 0.3, 0.5), v3(123, 3.1, 4.8), rgb(255, 110, 225), { parent = runwayFolder, material = "Neon", collide = false, shadow = false })
	B("Backdrop", v3(1.5, 24, 44), v3(182.8, 12, 0), rgb(26, 26, 34), ro)
	sign("GOO FASHION WEEK", v3(0.5, 7, 34), CFrame.new(181.8, 17, 0), DARK, rgb(255, 110, 225), Enum.NormalId.Left)
	B("Curtain", v3(1, 14, 12), v3(181, 10, 0), rgb(150, 30, 60), { parent = runwayFolder, material = "Fabric", collide = false })
	-- Stairs up to the catwalk for curious players
	for step = 1, 3 do
		B("StageStep", v3(3, step, 10), v3(96.5 - (3 - step) * 3 + 3, step / 2, 0), rgb(200, 200, 208), ro)
	end
	-- Light rig
	B("RigL", v3(0.8, 22, 0.8), v3(148, 11, -21), DARK, ro)
	B("RigR", v3(0.8, 22, 0.8), v3(148, 11, 21), DARK, ro)
	B("RigTop", v3(0.8, 0.8, 43), v3(148, 22, 0), DARK, ro)
	for _, z in ipairs({ -12, 0, 12 }) do
		local can = B("SpotCan", v3(1.6, 1.6, 1.6), v3(148, 21, z), rgb(60, 60, 70), { parent = runwayFolder, collide = false })
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Bottom
		spot.Angle = 60
		spot.Range = 40
		spot.Brightness = 2.5
		spot.Color = rgb(255, 220, 240)
		spot.Shadows = false
		spot.Parent = can
	end
	-- Audience seating on both sides
	for _, side in ipairs({ -1, 1 }) do
		for row = 0, 1 do
			for seat = 0, 5 do
				local x = 104 + seat * 7.5
				local z = side * (11 + row * 5)
				B("Seat", v3(5, 0.5, 2.4), v3(x, 1.4 + row * 1.2, z), rgb(232, 66, 78), { parent = runwayFolder, material = "Fabric" })
				B("SeatBase", v3(5, 1.2 + row * 1.2, 2.4), v3(x, (1.2 + row * 1.2) / 2, z), DARK, ro)
			end
		end
	end
	-- Sign-up kiosk (FashionServer connects to this prompt)
	B("KioskPost", v3(0.8, 5, 0.8), v3(92, 2.5, 14), DARK, ro)
	local kiosk = sign("🌟 ENTER SHOW", v3(8, 3, 0.6), CFrame.new(92, 6.4, 14) * CFrame.Angles(0, rad(90), 0), rgb(255, 110, 225), WHITE, Enum.NormalId.Front)
	local signup = PartUtil.prompt(kiosk, "Fashion Show", "Runway Sign-Up", { distance = 12, name = "RunwayPrompt" })

	local lineup, backstage = {}, {}
	for i = 1, 8 do
		local z = -15.75 + (i - 1) * 4.5
		lineup[i] = CFrame.lookAt(v3(160, 3, z), v3(100, 3, z))
		backstage[i] = CFrame.lookAt(v3(176, 3, z), v3(100, 3, z))
	end

	----------------------------------------------------------------------
	-- MINI-GAME ARCADE (west) + GOO OBBY
	----------------------------------------------------------------------
	local arcade = Instance.new("Folder")
	arcade.Name = "Arcade"
	arcade.Parent = map
	local ao = { parent = arcade }
	B("ArcadeFloor", v3(54, 0.6, 48), v3(-132, 0.3, 0), rgb(48, 40, 80), ao)
	for _, x in ipairs({ -157, -107 }) do
		for _, z in ipairs({ -22, 22 }) do
			B("ArcadePillar", v3(17, 2, 2), v3(x, 8.5, z), rgb(200, 50, 200), { parent = arcade, shape = "Cylinder", rot = UP })
		end
	end
	local arcadeRoof = B("ArcadeRoof", v3(58, 1.2, 52), v3(-132, 17.6, 0), rgb(34, 28, 60), { parent = arcade, collide = false })
	CollectionService:AddTag(arcadeRoof, "HouseRoof")
	sign("GOO ARCADE", v3(1, 5, 30), CFrame.new(-104.5, 21, 0), DARK, rgb(120, 255, 200), Enum.NormalId.Right)
	B("ArcadeNeon", v3(0.5, 0.5, 48), v3(-105.5, 17, 0), rgb(255, 110, 225), { parent = arcade, material = "Neon", collide = false, shadow = false })
	sign("+25% rewards here!", v3(0.6, 2, 16), CFrame.new(-104.8, 13, 0), DARK, GOLD, Enum.NormalId.Right)

	local machineColors = { rgb(232, 66, 78), rgb(72, 150, 255), GOLD, GOO, rgb(178, 92, 255) }
	local machineIndex = 0
	for _, def in ipairs(MinigameSystem.List) do
		if not def.world then
			machineIndex += 1
			local z = -18 + (machineIndex - 1) * 9
			local color = machineColors[(machineIndex - 1) % #machineColors + 1]
			local cabinet = B("ArcadeMachine", v3(4, 8, 5), v3(-153, 4.6, z), color, ao)
			B("ArcadeScreen", v3(0.2, 3, 3.8), v3(-150.9, 6.4, z), rgb(120, 255, 200), { parent = arcade, material = "Neon", collide = false })
			B("ArcadePanel", v3(1.6, 0.4, 4.4), v3(-150.4, 3.9, z), DARK, { parent = arcade, collide = false })
			sign(def.icon .. " " .. def.name, v3(0.3, 1.4, 5), CFrame.new(-150.8, 9.6, z), DARK, color, Enum.NormalId.Right)
			uiPrompt(cabinet, "Play", def.name, "Minigame", def.id)
		end
	end

	-- OBBY: floating platforms over a pool of goo, south-west of the arcade
	-- (well away from the food court and the houses).
	local obbyFolder = Instance.new("Folder")
	obbyFolder.Name = "Obby"
	obbyFolder.Parent = map
	local oo = { parent = obbyFolder }
	local function touchable(part)
		part.CanTouch = true
		return part
	end
	sign("🏃 GOO OBBY - step on START", v3(18, 3, 0.6), CFrame.new(-132, 8, 33), DARK, GOO, Enum.NormalId.Front)
	B("ObbyPostL", v3(0.8, 8, 0.8), v3(-140, 4, 33), DARK, oo)
	B("ObbyPostR", v3(0.8, 8, 0.8), v3(-124, 4, 33), DARK, oo)
	local obbyStart = touchable(B("ObbyStart", v3(10, 0.6, 8), v3(-132, 0.3, 42), GOO, { parent = obbyFolder, material = "Neon" }))
	local pool = touchable(B("GooPool", v3(76, 0.8, 96), v3(-156, 0.4, 96), rgb(96, 210, 60), { parent = obbyFolder, material = "Neon", transparency = 0.15 }))
	B("PoolRim", v3(80, 0.5, 100), v3(-156, 0.2, 96), rgb(60, 60, 68), { parent = obbyFolder, collide = false })

	-- Path: 6 platforms south, 5 west, 3 south. Each one a bit higher.
	local steps = {}
	local px, pz = -132, 42
	local function addSteps(count, dx, dz)
		for _ = 1, count do
			px += dx
			pz += dz
			table.insert(steps, v3(px, 0, pz))
		end
	end
	addSteps(6, 0, 9)
	addSteps(5, -9, 0)
	addSteps(3, 0, 9)
	local checkpoints, obbyHidden = {}, {}
	local obbyFinish
	for index, step in ipairs(steps) do
		local y = 2 + index * 0.75
		if index == #steps then
			obbyFinish = touchable(B("ObbyFinish", v3(12, 1, 12), v3(step.X, y, step.Z + 3), GOLD, { parent = obbyFolder, material = "Neon" }))
			sign("FINISH", v3(8, 2.4, 0.5), CFrame.new(step.X, y + 6, step.Z + 9), DARK, GOLD, Enum.NormalId.Front)
			obbyHidden.finish = CFrame.new(step.X + 4, y + 0.6, step.Z + 7)
			obbyHidden.finishFar = CFrame.new(step.X - 4.5, y + 0.6, step.Z + 7.5)
		elseif index == 5 or index == 10 then
			local checkpoint = touchable(B("ObbyCheckpoint", v3(8, 1, 8), v3(step.X, y, step.Z), rgb(255, 230, 90), { parent = obbyFolder, material = "Neon" }))
			table.insert(checkpoints, checkpoint)
			if index == 5 then
				obbyHidden.checkpoint = CFrame.new(step.X + 2.8, y + 0.6, step.Z + 2.8)
			end
		else
			local small = index % 3 == 0
			B("ObbyStep", small and v3(4, 1, 4) or v3(5.5, 1, 5.5), v3(step.X, y, step.Z), small and rgb(255, 110, 225) or rgb(90, 190, 255), oo)
		end
	end

	----------------------------------------------------------------------
	-- PARK (north-east)
	----------------------------------------------------------------------
	local parkCenter = v3(108, 0, -108)
	B("ParkLawn", v3(0.4, 100, 100), v3(parkCenter.X, 0.12, parkCenter.Z), rgb(86, 178, 80), { shape = "Cylinder", rot = UP, material = "Grass" })
	B("Pond", v3(0.5, 32, 32), v3(118, 0.3, -118), rgb(80, 170, 235), { shape = "Cylinder", rot = UP, material = "Glass", transparency = 0.25, collide = false })
	B("PondIsland", v3(1.2, 9, 9), v3(118, 0.6, -118), rgb(214, 196, 140), { shape = "Cylinder", rot = UP, material = "Sand" })
	tree(120, -120, 0.7)
	for _, t in ipairs({ { 82, -140 }, { 96, -150 }, { 140, -142 }, { 150, -116 }, { 146, -88 }, { 128, -70 }, { 84, -96 }, { 70, -118 }, { 132, -150 } }) do
		tree(t[1], t[2], 0.9 + ((t[1] + t[2]) % 3) * 0.12)
	end
	bench(96, -92, 135)
	bench(100, -128, 45)
	bench(134, -100, -90)
	local flowerColors = { rgb(255, 110, 180), rgb(255, 220, 80), rgb(170, 110, 255), WHITE }
	for i = 0, 15 do
		local angle = i / 16 * math.pi * 2
		local r = 30 + (i % 3) * 6
		B("Flower", v3(0.6, 1.4, 1.4), v3(parkCenter.X + math.cos(angle) * r, 0.6, parkCenter.Z + math.sin(angle) * r), flowerColors[i % 4 + 1], { shape = "Cylinder", rot = UP, collide = false })
	end
	-- Swing set (decor)
	B("SwingBar", v3(12, 0.5, 0.5), v3(90, 9, -112), DARK, { material = "Metal" })
	for _, x in ipairs({ 84.5, 95.5 }) do
		B("SwingLeg", v3(0.5, 9, 0.5), v3(x, 4.5, -112), DARK, { material = "Metal" })
	end
	for _, x in ipairs({ 87.5, 92.5 }) do
		B("SwingRope", v3(0.15, 5.5, 0.15), v3(x, 6, -112), rgb(200, 200, 205), { collide = false })
		B("SwingSeat", v3(2, 0.3, 1), v3(x, 3.2, -112), rgb(232, 66, 78), {})
	end
	sign("🌳 GOO PARK", v3(12, 3, 0.6), CFrame.new(74, 7, -74) * CFrame.Angles(0, rad(-45), 0), DARK, rgb(120, 255, 140), Enum.NormalId.Back)
	sign("psst... the rocks behind the park feel kinda soft", v3(9, 2.6, 0.4), CFrame.new(150, 3, -146) * CFrame.Angles(0, rad(-45), 0), WOOD, WHITE, Enum.NormalId.Back)

	----------------------------------------------------------------------
	-- FOOD COURT (north-west)
	----------------------------------------------------------------------
	local foodFolder = Instance.new("Folder")
	foodFolder.Name = "FoodCourt"
	foodFolder.Parent = map
	local fo = { parent = foodFolder }
	B("FoodFloor", v3(66, 0.4, 66), v3(-108, 0.2, -108), rgb(240, 226, 196), { parent = foodFolder, material = "Concrete" })
	local stalls = {
		{ name = "🍕 PIZZA", color = rgb(232, 66, 78), x = -128 },
		{ name = "🍔 BURGERS", color = rgb(255, 170, 60), x = -108 },
		{ name = "🧪 MYSTERY", color = rgb(178, 92, 255), x = -88 },
	}
	for _, stall in ipairs(stalls) do
		local stallCounter = B("StallCounter", v3(14, 3.6, 4), v3(stall.x, 2.2, -134), WHITE, fo)
		B("StallBack", v3(14, 11, 1), v3(stall.x, 5.9, -138.5), stall.color, fo)
		B("StallAwning", v3(15, 0.6, 8), CFrame.new(stall.x, 10.6, -134) * CFrame.Angles(rad(-10), 0, 0), stall.color, { parent = foodFolder, material = "Fabric", collide = false })
		B("StallStripe", v3(15.1, 0.62, 2), CFrame.new(stall.x, 10.3, -131.3) * CFrame.Angles(rad(-10), 0, 0), WHITE, { parent = foodFolder, material = "Fabric", collide = false })
		sign(stall.name, v3(11, 2.4, 0.4), CFrame.new(stall.x, 13.4, -134), DARK, stall.color)
		uiPrompt(stallCounter, "Buy Food", "Food Stall", "Shop", "Food")
	end
	for _, t in ipairs({ { -124, -112 }, { -92, -112 }, { -124, -92 }, { -92, -92 } }) do
		B("Table", v3(0.4, 7, 7), v3(t[1], 2.6, t[2]), rgb(232, 66, 78), { parent = foodFolder, shape = "Cylinder", rot = UP })
		B("TableLeg", v3(2.6, 0.8, 0.8), v3(t[1], 1.3, t[2]), DARK, { parent = foodFolder, shape = "Cylinder", rot = UP })
		B("Umbrella", v3(0.5, 11, 11), v3(t[1], 9.5, t[2]), rgb(255, 220, 80), { parent = foodFolder, shape = "Cylinder", rot = UP, collide = false })
		B("UmbrellaPole", v3(7, 0.4, 0.4), v3(t[1], 6, t[2]), WHITE, { parent = foodFolder, shape = "Cylinder", rot = UP, collide = false })
	end
	-- Giant burger sculpture
	local burger = { { rgb(220, 160, 90), 3.2, 16 }, { rgb(110, 70, 40), 2, 15 }, { rgb(255, 210, 70), 0.6, 16.5 }, { rgb(110, 200, 90), 0.8, 17 }, { rgb(230, 70, 60), 0.8, 15 }, { rgb(220, 160, 90), 4.2, 16 } }
	local burgerY = 0.4
	for _, layer in ipairs(burger) do
		B("BurgerLayer", v3(layer[2], layer[3], layer[3]), v3(-108, burgerY + layer[2] / 2, -102), layer[1], { parent = foodFolder, shape = "Cylinder", rot = UP })
		burgerY += layer[2]
	end
	sign("🍔 GOO FOOD COURT", v3(14, 3, 0.6), CFrame.new(-74, 7, -74) * CFrame.Angles(0, rad(45), 0), DARK, rgb(255, 170, 60), Enum.NormalId.Back)

	----------------------------------------------------------------------
	-- HOUSES (south): street + one plot pad per player
	----------------------------------------------------------------------
	local rows = math.ceil(Config.PlotCount / 2)
	local streetLength = rows * 80 + 30
	B("Street", v3(16, 0.3, streetLength), v3(0, 0.15, 58 + streetLength / 2), rgb(70, 72, 80), { material = "Concrete" })
	B("StreetLine", v3(0.6, 0.32, streetLength - 6), v3(0, 0.16, 58 + streetLength / 2), GOLD, { collide = false })
	local plots = {}
	for index = 1, Config.PlotCount do
		local cf = MapBuilder.plotCFrame(index)
		plots[index] = cf
		B("PlotLawn", v3(Config.PlotSize, 0.2, Config.PlotSize), cf * CFrame.new(0, 0.1, 0), rgb(120, 206, 110), { material = "Grass" })
		B("PlotWalk", v3(6, 0.24, 30), cf * CFrame.new(0, 0.12, 27), PATH, { material = "Concrete" })
		local mailbox = cf * CFrame.new(6, 0, 40)
		B("MailboxPost", v3(0.5, 3.4, 0.5), mailbox * CFrame.new(0, 1.7, 0), WOOD, { material = "Wood" })
		B("Mailbox", v3(1.4, 1.2, 2.2), mailbox * CFrame.new(0, 3.8, 0), rgb(232, 66, 78), {})
		local lamp = cf * CFrame.new(-8, 0, 40)
		lampPost(lamp.Position.X, lamp.Position.Z)
	end
	sign("HOME SWEET GOO", v3(22, 4, 1), CFrame.new(0, 17, 66), DARK, GOLD, Enum.NormalId.Front)
	B("StreetArchL", v3(15, 1.6, 1.6), v3(-11, 7.5, 66), DARK, { shape = "Cylinder", rot = UP })
	B("StreetArchR", v3(15, 1.6, 1.6), v3(11, 7.5, 66), DARK, { shape = "Cylinder", rot = UP })

	----------------------------------------------------------------------
	-- SECRET GOO CAVE (hidden behind the park)
	----------------------------------------------------------------------
	local cave = Instance.new("Folder")
	cave.Name = "GooCave"
	cave.Parent = map
	local rock = rgb(84, 80, 92)
	local caveCF = CFrame.new(188, 0, -188) * CFrame.Angles(0, rad(-45), 0) -- local +Z faces the park
	local function C(name, size, offset, color, o)
		o = o or {}
		o.parent = cave
		return B(name, size, caveCF * (typeof(offset) == "CFrame" and offset or CFrame.new(offset)), color, o)
	end
	C("CaveFloor", v3(34, 1, 34), v3(0, 0.5, 0), rgb(50, 46, 60), { material = "Slate" })
	C("CaveBack", v3(36, 18, 3), v3(0, 9, -17), rock, { material = "Slate" })
	C("CaveL", v3(3, 18, 36), v3(-17, 9, 0), rock, { material = "Slate" })
	C("CaveR", v3(3, 18, 36), v3(17, 9, 0), rock, { material = "Slate" })
	C("CaveFrontL", v3(13, 18, 3), v3(-11.5, 9, 17), rock, { material = "Slate" })
	C("CaveFrontR", v3(13, 18, 3), v3(11.5, 9, 17), rock, { material = "Slate" })
	C("CaveFrontTop", v3(10, 8, 3), v3(0, 14, 17), rock, { material = "Slate" })
	-- The "soft rock": looks solid, but you can walk straight through it.
	C("FakeRock", v3(10, 10, 3), v3(0, 5, 17), rock, { material = "Slate", collide = false })
	local caveRoof = C("CaveRoof", v3(38, 3, 38), v3(0, 19.5, 0), rock, { material = "Slate", collide = false })
	CollectionService:AddTag(caveRoof, "HouseRoof")
	for _, boulder in ipairs({ { -20, 4, 22, 12 }, { 21, 3, 20, 10 }, { 24, 5, -6, 14 }, { -24, 4, -8, 13 }, { 0, 6, -24, 16 } }) do
		C("Boulder", v3(boulder[4], boulder[4], boulder[4]), v3(boulder[1], boulder[2], boulder[3]), PartUtil.shade(rock, 0.92), { shape = "Ball", material = "Slate" })
	end
	C("GooPuddle", v3(0.3, 10, 10), CFrame.new(-8, 1.1, -6) * UP, GOO, { shape = "Cylinder", material = "Neon", collide = false })
	C("GooPuddle", v3(0.3, 7, 7), CFrame.new(9, 1.1, 5) * UP, GOO, { shape = "Cylinder", material = "Neon", collide = false })
	for _, m in ipairs({ { -12, -12 }, { 12, -10 }, { -11, 9 }, { 6, -13 }, { 13, 12 } }) do
		C("Mushroom", v3(2, 0.6, 0.6), CFrame.new(m[1], 2, m[2]) * UP, WHITE, { shape = "Cylinder", collide = false })
		C("MushroomCap", v3(2, 2, 2), v3(m[1], 3.2, m[2]), rgb(170, 90, 255), { shape = "Ball", material = "Neon", collide = false })
	end
	local pedestal = C("Pedestal", v3(3, 4, 4), CFrame.new(0, 2.5, -6) * UP, rgb(30, 26, 44), { shape = "Cylinder", material = "Marble" })
	local caveLight = Instance.new("PointLight")
	caveLight.Color = rgb(170, 90, 255)
	caveLight.Range = 40
	caveLight.Brightness = 1.6
	caveLight.Shadows = false
	caveLight.Parent = pedestal

	----------------------------------------------------------------------
	-- HIDDEN SPOTS
	----------------------------------------------------------------------
	local function spot(x, y, z)
		return CFrame.new(x, y, z)
	end
	local hiddenSpots = {
		spot(15, 0.3, -7), spot(-40, 0.3, 38), -- plaza
		spot(-25, 0.7, -143), spot(26, 0.3, -154), spot(4, 21, -152.5), -- store
		spot(177, 3.1, 18), spot(140, 0.3, 26), spot(188, 0.3, -24), -- runway
		spot(-155, 0.7, 21), spot(-108, 0.7, -21), obbyHidden.checkpoint, obbyHidden.finish, -- arcade + obby
		spot(132, 0.3, -146), spot(116, 1.3, -116), spot(78, 0.3, -130), spot(146, 0.3, -80), -- park
		spot(-132, 0.3, -141), spot(-82, 0.5, -136), spot(-108, 0.5, -112), -- food court
		spot(4, 0.4, 300), spot(-90, 0.3, 150), spot(90, 0.3, 390), spot(-4, 0.4, 58 + streetLength - 4), -- houses
		(caveCF * CFrame.new(11, 1.1, -11)), -- cave
	}
	local secretSpots = {
		spot(16, 21, -152.5), -- store ledge
		spot(189, 0.3, 12), -- behind the runway backdrop
		obbyHidden.finishFar, -- top of the obby
		spot(120.5, 1.3, -114.5), -- pond island
		spot(-108, 0.5, -117), -- behind the giant burger
		spot(5, 0.4, 58 + streetLength - 2), -- end of the street
		spot(-164, 0.9, -19), -- tucked behind the arcade machines
		spot(-300, 0.3, 380), -- far corner of the map
	}

	map.Parent = Workspace

	return {
		folder = map,
		spawn = CFrame.lookAt(v3(0, 0.6, 34), v3(0, 0.6, 0)),
		plots = plots,
		plotCFrame = MapBuilder.plotCFrame,
		park = { center = parkCenter, radius = 50, entrance = CFrame.lookAt(v3(74, 0.5, -78), parkCenter) },
		store = { entrance = CFrame.lookAt(v3(0, 0.7, -100), v3(0, 0.7, -140)) },
		food = { entrance = CFrame.lookAt(v3(-78, 0.5, -78), v3(-108, 0.5, -108)) },
		arcade = { center = v3(-132, 3, 0), radius = 36, entrance = CFrame.lookAt(v3(-100, 0.7, 0), v3(-150, 0.7, 0)) },
		runway = {
			stageStart = CFrame.lookAt(v3(172, 3, 0), v3(100, 3, 0)),
			runwayEnd = v3(102, 3, 0),
			lineup = lineup,
			backstage = backstage,
			audience = CFrame.lookAt(v3(118, 0.5, 26), v3(125, 3, 0)),
			signup = signup,
		},
		obby = {
			start = obbyStart,
			finish = obbyFinish,
			checkpoints = checkpoints,
			kill = { pool },
			respawn = CFrame.new(-132, 0.6, 36),
		},
		hiddenSpots = hiddenSpots,
		secretSpots = secretSpots,
		cavePedestal = caveCF * CFrame.new(0, 4.6, -6),
	}
end

return MapBuilder
