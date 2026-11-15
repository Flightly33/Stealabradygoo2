--[[
	GiftBuilder
	Builds the wearable gifts Brady gives the PLAYER as real Accessory
	instances made of parts. Humanoid:AddAccessory() snaps them onto the
	matching attachment of any avatar (R6 or R15, any body scale).
]]

local Modules = script.Parent.Parent
local GiftSystem = require(Modules.GiftSystem)
local PartUtil = require(script.Parent.PartUtil)

local GiftBuilder = {}

local v3 = Vector3.new
local rad = math.rad

-- Which avatar attachment each gift slot uses.
local ATTACHMENT = {
	Head = "HatAttachment",
	Face = "FaceFrontAttachment",
	Neck = "NeckAttachment",
	Back = "BodyBackAttachment",
	Aura = "BodyBackAttachment",
}

GiftBuilder.Prefix = "BradyGift_"

-- Each recipe returns: handleSize, attachmentCFrame (relative to the handle).
-- add(name, size, offset, color, opts) welds extra parts to the handle.
local RECIPES = {}

function RECIPES.bucket(handle, add, gift)
	handle.Size = v3(1.3, 0.5, 1.3)
	handle.Material = Enum.Material.Fabric
	add("Brim", v3(0.1, 2.1, 2.1), CFrame.new(0, -0.2, 0) * PartUtil.UP, gift.color2, { shape = "Cylinder", material = "Fabric" })
	return CFrame.new(0, -0.15, 0)
end

function RECIPES.cap(handle, add, gift)
	handle.Size = v3(1.3, 0.45, 1.3)
	handle.Material = Enum.Material.Fabric
	add("Brim", v3(1.1, 0.08, 0.7), v3(0, -0.16, -0.9), gift.color2)
	add("Button", v3(0.16, 0.1, 0.16), v3(0, 0.26, 0), gift.color2)
	return CFrame.new(0, -0.12, 0)
end

function RECIPES.crown(handle, add, gift)
	handle.Size = v3(1.1, 0.25, 1.1)
	handle.Material = Enum.Material.Glass
	handle.Reflectance = 0.3
	for i = 1, 6 do
		local a = (i - 1) / 6 * math.pi * 2
		add("Point", v3(0.2, 0.4, 0.2), v3(math.cos(a) * 0.44, 0.3, math.sin(a) * 0.44), gift.color, { material = "Glass", reflectance = 0.3 })
		add("Gem", v3(0.14, 0.14, 0.14), v3(math.cos(a) * 0.56, 0, math.sin(a) * 0.56), gift.color2, { shape = "Ball", material = "Neon" })
	end
	return CFrame.new(0, -0.1, 0)
end

function RECIPES.headphones(handle, add, gift)
	handle.Size = v3(1.4, 0.12, 0.2)
	for _, sign in ipairs({ -1, 1 }) do
		add("Side", v3(0.08, 0.6, 0.16), v3(sign * 0.68, -0.3, 0), gift.color)
		add("Cup", v3(0.2, 0.55, 0.55), v3(sign * 0.72, -0.65, 0), gift.color, { shape = "Cylinder" })
		add("Ring", v3(0.22, 0.35, 0.35), v3(sign * 0.73, -0.65, 0), gift.color2, { shape = "Cylinder", material = "Neon" })
	end
	return CFrame.new(0, -0.02, 0)
end

function RECIPES.shades(handle, add, gift)
	handle.Size = v3(1.15, 0.08, 0.08)
	add("LensL", v3(0.46, 0.3, 0.06), v3(-0.28, -0.14, -0.02), gift.color2, { material = "Glass", reflectance = 0.25 })
	add("LensR", v3(0.46, 0.3, 0.06), v3(0.28, -0.14, -0.02), gift.color2, { material = "Glass", reflectance = 0.25 })
	add("ArmL", v3(0.05, 0.05, 0.6), v3(-0.57, 0, 0.3), gift.color)
	add("ArmR", v3(0.05, 0.05, 0.6), v3(0.57, 0, 0.3), gift.color)
	return CFrame.new(0, -0.2, 0.06)
end

function RECIPES.chain(handle, add, gift)
	handle.Size = v3(0.2, 0.2, 0.2)
	handle.Transparency = 1
	for i = 0, 9 do
		local t = math.pi + (i / 9) * math.pi
		add("Link", v3(0.16, 0.16, 0.16), v3(math.cos(t) * 0.6, math.sin(t) * 0.7 - 0.05, -0.55), gift.color, { shape = "Ball", material = "Glass", reflectance = 0.35 })
	end
	add("Pendant", v3(0.34, 0.34, 0.34), v3(0, -0.9, -0.6), gift.color2, { shape = "Ball", material = "Neon" })
	return CFrame.new(0, 0, 0)
end

function RECIPES.scarf(handle, add, gift)
	handle.Size = v3(1.5, 0.4, 1.3)
	handle.Material = Enum.Material.Fabric
	add("End", v3(0.4, 1.2, 0.14), CFrame.new(-0.4, -0.7, -0.62) * CFrame.Angles(0, 0, rad(6)), gift.color, { material = "Fabric" })
	add("Tip", v3(0.42, 0.2, 0.15), CFrame.new(-0.45, -1.25, -0.62) * CFrame.Angles(0, 0, rad(6)), gift.color2, { material = "Fabric" })
	return CFrame.new(0, 0.05, 0)
end

function RECIPES.backpack(handle, add, gift)
	handle.Size = v3(1.5, 1.6, 0.7)
	add("Pocket", v3(1, 0.6, 0.2), v3(0, -0.3, 0.42), gift.color2)
	add("Top", v3(1.3, 0.2, 0.6), v3(0, 0.85, 0), gift.color2)
	return CFrame.new(0, 0, -0.38)
end

function RECIPES.cape(handle, add, gift)
	handle.Size = v3(2.1, 0.3, 0.3)
	handle.Material = Enum.Material.Fabric
	add("Cloth", v3(2.1, 3.6, 0.12), CFrame.new(0, -1.9, 0.35) * CFrame.Angles(rad(-9), 0, 0), gift.color, { material = "Fabric" })
	add("Lining", v3(1.9, 3.4, 0.05), CFrame.new(0, -1.9, 0.27) * CFrame.Angles(rad(-9), 0, 0), gift.color2, { material = "Fabric" })
	add("Tatter", v3(0.5, 0.6, 0.12), CFrame.new(-0.7, -3.9, 0.66) * CFrame.Angles(rad(-9), 0, rad(8)), gift.color, { material = "Fabric" })
	add("Tatter", v3(0.4, 0.8, 0.12), CFrame.new(0.5, -4, 0.68) * CFrame.Angles(rad(-9), 0, rad(-6)), gift.color, { material = "Fabric" })
	return CFrame.new(0, -0.85, -0.12)
end

function RECIPES.aura(handle, add, gift)
	handle.Size = v3(1, 1, 1)
	handle.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Aura"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 10
	emitter.Lifetime = NumberRange.new(0.8, 1.5)
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.5, 0)
	emitter.LightEmission = 0.8
	emitter.Color = ColorSequence.new(gift.color, gift.color2)
	emitter.Parent = handle
	local light = Instance.new("PointLight")
	light.Color = gift.color
	light.Range = 10
	light.Brightness = 0.9
	light.Shadows = false
	light.Parent = handle
	return CFrame.new(0, 0, -0.6)
end

-- build(giftId) -> Accessory (or nil for an unknown id)
function GiftBuilder.build(giftId)
	local gift = GiftSystem.get(giftId)
	local recipe = gift and RECIPES[gift.kind]
	if not recipe then
		return nil
	end
	local accessory = Instance.new("Accessory")
	accessory.Name = GiftBuilder.Prefix .. gift.slot

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Color = gift.color
	handle.Material = Enum.Material.SmoothPlastic
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.CFrame = CFrame.new()

	local function add(name, size, offset, color, opts)
		opts = opts or {}
		return PartUtil.attach(handle, handle, {
			name = name,
			size = size,
			offset = offset,
			color = color,
			material = opts.material,
			shape = opts.shape,
			reflectance = opts.reflectance,
		})
	end

	local attachmentCFrame = recipe(handle, add, gift)
	local attachment = Instance.new("Attachment")
	attachment.Name = ATTACHMENT[gift.slot]
	attachment.CFrame = attachmentCFrame
	attachment.Parent = handle
	handle.Parent = accessory
	accessory:SetAttribute("GiftId", giftId)
	return accessory
end

return GiftBuilder
