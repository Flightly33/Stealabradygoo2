--[[
	ShopSystem
	Crate ("haul") definitions and the weighted roll that picks what drops.

	Crates are bought with Goo Coins only. Goo Coins cannot be bought with
	Robux anywhere in this game, so crates are never a paid random item, and
	the odds are still shown to the player in the shop.
]]

local Modules = script.Parent
local Util = require(Modules.Util)
local ClothingSystem = require(Modules.ClothingSystem)

local ShopSystem = {}

local rgb = Color3.fromRGB

-- odds = relative weight per rarity. Grail is intentionally tiny.
ShopSystem.Crates = {
	{
		id = "thrift_bin", name = "Thrift Bin", icon = "🧺", price = 250, minAge = 1, color = rgb(120, 200, 120),
		desc = "dig through the bin. mostly basics. sometimes magic.",
		odds = { Common = 55, Uncommon = 32, Rare = 11, Epic = 2 },
	},
	{
		id = "designer_drop", name = "Designer Drop", icon = "🛍️", price = 1500, minAge = 10, color = rgb(90, 150, 255),
		desc = "limited release. he camped outside for it.",
		odds = { Uncommon = 34, Rare = 44, Epic = 18, Legendary = 3.7, Archive = 0.3 },
	},
	{
		id = "archive_vault", name = "Archive Vault", icon = "🗄️", price = 6000, minAge = 18, color = rgb(232, 66, 78),
		desc = "pieces from collections older than brady.",
		odds = { Rare = 30, Epic = 42, Legendary = 19, Archive = 8.6, Grail = 0.4 },
	},
	{
		id = "grail_vault", name = "Grail Vault", icon = "🏆", price = 20000, minAge = 21, color = rgb(255, 110, 225),
		desc = "the best odds anywhere. still brutal.",
		odds = { Epic = 40, Legendary = 36, Archive = 22, Grail = 2 },
	},
}

-- Loot table for the "BRADY FOUND A GRAIL" random event box (never bought).
ShopSystem.EventBox = { id = "event_box", name = "Mystery Box", odds = { Uncommon = 30, Rare = 40, Epic = 22, Legendary = 6.5, Archive = 1.3, Grail = 0.2 } }
-- Day 7 daily reward roll.
ShopSystem.DailyBox = { id = "daily_box", name = "Daily Fashion Item", odds = { Rare = 50, Epic = 36, Legendary = 12, Archive = 2 } }

ShopSystem.CrateById = {}
for _, crate in ipairs(ShopSystem.Crates) do
	ShopSystem.CrateById[crate.id] = crate
end

-- Droppable items grouped by rarity.
local pool = {}
for _, rarity in ipairs(ClothingSystem.RarityOrder) do
	pool[rarity] = {}
end
for _, item in ipairs(ClothingSystem.List) do
	if item.drop then
		table.insert(pool[item.rarity], item)
	end
end
ShopSystem.Pool = pool

-- Odds as percentages for the UI: { { rarity = "Common", percent = 55 }, ... }
function ShopSystem.oddsList(crate)
	local total = 0
	for _, weight in pairs(crate.odds) do
		total += weight
	end
	local list = {}
	for _, rarity in ipairs(ClothingSystem.RarityOrder) do
		local weight = crate.odds[rarity]
		if weight then
			table.insert(list, { rarity = rarity, percent = weight / total * 100 })
		end
	end
	return list
end

-- Rolls a crate. Returns an item definition (never nil for a valid crate).
-- `rng` is optional (a Random object) so tests can be deterministic.
function ShopSystem.roll(crate, rng)
	local entries = {}
	for rarity, weight in pairs(crate.odds) do
		if #pool[rarity] > 0 then
			table.insert(entries, { rarity = rarity, weight = weight })
		end
	end
	-- Sort so the roll does not depend on dictionary iteration order.
	table.sort(entries, function(a, b)
		return ClothingSystem.rarityOrder(a.rarity) < ClothingSystem.rarityOrder(b.rarity)
	end)
	local chosen = Util.weighted(entries, function(entry)
		return entry.weight
	end, rng)
	if not chosen then
		return nil
	end
	return Util.pick(pool[chosen.rarity], rng)
end

return ShopSystem
