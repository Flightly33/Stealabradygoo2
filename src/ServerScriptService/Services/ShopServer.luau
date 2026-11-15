--[[
	ShopServer
	Everything bought with Goo Coins: clothing, hairstyles, food, furniture /
	decorations / toys, and crates. Prices come from the shared catalogs, never
	from the client, and the coins are taken before anything is granted.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local ClothingSystem = require(Modules.ClothingSystem)
local Config = require(Modules.Config)
local FoodSystem = require(Modules.FoodSystem)
local FurnitureSystem = require(Modules.FurnitureSystem)
local ShopSystem = require(Modules.ShopSystem)

local ShopServer = {}

local S

local function fail(reason)
	return { ok = false, reason = reason }
end

local function buyClothing(player, data, id)
	local item = ClothingSystem.get(id)
	if not item or not item.price then
		return fail("that isn't for sale")
	end
	if data.inventory[id] then
		return fail("you already own that")
	end
	if data.age < item.age then
		return fail("Brady must be age " .. item.age)
	end
	if not S.Currency.spend(player, item.price) then
		return fail("not enough Goo Coins")
	end
	S.Clothing.grant(player, id, "shop")
	return { ok = true }
end

local function buyFood(player, data, id, quantity)
	local food = FoodSystem.get(id)
	if not food or food.free then
		return fail("that isn't for sale")
	end
	if type(quantity) ~= "number" or quantity % 1 ~= 0 or quantity < 1 or quantity > 10 then
		return fail("bad amount")
	end
	if data.age < (food.minAge or 1) then
		return fail("unlocks at age " .. food.minAge)
	end
	local cap = S.Passes.has(player, "ExtraStorage") and Config.MaxFoodStackWithPass or Config.MaxFoodStack
	local have = data.food[id] or 0
	if have + quantity > cap then
		return fail("your pantry only fits " .. cap .. " of each food")
	end
	if not S.Currency.spend(player, food.price * quantity) then
		return fail("not enough Goo Coins")
	end
	data.food[id] = have + quantity
	S.Data.sync(player, "food")
	return { ok = true }
end

local function buyFurniture(player, data, id)
	local def = FurnitureSystem.get(id)
	if not def or not def.price or def.special then
		return fail("that isn't for sale")
	end
	if def.vip and not S.Passes.has(player, "VIPDecor") then
		return fail("needs the VIP Room Decorations pass")
	end
	if data.age < (def.minAge or 1) then
		return fail("unlocks at age " .. def.minAge)
	end
	if (data.furniture.owned[id] or 0) >= 20 then
		return fail("you own plenty of those already")
	end
	if not S.Currency.spend(player, def.price) then
		return fail("not enough Goo Coins")
	end
	data.furniture.owned[id] = (data.furniture.owned[id] or 0) + 1
	S.Data.sync(player, "furniture")
	S.Net.fire(player, "ItemGranted", { kind = "furniture", id = id, isNew = true, source = "shop" })
	S.Achievements.check(player)
	return { ok = true }
end

local function buy(player, data, kind, id, quantity)
	if type(kind) ~= "string" or type(id) ~= "string" then
		return fail("bad request")
	end
	if kind == "clothing" then
		return buyClothing(player, data, id)
	elseif kind == "food" then
		return buyFood(player, data, id, quantity or 1)
	elseif kind == "furniture" then
		return buyFurniture(player, data, id)
	end
	return fail("bad request")
end

local function openCrate(player, data, crateId)
	local crate = type(crateId) == "string" and ShopSystem.CrateById[crateId]
	if not crate then
		return fail("unknown crate")
	end
	if data.age < crate.minAge then
		return fail("unlocks at age " .. crate.minAge)
	end
	if not S.Currency.spend(player, crate.price) then
		return fail("not enough Goo Coins")
	end
	local item = ShopSystem.roll(crate)
	if not item then
		S.Currency.add(player, crate.price, "refund")
		return fail("the crate was empty?? (refunded)")
	end
	-- Granted silently: the client plays the crate reveal, then announces it.
	local result = S.Clothing.grant(player, item.id, "crate", true)
	S.Achievements.bump(player, "crates", 1)
	if result.isNew and ClothingSystem.rarityOrder(item.rarity) >= 5 then
		S.House.refreshDisplays(player)
	end
	return { ok = true, itemId = item.id, isNew = result.isNew, refund = result.refund }
end

function ShopServer.init(services)
	S = services
	S.Net.handle("Buy", buy, 6)
	S.Net.handle("OpenCrate", openCrate, 3)
end

return ShopServer
