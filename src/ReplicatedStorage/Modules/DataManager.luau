--[[
	DataManager
	The save-data SCHEMA: the default profile for a new player and the
	reconcile() function that repairs anything loaded from the DataStore.

	Why this lives in ReplicatedStorage: it is only the shape of the data, so
	the client can read it too. The part that actually talks to DataStores
	(loading, saving, session locking) is server-only and lives in
	ServerScriptService/Services/DataServer - clients can never reach it.

	reconcile() is the "basic data corruption" protection. Whatever comes out
	of the DataStore is rebuilt field by field: wrong types are replaced with
	defaults, numbers are clamped, items that no longer exist are dropped and
	equipped items must actually be owned. Age is always re-derived from Age XP
	so the two can never disagree.

	DataStore rules respected here: dictionaries only use string keys, arrays
	have no holes, and there are no NaN / infinite numbers.
]]

local Modules = script.Parent
local Config = require(Modules.Config)
local Util = require(Modules.Util)
local AgeSystem = require(Modules.AgeSystem)
local ClothingSystem = require(Modules.ClothingSystem)
local FurnitureSystem = require(Modules.FurnitureSystem)
local FoodSystem = require(Modules.FoodSystem)
local GiftSystem = require(Modules.GiftSystem)
local AchievementSystem = require(Modules.AchievementSystem)
local CollectionSystem = require(Modules.CollectionSystem)

local DataManager = {}

DataManager.Version = 1

DataManager.StatKeys = {
	"feeds", "cleans", "sleeps", "minigames", "perfectGames", "events", "showsJoined", "showsWon",
	"hidden", "crates", "coinsEarned", "placed", "hypes", "photos", "ageUps",
}

DataManager.SettingDefaults = { music = true, sfx = true, lowGfx = false, chatter = true, dayNight = true, aura = "none" }

local function newStats()
	local stats = {}
	for _, key in ipairs(DataManager.StatKeys) do
		stats[key] = 0
	end
	return stats
end

-- A brand new player's profile.
function DataManager.new()
	return {
		version = DataManager.Version,
		coins = Config.StartCoins,
		ageXP = 0,
		age = 1,
		rebirths = 0,
		meters = { hunger = 55, clean = 70, energy = 90, fun = 55 },
		inventory = { hair_baby = true, plain_tee = true, basic_jeans = true },
		equipped = { Hair = "hair_baby" },
		outfits = {}, -- ["1"] = { Shirt = id, ... }
		food = { fruit = 2, pizza = 1 },
		furniture = { owned = { rug_goo = 1 }, placed = {} },
		gifts = { owned = {}, equipped = {} },
		achievements = {},
		stats = newStats(),
		collectionsClaimed = {},
		stageRewards = { ["1"] = true }, -- stage 1 rewards are the starter kit above
		daily = { lastClaimDay = 0, streak = 0, taskDay = 0, tasks = {}, hiddenDay = 0, hidden = {} },
		title = { name = "", expires = 0 },
		settings = Util.deepCopy(DataManager.SettingDefaults),
		tutorialDone = false,
		createdAt = os.time(),
		lastSeen = os.time(),
	}
end

----------------------------------------------------------------------
-- small sanitising helpers
----------------------------------------------------------------------
local function num(value, default, min, max)
	if not Util.isNumber(value) then
		return default
	end
	return math.clamp(value, min or -math.huge, max or math.huge)
end

local function int(value, default, min, max)
	return math.floor(num(value, default, min, max))
end

local function tbl(value)
	return type(value) == "table" and value or {}
end

-- Keeps only `true` flags whose key passes isValid.
local function flagSet(value, isValid)
	local result = {}
	for key, flag in pairs(tbl(value)) do
		if type(key) == "string" and flag == true and (isValid == nil or isValid(key)) then
			result[key] = true
		end
	end
	return result
end

----------------------------------------------------------------------
-- reconcile(raw) -> clean data table
----------------------------------------------------------------------
function DataManager.reconcile(raw)
	local fresh = DataManager.new()
	if type(raw) ~= "table" then
		return fresh
	end
	local data = {}

	data.version = DataManager.Version
	data.coins = int(raw.coins, fresh.coins, 0, 1e12)
	data.ageXP = int(raw.ageXP, 0, 0, AgeSystem.MaxXP)
	data.age = AgeSystem.ageFromXP(data.ageXP)
	data.rebirths = int(raw.rebirths, 0, 0, 1000)

	local meters = tbl(raw.meters)
	data.meters = {
		hunger = num(meters.hunger, fresh.meters.hunger, 0, 100),
		clean = num(meters.clean, fresh.meters.clean, 0, 100),
		energy = num(meters.energy, fresh.meters.energy, 0, 100),
		fun = num(meters.fun, fresh.meters.fun, 0, 100),
	}

	-- Inventory: only item ids that still exist in the catalog.
	data.inventory = flagSet(raw.inventory, function(id)
		return ClothingSystem.Items[id] ~= nil
	end)
	for id in pairs(fresh.inventory) do
		data.inventory[id] = true -- nobody can lose the starter kit
	end

	-- Equipped: must be owned and sitting in the right slot.
	data.equipped = {}
	for slot, id in pairs(tbl(raw.equipped)) do
		local item = type(id) == "string" and ClothingSystem.Items[id]
		if item and item.slot == slot and data.inventory[id] then
			data.equipped[slot] = id
		end
	end

	-- Saved outfits.
	data.outfits = {}
	for key, outfit in pairs(tbl(raw.outfits)) do
		local index = tonumber(key)
		if index and index >= 1 and index <= Config.OutfitSlotsWithPass and type(outfit) == "table" then
			local clean = {}
			for slot, id in pairs(outfit) do
				local item = type(id) == "string" and ClothingSystem.Items[id]
				if item and item.slot == slot and data.inventory[id] then
					clean[slot] = id
				end
			end
			data.outfits[tostring(math.floor(index))] = clean
		end
	end

	data.food = {}
	for id, amount in pairs(tbl(raw.food)) do
		if type(id) == "string" and FoodSystem.ById[id] then
			data.food[id] = int(amount, 0, 0, Config.MaxFoodStackWithPass)
		end
	end

	-- Furniture: owned counts, then placements (never more placed than owned).
	local furniture = tbl(raw.furniture)
	data.furniture = { owned = {}, placed = {} }
	for id, amount in pairs(tbl(furniture.owned)) do
		if type(id) == "string" and FurnitureSystem.ById[id] then
			local count = int(amount, 0, 0, 999)
			if count > 0 then
				data.furniture.owned[id] = count
			end
		end
	end
	local placedCounts = {}
	for _, placement in ipairs(tbl(furniture.placed)) do
		if type(placement) == "table" and type(placement.id) == "string" and FurnitureSystem.ById[placement.id] then
			local id = placement.id
			local used = placedCounts[id] or 0
			if used < (data.furniture.owned[id] or 0) and #data.furniture.placed < Config.MaxPlacedFurnitureWithPass then
				placedCounts[id] = used + 1
				table.insert(data.furniture.placed, {
					id = id,
					x = int(placement.x, 0, -200, 200),
					z = int(placement.z, 0, -200, 200),
					r = int(placement.r, 0, 0, 3),
				})
			end
		end
	end

	local gifts = tbl(raw.gifts)
	data.gifts = { owned = flagSet(gifts.owned, function(id)
		return GiftSystem.ById[id] ~= nil
	end), equipped = {} }
	for slot, id in pairs(tbl(gifts.equipped)) do
		local gift = type(id) == "string" and GiftSystem.ById[id]
		if gift and gift.slot == slot and data.gifts.owned[id] then
			data.gifts.equipped[slot] = id
		end
	end

	data.achievements = flagSet(raw.achievements, function(id)
		return AchievementSystem.ById[id] ~= nil
	end)
	data.collectionsClaimed = flagSet(raw.collectionsClaimed, function(id)
		return CollectionSystem.ById[id] ~= nil
	end)
	data.stageRewards = flagSet(raw.stageRewards, function(key)
		return tonumber(key) ~= nil
	end)
	data.stageRewards["1"] = true

	data.stats = newStats()
	for _, key in ipairs(DataManager.StatKeys) do
		data.stats[key] = int(tbl(raw.stats)[key], 0, 0, 1e12)
	end

	local daily = tbl(raw.daily)
	data.daily = {
		lastClaimDay = int(daily.lastClaimDay, 0, 0, 1e7),
		streak = int(daily.streak, 0, 0, 1e6),
		taskDay = int(daily.taskDay, 0, 0, 1e7),
		tasks = {},
		hiddenDay = int(daily.hiddenDay, 0, 0, 1e7),
		hidden = flagSet(daily.hidden, function(key)
			return tonumber(key) ~= nil
		end),
	}
	for _, task in ipairs(tbl(daily.tasks)) do
		if type(task) == "table" and type(task.id) == "string" and #data.daily.tasks < 3 then
			table.insert(data.daily.tasks, {
				id = task.id,
				progress = int(task.progress, 0, 0, 1e9),
				claimed = task.claimed == true,
			})
		end
	end

	local title = tbl(raw.title)
	data.title = {
		name = type(title.name) == "string" and string.sub(title.name, 1, 40) or "",
		expires = int(title.expires, 0, 0, 1e11),
	}

	data.settings = {}
	local settings = tbl(raw.settings)
	for key, default in pairs(DataManager.SettingDefaults) do
		if type(settings[key]) == type(default) then
			data.settings[key] = settings[key]
		else
			data.settings[key] = default
		end
	end

	data.tutorialDone = raw.tutorialDone == true
	data.createdAt = int(raw.createdAt, os.time(), 0, 1e11)
	data.lastSeen = int(raw.lastSeen, os.time(), 0, 1e11)

	return data
end

return DataManager
