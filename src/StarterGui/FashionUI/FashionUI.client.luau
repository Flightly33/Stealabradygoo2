--[[
	FashionUI
	The Fashion Show window. It mirrors whatever phase the server's show is
	in: countdown to the next show, sign-ups, the runway, voting and results.

	Entering and voting are requests - FashionServer enforces the age limit,
	one vote per player and "you cannot vote for your own Brady".
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Client = ReplicatedStorage:WaitForChild("Client")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local State = require(Client:WaitForChild("ClientState"))
local UI = require(Client:WaitForChild("UI"))
local Config = require(Modules:WaitForChild("Config"))
local FashionSystem = require(Modules:WaitForChild("FashionSystem"))
local Util = require(Modules:WaitForChild("Util"))

local gui = script.Parent
local C = UI.Colors
local localPlayer = Players.LocalPlayer

State.wait()

local window = UI.window(gui, { name = "Fashion", title = "🌟 Fashion Show", width = 720, height = 470 })
local body = window.body

local phaseLabel = UI.label(body, "", { Name = "Phase", Size = UDim2.new(1, 0, 0, 36), TextSize = 28, Color = C.pink, Outline = 3 })
local infoLabel = UI.label(body, "", { Name = "Info", Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 38), TextSize = 15, Font = UI.BodyFont, Color = C.sub })
local timerLabel = UI.label(body, "", { Name = "Timer", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 82), TextSize = 22, Color = C.gold })
local list = UI.scroll(body, { Name = "List", Size = UDim2.new(1, 0, 1, -176), Position = UDim2.fromOffset(0, 116) })
UI.list(list, { pad = 5 })
local actions = UI.box(body, { Name = "Actions", Size = UDim2.new(1, 0, 0, 50), Position = UDim2.new(0, 0, 1, -52) })
UI.list(actions, { horizontal = true, pad = 10, alignX = Enum.HorizontalAlignment.Center })

local votedFor = nil
local lastPhase = nil

local function mine(state)
	for _, contestant in ipairs(state.contestants) do
		if contestant.userId == localPlayer.UserId then
			return contestant
		end
	end
	return nil
end

local function actionButton(text, color, callback)
	return UI.button(actions, text, { Size = UDim2.fromOffset(210, 48), Color = color, TextSize = 18 }, callback)
end

local function contestantRow(index, contestant, right, color)
	local row = UI.row(list, { Name = "Contestant" .. index, Size = UDim2.new(1, -12, 0, 44), LayoutOrder = index, StrokeColor = contestant.userId == localPlayer.UserId and C.goo or nil })
	UI.label(row, (contestant.isBot and "🤖 " or "🧒 ") .. contestant.name .. (contestant.userId == localPlayer.UserId and "  (you)" or ""), { Size = UDim2.new(1, -230, 1, 0), Position = UDim2.fromOffset(12, 0), TextSize = 17, AlignX = Enum.TextXAlignment.Left })
	if right then
		UI.label(row, right, { Size = UDim2.fromOffset(210, 44), Position = UDim2.new(1, -216, 0, 0), TextSize = 15, Font = UI.BodyFont, Color = color or C.sub, AlignX = Enum.TextXAlignment.Right })
	end
	return row
end

local function refresh()
	if not window.visible then
		return
	end
	local state = State.fashion
	UI.clear(list)
	UI.clear(actions)
	if not state then
		phaseLabel.Text = "loading..."
		infoLabel.Text = ""
		return
	end
	if state.phase ~= lastPhase then
		lastPhase = state.phase
		if state.phase == "Signup" then
			votedFor = nil
		end
	end
	local data = State.data
	local me = mine(state)

	if state.phase == "Signup" then
		phaseLabel.Text = "SIGN-UPS OPEN: " .. string.upper(state.category.name)
		infoLabel.Text = "Tip: " .. state.category.hint .. ".  Winner gets " .. Config.FashionWinCoins .. "+ Goo Coins and the title \"" .. state.category.title .. "\"."
		for index, contestant in ipairs(state.contestants) do
			contestantRow(index, contestant, "entered")
		end
		if #state.contestants == 0 then
			UI.label(list, "nobody has entered yet - be the first!", { Size = UDim2.new(1, -12, 0, 44), TextSize = 15, Font = UI.BodyFont, Color = C.sub })
		end
		if me then
			actionButton("Leave show", C.red, function()
				State.send("Fashion", "Leave")
			end).TextColor3 = C.text
		elseif data.age < Config.FashionMinAge then
			UI.setEnabled(actionButton("🔒 Age " .. Config.FashionMinAge .. " to enter", C.sub), false)
		else
			actionButton("ENTER BRADY!", C.goo, function()
				State.send("Fashion", "Join")
			end)
		end
		actionButton("Go to runway", C.blue, function()
			State.send("Visit", "Runway")
		end).TextColor3 = C.text
	elseif state.phase == "Runway" then
		phaseLabel.Text = "ON THE RUNWAY"
		infoLabel.Text = "Category: " .. state.category.name .. ".  Voting opens when everyone has walked."
		for index, contestant in ipairs(state.contestants) do
			local status = index < state.current and "walked" or (index == state.current and "WALKING NOW" or "waiting backstage")
			contestantRow(index, contestant, status, index == state.current and C.gold or C.sub)
		end
		actionButton("Watch at the runway", C.blue, function()
			State.send("Visit", "Runway")
			State.close()
		end).TextColor3 = C.text
	elseif state.phase == "Voting" then
		phaseLabel.Text = "VOTE: " .. string.upper(state.category.name)
		infoLabel.Text = "Pick the best fit. You get one vote and you can't vote for your own Brady."
		for index, contestant in ipairs(state.contestants) do
			local row = contestantRow(index, contestant)
			if contestant.userId ~= localPlayer.UserId then
				local chosen = votedFor == contestant.id
				UI.button(row, chosen and "VOTED ✓" or "VOTE", { Name = "Vote", Size = UDim2.fromOffset(130, 34), Position = UDim2.new(1, -138, 0, 5), Color = chosen and C.goo or C.pink, TextSize = 16, Corner = 10 }, function()
					votedFor = contestant.id
					State.send("Fashion", "Vote", contestant.id)
					refresh()
				end)
			end
		end
	elseif state.phase == "Results" then
		phaseLabel.Text = "RESULTS: " .. string.upper(state.category.name)
		local winner = state.results and state.results[1]
		infoLabel.Text = winner and ("🏆 " .. winner.name .. " wins and earns the title \"" .. state.category.title .. "\"!") or ""
		for index, result in ipairs(state.results or {}) do
			local mineResult = me ~= nil and result.id == me.id
			local row = UI.row(list, { Name = "Result" .. index, Size = UDim2.new(1, -12, 0, 44), LayoutOrder = index, StrokeColor = index == 1 and C.gold or (mineResult and C.goo or nil) })
			UI.label(row, (index == 1 and "🏆" or ("#" .. result.place)) .. "  " .. result.name .. (mineResult and "  (you)" or ""), { Size = UDim2.new(1, -260, 1, 0), Position = UDim2.fromOffset(12, 0), TextSize = 17, Color = index == 1 and C.gold or C.text, AlignX = Enum.TextXAlignment.Left })
			UI.label(row, string.format("score %d   •   %d vote%s", result.score, result.votes, result.votes == 1 and "" or "s"), { Size = UDim2.fromOffset(240, 44), Position = UDim2.new(1, -248, 0, 0), TextSize = 14, Font = UI.BodyFont, Color = C.sub, AlignX = Enum.TextXAlignment.Right })
		end
	else
		phaseLabel.Text = "NEXT SHOW SOON"
		infoLabel.Text = "Every few minutes a show starts with a random category. Dress Brady for it, enter, walk the runway and get votes!"
		for index, category in ipairs(FashionSystem.Categories) do
			local row = UI.row(list, { Name = "Category" .. index, Size = UDim2.new(1, -12, 0, 40), LayoutOrder = index })
			UI.label(row, category.name, { Size = UDim2.fromOffset(190, 40), Position = UDim2.fromOffset(12, 0), TextSize = 16, Color = FashionSystem.TitleColors[category.title], AlignX = Enum.TextXAlignment.Left })
			UI.label(row, category.hint .. "   •   title: " .. category.title, { Size = UDim2.new(1, -220, 1, 0), Position = UDim2.fromOffset(206, 0), TextSize = 12, Font = UI.BodyFont, Color = C.sub, AlignX = Enum.TextXAlignment.Left })
		end
		actionButton("Go to runway", C.blue, function()
			State.send("Visit", "Runway")
			State.close()
		end).TextColor3 = C.text
		actionButton("Change outfit", C.pink, function()
			State.open("Wardrobe")
		end)
	end
end

window.onShow(refresh)
State.fashionChanged:Connect(refresh)
State.on("age", refresh)

-- countdown while the window is open
task.spawn(function()
	while true do
		task.wait(0.5)
		local state = State.fashion
		if window.visible and state then
			local now = Workspace:GetServerTimeNow()
			if state.phase == "Idle" then
				timerLabel.Text = "next show in " .. Util.clock(math.max(0, (state.nextAt or 0) - now))
			else
				timerLabel.Text = Util.clock(math.max(0, (state.endsAt or 0) - now))
			end
		end
	end
end)
