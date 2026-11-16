--[[
	RoomUI
	Decorating the player's room + travelling around.

	PLACING FURNITURE (grid based)
	Picking a piece shows a translucent ghost that follows the mouse / finger
	across the room floor, snapped to the 2-stud grid. It turns green where
	the piece fits and red where it does not, using the very same
	FurnitureSystem.canPlace() rule the server enforces - so what looks valid
	on screen is valid on the server.

	    PC:      move mouse, click to place, R = rotate, Q = cancel
	    Touch:   drag to move, then tap the PLACE button

	REMOVE MODE: tap any of your furniture to put it back into storage.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Client = ReplicatedStorage:WaitForChild("Client")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local State = require(Client:WaitForChild("ClientState"))
local UI = require(Client:WaitForChild("UI"))
local AgeSystem = require(Modules:WaitForChild("AgeSystem"))
local Config = require(Modules:WaitForChild("Config"))
local FurnitureSystem = require(Modules:WaitForChild("FurnitureSystem"))
local HouseSystem = require(Modules:WaitForChild("HouseSystem"))
local FurnitureBuilder = require(Modules:WaitForChild("Builders"):WaitForChild("FurnitureBuilder"))

local gui = script.Parent
local C = UI.Colors
local localPlayer = Players.LocalPlayer

State.wait()

local window = UI.window(gui, { name = "Room", title = "🏠 Room", width = 760, height = 480 })
local body = window.body

local mode = "Decorate"
local refresh
local tabs = UI.tabs(body, { { id = "Decorate", text = "🛋️ Decorate" }, { id = "Travel", text = "🧭 Travel & Visit" } }, function(id)
	mode = id
	refresh()
end, { Width = 736, TextSize = 16 })

local header = UI.label(body, "", { Name = "Summary", Size = UDim2.new(1, -230, 0, 30), Position = UDim2.fromOffset(0, 46), TextSize = 14, Font = UI.BodyFont, Color = C.sub, AlignX = Enum.TextXAlignment.Left })
local list = UI.scroll(body, { Name = "List", Size = UDim2.new(1, 0, 1, -84), Position = UDim2.fromOffset(0, 82) })
UI.list(list, { pad = 6 })

----------------------------------------------------------------------
-- Where is my room?
----------------------------------------------------------------------
-- Returns the room-local origin CFrame (centre of the floor) and room size.
local function myRoom()
	local houses = Workspace:FindFirstChild("Houses")
	local house = houses and houses:FindFirstChild("House_" .. localPlayer.UserId)
	local floor = house and house:FindFirstChild("Floor")
	if not floor then
		return nil
	end
	return floor.CFrame * CFrame.new(0, floor.Size.Y / 2, 0), house:GetAttribute("Size") or AgeSystem.houseSize(State.data.age), house
end

local function insideMyRoom()
	local origin, size = myRoom()
	local character = localPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not origin or not hrp then
		return false
	end
	return HouseSystem.isInside(size, origin:PointToObjectSpace(hrp.CFrame.Position), 6)
end

----------------------------------------------------------------------
-- Placement mode
----------------------------------------------------------------------
local placing = nil -- { id, r, x, z, ghost, valid }
local removing = false
local connections = {}

local bar = UI.frame(gui, { Name = "PlacementBar", Size = UDim2.fromOffset(560, 104), Position = UDim2.new(0.5, 0, 1, -120), AnchorPoint = Vector2.new(0.5, 1), Color = C.bg, Corner = 18, Stroke = 4, StrokeColor = C.goo, Visible = false })
UI.autoScale(bar, "hud")
local barText = UI.label(bar, "", { Name = "Hint", Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 4), TextSize = 15, Font = UI.BodyFont })
local barButtons = UI.box(bar, { Name = "Buttons", Size = UDim2.new(1, -16, 0, 52), Position = UDim2.fromOffset(8, 44) })
UI.list(barButtons, { horizontal = true, pad = 8, alignX = Enum.HorizontalAlignment.Center })

local function disconnectAll()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	connections = {}
end

local function stopPlacement()
	if placing and placing.ghost then
		placing.ghost:Destroy()
	end
	placing = nil
	removing = false
	disconnectAll()
	bar.Visible = false
end

-- Converts a screen point into a room-local floor position.
local function floorPoint(screenPosition)
	local origin = myRoom()
	local camera = Workspace.CurrentCamera
	if not origin or not camera then
		return nil
	end
	local ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
	local floorY = origin.Position.Y
	if ray.Direction.Y >= -0.01 then
		return nil -- looking at the sky
	end
	local t = (floorY - ray.Origin.Y) / ray.Direction.Y
	if t < 0 or t > 500 then
		return nil
	end
	return origin:PointToObjectSpace(ray.Origin + ray.Direction * t)
end

local function updateGhost()
	if not placing then
		return
	end
	local origin, size = myRoom()
	if not origin then
		return
	end
	local placement = { id = placing.id, x = placing.x, z = placing.z, r = placing.r }
	placing.ghost:PivotTo(origin * FurnitureSystem.localCFrame(placement))
	local ok, reason = FurnitureSystem.canPlace(State.data.furniture.placed, placing.id, placing.x, placing.z, placing.r, size)
	placing.valid = ok
	local base = placing.ghost.PrimaryPart
	if base then
		base.Color = ok and C.goo or C.red
	end
	local def = FurnitureSystem.get(placing.id)
	barText.Text = ok and ("Placing " .. def.name .. " - tap PLACE (or click) to put it down") or ("✖ " .. (reason or "can't go there"))
	barText.TextColor3 = ok and C.text or C.red
end

local function moveGhostTo(screenPosition)
	if not placing then
		return
	end
	local point = floorPoint(screenPosition)
	if point then
		placing.x, placing.z = FurnitureSystem.snap(placing.id, point.X, point.Z, placing.r)
		updateGhost()
	end
end

local function spareCount(id)
	local furniture = State.data.furniture
	return (furniture.owned[id] or 0) - FurnitureSystem.placedCount(furniture.placed, id)
end

local function confirmPlacement()
	if not placing then
		return
	end
	if not placing.valid then
		State.toast("it doesn't fit there", "bad")
		return
	end
	local id = placing.id
	State.send("PlaceFurniture", id, placing.x, placing.z, placing.r)
	-- The Faster Room Customizing pass keeps you placing the same piece.
	if State.hasPass("FastDecorating") and spareCount(id) > 1 then
		task.delay(0.3, updateGhost)
	else
		stopPlacement()
	end
end

local function rotateGhost()
	if placing then
		placing.r = (placing.r + 1) % 4
		-- keep the piece under the pointer after its footprint swaps
		local rect = FurnitureSystem.rectOf({ id = placing.id, x = placing.x, z = placing.z, r = (placing.r + 3) % 4 })
		placing.x, placing.z = FurnitureSystem.snap(placing.id, (rect.minX + rect.maxX) / 2, (rect.minZ + rect.maxZ) / 2, placing.r)
		updateGhost()
	end
end

local function barButton(text, color, callback)
	return UI.button(barButtons, text, { Size = UDim2.fromOffset(160, 50), Color = color, TextSize = 20 }, callback)
end

local function startPlacement(id)
	stopPlacement()
	local origin = myRoom()
	if not origin then
		State.toast("your house isn't ready yet", "bad")
		return
	end
	if not insideMyRoom() then
		State.toast("go inside your house to decorate (Travel > Home)", "bad")
		return
	end
	local ghost = FurnitureBuilder.build(id)
	if not ghost then
		return
	end
	FurnitureBuilder.makeGhost(ghost)
	ghost.Name = "PlacementGhost"
	ghost.Parent = Workspace
	local x, z = FurnitureSystem.snap(id, 0, 0, 0)
	placing = { id = id, r = 0, x = x, z = z, ghost = ghost, valid = false }
	State.close()

	UI.clear(barButtons)
	barButton("↻ Rotate", C.blue, rotateGhost).TextColor3 = C.text
	barButton("✔ PLACE", C.goo, confirmPlacement)
	barButton("✖ Cancel", C.red, stopPlacement).TextColor3 = C.text
	bar.Visible = true
	updateGhost()

	table.insert(connections, UserInputService.InputChanged:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseMovement or (input.UserInputType == Enum.UserInputType.Touch and not processed) then
			moveGhostTo(input.Position)
		end
	end))
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			moveGhostTo(input.Position)
			confirmPlacement()
		elseif input.UserInputType == Enum.UserInputType.Touch then
			moveGhostTo(input.Position)
		elseif input.KeyCode == Enum.KeyCode.R then
			rotateGhost()
		elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Backspace then
			stopPlacement()
		end
	end))
end

----------------------------------------------------------------------
-- Remove mode
----------------------------------------------------------------------
-- Finds which saved placement a floor position belongs to.
local function placementAt(localPoint)
	local placed = State.data.furniture.placed
	-- prefer normal furniture over the rug underneath it
	for pass = 1, 2 do
		for index = #placed, 1, -1 do
			local def = FurnitureSystem.get(placed[index].id)
			-- (small margin so a tap exactly on a grid line still counts)
			if def and ((def.layer == "rug") == (pass == 2)) and HouseSystem.pointInRect(localPoint.X, localPoint.Z, FurnitureSystem.rectOf(placed[index]), 0.05) then
				return index
			end
		end
	end
	return nil
end

local function startRemoving()
	stopPlacement()
	if not insideMyRoom() then
		State.toast("go inside your house first (Travel > Home)", "bad")
		return
	end
	removing = true
	State.close()
	UI.clear(barButtons)
	barButton("✔ Done", C.goo, stopPlacement)
	barText.Text = "REMOVE MODE: tap a piece of furniture to put it back in storage"
	barText.TextColor3 = C.text
	bar.Visible = true
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not removing then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local point = floorPoint(input.Position)
			local index = point and placementAt(point)
			if index then
				State.send("RemoveFurniture", index)
			end
		elseif input.KeyCode == Enum.KeyCode.Q then
			stopPlacement()
		end
	end))
end

-- Leaving the room or opening another window ends placement.
State.panelChanged:Connect(function(name)
	if name ~= nil and (placing or removing) then
		stopPlacement()
	end
end)

----------------------------------------------------------------------
-- Window contents
----------------------------------------------------------------------
local removeButton = UI.button(body, "🗑️ Remove mode", { Name = "RemoveMode", Size = UDim2.fromOffset(220, 32), Position = UDim2.new(1, -220, 0, 46), Color = C.red, TextColor = C.text, TextSize = 15, Corner = 10 }, startRemoving)

local function showDecorate()
	local data = State.data
	local furniture = data.furniture
	local limit = State.hasPass("ExtraStorage") and Config.MaxPlacedFurnitureWithPass or Config.MaxPlacedFurniture
	local size = AgeSystem.houseSize(data.age)
	header.Text = string.format("%s  •  %dx%d studs  •  %d / %d placed", AgeSystem.HouseNames[AgeSystem.houseTier(data.age)], size, size, #furniture.placed, limit)
	removeButton.Visible = true
	local ids = {}
	for id, owned in pairs(furniture.owned) do
		if owned > 0 and FurnitureSystem.get(id) then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return FurnitureSystem.get(a).name < FurnitureSystem.get(b).name
	end)
	for index, id in ipairs(ids) do
		local def = FurnitureSystem.get(id)
		local spare = spareCount(id)
		local row = UI.row(list, { Name = "Furniture_" .. id, Size = UDim2.new(1, -12, 0, 56), LayoutOrder = index })
		local swatch = UI.frame(row, { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(6, 6), Color = def.color, Corner = 10 })
		UI.label(swatch, def.toy and "🧸" or (def.category == "Decor" and "🪴" or "🛋️"), { TextSize = 24 })
		UI.label(row, def.name, { Size = UDim2.new(1, -230, 0, 24), Position = UDim2.fromOffset(58, 5), TextSize = 17, AlignX = Enum.TextXAlignment.Left })
		UI.label(row, string.format("%d in storage  •  %d placed  •  %dx%d studs", spare, furniture.owned[id] - spare, def.w, def.d), { Size = UDim2.new(1, -230, 0, 22), Position = UDim2.fromOffset(58, 29), TextSize = 12, Font = UI.BodyFont, Color = C.sub, AlignX = Enum.TextXAlignment.Left })
		local button = UI.button(row, spare > 0 and "PLACE" or "all placed", { Name = "Place", Size = UDim2.fromOffset(150, 40), Position = UDim2.new(1, -158, 0, 8), TextSize = 17 }, function()
			if spareCount(id) > 0 then
				startPlacement(id)
			end
		end)
		UI.setEnabled(button, spare > 0)
	end
	if #ids == 0 then
		UI.label(list, "no furniture yet - buy some in the Shop!", { Size = UDim2.new(1, -12, 0, 60), TextSize = 16, Font = UI.BodyFont, Color = C.sub })
	end
	UI.button(list, "🛒 Buy furniture", { Name = "ShopLink", Size = UDim2.new(1, -12, 0, 40), Color = C.gold, TextSize = 17, LayoutOrder = 999 }, function()
		State.open("Shop", "Home")
	end)
end

local PLACES = {
	{ "Home", "🏠 My House" }, { "Plaza", "⛲ Plaza" }, { "Shop", "👕 Clothing Store" }, { "Runway", "🌟 Fashion Runway" },
	{ "Arcade", "🎮 Mini-Games" }, { "Park", "🌳 Park" }, { "Food", "🍔 Food Court" },
}

local function showTravel()
	header.Text = "teleport around the map, or visit another player's house"
	removeButton.Visible = false
	local places = UI.box(list, { Name = "Places", Size = UDim2.new(1, -12, 0, 100), LayoutOrder = 1 })
	UI.grid(places, 170, 44, 8)
	for index, place in ipairs(PLACES) do
		UI.button(places, place[2], { Name = "Go_" .. place[1], Size = UDim2.fromOffset(170, 44), Color = C.goo, TextSize = 15, LayoutOrder = index }, function()
			State.send("Visit", place[1])
			State.close()
		end)
	end
	UI.label(list, "PLAYERS IN THIS SERVER", { Size = UDim2.new(1, -12, 0, 24), TextSize = 14, Color = C.sub, LayoutOrder = 2 })
	local shown = 0
	for index, player in ipairs(Players:GetPlayers()) do
		if player ~= localPlayer then
			shown += 1
			local row = UI.row(list, { Name = "Player_" .. player.UserId, Size = UDim2.new(1, -12, 0, 50), LayoutOrder = 2 + index })
			UI.label(row, "🧍 " .. player.DisplayName, { Size = UDim2.new(1, -330, 1, 0), Position = UDim2.fromOffset(12, 0), TextSize = 17, AlignX = Enum.TextXAlignment.Left })
			UI.button(row, "Visit house", { Name = "Visit", Size = UDim2.fromOffset(150, 36), Position = UDim2.new(1, -316, 0, 7), Color = C.goo, TextSize = 15 }, function()
				State.send("Visit", player.UserId)
				State.close()
			end)
			UI.button(row, "Inspect Brady", { Name = "Inspect", Size = UDim2.fromOffset(150, 36), Position = UDim2.new(1, -158, 0, 7), Color = C.pink, TextSize = 15 }, function()
				State.open("Inspect", player.UserId)
			end)
		end
	end
	if shown == 0 then
		UI.label(list, "nobody else is here right now", { Size = UDim2.new(1, -12, 0, 40), TextSize = 15, Font = UI.BodyFont, Color = C.sub, LayoutOrder = 3 })
	end
end

function refresh()
	if not window.visible then
		return
	end
	UI.clear(list)
	if mode == "Travel" then
		showTravel()
	else
		showDecorate()
	end
end

window.onShow(function(arg)
	if arg == "Travel" then
		mode = "Travel"
	elseif arg == "Decorate" then
		mode = "Decorate"
	end
	tabs.select(mode, true)
	refresh()
end)
State.on("furniture", function()
	refresh()
	if placing then
		if spareCount(placing.id) <= 0 then
			stopPlacement()
		else
			updateGhost()
		end
	end
end)
State.on("age", refresh)
