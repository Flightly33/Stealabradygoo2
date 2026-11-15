--[[
	Main (server entry point)
	The one Script that boots the whole game.

	Every system lives in a ModuleScript under Services/. This script requires
	them in a fixed order, hands each one the shared `S` table (so services can
	call each other without circular requires), and runs the player lifecycle:

	    join  -> load data -> each service's playerAdded() -> mark ready
	    leave -> each service's playerRemoving() -> final save

	One script deciding the order avoids the race conditions you get when many
	separate Scripts all start at once and hope the others are ready.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.Remotes)
Remotes.setup() -- create every RemoteEvent / RemoteFunction first

local Services = script.Parent.Services
local MapBuilder = require(script.Parent.World.MapBuilder)

-- Shared service table. S.Brady, S.Data ... are filled in below.
local S = {}
S.Map = MapBuilder.build()

local LOAD_ORDER = {
	{ "Data", "DataServer" },
	{ "Net", "Net" },
	{ "Currency", "CurrencyServer" },
	{ "Achievements", "AchievementServer" },
	{ "Daily", "DailyServer" },
	{ "Passes", "MonetizationServer" },
	{ "House", "HouseServer" },
	{ "Brady", "BradyServer" },
	{ "Clothing", "ClothingServer" },
	{ "Age", "AgeServer" },
	{ "Care", "CareServer" },
	{ "Gifts", "GiftServer" },
	{ "Minigames", "MinigameServer" },
	{ "Shop", "ShopServer" },
	{ "Events", "EventServer" },
	{ "Fashion", "FashionServer" },
	{ "Collection", "CollectionServer" },
	{ "Social", "SocialServer" },
}

local ordered = {}
for _, entry in ipairs(LOAD_ORDER) do
	local service = require(Services:WaitForChild(entry[2]))
	S[entry[1]] = service
	table.insert(ordered, { name = entry[1], service = service })
end

-- Runs fn and logs (instead of propagating) any error, with a traceback.
local function safe(label, fn, ...)
	local ok, err = xpcall(fn, debug.traceback, ...)
	if not ok then
		warn("[Main] " .. label .. " failed:\n" .. tostring(err))
	end
	return ok
end

for _, entry in ipairs(ordered) do
	if entry.service.init then
		safe(entry.name .. ".init", entry.service.init, S)
	end
end
for _, entry in ipairs(ordered) do
	if entry.service.start then
		safe(entry.name .. ".start", entry.service.start)
	end
end

----------------------------------------------------------------------
-- Player lifecycle
----------------------------------------------------------------------
local function onPlayerAdded(player)
	local data = S.Data.load(player) -- yields; kicks the player if loading fails
	if not data or not player.Parent then
		return
	end
	for _, entry in ipairs(ordered) do
		if entry.service.playerAdded then
			safe(entry.name .. ".playerAdded", entry.service.playerAdded, player, data)
		end
	end
	S.Data.markReady(player)
end

local function onPlayerRemoving(player)
	if not S.Data.get(player) then
		return
	end
	for index = #ordered, 1, -1 do
		local entry = ordered[index]
		if entry.service.playerRemoving then
			safe(entry.name .. ".playerRemoving", entry.service.playerRemoving, player)
		end
	end
	S.Data.release(player) -- final save + unlock
end

Players.PlayerAdded:Connect(function(player)
	safe("playerAdded", onPlayerAdded, player)
end)
Players.PlayerRemoving:Connect(function(player)
	safe("playerRemoving", onPlayerRemoving, player)
end)
-- Players who joined before this script finished starting (common in Studio).
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(safe, "playerAdded", onPlayerAdded, player)
end

-- Save everyone when the server shuts down.
game:BindToClose(function()
	S.Data.shutdown()
end)

----------------------------------------------------------------------
-- One shared 1-second heartbeat instead of a loop per system.
----------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(1)
		for _, entry in ipairs(ordered) do
			if entry.service.tick then
				safe(entry.name .. ".tick", entry.service.tick)
			end
		end
	end
end)

print("[Raise Brady Goo] server ready")
