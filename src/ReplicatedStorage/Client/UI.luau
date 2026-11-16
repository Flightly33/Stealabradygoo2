--[[
	UI kit
	Shared look + building blocks for every screen, so the whole game has one
	consistent chunky, colourful style and each UI script stays short.

	Everything is built in code (no image assets): rounded frames, thick
	outlines, emoji icons. Layout is authored against a reference screen and
	scaled with UIScale, which keeps buttons big and readable on phones,
	tablets and PC alike.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ClothingSystem = require(Modules:WaitForChild("ClothingSystem"))
local State = require(script.Parent:WaitForChild("ClientState"))

local UI = {}

local rgb = Color3.fromRGB

UI.Colors = {
	bg = rgb(30, 27, 48),
	panel = rgb(46, 42, 72),
	panel2 = rgb(62, 57, 96),
	dark = rgb(18, 16, 30),
	text = rgb(255, 255, 255),
	sub = rgb(198, 198, 222),
	goo = rgb(126, 232, 74),
	gooDark = rgb(64, 168, 52),
	gold = rgb(255, 205, 60),
	red = rgb(232, 66, 78),
	blue = rgb(72, 150, 255),
	pink = rgb(255, 110, 225),
	purple = rgb(178, 92, 255),
	grey = rgb(110, 108, 132),
}

UI.TitleFont = Enum.Font.FredokaOne
UI.BodyFont = Enum.Font.GothamBold
UI.LoudFont = Enum.Font.LuckiestGuy

----------------------------------------------------------------------
-- Basics
----------------------------------------------------------------------
-- UI.new("Frame", { Size = ..., Parent = x }, { child, child })
function UI.new(className, props, children)
	local instance = Instance.new(className)
	local parent
	if props then
		for key, value in pairs(props) do
			if key == "Parent" then
				parent = value
			else
				instance[key] = value
			end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UI.corner(parent, radius)
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 12), Parent = parent })
end

function UI.stroke(parent, thickness, color, transparency)
	return UI.new("UIStroke", {
		Thickness = thickness or 2,
		Color = color or UI.Colors.dark,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function UI.pad(parent, left, top, right, bottom)
	top = top or left
	right = right or left
	bottom = bottom or top
	return UI.new("UIPadding", {
		PaddingLeft = UDim.new(0, left),
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right),
		PaddingBottom = UDim.new(0, bottom),
		Parent = parent,
	})
end

-- opts: horizontal (bool), pad, alignX, alignY, wraps
function UI.list(parent, opts)
	opts = opts or {}
	return UI.new("UIListLayout", {
		FillDirection = opts.horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, opts.pad or 6),
		HorizontalAlignment = opts.alignX or Enum.HorizontalAlignment.Left,
		VerticalAlignment = opts.alignY or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Wraps = opts.wraps == true,
		Parent = parent,
	})
end

function UI.grid(parent, cellWidth, cellHeight, pad)
	return UI.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(cellWidth, cellHeight),
		CellPadding = UDim2.fromOffset(pad or 8, pad or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

-- A vertical light-to-dark gradient. UIGradient multiplies the object's own
-- colour, so the top stays at full colour and the bottom gets `dark` times it.
function UI.gradient(guiObject, dark, rotation)
	local value = dark or 0.78
	return UI.new("UIGradient", {
		Name = "Shade",
		Rotation = rotation or 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(value, value, value)),
		Parent = guiObject,
	})
end

function UI.frame(parent, props)
	props = props or {}
	local frame = UI.new("Frame", {
		Name = props.Name or "Frame",
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		BackgroundColor3 = props.Color or UI.Colors.panel,
		BackgroundTransparency = props.Transparency or 0,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		Visible = props.Visible ~= false,
		ClipsDescendants = props.Clips == true,
		Parent = parent,
	})
	if props.Corner ~= false then
		UI.corner(frame, props.Corner or 12)
	end
	if props.Stroke then
		UI.stroke(frame, props.Stroke, props.StrokeColor)
	end
	return frame
end

-- A transparent container.
function UI.box(parent, props)
	props = props or {}
	props.Transparency = 1
	props.Corner = false
	return UI.frame(parent, props)
end

function UI.label(parent, text, props)
	props = props or {}
	local label = UI.new("TextLabel", {
		Name = props.Name or "Label",
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		BackgroundTransparency = 1,
		Font = props.Font or UI.TitleFont,
		Text = text or "",
		TextSize = props.TextSize or 18,
		TextColor3 = props.Color or UI.Colors.text,
		TextXAlignment = props.AlignX or Enum.TextXAlignment.Center,
		TextYAlignment = props.AlignY or Enum.TextYAlignment.Center,
		TextWrapped = props.Wrapped ~= false,
		TextScaled = props.Scaled == true,
		TextTransparency = props.TextTransparency or 0,
		RichText = props.Rich == true,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		Parent = parent,
	})
	if props.Outline then
		-- chunky cartoon outline around the text
		UI.new("UIStroke", { Thickness = props.Outline, Color = props.OutlineColor or UI.Colors.dark, Parent = label })
	end
	return label
end

function UI.tween(instance, seconds, goals, style, direction)
	local tween = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goals)
	tween:Play()
	return tween
end

-- Squash-and-pop used when things appear.
-- A GuiObject should only ever have ONE UIScale, so this reuses the object's
-- existing scale (auto-scale or button press scale) when it has one and
-- animates back to that scale's resting value.
function UI.pop(guiObject, from)
	local scale = guiObject:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = UI.new("UIScale", { Name = "PopScale", Parent = guiObject })
	end
	local rest = scale:GetAttribute("Rest") or 1
	scale.Scale = rest * (from or 0.7)
	UI.tween(scale, 0.25, { Scale = rest }, Enum.EasingStyle.Back)
end

-- A chunky button. props: Size, Position, AnchorPoint, Color, TextColor,
-- TextSize, LayoutOrder, Name, Corner, Silent (no click sound)
function UI.button(parent, text, props, onClick)
	props = props or {}
	local color = props.Color or UI.Colors.goo
	local button = UI.new("TextButton", {
		Name = props.Name or "Button",
		Size = props.Size or UDim2.fromOffset(140, 44),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = props.Font or UI.TitleFont,
		Text = text or "",
		TextSize = props.TextSize or 20,
		TextColor3 = props.TextColor or UI.Colors.dark,
		TextWrapped = true,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		Parent = parent,
	})
	UI.corner(button, props.Corner or 12)
	UI.stroke(button, 3, UI.Colors.dark)
	UI.gradient(button, 0.74)
	local gloss = UI.new("Frame", {
		Name = "Gloss",
		Size = UDim2.new(1, -10, 0.32, 0),
		Position = UDim2.fromOffset(5, 3),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		ZIndex = (props.ZIndex or 1),
		Parent = button,
	})
	UI.corner(gloss, props.Corner or 12)
	local press = UI.new("UIScale", { Name = "Press", Parent = button })
	button.MouseButton1Down:Connect(function()
		UI.tween(press, 0.06, { Scale = 0.93 })
	end)
	button.MouseButton1Up:Connect(function()
		UI.tween(press, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	button.MouseLeave:Connect(function()
		UI.tween(press, 0.12, { Scale = 1 })
	end)
	if onClick then
		button.Activated:Connect(function()
			if not props.Silent then
				State.sound("click")
			end
			onClick(button)
		end)
	end
	return button
end

-- Greys a button out (it still fires, the caller decides what to do).
function UI.setEnabled(button, enabled, color)
	button.BackgroundColor3 = enabled and (color or UI.Colors.goo) or UI.Colors.grey
	button.TextTransparency = enabled and 0 or 0.35
	button:SetAttribute("Disabled", not enabled)
end

function UI.scroll(parent, props)
	props = props or {}
	return UI.new("ScrollingFrame", {
		Name = props.Name or "Scroll",
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = UI.Colors.goo,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	})
end

-- Removes every child except layout / padding objects.
function UI.clear(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- Progress bar. Returns { frame, fill, label, set(ratio, text) }
function UI.bar(parent, props)
	props = props or {}
	local frame = UI.frame(parent, {
		Name = props.Name or "Bar",
		Size = props.Size or UDim2.new(1, 0, 0, 20),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Color = UI.Colors.dark,
		Corner = props.Corner or 8,
		LayoutOrder = props.LayoutOrder,
	})
	local fill = UI.frame(frame, { Name = "Fill", Size = UDim2.fromScale(0, 1), Color = props.Color or UI.Colors.goo, Corner = props.Corner or 8 })
	UI.gradient(fill, 0.7)
	local label = UI.label(frame, "", { Name = "Text", TextSize = props.TextSize or 13, Font = UI.BodyFont, ZIndex = 2 })
	local bar = { frame = frame, fill = fill, label = label }
	function bar.set(ratio, text, color)
		ratio = math.clamp(ratio or 0, 0, 1)
		UI.tween(fill, 0.25, { Size = UDim2.fromScale(ratio, 1) })
		if text then
			label.Text = text
		end
		if color then
			fill.BackgroundColor3 = color
		end
	end
	return bar
end

----------------------------------------------------------------------
-- Scaling for every screen size
----------------------------------------------------------------------
-- kind "window": big centred panels (nearly fill a phone screen)
-- kind "hud":    always-visible clusters at the screen edges
function UI.autoScale(guiObject, kind)
	local scale = UI.new("UIScale", { Name = "AutoScale", Parent = guiObject })
	local function update()
		local camera = Workspace.CurrentCamera
		local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
		local value
		if kind == "window" then
			value = math.clamp(math.min(size.X / 820, size.Y / 500), 0.55, 1.35)
		else
			value = math.clamp(math.min(size.X / 1100, size.Y / 640), 0.62, 1.25)
		end
		scale:SetAttribute("Rest", value) -- UI.pop animates back to this
		scale.Scale = value
	end
	update()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	return scale
end

----------------------------------------------------------------------
-- Windows
----------------------------------------------------------------------
-- A centred window bound to a panel name. It shows itself when
-- State.open(name) is called and hides when any other window opens.
-- opts: name, title, width, height
-- Returns { root, body, title, visible, onShow(fn), onHide(fn), setTitle }
function UI.window(screenGui, opts)
	local window = { visible = false }
	local showHandlers, hideHandlers = {}, {}

	-- root is an invisible container so the window can have a drop shadow
	-- behind it (children always draw above their parent in Roblox).
	local root = UI.box(screenGui, {
		Name = opts.name .. "Window",
		Size = UDim2.fromOffset(opts.width or 760, opts.height or 460),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
	})
	UI.autoScale(root, "window")
	local shadow = UI.frame(root, { Name = "Shadow", Size = UDim2.new(1, 8, 1, 10), Position = UDim2.fromOffset(2, 8), Color = Color3.new(0, 0, 0), Transparency = 0.55, Corner = 24 })
	shadow.ZIndex = 0
	local panel = UI.frame(root, { Name = "Panel", Color = UI.Colors.bg, Corner = 20 })
	UI.stroke(panel, 4, UI.Colors.goo)
	UI.gradient(panel, 0.72)
	-- swallow clicks so the world behind the window is not tapped through
	panel.Active = true

	local header = UI.frame(panel, { Name = "Header", Size = UDim2.new(1, 0, 0, 54), Color = UI.Colors.panel, Corner = 20 })
	UI.gradient(header, 0.8)
	local accent = UI.frame(header, { Name = "Accent", Size = UDim2.new(1, -40, 0, 3), Position = UDim2.new(0, 20, 1, -3), Color = UI.Colors.goo, Corner = 2 })
	accent.BackgroundTransparency = 0.3
	local title = UI.label(header, opts.title or opts.name, {
		Name = "Title",
		Size = UDim2.new(1, -90, 1, 0),
		Position = UDim2.fromOffset(20, 0),
		TextSize = 28,
		AlignX = Enum.TextXAlignment.Left,
		Outline = 2,
	})
	UI.button(header, "X", {
		Name = "Close",
		Size = UDim2.fromOffset(44, 40),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = UI.Colors.red,
		TextColor = UI.Colors.text,
		TextSize = 22,
	}, function()
		State.close()
	end)

	local body = UI.box(panel, { Name = "Body", Size = UDim2.new(1, -24, 1, -70), Position = UDim2.fromOffset(12, 60) })

	window.root, window.body, window.title = root, body, title

	function window.onShow(fn)
		table.insert(showHandlers, fn)
	end
	function window.onHide(fn)
		table.insert(hideHandlers, fn)
	end
	function window.setTitle(text)
		title.Text = text
	end

	State.panelChanged:Connect(function(name, arg)
		if name == opts.name then
			local wasVisible = window.visible
			window.visible = true
			root.Visible = true
			if not wasVisible then
				UI.pop(root, 0.85)
				State.sound("open")
			end
			for _, fn in ipairs(showHandlers) do
				task.spawn(fn, arg)
			end
		elseif window.visible then
			window.visible = false
			root.Visible = false
			for _, fn in ipairs(hideHandlers) do
				task.spawn(fn)
			end
		end
	end)
	return window
end

-- A row of tab buttons. items = { { id = "x", text = "X" }, ... }
-- Returns { select(id), current }
function UI.tabs(parent, items, onSelect, props)
	props = props or {}
	local holder = UI.box(parent, { Name = "Tabs", Size = props.Size or UDim2.new(1, 0, 0, 40), Position = props.Position })
	UI.list(holder, { horizontal = true, pad = 6, alignY = Enum.VerticalAlignment.Center })
	local tabs = { current = nil, buttons = {} }
	local width = props.TabWidth or math.floor((props.Width or 720) / #items) - 6
	function tabs.select(id, silent)
		tabs.current = id
		for tabId, button in pairs(tabs.buttons) do
			button.BackgroundColor3 = tabId == id and UI.Colors.goo or UI.Colors.panel2
			button.TextColor3 = tabId == id and UI.Colors.dark or UI.Colors.text
		end
		if not silent then
			onSelect(id)
		end
	end
	for index, item in ipairs(items) do
		local button = UI.button(holder, item.text, {
			Name = "Tab_" .. item.id,
			Size = UDim2.fromOffset(width, props.TabHeight or 36),
			Color = UI.Colors.panel2,
			TextColor = UI.Colors.text,
			TextSize = props.TextSize or 15,
			LayoutOrder = index,
			Silent = true,
		}, function()
			State.sound("tab")
			tabs.select(item.id)
		end)
		tabs.buttons[item.id] = button
	end
	return tabs
end

----------------------------------------------------------------------
-- Clothing cards (inventory / wardrobe / shop / inspect)
----------------------------------------------------------------------
function UI.rarityColor(rarity)
	return ClothingSystem.rarityColor(rarity)
end

-- A square card for a clothing item with its rarity colour.
-- opts: Size (UDim2), footer (text under the name), equipped, locked
function UI.itemCard(parent, item, opts, onClick)
	opts = opts or {}
	local rarityColor = ClothingSystem.rarityColor(item.rarity)
	local order = ClothingSystem.rarityOrder(item.rarity)
	local card = UI.new("TextButton", {
		Name = "Item_" .. item.id,
		Size = opts.Size or UDim2.fromOffset(104, 122),
		BackgroundColor3 = UI.Colors.panel,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = opts.LayoutOrder or 0,
		Parent = parent,
	})
	UI.corner(card, 12)
	local stroke = UI.stroke(card, 3, rarityColor)
	-- tinted by rarity: neutral at the top, rarity colour glowing at the bottom
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	UI.new("UIGradient", {
		Name = "RarityGlow",
		Rotation = 90,
		Color = ColorSequence.new(UI.Colors.panel2, UI.Colors.panel:Lerp(rarityColor, 0.38)),
		Parent = card,
	})
	-- colour swatch + slot icon stand in for a thumbnail
	local swatch = UI.frame(card, { Name = "Swatch", Size = UDim2.new(1, -16, 0, 56), Position = UDim2.fromOffset(8, 8), Color = ClothingSystem.swatch(item), Corner = 8 })
	UI.label(swatch, ClothingSystem.SlotInfo[item.slot].icon, { TextSize = 32 })
	UI.label(card, item.name, { Name = "ItemName", Size = UDim2.new(1, -8, 0, 30), Position = UDim2.fromOffset(4, 66), TextSize = 12, Font = UI.BodyFont })
	UI.label(card, opts.footer or item.rarity, { Name = "Footer", Size = UDim2.new(1, -8, 0, 16), Position = UDim2.new(0, 4, 1, -20), TextSize = 12, Color = rarityColor })
	if opts.equipped then
		local badge = UI.frame(card, { Name = "Equipped", Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -4, 0, 4), AnchorPoint = Vector2.new(1, 0), Color = UI.Colors.goo, Corner = 12, ZIndex = 3 })
		UI.label(badge, "✓", { TextSize = 16, Color = UI.Colors.dark, ZIndex = 4 })
	end
	if opts.locked then
		local shade = UI.frame(card, { Name = "Locked", Color = UI.Colors.dark, Transparency = 0.45, Corner = 12, ZIndex = 3 })
		UI.label(shade, "🔒\n" .. tostring(opts.locked), { TextSize = 14, ZIndex = 4 })
	end
	-- Legendary and better pieces glow in the inventory.
	if order >= 5 and not opts.locked then
		task.spawn(function()
			while card.Parent do
				UI.tween(stroke, 0.7, { Thickness = 5, Transparency = 0.35 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				task.wait(0.7)
				if not card.Parent then
					break
				end
				UI.tween(stroke, 0.7, { Thickness = 3, Transparency = 0 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				task.wait(0.7)
			end
		end)
	end
	if onClick then
		card.Activated:Connect(function()
			State.sound("click")
			onClick(card)
		end)
	end
	return card
end

-- A simple text row card (shop entries, tasks, achievements).
function UI.row(parent, props)
	props = props or {}
	local row = UI.frame(parent, {
		Name = props.Name or "Row",
		Size = props.Size or UDim2.new(1, -10, 0, 64),
		Color = props.Color or UI.Colors.panel,
		Corner = 12,
		LayoutOrder = props.LayoutOrder,
	})
	UI.gradient(row, 0.82)
	if props.StrokeColor then
		UI.stroke(row, 2, props.StrokeColor)
	end
	return row
end

return UI
