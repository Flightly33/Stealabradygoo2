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

local Client = ReplicatedStorage:WaitForChild("Client")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local State = require(Client:WaitForChild("ClientState"))
local Sounds = require(Modules:WaitForChild("Sounds"))

local localPlayer = Players.LocalPlayer

----------------------------------------------------------------------
-- Roofs
----------------------------------------------------------------------
local ROOF_TAG = "HouseRoof"
local roofHidden = {} -- [part] = true while faded out

local function setRoof(part, hidden)
	if roofHidden[part] == hidden then
		return
	end
	roofHidden[part] = hidden
	TweenService:Create(part, TweenInfo.new(0.3), { LocalTransparencyModifier = hidden and 1 or 0 }):Play()
end

task.spawn(function()
	while true do
		task.wait(0.25)
		local character = localPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local position = hrp.CFrame.Position
			for _, roof in ipairs(CollectionService:GetTagged(ROOF_TAG)) do
				local localPosition = roof.CFrame:PointToObjectSpace(position)
				local half = roof.Size / 2
				local under = math.abs(localPosition.X) <= half.X and math.abs(localPosition.Z) <= half.Z and localPosition.Y < 0 and localPosition.Y > -60
				setRoof(roof, under)
			end
		end
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
