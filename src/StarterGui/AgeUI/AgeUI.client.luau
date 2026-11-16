--[[
	AgeUI
	The Age XP bar at the top of the screen:

	        AGE 13  [████████░░░░]  AGE 14
	              Teen Brady

	...and the "BRADY AGED UP!" celebration that plays when the server says
	Brady reached a new age (bigger when he enters a whole new stage).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = ReplicatedStorage:WaitForChild("Client")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local State = require(Client:WaitForChild("ClientState"))
local UI = require(Client:WaitForChild("UI"))
local AgeSystem = require(Modules:WaitForChild("AgeSystem"))
local Util = require(Modules:WaitForChild("Util"))

local gui = script.Parent
local C = UI.Colors

State.wait()

----------------------------------------------------------------------
-- Age bar
----------------------------------------------------------------------
local holder = UI.box(gui, { Name = "AgeBar", Size = UDim2.fromOffset(560, 100), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0) })
UI.autoScale(holder, "hud")

local row = UI.frame(holder, { Name = "Row", Size = UDim2.fromOffset(460, 34), Position = UDim2.fromOffset(50, 52), Color = C.bg, Corner = 17, Stroke = 3, StrokeColor = C.dark })
UI.gradient(row, 0.7)
local leftLabel = UI.label(row, "AGE 1", { Name = "Current", Size = UDim2.fromOffset(84, 34), TextSize = 18, Color = C.goo, Outline = 2 })
local rightLabel = UI.label(row, "AGE 2", { Name = "Next", Size = UDim2.fromOffset(84, 34), Position = UDim2.new(1, -84, 0, 0), TextSize = 18, Color = C.gold, Outline = 2 })
local bar = UI.bar(row, { Name = "XP", Size = UDim2.new(1, -176, 0, 20), Position = UDim2.fromOffset(88, 7), Color = C.goo, Corner = 10, TextSize = 12 })
local stageLabel = UI.label(holder, "", { Name = "Stage", Size = UDim2.fromOffset(460, 18), Position = UDim2.fromOffset(50, 86), TextSize = 14, Color = C.text, Outline = 2 })

local function refresh()
	local data = State.data
	local age, into, needed = AgeSystem.ageFromXP(data.ageXP)
	local stage = AgeSystem.getStage(age)
	leftLabel.Text = "AGE " .. age
	local stars = data.rebirths > 0 and ("  " .. string.rep("★", math.min(data.rebirths, 5))) or ""
	stageLabel.Text = stage.name .. stars
	if age >= AgeSystem.MaxAge then
		rightLabel.Text = "MAX"
		bar.set(1, "LEGENDARY", C.gold)
	else
		rightLabel.Text = "AGE " .. (age + 1)
		bar.set(into / needed, Util.commas(into) .. " / " .. Util.commas(needed) .. " XP", C.goo)
	end
end

State.on("ageXP", refresh)
State.on("age", refresh)
State.on("rebirths", refresh)

----------------------------------------------------------------------
-- "BRADY AGED UP!" celebration
----------------------------------------------------------------------
local overlay = UI.frame(gui, { Name = "AgeUp", Color = C.dark, Transparency = 1, Corner = false, Visible = false, ZIndex = 30 })
local card = UI.box(overlay, { Name = "Card", Size = UDim2.fromOffset(820, 420), Position = UDim2.fromScale(0.5, 0.46), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 31 })
UI.autoScale(card, "window")
local headline = UI.label(card, "BRADY AGED UP!", { Name = "Headline", Size = UDim2.new(1, 0, 0, 90), Font = UI.LoudFont, TextSize = 76, Color = C.gold, Outline = 6, ZIndex = 32 })
local ageLine = UI.label(card, "", { Name = "Age", Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 92), TextSize = 42, Color = C.goo, Outline = 4, ZIndex = 32 })
local blurb = UI.label(card, "", { Name = "Blurb", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 146), TextSize = 20, Font = UI.BodyFont, Color = C.text, Outline = 3, ZIndex = 32 })
local lines = UI.box(card, { Name = "Unlocks", Size = UDim2.new(1, 0, 0, 220), Position = UDim2.fromOffset(0, 186), ZIndex = 32 })
UI.list(lines, { pad = 4, alignX = Enum.HorizontalAlignment.Center })

local queue = {}
local playing = false

local function play(payload)
	playing = true
	UI.clear(lines)
	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	UI.tween(overlay, 0.25, { BackgroundTransparency = payload.stageChanged and 0.35 or 0.6 })
	headline.Text = payload.stageChanged and "NEW ERA UNLOCKED!" or "BRADY AGED UP!"
	headline.TextColor3 = payload.stageChanged and C.pink or C.gold
	ageLine.Text = payload.stageChanged and (payload.stageName .. "  •  AGE " .. payload.age) or ("AGE " .. payload.age)
	blurb.Text = payload.stageChanged and (payload.blurb or "") or ""
	UI.pop(card, 0.3)
	-- a celebration fanfare plus a goofy voice crack
	State.sound("ageUp")
	task.delay(0.35, State.sound, "ageUpGoofy")

	for index, text in ipairs(payload.lines or {}) do
		if index > 8 then
			break
		end
		task.wait(payload.stageChanged and 0.22 or 0.1)
		local pill = UI.frame(lines, { Name = "Line", Size = UDim2.fromOffset(520, 24), Color = C.bg, Corner = 12, LayoutOrder = index, ZIndex = 32 })
		UI.label(pill, text, { TextSize = 15, Font = UI.BodyFont, Color = index == 1 and C.goo or C.text, ZIndex = 33 })
		UI.pop(pill, 0.7)
		State.sound("coin")
	end

	task.wait(payload.stageChanged and 3.2 or 1.3)
	UI.tween(overlay, 0.25, { BackgroundTransparency = 1 })
	task.wait(0.25)
	overlay.Visible = false
	playing = false
	local nextPayload = table.remove(queue, 1)
	if nextPayload then
		play(nextPayload)
	end
end

State.listen("AgeUp", function(payload)
	if type(payload) ~= "table" then
		return
	end
	if playing then
		-- Several age-ups at once: keep stage changes, drop older plain ones.
		if #queue >= 3 then
			for index, queued in ipairs(queue) do
				if not queued.stageChanged then
					table.remove(queue, index)
					break
				end
			end
		end
		table.insert(queue, payload)
	else
		task.spawn(play, payload)
	end
end)
