--[[
	AdminUI
	Small owner-only panel. The button only appears when the server says this
	player is an admin; the server re-checks every request anyway.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = ReplicatedStorage:WaitForChild("Client")
local State = require(Client:WaitForChild("ClientState"))
local UI = require(Client:WaitForChild("UI"))

local gui = script.Parent
local C = UI.Colors

State.wait()

local window = UI.window(gui, { name = "Admin", title = "🛠️ Admin", width = 420, height = 470 })
local list = UI.scroll(window.body, { Name = "List" })
UI.grid(list, 186, 52, 8)

local ACTIONS = {
	{ "Coins", "+10,000 coins", C.gold, 10000 },
	{ "Coins", "+1,000,000 coins", C.gold, 1000000 },
	{ "AgeUp", "Age up +1", C.goo },
	{ "MaxAge", "Max age (25)", C.goo },
	{ "AllItems", "Unlock all items", C.pink },
	{ "FillNeeds", "Fill all needs", C.blue },
	{ "Event", "Random event", C.purple },
	{ "Secret", "Spawn secret item", C.purple },
	{ "ResetDaily", "Reset daily reward", C.sub },
}
for index, def in ipairs(ACTIONS) do
	UI.button(list, def[2], { Name = def[1] .. index, Size = UDim2.fromOffset(186, 52), Color = def[3], TextSize = 17, LayoutOrder = index }, function()
		State.send("Admin", def[1], def[4])
	end)
end

local button = UI.button(gui, "🛠️", { Name = "AdminButton", Size = UDim2.fromOffset(52, 52), Position = UDim2.new(1, -12, 1, -12), AnchorPoint = Vector2.new(1, 1), Color = C.red, TextSize = 26 }, function()
	State.toggle("Admin")
end)
UI.autoScale(button, "hud")
button.Visible = false

State.onSession("isAdmin", function(isAdmin)
	button.Visible = isAdmin == true
end)
