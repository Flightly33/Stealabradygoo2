--[[
	FashionSystem
	Fashion show categories, the titles winners receive, and the "judge score"
	formula. The judges exist so a show still works with one player online:
	real player votes are simply added on top of the judges' opinion.
]]

local Modules = script.Parent
local ClothingSystem = require(Modules.ClothingSystem)
local InventorySystem = require(Modules.InventorySystem)

local FashionSystem = {}

local rgb = Color3.fromRGB

FashionSystem.Categories = {
	{ id = "Streetwear", name = "Best Streetwear", title = "Goo Stylist", hint = "street pieces score big" },
	{ id = "Archive", name = "Most Archive", title = "Archive Collector", hint = "Archive + Grail pieces and anything vintage" },
	{ id = "Funniest", name = "Funniest Fit", title = "Fit Comedian", hint = "the goofier the better" },
	{ id = "Shoes", name = "Best Shoes", title = "Sole Legend", hint = "it's all about the kicks" },
	{ id = "Overall", name = "Best Overall", title = "Goo Fashion Icon", hint = "the best total fit wins" },
	{ id = "Drippy", name = "Most Drippy", title = "Certified Drip", hint = "rare pieces and glowing effects" },
}

FashionSystem.CategoryById = {}
for _, category in ipairs(FashionSystem.Categories) do
	FashionSystem.CategoryById[category.id] = category
end

-- Title colours for nameplates.
FashionSystem.TitleColors = {
	["Goo Stylist"] = rgb(90, 200, 255),
	["Archive Collector"] = rgb(232, 66, 78),
	["Fit Comedian"] = rgb(255, 170, 60),
	["Sole Legend"] = rgb(120, 255, 170),
	["Goo Fashion Icon"] = rgb(255, 205, 60),
	["Certified Drip"] = rgb(120, 220, 255),
	["Collection Master"] = rgb(255, 110, 225),
}

local function hasTag(item, tag)
	return table.find(item.tags, tag) ~= nil
end

-- What the judges think of a fit for a category. Higher = better.
-- `equipped` is a { slot = itemId } table. `rng` is optional.
function FashionSystem.judgeScore(categoryId, equipped, rng)
	local items = InventorySystem.equippedItems(equipped)
	local score = 0
	local rarities = {}
	for _, item in ipairs(items) do
		local points = ClothingSystem.Rarities[item.rarity].points
		if item.slot == "Outfit" then
			points *= 3
		end
		rarities[item.rarity] = true
		if categoryId == "Streetwear" then
			score += hasTag(item, "street") and points * 2 or points * 0.3
		elseif categoryId == "Archive" then
			if item.rarity == "Archive" or item.rarity == "Grail" then
				score += points * 2.5
			elseif hasTag(item, "vintage") then
				score += points * 1.5
			else
				score += points * 0.2
			end
		elseif categoryId == "Funniest" then
			score += hasTag(item, "funny") and (8 + points) or points * 0.2
		elseif categoryId == "Shoes" then
			score += item.slot == "Shoes" and points * 5 or points * 0.15
			if item.slot == "Outfit" then
				score += points -- outfits come with shoes
			end
		elseif categoryId == "Drippy" then
			score += points + (item.fx and 6 or 0)
		else -- Overall
			score += points * 1.2
		end
	end
	if categoryId == "Funniest" then
		-- Chaos bonus: lots of different rarities, or forgetting pants entirely.
		local distinct = 0
		for _ in pairs(rarities) do
			distinct += 1
		end
		score += distinct * 3
		if InventorySystem.isBadFit(equipped) then
			score += 10
		end
	end
	-- Judges are a little unpredictable (+/- 15%).
	local roll = rng and rng:NextNumber() or math.random()
	return math.max(1, score) * (0.85 + roll * 0.3)
end

-- Final score = judges + a big bonus per real vote.
function FashionSystem.finalScore(judgeScore, votes, bestJudgeScore)
	return judgeScore + votes * math.max(8, bestJudgeScore * 0.35)
end

return FashionSystem
