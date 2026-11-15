--[[
	Automated test suite for Raise Brady Goo.

	Usage (from the repository root):
	    rojo build default.project.json -o build/test.rbxl
	    lune run tests/run.luau

	It boots the real game scripts inside the fake engine from harness.luau,
	joins fake players and plays through every system on a virtual clock.
	Pass a test name fragment as an argument to run only matching tests:
	    lune run tests/run.luau fashion
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local H = require("./harness")
local roblox = H.roblox
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

local filter = process.args[1]
local SECTION = process.args[2] -- optional: "server" or "client"

H.boot(fs.readFile("build/test.rbxl"), { studio = false })

local RS = H.ReplicatedStorage
local SSS = H.ServerScriptService
local function shared(name)
	return H.server.require(RS.Modules:FindFirstChild(name) or RS.Modules.Builders:FindFirstChild(name))
end
local function service(name)
	return H.server.require(SSS.Services:FindFirstChild(name))
end

----------------------------------------------------------------------
-- tiny test framework
----------------------------------------------------------------------
local results = { passed = 0, failed = 0, failures = {} }
local seenErrors, seenWarnings = 0, 0

local function check(condition, message)
	if not condition then
		error(message or "check failed", 2)
	end
end

local function eq(actual, expected, message)
	if actual ~= expected then
		error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

-- Runs fn inside a scheduler thread (so it may yield) and returns its results.
local function run(fn, ...)
	local args = table.pack(...)
	local result
	local thread = H.task.spawn(function()
		result = table.pack(fn(table.unpack(args, 1, args.n)))
	end)
	local guard = 0
	while not result and coroutine.status(thread) ~= "dead" and guard < 20000 do
		H.advance(0.1)
		guard += 1
	end
	if not result then
		error("call did not finish: " .. tostring(H.errors[#H.errors]), 2)
	end
	return table.unpack(result, 1, result.n)
end

local allowWarnings = false

local function test(name, fn)
	if filter and filter ~= "all" and not string.find(string.lower(name), string.lower(filter), 1, true) then
		return
	end
	local ok, err = xpcall(fn, function(e)
		return tostring(e) .. "\n" .. debug.traceback()
	end)
	H.flush()
	local newErrors = {}
	for i = seenErrors + 1, #H.errors do
		table.insert(newErrors, H.errors[i])
	end
	seenErrors = #H.errors
	local newWarnings = {}
	for i = seenWarnings + 1, #H.warnings do
		table.insert(newWarnings, H.warnings[i])
	end
	seenWarnings = #H.warnings
	if ok and #newErrors == 0 and (allowWarnings or #newWarnings == 0) then
		results.passed += 1
		print("  PASS  " .. name)
	else
		results.failed += 1
		print("  FAIL  " .. name)
		local detail = {}
		if not ok then
			table.insert(detail, tostring(err))
		end
		for i, e in ipairs(newErrors) do
			if i <= 3 then
				table.insert(detail, "uncaught error: " .. e)
			end
		end
		if not allowWarnings then
			for i, w in ipairs(newWarnings) do
				if i <= 3 then
					table.insert(detail, "warning: " .. w)
				end
			end
		end
		local text = table.concat(detail, "\n")
		print("        " .. string.gsub(string.sub(text, 1, 1800), "\n", "\n        "))
		table.insert(results.failures, name)
	end
	allowWarnings = false
end

local function count(dict)
	local n = 0
	for _ in pairs(dict) do
		n += 1
	end
	return n
end

----------------------------------------------------------------------
-- 1. Pure data modules
----------------------------------------------------------------------
print("\n== shared modules ==")
local AgeSystem = shared("AgeSystem")
local ClothingSystem = shared("ClothingSystem")
local FurnitureSystem = shared("FurnitureSystem")
local GiftSystem = shared("GiftSystem")
local HouseSystem = shared("HouseSystem")
local ShopSystem = shared("ShopSystem")
local DataManager = shared("DataManager")
local InventorySystem = shared("InventorySystem")
local FashionSystem = shared("FashionSystem")
local CollectionSystem = shared("CollectionSystem")
local DailySystem = shared("DailySystem")
local MinigameSystem = shared("MinigameSystem")
local EventSystem = shared("EventSystem")
local FoodSystem = shared("FoodSystem")
local Config = shared("Config")
local Util = shared("Util")
local AchievementSystem = shared("AchievementSystem")
local Monetization = shared("Monetization")

test("age curve is monotonic and ends at 25", function()
	eq(AgeSystem.ageFromXP(0), 1)
	eq(AgeSystem.ageFromXP(AgeSystem.MaxXP), 25)
	eq(AgeSystem.ageFromXP(AgeSystem.MaxXP * 10), 25)
	local last = 0
	for age = 2, 25 do
		local need = AgeSystem.totalXPForAge(age)
		check(need > last, "xp must increase at age " .. age)
		eq(AgeSystem.ageFromXP(need), age)
		eq(AgeSystem.ageFromXP(need - 1), age - 1)
		last = need
	end
	eq(#AgeSystem.Stages, 10)
	local ages = { 1, 3, 5, 8, 10, 13, 16, 18, 21, 25 }
	for i, stage in ipairs(AgeSystem.Stages) do
		eq(stage.age, ages[i])
	end
	eq(AgeSystem.houseSize(1), 24)
	eq(AgeSystem.houseSize(25), 60)
end)

test("every stage reward refers to something that exists", function()
	for _, stage in ipairs(AgeSystem.Stages) do
		check(ClothingSystem.get(stage.look.hair), "missing hair " .. stage.look.hair)
		for _, id in ipairs(stage.rewards.items or {}) do
			check(ClothingSystem.get(id), "missing clothing " .. id)
		end
		if stage.rewards.furniture then
			check(FurnitureSystem.get(stage.rewards.furniture), "missing furniture " .. stage.rewards.furniture)
		end
		for _, key in ipairs({ "gift", "gift2" }) do
			if stage.rewards[key] then
				check(GiftSystem.get(stage.rewards[key]), "missing gift " .. stage.rewards[key])
			end
		end
		check(AgeSystem.PoseById[stage.rewards.pose], "missing pose " .. tostring(stage.rewards.pose))
		if stage.unlockSlot then
			check(ClothingSystem.SlotInfo[stage.unlockSlot], "bad slot " .. stage.unlockSlot)
		end
	end
	for _, item in ipairs(ClothingSystem.List) do
		if item.pose then
			check(AgeSystem.PoseById[item.pose], "item pose missing " .. item.pose)
		end
		-- An item must never need an age below the age its category unlocks at.
		if item.price then
			check(item.age >= AgeSystem.slotUnlockAge(item.slot), item.id .. " is sold before its slot unlocks")
		end
	end
	for _, pass in ipairs(Monetization.Passes) do
		check(type(pass.id) == "number")
	end
end)

test("catalog has every rarity and slot, and all seven secret items", function()
	for _, rarity in ipairs(ClothingSystem.RarityOrder) do
		check(#ClothingSystem.ByRarity[rarity] > 0, "no items of rarity " .. rarity)
	end
	for _, slot in ipairs(ClothingSystem.Slots) do
		check(#ClothingSystem.BySlot[slot] >= 3, "too few items in " .. slot)
	end
	eq(#ClothingSystem.SecretIds, 6)
	for _, item in ipairs(ClothingSystem.List) do
		check(type(item.name) == "string" and type(item.desc) == "string", item.id)
		check(item.vis, item.id .. " has no vis")
		if item.slot == "Outfit" then
			check(item.vis.shirt and item.vis.pants and item.vis.shoes, item.id .. " outfit incomplete")
		end
	end
	check(ClothingSystem.get("vintage_goo_jacket").rarity == "Archive")
end)

test("crates always drop a valid item and Grails are very rare", function()
	local rng = H.server.env.Random.new(7)
	for _, crate in ipairs(ShopSystem.Crates) do
		local grails = 0
		for _ = 1, 3000 do
			local item = ShopSystem.roll(crate, rng)
			check(item and item.drop, "bad roll from " .. crate.id)
			check(crate.odds[item.rarity], crate.id .. " dropped a rarity that is not in its odds")
			if item.rarity == "Grail" then
				grails += 1
			end
		end
		check(grails / 3000 < 0.05, crate.id .. " drops too many grails")
		local total = 0
		for _, entry in ipairs(ShopSystem.oddsList(crate)) do
			total += entry.percent
		end
		check(math.abs(total - 100) < 0.01, "odds must sum to 100%")
	end
	check(ShopSystem.roll(ShopSystem.EventBox, rng))
	check(ShopSystem.roll(ShopSystem.DailyBox, rng))
end)

test("reconcile repairs corrupt save data", function()
	local garbage = {
		false, "a string", 42, {}, { coins = -50 }, { coins = 0 / 0 }, { coins = math.huge },
		{ ageXP = "lots" }, { inventory = { fake_item = true, goo_tee = "yes" } },
		{ equipped = { Shirt = "goo_tee", Hat = 5, Pants = "plain_tee" } },
		{ furniture = { owned = { couch = -3, nope = 2 }, placed = { { id = "couch", x = 1, z = 1, r = 0 }, "junk" } } },
		{ meters = { hunger = 999, clean = "x" }, stats = { feeds = -1 }, daily = "no", title = 3, settings = { music = "loud" } },
		{ outfits = { ["1"] = { Shirt = "missing" }, x = 4, ["99"] = {} }, gifts = { owned = { gift_x = true }, equipped = { Head = "gift_crown" } } },
	}
	for index, raw in ipairs(garbage) do
		local data = DataManager.reconcile(raw)
		check(data.coins >= 0 and data.coins == data.coins and data.coins < math.huge, "coins not repaired #" .. index)
		check(data.inventory.plain_tee and data.inventory.hair_baby, "starter kit missing #" .. index)
		for slot, id in pairs(data.equipped) do
			check(data.inventory[id] and ClothingSystem.get(id).slot == slot, "bad equip survived #" .. index)
		end
		for id in pairs(data.inventory) do
			check(ClothingSystem.get(id), "unknown item survived #" .. index)
		end
		eq(#data.furniture.placed, 0, "unowned furniture stayed placed #" .. index)
		eq(data.age, AgeSystem.ageFromXP(data.ageXP))
		H.validateStorable(data, "reconciled#" .. index)
	end
	-- A healthy profile survives unchanged (idempotent).
	local good = DataManager.new()
	good.coins = 777
	good.ageXP = AgeSystem.totalXPForAge(13) + 5
	good.inventory.goo_tee = true
	good.equipped.Shirt = "goo_tee"
	good.furniture.owned.couch = 2
	good.furniture.placed = { { id = "couch", x = -1, z = 0, r = 1 } }
	local once = DataManager.reconcile(good)
	local twice = DataManager.reconcile(once)
	eq(once.coins, 777)
	eq(once.age, 13)
	eq(once.equipped.Shirt, "goo_tee")
	eq(#once.furniture.placed, 1)
	eq(twice.ageXP, once.ageXP)
	eq(count(twice.inventory), count(once.inventory))
end)

test("room stations never overlap each other or the doorway", function()
	for _, stage in ipairs(AgeSystem.Stages) do
		local size = AgeSystem.houseSize(stage.age)
		local h = size / 2
		local stations = HouseSystem.stations(size)
		local names = {}
		for name, station in pairs(stations) do
			table.insert(names, name)
			local r = station.rect
			check(r.minX >= -h and r.maxX <= h and r.minZ >= -h and r.maxZ <= h, name .. " is outside a " .. size .. " room")
			check(HouseSystem.isInside(size, station.stand), name .. " stand point is outside the room")
		end
		eq(#names, 10)
		for i = 1, #names do
			for j = i + 1, #names do
				check(not HouseSystem.rectsOverlap(stations[names[i]].rect, stations[names[j]].rect), names[i] .. " overlaps " .. names[j] .. " at size " .. size)
			end
		end
		local door = HouseSystem.blockedRects(size)
		eq(#door, 11)
		for _, name in ipairs(names) do
			check(not HouseSystem.rectsOverlap(stations[name].rect, door[#door]), name .. " blocks the door at size " .. size)
		end
	end
end)

test("furniture placement rules", function()
	local placed = {}
	check(FurnitureSystem.canPlace(placed, "rug_goo", -2, -2, 0, 24))
	table.insert(placed, { id = "rug_goo", x = -2, z = -2, r = 0 })
	check(not FurnitureSystem.canPlace(placed, "rug_goo", -1, -1, 0, 24), "rugs must not overlap rugs")
	check(FurnitureSystem.canPlace(placed, "plant", -1, -1, 0, 24), "furniture may sit on a rug")
	table.insert(placed, { id = "plant", x = -1, z = -1, r = 0 })
	check(not FurnitureSystem.canPlace(placed, "lamp", -1, -1, 0, 24), "furniture must not overlap furniture")
	check(not FurnitureSystem.canPlace(placed, "couch", 100, 0, 0, 24), "outside the room")
	check(not FurnitureSystem.canPlace(placed, "couch", -6, -6, 0, 24), "on top of the bed")
	check(not FurnitureSystem.canPlace(placed, "plant", 0, 5, 0, 24), "in the doorway")
	check(not FurnitureSystem.canPlace(placed, "plant", 0.5, 0, 0, 24), "fractional cells")
	check(not FurnitureSystem.canPlace(placed, "plant", 0, 0, 7, 24), "bad rotation")
	check(not FurnitureSystem.canPlace(placed, "nope", 0, 0, 0, 24), "unknown id")
	check(not FurnitureSystem.canPlace(placed, "plant", 0 / 0, 0, 0, 24), "NaN")
	check(FurnitureSystem.canPlace(placed, "lamp", -1, -1, 0, 24, 2), "ignoreIndex")
	-- rotation swaps the footprint
	local w, d = FurnitureSystem.footprint(FurnitureSystem.get("couch"), 1)
	eq(w, 4)
	eq(d, 6)
	local x, z = FurnitureSystem.snap("couch", 0, 0, 0)
	local r = FurnitureSystem.rectOf({ id = "couch", x = x, z = z, r = 0 })
	check(math.abs((r.minX + r.maxX) / 2) <= 1 and math.abs((r.minZ + r.maxZ) / 2) <= 1, "snap keeps the piece near the pointer")
	for _, def in ipairs(FurnitureSystem.List) do
		check(def.w % Config.GridSize == 0 and def.d % Config.GridSize == 0, def.id .. " footprint must fit the grid")
	end
end)

test("fashion judging, daily tasks and collections", function()
	local rng = H.server.env.Random.new(3)
	for _, category in ipairs(FashionSystem.Categories) do
		check(FashionSystem.judgeScore(category.id, {}, rng) > 0)
		check(FashionSystem.judgeScore(category.id, { Shirt = "grail_tee", Shoes = "sample_pair", Outfit = "the_grail_fit" }, rng) > 0)
		check(FashionSystem.TitleColors[category.title], "no colour for title " .. category.title)
	end
	local archive = FashionSystem.judgeScore("Archive", { Jacket = "vintage_goo_jacket", Shoes = "split_toe_boots" }, H.server.env.Random.new(1))
	local basic = FashionSystem.judgeScore("Archive", { Shirt = "plain_tee", Pants = "basic_jeans" }, H.server.env.Random.new(1))
	check(archive > basic * 3, "archive pieces must dominate the Most Archive category")
	local a = DailySystem.pickTasks(123, 20000, 10)
	local b = DailySystem.pickTasks(123, 20000, 10)
	eq(#a, 3)
	for i = 1, 3 do
		eq(a[i].id, b[i].id)
		check(DailySystem.TaskById[a[i].id])
	end
	check(a[1].id ~= a[2].id and a[2].id ~= a[3].id and a[1].id ~= a[3].id, "tasks must be distinct")
	for _, collection in ipairs(CollectionSystem.List) do
		check(#collection.ids > 0, collection.id .. " is empty")
	end
	eq(DailySystem.nextIndex({ streak = 0, lastClaimDay = 0 }, 100), 1)
	eq(DailySystem.nextIndex({ streak = 3, lastClaimDay = 99 }, 100), 4)
	eq(DailySystem.nextIndex({ streak = 3, lastClaimDay = 90 }, 100), 1)
	eq(DailySystem.nextIndex({ streak = 7, lastClaimDay = 99 }, 100), 1)
	for _, def in ipairs(DailySystem.Tasks) do
		check(table.find(DataManager.StatKeys, def.stat), "daily task uses unknown stat " .. def.stat)
	end
	for _, def in ipairs(AchievementSystem.List) do
		if def.kind == "stat" then
			check(table.find(DataManager.StatKeys, def.stat), "achievement uses unknown stat " .. def.stat)
		end
	end
end)

----------------------------------------------------------------------
-- 2. Builders (every recipe is executed against the real class database)
----------------------------------------------------------------------
print("\n== builders ==")
local BradyBuilder = shared("BradyBuilder")
local FurnitureBuilder = shared("FurnitureBuilder")
local GiftBuilder = shared("GiftBuilder")

local function describe(model)
	local parts, motors, emitters = 0, 0, 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
		elseif d.ClassName == "Motor6D" then
			motors += 1
		elseif d.ClassName == "ParticleEmitter" then
			emitters += 1
		end
	end
	return parts, motors, emitters
end

test("Brady builds at every age, and grows", function()
	local lastHeight = 0
	for age = 1, 25 do
		local model = BradyBuilder.build({ age = age, equipped = {}, ownerName = "T", ownerUserId = 1 })
		local parts, motors = describe(model)
		eq(motors, 6, "rig joints at age " .. age)
		check(parts >= 8, "too few parts at age " .. age)
		check(model.PrimaryPart and model.PrimaryPart.Name == "Root")
		check(model.Head:FindFirstChild("Face"), "no face")
		check(model.Head:FindFirstChild("Nameplate"), "no nameplate")
		eq(model:GetAttribute("Stage"), AgeSystem.getStage(age).id)
		local height = model:GetAttribute("Height")
		check(height >= lastHeight, "Brady shrank at age " .. age)
		lastHeight = height
		model:Destroy()
	end
	local baby = BradyBuilder.dimensions(1)
	local legend = BradyBuilder.dimensions(25)
	check(legend.height > baby.height * 2.2, "the final form must be much bigger than the baby")
	check(baby.H / baby.height > legend.H / legend.height * 1.6, "babies need a proportionally huge head")
end)

test("every clothing item builds on its own", function()
	local maxParts, maxName = 0, ""
	for _, item in ipairs(ClothingSystem.List) do
		for _, age in ipairs({ 1, 25 }) do
			local model = BradyBuilder.build({ age = age, equipped = { [item.slot] = item.id }, ownerName = "T", ownerUserId = 1 })
			local parts = describe(model)
			if parts > maxParts then
				maxParts, maxName = parts, item.id
			end
			model:Destroy()
		end
		local preview = BradyBuilder.build({ age = 16, equipped = { [item.slot] = item.id }, preview = true })
		local _, _, emitters = describe(preview)
		eq(emitters, 0, "preview models must not have particles")
		check(not preview.Head:FindFirstChild("Nameplate"), "preview has a nameplate")
		preview:Destroy()
	end
	print("        (largest single-item Brady: " .. maxParts .. " parts, " .. maxName .. ")")
end)

test("fully dressed Bradys build, with hats over every hairstyle", function()
	local rng = H.server.env.Random.new(11)
	local most = 0
	for round = 1, 150 do
		local equipped = {}
		for _, slot in ipairs(ClothingSystem.Slots) do
			if rng:NextNumber() < 0.8 then
				local list = ClothingSystem.BySlot[slot]
				equipped[slot] = list[rng:NextInteger(1, #list)].id
			end
		end
		local model = BradyBuilder.build({ age = rng:NextInteger(1, 25), equipped = equipped, ownerName = "T", ownerUserId = round, rebirths = round % 4, title = { name = "Goo Stylist" }, noShoes = round % 7 == 0, aura = round % 5 == 0 and "rainbow" or nil })
		local parts, _, emitters = describe(model)
		most = math.max(most, parts)
		check(emitters <= 5, "too many particle emitters: " .. emitters)
		model:Destroy()
	end
	for _, hair in ipairs(ClothingSystem.BySlot.Hair) do
		for _, hat in ipairs(ClothingSystem.BySlot.Hat) do
			BradyBuilder.build({ age = 20, equipped = { Hair = hair.id, Hat = hat.id } }):Destroy()
		end
	end
	check(most < 140, "a Brady should stay under 140 parts, got " .. most)
	print("        (most parts on one Brady: " .. most .. ")")
end)

test("every furniture piece and gift builds", function()
	for _, def in ipairs(FurnitureSystem.List) do
		local model = FurnitureBuilder.build(def.id)
		check(model and model.PrimaryPart and model.PrimaryPart.Name == "Base", def.id)
		check(#model:GetChildren() >= 2, def.id .. " has no recipe")
		eq(model.PrimaryPart.Size.X, def.w)
		eq(model.PrimaryPart.Size.Z, def.d)
		-- nothing may poke outside the footprint by more than half a stud
		for _, part in ipairs(model:GetChildren()) do
			if part:IsA("BasePart") and part ~= model.PrimaryPart then
				local p = part.CFrame.Position
				check(math.abs(p.X) <= def.w / 2 + 0.6 and math.abs(p.Z) <= def.d / 2 + 0.6, def.id .. "." .. part.Name .. " is outside its footprint")
			end
		end
		FurnitureBuilder.makeGhost(model)
		model:PivotTo(CFrame.new(10, 0, 10) * CFrame.Angles(0, math.rad(90), 0))
		model:Destroy()
	end
	for _, gift in ipairs(GiftSystem.List) do
		local accessory = GiftBuilder.build(gift.id)
		check(accessory and accessory:IsA("Accessory"), gift.id)
		local handle = accessory:FindFirstChild("Handle")
		check(handle and handle:FindFirstChildOfClass("Attachment"), gift.id .. " has no attachment")
		accessory:Destroy()
	end
	check(GiftBuilder.build("nope") == nil)
	check(FurnitureBuilder.build("nope") == nil)
end)

if SECTION == "builders" then
	print(string.format("\n%d passed, %d failed", results.passed, results.failed))
	process.exit(results.failed > 0 and 1 or 0)
end

----------------------------------------------------------------------
-- 3. Server boot + a player joining
----------------------------------------------------------------------
print("\n== server ==")
H.startServer()

local S = {
	Data = service("DataServer"),
	Age = service("AgeServer"),
	Brady = service("BradyServer"),
	House = service("HouseServer"),
	Currency = service("CurrencyServer"),
	Events = service("EventServer"),
	Fashion = service("FashionServer"),
	Collection = service("CollectionServer"),
	Care = service("CareServer"),
	Clothing = service("ClothingServer"),
}

local player, data

test("server boots and builds the world", function()
	check(table.find(H.prints, "[Raise Brady Goo] server ready"), "Main did not finish")
	local map = H.Workspace:FindFirstChild("Map")
	check(map, "no Map folder")
	local parts = 0
	for _, d in ipairs(map:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	check(parts > 400, "map looks empty: " .. parts .. " parts")
	print("        (map: " .. parts .. " parts)")
	for _, name in ipairs({ "Store", "Runway", "Arcade", "Obby", "FoodCourt", "GooCave" }) do
		check(map:FindFirstChild(name), "map area missing: " .. name)
	end
	eq(#H.Workspace.Collectibles:GetChildren(), 25, "24 hidden blobs + the Mystery Jacket")
	local remotes = RS:FindFirstChild("Remotes")
	local Remotes = shared("Remotes")
	eq(#remotes:GetChildren(), #Remotes.Events + #Remotes.Functions)
	check(#H.closeCallbacks == 1, "BindToClose not registered")
end)

test("a new player gets data, a house, a Brady and a leaderboard", function()
	player = H.addPlayer("Tester", { ["local"] = true })
	H.advance(2)
	data = S.Data.get(player)
	check(data, "data did not load")
	eq(data.age, 1)
	eq(data.coins, Config.StartCoins)
	check(S.Data.session(player).isNew, "should be flagged as a new player")
	local plot = S.House.get(player)
	check(plot and plot.model and plot.info, "no house")
	eq(plot.info.size, 24)
	local rec = S.Brady.get(player)
	check(rec and rec.model and rec.model.Parent == H.Workspace.Bradys, "no Brady")
	check(rec.model:HasTag("BradyGoo"))
	eq(rec.model:GetAttribute("OwnerUserId"), player.UserId)
	check(S.House.isInside(player, S.Brady.position(rec)), "Brady did not spawn inside his house")
	check(player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Goo Coins"), "no leaderstats")
	local got = H.invoke(player, "GetData")
	check(got and got.data and got.data.coins == data.coins and got.session, "GetData failed")
	-- the player was sent to their doorstep
	local hrp = player.Character.HumanoidRootPart
	check((hrp.CFrame.Position - S.House.doorstep(player).Position).Magnitude < 8, "player was not moved to the doorstep")
	eq(#data.daily.tasks, 3)
end)

local function give(coins)
	run(S.Currency.add, player, coins, "test")
end

local function setMeters(hunger, clean, energy, fun)
	data.meters.hunger, data.meters.clean, data.meters.energy, data.meters.fun = hunger, clean, energy, fun
end

local function settle()
	-- let any busy animation finish
	H.advance(6)
end

test("feeding: uses food, fills hunger, gives XP + coins, refuses when full", function()
	setMeters(20, 70, 90, 60)
	local xp, coins, fruit = data.ageXP, data.coins, data.food.fruit
	H.fire(player, "Care", "Feed", "fruit")
	check(data.meters.hunger > 40, "hunger did not rise")
	eq(data.food.fruit, fruit - 1)
	check(data.ageXP > xp, "no XP")
	check(data.coins > coins, "no coins")
	eq(data.stats.feeds, 1)
	eq(S.Brady.get(player).model:GetAttribute("State"), "Eat")
	-- busy: a second feed during the animation is refused
	local before = data.meters.hunger
	H.fire(player, "Care", "Feed", "cereal")
	eq(data.meters.hunger, before, "fed while busy")
	settle()
	eq(S.Brady.get(player).model:GetAttribute("State") == "Eat", false)
	-- free cereal never runs out
	H.fire(player, "Care", "Feed", "cereal")
	check(data.meters.hunger > before)
	settle()
	-- food you do not own
	data.food.burger = 0
	before = data.meters.hunger
	H.fire(player, "Care", "Feed", "burger")
	eq(data.meters.hunger, before, "ate a burger he does not own")
	-- full
	setMeters(100, 70, 90, 60)
	local xpBefore = data.ageXP
	H.fire(player, "Care", "Feed", "cereal")
	eq(data.ageXP, xpBefore, "XP for feeding a full Brady")
	-- garbage arguments are ignored
	for _, bad in ipairs({ 5, true, {}, "nope", "" }) do
		H.fire(player, "Care", "Feed", bad)
	end
	H.fire(player, "Care", nil, nil)
	H.fire(player, "Care", {}, {})
	settle()
end)

test("cleaning: shower, brush, shoes, with cooldowns", function()
	setMeters(60, 10, 90, 60)
	local xp = data.ageXP
	H.fire(player, "Care", "Shower")
	check(data.meters.clean >= 70, "shower did not clean him")
	check(data.ageXP > xp)
	H.advance(8)
	check(S.House.get(player).info.showerEmitter.Enabled == false, "shower left running")
	setMeters(60, 40, 90, 60)
	H.fire(player, "Care", "BrushHair")
	local afterBrush = data.meters.clean
	check(afterBrush > 40)
	settle()
	H.fire(player, "Care", "BrushHair") -- cooldown
	check(data.meters.clean <= afterBrush, "brushed again during the cooldown")
	H.fire(player, "Care", "CleanShoes") -- no shoes on
	check(data.meters.clean <= afterBrush, "cleaned shoes he is not wearing")
	setMeters(60, 100, 90, 60)
	xp = data.ageXP
	H.fire(player, "Care", "Shower")
	eq(data.ageXP, xp, "XP for showering a clean Brady")
	check(data.stats.cleans >= 2)
	settle()
end)

test("sleeping restores energy over time and wakes him when rested", function()
	setMeters(80, 80, 10, 60)
	local xp = data.ageXP
	H.fire(player, "Care", "Sleep")
	check(S.Data.session(player).sleeping, "did not fall asleep")
	H.advance(6)
	local rec = S.Brady.get(player)
	eq(rec.model:GetAttribute("State"), "Sleep")
	check((S.Brady.position(rec) - S.House.stationCFrame(player, "Bed").Position).Magnitude < 0.5, "not in bed")
	-- cannot feed or play while asleep
	local hunger = data.meters.hunger
	H.fire(player, "Care", "Feed", "cereal")
	check(data.meters.hunger <= hunger, "fed while asleep")
	check(not H.invoke(player, "MinigameStart", "catch").ok, "played while asleep")
	H.advance(20)
	check(data.meters.energy > 40, "energy did not restore: " .. data.meters.energy)
	check(data.ageXP > xp, "sleep gives a little XP")
	H.advance(60)
	check(not S.Data.session(player).sleeping, "did not wake up when rested")
	check(data.meters.energy >= 94, "energy after waking: " .. data.meters.energy)
	eq(data.stats.sleeps, 1)
	-- not tired -> refuses
	H.fire(player, "Care", "Sleep")
	check(not S.Data.session(player).sleeping)
	-- manual wake
	setMeters(80, 80, 30, 60)
	H.fire(player, "Care", "Sleep")
	H.advance(4)
	H.fire(player, "Care", "Wake")
	check(not S.Data.session(player).sleeping)
	check(S.House.isInside(player, S.Brady.position(S.Brady.get(player))))
	settle()
end)

test("meters decay slowly while online", function()
	setMeters(80, 80, 80, 80)
	H.advance(120)
	check(data.meters.hunger < 80 and data.meters.hunger > 55, "hunger decay off: " .. data.meters.hunger)
	check(data.meters.fun < 80 and data.meters.clean < 80 and data.meters.energy < 80)
	setMeters(80, 80, 80, 80)
end)

test("mini-games: tokens, score clamping, cooldown and energy", function()
	setMeters(80, 80, 100, 50)
	local coins, xp = data.coins, data.ageXP
	local started = H.invoke(player, "MinigameStart", "catch")
	check(started.ok and started.token, "could not start: " .. tostring(started.reason))
	eq(data.meters.energy, 100 - Config.MinigameEnergyCost)
	H.advance(14)
	local finished = H.invoke(player, "MinigameFinish", started.token, 1e9) -- absurd score is clamped
	check(finished.ok, tostring(finished.reason))
	local def = MinigameSystem.get("catch")
	local maxCoins = MinigameSystem.rewards(def, def.maxScore, AgeSystem.rewardMultiplier(data.age, 0))
	check(finished.coins <= maxCoins + 1, "score was not clamped")
	check(data.coins > coins and data.ageXP > xp)
	eq(data.stats.minigames, 1)
	eq(data.stats.perfectGames, 1)
	-- the same token cannot be cashed in twice
	check(not H.invoke(player, "MinigameFinish", started.token, 20).ok, "token reuse")
	check(not H.invoke(player, "MinigameFinish", "made-up-token", 20).ok, "fake token")
	-- cooldown
	check(not H.invoke(player, "MinigameStart", "target").ok, "no cooldown")
	H.advance(6)
	-- finishing instantly only pays the minimum
	started = H.invoke(player, "MinigameStart", "target")
	check(started.ok, tostring(started.reason))
	finished = H.invoke(player, "MinigameFinish", started.token, 25)
	check(finished.ok and finished.ratio == 0, "instant finish must not pay a full reward")
	H.advance(6)
	-- age-locked + unknown + world games
	check(not H.invoke(player, "MinigameStart", "dance").ok, "dance should be locked at age 1")
	check(not H.invoke(player, "MinigameStart", "obby").ok, "obby is not a UI game")
	check(not H.invoke(player, "MinigameStart", "nope").ok)
	check(not H.invoke(player, "MinigameStart", { 1 }).ok)
	-- too tired
	setMeters(80, 80, 3, 50)
	check(not H.invoke(player, "MinigameStart", "catch").ok, "played with no energy")
	-- NaN score
	setMeters(80, 80, 100, 50)
	started = H.invoke(player, "MinigameStart", "reaction")
	H.advance(8)
	finished = H.invoke(player, "MinigameFinish", started.token, 0 / 0)
	check(finished.ok and finished.coins == finished.coins, "NaN score broke the payout")
	settle()
end)

test("wardrobe: equip rules are enforced on the server", function()
	eq(data.equipped.Shirt, nil)
	H.fire(player, "Equip", "plain_tee")
	eq(data.equipped.Shirt, "plain_tee")
	H.fire(player, "Equip", "basic_jeans")
	eq(data.equipped.Pants, "basic_jeans")
	H.fire(player, "Equip", "goo_tee") -- not owned
	eq(data.equipped.Shirt, "plain_tee")
	data.inventory.simple_sneakers = true -- owned, but shoes are locked until age 3
	H.fire(player, "Equip", "simple_sneakers")
	eq(data.equipped.Shoes, nil, "equipped a locked category")
	data.inventory.simple_sneakers = nil
	data.inventory.archive_knit = true -- owned, but needs age 18
	H.fire(player, "Equip", "archive_knit")
	eq(data.equipped.Shirt, "plain_tee", "equipped an item above his age")
	data.inventory.archive_knit = nil
	for _, bad in ipairs({ 5, {}, true, "", "nope" }) do
		H.fire(player, "Equip", bad)
		H.fire(player, "Unequip", bad)
	end
	-- the model was rebuilt with the shirt colour
	local rec = S.Brady.get(player)
	check(rec.model.Torso.Color == ClothingSystem.get("plain_tee").vis.color, "shirt not visible on the model")
	-- outfits
	H.fire(player, "SaveOutfit", 1)
	check(data.outfits["1"] and data.outfits["1"].Shirt == "plain_tee")
	H.fire(player, "Unequip", "Shirt")
	eq(data.equipped.Shirt, nil)
	check(rec ~= nil and S.Brady.get(player).model:GetAttribute("Embarrassed") == true, "no-shirt Brady should be embarrassed")
	H.fire(player, "LoadOutfit", 1)
	eq(data.equipped.Shirt, "plain_tee")
	H.fire(player, "SaveOutfit", 4) -- slot 4 needs the gamepass
	eq(data.outfits["4"], nil)
	H.fire(player, "SaveOutfit", 1.5)
	H.fire(player, "SaveOutfit", "1")
	H.fire(player, "LoadOutfit", 3) -- empty
	eq(data.equipped.Shirt, "plain_tee")
	settle()
end)

test("shop: prices come from the server and coins are spent first", function()
	data.coins = 30
	local result = H.invoke(player, "Buy", "clothing", "goo_tee")
	check(not result.ok, "bought with too few coins")
	eq(data.inventory.goo_tee, nil)
	data.coins = 500
	result = H.invoke(player, "Buy", "clothing", "goo_tee")
	check(result.ok, tostring(result.reason))
	eq(data.coins, 440)
	check(data.inventory.goo_tee)
	check(not H.invoke(player, "Buy", "clothing", "goo_tee").ok, "bought it twice")
	check(not H.invoke(player, "Buy", "clothing", "silk_shirt").ok, "bought a crate-only item")
	check(not H.invoke(player, "Buy", "clothing", "flame_tee").ok, "bought above his age")
	check(not H.invoke(player, "Buy", "clothing", "mystery_jacket").ok, "bought a secret item")
	-- food
	local pizza = data.food.pizza or 0
	check(H.invoke(player, "Buy", "food", "pizza", 2).ok)
	eq(data.food.pizza, pizza + 2)
	eq(data.coins, 440 - 90)
	for _, quantity in ipairs({ 0, -5, 1.5, 9999, 0 / 0, "2" }) do
		check(not H.invoke(player, "Buy", "food", "pizza", quantity).ok, "bad quantity accepted: " .. tostring(quantity))
	end
	check(not H.invoke(player, "Buy", "food", "cereal", 1).ok, "free food is not sold")
	check(not H.invoke(player, "Buy", "food", "sushi", 1).ok, "age-locked food")
	-- furniture
	check(H.invoke(player, "Buy", "furniture", "plant").ok)
	eq(data.furniture.owned.plant, 1)
	check(not H.invoke(player, "Buy", "furniture", "vip_rope").ok, "VIP item without the pass")
	check(not H.invoke(player, "Buy", "furniture", "trophy_lamp").ok, "daily-exclusive item was sold")
	check(not H.invoke(player, "Buy", "furniture", "throne").ok, "age-locked furniture")
	check(not H.invoke(player, "Buy", "nonsense", "x").ok)
	check(not H.invoke(player, "Buy", nil, nil).ok)
	check(not H.invoke(player, "Buy", {}, {}).ok)
	-- crates
	data.coins = 100
	check(not H.invoke(player, "OpenCrate", "thrift_bin").ok, "opened a crate without coins")
	check(not H.invoke(player, "OpenCrate", "grail_vault").ok)
	data.coins = 1000
	local owned = count(data.inventory)
	local opened = H.invoke(player, "OpenCrate", "thrift_bin")
	check(opened.ok and ClothingSystem.get(opened.itemId), "crate gave nothing")
	check(data.coins <= 750 + 400, "crate was free")
	check(count(data.inventory) == owned + (opened.isNew and 1 or 0))
	eq(data.stats.crates, 1)
	check(not H.invoke(player, "OpenCrate", "archive_vault").ok, "age-locked crate")
	settle()
end)

test("furniture: grid placement is validated and saved", function()
	local placed = data.furniture.placed
	eq(#placed, 0)
	H.fire(player, "PlaceFurniture", "rug_goo", -2, -2, 0)
	eq(#placed, 1)
	H.fire(player, "PlaceFurniture", "rug_goo", 2, 2, 0) -- only owns one
	eq(#placed, 1)
	H.fire(player, "PlaceFurniture", "plant", -1, -1, 0)
	eq(#placed, 2)
	H.fire(player, "PlaceFurniture", "couch", 0, 0, 0) -- not owned
	eq(#placed, 2)
	for _, bad in ipairs({ { "plant", 0 / 0, 0, 0 }, { "plant", 0, 0, 9 }, { 5, 0, 0, 0 }, { "plant", "a", "b", "c" }, { "plant", 1e9, 0, 0 } }) do
		H.fire(player, "PlaceFurniture", bad[1], bad[2], bad[3], bad[4])
	end
	eq(#placed, 2)
	local folder = S.House.get(player).info.furniture
	eq(#folder:GetChildren(), 2)
	-- the model sits where the placement says
	local plant = folder:FindFirstChild("plant")
	local expected = S.House.origin(player) * FurnitureSystem.localCFrame(placed[2])
	check((plant.PrimaryPart.CFrame.Position - expected.Position).Magnitude < 0.2, "furniture model in the wrong place")
	H.fire(player, "RemoveFurniture", 1)
	eq(#data.furniture.placed, 1)
	eq(data.furniture.placed[1].id, "plant")
	eq(#S.House.get(player).info.furniture:GetChildren(), 1)
	for _, bad in ipairs({ 0, -1, 99, 1.5, "1", {} }) do
		H.fire(player, "RemoveFurniture", bad)
	end
	eq(#data.furniture.placed, 1)
	eq(data.stats.placed, 2)
end)

test("ageing up: every stage hands out its rewards and grows the house", function()
	local ups = H.sentCount(player, "AgeUp")
	local startAge = data.age
	local lastSize = S.House.size(player)
	for _, stage in ipairs(AgeSystem.Stages) do
		if stage.age > data.age then
			local need = AgeSystem.totalXPForAge(stage.age) - data.ageXP
			run(S.Age.addXP, player, need, { raw = true })
			eq(data.age, stage.age)
			for _, id in ipairs(stage.rewards.items) do
				check(data.inventory[id], "stage item not granted: " .. id)
			end
			check((data.furniture.owned[stage.rewards.furniture] or 0) >= 1, "stage furniture not granted")
			check(data.gifts.owned[stage.rewards.gift], "player gift not granted: " .. tostring(stage.rewards.gift))
			check(data.stageRewards[tostring(stage.index)])
			eq(data.equipped.Hair, stage.look.hair, "hair should follow the stage")
			local size = S.House.size(player)
			check(size > lastSize, "house did not grow at age " .. stage.age)
			lastSize = size
			local rec = S.Brady.get(player)
			eq(rec.model:GetAttribute("Stage"), stage.id)
			eq(rec.model:GetAttribute("State"), "Celebrate")
			check(S.House.isInside(player, S.Brady.position(rec)), "Brady ended up outside the bigger house")
			settle()
		end
	end
	eq(data.age, 25)
	eq(H.sentCount(player, "AgeUp") - ups, 25 - startAge, "one AgeUp message per age")
	eq(S.House.size(player), 60)
	eq(player.leaderstats.Age.Value, 25)
	check(data.inventory.vintage_goo_jacket and data.inventory.legendary_goo)
	check(data.gifts.owned.gift_crown and data.gifts.owned.gift_aura)
	-- XP past the cap does nothing
	local xp = data.ageXP
	eq(run(S.Age.addXP, player, 5000), 0)
	eq(data.ageXP, xp)
	-- stage rewards cannot be granted twice
	local last = H.lastSent(player, "AgeUp")[1]
	check(last.stageChanged and #last.lines >= 4, "AgeUp payload should list the unlocks")
	check(data.achievements.age_25, "age achievement")
end)

test("everything in the shop can be bought and worn at age 25", function()
	data.coins = 5e6
	local bought = 0
	for _, item in ipairs(ClothingSystem.List) do
		if item.price and not data.inventory[item.id] then
			local result = H.invoke(player, "Buy", "clothing", item.id)
			check(result.ok, item.id .. ": " .. tostring(result.reason))
			bought += 1
			H.advance(0.3)
		end
	end
	check(bought > 40, "expected lots of shop items, bought " .. bought)
	for _, def in ipairs(FurnitureSystem.List) do
		if def.price and not def.vip then
			local result = H.invoke(player, "Buy", "furniture", def.id)
			check(result.ok, def.id .. ": " .. tostring(result.reason))
			H.advance(0.3)
		end
	end
	for _, food in ipairs(FoodSystem.List) do
		if not food.free then
			check(H.invoke(player, "Buy", "food", food.id, 3).ok, food.id)
			H.advance(0.3)
		end
	end
	settle()
	-- wear every owned piece once
	for itemId in pairs(H.deepCopy(data.inventory)) do
		local item = ClothingSystem.get(itemId)
		H.fire(player, "Equip", itemId)
		eq(data.equipped[item.slot], itemId, "could not equip " .. itemId)
	end
	for _, slot in ipairs(ClothingSystem.Slots) do
		H.fire(player, "Unequip", slot)
	end
	eq(count(data.equipped), 0)
	settle()
end)

test("crates: many openings, duplicates refund coins, Archive / Grail announce", function()
	data.coins = 5e7
	local new, dupes, rarities = 0, 0, {}
	for _, crate in ipairs(ShopSystem.Crates) do
		for _ = 1, 120 do
			local coins = data.coins
			local opened = H.invoke(player, "OpenCrate", crate.id)
			check(opened.ok, crate.id .. ": " .. tostring(opened.reason))
			local item = ClothingSystem.get(opened.itemId)
			rarities[item.rarity] = (rarities[item.rarity] or 0) + 1
			if opened.isNew then
				new += 1
				eq(opened.refund, 0)
			else
				dupes += 1
				check(opened.refund > 0, "duplicate gave no refund")
				check(data.coins >= coins - crate.price + opened.refund, "refund not paid")
			end
			H.advance(0.4)
		end
	end
	check(new > 10 and dupes > 100)
	check((rarities.Archive or 0) > 0, "no Archive drops in 480 crates")
	print(string.format("        (480 crates: %d new, %d dupes; Legendary %d, Archive %d, Grail %d)", new, dupes, rarities.Legendary or 0, rarities.Archive or 0, rarities.Grail or 0))
	settle()
end)

test("full outfits, drip score and special animations", function()
	data.inventory.the_grail_fit = true
	data.inventory.platform_stompers = true
	H.fire(player, "Equip", "the_grail_fit")
	eq(data.equipped.Outfit, "the_grail_fit")
	local rec = S.Brady.get(player)
	eq(rec.model:GetAttribute("WalkStyle"), "LegendWalk")
	eq(rec.model:GetAttribute("IdleStyle"), "Legend")
	eq(rec.model:GetAttribute("State"), "GrailSpawn", "Grail pieces get a special spawn animation")
	check(rec.model.Head.Nameplate:GetAttribute("Grail"), "Grail nameplate missing")
	check(InventorySystem.dripScore(data.equipped) >= 70)
	check(InventorySystem.isPoseUnlocked(data, {}, "GrailFloat"), "Grail pose should unlock")
	settle()
	H.fire(player, "Unequip", "Outfit")
	H.fire(player, "Equip", "platform_stompers")
	rec = S.Brady.get(player)
	check(rec.model:GetAttribute("HipHeight") > BradyBuilder.dimensions(25).legH, "platform shoes should lift him")
	H.fire(player, "Unequip", "Shoes")
	settle()
end)

test("mirror + poses", function()
	H.fire(player, "Mirror", true)
	H.advance(8)
	local rec = S.Brady.get(player)
	eq(rec.model:GetAttribute("State"), "Mirror")
	check(H.lastSent(player, "OpenPanel")[1] == "Mirror")
	H.fire(player, "SetPose", "Dab")
	eq(rec.model:GetAttribute("State"), "Pose")
	eq(rec.model:GetAttribute("Pose"), "Dab")
	H.fire(player, "SetPose", "TPose") -- gamepass pose
	eq(rec.model:GetAttribute("Pose"), "Dab", "used a locked pose")
	H.fire(player, "SetPose", "NotAPose")
	H.fire(player, "SetPose", 5)
	eq(rec.model:GetAttribute("Pose"), "Dab")
	H.advance(30)
	eq(rec.model:GetAttribute("State"), "Pose", "mirror poses hold until you leave")
	H.fire(player, "Mirror", false)
	local after = rec.model:GetAttribute("State")
	check(after == "Idle" or after == "Walk", "leaving the mirror should release the pose, got " .. tostring(after))
	-- station prompts
	local prompts = S.House.get(player).info.prompts
	for _, name in ipairs({ "Bed", "Wardrobe", "Mirror", "Display", "Food", "Trophy", "Podium", "Shower", "Sink", "ShoeMat" }) do
		check(prompts[name], "missing station prompt " .. name)
	end
	H.trigger(prompts.Wardrobe, player)
	eq(H.lastSent(player, "OpenPanel")[1], "Wardrobe")
	H.trigger(prompts.Food, player)
	eq(H.lastSent(player, "OpenPanel")[1], "Feed")
	H.trigger(prompts.Podium, player)
	local posed = false
	for _ = 1, 20 do
		H.advance(0.5)
		if S.Brady.get(player).model:GetAttribute("State") == "Pose" then
			posed = true
			break
		end
	end
	check(posed, "the podium never made him pose")
	settle()
	H.fire(player, "Mirror", false)
end)

test("idle life: Brady wanders, trips, poses and talks on his own", function()
	local rec = S.Brady.get(player)
	local seen, said, moved = {}, 0, false
	local lastSeq = rec.saySeq
	local start = S.Brady.position(rec)
	for _ = 1, 400 do
		H.advance(1)
		rec = S.Brady.get(player)
		seen[rec.model:GetAttribute("State")] = true
		if rec.saySeq ~= lastSeq then
			said += 1
			lastSeq = rec.saySeq
		end
		local pos = S.Brady.position(rec)
		if (pos - start).Magnitude > 3 then
			moved = true
		end
		check(S.House.isInside(player, pos, 0.5), "Brady wandered out of his house")
	end
	check(moved, "Brady never wandered")
	check(seen.Walk, "never walked")
	check(seen.Trip, "never tripped in 400s")
	check(seen.Pose, "never posed in 400s")
	check(said >= 5, "barely spoke: " .. said)
end)

test("random events: every event can be started and completed", function()
	local events = data.stats.events
	local function begin(id)
		settle()
		check(S.Events.force(player, id), "could not start " .. id)
		local sent = H.lastSent(player, "EventUpdate")[1]
		eq(sent.id, id)
		return S.Events.current(player)
	end
	local function propPrompt(event)
		return event.props[1].Core:FindFirstChildOfClass("ProximityPrompt")
	end
	-- Hungry
	setMeters(60, 80, 80, 80)
	begin("Hungry")
	check(data.meters.hunger <= 12)
	H.fire(player, "Care", "Feed", "pizza")
	check(S.Events.current(player) == nil, "Hungry not completed by feeding")
	-- Lost shoes
	H.fire(player, "Equip", "simple_sneakers")
	local event = begin("LostShoes")
	check(not S.Brady.get(player).model:FindFirstChild("Shoe_Upper"), "shoes should disappear")
	H.trigger(propPrompt(event), player)
	check(S.Events.current(player) == nil)
	check(S.Brady.get(player).model:FindFirstChild("Shoe_Upper"), "shoes should come back")
	-- Found a grail (mystery box)
	local owned = count(data.inventory)
	local coins = data.coins
	event = begin("FoundGrail")
	H.trigger(propPrompt(event), player)
	check(S.Events.current(player) == nil)
	check(count(data.inventory) > owned or data.coins > coins, "mystery box gave nothing")
	-- Insane fit (hype)
	event = begin("InsaneFit")
	for _ = 1, 15 do
		H.fire(player, "EventAction", "Hype")
	end
	check(S.Events.current(player) == nil, "hype not completed")
	-- Fashion crisis
	begin("FashionCrisis")
	H.fire(player, "Equip", "goo_tee")
	check(S.Events.current(player) ~= nil)
	H.fire(player, "Equip", "plain_tee")
	check(S.Events.current(player) == nil, "fashion crisis not completed")
	-- Haircut: keep
	event = begin("NewHaircut")
	check(S.Brady.get(player).hairOverride == event.hair)
	H.fire(player, "EventAction", "Keep")
	check(S.Events.current(player) == nil)
	check(S.Brady.get(player).hairOverride == nil)
	-- Haircut: fix (brush)
	event = begin("NewHaircut")
	H.fire(player, "EventAction", "Fix")
	check(S.Events.current(player) ~= nil and S.Events.current(player).choice == "fix")
	H.advance(16)
	H.fire(player, "Care", "BrushHair")
	check(S.Events.current(player) == nil, "brushing did not fix the haircut")
	-- Go outside
	begin("GoOutside")
	check(S.Data.session(player).following, "Brady should start following")
	H.movePlayer(player, Vector3.new(108, 3, -108))
	H.advance(3)
	check(S.Events.current(player) == nil, "reaching the park did not complete the event")
	eq(data.stats.events, events + 8)
	-- a missed event cleans up after itself
	H.fire(player, "Care", "Follow", false)
	event = begin("LostShoes")
	local prop = event.props[1]
	H.advance(EventSystem.get("LostShoes").duration + 2)
	check(S.Events.current(player) == nil, "event did not time out")
	check(prop.Parent == nil, "prop left behind")
	check(S.Brady.get(player).noShoes == false)
	eq(data.stats.events, events + 8)
	H.fire(player, "EventAction", "Hype") -- no active event: ignored
	H.fire(player, "EventAction", {})
	settle()
end)

test("events start by themselves every few minutes", function()
	data.tutorialDone = true -- events wait until the tutorial is finished
	local before = H.sentCount(player, "EventUpdate")
	H.advance(Config.EventDelay[2] + 40)
	check(H.sentCount(player, "EventUpdate") > before, "no automatic event")
	H.advance(200)
end)

test("follow mode: Brady follows the player around the map", function()
	H.movePlayer(player, S.House.doorstep(player).Position + Vector3.new(0, 3, 0))
	H.fire(player, "Care", "Follow", true)
	check(S.Data.session(player).following)
	local rec = S.Brady.get(player)
	H.advance(4)
	local hrp = player.Character.HumanoidRootPart
	check((S.Brady.position(rec) - hrp.CFrame.Position).Magnitude < 12, "Brady did not come to the player")
	-- far away: he teleports to catch up
	H.movePlayer(player, Vector3.new(0, 3, 0))
	H.advance(2)
	check((S.Brady.position(rec) - Vector3.new(0, 0, 0)).Magnitude < 14, "Brady did not catch up")
	check(math.abs(S.Brady.position(rec).Y) < 0.5, "Brady should stand on the ground, y=" .. S.Brady.position(rec).Y)
	check(not S.Brady.isHome(player))
	-- needs to be home for a shower / bed
	setMeters(80, 10, 10, 80)
	local clean = data.meters.clean
	H.fire(player, "Care", "Shower")
	eq(data.meters.clean, clean)
	H.fire(player, "Care", "Sleep")
	check(not S.Data.session(player).sleeping)
	H.fire(player, "Care", "Call")
	H.fire(player, "Care", "Follow", false)
	check(not S.Data.session(player).following)
	check(S.Brady.isHome(player), "stay-home should send him home")
	setMeters(80, 80, 80, 80)
end)

test("hidden goo blobs, secret items and collections", function()
	local blobs = {}
	for _, child in ipairs(H.Workspace.Collectibles:GetChildren()) do
		if child.Name == "HiddenGoo" then
			table.insert(blobs, child)
		end
	end
	eq(#blobs, 24)
	local coins = data.coins
	H.touch(blobs[1], player)
	check(data.coins > coins, "no coins for a hidden blob")
	eq(data.stats.hidden, 1)
	eq(H.lastSent(player, "HiddenFound")[1], blobs[1]:GetAttribute("Index"))
	coins = data.coins
	H.touch(blobs[1], player)
	eq(data.coins, coins, "same blob twice in a day")
	for i = 2, #blobs do
		H.touch(blobs[i], player)
	end
	eq(data.stats.hidden, 24)
	check(data.achievements.explorer)
	-- secret item spawn
	local secret = run(S.Collection.forceSecret)
	check(secret and secret.model.Parent, "secret did not spawn")
	local owned = data.inventory[secret.itemId]
	H.touch(secret.model.Core, player)
	check(data.inventory[secret.itemId], "secret item not granted")
	check(owned == nil)
	local n = count(data.inventory)
	H.advance(3)
	H.touch(secret.model.Core, player)
	eq(count(data.inventory), n)
	H.advance(Config.SecretLifetime + 5)
	check(secret.model.Parent == nil, "secret item never despawned")
	-- the cave jacket
	H.touch(H.Workspace.Collectibles.MysteryJacket.Core, player)
	check(data.inventory.mystery_jacket)
	check(data.achievements.secret_finder)
	-- collections
	coins = data.coins
	H.fire(player, "ClaimCollection", "grail") -- not complete
	eq(data.coins, coins)
	for _, id in ipairs(CollectionSystem.ById.shoes.ids) do
		data.inventory[id] = true
	end
	H.fire(player, "ClaimCollection", "shoes")
	eq(data.coins, coins + CollectionSystem.ById.shoes.coins)
	H.fire(player, "ClaimCollection", "shoes")
	eq(data.coins, coins + CollectionSystem.ById.shoes.coins, "collection claimed twice")
	H.fire(player, "ClaimCollection", "nope")
	H.fire(player, "ClaimCollection", {})
	settle()
end)

test("obby: start, checkpoints in order, finish", function()
	setMeters(80, 80, 100, 50)
	local obby = H.Workspace.Map.Obby
	local start, finish = obby.ObbyStart, obby.ObbyFinish
	local checkpoints = {}
	for _, child in ipairs(obby:GetChildren()) do
		if child.Name == "ObbyCheckpoint" then
			table.insert(checkpoints, child)
		end
	end
	eq(#checkpoints, 2)
	table.sort(checkpoints, function(a, b)
		return a.CFrame.Position.Y < b.CFrame.Position.Y
	end)
	local coins, games = data.coins, data.stats.minigames
	H.advance(6)
	-- finishing without starting does nothing
	H.touch(finish, player)
	eq(data.coins, coins)
	H.touch(start, player)
	check(H.lastSent(player, "ObbyState")[1].running, "obby did not start")
	-- skipping checkpoints does not count
	H.advance(15)
	H.touch(finish, player)
	eq(data.coins, coins, "finished without the checkpoints")
	H.touch(checkpoints[2], player) -- out of order
	H.touch(finish, player)
	eq(data.coins, coins)
	H.touch(checkpoints[1], player)
	H.touch(checkpoints[2], player)
	-- falling in the goo returns you to the last checkpoint
	H.touch(obby.GooPool, player)
	check((player.Character.HumanoidRootPart.CFrame.Position - checkpoints[2].CFrame.Position).Magnitude < 8, "goo should send you to your checkpoint")
	H.touch(finish, player)
	check(data.coins > coins, "obby paid nothing")
	eq(data.stats.minigames, games + 1)
	local state = H.lastSent(player, "ObbyState")[1]
	check(state.running == false and state.result and state.result.coins > 0)
	settle()
end)

test("daily rewards: one claim per day, 7-day cycle, streak resets", function()
	local coins = data.coins
	H.fire(player, "ClaimDaily")
	eq(data.daily.streak, 1)
	eq(data.coins, coins + 100)
	H.advance(1)
	H.fire(player, "ClaimDaily")
	eq(data.daily.streak, 1, "claimed twice in one day")
	eq(data.coins, coins + 100)
	local lamp = data.furniture.owned.trophy_lamp or 0
	for day = 2, 8 do
		H.advance(86400)
		eq(S.Data.session(player).day, Util.today(), "day rollover not noticed")
		H.fire(player, "ClaimDaily")
		eq(data.daily.streak, day)
		H.advance(1)
	end
	eq(data.furniture.owned.trophy_lamp, lamp + 1, "day 6 furniture")
	check(data.achievements.streak_7, "streak achievement")
	-- miss two days: streak resets to 1
	H.advance(86400 * 3)
	H.fire(player, "ClaimDaily")
	eq(data.daily.streak, 1)
	-- daily tasks refresh each day and pay once
	eq(#data.daily.tasks, 3)
	local task_ = data.daily.tasks[1]
	local def = DailySystem.TaskById[task_.id]
	coins = data.coins
	H.fire(player, "ClaimTask", 1) -- not finished
	eq(data.coins, coins)
	task_.progress = def.goal
	H.fire(player, "ClaimTask", 1)
	check(data.coins > coins)
	coins = data.coins
	H.fire(player, "ClaimTask", 1)
	eq(data.coins, coins, "task claimed twice")
	for _, bad in ipairs({ 0, 9, "1", {}, 1.5 }) do
		H.fire(player, "ClaimTask", bad)
	end
	-- hidden blobs reset on a new day
	local blob = H.Workspace.Collectibles:FindFirstChild("HiddenGoo")
	coins = data.coins
	H.touch(blob, player)
	check(data.coins > coins, "hidden blobs should reset daily")
	settle()
end)

test("daily task progress is driven by real actions", function()
	data.daily.tasks = { { id = "feed", progress = 0, claimed = false }, { id = "games", progress = 0, claimed = false }, { id = "coins", progress = 0, claimed = false } }
	setMeters(10, 80, 100, 50)
	H.fire(player, "Care", "Feed", "cereal")
	eq(data.daily.tasks[1].progress, 1)
	check(data.daily.tasks[3].progress > 0, "coin task should advance")
	settle()
end)

test("fashion show: sign-up, runway, voting, results, title", function()
	local wins, joined = data.stats.showsWon, data.stats.showsJoined
	H.fire(player, "Equip", "the_grail_fit")
	settle()
	-- wait for sign-ups to open
	local guard = 0
	while S.Fashion.phase() ~= "Signup" and guard < 400 do
		H.advance(1)
		guard += 1
	end
	eq(S.Fashion.phase(), "Signup")
	local state = H.lastSent(player, "FashionState")[1]
	check(state.category and state.category.name, "no category announced")
	H.fire(player, "Fashion", "Join")
	local rec = S.Brady.get(player)
	check(rec.inShow, "Brady did not enter")
	eq(data.stats.showsJoined, joined + 1)
	H.fire(player, "Fashion", "Join") -- twice
	eq(data.stats.showsJoined, joined + 1)
	check((player.Character.HumanoidRootPart.CFrame.Position - Vector3.new(118, 4, 26)).Magnitude < 10, "player not taken to the audience")
	-- no care actions while he is in the show
	local hunger = data.meters.hunger
	data.meters.hunger = 20
	H.fire(player, "Care", "Feed", "cereal")
	eq(data.meters.hunger, 20)
	data.meters.hunger = hunger
	guard = 0
	local sawRunway, onRunway = false, false
	while S.Fashion.phase() ~= "Voting" and guard < 600 do
		H.advance(0.5)
		guard += 1
		if S.Fashion.phase() == "Runway" then
			sawRunway = true
			local pos = S.Brady.position(rec)
			if pos.X < 150 and pos.X > 100 and math.abs(pos.Z) < 2 then
				onRunway = true
			end
		end
	end
	check(sawRunway and onRunway, "Brady never walked the runway")
	eq(S.Fashion.phase(), "Voting")
	state = H.lastSent(player, "FashionState")[1]
	check(#state.contestants >= 3, "bots should fill the show")
	local mine, bot
	for _, c in ipairs(state.contestants) do
		if c.userId == player.UserId then
			mine = c
		elseif c.isBot then
			bot = c
		end
	end
	check(mine and bot)
	H.fire(player, "Fashion", "Vote", mine.id) -- cannot vote for yourself
	H.fire(player, "Fashion", "Vote", "nope")
	H.fire(player, "Fashion", "Vote", bot.id)
	guard = 0
	while S.Fashion.phase() ~= "Results" and guard < 200 do
		H.advance(0.5)
		guard += 1
	end
	state = H.lastSent(player, "FashionState")[1]
	check(state.results and #state.results >= 3, "no results")
	eq(state.results[1].place, 1)
	local botVotes = 0
	for _, r in ipairs(state.results) do
		if r.id == bot.id then
			botVotes = r.votes
		end
		if r.id == mine.id then
			eq(r.votes, 0, "self vote counted")
		end
	end
	eq(botVotes, 1)
	H.advance(Config.FashionResults + 3)
	eq(S.Fashion.phase(), "Idle")
	check(not rec.inShow and S.Brady.isHome(player), "Brady was not sent home")
	eq(#H.Workspace.Bradys:GetChildren(), 1, "bot Bradys were not cleaned up")
	if state.results[1].id == mine.id then
		eq(data.stats.showsWon, wins + 1)
		check(data.title.name ~= "" and data.title.expires > 0, "winner got no title")
		check(S.Brady.get(player).model.Head.Nameplate:FindFirstChild("Title"), "title missing from the nameplate")
	end
	print("        (winner: " .. state.results[1].name .. ", my place: " .. (function()
		for _, r in ipairs(state.results) do
			if r.id == mine.id then
				return r.place
			end
		end
	end)() .. ")")
	settle()
end)

test("a fashion show with nobody entered is skipped cleanly", function()
	local guard = 0
	while S.Fashion.phase() ~= "Signup" and guard < 400 do
		H.advance(1)
		guard += 1
	end
	H.advance(Config.FashionSignup + 5)
	eq(S.Fashion.phase(), "Idle")
	eq(#H.Workspace.Bradys:GetChildren(), 1)
end)

local other

test("multiplayer: a second player, profiles, visiting, hype, no stealing", function()
	other = H.addPlayer("Friend")
	H.advance(2)
	local otherData = S.Data.get(other)
	check(otherData, "second player has no data")
	check(S.House.get(other).index ~= S.House.get(player).index, "both players got the same plot")
	eq(#H.Workspace.Bradys:GetChildren(), 2)
	-- inspect
	local profile = H.invoke(other, "GetProfile", player.UserId)
	check(profile.ok and profile.age == 25 and profile.name == "Tester")
	check(profile.equipped.Outfit == data.equipped.Outfit)
	check(profile.collection >= 0 and profile.items > 50)
	check(profile.coins == nil, "profiles must not leak coins")
	check(not H.invoke(other, "GetProfile", 987654).ok)
	check(not H.invoke(other, "GetProfile", "x").ok)
	-- visit
	H.fire(other, "Visit", player.UserId)
	check((other.Character.HumanoidRootPart.CFrame.Position - S.House.doorstep(player).Position).Magnitude < 8, "visit did not teleport")
	for _, place in ipairs({ "Plaza", "Runway", "Shop", "Arcade", "Park", "Food", "Home" }) do
		H.advance(1)
		H.fire(other, "Visit", place)
	end
	check((other.Character.HumanoidRootPart.CFrame.Position - S.House.doorstep(other).Position).Magnitude < 8)
	H.fire(other, "Visit", {})
	H.fire(other, "Visit", 13371337)
	-- hype
	local hypes = data.stats.hypes
	H.fire(other, "Hype", player.UserId)
	eq(data.stats.hypes, hypes + 1)
	H.advance(2)
	H.fire(other, "Hype", player.UserId) -- cooldown
	eq(data.stats.hypes, hypes + 1)
	H.fire(other, "Hype", other.UserId) -- yourself
	eq(otherData.stats.hypes, 0)
	-- a visitor cannot use the owner's stations, furniture or data
	local prompts = S.House.get(player).info.prompts
	local sleeping = S.Data.session(player).sleeping
	H.trigger(prompts.Bed, other)
	eq(S.Data.session(player).sleeping, sleeping, "a visitor put Brady to bed")
	local placed = #data.furniture.placed
	H.fire(other, "RemoveFurniture", 1) -- acts on the visitor's own (empty) room
	eq(#data.furniture.placed, placed)
	local coins, items = data.coins, count(data.inventory)
	H.fire(other, "Equip", "the_grail_fit")
	eq(otherData.equipped.Outfit, nil, "equipped someone else's item")
	eq(data.coins, coins)
	eq(count(data.inventory), items)
	-- visitor display prompt opens the inspect panel
	H.trigger(prompts.Display, other)
	eq(H.lastSent(other, "OpenPanel")[1], "Inspect")
	eq(H.lastSent(other, "OpenPanel")[2], player.UserId)
	settle()
end)

test("gifts for the player's avatar + titles over the head", function()
	check(data.gifts.owned.gift_bucket)
	H.fire(player, "EquipGift", "gift_crown")
	eq(data.gifts.equipped.Head, "gift_crown")
	check(player.Character:FindFirstChild("BradyGift_Head"), "accessory not on the character")
	H.fire(player, "EquipGift", "gift_bucket") -- same slot replaces
	eq(data.gifts.equipped.Head, "gift_bucket")
	local n = 0
	for _, child in ipairs(player.Character:GetChildren()) do
		if child:IsA("Accessory") then
			n += 1
		end
	end
	eq(n, 1)
	H.fire(player, "EquipGift", "gift_aura")
	H.fire(player, "EquipGift", "gift_cape")
	eq(count(data.gifts.equipped), 3)
	H.fire(other, "EquipGift", "gift_crown") -- not owned
	eq(count(S.Data.get(other).gifts.equipped), 0)
	H.fire(player, "UnequipGift", "Head")
	eq(data.gifts.equipped.Head, nil)
	check(not player.Character:FindFirstChild("BradyGift_Head"))
	for _, bad in ipairs({ 5, {}, "nope" }) do
		H.fire(player, "EquipGift", bad)
		H.fire(player, "UnequipGift", bad)
	end
end)

test("settings, tutorial bonus and photo stat", function()
	H.fire(player, "Setting", "music", false)
	eq(data.settings.music, false)
	H.fire(player, "Setting", "music", "loud")
	eq(data.settings.music, false)
	H.fire(player, "Setting", "coins", 999999)
	eq(data.settings.coins, nil)
	H.fire(player, "Setting", "aura", "rainbow") -- needs the pass
	eq(data.settings.aura, "none")
	local coins = data.coins
	data.tutorialDone = false
	H.fire(player, "Tutorial", "Done")
	check(data.tutorialDone)
	check(data.coins > coins)
	coins = data.coins
	H.fire(player, "Tutorial", "Done")
	eq(data.coins, coins, "tutorial bonus paid twice")
	H.fire(player, "Tutorial", "Photo")
	H.fire(player, "Tutorial", "Photo")
	eq(data.stats.photos, 1)
end)

test("remote spam is rate limited", function()
	setMeters(10, 80, 80, 80)
	local remote = RS.Remotes.EventAction
	local handled = H.sentCount(player, "Notify")
	S.Events.force(player, "InsaneFit")
	local event = S.Events.current(player)
	for _ = 1, 400 do
		H.signalOf(remote, "OnServerEvent"):Fire(player, "Hype")
	end
	H.flush()
	check(event.progress <= 21, "rate limit let " .. event.progress .. " calls through in one burst")
	H.advance(30)
	check(handled ~= nil)
	settle()
end)

test("rebirth resets the age but keeps the wardrobe", function()
	local items = count(data.inventory)
	local coins = data.coins
	H.fire(other, "Rebirth") -- not max age
	eq(S.Data.get(other).rebirths, 0)
	H.fire(player, "Equip", "archive_trench")
	H.fire(player, "Rebirth")
	eq(data.rebirths, 1)
	eq(data.age, 1)
	eq(data.ageXP, 0)
	eq(count(data.inventory), items, "rebirth must keep items")
	check(data.coins >= coins)
	eq(data.equipped.Jacket, nil, "baby Brady cannot wear an age-21 trench")
	eq(S.House.size(player), 24)
	eq(S.Brady.get(player).model:GetAttribute("Stage"), "Baby")
	check(AgeSystem.rewardMultiplier(1, data.rebirths) > AgeSystem.rewardMultiplier(1, 0))
	check(data.achievements.reborn)
	-- ageing again gives coins but not duplicate stage items
	local giftCount = count(data.gifts.owned)
	local blocks = data.furniture.owned.toy_blocks
	run(S.Age.addXP, player, AgeSystem.totalXPForAge(3), { raw = true })
	eq(data.age, 3)
	eq(count(data.gifts.owned), giftCount)
	eq(data.furniture.owned.toy_blocks, blocks, "stage furniture granted twice")
	settle()
end)

test("saving: data survives leaving and rejoining", function()
	local store = H.stores[Config.DataStoreName]
	check(store, "nothing was ever saved")
	local snapshot = H.deepCopy(data)
	local userId = player.UserId
	H.removePlayer(player)
	H.advance(3)
	local record = store["Player_" .. userId]
	check(record and record.data, "no record written on leave")
	eq(record.lock, nil, "session lock not released")
	eq(record.data.coins, snapshot.coins)
	eq(#H.Workspace.Bradys:GetChildren(), 1, "the leaver's Brady should be gone")
	check(H.Workspace.Houses:FindFirstChild("House_" .. userId) == nil, "the leaver's house should be gone")
	-- rejoin
	player = H.addPlayer("Tester", { ["local"] = true, userId = userId })
	H.advance(2)
	data = S.Data.get(player)
	check(data, "did not load on rejoin")
	check(not S.Data.session(player).isNew)
	eq(data.coins, snapshot.coins)
	eq(data.age, snapshot.age)
	eq(data.rebirths, 1)
	eq(count(data.inventory), count(snapshot.inventory))
	eq(count(data.achievements), count(snapshot.achievements))
	eq(#data.furniture.placed, #snapshot.furniture.placed)
	eq(data.daily.streak, snapshot.daily.streak)
	eq(data.equipped.Shirt, snapshot.equipped.Shirt)
	check(data.tutorialDone)
	eq(#S.House.get(player).info.furniture:GetChildren(), #data.furniture.placed, "placed furniture should reappear")
	-- the record is locked to this server while the player is here
	record = store["Player_" .. userId]
	check(record.lock and record.lock.job == "test-server-1", "no session lock while online")
end)

test("autosave runs on its interval", function()
	local store = H.stores[Config.DataStoreName]
	local key = "Player_" .. player.UserId
	data.coins += 12345
	H.advance(Config.AutosaveInterval + 25)
	eq(store[key].data.coins, data.coins, "autosave did not write")
	check(store[key].lock ~= nil, "autosave must keep the session lock")
end)

test("session lock: a profile open on another server is not loaded", function()
	allowWarnings = true
	local store = H.stores[Config.DataStoreName]
	local now = H.server.env.os.time()
	store.Player_555 = { data = DataManager.new(), lock = { job = "another-server", t = now } }
	store.Player_555.data.coins = 999
	local kicks = #H.kicks
	local locked = H.addPlayer("Locked", { userId = 555 })
	H.advance(90)
	check(#H.kicks > kicks, "a locked profile should not load (the player is asked to rejoin)")
	eq(S.Data.get(locked), nil)
	eq(store.Player_555.lock.job, "another-server", "the other server's lock was stolen")
	eq(store.Player_555.data.coins, 999)
	-- a stale lock (dead server) is taken over
	store.Player_556 = { data = DataManager.new(), lock = { job = "dead-server", t = now - Config.SessionLockTimeout - 60 } }
	store.Player_556.data.coins = 4242
	local revived = H.addPlayer("Revived", { userId = 556 })
	H.advance(3)
	check(S.Data.get(revived), "a stale lock should be taken over")
	eq(S.Data.get(revived).coins, 4242)
	H.removePlayer(revived)
end)

test("DataStore outage: nobody gets a blank profile, saves fail safely", function()
	allowWarnings = true
	local kicks = #H.kicks
	H.dataStoreDown = true
	local unlucky = H.addPlayer("Unlucky", { userId = 777 })
	H.advance(120)
	check(#H.kicks > kicks, "must kick rather than hand out a blank profile")
	eq(S.Data.get(unlucky), nil)
	eq(H.stores[Config.DataStoreName].Player_777, nil, "wrote a blank profile during an outage")
	-- a save during the outage must not crash or lose the in-memory data
	local coins = data.coins
	check(run(S.Data.save, player, false) == false, "save should report failure")
	eq(data.coins, coins)
	H.dataStoreDown = false
	check(run(S.Data.save, player, false) == true, "save should work again")
end)

test("corrupt records are repaired instead of crashing", function()
	allowWarnings = true
	local store = H.stores[Config.DataStoreName]
	store.Player_888 = { data = "totally not a table" }
	local corrupt = H.addPlayer("Corrupt", { userId = 888 })
	H.advance(3)
	local d = S.Data.get(corrupt)
	check(d and d.coins == Config.StartCoins, "corrupt record should fall back to a fresh profile")
	local backedUp = false
	for key in pairs(store) do
		if string.find(key, "Corrupt_888", 1, true) then
			backedUp = true
		end
	end
	check(backedUp, "the corrupt record was not backed up")
	H.removePlayer(corrupt)
	store.Player_889 = { data = { coins = "NaN", inventory = 7, equipped = { Shirt = {} }, furniture = { placed = "x" } } }
	local weird = H.addPlayer("Weird", { userId = 889 })
	H.advance(3)
	check(S.Data.get(weird) and S.Data.get(weird).coins == Config.StartCoins)
	H.removePlayer(weird)
end)

----------------------------------------------------------------------
-- 4. Client: every LocalScript, driven through its real buttons
----------------------------------------------------------------------
print("\n== client ==")
local State, PlayerGui

-- Is this GuiObject (and all of its ancestors) actually showing?
local function onScreen(object)
	local node = object
	while node and node ~= PlayerGui do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		if node:IsA("ScreenGui") and not node.Enabled then
			return false
		end
		node = node.Parent
	end
	return node == PlayerGui
end

local function find(root, name)
	return root:FindFirstChild(name, true)
end

local function click(button)
	check(button, "button not found")
	H.click(button)
	H.advance(0.4)
end

local function windowOf(guiName, panel)
	return PlayerGui[guiName]:FindFirstChild(panel .. "Window")
end

-- Random events keep firing in the background. Before a UI test, wait out
-- any active event and bring Brady home so the test starts from a calm state.
local function calm()
	local guard = 0
	while S.Events.current(player) and guard < 400 do
		H.advance(1)
		guard += 1
	end
	if S.Data.session(player).following then
		H.fire(player, "Care", "Follow", false)
	end
	if S.Data.session(player).sleeping then
		H.fire(player, "Care", "Wake")
	end
	if State then
		State.close()
	end
	H.advance(7)
end

-- Long waits do not need 10 frames per virtual second.
local function advanceCoarse(seconds, step)
	H.frameStep = step or 5
	H.advance(seconds)
	H.frameStep = 0.1
	H.advance(0.5)
end

test("client boots: all 17 LocalScripts run and receive the profile", function()
	local started = H.startClient()
	eq(#started, 17, "LocalScripts started")
	H.advance(4)
	PlayerGui = player.PlayerGui
	State = H.client.require(RS.Client.ClientState)
	check(State.data, "client never received its data")
	eq(State.data.coins, data.coins)
	check(State.fashion, "client never received the fashion show state")
	eq(#PlayerGui:GetChildren(), 15, "ScreenGuis")
	eq(#PlayerGui.MainUI.Menu:GetChildren(), 10, "8 menu buttons + grid layout + auto scale")
end)

test("HUD shows coins, age and meters from the server", function()
	run(S.Currency.add, player, 250, "test")
	H.advance(1)
	eq(find(PlayerGui.MainUI, "Amount").Text, Util.short(data.coins))
	local ageBar = PlayerGui.AgeUI.AgeBar
	eq(find(ageBar, "Current").Text, "AGE " .. data.age)
	check(string.find(find(ageBar, "Stage").Text, AgeSystem.getStage(data.age).name, 1, true), "stage name missing")
	setMeters(15, 80, 80, 80)
	S.Data.sync(player, "meters")
	H.advance(1)
	eq(find(PlayerGui.MainUI.Top.Meter_hunger, "Text").Text, "15")
	check(PlayerGui.MainUI.Menu.Brady:FindFirstChild("Badge"), "a low meter should badge the Brady button")
	setMeters(80, 80, 80, 80)
	S.Data.sync(player, "meters")
end)

test("every menu button opens its window, X closes it", function()
	local map = {
		Brady = { "BradyUI", "Brady" }, Wardrobe = { "WardrobeUI", "Wardrobe" }, Inventory = { "InventoryUI", "Inventory" },
		Shop = { "ShopUI", "Shop" }, Room = { "RoomUI", "Room" }, Collection = { "CollectionUI", "Collection" },
		Fashion = { "FashionUI", "Fashion" }, Settings = { "SettingsUI", "Settings" },
	}
	for name, where in pairs(map) do
		click(PlayerGui.MainUI.Menu[name])
		local root = windowOf(where[1], where[2])
		check(root and root.Visible, name .. " window did not open")
		eq(State.current, where[2])
		-- only one window at a time
		local open = 0
		for _, descendant in ipairs(PlayerGui:GetDescendants()) do
			if descendant:IsA("Frame") and string.sub(descendant.Name, -6) == "Window" and descendant.Visible then
				open += 1
			end
		end
		eq(open, 1, "windows open at once")
		click(find(root, "Close"))
		check(not root.Visible, name .. " window did not close")
	end
end)

test("announcements, toasts and item popups render", function()
	local Net = service("Net")
	Net.notify(player, { text = "BRADY AGED UP!", sub = "test", kind = "good", big = true })
	H.advance(0.5)
	local big = find(PlayerGui.MainUI, "Big")
	check(big.Visible and big.Text == "BRADY AGED UP!", "announcement not shown")
	H.advance(5)
	check(not big.Visible, "announcement never went away")
	Net.toast(player, "hello toast", "bad")
	H.advance(0.3)
	check(find(PlayerGui.MainUI.Toasts, "Toast"), "toast not shown")
	H.advance(4)
	check(not find(PlayerGui.MainUI.Toasts, "Toast"), "toast never went away")
	for _, id in ipairs({ "goo_tee", "silk_shirt", "archive_knit", "grail_tee" }) do
		Net.fire(player, "ItemGranted", { kind = "clothing", id = id, isNew = true })
	end
	Net.fire(player, "ItemGranted", { kind = "clothing", id = "goo_tee", isNew = false, refund = 15 })
	Net.fire(player, "ItemGranted", { kind = "furniture", id = "couch", isNew = true })
	H.advance(1)
	eq(big.Text, "NEW FIT UNLOCKED!")
	H.advance(3.2)
	eq(big.Text, "LEGENDARY PIECE!")
	H.advance(3.2)
	eq(big.Text, "ARCHIVE ITEM FOUND!")
	H.advance(4)
	eq(big.Text, "GRAIL FOUND!")
	H.advance(6)
	Net.fire(player, "Effect", "Reward", { xp = 12, coins = 5 })
	Net.fire(player, "AgeUp", { age = 4, stageChanged = true, stageName = "Kid Brady", blurb = "x", lines = { "+100 Goo Coins", "Unlocked: Hats" } })
	H.advance(1)
	check(PlayerGui.AgeUI.AgeUp.Visible, "age-up celebration not shown")
	eq(find(PlayerGui.AgeUI.AgeUp, "Headline").Text, "NEW ERA UNLOCKED!")
	H.advance(8)
	check(not PlayerGui.AgeUI.AgeUp.Visible, "age-up celebration never ended")
end)

test("tutorial: intro, guided steps that follow real actions, one-time bonus", function()
	calm()
	local coins = data.coins
	H.fire(player, "Tutorial", "Replay")
	check(data.tutorialDone == false)
	H.advance(2)
	local tutorial = PlayerGui.TutorialUI
	check(tutorial.Dim.Visible, "intro did not start")
	eq(tutorial.Dim.Intro.Text, "welcome to raise brady goo")
	H.advance(12)
	check(not tutorial.Dim.Visible and tutorial.Step.Visible, "guided steps did not start")
	eq(tutorial.Step.Title.Text, "1. FEED BRADY")
	setMeters(30, 80, 100, 50)
	H.fire(player, "Care", "Feed", "cereal")
	H.advance(1)
	eq(tutorial.Step.Title.Text, "2. PLAY WITH BRADY")
	click(tutorial.Step.Next) -- skip step
	H.advance(0.5)
	eq(tutorial.Step.Title.Text, "3. YOU EARNED GOO COINS!")
	H.advance(6) -- auto-advances
	eq(tutorial.Step.Title.Text, "4. OPEN THE WARDROBE")
	click(PlayerGui.MainUI.Menu.Wardrobe)
	H.advance(0.5)
	eq(tutorial.Step.Title.Text, "5. EQUIP CLOTHING")
	H.fire(player, "Unequip", "Shirt")
	H.fire(player, "Equip", "goo_tee")
	H.advance(1)
	eq(tutorial.Step.Title.Text, "6. AGE HIM UP")
	click(tutorial.Step.Next)
	H.advance(1)
	check(data.tutorialDone, "tutorial did not finish")
	check(not tutorial.Step.Visible)
	check(data.coins >= coins, "coins went down?")
	State.close()
	settle()
end)

test("inventory: lists owned items by category and equips through the UI", function()
	calm()
	click(PlayerGui.MainUI.Menu.Inventory)
	local root = windowOf("InventoryUI", "Inventory")
	local grid = find(root, "Grid")
	local cards = 0
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("TextButton") then
			cards += 1
		end
	end
	eq(cards, count(data.inventory), "one card per owned item")
	click(find(root, "Tab_Shirt"))
	local shirts = 0
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("TextButton") then
			shirts += 1
			check(ClothingSystem.get(string.sub(child.Name, 6)).slot == "Shirt", "wrong category in the Shirts tab")
		end
	end
	check(shirts >= 2)
	H.fire(player, "Unequip", "Shirt")
	click(find(grid, "Item_plain_tee"))
	local detail = find(root, "Detail")
	eq(find(detail, "ItemName").Text, "Plain White Tee")
	eq(find(detail, "Rarity").Text, "Rarity: Common")
	eq(find(detail, "Age").Text, "Required Age: 1")
	check(find(detail, "Description").Text ~= "")
	eq(find(detail, "Equip").Text, "EQUIP")
	click(find(detail, "Equip"))
	eq(data.equipped.Shirt, "plain_tee", "Equip button did nothing")
	H.advance(0.5)
	eq(find(detail, "Status").Text, "✓ EQUIPPED")
	eq(find(detail, "Equip").Text, "UNEQUIP")
	check(find(grid, "Item_plain_tee"):FindFirstChild("Equipped"), "equipped badge missing")
	click(find(detail, "Equip"))
	eq(data.equipped.Shirt, nil)
	-- an age-locked item shows as locked and cannot be equipped from the UI
	data.inventory.archive_knit = true
	S.Data.sync(player, "inventory")
	H.advance(0.5)
	click(find(grid, "Item_archive_knit"))
	if data.age < 18 then
		eq(find(detail, "Equip").Text, "LOCKED")
		click(find(detail, "Equip"))
		eq(data.equipped.Shirt, nil)
	end
	State.close()
end)

test("wardrobe: slot rows, picker, saved outfits and player gifts", function()
	calm()
	click(PlayerGui.MainUI.Menu.Wardrobe)
	local root = windowOf("WardrobeUI", "Wardrobe")
	local content = find(root, "Content")
	check(find(content, "Slot_Shirt") and find(content, "Slot_Hair"), "slot rows missing")
	check(find(root, "BradyPreview"):FindFirstChild("Brady"), "no preview model")
	click(find(find(content, "Slot_Shirt"), "Change"))
	check(find(content, "Item_plain_tee"), "picker did not list shirts")
	click(find(content, "Item_plain_tee"))
	eq(data.equipped.Shirt, "plain_tee")
	H.advance(0.5)
	click(find(content, "Back"))
	check(find(content, "Slot_Shirt"), "Back did not return to the slot list")
	click(find(find(root, "Outfit2"), "Button")) -- "Wear" on an empty slot: nothing
	local outfit = find(root, "Outfit2")
	for _, child in ipairs(outfit:GetChildren()) do
		if child:IsA("TextButton") and child.Text == "Save" then
			click(child)
		end
	end
	check(data.outfits["2"] and data.outfits["2"].Shirt == "plain_tee", "Save outfit button did nothing")
	click(find(root, "Tab_Style"))
	local gift = find(content, "Gift_gift_bucket")
	check(gift, "gift rows missing")
	if data.gifts.owned.gift_bucket then
		click(find(gift, "Wear"))
		eq(data.gifts.equipped.Head, "gift_bucket")
	end
	State.close()
end)

test("shop: every tab renders, buying and crates work through the UI", function()
	calm()
	data.coins = 500000
	S.Data.sync(player, "coins")
	click(PlayerGui.MainUI.Menu.Shop)
	local root = windowOf("ShopUI", "Shop")
	local list = find(root, "List")
	for _, tab in ipairs({ "Clothing", "Hair", "Food", "Furniture", "Decor", "Toys", "Crates", "Passes" }) do
		click(find(root, "Tab_" .. tab))
		local rows = 0
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("GuiObject") then
				rows += 1
			end
		end
		check(rows >= 2, tab .. " tab is empty")
	end
	-- food
	click(find(root, "Tab_Food"))
	local fruit = data.food.fruit or 0
	click(find(find(list, "Row1"), "Buy"))
	eq(data.food.fruit, fruit + 1, "food Buy button did nothing")
	-- furniture
	click(find(root, "Tab_Decor"))
	local owned = 0
	for _, n in pairs(data.furniture.owned) do
		owned += n
	end
	click(find(find(list, "Row1"), "Buy"))
	local after = 0
	for _, n in pairs(data.furniture.owned) do
		after += n
	end
	check(after == owned + 1 or data.age < 8, "furniture Buy button did nothing")
	-- crate with reveal
	click(find(root, "Tab_Crates"))
	local crates = data.stats.crates
	click(find(find(list, "Crate_thrift_bin"), "Open"))
	H.advance(4)
	eq(data.stats.crates, crates + 1, "crate Open button did nothing")
	local reveal = PlayerGui.ShopUI.CrateReveal
	check(reveal.Visible and find(reveal, "Rarity").Text ~= "", "crate reveal not shown")
	click(find(reveal, "Close"))
	check(not reveal.Visible)
	-- odds are visible for every crate
	for _, crate in ipairs(ShopSystem.Crates) do
		check(#find(find(list, "Crate_" .. crate.id), "Odds"):GetChildren() >= 4, "odds missing for " .. crate.id)
	end
	State.close()
	H.advance(6)
end)

test("Brady window + feed window drive the care actions", function()
	calm()
	click(PlayerGui.MainUI.Menu.Brady)
	local root = windowOf("BradyUI", "Brady")
	check(find(root, "BradyPreview"):FindFirstChild("Brady"), "no preview")
	check(string.find(find(root, "Stage").Text, "Age " .. data.age, 1, true))
	setMeters(20, 20, 60, 50)
	S.Data.sync(player, "meters")
	H.advance(0.5)
	click(find(root, "Action1")) -- Feed -> opens the pantry
	local feed = windowOf("BradyUI", "Feed")
	check(feed.Visible, "Feed window did not open")
	local feeds = data.stats.feeds
	click(find(find(feed, "Food_cereal"), "Button"))
	eq(data.stats.feeds, feeds + 1, "FEED button did nothing")
	settle()
	click(PlayerGui.MainUI.Menu.Brady)
	local cleans = data.stats.cleans
	click(find(root, "Action3")) -- brush hair
	check(data.stats.cleans > cleans, "Brush Hair button did nothing")
	H.advance(10) -- he may walk all the way to the sink first
	setMeters(60, 60, 20, 50)
	click(find(root, "Action5")) -- sleep
	check(S.Data.session(player).sleeping, "Sleep button did nothing: " .. tostring(H.lastSent(player, "Notify")[1].text))
	H.advance(1)
	eq(find(root, "Action5").Text, "⏰ Wake Up")
	click(find(root, "Action5"))
	check(not S.Data.session(player).sleeping, "Wake button did nothing")
	State.close()
	settle()
end)

test("mini-games: a full round of each UI game through the real UI", function()
	calm()
	local overlay = PlayerGui.MinigameUI.GameOverlay
	for _, id in ipairs({ "catch", "target", "reaction", "soccer", "dance" }) do
		H.advance(8)
		setMeters(80, 80, 100, 50)
		data.ageXP = math.max(data.ageXP, AgeSystem.totalXPForAge(8)) -- dance needs age 8
		data.age = AgeSystem.ageFromXP(data.ageXP)
		S.Data.sync(player, "meters", "age", "ageXP")
		local games = data.stats.minigames
		click(PlayerGui.MainUI.Menu.Brady)
		click(find(windowOf("BradyUI", "Brady"), "Action6")) -- Play
		local picker = windowOf("MinigameUI", "Minigame")
		check(picker.Visible, "game picker did not open")
		click(find(find(picker, "Game_" .. id), "Play"))
		H.advance(1.5)
		check(overlay.Visible, id .. " did not start")
		-- poke at whatever the game put on screen while it runs
		for _ = 1, 90 do
			for _, child in ipairs(find(overlay, "Arena"):GetChildren()) do
				if child:IsA("TextButton") and math.random() < 0.5 then
					H.click(child)
				end
			end
			H.advance(0.5)
			if find(overlay, "Results").Visible then
				break
			end
		end
		check(find(overlay, "Results").Visible, id .. " never finished")
		eq(data.stats.minigames, games + 1, id .. " did not pay out")
		check(string.find(find(find(overlay, "Results"), "Reward").Text, "Goo Coins", 1, true), id .. " reward text missing")
		for _, child in ipairs(find(overlay, "Results").Buttons:GetChildren()) do
			if child:IsA("TextButton") and child.Text == "Done" then
				click(child)
			end
		end
		check(not overlay.Visible, "Done did not close the game")
	end
	settle()
end)

test("room: placement mode places furniture where the ghost is", function()
	calm()
	local origin = S.House.origin(player)
	H.movePlayer(player, origin.Position + Vector3.new(0, 3, 0))
	-- aim the (fake) camera ray at the middle of the room
	local direction = Vector3.new(0.2, -0.7, -0.6).Unit
	H.camera.CFrame = CFrame.new(origin.Position - direction * 24)
	data.furniture.owned.lamp = (data.furniture.owned.lamp or 0) + 1
	for index = #data.furniture.placed, 1, -1 do
		H.fire(player, "RemoveFurniture", index)
	end
	S.Data.sync(player, "furniture")
	H.advance(0.5)
	click(PlayerGui.MainUI.Menu.Room)
	local root = windowOf("RoomUI", "Room")
	click(find(find(root, "Furniture_lamp"), "Place"))
	local bar = PlayerGui.RoomUI.PlacementBar
	check(bar.Visible, "placement bar not shown")
	local ghost = H.Workspace:FindFirstChild("PlacementGhost")
	check(ghost, "no placement ghost")
	check(not root.Visible, "window should close while placing")
	-- move the pointer, rotate, then click to place
	local UIT, KC = roblox.Enum.UserInputType, roblox.Enum.KeyCode
	H.input.InputChanged:Fire({ UserInputType = UIT.MouseMovement, Position = Vector3.new(600, 300, 0) }, false)
	H.input.InputBegan:Fire({ UserInputType = UIT.Keyboard, KeyCode = KC.R, Position = Vector3.new(0, 0, 0) }, false)
	H.advance(0.3)
	local hint = find(bar, "Hint").Text
	check(string.find(hint, "Placing", 1, true), "ghost should be valid in the middle of the room: " .. hint)
	local placed = #data.furniture.placed
	H.input.InputBegan:Fire({ UserInputType = UIT.MouseButton1, Position = Vector3.new(600, 300, 0) }, false)
	H.advance(0.6)
	eq(#data.furniture.placed, placed + 1, "clicking did not place the furniture")
	check(not bar.Visible and not H.Workspace:FindFirstChild("PlacementGhost"), "placement mode should end")
	local placement = data.furniture.placed[#data.furniture.placed]
	eq(placement.id, "lamp")
	eq(placement.r, 1, "R should have rotated it")
	-- remove mode: clicking the same spot picks it back up
	click(PlayerGui.MainUI.Menu.Room)
	click(find(root, "RemoveMode"))
	check(bar.Visible)
	H.input.InputBegan:Fire({ UserInputType = UIT.MouseButton1, Position = Vector3.new(600, 300, 0) }, false)
	H.advance(0.6)
	eq(#data.furniture.placed, placed, "remove mode did not pick the furniture up: " .. find(bar, "Hint").Text .. " / " .. tostring(H.lastSent(player, "Notify")[1].text))
	click(find(bar, "Button"))
	check(not bar.Visible)
	-- travel tab
	click(PlayerGui.MainUI.Menu.Room)
	click(find(root, "Tab_Travel"))
	check(find(root, "Player_" .. other.UserId), "other players should be listed")
	click(find(root, "Go_Plaza"))
	check((player.Character.HumanoidRootPart.CFrame.Position - Vector3.new(0, 4, 34)).Magnitude < 8, "Plaza travel button did nothing")
	H.fire(player, "Visit", "Home")
end)

test("collection book: progress, claims and the daily page", function()
	calm()
	click(PlayerGui.MainUI.Menu.Collection)
	local root = windowOf("CollectionUI", "Collection")
	local list = find(root, "List")
	check(string.find(find(root, "Summary").Text, "TOTAL COMPLETION", 1, true))
	local archive = find(list, "Collection_archive")
	local owned, total = CollectionSystem.progress(data, CollectionSystem.ById.archive)
	check(string.find(find(archive, "Text").Text, owned .. " / " .. total .. " ITEMS", 1, true), "archive collection count wrong: " .. find(archive, "Text").Text)
	local coins = data.coins
	click(find(archive, "Claim")) -- not complete: no payout
	eq(data.coins, coins)
	click(find(root, "Tab_Achievements"))
	check(find(list, "Achievement_first_bite"))
	click(find(root, "Tab_Tasks"))
	check(find(list, "Task1") and find(list, "Task3"), "daily tasks missing")
	data.daily.tasks[1].progress = 9999
	data.daily.tasks[1].claimed = false
	S.Data.sync(player, "daily")
	H.advance(0.5)
	coins = data.coins
	click(find(find(list, "Task1"), "Claim"))
	check(data.coins > coins, "task Claim button did nothing")
	click(find(root, "Tab_Daily"))
	check(find(list, "Day1") and find(list, "Day7"), "daily tiles missing")
	advanceCoarse(86400 + 40)
	calm()
	click(PlayerGui.MainUI.Menu.Collection)
	click(find(root, "Tab_Daily"))
	local streak = data.daily.streak
	click(find(list, "ClaimDaily"))
	check(data.daily.lastClaimDay == Util.today(), "daily Claim button did nothing")
	check(data.daily.streak >= 1 and data.daily.streak ~= streak or streak == 1)
	State.close()
	settle()
end)

test("mirror mode: camera, poses, screenshot, exit", function()
	calm()
	H.movePlayer(player, S.House.origin(player).Position + Vector3.new(0, 3, 0))
	H.trigger(S.House.get(player).info.prompts.Mirror, player)
	H.advance(8)
	local bar = PlayerGui.MirrorUI.MirrorBar
	check(bar.Visible, "mirror bar not shown")
	eq(H.camera.CameraType, roblox.Enum.CameraType.Scriptable)
	local rec = S.Brady.get(player)
	local toBrady = (H.camera.CFrame.Position - S.Brady.position(rec)).Magnitude
	check(toBrady < 30, "camera did not move close to Brady: " .. toBrady)
	click(find(bar, "Pose_Wave"))
	eq(rec.model:GetAttribute("Pose"), "Wave")
	local shots, photos = H.screenshots, data.stats.photos
	H.advance(31)
	click(find(bar, "Photo"))
	H.advance(2)
	eq(H.screenshots, shots + 1, "no screenshot was taken")
	eq(data.stats.photos, photos + 1)
	check(PlayerGui.MainUI.Enabled, "menus were left hidden after the screenshot")
	-- outfit change keeps mirror mode, closing the wardrobe returns to it
	click(find(bar, "Outfit"))
	check(windowOf("WardrobeUI", "Wardrobe").Visible and not bar.Visible)
	eq(H.camera.CameraType, roblox.Enum.CameraType.Scriptable)
	State.close()
	H.advance(0.3)
	check(bar.Visible, "pose bar should come back")
	click(find(bar, "Exit"))
	check(not bar.Visible)
	eq(H.camera.CameraType, roblox.Enum.CameraType.Custom)
	H.advance(1)
	check(rec.model:GetAttribute("State") ~= "Pose" and rec.model:GetAttribute("State") ~= "Mirror", "Brady is stuck at the mirror")
end)

test("inspect another player's Brady + settings window", function()
	calm()
	State.open("Inspect", other.UserId)
	H.advance(1.5)
	local root = windowOf("SocialUI", "Inspect")
	check(root.Visible)
	check(string.find(find(root, "Title").Text, "Friend", 1, true), "inspect title: " .. find(root, "Title").Text)
	check(find(root, "BradyPreview"):FindFirstChild("Brady"))
	local hypes = S.Data.get(other).stats.hypes
	click(find(root, "Hype"))
	eq(S.Data.get(other).stats.hypes, hypes + 1, "Hype button did nothing")
	State.open("Inspect", 424242)
	H.advance(1.5)
	click(PlayerGui.MainUI.Menu.Settings)
	local settings = windowOf("SettingsUI", "Settings")
	local before = data.settings.chatter
	click(find(find(settings, "Setting_chatter"), "Toggle"))
	eq(data.settings.chatter, not before, "settings toggle did nothing")
	H.advance(0.5)
	eq(find(find(settings, "Setting_chatter"), "Toggle").Text, before and "OFF" or "ON")
	click(find(find(settings, "Setting_lowGfx"), "Toggle"))
	click(find(find(settings, "Setting_lowGfx"), "Toggle"))
	click(find(settings, "Aura_rainbow")) -- no pass: stays "none"
	eq(data.settings.aura, "none")
	State.close()
end)

test("event banner + fashion window follow the server", function()
	calm()
	S.Events.force(player, "InsaneFit")
	H.advance(0.5)
	local banner = find(PlayerGui.MainUI, "EventBanner")
	check(banner.Visible, "event banner not shown")
	eq(find(banner, "Title").Text, "BRADY'S FIT IS INSANE")
	for _ = 1, 15 do
		-- the banner rebuilds its button as progress comes back: fetch it fresh
		local hype = find(banner, "Buttons"):FindFirstChildOfClass("TextButton")
		if hype then
			H.click(hype)
		end
		H.advance(0.35)
	end
	check(S.Events.current(player) == nil, "HYPE button did not complete the event")
	H.advance(0.5)
	check(not banner.Visible, "banner stayed after the event ended")
	settle()
	S.Events.force(player, "NewHaircut")
	H.advance(0.5)
	local keep
	for _, child in ipairs(find(banner, "Buttons"):GetChildren()) do
		if child:IsA("TextButton") and child.Text == "KEEP IT" then
			keep = child
		end
	end
	click(keep)
	check(S.Events.current(player) == nil, "KEEP IT did nothing")
	-- fashion window through a whole show
	local guard = 0
	while S.Fashion.phase() ~= "Signup" and guard < 400 do
		H.advance(1)
		guard += 1
	end
	H.advance(1)
	click(find(PlayerGui.MainUI, "FashionTicker"))
	local root = windowOf("FashionUI", "Fashion")
	check(root.Visible and string.find(find(root, "Phase").Text, "SIGN-UPS OPEN", 1, true), "fashion window: " .. find(root, "Phase").Text)
	local joined = data.stats.showsJoined
	for _, child in ipairs(find(root, "Actions"):GetChildren()) do
		if child:IsA("TextButton") and child.Text == "ENTER BRADY!" then
			click(child) -- (the window rebuilds its buttons, so stop iterating)
			break
		end
	end
	eq(data.stats.showsJoined, joined + 1, "ENTER BRADY! did nothing")
	guard = 0
	while S.Fashion.phase() ~= "Voting" and guard < 400 do
		H.advance(0.5)
		guard += 1
	end
	H.advance(1)
	check(root.Visible and string.find(find(root, "Phase").Text, "VOTE", 1, true), "voting should pop the window open")
	local voted = false
	for _, row in ipairs(find(root, "List"):GetChildren()) do
		local vote = row:IsA("Frame") and row:FindFirstChild("Vote")
		if vote then
			click(vote) -- (the list is rebuilt after voting, so stop iterating)
			voted = true
			break
		end
	end
	check(voted, "no vote buttons")
	guard = 0
	while S.Fashion.phase() ~= "Results" and guard < 200 do
		H.advance(0.5)
		guard += 1
	end
	H.advance(1)
	check(string.find(find(root, "Phase").Text, "RESULTS", 1, true))
	check(find(find(root, "List"), "Result1"), "results list empty")
	H.advance(Config.FashionResults + 4)
	State.close()
	settle()
end)

test("animator: every idle, walk, state and pose produces valid joints", function()
	calm()
	local Animator = H.client.require(RS.Client.BradyAnimator)
	local entry = { S = 1, hip = 2, pose = "Wave" }
	local n = 0
	local function runAll(tbl)
		for name, fn in pairs(tbl) do
			for _, t in ipairs({ 0, 0.1, 0.5, 1, 1.4, 2, 3 }) do
				local o = { W = CFrame.new(), N = CFrame.new(), LS = CFrame.new(), RS = CFrame.new(), LH = CFrame.new(), RH = CFrame.new() }
				fn(o, t, t * 1.3 + 2, entry)
				for key, value in pairs(o) do
					check(typeof(value) == "CFrame", name .. "." .. key .. " is not a CFrame")
					check(value.Position.X == value.Position.X, name .. " produced NaN")
				end
			end
			n += 1
		end
	end
	runAll(Animator.Idle)
	runAll(Animator.Walk)
	runAll(Animator.State)
	runAll(Animator.Poses)
	check(n >= 40, "expected 40+ animations, found " .. n)
	-- every style / pose the data refers to has an animation
	for _, stage in ipairs(AgeSystem.Stages) do
		check(Animator.Idle[stage.look.idle], "missing idle " .. stage.look.idle)
		check(Animator.Walk[stage.look.walk], "missing walk " .. stage.look.walk)
	end
	for _, pose in ipairs(AgeSystem.Poses) do
		check(Animator.Poses[pose.id], "missing pose " .. pose.id)
	end
	for _, item in ipairs(ClothingSystem.List) do
		check(not item.idle or Animator.Idle[item.idle], "missing idle " .. tostring(item.idle))
		check(not item.walk or Animator.Walk[item.walk], "missing walk " .. tostring(item.walk))
	end
	-- the live Brady is registered and actually being animated
	local rec = S.Brady.get(player)
	local live = Animator.get(rec.model)
	check(live, "the player's Brady is not registered with the animator")
	-- (Bradys far from the camera are deliberately not animated)
	H.camera.CFrame = CFrame.new(S.Brady.position(rec) + Vector3.new(0, 8, 20))
	S.Brady.act(rec, "Dance", 3)
	H.advance(1)
	rec = S.Brady.get(player)
	live = Animator.get(rec.model) -- (a random event may have rebuilt the model)
	check(live, "the rebuilt Brady is not registered with the animator")
	check(live.state == "Dance", string.format("the animator did not pick up the Dance state: entry=%s attr=%s distance=%.0f sleeping=%s", tostring(live.state), tostring(rec.model:GetAttribute("State")), (rec.model.PrimaryPart.CFrame.Position - H.camera.CFrame.Position).Magnitude, tostring(S.Data.session(player).sleeping)))
	check(live.motors.W.C0 ~= live.base.W, "joints are not moving")
	-- walking moves the model on the client
	settle()
	rec = S.Brady.get(player)
	S.Brady.setState(rec, "Idle")
	local start = rec.model.PrimaryPart.CFrame.Position
	S.Brady.walkTo(rec, S.Brady.position(rec) + Vector3.new(6, 0, 0), 6)
	H.advance(0.5)
	local mid = rec.model.PrimaryPart.CFrame.Position
	check((mid - start).Magnitude > 1 and (mid - start).Magnitude < 5.5, "client did not slide Brady along the walk line: " .. (mid - start).Magnitude)
	H.advance(2)
	check((rec.model.PrimaryPart.CFrame.Position - start).Magnitude > 5.5, "walk did not finish at the target")
	-- a Brady far from the camera is skipped (performance)
	H.camera.CFrame = CFrame.new(S.Brady.position(rec) + Vector3.new(0, 8, 400))
	H.advance(0.5)
	local frozen = Animator.get(rec.model).motors.W.C0
	S.Brady.act(rec, "Dance", 2)
	H.advance(1)
	check(Animator.get(rec.model).motors.W.C0 == frozen, "far-away Bradys should not be animated")
	H.camera.CFrame = CFrame.new(S.Brady.position(rec) + Vector3.new(0, 8, 20))
	settle()
	-- speech bubble
	S.Brady.say(rec, "archive era")
	H.advance(0.3)
	check(rec.model.Head:FindFirstChild("Bubble"), "no speech bubble")
end)

test("fuzz: mashing every visible button never errors", function()
	allowWarnings = true
	H.advance(40)
	setMeters(80, 80, 80, 80)
	data.coins = math.max(data.coins, 100000)
	local clicks = 0
	for pass = 1, 6 do
		-- open a different window each pass, then click everything on screen
		local menu = { "Brady", "Wardrobe", "Inventory", "Shop", "Room", "Collection", "Fashion", "Settings" }
		for _, name in ipairs(menu) do
			H.click(PlayerGui.MainUI.Menu[name])
			H.advance(0.4)
			local buttons = {}
			for _, descendant in ipairs(PlayerGui:GetDescendants()) do
				if descendant:IsA("GuiButton") and onScreen(descendant) then
					table.insert(buttons, descendant)
				end
			end
			for index = #buttons, 2, -1 do
				local swap = math.random(1, index)
				buttons[index], buttons[swap] = buttons[swap], buttons[index]
			end
			for index = 1, math.min(#buttons, 14) do
				local button = buttons[index]
				local alive = pcall(function()
					return button.Parent
				end)
				-- "DO IT" (rebirth) is skipped so the rest of the run keeps its age
				if alive and button.Parent and button.Text ~= "DO IT" and onScreen(button) then
					H.click(button)
					clicks += 1
					H.advance(0.35)
				end
			end
			H.advance(pass == 3 and 30 or 1)
		end
	end
	check(clicks > 300, "fuzz barely clicked anything: " .. clicks)
	print("        (" .. clicks .. " random button presses)")
	H.advance(60)
	State.close()
end)

test("soak: two hours of idle play with two players stays healthy", function()
	local shows = H.sentCount(player, "FashionState")
	advanceCoarse(7200, 1)
	check(H.sentCount(player, "FashionState") > shows + 20, "fashion shows stopped cycling")
	check(S.Data.get(player) and S.Data.get(other))
	local rec = S.Brady.get(player)
	check(rec.model and rec.model.Parent, "Brady vanished")
	check(data.meters.hunger >= 0 and data.meters.hunger <= 100)
	eq(#H.Workspace.EventProps:GetChildren() <= 2, true, "event props are leaking")
	eq(#H.Workspace.Bradys:GetChildren(), 2)
end)

test("shutdown saves everyone", function()
	data.coins = 31337
	local store = H.stores[Config.DataStoreName]
	H.shutdown()
	eq(store["Player_" .. player.UserId].data.coins, 31337)
	eq(store["Player_" .. player.UserId].lock, nil)
	eq(store["Player_" .. other.UserId].lock, nil)
end)

print(string.format("\n%d passed, %d failed", results.passed, results.failed))
if results.failed > 0 then
	print("failed: " .. table.concat(results.failures, " | "))
end
process.exit(results.failed > 0 and 1 or 0)
