--[[
	MirrorUI
	Mirror mode. Using the mirror in the room makes Brady stand in front of it
	and strike a pose while the camera glides in close. From here the player
	can cycle through unlocked poses, change his outfit, or take a screenshot.

	The server opens this (OpenPanel "Mirror", spot) after it has moved Brady
	to the mirror; leaving sends Mirror(false) so he goes back to normal.
]]

local CaptureService = game:GetService("CaptureService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Client = ReplicatedStorage:WaitForChild("Client")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local State = require(Client:WaitForChild("ClientState"))
local UI = require(Client:WaitForChild("UI"))
local InventorySystem = require(Modules:WaitForChild("InventorySystem"))
local BradyBuilder = require(Modules:WaitForChild("Builders"):WaitForChild("BradyBuilder"))

local gui = script.Parent
local C = UI.Colors
local localPlayer = Players.LocalPlayer

State.wait()

local active = false
local spot = nil -- CFrame where Brady stands (he faces away from the mirror)
local savedCameraType = Enum.CameraType.Custom

local bar = UI.frame(gui, { Name = "MirrorBar", Size = UDim2.fromOffset(760, 132), Position = UDim2.new(0.5, 0, 1, -16), AnchorPoint = Vector2.new(0.5, 1), Color = C.bg, Corner = 18, Stroke = 4, StrokeColor = C.pink, Visible = false })
UI.autoScale(bar, "hud")
UI.label(bar, "🪞 MIRROR MODE - pick a pose", { Name = "Title", Size = UDim2.new(1, -420, 0, 28), Position = UDim2.fromOffset(14, 6), TextSize = 18, Color = C.pink, AlignX = Enum.TextXAlignment.Left })
local poses = UI.new("ScrollingFrame", {
	Name = "Poses",
	Size = UDim2.new(1, -24, 0, 54),
	Position = UDim2.fromOffset(12, 68),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = C.pink,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	ScrollingDirection = Enum.ScrollingDirection.X,
	Parent = bar,
})
UI.list(poses, { horizontal = true, pad = 6 })
local buttons = UI.box(bar, { Name = "Buttons", Size = UDim2.fromOffset(410, 36), Position = UDim2.new(1, -420, 0, 6) })
UI.list(buttons, { horizontal = true, pad = 6, alignX = Enum.HorizontalAlignment.Right })

local flash = UI.frame(gui, { Name = "Flash", Color = Color3.new(1, 1, 1), Transparency = 1, Corner = false, ZIndex = 50 })
flash.Visible = false

----------------------------------------------------------------------
-- Camera
----------------------------------------------------------------------
local function cameraGoal()
	local height = BradyBuilder.heightFor(State.data.age)
	local focus = spot.Position + Vector3.new(0, height * 0.55, 0)
	-- stand in front of Brady (he looks along spot.LookVector), slightly to one side
	local eye = focus + spot.LookVector * (height * 1.5 + 5) + spot.RightVector * 1.5 + Vector3.new(0, height * 0.1, 0)
	return CFrame.lookAt(eye, focus)
end

local function enterCamera()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	savedCameraType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(camera, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = cameraGoal() }):Play()
end

local function exitCamera()
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = savedCameraType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or savedCameraType
	end
end

----------------------------------------------------------------------
-- Poses + buttons
----------------------------------------------------------------------
local function refreshPoses()
	UI.clear(poses)
	local unlocked = InventorySystem.unlockedPoses(State.data, State.passes())
	for index, pose in ipairs(unlocked) do
		UI.button(poses, pose.name, { Name = "Pose_" .. pose.id, Size = UDim2.fromOffset(120, 42), Color = C.pink, TextSize = 14, Corner = 10, LayoutOrder = index }, function()
			State.send("SetPose", pose.id)
		end)
	end
end

local function leave()
	if not active then
		return
	end
	active = false
	bar.Visible = false
	exitCamera()
	State.send("Mirror", false)
end

local function screenshot()
	-- Hide every menu, snap, then bring them back.
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	local hidden = {}
	if playerGui then
		for _, child in ipairs(playerGui:GetChildren()) do
			if child:IsA("ScreenGui") and child.Enabled and child ~= gui then
				child.Enabled = false
				table.insert(hidden, child)
			end
		end
	end
	bar.Visible = false
	State.sound("camera")
	task.wait(0.15)
	local finished = false
	local function restore(message, kind)
		if finished then
			return
		end
		finished = true
		for _, child in ipairs(hidden) do
			child.Enabled = true
		end
		bar.Visible = active
		flash.Visible = true
		flash.BackgroundTransparency = 0.2
		UI.tween(flash, 0.5, { BackgroundTransparency = 1 })
		task.delay(0.5, function()
			flash.Visible = false
		end)
		State.toast(message, kind)
	end
	local ok = pcall(function()
		CaptureService:CaptureScreenshot(function(contentId)
			restore("📸 fit pic saved to your Roblox captures!", "good")
			State.send("Tutorial", "Photo")
			pcall(function()
				CaptureService:PromptSaveCapturesToGallery({ contentId }, function() end)
			end)
		end)
	end)
	if not ok then
		restore("screenshots aren't supported on this device - use your device's own screenshot button", "info")
	end
	-- never leave the menus hidden if the capture callback does not arrive
	task.delay(4, function()
		restore("📸 done!", "info")
	end)
end

UI.button(buttons, "👕 Outfit", { Name = "Outfit", Size = UDim2.fromOffset(120, 34), Color = C.blue, TextColor = C.text, TextSize = 15, Corner = 10, LayoutOrder = 1 }, function()
	State.open("Wardrobe")
end)
UI.button(buttons, "📸 Photo", { Name = "Photo", Size = UDim2.fromOffset(120, 34), Color = C.gold, TextSize = 15, Corner = 10, LayoutOrder = 2 }, function()
	task.spawn(screenshot)
end)
UI.button(buttons, "✖ Exit", { Name = "Exit", Size = UDim2.fromOffset(120, 34), Color = C.red, TextColor = C.text, TextSize = 15, Corner = 10, LayoutOrder = 3 }, function()
	leave()
	State.close()
end)

----------------------------------------------------------------------
-- Opening / closing
----------------------------------------------------------------------
State.panelChanged:Connect(function(name, arg)
	if name == "Mirror" then
		if typeof(arg) == "CFrame" then
			spot = arg
		end
		if not spot then
			return
		end
		if not active then
			active = true
			enterCamera()
		end
		refreshPoses()
		bar.Visible = true
		UI.pop(bar, 0.85)
	elseif name == "Wardrobe" and active then
		-- changing his outfit from the mirror: keep the close-up camera
		bar.Visible = false
	elseif name == nil and active then
		-- closed the wardrobe: back to the pose bar
		bar.Visible = true
	elseif active then
		leave()
	end
end)

State.on("age", function()
	if active then
		refreshPoses()
	end
end)
State.on("inventory", function()
	if active then
		refreshPoses()
	end
end)

-- If he falls asleep or the player walks off, drop out of mirror mode.
State.onSession("sleeping", function(sleeping)
	if sleeping and active then
		leave()
	end
end)
