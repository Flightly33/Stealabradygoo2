--[[
	BradyUI
	Two windows:
	  "Brady" - his status (age, mood, the four meters) and every care action
	  "Feed"  - the pantry: pick a food to feed him, or buy more

	Buttons only send requests. The server decides whether Brady is asleep,
	busy, full, out of food... and the HUD shows its answer.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = ReplicatedStorage:WaitForChild("Client")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local State = require(Client:WaitForChild("ClientState"))
local UI = require(Client:WaitForChild("UI"))
local Preview = require(Client:WaitForChild("Preview"))
local AgeSystem = require(Modules:WaitForChild("AgeSystem"))
local Config = require(Modules:WaitForChild("Config"))
local FoodSystem = require(Modules:WaitForChild("FoodSystem"))
local InventorySystem = require(Modules:WaitForChild("InventorySystem"))

local gui = script.Parent
local C = UI.Colors

State.wait()

----------------------------------------------------------------------
-- BRADY WINDOW
----------------------------------------------------------------------
local window = UI.window(gui, { name = "Brady", title = "🧒 Brady Goo", width = 780, height = 470 })
local body = window.body

local left = UI.box(body, { Name = "Left", Size = UDim2.new(0, 250, 1, 0) })
local preview = Preview.new(left, { Size = UDim2.new(1, 0, 0, 250) })
local nameLabel = UI.label(left, "", { Name = "Stage", Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 256), TextSize = 22, Color = C.goo, Outline = 2 })
local blurbLabel = UI.label(left, "", { Name = "Blurb", Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 284), TextSize = 13, Font = UI.BodyFont, Color = C.sub })
local moodLabel = UI.label(left, "", { Name = "Mood", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 326), TextSize = 16, Color = C.gold })
local rebirthButton = UI.button(left, "⭐ REBIRTH", { Name = "Rebirth", Size = UDim2.new(1, 0, 0, 38), Position = UDim2.fromOffset(0, 356), Color = C.pink, TextSize = 18 }, function()
	State.open("Rebirth")
end)

local right = UI.box(body, { Name = "Right", Size = UDim2.new(1, -266, 1, 0), Position = UDim2.fromOffset(266, 0) })

local METERS = {
	{ key = "hunger", name = "🍔 Hunger", color = C.gold },
	{ key = "clean", name = "🫧 Clean", color = C.blue },
	{ key = "energy", name = "⚡ Energy", color = C.goo },
	{ key = "fun", name = "🎮 Fun", color = C.pink },
}
local bars = {}
for index, meter in ipairs(METERS) do
	local y = (index - 1) * 32
	UI.label(right, meter.name, { Size = UDim2.fromOffset(110, 26), Position = UDim2.fromOffset(0, y), TextSize = 16, AlignX = Enum.TextXAlignment.Left })
	bars[meter.key] = UI.bar(right, { Size = UDim2.new(1, -118, 0, 22), Position = UDim2.fromOffset(116, y + 2), Color = meter.color, TextSize = 13 })
end

local actions = UI.box(right, { Name = "Actions", Size = UDim2.new(1, 0, 1, -140), Position = UDim2.fromOffset(0, 138) })
UI.grid(actions, 160, 62, 8)

local function action(order, text, color, callback)
	return UI.button(actions, text, { Name = "Action" .. order, Size = UDim2.fromOffset(160, 62), Color = color, TextSize = 17, LayoutOrder = order }, callback)
end

action(1, "🍔 Feed", C.gold, function()
	State.open("Feed")
end)
action(2, "🚿 Shower", C.blue, function()
	State.send("Care", "Shower")
end)
action(3, "💇 Brush Hair", C.blue, function()
	State.send("Care", "BrushHair")
end)
action(4, "👟 Clean Shoes", C.blue, function()
	State.send("Care", "CleanShoes")
end)
local sleepButton = action(5, "🛏️ Sleep", C.purple, function()
	State.send("Care", State.session.sleeping and "Wake" or "Sleep")
end)
action(6, "🎮 Play", C.pink, function()
	State.open("Minigame")
end)
local followButton = action(7, "🚶 Follow me", C.goo, function()
	State.send("Care", "Follow", not State.session.following)
end)
action(8, "📣 Call Brady", C.goo, function()
	State.send("Care", "Call")
end)
action(9, "🏠 Go Home", C.sub, function()
	State.send("Visit", "Home")
	State.close()
end)

local function refreshStatus()
	local data = State.data
	local stage = AgeSystem.getStage(data.age)
	nameLabel.Text = stage.name .. "  •  Age " .. data.age
	blurbLabel.Text = stage.blurb
	local mood, face = AgeSystem.moodName(data.meters)
	moodLabel.Text = string.format("%s %s  (XP x%.2f)", face, mood, AgeSystem.moodMultiplier(data.meters))
	for _, meter in ipairs(METERS) do
		local value = data.meters[meter.key]
		bars[meter.key].set(value / 100, math.floor(value + 0.5) .. " / 100", value < 20 and C.red or meter.color)
	end
	rebirthButton.Visible = data.age >= AgeSystem.MaxAge
	sleepButton.Text = State.session.sleeping and "⏰ Wake Up" or "🛏️ Sleep"
	if data.age < Config.FollowMinAge then
		followButton.Text = "🔒 Outside at age " .. Config.FollowMinAge
	else
		followButton.Text = State.session.following and "🏠 Stay home" or "🚶 Follow me"
	end
end

local function refreshPreview()
	if window.visible then
		preview.set({ age = State.data.age, equipped = State.data.equipped })
	end
end

window.onShow(function()
	refreshStatus()
	refreshPreview()
end)
State.on("meters", function()
	if window.visible then
		refreshStatus()
	end
end)
State.on("age", function()
	refreshStatus()
	refreshPreview()
end)
State.on("equipped", refreshPreview)
State.onSession("sleeping", refreshStatus)
State.onSession("following", refreshStatus)

----------------------------------------------------------------------
-- REBIRTH CONFIRMATION (a tiny window of its own)
----------------------------------------------------------------------
local rebirth = UI.window(gui, { name = "Rebirth", title = "⭐ Rebirth Brady?", width = 520, height = 330 })
UI.label(rebirth.body, "Brady goes back to being a baby.\n\nYou KEEP: every clothing item, furniture, Goo Coins, collections and gifts.\nYou LOSE: his age (and the house shrinks until he grows again).\n\nReward: +" .. math.floor(Config.RebirthBonus * 100) .. "% Goo Coins and Age XP forever, and a ★ on his nameplate.", {
	Size = UDim2.new(1, 0, 1, -64),
	TextSize = 16,
	Font = UI.BodyFont,
	Color = C.text,
})
UI.button(rebirth.body, "DO IT", { Size = UDim2.fromOffset(200, 50), Position = UDim2.new(0.5, -210, 1, -54), Color = C.pink, TextSize = 24 }, function()
	State.send("Rebirth")
	State.close()
end)
UI.button(rebirth.body, "not yet", { Size = UDim2.fromOffset(200, 50), Position = UDim2.new(0.5, 10, 1, -54), Color = C.sub, TextSize = 20 }, function()
	State.open("Brady")
end)

----------------------------------------------------------------------
-- FEED WINDOW
----------------------------------------------------------------------
local feed = UI.window(gui, { name = "Feed", title = "🍔 Feed Brady", width = 600, height = 470 })
local hungerBar = UI.bar(feed.body, { Size = UDim2.new(1, 0, 0, 22), Color = C.gold, TextSize = 13 })
local foodList = UI.scroll(feed.body, { Size = UDim2.new(1, 0, 1, -30), Position = UDim2.fromOffset(0, 30) })
UI.list(foodList, { pad = 6 })

local function refreshFeed()
	if not feed.visible then
		return
	end
	local data = State.data
	hungerBar.set(data.meters.hunger / 100, "Hunger " .. math.floor(data.meters.hunger + 0.5) .. " / 100")
	UI.clear(foodList)
	for index, food in ipairs(FoodSystem.List) do
		local owned = data.food[food.id] or 0
		local locked = data.age < (food.minAge or 1)
		local row = UI.row(foodList, { Name = "Food_" .. food.id, Size = UDim2.new(1, -12, 0, 62), LayoutOrder = index })
		UI.label(row, food.icon, { Size = UDim2.fromOffset(54, 62), TextSize = 36 })
		UI.label(row, food.name .. (food.free and "  (free)" or "  x" .. owned), { Size = UDim2.new(1, -330, 0, 26), Position = UDim2.fromOffset(58, 6), TextSize = 18, AlignX = Enum.TextXAlignment.Left })
		local stats = food.mystery and "+40 hunger, ??? XP" or ("+" .. food.hunger .. " hunger, +" .. food.xp .. " XP")
		UI.label(row, stats .. "  •  " .. food.desc, { Size = UDim2.new(1, -330, 0, 26), Position = UDim2.fromOffset(58, 32), TextSize = 12, Font = UI.BodyFont, Color = C.sub, AlignX = Enum.TextXAlignment.Left })
		if locked then
			UI.label(row, "🔒 Age " .. food.minAge, { Size = UDim2.fromOffset(250, 62), Position = UDim2.new(1, -258, 0, 0), TextSize = 18, Color = C.sub })
		else
			local canFeed = food.free or owned > 0
			local feedButton = UI.button(row, "FEED", { Size = UDim2.fromOffset(110, 44), Position = UDim2.new(1, -252, 0, 9), Color = C.goo, TextSize = 18 }, function()
				if food.free or (State.data.food[food.id] or 0) > 0 then
					State.send("Care", "Feed", food.id)
				else
					State.toast("you're out of " .. food.name .. " - buy some!", "bad")
				end
			end)
			UI.setEnabled(feedButton, canFeed)
			if not food.free then
				UI.button(row, "BUY " .. food.price, { Size = UDim2.fromOffset(124, 44), Position = UDim2.new(1, -134, 0, 9), Color = C.gold, TextSize = 16 }, function()
					local result = State.invoke("Buy", "food", food.id, 1)
					if not result.ok then
						State.toast(result.reason or "could not buy that", "bad")
					end
				end)
			end
		end
	end
end

feed.onShow(refreshFeed)
State.on("food", refreshFeed)
State.on("meters", function(meters)
	if feed.visible then
		hungerBar.set(meters.hunger / 100, "Hunger " .. math.floor(meters.hunger + 0.5) .. " / 100")
	end
end)

-- silence "unused" for the shared helper (kept for future pose shortcuts)
local _ = InventorySystem
