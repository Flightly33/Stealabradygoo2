--[[
	CurrencySystem
	Shared facts about Goo Coins: the reward table and formatting.
	The actual wallet changes happen in Services/CurrencyServer (server only).
]]

local Modules = script.Parent
local Util = require(Modules.Util)
local ClothingSystem = require(Modules.ClothingSystem)

local CurrencySystem = {}

CurrencySystem.Name = "Goo Coins"
CurrencySystem.Icon = "🟢"

-- Base coin rewards. Most are multiplied by AgeSystem.rewardMultiplier().
CurrencySystem.Rewards = {
	Feed = 5,
	Shower = 14,
	BrushHair = 7,
	CleanShoes = 7,
	ChangeClothes = 6,
	PlayToy = 6,
	TutorialDone = 100,
	Hidden = 40,
}

-- Coins for reaching a new age. Milestone stages add their own bonus on top.
function CurrencySystem.ageUpReward(age)
	return 40 + age * 25
end

-- Duplicate crate items are converted into coins.
function CurrencySystem.sellValue(rarity)
	local info = ClothingSystem.Rarities[rarity]
	return info and info.sell or 0
end

function CurrencySystem.canAfford(data, price)
	return Util.isNumber(price) and price >= 0 and data.coins >= price
end

function CurrencySystem.format(amount)
	return Util.short(amount)
end

return CurrencySystem
