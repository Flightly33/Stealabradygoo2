--[[
	PartUtil
	Tiny helpers for building things out of plain Parts in code.
	The whole game (Brady, clothes, houses, furniture, the map) is assembled
	from primitives, so there are zero uploaded meshes or images to manage.
]]

local PartUtil = {}

PartUtil.UP = CFrame.Angles(0, 0, math.rad(90)) -- stands a Cylinder upright (axis -> Y)
PartUtil.FWD = CFrame.Angles(0, math.rad(90), 0) -- points a Cylinder's axis along Z

local function materialOf(material)
	if material == nil then
		return Enum.Material.SmoothPlastic
	elseif type(material) == "string" then
		return Enum.Material[material]
	end
	return material
end

local function finish(part, props)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = materialOf(props.material)
	if props.shape then
		part.Shape = Enum.PartType[props.shape]
	end
	if props.name then
		part.Name = props.name
	end
	if props.size then
		part.Size = props.size
	end
	if props.color then
		part.Color = props.color
	end
	if props.transparency then
		part.Transparency = props.transparency
	end
	if props.reflectance then
		part.Reflectance = props.reflectance
	end
	if props.cframe then
		part.CFrame = props.cframe
	end
end

-- A static, anchored world part (map, houses, furniture).
-- props: name, size, cframe, color, material, shape, transparency, collide, class
function PartUtil.block(parent, props)
	local part = Instance.new(props.class or "Part")
	part.Anchored = true
	part.CanCollide = props.collide ~= false
	if props.collide == false then
		part.CanTouch = false
		part.CanQuery = false
	end
	part.CastShadow = props.shadow ~= false
	finish(part, props)
	part.Parent = parent
	return part
end

-- A decorative, non-colliding, massless part welded to `base` at `offset`
-- (offset is relative to the base part's CFrame). Used for Brady + clothing.
function PartUtil.attach(parent, base, props)
	local part = Instance.new(props.class or "Part")
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = props.shadow == true
	finish(part, props)
	local offset = props.offset or CFrame.new()
	if typeof(offset) == "Vector3" then
		offset = CFrame.new(offset)
	end
	part.CFrame = base.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = part
	weld.Parent = part
	part.Parent = parent
	return part
end

-- Darken / lighten a colour (factor < 1 darkens).
function PartUtil.shade(color, factor)
	return Color3.new(math.clamp(color.R * factor, 0, 1), math.clamp(color.G * factor, 0, 1), math.clamp(color.B * factor, 0, 1))
end

-- A sign: text drawn on one face of a part with a SurfaceGui.
function PartUtil.label(part, text, props)
	props = props or {}
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label"
	gui.Face = props.face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = props.pixelsPerStud or 30
	gui.LightInfluence = props.lightInfluence or 0
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = props.font or Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = props.color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = props.stroke == false and 1 or 0.4
	label.Parent = gui
	gui.Parent = part
	return gui, label
end

-- A ProximityPrompt with the options every prompt in the game uses.
function PartUtil.prompt(parent, actionText, objectText, props)
	props = props or {}
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText or ""
	prompt.HoldDuration = props.hold or 0
	prompt.MaxActivationDistance = props.distance or 9
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = props.key or Enum.KeyCode.E
	prompt.Name = props.name or "Prompt"
	prompt.Parent = parent
	return prompt
end

return PartUtil
