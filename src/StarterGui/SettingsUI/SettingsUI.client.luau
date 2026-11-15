--[[
	SettingsUI
	Music / sound effects / low graphics / Brady chatter toggles, the cosmetic
	aura picker (Cosmetic Effects pass) and a "replay tutorial" button.
	Settings are saved with the player's profile.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = ReplicatedStorage:WaitForChild("Client")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local State = require(Client:WaitForChild("ClientState"))
local UI = require(Client:WaitForChild("UI"))
local Monetization = require(Modules:WaitForChild("Monetization"))
local Sounds = require(Modules:WaitForChild("Sounds"))

local gui = script.Parent
local C = UI.Colors

State.wait()

local window = UI.window(gui, { name = "Settings", title = "⚙️ Settings", width = 560, height = 470 })
local list = UI.scroll(window.body, { Name = "List" })
UI.list(list, { pad = 8 })

local TOGGLES = {
	{ key = "sfx", name = "🔊 Sound effects", desc = "clicks, coins and Brady noises" },
	{ key = "music", name = "🎵 Music", desc = Sounds.Music == "" and "no music track is set up for this game yet" or "background music" },
	{ key = "chatter", name = "💬 Brady chatter", desc = "random speech bubbles when he is idle" },
	{ key = "lowGfx", name = "⚡ Low graphics", desc = "fewer particles and animations for slower devices" },
}

local toggleButtons = {}

for index, toggle in ipairs(TOGGLES) do
	local row = UI.row(list, { Name = "Setting_" .. toggle.key, Size = UDim2.new(1, -12, 0, 60), LayoutOrder = index })
	UI.label(row, toggle.name, { Size = UDim2.new(1, -150, 0, 26), Position = UDim2.fromOffset(14, 6), TextSize = 18, AlignX = Enum.TextXAlignment.Left })
	UI.label(row, toggle.desc, { Size = UDim2.new(1, -150, 0, 22), Position = UDim2.fromOffset(14, 32), TextSize = 12, Font = UI.BodyFont, Color = C.sub, AlignX = Enum.TextXAlignment.Left })
	toggleButtons[toggle.key] = UI.button(row, "ON", { Name = "Toggle", Size = UDim2.fromOffset(110, 40), Position = UDim2.new(1, -120, 0, 10), TextSize = 18 }, function()
		State.send("Setting", toggle.key, not State.data.settings[toggle.key])
	end)
end

-- Aura picker (purely cosmetic gamepass feature)
local auraRow = UI.row(list, { Name = "Aura", Size = UDim2.new(1, -12, 0, 92), LayoutOrder = 10 })
UI.label(auraRow, "🌈 Brady's aura", { Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(14, 6), TextSize = 18, AlignX = Enum.TextXAlignment.Left })
local auraNote = UI.label(auraRow, "", { Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(14, 30), TextSize = 12, Font = UI.BodyFont, Color = C.sub, AlignX = Enum.TextXAlignment.Left })
local auraButtons = UI.box(auraRow, { Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 52) })
UI.list(auraButtons, { horizontal = true, pad = 6 })
local auraChoices = {}
for index, aura in ipairs(Monetization.Auras) do
	auraChoices[aura] = UI.button(auraButtons, aura, { Name = "Aura_" .. aura, Size = UDim2.fromOffset(94, 32), Color = C.panel2, TextColor = C.text, TextSize = 14, Corner = 10, LayoutOrder = index }, function()
		if aura ~= "none" and not State.hasPass("CosmeticEffects") then
			State.toast("auras come with the Cosmetic Effects pass (Shop > Passes)", "info")
			return
		end
		State.send("Setting", "aura", aura)
	end)
end

UI.button(list, "📘 Replay the tutorial", { Name = "Replay", Size = UDim2.new(1, -12, 0, 44), Color = C.blue, TextColor = C.text, TextSize = 18, LayoutOrder = 20 }, function()
	State.send("Tutorial", "Replay")
	State.close()
end)
UI.button(list, "🏠 Take me home", { Name = "Home", Size = UDim2.new(1, -12, 0, 44), Color = C.goo, TextSize = 18, LayoutOrder = 21 }, function()
	State.send("Visit", "Home")
	State.close()
end)
UI.label(list, "Raise Brady Goo  •  progress saves automatically", { Size = UDim2.new(1, -12, 0, 26), TextSize = 12, Font = UI.BodyFont, Color = C.sub, LayoutOrder = 30 })

local function refresh()
	local settings = State.data.settings
	for key, button in pairs(toggleButtons) do
		local on = settings[key] == true
		button.Text = on and "ON" or "OFF"
		button.BackgroundColor3 = on and C.goo or C.grey
	end
	local hasPass = State.hasPass("CosmeticEffects")
	auraNote.Text = hasPass and "pick a trail effect - looks only" or "🔒 needs the Cosmetic Effects pass - looks only, no gameplay bonus"
	for aura, button in pairs(auraChoices) do
		local selected = settings.aura == aura
		button.BackgroundColor3 = selected and C.goo or C.panel2
		button.TextColor3 = selected and C.dark or C.text
	end
end

window.onShow(refresh)
State.on("settings", refresh)
State.onSession("passes", refresh)
