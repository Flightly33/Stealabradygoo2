--[[
	Environment
	Everything that sets the mood of the world: lighting, sky, clouds,
	atmosphere, post-processing and the terrain.

	Roblox does not support custom shaders. The "shader" levers it gives are:
	  * Lighting.Technology = Future (set in default.project.json - it cannot
	    be changed from a script) for real per-light shadows and specular
	  * the 2022 PBR materials (MaterialService.Use2022Materials, also in the
	    project file)
	  * post-processing: Bloom, ColorCorrection, SunRays, DepthOfField
	  * Atmosphere (haze, glare, distance colour), Sky and dynamic Clouds
	  * Terrain, which brings animated grass blades and real water
	All of them are set up here. The client (LightingClient) then animates
	the time of day locally and can switch the heavy effects off on slow
	devices.

	TERRAIN NOTE: animated grass blades grow on every exposed Grass voxel,
	even under thin parts. So everything players walk on - the plaza, paths,
	buildings, the street - is painted with a different terrain material
	underneath. Houses paint their own patch (HouseBuilder).
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TimeOfDay = require(ReplicatedStorage.Modules.TimeOfDay)

local Environment = {}

local rgb = Color3.fromRGB
local v3 = Vector3.new
local M = Enum.Material

Environment.NightFxTag = TimeOfDay.Tags.NightFx
Environment.NightLightTag = TimeOfDay.Tags.NightLight
Environment.NightWindowTag = TimeOfDay.Tags.NightWindow
Environment.Day = TimeOfDay.Day
Environment.Night = TimeOfDay.Night

local function clearOld(className)
	for _, child in ipairs(Lighting:GetChildren()) do
		if child.ClassName == className then
			child:Destroy()
		end
	end
end

local function make(className, name, props)
	clearOld(className)
	local instance = Instance.new(className)
	instance.Name = name
	for key, value in pairs(props) do
		instance[key] = value
	end
	instance.Parent = Lighting
	return instance
end

----------------------------------------------------------------------
-- Lighting + post-processing
----------------------------------------------------------------------
function Environment.lighting()
	local day = Environment.Day
	Lighting.ClockTime = 14
	Lighting.Brightness = day.brightness
	Lighting.Ambient = day.ambient
	Lighting.OutdoorAmbient = day.outdoor
	Lighting.ColorShift_Top = rgb(255, 240, 222) -- warm sunlit tops
	Lighting.ColorShift_Bottom = rgb(160, 170, 210) -- cool bounce underneath
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ExposureCompensation = day.exposure
	Lighting.ShadowSoftness = 0.2
	Lighting.GlobalShadows = true
	Lighting.GeographicLatitude = 35

	make("Sky", "Sky", {
		SunAngularSize = 13,
		MoonAngularSize = 9,
		StarCount = 3000,
		CelestialBodiesShown = true,
	})
	make("Atmosphere", "Atmosphere", {
		Density = 0.3,
		Offset = 0.22,
		Color = day.atmosphere,
		Decay = day.decay,
		Glare = 0.25,
		Haze = 1.3,
	})
	make("BloomEffect", "Bloom", {
		Intensity = 0.3,
		Size = 26,
		Threshold = 2, -- only neon + bright highlights bloom
	})
	make("SunRaysEffect", "SunRays", {
		Intensity = 0.06,
		Spread = 0.7,
	})
	make("ColorCorrectionEffect", "Grade", {
		Brightness = -0.02,
		Contrast = 0.1,
		Saturation = day.saturation,
		TintColor = day.tint,
	})
	-- A gentle far blur makes the distance read as "far" (tilt-shift toy look).
	make("DepthOfFieldEffect", "DepthOfField", {
		FarIntensity = 0.12,
		FocusDistance = 70,
		InFocusRadius = 70,
		NearIntensity = 0,
	})
end

----------------------------------------------------------------------
-- Terrain
----------------------------------------------------------------------
local terrain

-- Paints a slab of terrain whose top surface is at y = 0.
local function paint(cframe, size, material)
	terrain:FillBlock(cframe * CFrame.new(0, -2, 0), v3(size.X, 4, size.Z), material)
end
Environment.paint = function(cframe, size, material)
	if terrain then
		paint(cframe, size, material)
	end
end

-- Removes terrain in a box whose top is at y = 0 (and a little above it).
Environment.carve = function(cframe, size)
	if terrain then
		terrain:FillBlock(cframe * CFrame.new(0, -size.Y / 2 + 2, 0), v3(size.X, size.Y + 4, size.Z), M.Air)
	end
end

local function hill(x, z, radius, height, material)
	-- A dome: a ball sunk into the ground so only `height` studs show.
	terrain:FillBall(v3(x, height - radius, z), radius, material or M.Grass)
end

function Environment.terrain(map)
	terrain = Workspace:FindFirstChildOfClass("Terrain")
	if not terrain then
		return false
	end
	Environment.hasTerrain = true

	-- cartoon-saturated material colours
	terrain:SetMaterialColor(M.Grass, rgb(104, 192, 80))
	terrain:SetMaterialColor(M.LeafyGrass, rgb(84, 168, 70))
	terrain:SetMaterialColor(M.Sand, rgb(240, 220, 166))
	terrain:SetMaterialColor(M.Rock, rgb(126, 120, 134))
	terrain:SetMaterialColor(M.Ground, rgb(134, 104, 74))
	terrain:SetMaterialColor(M.Pavement, rgb(196, 190, 178))
	terrain:SetMaterialColor(M.Cobblestone, rgb(176, 166, 150))
	terrain:SetMaterialColor(M.Asphalt, rgb(70, 72, 80))
	terrain.WaterColor = rgb(40, 168, 210)
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8
	terrain.WaterTransparency = 0.45
	terrain.WaterReflectance = 0.6
	pcall(function()
		terrain.Decoration = true -- animated grass blades
	end)

	-- the main island of grass (top at y = 0)
	terrain:FillBlock(CFrame.new(50, -6, 155), v3(620, 12, 990), M.Grass)

	-- GOO BEACH + ocean along the west edge (a nod to Brady's Malibu fit)
	terrain:FillBlock(CFrame.new(-300, -6, 155), v3(88, 12, 990), M.Sand)
	terrain:FillBlock(CFrame.new(-520, -18, 155), v3(352, 10, 1200), M.Sand)
	terrain:FillBlock(CFrame.new(-520, -7, 155), v3(352, 12, 1200), M.Water)

	-- hills framing the world (north, east and south edges)
	local hills = {
		{ -260, -300, 46, 22 }, { -170, -320, 52, 28 }, { -60, -330, 44, 20 }, { 50, -322, 50, 30 }, { 160, -330, 48, 24 },
		{ 300, -300, 56, 34 }, { 320, -180, 46, 26 }, { 330, -60, 50, 22 }, { 325, 70, 44, 26 }, { 330, 210, 52, 30 },
		{ 320, 360, 46, 22 }, { 325, 500, 50, 28 }, { 240, 620, 46, 22 }, { 120, 640, 40, 18 }, { -120, 640, 42, 20 }, { -220, 610, 46, 24 },
	}
	for _, h in ipairs(hills) do
		hill(h[1], h[2], h[3], h[4])
		-- a rocky face on some of them
		if (h[1] + h[2]) % 3 == 0 then
			hill(h[1] + h[3] * 0.25, h[2] + h[3] * 0.2, h[3] * 0.55, h[4] * 0.8, M.Rock)
		end
	end
	-- rocky hill wrapped around the back of the secret Goo Cave
	local cave = map and map.caveCFrame
	if cave then
		for _, offset in ipairs({ { 0, -44, 26, 24 }, { -30, -30, 20, 18 }, { 30, -30, 20, 18 }, { -36, -6, 14, 14 }, { 36, -6, 14, 14 } }) do
			local p = cave * CFrame.new(offset[1], 0, offset[2])
			terrain:FillBall(v3(p.X, offset[4] - offset[3], p.Z), offset[3], M.Rock)
		end
		paint(cave, v3(40, 4, 40), M.Rock)
	end

	-- real water pond in the park
	local pond = map and map.pond
	if pond then
		terrain:FillCylinder(CFrame.new(pond.X, -3, pond.Z), 6, pond.radius, M.Sand)
		terrain:FillCylinder(CFrame.new(pond.X, -2.6, pond.Z), 4.6, pond.radius - 2, M.Water)
		terrain:FillCylinder(CFrame.new(pond.X, -1, pond.Z), 2, pond.radius + 3, M.Sand)
		terrain:FillCylinder(CFrame.new(pond.X, -1.3, pond.Z), 2.4, pond.radius - 2, M.Water)
	end

	-- paint under everything players walk on (no grass poking through)
	for _, patch in ipairs(map and map.paint or {}) do
		if patch[4] then
			terrain:FillCylinder(patch[1] * CFrame.new(0, -2, 0), 4, patch[4], patch[3]) -- round patch
		else
			paint(patch[1], patch[2], patch[3])
		end
	end

	-- dynamic clouds
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.62
	clouds.Color = rgb(255, 255, 255)
	clouds.Parent = terrain
	return true
end

-- Ambient particles: butterflies in the day, fireflies at night.
function Environment.ambientFx(parent, center, radius, kind)
	local holder = Instance.new("Part")
	holder.Name = kind == "fireflies" and "Fireflies" or "Butterflies"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanTouch = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = v3(radius * 2, 6, radius * 2)
	holder.CFrame = CFrame.new(center + v3(0, 4, 0))
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Lifetime = NumberRange.new(3, 6)
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Acceleration = v3(0, 0.3, 0)
	if kind == "fireflies" then
		emitter.Rate = 6
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 0) })
		emitter.Color = ColorSequence.new(rgb(255, 236, 120), rgb(190, 255, 120))
		emitter.LightEmission = 1
		emitter.Enabled = false
		CollectionService:AddTag(emitter, Environment.NightFxTag)
	else
		emitter.Rate = 2
		emitter.Size = NumberSequence.new(0.45, 0.2)
		emitter.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(255, 150, 210)),
			ColorSequenceKeypoint.new(0.5, rgb(255, 230, 120)),
			ColorSequenceKeypoint.new(1, rgb(140, 200, 255)),
		})
		emitter.LightEmission = 0.3
	end
	emitter.Parent = holder
	holder.Parent = parent
	return holder
end

return Environment
