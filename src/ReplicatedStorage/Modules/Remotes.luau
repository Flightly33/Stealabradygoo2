--[[
	Remotes
	One place that declares every RemoteEvent / RemoteFunction in the game.

	The SERVER calls Remotes.setup() once at boot, which creates them all inside
	ReplicatedStorage.Remotes. The CLIENT just calls Remotes.event(name) /
	Remotes.func(name), which wait for the server-made instance.

	Declaring the full list up front means a typo in a remote name errors
	immediately instead of hanging forever on WaitForChild.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

Remotes.Events = {
	-- server -> client
	"DataUpdate", -- ({ data = {...}, session = {...} }) replaces top-level keys
	"Notify", -- ({ text, sub, kind, sound, big })
	"AgeUp", -- ({ age, stage, stageChanged, coins, unlocks })
	"ItemGranted", -- ({ kind, id, name, rarity, isNew, refund, source })
	"EventUpdate", -- (eventState | nil)
	"FashionState", -- (state table)
	"Effect", -- (kind, payload) world effects such as confetti
	"OpenPanel", -- (panelName, arg) ask the client to open a UI panel
	"HiddenFound", -- (spotIndex)
	"ObbyState", -- ({ running, startedAt, result })

	-- client -> server
	"Care", -- (action, arg)
	"Equip", -- (itemId)
	"Unequip", -- (slot)
	"SaveOutfit", -- (index)
	"LoadOutfit", -- (index)
	"EquipGift", -- (giftId)
	"UnequipGift", -- (slot)
	"PlaceFurniture", -- (id, x, z, rot)
	"RemoveFurniture", -- (placedIndex)
	"EventAction", -- (action, arg)
	"Fashion", -- (action, arg)
	"ClaimDaily", -- ()
	"ClaimTask", -- (index)
	"ClaimCollection", -- (collectionId)
	"SetPose", -- (poseId)
	"Mirror", -- (enter: boolean)
	"Setting", -- (key, value)
	"Tutorial", -- (action)
	"Visit", -- (userId | "Home" | "Plaza" | "Runway")
	"Hype", -- (userId)
	"Rebirth", -- ()
}

Remotes.Functions = {
	"GetData", -- () -> { data, session }
	"Buy", -- (kind, id, quantity) -> { ok, reason }
	"OpenCrate", -- (crateId) -> { ok, reason, itemId, isNew, refund }
	"MinigameStart", -- (gameId) -> { ok, reason, token }
	"MinigameFinish", -- (token, score) -> { ok, coins, xp }
	"GetProfile", -- (userId) -> public profile table
}

local FOLDER_NAME = "Remotes"
local folder

local function getFolder()
	if folder then
		return folder
	end
	if RunService:IsServer() then
		folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
	else
		folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	end
	return folder
end

-- Server only: create every declared remote.
function Remotes.setup()
	assert(RunService:IsServer(), "Remotes.setup() must run on the server")
	local parent = getFolder()
	for _, name in ipairs(Remotes.Events) do
		if not parent:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = parent
		end
	end
	for _, name in ipairs(Remotes.Functions) do
		if not parent:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = parent
		end
	end
end

function Remotes.event(name)
	assert(table.find(Remotes.Events, name), "Unknown RemoteEvent: " .. tostring(name))
	local parent = getFolder()
	if RunService:IsServer() then
		return parent:FindFirstChild(name)
	end
	return parent:WaitForChild(name)
end

function Remotes.func(name)
	assert(table.find(Remotes.Functions, name), "Unknown RemoteFunction: " .. tostring(name))
	local parent = getFolder()
	if RunService:IsServer() then
		return parent:FindFirstChild(name)
	end
	return parent:WaitForChild(name)
end

return Remotes
