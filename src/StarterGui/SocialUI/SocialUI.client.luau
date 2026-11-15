--[[
	SocialUI
	The "Inspect" window: look at another player's Brady - his age, what he
	is wearing (with rarity colours), drip score, rare pieces owned and how
	complete their collection is. You can hype the fit or visit their house.

	It is read-only: the server sends a public summary and nothing here can
	change or take the other player's items.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = ReplicatedStorage:WaitForChild("Client")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local State = require(Client:WaitForChild("ClientState"))
local UI = require(Client:WaitForChild("UI"))
local Preview = require(Client:WaitForChild("Preview"))
local ClothingSystem = require(Modules:WaitForChild("ClothingSystem"))
local FashionSystem = require(Modules:WaitForChild("FashionSystem"))

local gui = script.Parent
local C = UI.Colors

State.wait()

local window = UI.window(gui, { name = "Inspect", title = "🔍 Inspect", width = 720, height = 470 })
local body = window.body

local left = UI.box(body, { Name = "Left", Size = UDim2.new(0, 240, 1, 0) })
local preview = Preview.new(left, { Size = UDim2.new(1, 0, 0, 250) })
local titleLabel = UI.label(left, "", { Name = "Title", Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 254), TextSize = 15, Color = C.gold })
local stageLabel = UI.label(left, "", { Name = "Stage", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 276), TextSize = 17, Color = C.goo })
local hypeButton = UI.button(left, "🔥 HYPE THE FIT", { Name = "Hype", Size = UDim2.new(1, 0, 0, 42), Position = UDim2.fromOffset(0, 306), Color = C.pink, TextSize = 18 })
local visitButton = UI.button(left, "🏠 Visit house", { Name = "Visit", Size = UDim2.new(1, 0, 0, 38), Position = UDim2.fromOffset(0, 354), Color = C.goo, TextSize = 16 })

local right = UI.box(body, { Name = "Right", Size = UDim2.new(1, -252, 1, 0), Position = UDim2.fromOffset(252, 0) })
local stats = UI.box(right, { Name = "Stats", Size = UDim2.new(1, 0, 0, 96) })
UI.grid(stats, 142, 44, 6)
local fitList = UI.scroll(right, { Name = "Fit", Size = UDim2.new(1, 0, 1, -104), Position = UDim2.fromOffset(0, 102) })
UI.list(fitList, { pad = 4 })

local currentUserId = nil

hypeButton.Activated:Connect(function()
	if currentUserId then
		State.send("Hype", currentUserId)
	end
end)
visitButton.Activated:Connect(function()
	if currentUserId then
		State.send("Visit", currentUserId)
		State.close()
	end
end)

local function stat(order, value, name, color)
	local tile = UI.frame(stats, { Name = "Stat" .. order, Size = UDim2.fromOffset(142, 44), Color = C.panel, Corner = 10, LayoutOrder = order })
	UI.label(tile, tostring(value), { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 2), TextSize = 19, Color = color or C.text })
	UI.label(tile, name, { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 26), TextSize = 11, Font = UI.BodyFont, Color = C.sub })
end

local function show(userId)
	currentUserId = nil
	window.setTitle("🔍 Inspect")
	UI.clear(stats)
	UI.clear(fitList)
	titleLabel.Text = ""
	stageLabel.Text = "loading..."
	if type(userId) ~= "number" then
		stageLabel.Text = "nobody selected"
		return
	end
	local profile = State.invoke("GetProfile", userId)
	if not window.visible then
		return
	end
	if not profile.ok then
		stageLabel.Text = profile.reason or "that player left"
		return
	end
	currentUserId = userId
	window.setTitle("🔍 " .. profile.name .. "'s Brady")
	preview.set({ age = profile.age, equipped = profile.equipped })
	titleLabel.Text = profile.title and ("« " .. profile.title .. " »") or ""
	titleLabel.TextColor3 = profile.title and FashionSystem.TitleColors[profile.title] or C.gold
	stageLabel.Text = profile.stageName .. "  •  Age " .. profile.age .. (profile.rebirths > 0 and ("  " .. string.rep("★", math.min(profile.rebirths, 5))) or "")

	stat(1, profile.drip, "drip score", C.gold)
	stat(2, profile.collection .. "%", "collection", C.goo)
	stat(3, profile.items, "items owned")
	stat(4, profile.archive, "Archive pieces", ClothingSystem.rarityColor("Archive"))
	stat(5, profile.grail, "Grail pieces", ClothingSystem.rarityColor("Grail"))
	stat(6, profile.wins, "show wins", C.pink)

	local order = 0
	for _, slot in ipairs(ClothingSystem.Slots) do
		local item = profile.equipped[slot] and ClothingSystem.get(profile.equipped[slot])
		if item then
			order += 1
			local color = ClothingSystem.rarityColor(item.rarity)
			local row = UI.row(fitList, { Name = "Worn_" .. slot, Size = UDim2.new(1, -12, 0, 40), LayoutOrder = order, StrokeColor = color })
			UI.label(row, ClothingSystem.SlotInfo[slot].icon, { Size = UDim2.fromOffset(40, 40), TextSize = 22 })
			UI.label(row, item.name, { Size = UDim2.new(1, -170, 1, 0), Position = UDim2.fromOffset(44, 0), TextSize = 15, AlignX = Enum.TextXAlignment.Left })
			UI.label(row, item.rarity, { Size = UDim2.fromOffset(110, 40), Position = UDim2.new(1, -118, 0, 0), TextSize = 14, Color = color, AlignX = Enum.TextXAlignment.Right })
		end
	end
	if order == 0 then
		UI.label(fitList, "this Brady is wearing... nothing special. yet.", { Size = UDim2.new(1, -12, 0, 40), TextSize = 14, Font = UI.BodyFont, Color = C.sub })
	end
end

window.onShow(show)
