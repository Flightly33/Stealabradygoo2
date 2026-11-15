--[[
	CurrencyServer
	The ONLY place Goo Coins are added or removed. Every other service calls
	Currency.add / Currency.spend, so the client can never set its own balance.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local AgeSystem = require(Modules.AgeSystem)
local Util = require(Modules.Util)

local CurrencyServer = {}

local S
local MAX_COINS = 1e12

function CurrencyServer.init(services)
	S = services
end

-- Gives coins. Returns the amount actually added.
function CurrencyServer.add(player, amount, _reason)
	local data = S.Data.get(player)
	if not data or not Util.isNumber(amount) then
		return 0
	end
	amount = math.floor(amount)
	if amount <= 0 then
		return 0
	end
	data.coins = math.min(MAX_COINS, data.coins + amount)
	S.Data.sync(player, "coins")
	S.Achievements.bump(player, "coinsEarned", amount)
	return amount
end

-- Takes coins if the player can afford it. Returns true on success.
function CurrencyServer.spend(player, amount)
	local data = S.Data.get(player)
	if not data or not Util.isNumber(amount) then
		return false
	end
	amount = math.floor(amount)
	if amount < 0 or data.coins < amount then
		return false
	end
	data.coins -= amount
	S.Data.sync(player, "coins")
	return true
end

-- Scales a base reward by Brady's age and the player's rebirths.
function CurrencyServer.scaled(player, base)
	local data = S.Data.get(player)
	if not data then
		return 0
	end
	return math.max(1, Util.round(base * AgeSystem.rewardMultiplier(data.age, data.rebirths)))
end

return CurrencyServer
