--[[
	InventoryUI
	Every piece of clothing the player owns, organised into the categories
	Shirts / Pants / Shoes / Jackets / Accessories / Hats / Glasses /
	Full Outfits / Hairstyles, coloured by rarity.

	Selecting an item shows its name, rarity, required age, description and
	whether it is equipped, with an Equip / Unequip button. The button only
	sends a request: ClothingServer checks ownership and the age rule.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = ReplicatedStorage:WaitForChild("Client")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local State = require(Client:WaitForChild("ClientState"))
local UI = require(Client:WaitForChild("UI"))
local ClothingSystem = require(Modules:WaitForChild("ClothingSystem"))
local InventorySystem = require(Modules:WaitForChild("InventorySystem"))

local gui = script.Parent
local C = UI.Colors

State.wait()

local window = UI.window(gui, { name = "Inventory", title = "🎒 Inventory", width = 840, height = 490 })
local body = window.body

local TABS = {
	{ id = "All", text = "All" },
	{ id = "Tops", text = "👕 Tops" },
	{ id = "Bottoms", text = "👖 Bottoms" },
	{ id = "Extras", text = "🕶️ Extras" },
	{ id = "Outfit", text = "✨ Outfits" },
}
local GROUPS = {
	Tops = { Shirt = true, Jacket = true },
	Bottoms = { Pants = true, Shoes = true },
	Extras = { Hat = true, Glasses = true, Accessory = true, Hair = true },
	Outfit = { Outfit = true },
}

local currentSlot = "All"
local selectedId = nil
local refresh -- forward declaration

local tabs = UI.tabs(body, TABS, function(id)
	currentSlot = id
	refresh()
end, { Width = 816, TextSize = 16, TabHeight = 36 })

local grid = UI.scroll(body, { Name = "Grid", Size = UDim2.new(1, -262, 1, -72), Position = UDim2.fromOffset(0, 44) })
UI.grid(grid, 104, 122, 8)
UI.pad(grid, 4, 4, 12, 4)
local countLabel = UI.label(body, "", { Name = "Count", Size = UDim2.new(1, -262, 0, 22), Position = UDim2.new(0, 0, 1, -24), TextSize = 14, Font = UI.BodyFont, Color = C.sub, AlignX = Enum.TextXAlignment.Left })

-- DETAIL PANEL -----------------------------------------------------------
local detail = UI.frame(body, { Name = "Detail", Size = UDim2.new(0, 252, 1, -44), Position = UDim2.new(1, -252, 0, 44), Color = C.panel, Corner = 14 })
local swatch = UI.frame(detail, { Name = "Swatch", Size = UDim2.new(1, -24, 0, 90), Position = UDim2.fromOffset(12, 12), Color = C.panel2, Corner = 12 })
local swatchIcon = UI.label(swatch, "", { TextSize = 52 })
local swatchStroke = UI.stroke(swatch, 4, C.sub)
local nameLabel = UI.label(detail, "pick an item", { Name = "ItemName", Size = UDim2.new(1, -16, 0, 44), Position = UDim2.fromOffset(8, 106), TextSize = 19 })
local rarityLabel = UI.label(detail, "", { Name = "Rarity", Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 150), TextSize = 17 })
local ageLabel = UI.label(detail, "", { Name = "Age", Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 174), TextSize = 14, Font = UI.BodyFont, Color = C.sub })
local descLabel = UI.label(detail, "", { Name = "Description", Size = UDim2.new(1, -24, 0, 70), Position = UDim2.fromOffset(12, 198), TextSize = 14, Font = UI.BodyFont, Color = C.text, AlignY = Enum.TextYAlignment.Top })
local sourceLabel = UI.label(detail, "", { Name = "Source", Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 270), TextSize = 12, Font = UI.BodyFont, Color = C.sub })
local statusLabel = UI.label(detail, "", { Name = "Status", Size = UDim2.new(1, -16, 0, 22), Position = UDim2.new(0, 8, 1, -84), TextSize = 15, Color = C.goo })
local equipButton = UI.button(detail, "EQUIP", { Name = "Equip", Size = UDim2.new(1, -24, 0, 46), Position = UDim2.new(0, 12, 1, -58), TextSize = 22 }, function()
	local item = selectedId and ClothingSystem.get(selectedId)
	if not item then
		return
	end
	if State.data.equipped[item.slot] == item.id then
		State.send("Unequip", item.slot)
	else
		local ok, reason = InventorySystem.canEquip(State.data, item.id)
		if ok then
			State.send("Equip", item.id)
		else
			State.toast(reason, "bad")
		end
	end
end)

local function showDetail()
	local data = State.data
	local item = selectedId and ClothingSystem.get(selectedId)
	if not item or not data.inventory[item.id] then
		selectedId = nil
		nameLabel.Text = "pick an item"
		rarityLabel.Text, ageLabel.Text, descLabel.Text, sourceLabel.Text, statusLabel.Text = "", "", "", "", ""
		swatchIcon.Text = "👆"
		swatch.BackgroundColor3 = C.panel2
		swatchStroke.Color = C.sub
		equipButton.Visible = false
		return
	end
	local color = ClothingSystem.rarityColor(item.rarity)
	swatch.BackgroundColor3 = ClothingSystem.swatch(item)
	swatchStroke.Color = color
	swatchIcon.Text = ClothingSystem.SlotInfo[item.slot].icon
	nameLabel.Text = item.name
	rarityLabel.Text = "Rarity: " .. item.rarity
	rarityLabel.TextColor3 = color
	ageLabel.Text = "Required Age: " .. item.age
	descLabel.Text = "\"" .. item.desc .. "\""
	sourceLabel.Text = "From: " .. item.source
	local equipped = data.equipped[item.slot] == item.id
	local ok, reason = InventorySystem.canEquip(data, item.id)
	equipButton.Visible = true
	if equipped then
		statusLabel.Text = "✓ EQUIPPED"
		statusLabel.TextColor3 = C.goo
		equipButton.Text = "UNEQUIP"
		UI.setEnabled(equipButton, true, C.red)
	elseif ok then
		statusLabel.Text = "not equipped"
		statusLabel.TextColor3 = C.sub
		equipButton.Text = "EQUIP"
		UI.setEnabled(equipButton, true, C.goo)
	else
		statusLabel.Text = "🔒 " .. reason
		statusLabel.TextColor3 = C.red
		equipButton.Text = "LOCKED"
		UI.setEnabled(equipButton, false)
	end
end

function refresh()
	if not window.visible then
		return
	end
	local data = State.data
	UI.clear(grid)
	local group = GROUPS[currentSlot]
	local items = {}
	for _, item in ipairs(InventorySystem.ownedItems(data)) do
		if not group or group[item.slot] then
			table.insert(items, item)
		end
	end
	for index, item in ipairs(items) do
		local locked = nil
		if not InventorySystem.canEquip(data, item.id) then
			locked = "Age " .. math.max(item.age, 1)
		end
		UI.itemCard(grid, item, {
			LayoutOrder = index,
			equipped = data.equipped[item.slot] == item.id,
			locked = locked,
		}, function()
			selectedId = item.id
			showDetail()
		end)
	end
	local owned = InventorySystem.countOwned(data)
	countLabel.Text = string.format("%d shown  •  %d / %d items owned", #items, owned, #ClothingSystem.List)
	showDetail()
end

window.onShow(function(arg)
	if type(arg) == "string" and tabs.buttons[arg] then
		currentSlot = arg
	end
	tabs.select(currentSlot, true)
	refresh()
end)
State.on("inventory", refresh)
State.on("equipped", refresh)
State.on("age", refresh)
