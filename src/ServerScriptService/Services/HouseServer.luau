--[[
	HouseServer
	Gives every player a plot, builds their house (and rebuilds it bigger when
	Brady reaches a new stage), wires up the room's stations, and runs the
	grid-based furniture placement.

	Furniture placement is validated here with the same FurnitureSystem rules
	the client used for its preview: the player must own a spare copy, the
	footprint must be inside the room and may not overlap stations, the
	doorway or other furniture.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage.Modules
local AgeSystem = require(Modules.AgeSystem)
local Config = require(Modules.Config)
local FurnitureSystem = require(Modules.FurnitureSystem)
local HouseSystem = require(Modules.HouseSystem)
local InventorySystem = require(Modules.InventorySystem)
local FurnitureBuilder = require(Modules.Builders.FurnitureBuilder)
local PartUtil = require(Modules.Builders.PartUtil)
local HouseBuilder = require(script.Parent.Parent.World.HouseBuilder)

local HouseServer = {}

local S
local plots = {} -- [index] = { index, cframe, owner, model, info }
local byPlayer = {}
local folder

local function plotCFrame(index)
	local list = S.Map.plots
	if list[index] then
		return list[index]
	end
	-- More players than pre-built plots: keep extending the street.
	return S.Map.plotCFrame(index)
end

function HouseServer.get(player)
	return byPlayer[player]
end

-- Room-local origin (centre of the floor) in world space.
function HouseServer.origin(player)
	local plot = byPlayer[player]
	return plot and plot.info and plot.info.origin or CFrame.new(0, 5, 0)
end

function HouseServer.size(player)
	local plot = byPlayer[player]
	return plot and plot.info and plot.info.size or 24
end

-- Where Brady stands to use a station (world CFrame).
function HouseServer.stationCFrame(player, station)
	return HouseServer.origin(player) * HouseSystem.standCFrame(HouseServer.size(player), station)
end

-- Middle of the room, facing the front door.
function HouseServer.homeCFrame(player)
	return HouseServer.origin(player) * CFrame.lookAt(Vector3.new(0, 0, 1), Vector3.new(0, 0, 4))
end

function HouseServer.doorstep(player)
	return HouseServer.origin(player) * HouseSystem.doorstep(HouseServer.size(player))
end

function HouseServer.isInside(player, worldPosition, margin)
	local plot = byPlayer[player]
	if not plot or not plot.info then
		return false
	end
	local localPosition = plot.info.origin:PointToObjectSpace(worldPosition)
	return localPosition.Y > -4 and localPosition.Y < 30 and HouseSystem.isInside(plot.info.size, localPosition, margin)
end

-- A random free floor spot for Brady to wander to (world position).
function HouseServer.randomSpot(player)
	local plot = byPlayer[player]
	local data = S.Data.get(player)
	if not plot or not plot.info or not data then
		return nil
	end
	local size = plot.info.size
	local h = size / 2 - 2.5
	local blocked = HouseSystem.blockedRects(size)
	for _ = 1, 10 do
		local x, z = (math.random() * 2 - 1) * h, (math.random() * 2 - 1) * h
		local free = true
		for _, rect in ipairs(blocked) do
			if HouseSystem.pointInRect(x, z, rect, 1) then
				free = false
				break
			end
		end
		if free then
			for _, placement in ipairs(data.furniture.placed) do
				local def = FurnitureSystem.get(placement.id)
				if def and def.layer ~= "rug" and HouseSystem.pointInRect(x, z, FurnitureSystem.rectOf(placement), 1) then
					free = false
					break
				end
			end
		end
		if free then
			return (plot.info.origin * CFrame.new(x, 0, z)).Position
		end
	end
	return nil
end

----------------------------------------------------------------------
-- Furniture
----------------------------------------------------------------------
local function spawnFurniture(player, plot, placement)
	local def = FurnitureSystem.get(placement.id)
	local model = FurnitureBuilder.build(placement.id)
	if not model or not def then
		return
	end
	model:PivotTo(plot.info.origin * FurnitureSystem.localCFrame(placement))
	model:SetAttribute("OwnerUserId", player.UserId)
	if def.toy then
		-- Toys can be played with (owner only).
		local prompt = PartUtil.prompt(model.PrimaryPart, "Play", def.name, { distance = 8, name = "ToyPrompt" })
		prompt:SetAttribute("OwnerUserId", player.UserId)
		game:GetService("CollectionService"):AddTag(prompt, HouseBuilder.OwnerPromptTag)
		prompt.Triggered:Connect(function(who)
			if who == player then
				S.Care.playToy(player, placement.id)
			end
		end)
	end
	model.Parent = plot.info.furniture
end

-- Destroys and respawns every furniture model, dropping any placement that
-- is no longer valid (for example after the room layout changed).
local function refreshFurniture(player)
	local plot = byPlayer[player]
	local data = S.Data.get(player)
	if not plot or not plot.info or not data then
		return
	end
	plot.info.furniture:ClearAllChildren()
	local valid, removed = {}, 0
	for _, placement in ipairs(data.furniture.placed) do
		if FurnitureSystem.canPlace(valid, placement.id, placement.x, placement.z, placement.r, plot.info.size) then
			table.insert(valid, placement)
		else
			removed += 1
		end
	end
	data.furniture.placed = valid
	for _, placement in ipairs(valid) do
		spawnFurniture(player, plot, placement)
	end
	if removed > 0 then
		S.Data.sync(player, "furniture")
		S.Net.toast(player, removed .. " furniture item(s) went back into storage", "info")
	end
end

local function maxPlaced(player)
	return S.Passes.has(player, "ExtraStorage") and Config.MaxPlacedFurnitureWithPass or Config.MaxPlacedFurniture
end

local function placeFurniture(player, data, id, x, z, r)
	local plot = byPlayer[player]
	if type(id) ~= "string" or not plot or not plot.info then
		return
	end
	local def = FurnitureSystem.get(id)
	if not def then
		return
	end
	local placed = data.furniture.placed
	if (data.furniture.owned[id] or 0) - FurnitureSystem.placedCount(placed, id) <= 0 then
		S.Net.toast(player, "you don't have a spare " .. def.name, "bad")
		return
	end
	if def.vip and not S.Passes.has(player, "VIPDecor") then
		S.Net.toast(player, "that needs the VIP Room Decorations pass", "bad")
		return
	end
	if #placed >= maxPlaced(player) then
		S.Net.toast(player, "your room is full!", "bad")
		return
	end
	local ok, reason = FurnitureSystem.canPlace(placed, id, x, z, r, plot.info.size)
	if not ok then
		S.Net.toast(player, reason, "bad")
		return
	end
	local placement = { id = id, x = x, z = z, r = r }
	table.insert(placed, placement)
	spawnFurniture(player, plot, placement)
	S.Data.sync(player, "furniture")
	S.Achievements.bump(player, "placed", 1)
	S.Net.fire(player, "Effect", "Sound", { name = "place" })
end

local function removeFurniture(player, data, index)
	local placed = data.furniture.placed
	if type(index) ~= "number" or index % 1 ~= 0 or not placed[index] then
		return
	end
	table.remove(placed, index)
	refreshFurniture(player)
	S.Data.sync(player, "furniture")
	S.Net.fire(player, "Effect", "Sound", { name = "remove" })
end

----------------------------------------------------------------------
-- Stations
----------------------------------------------------------------------
local function connectStations(player, plot)
	for station, prompt in pairs(plot.info.prompts) do
		prompt.Triggered:Connect(function(who)
			local isOwner = who == player
			if station == "Display" then
				if isOwner then
					S.Net.fire(who, "OpenPanel", "Inventory")
				else
					S.Net.fire(who, "OpenPanel", "Inspect", player.UserId)
				end
				return
			elseif station == "Trophy" then
				if isOwner then
					S.Net.fire(who, "OpenPanel", "Collection")
				else
					S.Net.fire(who, "OpenPanel", "Inspect", player.UserId)
				end
				return
			end
			if not isOwner then
				return -- visitors can look, not touch
			end
			if station == "Bed" then
				S.Care.toggleSleep(player)
			elseif station == "Wardrobe" then
				S.Net.fire(player, "OpenPanel", "Wardrobe")
			elseif station == "Mirror" then
				S.Care.mirror(player, true)
			elseif station == "Food" then
				S.Net.fire(player, "OpenPanel", "Feed")
			elseif station == "Podium" then
				S.Care.podiumPose(player)
			elseif station == "Shower" then
				S.Care.perform(player, "Shower")
			elseif station == "Sink" then
				S.Care.perform(player, "BrushHair")
			elseif station == "ShoeMat" then
				S.Care.perform(player, "CleanShoes")
			end
		end)
	end
end

----------------------------------------------------------------------
-- Building
----------------------------------------------------------------------
local function showcaseItems(data)
	local owned = InventorySystem.ownedItems(data) -- rarest first
	return { owned[1], owned[2], owned[3] }
end

local function build(player)
	local plot = byPlayer[player]
	local data = S.Data.get(player)
	if not plot or not data then
		return
	end
	if plot.model then
		plot.model:Destroy()
	end
	local model, info = HouseBuilder.build(folder, plot.cframe, {
		age = data.age,
		ownerName = player.DisplayName,
		ownerUserId = player.UserId,
		showcase = showcaseItems(data),
		trophies = { achievements = require(Modules.Util).count(data.achievements), wins = data.stats.showsWon },
	})
	plot.model, plot.info = model, info
	connectStations(player, plot)
	refreshFurniture(player)
end

-- Rebuild after a stage change (bigger room), keeping Brady inside it.
function HouseServer.upgrade(player)
	build(player)
	local rec = S.Brady.get(player)
	local session = S.Data.session(player)
	if rec and session and not rec.following and not rec.inShow then
		if session.sleeping then
			S.Brady.place(rec, HouseServer.stationCFrame(player, "Bed"))
		else
			S.Brady.place(rec, HouseServer.homeCFrame(player))
		end
	end
end

-- Refresh only the decorative display / trophies (cheap rebuild).
function HouseServer.refreshDisplays(player)
	-- The displays are part of the house model; a full rebuild keeps it simple
	-- and only happens on rare events (new Epic+ item, fashion show win).
	HouseServer.upgrade(player)
end

-- Turns the shower water on for a few seconds.
function HouseServer.runShower(player, seconds)
	local plot = byPlayer[player]
	local emitter = plot and plot.info and plot.info.showerEmitter
	if not emitter then
		return
	end
	emitter.Enabled = true
	task.delay(seconds, function()
		if emitter.Parent then
			emitter.Enabled = false
		end
	end)
end

-- Folder where random events may drop props inside this player's house.
function HouseServer.eventFolder(player)
	local plot = byPlayer[player]
	return plot and plot.info and plot.info.eventProps
end

function HouseServer.teleportTo(player, cframe)
	local character = player.Character
	if character and character.PrimaryPart then
		character:PivotTo(cframe * CFrame.new(0, 4, 0))
		return true
	end
	return false
end

----------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------
function HouseServer.init(services)
	S = services
	folder = Instance.new("Folder")
	folder.Name = "Houses"
	folder.Parent = Workspace
	for index = 1, Config.PlotCount do
		plots[index] = { index = index, cframe = plotCFrame(index) }
	end
	S.Net.on("PlaceFurniture", placeFurniture, 6)
	S.Net.on("RemoveFurniture", removeFurniture, 6)
end

function HouseServer.playerAdded(player)
	local chosen
	for _, plot in ipairs(plots) do
		if not plot.owner then
			chosen = plot
			break
		end
	end
	if not chosen then
		local index = #plots + 1
		chosen = { index = index, cframe = plotCFrame(index) }
		plots[index] = chosen
	end
	chosen.owner = player
	byPlayer[player] = chosen
	local session = S.Data.session(player)
	if session then
		session.plot = chosen.index
	end
	build(player)

	-- New arrivals start on their own doorstep.
	local function sendHome(character)
		task.defer(function()
			if byPlayer[player] and character.Parent then
				local primary = character:WaitForChild("HumanoidRootPart", 10)
				if primary then
					character:PivotTo(HouseServer.doorstep(player) * CFrame.new(0, 4, 0))
				end
			end
		end)
	end
	if player.Character then
		sendHome(player.Character)
	end
	chosen.spawnConnection = player.CharacterAdded:Connect(sendHome)
end

function HouseServer.playerRemoving(player)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	if plot.spawnConnection then
		plot.spawnConnection:Disconnect()
	end
	if plot.model then
		plot.model:Destroy()
	end
	plot.model, plot.info, plot.owner, plot.spawnConnection = nil, nil, nil, nil
	byPlayer[player] = nil
end

function HouseServer.ownerOf(index)
	local plot = plots[index]
	return plot and plot.owner or nil
end

function HouseServer.count()
	return #Players:GetPlayers()
end

return HouseServer
