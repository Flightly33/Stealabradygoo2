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
local PartUtil = require(Modules.Builders.PartUtil)

local HouseBuilder = {}

local rgb = Color3.fromRGB
local v3 = Vector3.new
local rad = math.rad
local UP = PartUtil.UP

local WHITE = rgb(245, 245, 245)
local GOLD = rgb(255, 205, 60)
local GOO = rgb(126, 232, 74)
local DARK = rgb(34, 34, 40)

HouseBuilder.RoofTag = "HouseRoof"
HouseBuilder.OwnerPromptTag = "OwnerPrompt"

local STYLES = {
	{ wall = rgb(150, 110, 70), wallMat = "WoodPlanks", floor = rgb(196, 164, 120), floorMat = "WoodPlanks", trim = rgb(104, 74, 46), roof = rgb(124, 62, 50), height = 11, accent = GOO },
	{ wall = rgb(188, 92, 72), wallMat = "Brick", floor = rgb(216, 192, 152), floorMat = "WoodPlanks", trim = WHITE, roof = rgb(88, 90, 100), height = 12, accent = rgb(255, 200, 80) },
	{ wall = rgb(236, 236, 238), wallMat = "Concrete", floor = rgb(204, 206, 212), floorMat = "SmoothPlastic", trim = rgb(60, 190, 190), roof = rgb(58, 70, 92), height = 13, accent = rgb(60, 190, 190) },
	{ wall = rgb(62, 64, 72), wallMat = "Slate", floor = rgb(44, 44, 50), floorMat = "Marble", trim = rgb(232, 66, 78), roof = rgb(28, 28, 32), height = 15, accent = rgb(232, 66, 78) },
	{ wall = rgb(246, 241, 232), wallMat = "Marble", floor = rgb(250, 250, 250), floorMat = "Marble", trim = GOLD, roof = rgb(40, 40, 52), height = 17, accent = GOLD },
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

	-- WALLS (with a door gap and windows) -------------------------------
	local function wall(alongX, fixed, length, openings)
		local cursor = -length / 2
		local function seg(name, c0, c1, y0, y1, color, o)
			if c1 - c0 < 0.05 or y1 - y0 < 0.05 then
				return
			end
			local mid, midY = (c0 + c1) / 2, (y0 + y1) / 2
			local partSize = alongX and v3(c1 - c0, y1 - y0, 1) or v3(1, y1 - y0, c1 - c0)
			local position = alongX and v3(mid, midY, fixed) or v3(fixed, midY, mid)
			p(name, partSize, position, color, o)
		end
		local wallOpts = { material = style.wallMat }
		for _, opening in ipairs(openings) do
			local c0, c1 = opening.center - opening.width / 2, opening.center + opening.width / 2
			seg("Wall", cursor, c0, -1, H, style.wall, wallOpts)
			seg("Wall", c0, c1, opening.top, H, style.wall, wallOpts)
			seg("Wall", c0, c1, -1, opening.bottom, style.wall, wallOpts)
			if opening.glass then
				seg("Window", c0, c1, opening.bottom, opening.top, rgb(170, 220, 255), { material = "Glass", transparency = 0.6, shadow = false })
			end
			cursor = c1
		end
		seg("Wall", cursor, length / 2, -1, H, style.wall, wallOpts)
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
	wall(true, h + 0.5, size + 2, { { center = 0, width = HouseSystem.DoorWidth, bottom = 0, top = 9 } }) -- front
	wall(true, -h - 0.5, size + 2, {}) -- back
	wall(false, -h - 0.5, size, sideWindows) -- left
	wall(false, h + 0.5, size, sideWindows) -- right

	-- Trim along the top of the walls + corner posts.
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			p("Post", v3(1.4, H + 1.4, 1.4), v3(sx * (h + 0.5), (H - 1) / 2 + 0.2, sz * (h + 0.5)), style.trim, { material = tier >= 5 and "Marble" or nil })
		end
	end
	p("DoorFrame", v3(HouseSystem.DoorWidth + 1.2, 0.6, 1.3), v3(0, 9.3, h + 0.5), style.trim)

	-- ROOF: no collisions, so it never traps the camera. Clients hide it
	-- locally while you are inside (see WorldClient).
	local roof = p("Roof", v3(size + 5, 1, size + 5), v3(0, H + 0.5, 0), style.roof, { collide = false, material = tier <= 2 and "Slate" or nil })
	CollectionService:AddTag(roof, HouseBuilder.RoofTag)
	local roofTrim = p("RoofTrim", v3(size + 5.6, 0.5, size + 5.6), v3(0, H - 0.1, 0), style.trim, { collide = false })
	CollectionService:AddTag(roofTrim, HouseBuilder.RoofTag)
	if tier >= 5 then
		-- mansion pillars + glow
		for _, x in ipairs({ -6.5, 6.5 }) do
			p("Pillar", v3(H, 1.6, 1.6), v3(x, H / 2 - 0.5, h + 2.6), WHITE, { shape = "Cylinder", rot = UP, material = "Marble" })
			p("PillarCap", v3(2.4, 0.6, 2.4), v3(x, H - 0.4, h + 2.6), GOLD, { material = "Glass", reflectance = 0.3 })
		end
		p("Glow", v3(size + 5.7, 0.2, size + 5.7), v3(0, H + 1.1, 0), GOLD, { material = "Neon", collide = false, shadow = false })
	end

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
