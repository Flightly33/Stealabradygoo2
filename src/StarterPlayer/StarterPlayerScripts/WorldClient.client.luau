--[[
	WorldClient
	Small per-player world behaviours:
	  * roofs fade away while you are standing under them (so you can see
	    inside houses, the store, the arcade and the cave)
	  * prompts that belong to another player's house are hidden
	  * prompts that open a menu (shop counter, arcade machines, a Brady) do so
	  * hidden goo blobs you already collected today disappear for you only
	  * optional background music
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Client = ReplicatedStorage:WaitForChild("Client")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local State = require(Client:WaitForChild("ClientState"))
local Sounds = require(Modules:WaitForChild("Sounds"))

local localPlayer = Players.LocalPlayer

----------------------------------------------------------------------
-- Roofs: every roof is a Model with an invisible "RoofZone" box inside.
-- While you stand inside the box, that whole roof fades away (locally).
----------------------------------------------------------------------
local ZONE_TAG = "RoofZone"
local hiddenRoofs = {} -- [zone] = true while faded out
local roofParts = {} -- [zone] = { parts }

local function partsOf(zone)
	local list = roofParts[zone]
	if not list then
		list = {}
		for _, descendant in ipairs(zone.Parent:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant ~= zone then
				table.insert(list, descendant)
			end
		end
		roofParts[zone] = list
	end
	return list
end

local function setRoof(zone, hidden)
	if (hiddenRoofs[zone] == true) == hidden then
		return
	end
	hiddenRoofs[zone] = hidden or nil
	for _, part in ipairs(partsOf(zone)) do
		if part.Parent then
			TweenService:Create(part, TweenInfo.new(0.3), { LocalTransparencyModifier = hidden and 1 or 0 }):Play()
		end
	end
end

task.spawn(function()
	while true do
		task.wait(0.25)
		local character = localPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local position = hrp.CFrame.Position
			for _, zone in ipairs(CollectionService:GetTagged(ZONE_TAG)) do
				if zone.Parent then
					local p = zone.CFrame:PointToObjectSpace(position)
					local half = zone.Size / 2
					setRoof(zone, math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z)
				end
			end
			-- forget zones whose house was rebuilt
			for zone in pairs(roofParts) do
				if not zone.Parent then
					roofParts[zone] = nil
					hiddenRoofs[zone] = nil
				end
			end
		end
	end
end)

----------------------------------------------------------------------
-- Walls: while you are inside a house, any wall between the camera and the
-- room fades to see-through, so the camera never gets blocked.
----------------------------------------------------------------------
local WALL_NAMES = {
	Wall = true, WallLining = true, Baseboard = true, Crown = true, Window = true, WindowFrame = true,
	WindowSill = true, Mullion = true, FlowerBox = true, BoxFlower = true, Post = true, DoorFrame = true,
	DoorJamb = true, Door = true, DoorKnob = true, PorchLantern = true, PorchBulb = true, Sign = true,
}
local houseWalls = {} -- [house model] = { parts }
local fadedWalls = {} -- [part] = true

local function wallsOf(house)
	local list = houseWalls[house]
	if not list then
		list = {}
		for _, child in ipairs(house:GetChildren()) do
			if child:IsA("BasePart") and WALL_NAMES[child.Name] then
				table.insert(list, child)
			end
		end
		houseWalls[house] = list
	end
	return list
end

local function setWall(part, faded)
	if (fadedWalls[part] == true) == faded then
		return
	end
	fadedWalls[part] = faded or nil
	part.LocalTransparencyModifier = faded and 0.75 or 0
end

local function updateWalls()
	local camera = Workspace.CurrentCamera
	local character = localPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local insideZone
	if camera and hrp then
		for zone in pairs(hiddenRoofs) do
			local house = zone.Parent and zone.Parent.Parent
			if house and house.Parent and house.Parent.Name == "Houses" then
				insideZone = zone
				break
			end
		end
	end
	local keep = {}
	if insideZone then
		local house = insideZone.Parent.Parent
		local half = insideZone.Size / 2
		local cam = insideZone.CFrame:PointToObjectSpace(camera.CFrame.Position)
		for _, part in ipairs(wallsOf(house)) do
			local p = insideZone.CFrame:PointToObjectSpace(part.CFrame.Position)
			-- which side of the room is this wall on, and is the camera out past it?
			local onX = math.abs(p.X) > half.X - 2.5 and math.sign(p.X) == math.sign(cam.X) and math.abs(cam.X) > half.X - 4
			local onZ = math.abs(p.Z) > half.Z - 2.5 and math.sign(p.Z) == math.sign(cam.Z) and math.abs(cam.Z) > half.Z - 4
			if onX or onZ then
				keep[part] = true
			end
		end
	end
	for part in pairs(fadedWalls) do
		if not keep[part] or not part.Parent then
			setWall(part, false)
		end
	end
	for part in pairs(keep) do
		setWall(part, true)
	end
	for house in pairs(houseWalls) do
		if not house.Parent then
			houseWalls[house] = nil
		end
	end
end

task.spawn(function()
	while true do
		task.wait(0.1)
		pcall(updateWalls)
	end
end)

----------------------------------------------------------------------
-- Prompts
----------------------------------------------------------------------
local OWNER_TAG = "OwnerPrompt"

local function filterPrompt(prompt)
	if prompt:IsA("ProximityPrompt") then
		prompt.Enabled = prompt:GetAttribute("OwnerUserId") == localPlayer.UserId
	end
end

for _, prompt in ipairs(CollectionService:GetTagged(OWNER_TAG)) do
	filterPrompt(prompt)
end
CollectionService:GetInstanceAddedSignal(OWNER_TAG):Connect(filterPrompt)

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if player ~= localPlayer then
		return
	end
	local panel = prompt:GetAttribute("Panel")
	if panel then
		-- shop counters, crate machines, food stalls, arcade machines
		State.open(panel, prompt:GetAttribute("PanelArg"))
	elseif prompt.Name == "InspectPrompt" then
		local owner = prompt:GetAttribute("OwnerUserId")
		if owner == localPlayer.UserId then
			State.open("Brady")
		elseif owner and owner ~= 0 then
			State.open("Inspect", owner)
		end
	end
end)

----------------------------------------------------------------------
-- Hidden goo blobs (per-player visibility)
----------------------------------------------------------------------
local HIDDEN_TAG = "HiddenGoo"

local function setBlobVisible(blob, visible)
	blob.LocalTransparencyModifier = visible and 0 or 1
end

local function refreshBlobs()
	local data = State.data
	if not data then
		return
	end
	local today = State.session.day
	local found = data.daily.hiddenDay == today and data.daily.hidden or {}
	for _, blob in ipairs(CollectionService:GetTagged(HIDDEN_TAG)) do
		setBlobVisible(blob, not found[tostring(blob:GetAttribute("Index"))])
	end
end

State.on("daily", refreshBlobs)
State.onSession("day", refreshBlobs)
CollectionService:GetInstanceAddedSignal(HIDDEN_TAG):Connect(function()
	task.defer(refreshBlobs)
end)
State.listen("HiddenFound", function(index)
	for _, blob in ipairs(CollectionService:GetTagged(HIDDEN_TAG)) do
		if blob:GetAttribute("Index") == index then
			setBlobVisible(blob, false)
		end
	end
	State.sound("coin")
end)

----------------------------------------------------------------------
-- Background music (off unless Sounds.Music is set to an asset id)
----------------------------------------------------------------------
if Sounds.Music ~= "" then
	local music = Instance.new("Sound")
	music.Name = "Music"
	music.SoundId = Sounds.Music
	music.Volume = Sounds.MusicVolume
	music.Looped = true
	music.Parent = SoundService
	State.on("settings", function(settings)
		if settings and settings.music == false then
			music:Stop()
		elseif not music.IsPlaying then
			music:Play()
		end
	end)
end
