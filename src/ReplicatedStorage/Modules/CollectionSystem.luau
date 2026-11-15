--[[
	CollectionSystem
	The collection book: groups of things to collect, how complete each group
	is, and the reward for finishing one. Rewards are claimed through
	Services/CollectionServer, which re-checks completion on the server.
]]

local Modules = script.Parent
local ClothingSystem = require(Modules.ClothingSystem)
local FurnitureSystem = require(Modules.FurnitureSystem)
local AchievementSystem = require(Modules.AchievementSystem)

local CollectionSystem = {}

local function clothingIds(predicate)
	local ids = {}
	for _, item in ipairs(ClothingSystem.List) do
		if predicate(item) then
			table.insert(ids, item.id)
		end
	end
	return ids
end

local function slotSet(slots)
	return function(item)
		return not item.secret and table.find(slots, item.slot) ~= nil
	end
end

local furnitureIds = {}
for _, def in ipairs(FurnitureSystem.List) do
	if not def.vip then
		table.insert(furnitureIds, def.id)
	end
end

local achievementIds = {}
for _, def in ipairs(AchievementSystem.List) do
	table.insert(achievementIds, def.id)
end

-- kind: "clothing" (data.inventory), "furniture" (data.furniture.owned),
--       "achievement" (data.achievements)
CollectionSystem.List = {
	{ id = "basics", name = "Tops & Bottoms", icon = "👕", kind = "clothing", coins = 2500,
		ids = clothingIds(slotSet({ "Shirt", "Pants", "Jacket" })) },
	{ id = "shoes", name = "Shoe Collection", icon = "👟", kind = "clothing", coins = 3000,
		ids = clothingIds(slotSet({ "Shoes" })) },
	{ id = "accessories", name = "Accessory Collection", icon = "📿", kind = "clothing", coins = 4000,
		ids = clothingIds(slotSet({ "Accessory", "Hat", "Glasses" })) },
	{ id = "outfits", name = "Outfit Collection", icon = "✨", kind = "clothing", coins = 6000,
		ids = clothingIds(slotSet({ "Outfit" })) },
	{ id = "hair", name = "Hairstyle Collection", icon = "💇", kind = "clothing", coins = 2500,
		ids = clothingIds(slotSet({ "Hair" })) },
	{ id = "archive", name = "Archive Collection", icon = "🗄️", kind = "clothing", coins = 15000,
		ids = clothingIds(function(item)
			return item.rarity == "Archive"
		end) },
	{ id = "grail", name = "Grail Collection", icon = "🏆", kind = "clothing", coins = 100000, title = "Collection Master",
		ids = clothingIds(function(item)
			return item.rarity == "Grail"
		end) },
	{ id = "rare", name = "Secret Items", icon = "❓", kind = "clothing", coins = 20000, title = "Collection Master",
		ids = clothingIds(function(item)
			return item.secret == true
		end) },
	{ id = "furniture", name = "Furniture Collection", icon = "🛋️", kind = "furniture", coins = 5000, ids = furnitureIds },
	{ id = "achievements", name = "Achievements", icon = "🏅", kind = "achievement", coins = 10000, ids = achievementIds },
}

CollectionSystem.ById = {}
for _, collection in ipairs(CollectionSystem.List) do
	CollectionSystem.ById[collection.id] = collection
end

function CollectionSystem.has(data, collection, id)
	if collection.kind == "clothing" then
		return data.inventory[id] == true
	elseif collection.kind == "furniture" then
		return (data.furniture.owned[id] or 0) > 0
	end
	return data.achievements[id] == true
end

-- Returns owned, total.
function CollectionSystem.progress(data, collection)
	local owned = 0
	for _, id in ipairs(collection.ids) do
		if CollectionSystem.has(data, collection, id) then
			owned += 1
		end
	end
	return owned, #collection.ids
end

function CollectionSystem.isComplete(data, collection)
	local owned, total = CollectionSystem.progress(data, collection)
	return total > 0 and owned >= total
end

-- Overall completion across every collection, 0-100.
function CollectionSystem.totalPercent(data)
	local owned, total = 0, 0
	for _, collection in ipairs(CollectionSystem.List) do
		local o, t = CollectionSystem.progress(data, collection)
		owned += o
		total += t
	end
	if total == 0 then
		return 0
	end
	return math.floor(owned / total * 100 + 0.5)
end

return CollectionSystem
