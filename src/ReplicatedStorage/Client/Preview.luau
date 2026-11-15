--[[
	Preview
	A little 3D Brady inside a ViewportFrame, used by the Brady panel, the
	wardrobe and the inspect window. It is built with the same BradyBuilder
	the server uses, so what you see in the preview is what everyone sees.

	    local preview = Preview.new(parentFrame, { Size = ... })
	    preview.set({ age = 13, equipped = data.equipped })
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local BradyBuilder = require(Modules:WaitForChild("Builders"):WaitForChild("BradyBuilder"))

local Preview = {}

local active = {} -- previews that are currently spinning
local connection

local function ensureLoop()
	if connection then
		return
	end
	-- One shared loop turns every visible preview slowly.
	connection = RunService.RenderStepped:Connect(function(dt)
		for preview in pairs(active) do
			local frame = preview.frame
			if not frame.Parent then
				active[preview] = nil
			elseif preview.model and preview.isVisible() then
				preview.angle += dt * 0.6
				preview.aim()
			end
		end
	end)
end

function Preview.new(parent, props)
	props = props or {}
	local frame = Instance.new("ViewportFrame")
	frame.Name = props.Name or "BradyPreview"
	frame.Size = props.Size or UDim2.fromScale(1, 1)
	frame.Position = props.Position or UDim2.new()
	frame.AnchorPoint = props.AnchorPoint or Vector2.new()
	frame.BackgroundColor3 = props.Color or Color3.fromRGB(46, 42, 72)
	frame.BackgroundTransparency = props.Transparency or 0
	frame.BorderSizePixel = 0
	frame.Ambient = Color3.fromRGB(190, 190, 200)
	frame.LightColor = Color3.fromRGB(255, 255, 255)
	frame.LightDirection = Vector3.new(-1, -1.5, 1)
	frame.LayoutOrder = props.LayoutOrder or 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame

	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	camera.Parent = frame
	frame.CurrentCamera = camera
	frame.Parent = parent

	local preview = { frame = frame, camera = camera, model = nil, angle = props.Angle or 0.5, height = 4 }

	-- Is the preview (and every ancestor) actually on screen?
	function preview.isVisible()
		local node = frame
		while node and node:IsA("GuiObject") do
			if not node.Visible then
				return false
			end
			node = node.Parent
		end
		return true
	end

	-- Orbit the camera around Brady (he faces -Z).
	function preview.aim()
		local h = preview.height
		local distance = h * 1.9 + 3
		local target = Vector3.new(0, h * 0.5, 0)
		local offset = Vector3.new(math.sin(preview.angle) * distance, h * 0.15, -math.cos(preview.angle) * distance)
		camera.CFrame = CFrame.lookAt(target + offset, target)
	end

	-- spec = { age, equipped, hairOverride }
	function preview.set(spec)
		if preview.model then
			preview.model:Destroy()
			preview.model = nil
		end
		local model = BradyBuilder.build({
			age = spec.age,
			equipped = spec.equipped,
			hairOverride = spec.hairOverride,
			preview = true,
		})
		preview.height = model:GetAttribute("Height") or 4
		model.Parent = frame
		preview.model = model
		preview.aim()
	end

	function preview.destroy()
		active[preview] = nil
		frame:Destroy()
	end

	if props.Spin ~= false then
		active[preview] = true
		ensureLoop()
	end
	return preview
end

return Preview
