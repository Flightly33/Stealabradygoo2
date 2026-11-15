--[[
	DailyServer
	Daily login rewards (a 7 day track that gets better every day) and three
	daily tasks. The day number always comes from the server clock (UTC), and
	lastClaimDay is written before the reward is handed out, so a reward can
	never be claimed twice in one day.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local ClothingSystem = require(Modules.ClothingSystem)
local DailySystem = require(Modules.DailySystem)
local FoodSystem = require(Modules.FoodSystem)
local FurnitureSystem = require(Modules.FurnitureSystem)
local ShopSystem = require(Modules.ShopSystem)
local Util = require(Modules.Util)

local DailyServer = {}

local S
local clock = 0

-- Makes sure the player has today's three tasks.
local function ensureTasks(player, data)
	local today = Util.today()
	if data.daily.taskDay ~= today or #data.daily.tasks == 0 then
		data.daily.taskDay = today
		data.daily.tasks = DailySystem.pickTasks(player.UserId, today, data.age)
		return true
	end
	return false
end

-- Random unowned clothing of a rarity (optionally limited to some slots).
local function randomUnowned(data, rarity, slots)
	local options = {}
	for _, item in ipairs(ClothingSystem.ByRarity[rarity]) do
		if item.drop and not data.inventory[item.id] and (slots == nil or table.find(slots, item.slot)) then
			table.insert(options, item)
		end
	end
	return Util.pick(options)
end

local function claimDaily(player, data)
	local today = Util.today()
	local daily = data.daily
	if not DailySystem.canClaim(daily, today) then
		S.Net.toast(player, "come back tomorrow for the next reward!", "bad")
		return
	end
	local index = DailySystem.nextIndex(daily, today)
	local continued = daily.lastClaimDay == today - 1
	daily.streak = continued and daily.streak + 1 or 1
	daily.lastClaimDay = today -- written before granting anything
	local reward = DailySystem.Rewards[index]
	local multiplier = DailySystem.weekMultiplier(daily.streak - 1)
	local text

	if reward.kind == "coins" then
		local coins = S.Currency.add(player, math.floor(reward.amount * multiplier), "daily")
		text = "+" .. coins .. " Goo Coins"
	elseif reward.kind == "food" then
		local food = FoodSystem.get(reward.id)
		data.food[reward.id] = math.min(99, (data.food[reward.id] or 0) + reward.amount)
		S.Data.sync(player, "food")
		text = reward.amount .. "x " .. food.name
	elseif reward.kind == "clothing" then
		local item = randomUnowned(data, reward.rarity, reward.slots)
		if item then
			S.Clothing.grant(player, item.id, "daily")
			text = item.name
		else
			local coins = S.Currency.add(player, math.floor(reward.fallback * multiplier), "daily")
			text = "you own them all! +" .. coins .. " Goo Coins instead"
		end
	elseif reward.kind == "furniture" then
		local def = FurnitureSystem.get(reward.id)
		data.furniture.owned[reward.id] = (data.furniture.owned[reward.id] or 0) + 1
		S.Data.sync(player, "furniture")
		text = def.name
	elseif reward.kind == "box" then
		local item = ShopSystem.roll(ShopSystem.DailyBox)
		if item then
			local result = S.Clothing.grant(player, item.id, "daily")
			text = item.name .. (result.isNew and "" or " (duplicate: +" .. result.refund .. " coins)")
		else
			local coins = S.Currency.add(player, reward.fallback, "daily")
			text = "+" .. coins .. " Goo Coins"
		end
	end

	S.Data.sync(player, "daily")
	S.Net.notify(player, { text = "DAY " .. index .. " REWARD!", sub = (text or "") .. "  •  streak: " .. daily.streak, kind = "good", sound = "rare" })
	S.Achievements.check(player)
end

local function claimTask(player, data, index)
	if type(index) ~= "number" then
		return
	end
	local task_ = data.daily.tasks[index]
	local def = task_ and DailySystem.TaskById[task_.id]
	if not def or task_.claimed or task_.progress < def.goal then
		return
	end
	task_.claimed = true -- flag first
	S.Data.sync(player, "daily")
	local coins = S.Currency.add(player, S.Currency.scaled(player, def.coins), "task")
	local xp = S.Age.addXP(player, 40)
	S.Net.fire(player, "Effect", "Reward", { xp = xp, coins = coins, text = "TASK DONE!" })
end

-- Called by AchievementServer.bump whenever a stat counter increases.
function DailyServer.progress(player, stat, amount)
	local data = S.Data.get(player)
	if not data then
		return
	end
	local changed = false
	for _, task_ in ipairs(data.daily.tasks) do
		local def = DailySystem.TaskById[task_.id]
		if def and def.stat == stat and not task_.claimed and task_.progress < def.goal then
			task_.progress = math.min(def.goal, task_.progress + amount)
			changed = true
			if task_.progress >= def.goal then
				S.Net.toast(player, "Daily task complete: " .. DailySystem.taskText(def), "good")
			end
		end
	end
	if changed then
		S.Data.sync(player, "daily")
	end
end

-- Called once a second from Main: handles midnight (UTC) rolling over.
function DailyServer.tick()
	clock += 1
	if clock < 30 then
		return
	end
	clock = 0
	local today = Util.today()
	for player, data, session in S.Data.each() do
		if session.day ~= today then
			session.day = today
			ensureTasks(player, data)
			S.Data.syncSession(player, "day")
			S.Data.sync(player, "daily")
		end
	end
end

function DailyServer.init(services)
	S = services
	S.Net.on("ClaimDaily", claimDaily, 2)
	S.Net.on("ClaimTask", claimTask, 4)
end

function DailyServer.playerAdded(player, data)
	local session = S.Data.session(player)
	session.day = Util.today()
	ensureTasks(player, data)
end

return DailyServer
