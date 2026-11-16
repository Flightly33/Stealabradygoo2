--[[
	ShopUI
	Spend Goo Coins: clothing, hairstyles, food, furniture, decorations, toys,
	crates (with their odds shown) and the optional gamepasses.

	The shop only ASKS the server to buy something. Prices, age locks and
	the crate roll all happen in ShopServer.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = ReplicatedStorage:WaitForChild("Client")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local State = require(Client:WaitForChild("ClientState"))
local UI = require(Client:WaitForChild("UI"))
local ClothingSystem = require(Modules:WaitForChild("ClothingSystem"))
local FoodSystem = require(Modules:WaitForChild("FoodSystem"))
local FurnitureSystem = require(Modules:WaitForChild("FurnitureSystem"))
local Monetization = require(Modules:WaitForChild("Monetization"))
local ShopSystem = require(Modules:WaitForChild("ShopSystem"))
local Util = require(Modules:WaitForChild("Util"))

local gui = script.Parent
local C = UI.Colors
local localPlayer = Players.LocalPlayer

State.wait()

local window = UI.window(gui, { name = "Shop", title = "🛒 Shop", width = 850, height = 500 })
local body = window.body

local TABS = {
	{ id = "Clothing", text = "👕 Clothes" },
	{ id = "Food", text = "🍔 Food" },
	{ id = "Home", text = "🛋️ Home" },
	{ id = "Crates", text = "🎁 Crates" },
	{ id = "Passes", text = "💎 Passes" },
}

local current = "Clothing"
local selected = nil -- clothing item selected for the detail panel
local busy = false
local refresh

local tabs = UI.tabs(body, TABS, function(id)
	current = id
	selected = nil
	refresh()
end, { Width = 826, TextSize = 13 })

local list = UI.scroll(body, { Name = "List", Size = UDim2.new(1, 0, 1, -48), Position = UDim2.fromOffset(0, 46) })
local layout

-- Clothing detail / buy panel (only visible on the clothing + hair tabs)
local detail = UI.frame(body, { Name = "Detail", Size = UDim2.new(0, 240, 1, -48), Position = UDim2.new(1, -240, 0, 46), Color = C.panel, Corner = 14, Visible = false })
local detailName = UI.label(detail, "", { Name = "ItemName", Size = UDim2.new(1, -16, 0, 48), Position = UDim2.fromOffset(8, 10), TextSize = 19 })
local detailRarity = UI.label(detail, "", { Name = "Rarity", Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 60), TextSize = 17 })
local detailAge = UI.label(detail, "", { Name = "Age", Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 84), TextSize = 14, Font = UI.BodyFont, Color = C.sub })
local detailDesc = UI.label(detail, "", { Name = "Description", Size = UDim2.new(1, -24, 0, 110), Position = UDim2.fromOffset(12, 110), TextSize = 14, Font = UI.BodyFont, AlignY = Enum.TextYAlignment.Top })
local detailPrice = UI.label(detail, "", { Name = "Price", Size = UDim2.new(1, -16, 0, 26), Position = UDim2.new(0, 8, 1, -92), TextSize = 20, Color = C.gold })
local buyButton

local function request(kind, id, quantity)
	if busy then
		return
	end
	busy = true
	local result = State.invoke("Buy", kind, id, quantity)
	busy = false
	if result.ok then
		State.sound("coin")
	else
		State.toast(result.reason or "could not buy that", "bad")
	end
end

buyButton = UI.button(detail, "BUY", { Name = "Buy", Size = UDim2.new(1, -24, 0, 50), Position = UDim2.new(0, 12, 1, -62), TextSize = 24 }, function()
	if selected then
		request("clothing", selected.id)
	end
end)

local function showDetail()
	local item = selected
	if not item then
		detailName.Text = "tap a piece to see it"
		detailRarity.Text, detailAge.Text, detailDesc.Text, detailPrice.Text = "", "", "", ""
		buyButton.Visible = false
		return
	end
	local data = State.data
	detailName.Text = item.name
	detailRarity.Text = item.rarity
	detailRarity.TextColor3 = ClothingSystem.rarityColor(item.rarity)
	detailAge.Text = "Required Age: " .. item.age
	detailDesc.Text = "\"" .. item.desc .. "\""
	detailPrice.Text = Util.commas(item.price) .. " Goo Coins"
	buyButton.Visible = true
	if data.inventory[item.id] then
		buyButton.Text = "OWNED"
		UI.setEnabled(buyButton, false)
	elseif data.age < item.age then
		buyButton.Text = "🔒 AGE " .. item.age
		UI.setEnabled(buyButton, false)
	elseif data.coins < item.price then
		buyButton.Text = "NEED COINS"
		UI.setEnabled(buyButton, false)
	else
		buyButton.Text = "BUY"
		UI.setEnabled(buyButton, true)
	end
end

local function setLayout(kind)
	if layout then
		layout:Destroy()
	end
	if kind == "grid" then
		layout = UI.grid(list, 104, 122, 8)
	else
		layout = UI.list(list, { pad = 6 })
	end
end

local function showClothing(hair)
	setLayout("grid")
	list.Size = UDim2.new(1, -250, 1, -48)
	detail.Visible = true
	local data = State.data
	local items = {}
	for _, item in ipairs(ClothingSystem.List) do
		if item.price and (hair == nil or (item.slot == "Hair") == hair) then
			table.insert(items, item)
		end
	end
	-- cheapest first so there is always a "next thing to buy"
	table.sort(items, function(a, b)
		if a.age ~= b.age then
			return a.age < b.age
		end
		return a.price < b.price
	end)
	for index, item in ipairs(items) do
		local owned = data.inventory[item.id]
		UI.itemCard(list, item, {
			LayoutOrder = index,
			footer = owned and "OWNED" or (Util.short(item.price) .. " coins"),
			equipped = owned,
			locked = (not owned and data.age < item.age) and ("Age " .. item.age) or nil,
		}, function()
			selected = item
			showDetail()
		end)
	end
	showDetail()
end

local function shopRow(index, icon, title, subtitle, buttonText, enabled, callback)
	local row = UI.row(list, { Name = "Row" .. index, Size = UDim2.new(1, -12, 0, 62), LayoutOrder = index })
	UI.label(row, icon, { Size = UDim2.fromOffset(56, 62), TextSize = 34 })
	UI.label(row, title, { Name = "Title", Size = UDim2.new(1, -240, 0, 26), Position = UDim2.fromOffset(60, 6), TextSize = 18, AlignX = Enum.TextXAlignment.Left })
	UI.label(row, subtitle, { Name = "Sub", Size = UDim2.new(1, -240, 0, 26), Position = UDim2.fromOffset(60, 32), TextSize = 12, Font = UI.BodyFont, Color = C.sub, AlignX = Enum.TextXAlignment.Left })
	local button = UI.button(row, buttonText, { Name = "Buy", Size = UDim2.fromOffset(160, 44), Position = UDim2.new(1, -168, 0, 9), Color = C.gold, TextSize = 16 }, callback)
	UI.setEnabled(button, enabled, C.gold)
	return row
end

local function showFood()
	setLayout("list")
	local data = State.data
	local index = 0
	for _, food in ipairs(FoodSystem.List) do
		if not food.free then
			index += 1
			local locked = data.age < (food.minAge or 1)
			local stats = food.mystery and "+40 hunger, 5 to 120 XP" or ("+" .. food.hunger .. " hunger, +" .. food.xp .. " XP")
			shopRow(index, food.icon, food.name .. "   (you have " .. (data.food[food.id] or 0) .. ")", stats .. "  •  " .. food.desc,
				locked and ("🔒 Age " .. food.minAge) or (food.price .. " coins"), not locked, function()
					request("food", food.id, 1)
				end)
		end
	end
end

local FURNITURE_ICONS = { Furniture = "🛋️", Decor = "🪴", Toys = "🧸" }
local function iconFor(def)
	return FURNITURE_ICONS[def.category]
end

local function showFurniture(category)
	setLayout("list")
	local data = State.data
	local index = 0
	for _, def in ipairs(FurnitureSystem.List) do
		if (category == nil or def.category == category) and def.price then
			index += 1
			local locked = data.age < (def.minAge or 1)
			local needsPass = def.vip and not State.hasPass("VIPDecor")
			local label = Util.short(def.price) .. " coins"
			if needsPass then
				label = "💎 VIP pass"
			elseif locked then
				label = "🔒 Age " .. def.minAge
			end
			local owned = data.furniture.owned[def.id] or 0
			shopRow(index, def.vip and "💎" or iconFor(def), def.name .. "   (owned " .. owned .. ")", string.format("%dx%d studs  •  %s", def.w, def.d, def.desc),
				label, not locked and not needsPass, function()
					request("furniture", def.id)
				end)
		end
	end
end

----------------------------------------------------------------------
-- Crates
----------------------------------------------------------------------
local reveal = UI.frame(gui, { Name = "CrateReveal", Color = C.dark, Transparency = 0.3, Corner = false, Visible = false, ZIndex = 40 })
reveal.Active = true
local revealCard = UI.frame(reveal, { Name = "Card", Size = UDim2.fromOffset(420, 300), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = C.bg, Corner = 24, ZIndex = 41 })
UI.autoScale(revealCard, "window")
local revealStroke = UI.stroke(revealCard, 6, C.sub)
local revealIcon = UI.label(revealCard, "🎁", { Name = "Icon", Size = UDim2.new(1, 0, 0, 110), Position = UDim2.fromOffset(0, 14), TextSize = 90, ZIndex = 42 })
local revealName = UI.label(revealCard, "", { Name = "ItemName", Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 128), TextSize = 26, Outline = 3, ZIndex = 42 })
local revealRarity = UI.label(revealCard, "", { Name = "Rarity", Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 180), TextSize = 24, Outline = 3, ZIndex = 42 })
local revealNote = UI.label(revealCard, "", { Name = "Note", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 214), TextSize = 16, Font = UI.BodyFont, Color = C.sub, ZIndex = 42 })
local revealClose = UI.button(revealCard, "NICE", { Name = "Close", Size = UDim2.fromOffset(180, 44), Position = UDim2.new(0.5, -90, 1, -54), TextSize = 22, ZIndex = 42 }, function()
	reveal.Visible = false
end)

local function openCrate(crate)
	if busy then
		return
	end
	busy = true
	local result = State.invoke("OpenCrate", crate.id)
	if not result.ok then
		busy = false
		State.toast(result.reason or "could not open that", "bad")
		return
	end
	local item = ClothingSystem.get(result.itemId)
	reveal.Visible = true
	revealClose.Visible = false
	revealNote.Text = ""
	revealRarity.Text = ""
	revealIcon.Text = crate.icon
	revealStroke.Color = C.sub
	-- shuffle through random pieces before landing on the real one
	local pool = ClothingSystem.List
	for step = 1, 14 do
		local fake = pool[math.random(1, #pool)]
		revealName.Text = fake.name
		revealName.TextColor3 = ClothingSystem.rarityColor(fake.rarity)
		State.sound("crate")
		task.wait(0.05 + step * 0.012)
	end
	local color = ClothingSystem.rarityColor(item.rarity)
	revealIcon.Text = ClothingSystem.SlotInfo[item.slot].icon
	revealName.Text = item.name
	revealName.TextColor3 = color
	revealRarity.Text = string.upper(item.rarity)
	revealRarity.TextColor3 = color
	revealStroke.Color = color
	revealNote.Text = result.isNew and "NEW!  added to your inventory" or ("duplicate  ->  +" .. tostring(result.refund) .. " Goo Coins")
	UI.pop(revealCard, 0.8)
	revealClose.Visible = true
	busy = false
	-- the HUD plays "ARCHIVE ITEM FOUND!" / "GRAIL FOUND!" etc.
	State.announce({ item = item.id, isNew = result.isNew, refund = result.refund })
end

local function showCrates()
	setLayout("list")
	local data = State.data
	for index, crate in ipairs(ShopSystem.Crates) do
		local locked = data.age < crate.minAge
		local row = UI.row(list, { Name = "Crate_" .. crate.id, Size = UDim2.new(1, -12, 0, 92), LayoutOrder = index, StrokeColor = crate.color })
		UI.label(row, crate.icon, { Size = UDim2.fromOffset(70, 92), TextSize = 46 })
		UI.label(row, crate.name, { Size = UDim2.new(1, -260, 0, 26), Position = UDim2.fromOffset(74, 6), TextSize = 20, Color = crate.color, AlignX = Enum.TextXAlignment.Left })
		UI.label(row, crate.desc, { Size = UDim2.new(1, -260, 0, 20), Position = UDim2.fromOffset(74, 32), TextSize = 12, Font = UI.BodyFont, Color = C.sub, AlignX = Enum.TextXAlignment.Left })
		-- Odds are always shown, even though crates only cost earnable coins.
		local odds = UI.box(row, { Name = "Odds", Size = UDim2.new(1, -260, 0, 30), Position = UDim2.fromOffset(74, 56) })
		UI.list(odds, { horizontal = true, pad = 8, alignY = Enum.VerticalAlignment.Center })
		for order, entry in ipairs(ShopSystem.oddsList(crate)) do
			local text = string.format(entry.percent < 1 and "%s %.1f%%" or "%s %.0f%%", entry.rarity, entry.percent)
			UI.label(odds, text, { Size = UDim2.fromOffset(#text * 7 + 6, 26), TextSize = 12, Font = UI.BodyFont, Color = ClothingSystem.rarityColor(entry.rarity), LayoutOrder = order, Wrapped = false })
		end
		local button = UI.button(row, locked and ("🔒 Age " .. crate.minAge) or ("OPEN\n" .. Util.commas(crate.price)), { Name = "Open", Size = UDim2.fromOffset(160, 64), Position = UDim2.new(1, -170, 0, 14), Color = crate.color, TextSize = 18 }, function()
			if not locked then
				task.spawn(openCrate, crate)
			end
		end)
		UI.setEnabled(button, not locked and data.coins >= crate.price, crate.color)
	end
end

----------------------------------------------------------------------
-- Passes (optional, cosmetic / convenience only)
----------------------------------------------------------------------
local function showPasses()
	setLayout("list")
	UI.label(list, "Every pass is optional. None of them sell Goo Coins, XP or clothing - you can finish the whole game for free.", { Size = UDim2.new(1, -12, 0, 36), TextSize = 13, Font = UI.BodyFont, Color = C.sub, LayoutOrder = 0 })
	for index, pass in ipairs(Monetization.Passes) do
		local owned = State.hasPass(pass.key)
		shopRow(index, pass.icon, pass.name, pass.desc, owned and "OWNED" or (pass.id > 0 and "BUY" or "coming soon"), not owned and pass.id > 0, function()
			if owned then
				return
			end
			if pass.id > 0 then
				MarketplaceService:PromptGamePassPurchase(localPlayer, pass.id)
			else
				State.toast("that pass isn't on sale yet", "info")
			end
		end)
	end
end

function refresh()
	if not window.visible then
		return
	end
	UI.clear(list)
	detail.Visible = false
	list.Size = UDim2.new(1, 0, 1, -48)
	if current == "Clothing" then
		showClothing(nil) -- clothes and hairstyles together
	elseif current == "Food" then
		showFood()
	elseif current == "Crates" then
		showCrates()
	elseif current == "Passes" then
		showPasses()
	else
		showFurniture(nil) -- furniture, decor and toys together
	end
end

window.onShow(function(arg)
	local ALIAS = { Hair = "Clothing", Furniture = "Home", Decor = "Home", Toys = "Home" }
	arg = ALIAS[arg] or arg
	if type(arg) == "string" and tabs.buttons[arg] then
		current = arg
		selected = nil
	end
	tabs.select(current, true)
	refresh()
end)
State.on("inventory", refresh)
State.on("furniture", refresh)
State.on("food", refresh)
State.on("age", refresh)
State.onSession("passes", refresh)
-- coins change constantly: only the buy buttons need to react
State.on("coins", function()
	if window.visible and current == "Clothing" then
		showDetail()
	elseif window.visible and current == "Crates" and not busy then
		refresh()
	end
end)
