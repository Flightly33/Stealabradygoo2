--[[
	AchievementSystem
	Achievement definitions. Each one is unlocked automatically by
	Services/AchievementServer the moment its condition becomes true, and pays
	out its Goo Coins exactly once (data.achievements[id] guards the payout).

	kind = "stat"   -> data.stats[stat] >= goal
	other kinds are small special cases handled in AchievementSystem.value().
]]

local Modules = script.Parent
local ClothingSystem = require(Modules.ClothingSystem)

local AchievementSystem = {}

AchievementSystem.List = {
	{ id = "first_bite", name = "First Bite", desc = "Feed Brady for the first time", kind = "stat", stat = "feeds", goal = 1, coins = 25 },
	{ id = "chef", name = "Personal Chef", desc = "Feed Brady 50 times", kind = "stat", stat = "feeds", goal = 50, coins = 300 },
	{ id = "buffet", name = "All You Can Eat", desc = "Feed Brady 250 times", kind = "stat", stat = "feeds", goal = 250, coins = 1500 },
	{ id = "squeaky", name = "Squeaky Clean", desc = "Clean Brady 25 times", kind = "stat", stat = "cleans", goal = 25, coins = 250 },
	{ id = "nap_time", name = "Nap Time", desc = "Put Brady to bed 10 times", kind = "stat", stat = "sleeps", goal = 10, coins = 200 },
	{ id = "gamer", name = "Gamer", desc = "Play 10 mini-games", kind = "stat", stat = "minigames", goal = 10, coins = 200 },
	{ id = "pro_gamer", name = "Pro Gamer", desc = "Play 100 mini-games", kind = "stat", stat = "minigames", goal = 100, coins = 1500 },
	{ id = "perfect", name = "Flawless", desc = "Get a near-perfect mini-game score", kind = "stat", stat = "perfectGames", goal = 1, coins = 300 },
	{ id = "eventful", name = "Eventful", desc = "Complete 10 random events", kind = "stat", stat = "events", goal = 10, coins = 500 },
	{ id = "explorer", name = "Explorer", desc = "Find 10 hidden goo blobs", kind = "stat", stat = "hidden", goal = 10, coins = 300 },
	{ id = "treasure", name = "Treasure Hunter", desc = "Find 100 hidden goo blobs", kind = "stat", stat = "hidden", goal = 100, coins = 2000 },
	{ id = "debut", name = "Runway Debut", desc = "Enter a fashion show", kind = "stat", stat = "showsJoined", goal = 1, coins = 150 },
	{ id = "winner", name = "Best Dressed", desc = "Win a fashion show", kind = "stat", stat = "showsWon", goal = 1, coins = 500 },
	{ id = "icon", name = "Fashion Icon", desc = "Win 10 fashion shows", kind = "stat", stat = "showsWon", goal = 10, coins = 5000 },
	{ id = "unboxer", name = "Unboxer", desc = "Open 20 crates", kind = "stat", stat = "crates", goal = 20, coins = 800 },
	{ id = "decorator", name = "Interior Designer", desc = "Place furniture 10 times", kind = "stat", stat = "placed", goal = 10, coins = 300 },
	{ id = "rich", name = "Goo Millionaire (kinda)", desc = "Earn 50,000 Goo Coins in total", kind = "stat", stat = "coinsEarned", goal = 50000, coins = 2500 },
	{ id = "photographer", name = "Fit Pic", desc = "Take a mirror screenshot", kind = "stat", stat = "photos", goal = 1, coins = 100 },
	{ id = "collector_10", name = "Starter Closet", desc = "Own 10 clothing items", kind = "items", goal = 10, coins = 200 },
	{ id = "collector_30", name = "Walk-In Closet", desc = "Own 30 clothing items", kind = "items", goal = 30, coins = 1000 },
	{ id = "collector_60", name = "Warehouse", desc = "Own 60 clothing items", kind = "items", goal = 60, coins = 4000 },
	{ id = "first_archive", name = "Archive Era", desc = "Own an Archive item", kind = "rarity", rarity = "Archive", goal = 1, coins = 1500 },
	{ id = "grail_found", name = "GRAIL FOUND", desc = "Own a Grail item", kind = "rarity", rarity = "Grail", goal = 1, coins = 10000 },
	{ id = "secret_finder", name = "Secret Finder", desc = "Find a secret item", kind = "secrets", goal = 1, coins = 1000 },
	{ id = "age_10", name = "Double Digits", desc = "Raise Brady to age 10", kind = "age", goal = 10, coins = 500 },
	{ id = "age_18", name = "Officially Archive", desc = "Raise Brady to age 18", kind = "age", goal = 18, coins = 2500 },
	{ id = "age_25", name = "Legendary", desc = "Raise Brady to age 25", kind = "age", goal = 25, coins = 10000 },
	{ id = "streak_7", name = "Dedicated", desc = "Reach a 7 day login streak", kind = "streak", goal = 7, coins = 1000 },
	{ id = "reborn", name = "Reborn", desc = "Rebirth Brady", kind = "rebirths", goal = 1, coins = 5000 },
}

AchievementSystem.ById = {}
for _, def in ipairs(AchievementSystem.List) do
	AchievementSystem.ById[def.id] = def
end

-- Current progress value for an achievement.
function AchievementSystem.value(def, data)
	if def.kind == "stat" then
		return data.stats[def.stat] or 0
	elseif def.kind == "age" then
		return data.rebirths > 0 and math.max(data.age, def.goal) or data.age
	elseif def.kind == "streak" then
		return data.daily.streak
	elseif def.kind == "rebirths" then
		return data.rebirths
	end
	-- item based
	local n = 0
	for itemId in pairs(data.inventory) do
		local item = ClothingSystem.get(itemId)
		if item then
			if def.kind == "items" then
				n += 1
			elseif def.kind == "rarity" and item.rarity == def.rarity then
				n += 1
			elseif def.kind == "secrets" and item.secret then
				n += 1
			end
		end
	end
	return n
end

function AchievementSystem.isComplete(def, data)
	return AchievementSystem.value(def, data) >= def.goal
end

return AchievementSystem
