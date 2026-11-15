--[[
	DailySystem
	The 7-day login reward track and the pool of daily tasks.
	"Days" are UTC day numbers (os.time() // 86400) decided by the SERVER, so
	changing the clock on a device does nothing.
]]

local DailySystem = {}

-- kind: coins | food | clothing (random unowned of a rarity) | furniture | box
DailySystem.Rewards = {
	{ day = 1, kind = "coins", amount = 100, icon = "🟢", label = "100 Goo Coins" },
	{ day = 2, kind = "food", id = "pizza", amount = 3, icon = "🍕", label = "3 Pizza Slices" },
	{ day = 3, kind = "clothing", rarity = "Common", icon = "👕", label = "Common Clothing", fallback = 200 },
	{ day = 4, kind = "coins", amount = 500, icon = "🟢", label = "500 Goo Coins" },
	{ day = 5, kind = "clothing", rarity = "Rare", slots = { "Accessory", "Hat", "Glasses" }, icon = "📿", label = "Rare Accessory", fallback = 800 },
	{ day = 6, kind = "furniture", id = "trophy_lamp", icon = "🏆", label = "Golden Trophy Lamp" },
	{ day = 7, kind = "box", icon = "🎁", label = "Random Fashion Item", fallback = 1500 },
}

-- Can the player claim today?  `daily` = data.daily
function DailySystem.canClaim(daily, today)
	return daily.lastClaimDay < today
end

-- Which of the 7 tiles the next claim will be (1-7).
function DailySystem.nextIndex(daily, today)
	local streak = daily.streak
	if daily.lastClaimDay < today - 1 then
		streak = 0 -- missed a day: the streak resets
	end
	return streak % 7 + 1
end

-- Coin rewards grow a little every completed week (capped at 3x).
function DailySystem.weekMultiplier(streak)
	return math.min(3, 1 + math.floor(streak / 7) * 0.5)
end

----------------------------------------------------------------------
-- DAILY TASKS: three are picked per player per day.
-- `stat` is the stats counter that advances the task.
----------------------------------------------------------------------
DailySystem.Tasks = {
	{ id = "feed", text = "Feed Brady %d times", stat = "feeds", goal = 5, coins = 120 },
	{ id = "clean", text = "Clean Brady %d times", stat = "cleans", goal = 3, coins = 120 },
	{ id = "sleep", text = "Put Brady to bed", stat = "sleeps", goal = 1, coins = 100 },
	{ id = "games", text = "Play %d mini-games", stat = "minigames", goal = 4, coins = 180 },
	{ id = "hidden", text = "Find %d hidden goo blobs", stat = "hidden", goal = 3, coins = 200 },
	{ id = "event", text = "Complete a random event", stat = "events", goal = 1, coins = 150 },
	{ id = "crate", text = "Open a crate", stat = "crates", goal = 1, coins = 150 },
	{ id = "coins", text = "Earn %d Goo Coins", stat = "coinsEarned", goal = 600, coins = 150 },
	{ id = "show", text = "Enter a fashion show", stat = "showsJoined", goal = 1, coins = 220, minAge = 5 },
}

DailySystem.TaskById = {}
for _, task in ipairs(DailySystem.Tasks) do
	DailySystem.TaskById[task.id] = task
end

-- Deterministic pick: the same player gets the same 3 tasks all day.
function DailySystem.pickTasks(userId, day, age)
	local rng = Random.new((userId % 100000) * 31 + day)
	local candidates = {}
	for _, task in ipairs(DailySystem.Tasks) do
		if age >= (task.minAge or 1) then
			table.insert(candidates, task)
		end
	end
	local picked = {}
	for _ = 1, 3 do
		if #candidates == 0 then
			break
		end
		local index = rng:NextInteger(1, #candidates)
		table.insert(picked, { id = candidates[index].id, progress = 0, claimed = false })
		table.remove(candidates, index)
	end
	return picked
end

function DailySystem.taskText(task)
	if string.find(task.text, "%%d") then
		return string.format(task.text, task.goal)
	end
	return task.text
end

return DailySystem
