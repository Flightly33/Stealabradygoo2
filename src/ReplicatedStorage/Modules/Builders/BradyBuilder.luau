--[[
	BradyBuilder
	Assembles a complete Brady Goo model from parts: body proportions for his
	current stage, hairstyle, face, and every equipped clothing piece.

	Used by the SERVER (the real Brady everyone sees) and by the CLIENT (the
	little preview Brady inside the wardrobe / inspect windows) so both always
	look identical.

	Rig layout (all code-driven, no uploaded animations):
	    Root  (anchored, invisible, sits on the ground)
	      Waist         -> Torso
	        Neck          -> Head
	        LeftShoulder  -> LeftArm      RightShoulder -> RightArm
	        LeftHip       -> LeftLeg      RightHip      -> RightLeg
	Clothing parts are welded to whichever limb they belong to, so they follow
	the procedural animation in Client/BradyAnimator for free.

	Brady faces -Z (Roblox's "front").
]]

local CollectionService = game:GetService("CollectionService")

local Modules = script.Parent.Parent
local AgeSystem = require(Modules.AgeSystem)
local ClothingSystem = require(Modules.ClothingSystem)
local InventorySystem = require(Modules.InventorySystem)
local PartUtil = require(script.Parent.PartUtil)

local BradyBuilder = {}

local rgb = Color3.fromRGB
local v3 = Vector3.new
local rad = math.rad

local SKIN = rgb(255, 214, 92)
local GOO = ClothingSystem.GooColor
local UNDERSHIRT = rgb(242, 242, 236)
local DARK = rgb(30, 30, 34)

BradyBuilder.Tag = "BradyGoo"
BradyBuilder.FxTag = "BradyFx"
BradyBuilder.SkinColor = SKIN

----------------------------------------------------------------------
-- Dimensions for an age (also used by the server to place cameras etc.)
----------------------------------------------------------------------
function BradyBuilder.dimensions(age)
	local look = AgeSystem.getStage(age).look
	local S = look.scale
	local d = {
		S = S,
		legW = 0.9 * S,
		legH = 1.9 * S * look.leg,
		torsoW = 2.0 * S,
		torsoH = 1.9 * S * look.torso,
		torsoD = 1.0 * S,
		armW = 0.8 * S,
		armH = 1.9 * S * look.arm,
		H = 1.3 * S * look.head,
	}
	d.height = d.legH + d.torsoH + d.H
	return d
end

----------------------------------------------------------------------
-- Build context helpers
----------------------------------------------------------------------
local function add(ctx, base, name, size, offset, color, opts)
	opts = opts or {}
	return PartUtil.attach(ctx.model, base, {
		name = name,
		size = size,
		offset = offset,
		color = color,
		material = opts.material,
		shape = opts.shape,
		transparency = opts.transparency,
		reflectance = opts.reflectance,
		class = opts.class,
	})
end

-- N small blocks arranged in a horizontal circle (halos, auras, crowns).
local function ring(ctx, base, name, center, radius, count, size, color, material)
	local parts = {}
	for i = 1, count do
		local angle = (i - 1) / count * math.pi * 2
		local offset = CFrame.new(center) * CFrame.Angles(0, -angle, 0) * CFrame.new(radius, 0, 0)
		parts[i] = add(ctx, base, name, size, offset, color, { material = material })
	end
	return parts
end

----------------------------------------------------------------------
-- Particle effects for rare pieces
----------------------------------------------------------------------
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local function seq(a, b)
	return NumberSequence.new(a, b)
end

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, rgb(255, 90, 90)),
	ColorSequenceKeypoint.new(0.25, rgb(255, 220, 80)),
	ColorSequenceKeypoint.new(0.5, rgb(110, 255, 140)),
	ColorSequenceKeypoint.new(0.75, rgb(100, 200, 255)),
	ColorSequenceKeypoint.new(1, rgb(255, 110, 225)),
})

local FX = {
	sparkle = { texture = SPARKLE, rate = 6, life = { 0.6, 1.2 }, speed = { 0.4, 1.4 }, size = seq(0.3, 0), color = ColorSequence.new(rgb(255, 255, 230)), emission = 1 },
	gold = { texture = SPARKLE, rate = 8, life = { 0.6, 1.3 }, speed = { 0.4, 1.6 }, size = seq(0.35, 0), color = ColorSequence.new(rgb(255, 210, 70)), emission = 1, light = rgb(255, 210, 70) },
	goo = { texture = SPARKLE, rate = 5, life = { 0.8, 1.4 }, speed = { 0.2, 0.8 }, size = seq(0.3, 0.05), color = ColorSequence.new(GOO), emission = 0.4, accel = v3(0, -7, 0), light = GOO },
	dust = { texture = SMOKE, rate = 3, life = { 1.4, 2.4 }, speed = { 0.2, 0.6 }, size = seq(0.4, 1.3), color = ColorSequence.new(rgb(214, 200, 170)), transparency = seq(0.7, 1), emission = 0 },
	smoke = { texture = SMOKE, rate = 5, life = { 1.2, 2.2 }, speed = { 0.3, 0.9 }, size = seq(0.6, 1.8), color = ColorSequence.new(rgb(40, 40, 46)), transparency = seq(0.55, 1), emission = 0 },
	stars = { texture = SPARKLE, rate = 5, life = { 1.2, 2 }, speed = { 0.6, 1.2 }, size = seq(0.25, 0), color = ColorSequence.new(rgb(190, 215, 255)), emission = 1, accel = v3(0, 2, 0) },
	flame = { texture = FIRE, rate = 16, life = { 0.4, 0.8 }, speed = { 2, 3.2 }, size = seq(0.7, 0), color = ColorSequence.new(rgb(255, 170, 50), rgb(255, 70, 30)), emission = 1, direction = "Top", light = rgb(255, 140, 40) },
	void = { texture = SMOKE, rate = 6, life = { 1, 1.8 }, speed = { 0.3, 1 }, size = seq(0.5, 1.4), color = ColorSequence.new(rgb(150, 70, 255)), transparency = seq(0.5, 1), emission = 0.6, light = rgb(150, 70, 255) },
	rainbow = { texture = SPARKLE, rate = 12, life = { 0.7, 1.4 }, speed = { 0.6, 1.8 }, size = seq(0.4, 0), color = RAINBOW, emission = 1, light = rgb(255, 150, 235) },
}

BradyBuilder.FxKeys = FX

local function addFx(ctx, part, fxKey)
	local def = FX[fxKey]
	if not def or ctx.preview or not part then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Fx_" .. fxKey
	emitter.Texture = def.texture
	emitter.Rate = def.rate
	emitter.Lifetime = NumberRange.new(def.life[1], def.life[2])
	emitter.Speed = NumberRange.new(def.speed[1], def.speed[2])
	emitter.Size = def.size
	emitter.Color = def.color
	emitter.Transparency = def.transparency or seq(0, 1)
	emitter.LightEmission = def.emission
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-60, 60)
	if def.accel then
		emitter.Acceleration = def.accel
	end
	if def.direction then
		emitter.EmissionDirection = Enum.NormalId[def.direction]
		emitter.SpreadAngle = Vector2.new(20, 20)
	end
	emitter.Parent = part
	CollectionService:AddTag(emitter, BradyBuilder.FxTag)
	if def.light and not ctx.hasLight then
		ctx.hasLight = true -- one light per Brady keeps low-end devices happy
		local light = Instance.new("PointLight")
		light.Name = "FxLight"
		light.Color = def.light
		light.Range = 9
		light.Brightness = 0.8
		light.Shadows = false
		light.Parent = part
		CollectionService:AddTag(light, BradyBuilder.FxTag)
	end
end

----------------------------------------------------------------------
-- FACE (a SurfaceGui drawn with rounded Frames - no decal assets)
----------------------------------------------------------------------
local FACES = {
	-- eye = { width, height } as a fraction of the face, mouth = preset name
	Baby = { eye = { 0.2, 0.25 }, eyeY = 0.44, mouth = "o", blush = true, shine = true },
	Little = { eye = { 0.17, 0.21 }, eyeY = 0.42, mouth = "grin", blush = true, shine = true },
	Kid = { eye = { 0.15, 0.19 }, eyeY = 0.42, mouth = "tongue", shine = true },
	Drippy = { eye = { 0.14, 0.17 }, eyeY = 0.42, mouth = "smirk", brow = 8 },
	Trendy = { eye = { 0.13, 0.16 }, eyeY = 0.42, mouth = "smile", brow = -10 },
	Teen = { eye = { 0.14, 0.08 }, eyeY = 0.44, mouth = "flat", brow = 0 },
	Fashion = { eye = { 0.13, 0.12 }, eyeY = 0.43, mouth = "smirk", brow = 6 },
	Archive = { eye = { 0.13, 0.07 }, eyeY = 0.44, mouth = "line", brow = 4 },
	Vintage = { eye = { 0.13, 0.1 }, eyeY = 0.43, mouth = "smile", brow = 0, mustache = true },
	Legendary = { eye = { 0.13, 0.12 }, eyeY = 0.43, mouth = "smile", brow = 6, golden = true },
}

local function frame(parent, name, size, position, color, corner, rotation)
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = size
	f.Position = position
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Rotation = rotation or 0
	if corner then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(corner, 0)
		c.Parent = f
	end
	f.Parent = parent
	return f
end

local function buildFace(head, faceId)
	local def = FACES[faceId] or FACES.Kid
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Face"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(200, 200)
	gui.LightInfluence = 1
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local eyeColor = def.golden and rgb(120, 80, 10) or rgb(28, 28, 32)
	for _, side in ipairs({ { "EyeL", 0.3 }, { "EyeR", 0.7 } }) do
		local eye = frame(gui, side[1], UDim2.fromScale(def.eye[1], def.eye[2]), UDim2.fromScale(side[2], def.eyeY), eyeColor, 1)
		if def.shine then
			frame(eye, "Shine", UDim2.fromScale(0.36, 0.36), UDim2.fromScale(0.68, 0.3), Color3.new(1, 1, 1), 1)
		end
		if def.golden then
			frame(eye, "Shine", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.5, 0.5), rgb(255, 215, 80), 1)
		end
	end
	if def.brow then
		frame(gui, "BrowL", UDim2.fromScale(0.2, 0.035), UDim2.fromScale(0.3, def.eyeY - 0.15), rgb(40, 110, 36), 1, def.brow)
		frame(gui, "BrowR", UDim2.fromScale(0.2, 0.035), UDim2.fromScale(0.7, def.eyeY - 0.15), rgb(40, 110, 36), 1, -def.brow)
	end
	-- Blush is always created so the animator can show it when he's embarrassed.
	for _, side in ipairs({ { "BlushL", 0.17 }, { "BlushR", 0.83 } }) do
		local blush = frame(gui, side[1], UDim2.fromScale(0.16, 0.1), UDim2.fromScale(side[2], 0.6), rgb(255, 120, 130), 1)
		blush.BackgroundTransparency = 0.35
		blush.Visible = def.blush == true
		blush:SetAttribute("Default", def.blush == true)
	end

	local mouthColor = rgb(60, 20, 24)
	local mouth
	if def.mouth == "o" then
		mouth = frame(gui, "Mouth", UDim2.fromScale(0.13, 0.13), UDim2.fromScale(0.5, 0.7), mouthColor, 1)
	elseif def.mouth == "grin" then
		mouth = frame(gui, "Mouth", UDim2.fromScale(0.36, 0.16), UDim2.fromScale(0.5, 0.7), mouthColor, 0.5)
		frame(mouth, "Tooth", UDim2.fromScale(0.22, 0.45), UDim2.fromScale(0.5, 0.22), Color3.new(1, 1, 1), 0.2)
	elseif def.mouth == "tongue" then
		mouth = frame(gui, "Mouth", UDim2.fromScale(0.32, 0.12), UDim2.fromScale(0.5, 0.7), mouthColor, 0.5)
		frame(mouth, "Tongue", UDim2.fromScale(0.4, 1.3), UDim2.fromScale(0.62, 0.9), rgb(255, 120, 140), 0.45)
	elseif def.mouth == "smirk" then
		mouth = frame(gui, "Mouth", UDim2.fromScale(0.26, 0.05), UDim2.fromScale(0.54, 0.7), mouthColor, 1, -10)
	elseif def.mouth == "flat" then
		mouth = frame(gui, "Mouth", UDim2.fromScale(0.22, 0.045), UDim2.fromScale(0.5, 0.71), mouthColor, 1)
	elseif def.mouth == "line" then
		mouth = frame(gui, "Mouth", UDim2.fromScale(0.16, 0.04), UDim2.fromScale(0.5, 0.71), mouthColor, 1)
	else -- smile
		mouth = frame(gui, "Mouth", UDim2.fromScale(0.3, 0.08), UDim2.fromScale(0.5, 0.7), mouthColor, 1)
	end
	if def.mustache then
		frame(gui, "Mustache", UDim2.fromScale(0.2, 0.035), UDim2.fromScale(0.5, 0.63), rgb(40, 110, 36), 1)
	end
	gui.Parent = head
	return gui
end

-- ViewportFrames cannot draw SurfaceGuis, so preview models (wardrobe,
-- inspect window) get a simple face made of thin parts instead.
local function buildPreviewFace(ctx, faceId)
	local def = FACES[faceId] or FACES.Kid
	local head, H = ctx.parts.Head, ctx.d.H
	local z = -(H / 2 + 0.012)
	local eyeColor = rgb(28, 28, 32)
	for _, x in ipairs({ -0.2, 0.2 }) do
		add(ctx, head, "FaceEye", v3(def.eye[1] * H, def.eye[2] * H, 0.03), v3(x * H, (0.5 - def.eyeY) * H, z), eyeColor)
	end
	local mouthW = (def.mouth == "o" and 0.13) or (def.mouth == "line" and 0.16) or 0.28
	local mouthH = (def.mouth == "o" and 0.13) or (def.mouth == "grin" and 0.14) or 0.05
	add(ctx, head, "FaceMouth", v3(mouthW * H, mouthH * H, 0.03), v3(0, -0.2 * H, z), rgb(60, 20, 24))
	if def.blush then
		add(ctx, head, "FaceBlush", v3(0.16 * H, 0.09 * H, 0.03), v3(-0.33 * H, -0.1 * H, z), rgb(255, 150, 160))
		add(ctx, head, "FaceBlush", v3(0.16 * H, 0.09 * H, 0.03), v3(0.33 * H, -0.1 * H, z), rgb(255, 150, 160))
	end
	if def.mustache then
		add(ctx, head, "FaceMustache", v3(0.2 * H, 0.04 * H, 0.03), v3(0, -0.13 * H, z), rgb(40, 110, 36))
	end
end

----------------------------------------------------------------------
-- HAIR
----------------------------------------------------------------------
-- Each style adds parts relative to the head (H = head size).
-- `top = true` pieces are skipped when a hat is worn.
local function buildHair(ctx, vis, hatDef)
	local head, H = ctx.parts.Head, ctx.d.H
	local color = vis.color or GOO
	local tip = vis.color2 or color
	local hasHat = hatDef ~= nil
	if hatDef and hatDef.kind == "hood" then
		return nil -- fully covered
	end
	local first
	local function hair(name, size, offset, isTop, c, opts)
		if isTop and hasHat then
			return nil
		end
		local part = add(ctx, head, "Hair_" .. name, size * H, typeof(offset) == "Vector3" and CFrame.new(offset * H) or (offset - offset.Position + offset.Position * H), c or color, opts)
		first = first or part
		return part
	end
	-- Shared "what pokes out under a hat" pieces.
	local function underHat(length)
		hair("Back", v3(1.06, length, 0.1), v3(0, 0.22 - length / 2, 0.52), false)
		hair("SideL", v3(0.08, length * 0.7, 0.5), v3(-0.53, 0.2 - length * 0.35, 0.2), false)
		hair("SideR", v3(0.08, length * 0.7, 0.5), v3(0.53, 0.2 - length * 0.35, 0.2), false)
	end

	local style = vis.style
	if style == "babycurl" then
		hair("Curl", v3(0.24, 0.24, 0.24), v3(0, 0.58, -0.1), true, nil, { shape = "Ball" })
		hair("Curl2", v3(0.15, 0.15, 0.15), v3(0.08, 0.74, -0.14), true, nil, { shape = "Ball" })
	elseif style == "buzz" then
		hair("Cap", v3(1.03, 0.14, 1.03), v3(0, 0.46, 0), true, PartUtil.shade(color, 0.75))
		hair("Back", v3(1.03, 0.3, 0.06), v3(0, 0.3, 0.5), false, PartUtil.shade(color, 0.75))
	elseif style == "bowl" then
		hair("Bowl", v3(1.1, 0.4, 1.1), v3(0, 0.44, 0), true)
		underHat(0.4)
	elseif style == "spiky" then
		hair("Cap", v3(1.05, 0.22, 1.05), v3(0, 0.46, 0), true)
		local spikes = { { -0.3, -0.25, -18, -14 }, { 0.3, -0.25, -18, 14 }, { 0, 0, 0, 0 }, { -0.3, 0.25, 16, -14 }, { 0.3, 0.25, 16, 14 }, { 0, -0.38, -26, 0 } }
		for i, s in ipairs(spikes) do
			local cf = CFrame.new(s[1], 0.72, s[2]) * CFrame.Angles(rad(s[3]), 0, rad(-s[4]))
			hair("Spike" .. i, v3(0.26, 0.46, 0.26), cf, true)
			if vis.color2 then
				hair("Tip" .. i, v3(0.2, 0.2, 0.2), cf * CFrame.new(0, 0.26, 0), true, tip)
			end
		end
		underHat(0.35)
	elseif style == "swoop" then
		hair("Cap", v3(1.06, 0.26, 1.06), v3(0, 0.46, 0.02), true)
		hair("Swoop", v3(0.95, 0.32, 0.5), CFrame.new(0.12, 0.5, -0.42) * CFrame.Angles(rad(10), rad(12), rad(-16)), true)
		hair("SwoopTip", v3(0.4, 0.26, 0.36), CFrame.new(0.52, 0.34, -0.5) * CFrame.Angles(0, rad(20), rad(-34)), true)
		underHat(0.45)
	elseif style == "fluffy" then
		local puffs = { { 0, 0.62, 0 }, { -0.36, 0.5, -0.3 }, { 0.36, 0.5, -0.3 }, { -0.38, 0.5, 0.3 }, { 0.38, 0.5, 0.3 }, { 0, 0.52, -0.46 }, { 0, 0.5, 0.42 } }
		for i, p in ipairs(puffs) do
			hair("Puff" .. i, v3(0.56, 0.56, 0.56), v3(p[1], p[2], p[3]), true, nil, { shape = "Ball" })
		end
		underHat(0.45)
	elseif style == "curtains" then
		hair("TopL", v3(0.56, 0.26, 1.1), CFrame.new(-0.27, 0.5, 0) * CFrame.Angles(0, 0, rad(12)), true)
		hair("TopR", v3(0.56, 0.26, 1.1), CFrame.new(0.27, 0.5, 0) * CFrame.Angles(0, 0, rad(-12)), true)
		hair("FringeL", v3(0.34, 0.4, 0.07), CFrame.new(-0.36, 0.3, -0.53) * CFrame.Angles(0, 0, rad(10)), true)
		hair("FringeR", v3(0.34, 0.4, 0.07), CFrame.new(0.36, 0.3, -0.53) * CFrame.Angles(0, 0, rad(-10)), true)
		underHat(0.7)
	elseif style == "slick" then
		hair("Top", v3(1.05, 0.24, 1.14), CFrame.new(0, 0.48, 0.06) * CFrame.Angles(rad(-6), 0, 0), true)
		hair("Wave", v3(0.9, 0.2, 0.4), CFrame.new(0, 0.6, -0.3) * CFrame.Angles(rad(14), 0, 0), true)
		underHat(0.5)
	elseif style == "layers" then
		hair("Top", v3(1.08, 0.26, 1.08), v3(0, 0.47, 0), true)
		hair("Fringe1", v3(0.3, 0.36, 0.07), CFrame.new(-0.3, 0.32, -0.53) * CFrame.Angles(0, 0, rad(14)), true)
		hair("Fringe2", v3(0.26, 0.42, 0.07), CFrame.new(0.05, 0.3, -0.54) * CFrame.Angles(0, 0, rad(-8)), true)
		hair("Fringe3", v3(0.28, 0.34, 0.07), CFrame.new(0.36, 0.33, -0.53) * CFrame.Angles(0, 0, rad(-18)), true)
		hair("LongBack", v3(1.1, 1.15, 0.14), v3(0, -0.1, 0.55), false)
		hair("LayerL", v3(0.12, 0.95, 0.85), v3(-0.56, -0.02, 0.12), false)
		hair("LayerR", v3(0.12, 0.95, 0.85), v3(0.56, -0.02, 0.12), false)
	elseif style == "shag" then
		hair("Top", v3(1.08, 0.3, 1.08), v3(0, 0.48, 0), true)
		hair("Fringe", v3(0.9, 0.3, 0.08), CFrame.new(0, 0.34, -0.54) * CFrame.Angles(0, 0, rad(4)), true)
		hair("Mullet", v3(1.0, 1.4, 0.16), CFrame.new(0, -0.3, 0.56) * CFrame.Angles(rad(-8), 0, 0), false)
		hair("TuftL", v3(0.14, 0.6, 0.6), CFrame.new(-0.57, 0.1, 0.1) * CFrame.Angles(0, 0, rad(-8)), false)
		hair("TuftR", v3(0.14, 0.6, 0.6), CFrame.new(0.57, 0.1, 0.1) * CFrame.Angles(0, 0, rad(8)), false)
	elseif style == "legend" then
		hair("Top", v3(1.1, 0.3, 1.1), v3(0, 0.48, 0), true)
		hair("Crest", v3(0.7, 0.3, 0.5), CFrame.new(0, 0.66, -0.2) * CFrame.Angles(rad(18), 0, 0), true)
		hair("Flow", v3(1.12, 1.7, 0.18), CFrame.new(0, -0.4, 0.58) * CFrame.Angles(rad(-6), 0, 0), false)
		hair("FlowTip", v3(1.14, 0.3, 0.2), CFrame.new(0, -1.28, 0.67) * CFrame.Angles(rad(-6), 0, 0), false, tip, { material = "Neon" })
		hair("StrandL", v3(0.16, 1.2, 0.3), v3(-0.58, -0.15, -0.2), false)
		hair("StrandR", v3(0.16, 1.2, 0.3), v3(0.58, -0.15, -0.2), false)
		hair("StrandTipL", v3(0.18, 0.22, 0.32), v3(-0.58, -0.82, -0.2), false, tip, { material = "Neon" })
		hair("StrandTipR", v3(0.18, 0.22, 0.32), v3(0.58, -0.82, -0.2), false, tip, { material = "Neon" })
	elseif style == "mohawk" then
		hair("Fade", v3(1.03, 0.1, 1.03), v3(0, 0.48, 0), true, PartUtil.shade(color, 0.6))
		local heights = { 0.4, 0.56, 0.64, 0.56, 0.4 }
		for i, h in ipairs(heights) do
			local z = -0.44 + (i - 1) * 0.22
			hair("Hawk" .. i, v3(0.18, h, 0.24), v3(0, 0.5 + h / 2, z), true)
			if vis.color2 then
				hair("HawkTip" .. i, v3(0.2, 0.14, 0.26), v3(0, 0.5 + h, z), true, tip, { material = "Neon" })
			end
		end
	elseif style == "puff" then
		hair("Cap", v3(1.05, 0.2, 1.05), v3(0, 0.45, 0), true)
		hair("Puff", v3(1.35, 1.35, 1.35), v3(0, 0.95, 0.05), true, nil, { shape = "Ball" })
		underHat(0.35)
	elseif style == "buns" then
		hair("Cap", v3(1.06, 0.24, 1.06), v3(0, 0.46, 0), true)
		hair("BunL", v3(0.5, 0.5, 0.5), v3(-0.45, 0.78, 0), true, nil, { shape = "Ball" })
		hair("BunR", v3(0.5, 0.5, 0.5), v3(0.45, 0.78, 0), true, nil, { shape = "Ball" })
		underHat(0.4)
	elseif style == "long" then
		hair("Top", v3(1.08, 0.26, 1.08), v3(0, 0.47, 0), true)
		hair("Back", v3(1.1, 1.6, 0.16), v3(0, -0.35, 0.56), false)
		hair("SideL", v3(0.14, 1.5, 0.9), v3(-0.57, -0.3, 0.05), false)
		hair("SideR", v3(0.14, 1.5, 0.9), v3(0.57, -0.3, 0.05), false)
	else
		hair("Cap", v3(1.05, 0.24, 1.05), v3(0, 0.46, 0), true)
	end
	return first
end

----------------------------------------------------------------------
-- SHIRT
----------------------------------------------------------------------
local function graphicOn(part, vis)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Graphic"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(200, 200)
	gui.LightInfluence = 1
	local color = vis.graphicColor or DARK
	local kind = vis.graphic
	if kind == "goo" then
		-- a goo droplet: a circle with a rotated square on top
		frame(gui, "Tip", UDim2.fromScale(0.22, 0.22), UDim2.fromScale(0.5, 0.36), color, 0.15, 45)
		frame(gui, "Drop", UDim2.fromScale(0.34, 0.34), UDim2.fromScale(0.5, 0.52), color, 1)
	elseif kind == "smile" then
		frame(gui, "EyeL", UDim2.fromScale(0.08, 0.12), UDim2.fromScale(0.4, 0.4), color, 1)
		frame(gui, "EyeR", UDim2.fromScale(0.08, 0.12), UDim2.fromScale(0.6, 0.4), color, 1)
		frame(gui, "Mouth", UDim2.fromScale(0.36, 0.07), UDim2.fromScale(0.5, 0.6), color, 1)
	else
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.46)
		label.Size = UDim2.fromScale(0.62, 0.5)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = color
		if kind == "flame" then
			label.Text = "🔥"
		elseif kind == "banana" then
			label.Text = "🍌"
		elseif kind == "star" then
			label.Text = "★"
		elseif kind == "number" then
			label.Text = "00"
		else
			label.Text = vis.text or "GOO"
		end
		label.Parent = gui
	end
	gui.Parent = part
end

local function buildShirt(ctx, vis)
	local d, parts = ctx.d, ctx.parts
	local torso = parts.Torso
	local material = vis.material
	torso.Color = vis.color
	if material then
		torso.Material = Enum.Material[material]
	end
	local front = torso -- the part that carries the chest graphic
	if vis.oversized then
		front = add(ctx, torso, "Shirt_Shell", v3(d.torsoW + 0.24 * d.S, d.torsoH + 0.3 * d.S, d.torsoD + 0.24 * d.S), v3(0, -0.13 * d.S, 0), vis.color, { material = material })
	end
	if vis.under then
		-- a long-sleeve layer poking out under the tee
		add(ctx, torso, "Shirt_Hem", v3(d.torsoW * 1.02, 0.2 * d.S, d.torsoD * 1.02), v3(0, -d.torsoH / 2 - (vis.oversized and 0.3 or 0.06) * d.S, 0), vis.under)
	end
	for _, side in ipairs({ "LeftArm", "RightArm" }) do
		local arm = parts[side]
		local sleeveColor = vis.sleeveColor or vis.color
		if vis.sleeves == "long" or vis.under then
			arm.Color = vis.under or sleeveColor
			add(ctx, arm, "Hand", v3(d.armW * 1.02, d.armH * 0.16, d.armW * 1.02), v3(0, -d.armH * 0.42, 0), SKIN)
		end
		if vis.sleeves == "short" then
			local bulk = vis.oversized and 1.3 or 1.14
			add(ctx, arm, "Shirt_Sleeve", v3(d.armW * bulk, d.armH * (vis.oversized and 0.55 or 0.42), d.armW * bulk), v3(0, d.armH * (vis.oversized and 0.225 or 0.29), 0), sleeveColor, { material = material })
		elseif vis.sleeves == "long" and vis.oversized then
			add(ctx, arm, "Shirt_Sleeve", v3(d.armW * 1.28, d.armH * 0.8, d.armW * 1.28), v3(0, d.armH * 0.08, 0), sleeveColor, { material = material })
		end
	end
	if vis.stripes then
		local w, dd = front.Size.X * 1.02, front.Size.Z * 1.02
		add(ctx, torso, "Shirt_Stripe", v3(w, d.torsoH * 0.11, dd), v3(0, d.torsoH * 0.2, 0), vis.stripes)
		add(ctx, torso, "Shirt_Stripe", v3(w, d.torsoH * 0.11, dd), v3(0, -d.torsoH * 0.12, 0), vis.stripes)
	end
	if vis.holes then
		local z = -(front.Size.Z / 2 + 0.01)
		add(ctx, torso, "Shirt_Hole", v3(0.3 * d.S, 0.16 * d.S, 0.04), CFrame.new(-0.4 * d.S, 0.2 * d.S, z) * CFrame.Angles(0, 0, rad(20)), PartUtil.shade(vis.color, 0.45))
		add(ctx, torso, "Shirt_Hole", v3(0.22 * d.S, 0.3 * d.S, 0.04), CFrame.new(0.45 * d.S, -0.3 * d.S, z) * CFrame.Angles(0, 0, rad(-15)), PartUtil.shade(vis.color, 0.45))
		add(ctx, torso, "Shirt_Hole", v3(0.36 * d.S, 0.12 * d.S, 0.04), CFrame.new(0.1 * d.S, -0.6 * d.S, z) * CFrame.Angles(0, 0, rad(8)), PartUtil.shade(vis.color, 0.45))
	end
	if vis.graphic and not ctx.preview then
		graphicOn(front, vis)
	end
	return front
end

----------------------------------------------------------------------
-- PANTS
----------------------------------------------------------------------
local function buildPants(ctx, vis)
	local d, parts = ctx.d, ctx.parts
	local width = vis.width or 1
	local length = vis.length or 1
	local material = vis.material
	local first
	for index, side in ipairs({ "LeftLeg", "RightLeg" }) do
		local leg = parts[side]
		local sign = index == 1 and -1 or 1
		local outward = (width - 1) * d.legW * 0.22 * sign
		local w = d.legW * math.max(width, 1.04)
		if length < 1 then
			-- shorts: skin shows below
			leg.Color = SKIN
			add(ctx, leg, "Pants_Short", v3(w * 1.06, d.legH * length, w * 1.06), v3(outward, d.legH * (1 - length) / 2, 0), vis.color, { material = material })
		else
			leg.Color = vis.color
			if material then
				leg.Material = Enum.Material[material]
			end
			if width > 1.04 then
				add(ctx, leg, "Pants_Shell", v3(w, d.legH * 0.99, w), v3(outward, 0, 0), vis.color, { material = material })
			end
		end
		first = first or leg
		local outer = sign * (w / 2 + 0.03 * d.S) + outward
		if vis.flare then
			add(ctx, leg, "Pants_Flare", v3(w * 1.45, d.legH * 0.3, w * 1.45), v3(outward, -d.legH * 0.35, 0), vis.color, { material = material })
		end
		if vis.pockets then
			add(ctx, leg, "Pants_Pocket", v3(0.14 * d.S, d.legH * 0.24, d.legW * 0.62), v3(outer, d.legH * 0.05, 0), PartUtil.shade(vis.color, 0.82), { material = material })
		end
		if vis.stripe then
			add(ctx, leg, "Pants_Stripe", v3(0.05 * d.S, d.legH * length * 0.98, d.legW * 0.3), v3(outer, d.legH * (1 - length) / 2, 0), vis.stripe)
		end
		if vis.patches then
			add(ctx, leg, "Pants_Rip", v3(d.legW * 0.6, d.legH * 0.14, 0.05), v3(outward, d.legH * 0.08, -(w / 2 + 0.01)), SKIN)
			add(ctx, leg, "Pants_Rip", v3(d.legW * 0.4, d.legH * 0.08, 0.05), v3(outward + 0.1 * d.S * sign, -d.legH * 0.2, -(w / 2 + 0.01)), SKIN)
		end
		if vis.plaid then
			add(ctx, leg, "Pants_Plaid", v3(w * 1.03, d.legH * 0.07, w * 1.03), v3(outward, d.legH * 0.22, 0), vis.plaid)
			add(ctx, leg, "Pants_Plaid", v3(w * 1.03, d.legH * 0.07, w * 1.03), v3(outward, -d.legH * 0.15, 0), vis.plaid)
			add(ctx, leg, "Pants_Plaid", v3(w * 0.14, d.legH * length * 0.97, w * 1.03), v3(outward, 0, 0), vis.plaid)
		end
		if vis.straps then
			add(ctx, leg, "Pants_Strap", v3(w * 1.05, d.legH * 0.06, w * 1.05), v3(outward, d.legH * 0.3, 0), vis.straps)
			add(ctx, leg, "Pants_Strap", v3(w * 1.05, d.legH * 0.06, w * 1.05), v3(outward, -d.legH * 0.05, 0), vis.straps)
			add(ctx, leg, "Pants_StrapHang", v3(0.07 * d.S, d.legH * 0.5, 0.12 * d.S), CFrame.new(outer, -d.legH * 0.1, 0.1 * d.S) * CFrame.Angles(rad(12), 0, 0), vis.straps)
		end
	end
	return first
end

-- What he wears with no pants equipped: a diaper (baby) or goo boxers.
local function buildUnderwear(ctx)
	local d, parts = ctx.d, ctx.parts
	local isBaby = ctx.stage.id == "Baby"
	for index, side in ipairs({ "LeftLeg", "RightLeg" }) do
		local leg = parts[side]
		local sign = index == 1 and -1 or 1
		leg.Color = SKIN
		local w = d.legW * (isBaby and 1.3 or 1.1)
		add(ctx, leg, "Underwear", v3(w, d.legH * (isBaby and 0.6 or 0.38), w), v3(sign * (isBaby and 0.05 or 0) * d.S, d.legH * (isBaby and 0.2 or 0.31), 0), Color3.new(1, 1, 1))
		if not isBaby then
			add(ctx, leg, "UnderwearDot", v3(0.16 * d.S, 0.16 * d.S, 0.04), v3(0, d.legH * 0.3, -(w / 2 + 0.01)), GOO, { shape = "Ball" })
		end
	end
end

----------------------------------------------------------------------
-- SHOES
----------------------------------------------------------------------
local function buildShoes(ctx, vis)
	local d, parts = ctx.d, ctx.parts
	local chunk = vis.chunk or 1
	local lift = ctx.lift
	local material = vis.material
	local first
	for _, side in ipairs({ "LeftLeg", "RightLeg" }) do
		local leg = parts[side]
		local bottom = -d.legH / 2
		if vis.invisible then
			-- nothing to see here. (a faint sparkle proves they exist.)
			local ghost = add(ctx, leg, "Shoe_Invisible", v3(d.legW, 0.3 * d.S, d.legW * 1.5), v3(0, bottom + 0.15 * d.S, -0.2 * d.S), Color3.new(1, 1, 1), { transparency = 1 })
			addFx(ctx, ghost, "sparkle")
			first = first or ghost
		else
			local w = d.legW * 1.14 * chunk
			local len = d.legW * 1.6 * chunk
			local forward = -(len - d.legW) / 2
			local soleH = 0.14 * d.S + lift
			local sole = add(ctx, leg, "Shoe_Sole", v3(w * 1.04, soleH, len * 1.04), v3(0, bottom - lift + soleH / 2, forward), vis.sole, { material = vis.glow and "Neon" or nil })
			if vis.glow then
				sole.Color = vis.glow
			end
			local upH = (vis.high and 0.78 or 0.42) * d.S * math.min(chunk, 1.2)
			if vis.slide then
				add(ctx, leg, "Shoe_Band", v3(w * 1.02, 0.26 * d.S, d.legW * 0.7), v3(0, bottom + 0.14 * d.S + 0.13 * d.S, forward - len * 0.12), vis.color, { material = material })
			else
				local upper = add(ctx, leg, "Shoe_Upper", v3(w, upH, len), v3(0, bottom + 0.14 * d.S + upH / 2, forward), vis.color, { material = material })
				add(ctx, leg, "Shoe_Toe", v3(w * 0.9, upH * 0.5, len * 0.3), v3(0, bottom + 0.14 * d.S + upH * 0.25, forward - len * 0.42), PartUtil.shade(vis.color, 0.92), { material = material })
				if vis.split then
					add(ctx, leg, "Shoe_Split", v3(0.05 * d.S, upH * 0.6, len * 0.35), v3(0, bottom + 0.14 * d.S + upH * 0.3, forward - len * 0.42), DARK)
				end
				first = first or upper
			end
			first = first or sole
		end
	end
	return first
end

----------------------------------------------------------------------
-- JACKET (one generic recipe covers hoodies, puffers, trench coats...)
----------------------------------------------------------------------
local function buildJacket(ctx, vis)
	local d, parts = ctx.d, ctx.parts
	local torso = parts.Torso
	local S = d.S
	local b = (vis.bulk or 0.14) * S
	local len = (vis.length or 0) * S
	local material = vis.material
	local color = vis.color
	local sleeveColor = vis.sleeve or color
	local opts = { material = material }
	local W, Hh, D = d.torsoW + 2 * b, d.torsoH + len + 0.08 * S, d.torsoD + 2 * b
	local yMid = -len / 2
	-- back, sides and two front panels (open down the middle)
	local back = add(ctx, torso, "Jacket_Back", v3(W, Hh, b), v3(0, yMid, d.torsoD / 2 + b / 2), color, opts)
	add(ctx, torso, "Jacket_Side", v3(b, Hh, D), v3(-(d.torsoW / 2 + b / 2), yMid, 0), color, opts)
	add(ctx, torso, "Jacket_Side", v3(b, Hh, D), v3(d.torsoW / 2 + b / 2, yMid, 0), color, opts)
	add(ctx, torso, "Jacket_Front", v3(W * 0.36, Hh, b), v3(-W * 0.32, yMid, -(d.torsoD / 2 + b / 2)), color, opts)
	add(ctx, torso, "Jacket_Front", v3(W * 0.36, Hh, b), v3(W * 0.32, yMid, -(d.torsoD / 2 + b / 2)), color, opts)
	add(ctx, torso, "Jacket_Shoulders", v3(W, b, D), v3(0, d.torsoH / 2 + b / 2, 0), color, opts)
	-- sleeves (welded to the arms so they swing)
	for _, side in ipairs({ "LeftArm", "RightArm" }) do
		local arm = parts[side]
		local sw = d.armW + 1.5 * b
		add(ctx, arm, "Jacket_Sleeve", v3(sw, d.armH * 0.88, sw), v3(0, d.armH * 0.07, 0), sleeveColor, opts)
		if vis.trim then
			add(ctx, arm, "Jacket_Cuff", v3(sw * 1.04, d.armH * 0.1, sw * 1.04), v3(0, -d.armH * 0.33, 0), vis.trim, opts)
		end
		if vis.puffy then
			add(ctx, arm, "Jacket_Seam", v3(sw * 1.03, 0.05 * S, sw * 1.03), v3(0, d.armH * 0.22, 0), PartUtil.shade(sleeveColor, 0.72))
			add(ctx, arm, "Jacket_Seam", v3(sw * 1.03, 0.05 * S, sw * 1.03), v3(0, -d.armH * 0.08, 0), PartUtil.shade(sleeveColor, 0.72))
		end
	end
	if vis.trim then
		add(ctx, torso, "Jacket_Hem", v3(W * 1.02, 0.18 * S, D * 1.02), v3(0, -d.torsoH / 2 - len + 0.05 * S, 0), vis.trim, opts)
	end
	if vis.puffy then
		for _, y in ipairs({ 0.25, -0.05, -0.35 }) do
			add(ctx, torso, "Jacket_Seam", v3(W * 1.02, 0.05 * S, D * 1.02), v3(0, d.torsoH * y, 0), PartUtil.shade(color, 0.72))
		end
	end
	if vis.collar then
		local collarColor = typeof(vis.collar) == "Color3" and vis.collar or PartUtil.shade(color, 0.85)
		add(ctx, torso, "Jacket_Collar", v3(d.torsoW * 0.78 + 2 * b, 0.3 * S, D * 1.02), v3(0, d.torsoH / 2 + 0.12 * S, 0.04 * S), collarColor, opts)
	end
	if vis.hood then
		add(ctx, torso, "Jacket_Hood", v3(d.H * 0.95, d.H * 0.7, d.H * 0.5), CFrame.new(0, d.torsoH / 2 + d.H * 0.28, d.torsoD / 2 + d.H * 0.12) * CFrame.Angles(rad(-12), 0, 0), color, opts)
	end
	if vis.straps then
		add(ctx, torso, "Jacket_Strap", v3(0.1 * S, d.torsoH * 0.9, 0.06 * S), CFrame.new(-W * 0.3, yMid - 0.2 * S, d.torsoD / 2 + b + 0.04 * S) * CFrame.Angles(0, 0, rad(8)), vis.straps)
		add(ctx, torso, "Jacket_Strap", v3(0.1 * S, d.torsoH * 0.9, 0.06 * S), CFrame.new(W * 0.3, yMid - 0.2 * S, d.torsoD / 2 + b + 0.04 * S) * CFrame.Angles(0, 0, rad(-8)), vis.straps)
		add(ctx, torso, "Jacket_Strap", v3(W * 1.03, 0.1 * S, D * 1.03), v3(0, -d.torsoH * 0.2, 0), vis.straps)
	end
	return back
end

----------------------------------------------------------------------
-- HATS
----------------------------------------------------------------------
local function buildHat(ctx, vis)
	local head, H = ctx.parts.Head, ctx.d.H
	local c1, c2 = vis.color, vis.color2 or vis.color
	local top = H / 2
	local main
	local function hat(name, size, offset, color, opts)
		local cf = typeof(offset) == "Vector3" and CFrame.new(offset * H) or (offset - offset.Position + offset.Position * H)
		return add(ctx, head, "Hat_" .. name, size * H, cf, color or c1, opts)
	end
	local kind = vis.kind
	if kind == "beanie" then
		main = hat("Body", v3(1.07, 0.44, 1.07), v3(0, 0.52, 0), c1, { material = "Fabric" })
		hat("Cuff", v3(1.11, 0.17, 1.11), v3(0, 0.36, 0), c2, { material = "Fabric" })
		hat("Pom", v3(0.26, 0.26, 0.26), v3(0, 0.82, 0), c2, { shape = "Ball" })
	elseif kind == "cap" then
		main = hat("Crown", v3(1.05, 0.34, 1.05), v3(0, 0.56, 0))
		local z = vis.backwards and 0.7 or -0.7
		hat("Brim", v3(0.92, 0.07, 0.56), v3(0, 0.43, z), c2)
		hat("Button", v3(0.14, 0.08, 0.14), v3(0, 0.75, 0), c2)
	elseif kind == "bucket" then
		main = hat("Crown", v3(1.06, 0.38, 1.06), v3(0, 0.56, 0), c1, { material = "Fabric" })
		hat("Brim", v3(0.09, 1.75, 1.75), CFrame.new(0, 0.4, 0) * PartUtil.UP, c2, { shape = "Cylinder", material = "Fabric" })
	elseif kind == "propeller" then
		main = hat("Crown", v3(1.05, 0.3, 1.05), v3(0, 0.55, 0))
		hat("Stick", v3(0.07, 0.22, 0.07), v3(0, 0.8, 0), rgb(240, 220, 80))
		hat("Blade", v3(0.8, 0.03, 0.14), CFrame.new(0, 0.92, 0) * CFrame.Angles(0, rad(20), 0), c2).Name = "Hat_Spin"
		hat("Blade", v3(0.14, 0.03, 0.8), CFrame.new(0, 0.92, 0) * CFrame.Angles(0, rad(20), 0), c2).Name = "Hat_Spin"
	elseif kind == "beret" then
		main = hat("Beret", v3(0.24, 1.25, 1.25), CFrame.new(0.1, 0.56, 0.02) * CFrame.Angles(0, 0, rad(-10)) * PartUtil.UP, c1, { shape = "Cylinder", material = "Fabric" })
		hat("Stem", v3(0.07, 0.12, 0.07), v3(0.1, 0.72, 0.02))
	elseif kind == "trapper" then
		main = hat("Crown", v3(1.09, 0.42, 1.09), v3(0, 0.53, 0), c1, { material = "Fabric" })
		hat("Fur", v3(1.13, 0.2, 0.14), v3(0, 0.42, -0.52), c2, { material = "Sand" })
		hat("FlapL", v3(0.14, 0.62, 0.52), v3(-0.57, 0.04, 0.05), c1, { material = "Fabric" })
		hat("FlapR", v3(0.14, 0.62, 0.52), v3(0.57, 0.04, 0.05), c1, { material = "Fabric" })
	elseif kind == "cowboy" then
		main = hat("Crown", v3(0.74, 0.46, 0.74), v3(0, 0.66, 0))
		hat("Brim", v3(0.07, 1.95, 1.95), CFrame.new(0, 0.44, 0) * PartUtil.UP, c1, { shape = "Cylinder" })
		hat("Band", v3(0.77, 0.1, 0.77), v3(0, 0.52, 0), c2)
	elseif kind == "tophat" then
		main = hat("Crown", v3(0.9, 0.82, 0.82), CFrame.new(0, 0.9, 0) * PartUtil.UP, c1, { shape = "Cylinder" })
		hat("Brim", v3(0.07, 1.35, 1.35), CFrame.new(0, 0.48, 0) * PartUtil.UP, c1, { shape = "Cylinder" })
		hat("Band", v3(0.14, 0.85, 0.85), CFrame.new(0, 0.58, 0) * PartUtil.UP, c2, { shape = "Cylinder" })
	elseif kind == "crown" then
		main = hat("Band", v3(0.92, 0.2, 0.92), v3(0, 0.58, 0), c1, { material = "Glass", reflectance = 0.3 })
		for i = 1, 6 do
			local a = (i - 1) / 6 * math.pi * 2
			hat("Point", v3(0.18, 0.34, 0.18), v3(math.cos(a) * 0.37, 0.82, math.sin(a) * 0.37), c1, { material = "Glass", reflectance = 0.3 })
			hat("Gem", v3(0.11, 0.11, 0.11), v3(math.cos(a) * 0.47, 0.6, math.sin(a) * 0.47), c2, { shape = "Ball", material = "Neon" })
		end
	elseif kind == "hood" then
		main = hat("Back", v3(1.14, 1.14, 0.14), v3(0, 0.02, 0.56), c1, { material = "Fabric" })
		hat("Top", v3(1.14, 0.14, 1.2), v3(0, 0.56, 0.02), c1, { material = "Fabric" })
		hat("SideL", v3(0.14, 1.14, 1.2), v3(-0.56, 0.02, 0.02), c1, { material = "Fabric" })
		hat("SideR", v3(0.14, 1.14, 1.2), v3(0.56, 0.02, 0.02), c1, { material = "Fabric" })
		hat("Trim", v3(1.16, 0.1, 0.1), v3(0, 0.58, -0.56), c2, { material = "Fabric" })
	elseif kind == "halo" then
		local segments = ring(ctx, head, "Hat_Halo", v3(0, top + 0.5 * H, 0), 0.5 * H, 10, v3(0.1 * H, 0.08 * H, 0.34 * H), c1, "Neon")
		main = segments[1]
	elseif kind == "ancient" then
		main = hat("Base", v3(1.2, 0.3, 1.2), v3(0, 0.56, 0), c1, { material = "Slate" })
		hat("Mid", v3(0.9, 0.36, 0.9), v3(0, 0.88, 0), PartUtil.shade(c1, 0.85), { material = "Slate" })
		hat("Tip", v3(0.56, 0.4, 0.56), CFrame.new(0.05, 1.22, 0) * CFrame.Angles(0, 0, rad(-10)), c1, { material = "Slate" })
		hat("Band", v3(1.23, 0.1, 1.23), v3(0, 0.5, 0), c2, { material = "Glass", reflectance = 0.3 })
		hat("Drip", v3(0.16, 0.34, 0.1), v3(-0.36, 0.3, -0.62), GOO, { material = "Neon" })
		hat("Drip", v3(0.12, 0.22, 0.1), v3(0.3, 0.36, -0.62), GOO, { material = "Neon" })
	end
	return main
end

----------------------------------------------------------------------
-- GLASSES
----------------------------------------------------------------------
local function buildGlasses(ctx, vis)
	local head, H = ctx.parts.Head, ctx.d.H
	local frameColor, lensColor = vis.color, vis.lens or vis.color
	local z = -0.53
	local eyeY = 0.08
	local lensOpts = { material = "Glass", transparency = vis.clear and 0.55 or 0.05, reflectance = 0.2 }
	local main
	local function piece(name, size, offset, color, opts)
		local cf = typeof(offset) == "Vector3" and CFrame.new(offset * H) or (offset - offset.Position + offset.Position * H)
		return add(ctx, head, "Glasses_" .. name, size * H, cf, color, opts)
	end
	local function temples()
		piece("ArmL", v3(0.04, 0.04, 0.55), v3(-0.52, eyeY, -0.26), frameColor)
		piece("ArmR", v3(0.04, 0.04, 0.55), v3(0.52, eyeY, -0.26), frameColor)
	end
	local kind = vis.kind
	if kind == "visor" then
		local tall = vis.tall and 0.4 or 0.24
		main = piece("Lens", v3(1.02, tall, 0.07), v3(0, eyeY, z), lensColor, { material = "Neon", transparency = 0.1 })
		piece("Bar", v3(1.06, 0.06, 0.09), v3(0, eyeY + tall / 2, z), frameColor)
		temples()
	elseif kind == "goggles" then
		main = piece("Strap", v3(1.07, 0.16, 1.07), v3(0, eyeY, 0), frameColor, { material = "Fabric" })
		for _, x in ipairs({ -0.22, 0.22 }) do
			piece("Rim", v3(0.12, 0.42, 0.42), CFrame.new(x, eyeY, z - 0.03) * PartUtil.FWD, frameColor, { shape = "Cylinder" })
			piece("Lens", v3(0.14, 0.32, 0.32), CFrame.new(x, eyeY, z - 0.04) * PartUtil.FWD, lensColor, { shape = "Cylinder", material = "Neon" })
		end
	else
		for _, x in ipairs({ -0.22, 0.22 }) do
			if kind == "round" then
				main = piece("Rim", v3(0.05, 0.34, 0.34), CFrame.new(x, eyeY, z) * PartUtil.FWD, frameColor, { shape = "Cylinder" })
				piece("Lens", v3(0.06, 0.27, 0.27), CFrame.new(x, eyeY, z) * PartUtil.FWD, lensColor, { shape = "Cylinder", material = "Glass", transparency = lensOpts.transparency })
			elseif kind == "nerd" then
				main = piece("Rim", v3(0.38, 0.32, 0.05), v3(x, eyeY, z), frameColor)
				piece("Lens", v3(0.28, 0.22, 0.06), v3(x, eyeY, z), lensColor, lensOpts)
			elseif kind == "tiny" then
				main = piece("Lens", v3(0.05, 0.2, 0.2), CFrame.new(x, eyeY, z) * PartUtil.FWD * CFrame.new(0, 0, 0), lensColor, { shape = "Cylinder", material = "Glass" })
				piece("Rim", v3(0.24, 0.03, 0.05), v3(x, eyeY + 0.09, z), frameColor)
			elseif kind == "star" then
				main = piece("Star", v3(0.3, 0.3, 0.05), v3(x, eyeY, z), frameColor)
				piece("Star", v3(0.3, 0.3, 0.05), CFrame.new(x, eyeY, z) * CFrame.Angles(0, 0, rad(45)), frameColor)
				piece("Lens", v3(0.06, 0.18, 0.18), CFrame.new(x, eyeY, z) * PartUtil.FWD, lensColor, { shape = "Cylinder", material = "Neon" })
			elseif kind == "heart" then
				main = piece("Heart", v3(0.22, 0.22, 0.05), CFrame.new(x, eyeY - 0.03, z) * CFrame.Angles(0, 0, rad(45)), lensColor, { material = "Glass" })
				piece("Lobe", v3(0.05, 0.19, 0.19), CFrame.new(x - 0.08, eyeY + 0.07, z) * PartUtil.FWD, lensColor, { shape = "Cylinder", material = "Glass" })
				piece("Lobe", v3(0.05, 0.19, 0.19), CFrame.new(x + 0.08, eyeY + 0.07, z) * PartUtil.FWD, lensColor, { shape = "Cylinder", material = "Glass" })
			else -- shades
				main = piece("Lens", v3(0.38, 0.22, 0.05), v3(x, eyeY, z), lensColor, { material = "Glass", reflectance = 0.25 })
			end
		end
		piece("Bridge", v3(0.14, 0.04, 0.05), v3(0, eyeY + 0.03, z), frameColor)
		if kind == "shades" then
			piece("Bar", v3(0.86, 0.05, 0.06), v3(0, eyeY + 0.11, z), frameColor)
		end
		temples()
	end
	return main
end

----------------------------------------------------------------------
-- ACCESSORIES
----------------------------------------------------------------------
local function buildAccessory(ctx, vis)
	local d, parts = ctx.d, ctx.parts
	local torso, S = parts.Torso, d.S
	local c1, c2 = vis.color, vis.color2 or vis.color
	local frontZ = -(ctx.frontDepth or d.torsoD / 2) - 0.05 * S
	local main
	local kind = vis.kind
	if kind == "chain" then
		local size = vis.size or 1
		local link = 0.13 * S * (0.7 + size * 0.3)
		local rx, ry = d.torsoW * 0.36, d.torsoH * 0.26 * size
		local count = 9
		for i = 0, count do
			local t = math.pi + (i / count) * math.pi
			local offset = v3(math.cos(t) * rx, d.torsoH / 2 + math.sin(t) * ry, frontZ)
			main = add(ctx, torso, "Acc_Link", v3(link, link, link), offset, c1, { shape = "Ball", material = "Glass", reflectance = 0.35 })
		end
		local pendant = 0.26 * S * (0.6 + size * 0.4)
		main = add(ctx, torso, "Acc_Pendant", v3(pendant, pendant, pendant), v3(0, d.torsoH / 2 - ry - pendant * 0.4, frontZ - 0.03 * S), c2, { shape = "Ball", material = "Neon" })
	elseif kind == "scarf" then
		main = add(ctx, torso, "Acc_Scarf", v3(d.torsoW * 0.8, 0.3 * S, d.torsoD * 1.4), v3(0, d.torsoH / 2 + 0.08 * S, 0), c1, { material = "Fabric" })
		add(ctx, torso, "Acc_ScarfEnd", v3(0.34 * S, 0.9 * S, 0.12 * S), CFrame.new(-0.4 * S, d.torsoH / 2 - 0.4 * S, frontZ) * CFrame.Angles(0, 0, rad(6)), c1, { material = "Fabric" })
		add(ctx, torso, "Acc_ScarfTip", v3(0.36 * S, 0.16 * S, 0.13 * S), CFrame.new(-0.44 * S, d.torsoH / 2 - 0.8 * S, frontZ) * CFrame.Angles(0, 0, rad(6)), c2, { material = "Fabric" })
	elseif kind == "backpack" then
		local backZ = (ctx.backDepth or d.torsoD / 2)
		main = add(ctx, torso, "Acc_Pack", v3(d.torsoW * 0.76, d.torsoH * 0.72, 0.5 * S), v3(0, 0, backZ + 0.25 * S), c1)
		add(ctx, torso, "Acc_PackPocket", v3(d.torsoW * 0.5, d.torsoH * 0.3, 0.14 * S), v3(0, -d.torsoH * 0.14, backZ + 0.55 * S), c2)
		add(ctx, torso, "Acc_PackStrap", v3(0.14 * S, d.torsoH * 0.92, 0.06 * S), v3(-d.torsoW * 0.32, 0, frontZ), c1)
		add(ctx, torso, "Acc_PackStrap", v3(0.14 * S, d.torsoH * 0.92, 0.06 * S), v3(d.torsoW * 0.32, 0, frontZ), c1)
	elseif kind == "crossbody" then
		add(ctx, torso, "Acc_Strap", v3(0.13 * S, d.torsoH * 1.3, 0.05 * S), CFrame.new(0, 0, frontZ) * CFrame.Angles(0, 0, rad(-38)), c1)
		main = add(ctx, torso, "Acc_Bag", v3(0.75 * S, 0.5 * S, 0.3 * S), v3(d.torsoW * 0.42, -d.torsoH * 0.42, frontZ - 0.1 * S), c1)
		add(ctx, torso, "Acc_BagClip", v3(0.2 * S, 0.12 * S, 0.06 * S), v3(d.torsoW * 0.42, -d.torsoH * 0.36, frontZ - 0.27 * S), c2)
	elseif kind == "headphones" then
		local head, H = parts.Head, d.H
		main = add(ctx, head, "Acc_Band", v3(1.14 * H, 0.1 * H, 0.16 * H), v3(0, 0.56 * H, 0), c1)
		for _, sign in ipairs({ -1, 1 }) do
			add(ctx, head, "Acc_BandSide", v3(0.07 * H, 0.5 * H, 0.14 * H), v3(sign * 0.56 * H, 0.32 * H, 0), c1)
			add(ctx, head, "Acc_Cup", v3(0.18 * H, 0.46 * H, 0.46 * H), v3(sign * 0.6 * H, 0.02 * H, 0), c1, { shape = "Cylinder" })
			add(ctx, head, "Acc_CupRing", v3(0.2 * H, 0.3 * H, 0.3 * H), v3(sign * 0.61 * H, 0.02 * H, 0), c2, { shape = "Cylinder", material = "Neon" })
		end
	elseif kind == "walletchain" then
		local x = d.torsoW / 2 + 0.06 * S
		for i = 0, 6 do
			local t = i / 6
			local offset = v3(x, -d.torsoH / 2 - math.sin(t * math.pi) * 0.7 * S, (t - 0.5) * 0.9 * S)
			main = add(ctx, torso, "Acc_Link", v3(0.12 * S, 0.12 * S, 0.12 * S), offset, c1, { shape = "Ball", material = "Glass", reflectance = 0.35 })
		end
	elseif kind == "wings" then
		local backZ = (ctx.backDepth or d.torsoD / 2) + 0.06 * S
		for _, sign in ipairs({ -1, 1 }) do
			local base = CFrame.new(sign * 0.35 * S, d.torsoH * 0.15, backZ) * CFrame.Angles(0, rad(sign * -28), rad(sign * -18))
			main = add(ctx, torso, "Acc_Wing", v3(0.95 * S, 0.5 * S, 0.08 * S), base * CFrame.new(sign * 0.5 * S, 0.1 * S, 0), c1)
			add(ctx, torso, "Acc_Feather", v3(0.7 * S, 0.34 * S, 0.07 * S), base * CFrame.new(sign * 0.45 * S, -0.26 * S, 0.02 * S), c1)
			add(ctx, torso, "Acc_Feather", v3(0.42 * S, 0.24 * S, 0.06 * S), base * CFrame.new(sign * 0.32 * S, -0.5 * S, 0.04 * S), c2)
		end
	elseif kind == "tote" then
		local arm = parts.RightArm
		local material = vis.shiny and "Glass" or "Fabric"
		main = add(ctx, arm, "Acc_Tote", v3(0.34 * S, 0.85 * S, 0.95 * S), v3(0, -d.armH / 2 - 0.62 * S, 0), c1, { material = material, reflectance = vis.shiny and 0.35 or 0 })
		add(ctx, arm, "Acc_ToteHandle", v3(0.06 * S, 0.3 * S, 0.06 * S), v3(0, -d.armH / 2 - 0.1 * S, -0.26 * S), c2)
		add(ctx, arm, "Acc_ToteHandle", v3(0.06 * S, 0.3 * S, 0.06 * S), v3(0, -d.armH / 2 - 0.1 * S, 0.26 * S), c2)
		add(ctx, arm, "Acc_ToteStripe", v3(0.36 * S, 0.14 * S, 0.97 * S), v3(0, -d.armH / 2 - 0.5 * S, 0), c2, { material = material })
	elseif kind == "aura" then
		local shards = ring(ctx, torso, "Acc_Aura", v3(0, -d.torsoH * 0.1, 0), 1.7 * S, 8, v3(0.14 * S, 0.5 * S, 0.14 * S), c1, "Neon")
		for i, shard in ipairs(shards) do
			if i % 2 == 0 then
				shard.Color = c2
			end
		end
		main = torso
	elseif kind == "orb" then
		main = add(ctx, torso, "Acc_Orb", v3(0.7 * S, 0.7 * S, 0.7 * S), v3(d.torsoW / 2 + 1.0 * S, d.torsoH / 2 + 0.7 * S, 0), c1, { shape = "Ball", material = "Neon" })
		add(ctx, torso, "Acc_OrbBlob", v3(0.34 * S, 0.34 * S, 0.34 * S), v3(d.torsoW / 2 + 1.35 * S, d.torsoH / 2 + 0.4 * S, 0.1 * S), c2, { shape = "Ball", material = "Neon" })
		add(ctx, torso, "Acc_OrbEye", v3(0.1 * S, 0.14 * S, 0.06 * S), v3(d.torsoW / 2 + 0.88 * S, d.torsoH / 2 + 0.76 * S, -0.33 * S), DARK)
		add(ctx, torso, "Acc_OrbEye", v3(0.1 * S, 0.14 * S, 0.06 * S), v3(d.torsoW / 2 + 1.12 * S, d.torsoH / 2 + 0.76 * S, -0.33 * S), DARK)
	end
	return main
end

----------------------------------------------------------------------
-- NAMEPLATE
----------------------------------------------------------------------
local function buildNameplate(ctx, spec)
	local head, d = ctx.parts.Head, ctx.d
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Size = UDim2.fromScale(8, 2.4)
	gui.StudsOffsetWorldSpace = Vector3.new(0, d.H / 2 + 2.1, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false

	local function line(name, text, y, height, color, font)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0, y)
		label.Size = UDim2.fromScale(1, height)
		label.Font = font or Enum.Font.FredokaOne
		label.Text = text
		label.TextScaled = true
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.25
		label.Parent = gui
		return label
	end

	local stars = string.rep("★", math.min(spec.rebirths or 0, 5))
	local title = spec.title
	local hasTitle = title and title.name and title.name ~= ""
	if hasTitle then
		line("Title", "« " .. title.name .. " »", 0, 0.28, title.color or rgb(255, 205, 60))
	end
	local owner = line("Owner", (stars ~= "" and stars .. " " or "") .. (spec.ownerName or "???") .. "'s Brady", 0.28, 0.4, Color3.new(1, 1, 1))
	line("Stage", ctx.stage.name .. " • Age " .. spec.age, 0.68, 0.3, rgb(200, 255, 170), Enum.Font.GothamBold)

	if ctx.specials.nameplate == "Grail" then
		-- unique Grail nameplate: rainbow gradient + sparkles
		owner.Text = "✦ " .. owner.Text .. " ✦"
		local gradient = Instance.new("UIGradient")
		gradient.Name = "GrailGradient"
		gradient.Color = RAINBOW
		gradient.Parent = owner
		gui:SetAttribute("Grail", true)
	end
	gui.Parent = head
	return gui
end

----------------------------------------------------------------------
-- build(spec) -> Model
-- spec = {
--   age, equipped = { slot = itemId },
--   ownerName, ownerUserId, title = { name, color }, rebirths,
--   hairOverride (item id), noShoes (lost-shoes event), aura (fx key),
--   preview = true for client-side ViewportFrame models (no particles/nameplate)
-- }
----------------------------------------------------------------------
function BradyBuilder.build(spec)
	local age = spec.age or 1
	local equipped = spec.equipped or {}
	local stage = AgeSystem.getStage(age)
	local d = BradyBuilder.dimensions(age)
	local S = d.S
	local specials = InventorySystem.specials(equipped)

	local model = Instance.new("Model")
	model.Name = "Brady"

	local ctx = { model = model, d = d, stage = stage, preview = spec.preview == true, parts = {}, specials = specials, lift = 0 }

	-- Work out what is actually worn. A full outfit replaces the 4 body slots.
	local function visOf(slot)
		local item = equipped[slot] and ClothingSystem.get(equipped[slot])
		return item and item.vis, item
	end
	local outfitVis, outfitItem = visOf("Outfit")
	local shirtVis, shirtItem = visOf("Shirt")
	local pantsVis, pantsItem = visOf("Pants")
	local shoesVis, shoesItem = visOf("Shoes")
	local jacketVis, jacketItem = visOf("Jacket")
	local hatVis, hatItem = visOf("Hat")
	local glassesVis, glassesItem = visOf("Glasses")
	local accVis, accItem = visOf("Accessory")
	if outfitVis then
		shirtVis, pantsVis, shoesVis, jacketVis = outfitVis.shirt, outfitVis.pants, outfitVis.shoes, outfitVis.jacket
		shirtItem, pantsItem, shoesItem, jacketItem = nil, nil, nil, nil
		hatVis = hatVis or outfitVis.hat
		glassesVis = glassesVis or outfitVis.glasses
		accVis = accVis or outfitVis.accessory
	end
	if spec.noShoes then
		shoesVis, shoesItem = nil, nil
	end
	-- Platform shoes lift the whole body so the soles still touch the floor.
	if shoesVis and shoesVis.platform then
		ctx.lift = shoesVis.platform * S
	end
	local lift = ctx.lift

	-- ROOT ---------------------------------------------------------------
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = v3(math.max(1, d.torsoW), 0.2, math.max(1, d.torsoD))
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	-- BODY ---------------------------------------------------------------
	local function limb(name, size, position)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = SKIN
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CFrame = CFrame.new(position)
		part.Parent = model
		ctx.parts[name] = part
		return part
	end
	local hipY = d.legH + lift
	local torso = limb("Torso", v3(d.torsoW, d.torsoH, d.torsoD), v3(0, hipY + d.torsoH / 2, 0))
	local head = limb("Head", v3(d.H, d.H, d.H), v3(0, hipY + d.torsoH + d.H / 2 - 0.03 * S, 0))
	local armX = d.torsoW / 2 + d.armW / 2
	local armY = hipY + d.torsoH - d.armH / 2
	local leftArm = limb("LeftArm", v3(d.armW, d.armH, d.armW), v3(-armX, armY, 0))
	local rightArm = limb("RightArm", v3(d.armW, d.armH, d.armW), v3(armX, armY, 0))
	local legX = 0.5 * S
	local leftLeg = limb("LeftLeg", v3(d.legW, d.legH, d.legW), v3(-legX, lift + d.legH / 2, 0))
	local rightLeg = limb("RightLeg", v3(d.legW, d.legH, d.legW), v3(legX, lift + d.legH / 2, 0))
	torso.Color = UNDERSHIRT

	-- JOINTS -------------------------------------------------------------
	local function joint(name, part0, part1, worldPosition)
		local motor = Instance.new("Motor6D")
		motor.Name = name
		local pivot = CFrame.new(worldPosition)
		motor.C0 = part0.CFrame:ToObjectSpace(pivot)
		motor.C1 = part1.CFrame:ToObjectSpace(pivot)
		motor.Part0 = part0
		motor.Part1 = part1
		motor.Parent = part0
		return motor
	end
	joint("Waist", root, torso, v3(0, hipY, 0))
	joint("Neck", torso, head, v3(0, hipY + d.torsoH, 0))
	joint("LeftShoulder", torso, leftArm, v3(-armX, hipY + d.torsoH - 0.2 * S, 0))
	joint("RightShoulder", torso, rightArm, v3(armX, hipY + d.torsoH - 0.2 * S, 0))
	joint("LeftHip", torso, leftLeg, v3(-legX, hipY, 0))
	joint("RightHip", torso, rightLeg, v3(legX, hipY, 0))

	-- FACE + HAIR --------------------------------------------------------
	if ctx.preview then
		buildPreviewFace(ctx, stage.look.face)
	else
		buildFace(head, stage.look.face)
	end
	local hairId = spec.hairOverride or equipped.Hair or stage.look.hair
	local hairItem = ClothingSystem.get(hairId) or ClothingSystem.get(stage.look.hair)
	local hairPart = buildHair(ctx, hairItem.vis, hatVis)

	-- CLOTHES ------------------------------------------------------------
	local fxTargets = {} -- { part, fxKey }
	local function fx(item, part)
		if item and item.fx and part then
			table.insert(fxTargets, { part, item.fx })
		end
	end

	if pantsVis then
		fx(pantsItem, buildPants(ctx, pantsVis))
	else
		buildUnderwear(ctx)
	end
	if shoesVis then
		fx(shoesItem, buildShoes(ctx, shoesVis))
	end
	local shirtFront = torso
	if shirtVis then
		shirtFront = buildShirt(ctx, shirtVis)
		fx(shirtItem, torso)
	end
	ctx.frontDepth = shirtFront.Size.Z / 2
	ctx.backDepth = shirtFront.Size.Z / 2
	if jacketVis then
		fx(jacketItem, buildJacket(ctx, jacketVis))
		local bulk = (jacketVis.bulk or 0.14) * S
		ctx.frontDepth = d.torsoD / 2 + bulk
		ctx.backDepth = d.torsoD / 2 + bulk
	end
	if hatVis then
		fx(hatItem, buildHat(ctx, hatVis))
	end
	if glassesVis then
		fx(glassesItem, buildGlasses(ctx, glassesVis))
	end
	if accVis then
		fx(accItem, buildAccessory(ctx, accVis))
	end
	fx(hairItem, hairPart or head)
	fx(outfitItem, torso)
	if spec.aura and spec.aura ~= "none" then
		table.insert(fxTargets, { torso, spec.aura })
	end
	-- Legendary Brady Goo always has a faint golden glow.
	if stage.id == "Legendary" then
		table.insert(fxTargets, { head, "gold" })
	end
	-- At most 4 emitters per Brady (performance), rarest pieces were added last.
	for i = math.max(1, #fxTargets - 3), #fxTargets do
		addFx(ctx, fxTargets[i][1], fxTargets[i][2])
	end

	-- ATTRIBUTES (read by the animator and the UI) -----------------------
	model:SetAttribute("Age", age)
	model:SetAttribute("Stage", stage.id)
	model:SetAttribute("Scale", S)
	model:SetAttribute("HipHeight", hipY)
	model:SetAttribute("Height", d.height + lift)
	model:SetAttribute("IdleStyle", specials.idle or stage.look.idle)
	model:SetAttribute("WalkStyle", specials.walk or stage.look.walk)
	model:SetAttribute("State", "Idle")
	model:SetAttribute("Pose", "")
	model:SetAttribute("OwnerUserId", spec.ownerUserId or 0)
	model:SetAttribute("OwnerName", spec.ownerName or "")
	model:SetAttribute("Embarrassed", InventorySystem.isBadFit(equipped))

	if not ctx.preview then
		buildNameplate(ctx, spec)
		CollectionService:AddTag(model, BradyBuilder.Tag)
	end
	return model
end

-- Height of the model for an age (preview camera framing).
function BradyBuilder.heightFor(age)
	return BradyBuilder.dimensions(age).height
end

return BradyBuilder
