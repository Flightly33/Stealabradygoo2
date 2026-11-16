--[[
	AdminServer
	Owner-only cheat panel for testing and running the game.

	Who is an admin (checked on the SERVER for every single request):
	  * the experience owner (or the owner of the group that owns it)
	  * any user id listed in Config.AdminUserIds
	  * anyone playing inside Roblox Studio
	Non-admins never even see the button, and requests they send are ignored.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage.Modules
local AgeSystem = require(Modules.AgeSystem)
local ClothingSystem = require(Modules.ClothingSystem)
local Config = require(Modules.Config)
local EventSystem = require(Modules.EventSystem)
local FurnitureSystem = require(Modules.FurnitureSystem)

local AdminServer = {}

local S

local function isAdmin(player)
	if RunService:IsStudio() or table.find(Config.AdminUserIds, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(function()
		return player:GetRankInGroup(game.CreatorId)
	end)
	return ok and rank == 255
end

-- action -> function(player, data, arg)
local ACTIONS = {}

function ACTIONS.Coins(player, _data, amount)
	amount = tonumber(amount) or 10000
	S.Currency.add(player, math.clamp(math.floor(amount), 1, 1e9), "admin")
end

function ACTIONS.AgeUp(player, data)
	if data.age < AgeSystem.MaxAge then
		S.Age.addXP(player, AgeSystem.totalXPForAge(data.age + 1) - data.ageXP, { raw = true })
	end
end

function ACTIONS.MaxAge(player, data)
	S.Age.addXP(player, AgeSystem.MaxXP - data.ageXP, { raw = true })
end

function ACTIONS.AllItems(player, data)
	for _, item in ipairs(ClothingSystem.List) do
		data.inventory[item.id] = true
	end
	for _, def in ipairs(FurnitureSystem.List) do
		data.furniture.owned[def.id] = math.max(data.furniture.owned[def.id] or 0, 3)
	end
	S.Data.sync(player, "inventory", "furniture")
	S.Achievements.check(player)
	S.Net.toast(player, "all items unlocked", "good")
end

function ACTIONS.FillNeeds(player, data)
	data.meters = { hunger = 100, clean = 100, energy = 100, fun = 100 }
	S.Data.sync(player, "meters")
end

function ACTIONS.Event(player, _data, id)
	if type(id) ~= "string" or not EventSystem.get(id) then
		local list = EventSystem.List
		id = list[math.random(1, #list)].id
	end
	if not S.Events.force(player, id) then
		S.Net.toast(player, "an event is already running", "bad")
	end
end

function ACTIONS.Secret()
	S.Collection.forceSecret()
end

function ACTIONS.ResetDaily(player, data)
	data.daily.lastClaimDay = 0
	S.Data.sync(player, "daily")
	S.Net.toast(player, "daily reward can be claimed again", "good")
end

function AdminServer.init(services)
	S = services
	S.Net.on("Admin", function(player, data, action, arg)
		if not isAdmin(player) then
			return
		end
		local fn = type(action) == "string" and ACTIONS[action]
		if fn then
			fn(player, data, arg)
		end
	end, 10)
end

function AdminServer.playerAdded(player)
	local session = S.Data.session(player)
	session.isAdmin = isAdmin(player)
	S.Data.syncSession(player, "isAdmin")
end

AdminServer.isAdmin = isAdmin
local _ = Players

return AdminServer
