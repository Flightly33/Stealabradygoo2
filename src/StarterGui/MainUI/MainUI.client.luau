--[[
	MainUI
	The always-on HUD:
	  * Goo Coins + Brady's four meters at the top of the screen
	  * the eight big menu buttons
	  * centre-screen announcements ("BRADY AGED UP!", "ARCHIVE ITEM FOUND!")
	  * small toasts and floating reward text
	  * the random-event banner and the fashion show ticker

	It never decides anything: every number shown comes from ClientState,
	which is a copy of what the server sent.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Client = ReplicatedStorage:WaitForChild("Client")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local State = require(Client:WaitForChild("ClientState"))
local UI = require(Client:WaitForChild("UI"))
local ClothingSystem = require(Modules:WaitForChild("ClothingSystem"))
local FurnitureSystem = require(Modules:WaitForChild("FurnitureSystem"))
local Util = require(Modules:WaitForChild("Util"))

local gui = script.Parent
local C = UI.Colors

local data = State.wait()

----------------------------------------------------------------------
-- TOP: coins + meters
----------------------------------------------------------------------
local top = UI.box(gui, { Name = "Top", Size = UDim2.fromOffset(560, 46), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0) })
UI.autoScale(top, "hud")

local coinPill = UI.frame(top, { Name = "Coins", Size = UDim2.fromOffset(190, 44), Color = C.bg, Corner = 22, Stroke = 3, StrokeColor = C.goo })
local coinIcon = UI.frame(coinPill, { Name = "Icon", Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(5, 5), Color = C.goo, Corner = 17 })
UI.stroke(coinIcon, 2, C.gooDark)
UI.label(coinIcon, "G", { TextSize = 22, Color = C.dark })
local coinLabel = UI.label(coinPill, "0", { Name = "Amount", Size = UDim2.new(1, -52, 1, 0), Position = UDim2.fromOffset(46, 0), TextSize = 24, AlignX = Enum.TextXAlignment.Left, Outline = 2 })

local shownCoins = data.coins
State.on("coins", function(coins)
	local from = shownCoins
	shownCoins = coins
	if coins > from then
		State.sound("coin")
		UI.pop(coinPill, 1.12)
	end
	-- quick count-up so gains feel good
	task.spawn(function()
		for step = 1, 8 do
			if shownCoins ~= coins then
				return
			end
			coinLabel.Text = Util.short(from + (coins - from) * step / 8)
			task.wait(0.03)
		end
		coinLabel.Text = Util.short(coins)
	end)
end)

local METERS = {
	{ key = "hunger", icon = "🍔", color = C.gold },
	{ key = "clean", icon = "🫧", color = C.blue },
	{ key = "energy", icon = "⚡", color = C.goo },
	{ key = "fun", icon = "🎮", color = C.pink },
}
local meterBars = {}
for index, meter in ipairs(METERS) do
	local chip = UI.new("TextButton", {
		Name = "Meter_" .. meter.key,
		Size = UDim2.fromOffset(84, 44),
		Position = UDim2.fromOffset(198 + (index - 1) * 90, 0),
		BackgroundColor3 = C.bg,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Parent = top,
	})
	UI.corner(chip, 14)
	UI.stroke(chip, 3, C.dark)
	UI.label(chip, meter.icon, { Size = UDim2.fromOffset(30, 44), Position = UDim2.fromOffset(2, 0), TextSize = 22 })
	local bar = UI.bar(chip, { Size = UDim2.fromOffset(44, 16), Position = UDim2.fromOffset(34, 14), Color = meter.color, Corner = 6, TextSize = 11 })
	meterBars[meter.key] = bar
	chip.Activated:Connect(function()
		State.sound("click")
		State.toggle("Brady")
	end)
end

State.on("meters", function(meters)
	for _, meter in ipairs(METERS) do
		local value = meters[meter.key]
		meterBars[meter.key].set(value / 100, tostring(math.floor(value + 0.5)), value < 20 and C.red or meter.color)
	end
end)

----------------------------------------------------------------------
-- MAIN BUTTONS
----------------------------------------------------------------------
local BUTTONS = {
	{ panel = "Brady", icon = "🧒", text = "Brady", color = C.goo },
	{ panel = "Wardrobe", icon = "👕", text = "Wardrobe", color = C.pink },
	{ panel = "Inventory", icon = "🎒", text = "Inventory", color = C.blue },
	{ panel = "Shop", icon = "🛒", text = "Shop", color = C.gold },
	{ panel = "Room", icon = "🏠", text = "Room", color = C.purple },
	{ panel = "Collection", icon = "📖", text = "Collection", color = C.red },
	{ panel = "Fashion", icon = "🌟", text = "Fashion Show", color = C.pink },
	{ panel = "Settings", icon = "⚙️", text = "Settings", color = C.sub },
}

local menu = UI.box(gui, { Name = "Menu", Size = UDim2.fromOffset(158, 316), Position = UDim2.new(0, 8, 0.5, 10), AnchorPoint = Vector2.new(0, 0.5) })
UI.autoScale(menu, "hud")
UI.grid(menu, 74, 74, 5)
local menuButtons = {}
for index, def in ipairs(BUTTONS) do
	local button = UI.button(menu, "", { Name = def.panel, Size = UDim2.fromOffset(74, 74), Color = def.color, LayoutOrder = index, Corner = 16 }, function()
		State.toggle(def.panel)
	end)
	UI.label(button, def.icon, { Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 4), TextSize = 32 })
	UI.label(button, def.text, { Size = UDim2.new(1, -4, 0, 24), Position = UDim2.new(0, 2, 1, -26), TextSize = 12, Color = C.dark })
	menuButtons[def.panel] = button
end

-- A red dot on a menu button when something is waiting there.
local function setBadge(panel, visible)
	local button = menuButtons[panel]
	local badge = button:FindFirstChild("Badge")
	if visible and not badge then
		badge = UI.frame(button, { Name = "Badge", Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -2, 0, 2), AnchorPoint = Vector2.new(1, 0), Color = C.red, Corner = 10, ZIndex = 5 })
		UI.stroke(badge, 2, C.dark)
		UI.label(badge, "!", { TextSize = 14, ZIndex = 6 })
	elseif not visible and badge then
		badge:Destroy()
	end
end

----------------------------------------------------------------------
-- CENTRE ANNOUNCEMENTS
----------------------------------------------------------------------
local KIND_COLORS = {
	good = C.goo,
	bad = C.red,
	rare = C.blue,
	archive = ClothingSystem.rarityColor("Archive"),
	grail = ClothingSystem.rarityColor("Grail"),
	event = C.gold,
	info = C.text,
	legendary = ClothingSystem.rarityColor("Legendary"),
}

local center = UI.box(gui, { Name = "Announcements", Size = UDim2.fromOffset(900, 150), Position = UDim2.fromScale(0.5, 0.26), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 20 })
UI.autoScale(center, "hud")
local bigText = UI.label(center, "", { Name = "Big", Size = UDim2.new(1, 0, 0, 84), Font = UI.LoudFont, TextSize = 60, Outline = 5, ZIndex = 21 })
local subText = UI.label(center, "", { Name = "Sub", Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 88), Font = UI.BodyFont, TextSize = 24, Outline = 3, ZIndex = 21 })
bigText.Visible, subText.Visible = false, false

local queue = {}
local showing = false

local function showNext()
	if showing then
		return
	end
	local payload = table.remove(queue, 1)
	if not payload then
		return
	end
	showing = true
	bigText.Text = payload.text or ""
	bigText.TextColor3 = KIND_COLORS[payload.kind] or C.text
	bigText.TextSize = payload.big and 68 or 54
	subText.Text = payload.sub or ""
	bigText.Visible, subText.Visible = true, true
	bigText.TextTransparency, subText.TextTransparency = 0, 0
	UI.pop(center, 0.4)
	State.sound(payload.sound or "notify")
	task.delay(payload.big and 3.2 or 2.4, function()
		UI.tween(bigText, 0.3, { TextTransparency = 1 })
		UI.tween(subText, 0.3, { TextTransparency = 1 })
		task.wait(0.32)
		bigText.Visible, subText.Visible = false, false
		showing = false
		showNext()
	end)
end

local function announce(payload)
	if #queue >= 6 then
		table.remove(queue, 1) -- never let a backlog build up
	end
	table.insert(queue, payload)
	showNext()
end

----------------------------------------------------------------------
-- TOASTS + floating reward text
----------------------------------------------------------------------
local toasts = UI.box(gui, { Name = "Toasts", Size = UDim2.fromOffset(600, 150), Position = UDim2.new(0.5, 0, 1, -110), AnchorPoint = Vector2.new(0.5, 1) })
UI.autoScale(toasts, "hud")
UI.list(toasts, { pad = 6, alignX = Enum.HorizontalAlignment.Center, alignY = Enum.VerticalAlignment.Bottom })
local toastOrder = 0

local function toast(text, kind)
	toastOrder += 1
	local existing = {}
	for _, child in ipairs(toasts:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(existing, child)
		end
	end
	if #existing >= 3 then
		table.sort(existing, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		existing[1]:Destroy()
	end
	local pill = UI.frame(toasts, { Name = "Toast", Size = UDim2.fromOffset(math.clamp(#text * 11 + 50, 220, 600), 40), Color = C.bg, Corner = 20, Stroke = 3, StrokeColor = KIND_COLORS[kind] or C.sub, LayoutOrder = toastOrder })
	UI.label(pill, text, { TextSize = 17, Font = UI.BodyFont, Color = KIND_COLORS[kind] or C.text })
	UI.pop(pill, 0.8)
	if kind == "bad" then
		State.sound("error")
	end
	task.delay(2.6, function()
		if pill.Parent then
			pill:Destroy()
		end
	end)
end

local rewards = UI.box(gui, { Name = "Rewards", Size = UDim2.fromOffset(500, 60), Position = UDim2.fromScale(0.5, 0.62), AnchorPoint = Vector2.new(0.5, 0.5) })
UI.autoScale(rewards, "hud")

local function floatReward(payload)
	local parts = {}
	if payload.text then
		table.insert(parts, payload.text)
	end
	if payload.xp and payload.xp > 0 then
		table.insert(parts, "+" .. payload.xp .. " XP")
	end
	if payload.coins and payload.coins > 0 then
		table.insert(parts, "+" .. payload.coins .. " coins")
	end
	if #parts == 0 then
		return
	end
	local label = UI.label(rewards, table.concat(parts, "   "), { Name = "Reward", TextSize = 30, Color = C.goo, Outline = 4 })
	label.Position = UDim2.fromOffset(math.random(-40, 40), 0)
	UI.tween(label, 1.3, { Position = UDim2.fromOffset(label.Position.X.Offset, -90), TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(1.35, function()
		label:Destroy()
	end)
end

-- Turns an item grant into the right announcement.
local function announceItem(payload)
	if payload.kind == "furniture" then
		local def = FurnitureSystem.get(payload.id)
		toast("New room item: " .. (def and def.name or payload.id), "good")
		return
	end
	local item = ClothingSystem.get(payload.id or payload.item)
	if not item then
		return
	end
	if payload.isNew == false then
		toast("Duplicate " .. item.name .. "  ->  +" .. tostring(payload.refund or 0) .. " Goo Coins", "info")
		return
	end
	local sub = item.name .. "  •  " .. item.rarity
	if item.rarity == "Grail" then
		announce({ text = "GRAIL FOUND!", sub = sub, kind = "grail", sound = "grail", big = true })
	elseif item.rarity == "Archive" then
		announce({ text = "ARCHIVE ITEM FOUND!", sub = sub, kind = "archive", sound = "rare", big = true })
	elseif item.rarity == "Legendary" then
		announce({ text = "LEGENDARY PIECE!", sub = sub, kind = "legendary", sound = "rare" })
	else
		announce({ text = "NEW FIT UNLOCKED!", sub = sub, kind = "good", sound = "item" })
	end
end

State.notified:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.item then
		announceItem(payload)
	elseif payload.toast then
		toast(tostring(payload.text or ""), payload.kind)
	else
		announce(payload)
	end
end)

State.listen("ItemGranted", announceItem)
State.listen("Effect", function(kind, payload)
	if kind == "Reward" and type(payload) == "table" then
		floatReward(payload)
	elseif kind == "Sound" and type(payload) == "table" then
		State.sound(payload.name)
	end
end)

----------------------------------------------------------------------
-- STATUS STRIP: fashion show ticker + random event banner + obby timer
----------------------------------------------------------------------
local strip = UI.box(gui, { Name = "Status", Size = UDim2.fromOffset(560, 190), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0) })
UI.autoScale(strip, "hud")

local ticker = UI.button(strip, "", { Name = "FashionTicker", Size = UDim2.fromOffset(360, 30), Position = UDim2.fromOffset(100, 100), Color = C.bg, TextColor = C.text, TextSize = 15, Corner = 15, Font = UI.BodyFont }, function()
	State.open("Fashion")
end)

local banner = UI.frame(strip, { Name = "EventBanner", Size = UDim2.fromOffset(560, 100), Position = UDim2.fromOffset(0, 136), Color = C.bg, Corner = 16, Stroke = 4, StrokeColor = C.gold, Visible = false })
local bannerTitle = UI.label(banner, "", { Name = "Title", Size = UDim2.new(1, -150, 0, 30), Position = UDim2.fromOffset(12, 6), TextSize = 22, Color = C.gold, AlignX = Enum.TextXAlignment.Left, Outline = 2 })
local bannerDesc = UI.label(banner, "", { Name = "Desc", Size = UDim2.new(1, -150, 0, 36), Position = UDim2.fromOffset(12, 36), TextSize = 14, Font = UI.BodyFont, Color = C.sub, AlignX = Enum.TextXAlignment.Left })
local bannerTimer = UI.bar(banner, { Name = "Timer", Size = UDim2.new(1, -24, 0, 14), Position = UDim2.new(0, 12, 1, -22), Color = C.gold, Corner = 6, TextSize = 11 })
local bannerButtons = UI.box(banner, { Name = "Buttons", Size = UDim2.fromOffset(134, 62), Position = UDim2.new(1, -142, 0, 8) })
UI.list(bannerButtons, { pad = 4 })

local eventTotal = 60

local function eventButton(text, color, callback)
	return UI.button(bannerButtons, text, { Size = UDim2.fromOffset(134, 29), TextSize = 15, Color = color or C.goo, Corner = 10 }, callback)
end

local function refreshEvent(event)
	UI.clear(bannerButtons)
	if not event then
		banner.Visible = false
		return
	end
	local wasVisible = banner.Visible
	banner.Visible = true
	bannerTitle.Text = event.title
	bannerDesc.Text = event.desc
	eventTotal = math.max(1, event.endsAt - Workspace:GetServerTimeNow())
	if not wasVisible then
		UI.pop(banner, 0.8)
	end
	if event.task == "hype" then
		local button = eventButton("HYPE! " .. event.progress .. "/" .. event.goal, C.pink, function(self)
			UI.pop(self, 1.15)
			State.sound("hype")
			State.send("EventAction", "Hype")
		end)
		button.Size = UDim2.fromOffset(134, 60)
		button.TextSize = 20
	elseif event.task == "haircut" and not event.choice then
		eventButton("KEEP IT", C.goo, function()
			State.send("EventAction", "Keep")
		end)
		eventButton("FIX IT", C.red, function()
			State.send("EventAction", "Fix")
		end)
	elseif event.task == "haircut" then
		eventButton("Brush Hair", C.blue, function()
			State.send("Care", "BrushHair")
		end)
	elseif event.task == "changeFit" then
		eventButton("Wardrobe (" .. event.progress .. "/" .. event.goal .. ")", C.pink, function()
			State.open("Wardrobe")
		end).Size = UDim2.fromOffset(134, 60)
	elseif event.task == "feed" then
		eventButton("Feed him!", C.gold, function()
			State.open("Feed")
		end).Size = UDim2.fromOffset(134, 60)
	elseif event.task == "goPark" then
		eventButton("Where's the park?", C.goo, function()
			State.toast("the park is north-east of the plaza - follow the signs!", "info")
		end).Size = UDim2.fromOffset(134, 60)
	else
		eventButton("Go Home", C.goo, function()
			State.send("Visit", "Home")
		end).Size = UDim2.fromOffset(134, 60)
	end
end
State.eventChanged:Connect(refreshEvent)

-- Obby timer pill
local obbyPill = UI.frame(strip, { Name = "Obby", Size = UDim2.fromOffset(220, 34), Position = UDim2.fromOffset(170, 100), Color = C.goo, Corner = 17, Stroke = 3, Visible = false })
local obbyLabel = UI.label(obbyPill, "", { TextSize = 18, Color = C.dark })
local obbyStart

State.listen("ObbyState", function(state)
	if state.running then
		if state.startedAt then
			obbyStart = state.startedAt
		end
		obbyPill.Visible = true
		ticker.Visible = false
		if state.checkpoint then
			toast("Checkpoint " .. state.checkpoint .. "/" .. (state.total or 2) .. "!", "good")
			State.sound("good")
		end
	else
		obbyPill.Visible = false
		ticker.Visible = true
		obbyStart = nil
		if state.result then
			announce({ text = "OBBY COMPLETE!", sub = string.format("%.1fs   +%d Goo Coins   +%d XP", state.result.time, state.result.coins, state.result.xp), kind = "good", sound = "rare" })
		elseif state.timeout then
			toast("obby timed out - step on START to try again", "bad")
		end
	end
end)

local function fashionText(state, now)
	if not state then
		return "🌟 Fashion Show"
	end
	local remaining = Util.clock(math.max(0, (state.endsAt or 0) - now))
	if state.phase == "Signup" then
		return "🌟 SIGN-UPS OPEN • " .. state.category.name .. " • " .. remaining .. " • tap to enter"
	elseif state.phase == "Runway" then
		local current = state.contestants[state.current]
		return "🌟 On the runway: " .. (current and current.name or "...")
	elseif state.phase == "Voting" then
		return "🗳️ VOTE NOW • " .. state.category.name .. " • " .. remaining
	elseif state.phase == "Results" then
		local winner = state.results and state.results[1]
		return "🏆 Winner: " .. (winner and winner.name or "?")
	end
	return "🌟 Next fashion show in " .. Util.clock(math.max(0, (state.nextAt or 0) - now))
end

State.fashionChanged:Connect(function(state)
	local live = state.phase == "Signup" or state.phase == "Voting"
	ticker.BackgroundColor3 = live and C.gold or C.bg
	ticker.TextColor3 = live and C.dark or C.text
	setBadge("Fashion", live)
	if state.phase == "Voting" then
		State.open("Fashion")
	end
end)

-- One light loop drives every on-screen countdown.
task.spawn(function()
	while true do
		local now = Workspace:GetServerTimeNow()
		ticker.Text = fashionText(State.fashion, now)
		local event = State.event
		if event and banner.Visible then
			local remaining = math.max(0, event.endsAt - now)
			bannerTimer.set(remaining / eventTotal, Util.clock(remaining), remaining < 10 and C.red or C.gold)
		end
		if obbyStart then
			obbyLabel.Text = string.format("🏃 %.1fs", now - obbyStart)
		end
		task.wait(obbyStart and 0.1 or 0.5)
	end
end)

----------------------------------------------------------------------
-- Badges: things waiting for the player
----------------------------------------------------------------------
local DailySystem = require(Modules:WaitForChild("DailySystem"))

local function refreshBadges()
	local daily = State.data.daily
	local today = State.session.day or 0
	local waiting = DailySystem.canClaim(daily, today)
	for _, task_ in ipairs(daily.tasks) do
		local def = DailySystem.TaskById[task_.id]
		if def and not task_.claimed and task_.progress >= def.goal then
			waiting = true
		end
	end
	setBadge("Collection", waiting)
end
State.on("daily", refreshBadges)
State.onSession("day", refreshBadges)

State.on("meters", function(meters)
	setBadge("Brady", meters.hunger < 20 or meters.clean < 20 or meters.energy < 20 or meters.fun < 20)
end)
