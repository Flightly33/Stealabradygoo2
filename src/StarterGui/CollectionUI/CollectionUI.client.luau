--[[
	CollectionUI
	The collection book, in four tabs:
	  * Collections   - "ARCHIVE COLLECTION 17 / 50 ITEMS" with completion
	                    percentage and a reward to claim when finished
	  * Achievements  - progress + the Goo Coins each one paid
	  * Daily Tasks   - today's three tasks
	  * Daily Reward  - the 7 day login track

	All claims are requests. The server re-checks that the collection / task
	is really complete and that it has not been claimed before.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = ReplicatedStorage:WaitForChild("Client")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local State = require(Client:WaitForChild("ClientState"))
local UI = require(Client:WaitForChild("UI"))
local AchievementSystem = require(Modules:WaitForChild("AchievementSystem"))
local AgeSystem = require(Modules:WaitForChild("AgeSystem"))
local CollectionSystem = require(Modules:WaitForChild("CollectionSystem"))
local DailySystem = require(Modules:WaitForChild("DailySystem"))
local Util = require(Modules:WaitForChild("Util"))

local gui = script.Parent
local C = UI.Colors

State.wait()

local window = UI.window(gui, { name = "Collection", title = "📖 Collection Book", width = 820, height = 490 })
local body = window.body

local current = "Collections"
local refresh
local tabs = UI.tabs(body, {
	{ id = "Collections", text = "📖 Collections" },
	{ id = "Achievements", text = "🏅 Achievements" },
	{ id = "Tasks", text = "✅ Daily Tasks" },
	{ id = "Daily", text = "🎁 Daily Reward" },
}, function(id)
	current = id
	refresh()
end, { Width = 796, TextSize = 15 })

local header = UI.label(body, "", { Name = "Summary", Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 44), TextSize = 17, Color = C.gold })
local list = UI.scroll(body, { Name = "List", Size = UDim2.new(1, 0, 1, -78), Position = UDim2.fromOffset(0, 76) })
local layout

local function setLayout(kind)
	if layout then
		layout:Destroy()
	end
	if kind == "grid" then
		layout = UI.grid(list, 104, 140, 8)
	else
		layout = UI.list(list, { pad = 6 })
	end
end

----------------------------------------------------------------------
local function showCollections()
	setLayout("list")
	local data = State.data
	header.Text = "TOTAL COMPLETION: " .. CollectionSystem.totalPercent(data) .. "%"
	for index, collection in ipairs(CollectionSystem.List) do
		local owned, total = CollectionSystem.progress(data, collection)
		local complete = owned >= total
		local claimed = data.collectionsClaimed[collection.id] == true
		local row = UI.row(list, { Name = "Collection_" .. collection.id, Size = UDim2.new(1, -12, 0, 70), LayoutOrder = index, StrokeColor = complete and C.goo or nil })
		UI.label(row, collection.icon, { Size = UDim2.fromOffset(56, 70), TextSize = 34 })
		UI.label(row, string.upper(collection.name), { Size = UDim2.new(1, -250, 0, 24), Position = UDim2.fromOffset(60, 5), TextSize = 17, AlignX = Enum.TextXAlignment.Left })
		local bar = UI.bar(row, { Size = UDim2.new(1, -250, 0, 18), Position = UDim2.fromOffset(60, 30), Color = complete and C.goo or C.blue, TextSize = 12 })
		bar.set(owned / math.max(1, total), string.format("%d / %d ITEMS  (%d%%)", owned, total, math.floor(owned / math.max(1, total) * 100)))
		local rewardText = "Reward: " .. Util.commas(collection.coins) .. " Goo Coins" .. (collection.title and ("  +  title \"" .. collection.title .. "\"") or "")
		UI.label(row, rewardText, { Size = UDim2.new(1, -250, 0, 18), Position = UDim2.fromOffset(60, 50), TextSize = 11, Font = UI.BodyFont, Color = C.sub, AlignX = Enum.TextXAlignment.Left })
		local button = UI.button(row, claimed and "CLAIMED ✓" or "CLAIM", { Name = "Claim", Size = UDim2.fromOffset(160, 46), Position = UDim2.new(1, -170, 0, 12), TextSize = 18 }, function()
			if complete and not claimed then
				State.send("ClaimCollection", collection.id)
			elseif not complete then
				State.toast(string.format("collect %d more to finish this", total - owned), "info")
			end
		end)
		UI.setEnabled(button, complete and not claimed)
	end
end

local function showAchievements()
	setLayout("list")
	local data = State.data
	local done = Util.count(data.achievements)
	header.Text = string.format("ACHIEVEMENTS: %d / %d", done, #AchievementSystem.List)
	-- unlocked ones first
	local sorted = table.clone(AchievementSystem.List)
	table.sort(sorted, function(a, b)
		local da, db = data.achievements[a.id] == true, data.achievements[b.id] == true
		if da ~= db then
			return db -- locked first, so the next goals are on top
		end
		return a.coins < b.coins
	end)
	for index, def in ipairs(sorted) do
		local unlocked = data.achievements[def.id] == true
		local value = math.min(AchievementSystem.value(def, data), def.goal)
		local row = UI.row(list, { Name = "Achievement_" .. def.id, Size = UDim2.new(1, -12, 0, 54), LayoutOrder = index, StrokeColor = unlocked and C.gold or nil })
		UI.label(row, unlocked and "🏅" or "🔒", { Size = UDim2.fromOffset(50, 54), TextSize = 28 })
		UI.label(row, def.name, { Size = UDim2.new(1, -330, 0, 24), Position = UDim2.fromOffset(54, 4), TextSize = 16, Color = unlocked and C.gold or C.text, AlignX = Enum.TextXAlignment.Left })
		UI.label(row, def.desc, { Size = UDim2.new(1, -330, 0, 20), Position = UDim2.fromOffset(54, 28), TextSize = 12, Font = UI.BodyFont, Color = C.sub, AlignX = Enum.TextXAlignment.Left })
		local bar = UI.bar(row, { Size = UDim2.fromOffset(150, 18), Position = UDim2.new(1, -270, 0, 18), Color = unlocked and C.gold or C.blue, TextSize = 11 })
		bar.set(value / def.goal, Util.short(value) .. " / " .. Util.short(def.goal))
		UI.label(row, "+" .. Util.short(def.coins), { Size = UDim2.fromOffset(100, 54), Position = UDim2.new(1, -108, 0, 0), TextSize = 16, Color = C.goo })
	end
end

local function showTasks()
	setLayout("list")
	local data = State.data
	header.Text = "TODAY'S TASKS  (new ones every day)"
	local multiplier = AgeSystem.rewardMultiplier(data.age, data.rebirths)
	for index, task_ in ipairs(data.daily.tasks) do
		local def = DailySystem.TaskById[task_.id]
		if def then
			local complete = task_.progress >= def.goal
			local row = UI.row(list, { Name = "Task" .. index, Size = UDim2.new(1, -12, 0, 76), LayoutOrder = index, StrokeColor = complete and C.goo or nil })
			UI.label(row, complete and "✅" or "📝", { Size = UDim2.fromOffset(56, 76), TextSize = 32 })
			UI.label(row, DailySystem.taskText(def), { Size = UDim2.new(1, -250, 0, 26), Position = UDim2.fromOffset(60, 8), TextSize = 18, AlignX = Enum.TextXAlignment.Left })
			local bar = UI.bar(row, { Size = UDim2.new(1, -250, 0, 20), Position = UDim2.fromOffset(60, 40), Color = complete and C.goo or C.blue, TextSize = 12 })
			bar.set(task_.progress / def.goal, Util.short(task_.progress) .. " / " .. Util.short(def.goal))
			local button = UI.button(row, task_.claimed and "CLAIMED ✓" or ("CLAIM\n+" .. math.floor(def.coins * multiplier + 0.5)), { Name = "Claim", Size = UDim2.fromOffset(160, 52), Position = UDim2.new(1, -170, 0, 12), TextSize = 16 }, function()
				if complete and not task_.claimed then
					State.send("ClaimTask", index)
				end
			end)
			UI.setEnabled(button, complete and not task_.claimed)
		end
	end
	if #data.daily.tasks == 0 then
		UI.label(list, "tasks are loading...", { Size = UDim2.new(1, -12, 0, 60), TextSize = 16, Font = UI.BodyFont, Color = C.sub })
	end
end

local function showDaily()
	setLayout("grid")
	local data = State.data
	local today = State.session.day or 0
	local canClaim = DailySystem.canClaim(data.daily, today)
	local nextIndex = DailySystem.nextIndex(data.daily, today)
	local streak = data.daily.streak
	if data.daily.lastClaimDay < today - 1 then
		streak = 0
	end
	header.Text = canClaim and ("DAY " .. nextIndex .. " IS READY!   streak: " .. streak) or ("come back tomorrow!   streak: " .. streak)
	for index, reward in ipairs(DailySystem.Rewards) do
		local claimedToday = not canClaim and ((streak - 1) % 7 + 1) >= index
		local isNext = canClaim and index == nextIndex
		local past = canClaim and index < nextIndex
		local tile = UI.frame(list, { Name = "Day" .. index, Size = UDim2.fromOffset(104, 140), Color = isNext and C.gold or C.panel, Corner = 14, LayoutOrder = index })
		UI.stroke(tile, 3, isNext and C.goo or C.dark)
		UI.label(tile, "DAY " .. index, { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 6), TextSize = 16, Color = isNext and C.dark or C.sub })
		UI.label(tile, reward.icon, { Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 32), TextSize = 40 })
		UI.label(tile, reward.label, { Size = UDim2.new(1, -8, 0, 36), Position = UDim2.fromOffset(4, 84), TextSize = 12, Font = UI.BodyFont, Color = isNext and C.dark or C.text })
		if claimedToday or past then
			local shade = UI.frame(tile, { Name = "Done", Color = C.dark, Transparency = 0.45, Corner = 14, ZIndex = 3 })
			UI.label(shade, "✓", { TextSize = 46, Color = C.goo, ZIndex = 4 })
		end
	end
	local button = UI.button(list, canClaim and "CLAIM!" or "tomorrow", { Name = "ClaimDaily", Size = UDim2.fromOffset(104, 140), Color = C.goo, TextSize = 22, LayoutOrder = 8 }, function()
		if DailySystem.canClaim(State.data.daily, State.session.day or 0) then
			State.send("ClaimDaily")
		else
			State.toast("you already claimed today's reward", "info")
		end
	end)
	UI.setEnabled(button, canClaim)
end

function refresh()
	if not window.visible then
		return
	end
	UI.clear(list)
	if current == "Achievements" then
		showAchievements()
	elseif current == "Tasks" then
		showTasks()
	elseif current == "Daily" then
		showDaily()
	else
		showCollections()
	end
end

window.onShow(function(arg)
	if type(arg) == "string" and tabs.buttons[arg] then
		current = arg
	end
	tabs.select(current, true)
	refresh()
end)
State.on("inventory", refresh)
State.on("achievements", refresh)
State.on("collectionsClaimed", refresh)
State.on("daily", refresh)
State.on("furniture", function()
	if current == "Collections" then
		refresh()
	end
end)
State.onSession("day", refresh)
