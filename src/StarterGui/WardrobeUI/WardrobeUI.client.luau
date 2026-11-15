--[[
	WardrobeUI
	Dress Brady with a live 3D preview.
	  * "Brady's Fit" - one row per clothing slot; tap a slot to pick a piece
	  * saved outfit slots (3 free, 8 with the optional gamepass)
	  * "My Style" - the wearable gifts Brady has given the PLAYER's avatar

	The preview is built locally with BradyBuilder from the server's data, so
	it always matches the real Brady everyone else sees.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = ReplicatedStorage:WaitForChild("Client")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local State = require(Client:WaitForChild("ClientState"))
local UI = require(Client:WaitForChild("UI"))
local Preview = require(Client:WaitForChild("Preview"))
local AgeSystem = require(Modules:WaitForChild("AgeSystem"))
local ClothingSystem = require(Modules:WaitForChild("ClothingSystem"))
local Config = require(Modules:WaitForChild("Config"))
local GiftSystem = require(Modules:WaitForChild("GiftSystem"))
local InventorySystem = require(Modules:WaitForChild("InventorySystem"))

local gui = script.Parent
local C = UI.Colors

State.wait()

local window = UI.window(gui, { name = "Wardrobe", title = "👕 Wardrobe", width = 850, height = 500 })
local body = window.body

----------------------------------------------------------------------
-- LEFT: preview + outfits
----------------------------------------------------------------------
local left = UI.box(body, { Name = "Left", Size = UDim2.new(0, 250, 1, 0) })
local preview = Preview.new(left, { Size = UDim2.new(1, 0, 0, 236) })
local dripLabel = UI.label(left, "", { Name = "Drip", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 240), TextSize = 17, Color = C.gold, Outline = 2 })
UI.label(left, "SAVED OUTFITS", { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 268), TextSize = 13, Color = C.sub })
local outfitList = UI.scroll(left, { Name = "Outfits", Size = UDim2.new(1, 0, 1, -290), Position = UDim2.fromOffset(0, 288) })
UI.list(outfitList, { pad = 4 })

local function refreshOutfits()
	UI.clear(outfitList)
	local slots = State.hasPass("ExtraOutfits") and Config.OutfitSlotsWithPass or Config.OutfitSlots
	for index = 1, slots do
		local saved = State.data.outfits[tostring(index)]
		local row = UI.box(outfitList, { Name = "Outfit" .. index, Size = UDim2.new(1, -10, 0, 34), LayoutOrder = index })
		local wear = UI.button(row, saved and ("Wear #" .. index) or ("#" .. index .. " empty"), { Size = UDim2.new(0.58, -3, 1, 0), Color = C.goo, TextSize = 15, Corner = 10 }, function()
			if State.data.outfits[tostring(index)] then
				State.send("LoadOutfit", index)
			else
				State.toast("save an outfit in this slot first", "bad")
			end
		end)
		UI.setEnabled(wear, saved ~= nil)
		UI.button(row, "Save", { Size = UDim2.new(0.42, -3, 1, 0), Position = UDim2.new(0.58, 3, 0, 0), Color = C.blue, TextColor = C.text, TextSize = 15, Corner = 10 }, function()
			State.send("SaveOutfit", index)
		end)
	end
	if slots == Config.OutfitSlots then
		UI.label(outfitList, "+5 slots with the Extra Outfit Slots pass", { Size = UDim2.new(1, -10, 0, 30), TextSize = 11, Font = UI.BodyFont, Color = C.sub, LayoutOrder = 99 })
	end
end

----------------------------------------------------------------------
-- RIGHT: tabs
----------------------------------------------------------------------
local right = UI.box(body, { Name = "Right", Size = UDim2.new(1, -262, 1, 0), Position = UDim2.fromOffset(262, 0) })
local mode = "Fit" -- "Fit" | "Style"
local pickingSlot = nil
local refresh

local tabs = UI.tabs(right, { { id = "Fit", text = "🧒 Brady's Fit" }, { id = "Style", text = "🧍 My Style (gifts)" } }, function(id)
	mode = id
	pickingSlot = nil
	refresh()
end, { Width = 560, TextSize = 15 })

local content = UI.scroll(right, { Name = "Content", Size = UDim2.new(1, 0, 1, -48), Position = UDim2.fromOffset(0, 46) })
local contentLayout

local function setLayout(kind)
	if contentLayout then
		contentLayout:Destroy()
	end
	if kind == "grid" then
		contentLayout = UI.grid(content, 104, 122, 8)
	else
		contentLayout = UI.list(content, { pad = 5 })
	end
end

-- Slot overview: one row per clothing slot.
local function showSlots()
	setLayout("list")
	local data = State.data
	for index, slot in ipairs(ClothingSystem.Slots) do
		local info = ClothingSystem.SlotInfo[slot]
		local item = data.equipped[slot] and ClothingSystem.get(data.equipped[slot])
		local unlocked = AgeSystem.isSlotUnlocked(slot, data.age)
		local row = UI.row(content, { Name = "Slot_" .. slot, Size = UDim2.new(1, -12, 0, 42), LayoutOrder = index, StrokeColor = item and ClothingSystem.rarityColor(item.rarity) or nil })
		UI.label(row, info.icon, { Size = UDim2.fromOffset(40, 42), TextSize = 24 })
		UI.label(row, info.plural, { Size = UDim2.fromOffset(110, 42), Position = UDim2.fromOffset(42, 0), TextSize = 15, AlignX = Enum.TextXAlignment.Left })
		local text, color = "nothing", C.sub
		if not unlocked then
			text = "🔒 unlocks at age " .. AgeSystem.slotUnlockAge(slot)
		elseif item then
			text, color = item.name, ClothingSystem.rarityColor(item.rarity)
		elseif slot == "Hair" then
			text = "stage default"
		end
		UI.label(row, text, { Size = UDim2.new(1, -330, 1, 0), Position = UDim2.fromOffset(152, 0), TextSize = 14, Font = UI.BodyFont, Color = color, AlignX = Enum.TextXAlignment.Left })
		if unlocked then
			UI.button(row, "Change", { Name = "Change", Size = UDim2.fromOffset(100, 32), Position = UDim2.new(1, -150, 0, 5), Color = C.pink, TextSize = 15, Corner = 10 }, function()
				pickingSlot = slot
				refresh()
			end)
			if item then
				UI.button(row, "X", { Name = "Remove", Size = UDim2.fromOffset(36, 32), Position = UDim2.new(1, -44, 0, 5), Color = C.red, TextColor = C.text, TextSize = 16, Corner = 10 }, function()
					State.send("Unequip", slot)
				end)
			end
		end
	end
end

-- Picker: every owned piece for one slot.
local function showPicker(slot)
	setLayout("grid")
	local data = State.data
	local back = UI.button(content, "< Back", { Name = "Back", Size = UDim2.fromOffset(104, 122), Color = C.panel2, TextColor = C.text, TextSize = 18, LayoutOrder = 0 }, function()
		pickingSlot = nil
		refresh()
	end)
	back.Name = "Back"
	local items = InventorySystem.ownedItems(data, slot)
	for index, item in ipairs(items) do
		local ok, reason = InventorySystem.canEquip(data, item.id)
		UI.itemCard(content, item, {
			LayoutOrder = index,
			equipped = data.equipped[slot] == item.id,
			locked = not ok and ("Age " .. item.age) or nil,
		}, function()
			if not ok then
				State.toast(reason, "bad")
			elseif State.data.equipped[slot] == item.id then
				State.send("Unequip", slot)
			else
				State.send("Equip", item.id)
			end
		end)
	end
	if #items == 0 then
		UI.label(content, "no " .. ClothingSystem.SlotInfo[slot].plural .. " yet - check the Shop!", { Size = UDim2.fromOffset(104, 122), TextSize = 13, Font = UI.BodyFont, Color = C.sub, LayoutOrder = 1 })
	end
end

-- Gifts for the player's own avatar.
local function showGifts()
	setLayout("list")
	local data = State.data
	for index, gift in ipairs(GiftSystem.List) do
		local owned = data.gifts.owned[gift.id] == true
		local equipped = data.gifts.equipped[gift.slot] == gift.id
		local row = UI.row(content, { Name = "Gift_" .. gift.id, Size = UDim2.new(1, -12, 0, 56), LayoutOrder = index, StrokeColor = equipped and C.goo or nil })
		local swatch = UI.frame(row, { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(6, 6), Color = gift.color, Corner = 10 })
		UI.label(swatch, owned and "🎁" or "🔒", { TextSize = 24 })
		UI.label(row, gift.name .. "  (" .. gift.slot .. ")", { Size = UDim2.new(1, -200, 0, 24), Position = UDim2.fromOffset(58, 5), TextSize = 16, AlignX = Enum.TextXAlignment.Left })
		UI.label(row, owned and gift.desc or ("Brady gifts you this when he turns " .. gift.age), { Size = UDim2.new(1, -200, 0, 22), Position = UDim2.fromOffset(58, 29), TextSize = 12, Font = UI.BodyFont, Color = C.sub, AlignX = Enum.TextXAlignment.Left })
		if owned then
			UI.button(row, equipped and "Take off" or "Wear", { Name = "Wear", Size = UDim2.fromOffset(120, 38), Position = UDim2.new(1, -128, 0, 9), Color = equipped and C.red or C.goo, TextColor = equipped and C.text or C.dark, TextSize = 16, Corner = 10 }, function()
				if equipped then
					State.send("UnequipGift", gift.slot)
				else
					State.send("EquipGift", gift.id)
				end
			end)
		end
	end
end

function refresh()
	if not window.visible then
		return
	end
	local data = State.data
	preview.set({ age = data.age, equipped = data.equipped })
	local drip = InventorySystem.dripScore(data.equipped)
	local verdict = InventorySystem.isBadFit(data.equipped) and "the fit is NOT it" or (drip >= 40 and "ARCHIVE LEVEL DRIP" or drip >= 24 and "dripped out" or drip >= 10 and "getting there" or "kinda basic")
	dripLabel.Text = string.format("Drip %d  •  %s", math.floor(drip), verdict)
	UI.clear(content)
	if mode == "Style" then
		showGifts()
	elseif pickingSlot then
		showPicker(pickingSlot)
	else
		showSlots()
	end
	refreshOutfits()
end

window.onShow(function(arg)
	pickingSlot = nil
	if arg == "Style" then
		mode = "Style"
	else
		mode = "Fit"
	end
	tabs.select(mode, true)
	refresh()
end)
State.on("equipped", refresh)
State.on("inventory", refresh)
State.on("outfits", refresh)
State.on("gifts", refresh)
State.on("age", refresh)
State.onSession("passes", refresh)
