--[[
	AchievementServer
	Owns the stat counters (feeds, mini-games played, ...) and unlocks
	achievements when their condition is met. Each achievement can only ever
	pay out once because the flag is written before the coins are granted.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local AchievementSystem = require(Modules.AchievementSystem)

local AchievementServer = {}

local S

function AchievementServer.init(services)
	S = services
end

-- Checks every locked achievement for this player.
function AchievementServer.check(player)
	local data = S.Data.get(player)
	if not data then
		return
	end
	local unlocked = false
	for _, def in ipairs(AchievementSystem.List) do
		if not data.achievements[def.id] and AchievementSystem.isComplete(def, data) then
			data.achievements[def.id] = true -- flag first: no double payouts
			unlocked = true
			S.Net.notify(player, { text = "ACHIEVEMENT UNLOCKED!", sub = def.name .. "  +" .. def.coins .. " Goo Coins", kind = "good", sound = "rare" })
			S.Currency.add(player, def.coins, "achievement")
		end
	end
	if unlocked then
		S.Data.sync(player, "achievements")
	end
end

-- Adds to a stat counter, advances daily tasks and re-checks achievements.
function AchievementServer.bump(player, stat, amount)
	local data = S.Data.get(player)
	if not data then
		return
	end
	amount = amount or 1
	data.stats[stat] = (data.stats[stat] or 0) + amount
	S.Data.sync(player, "stats")
	S.Daily.progress(player, stat, amount)
	AchievementServer.check(player)
end

function AchievementServer.playerAdded(player)
	-- Catches achievements earned by rule changes while the player was away.
	AchievementServer.check(player)
end

return AchievementServer
