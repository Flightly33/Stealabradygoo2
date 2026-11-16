--[[
	MinigameUI
	"Play with Brady": the game picker plus five little UI mini-games.

	    Catch the Ball   drag Brady left/right, catch balls, dodge socks
	    Click the Target tap targets before they vanish
	    Reaction Test    wait for green, tap fast (5 rounds)
	    Goo Soccer       time 5 penalty kicks past the goalie
	    Dance Battle     hit the falling arrows on the line

	(The sixth game, the Goo Obby, is a physical course in the mini-game area.)

	A round is started and finished through the server. The score computed
	here is only a claim: MinigameServer clamps it, checks the round lasted a
	believable time and works out the reward itself.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Client = ReplicatedStorage:WaitForChild("Client")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local State = require(Client:WaitForChild("ClientState"))
local UI = require(Client:WaitForChild("UI"))
local Config = require(Modules:WaitForChild("Config"))
local MinigameSystem = require(Modules:WaitForChild("MinigameSystem"))

local gui = script.Parent
local C = UI.Colors

State.wait()

----------------------------------------------------------------------
-- Picker window
----------------------------------------------------------------------
local window = UI.window(gui, { name = "Minigame", title = "🎮 Play with Brady", width = 700, height = 470 })
local energyBar = UI.bar(window.body, { Size = UDim2.new(1, 0, 0, 22), Color = C.goo, TextSize = 13 })
local picker = UI.scroll(window.body, { Name = "Games", Size = UDim2.new(1, 0, 1, -30), Position = UDim2.fromOffset(0, 30) })
UI.list(picker, { pad = 6 })

----------------------------------------------------------------------
-- Game overlay
----------------------------------------------------------------------
local overlay = UI.frame(gui, { Name = "GameOverlay", Color = C.dark, Transparency = 0.25, Corner = false, Visible = false, ZIndex = 10 })
overlay.Active = true
local stage = UI.frame(overlay, { Name = "Stage", Size = UDim2.fromOffset(680, 470), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = C.bg, Corner = 22, ZIndex = 11 })
UI.stroke(stage, 4, C.pink)
UI.gradient(stage, 0.72)
UI.autoScale(stage, "window")
local gameTitle = UI.label(stage, "", { Name = "Title", Size = UDim2.new(1, -260, 0, 34), Position = UDim2.fromOffset(16, 6), TextSize = 22, AlignX = Enum.TextXAlignment.Left, ZIndex = 12 })
local scoreLabel = UI.label(stage, "0", { Name = "Score", Size = UDim2.fromOffset(150, 34), Position = UDim2.new(1, -250, 0, 6), TextSize = 22, Color = C.gold, ZIndex = 12 })
local timeBar = UI.bar(stage, { Name = "Time", Size = UDim2.new(1, -32, 0, 10), Position = UDim2.fromOffset(16, 44), Color = C.pink, Corner = 5 })
local arena = UI.frame(stage, { Name = "Arena", Size = UDim2.new(1, -32, 1, -76), Position = UDim2.fromOffset(16, 60), Color = C.panel, Corner = 16, Clips = true, ZIndex = 12 })
local message = UI.label(stage, "", { Name = "Message", Size = UDim2.new(1, 0, 0, 70), Position = UDim2.new(0, 0, 0.5, -35), Font = UI.LoudFont, TextSize = 52, Outline = 5, ZIndex = 30 })
message.Visible = false

local playing = false
local cancelled = false

UI.button(stage, "Quit", { Name = "Quit", Size = UDim2.fromOffset(84, 32), Position = UDim2.new(1, -94, 0, 7), Color = C.red, TextColor = C.text, TextSize = 15, Corner = 10, ZIndex = 13 }, function()
	cancelled = true
end)

local results = UI.frame(stage, { Name = "Results", Size = UDim2.fromOffset(420, 280), Position = UDim2.fromScale(0.5, 0.52), AnchorPoint = Vector2.new(0.5, 0.5), Color = C.bg, Corner = 20, Visible = false, ZIndex = 40 })
UI.stroke(results, 4, C.gold)
local resultTitle = UI.label(results, "", { Name = "Title", Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 10), Font = UI.LoudFont, TextSize = 40, Color = C.gold, Outline = 4, ZIndex = 41 })
local resultScore = UI.label(results, "", { Name = "Score", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 72), TextSize = 22, ZIndex = 41 })
local resultReward = UI.label(results, "", { Name = "Reward", Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 106), TextSize = 20, Color = C.goo, ZIndex = 41 })
local resultButtons = UI.box(results, { Name = "Buttons", Size = UDim2.new(1, -24, 0, 50), Position = UDim2.new(0, 12, 1, -62), ZIndex = 41 })
UI.list(resultButtons, { horizontal = true, pad = 10, alignX = Enum.HorizontalAlignment.Center })

local function flashMessage(text, color, seconds)
	message.Text = text
	message.TextColor3 = color or C.text
	message.Visible = true
	UI.pop(message, 0.5)
	task.delay(seconds or 0.6, function()
		if message.Text == text then
			message.Visible = false
		end
	end)
end

-- Runs fn(dt, elapsed) every frame for `duration` seconds (or until it
-- returns true / the player quits).
local function frames(duration, fn)
	local elapsed = 0
	while elapsed < duration and not cancelled do
		local dt = math.min(RunService.RenderStepped:Wait(), 0.1)
		elapsed += dt
		timeBar.set(1 - elapsed / duration)
		if fn(dt, elapsed) then
			break
		end
	end
end

local function setScore(score, max)
	scoreLabel.Text = "score " .. math.floor(score) .. (max and (" / " .. max) or "")
end

-- Horizontal pointer position inside the arena, 0..1.
local function pointerX(input)
	local left = arena.AbsolutePosition.X
	local width = math.max(1, arena.AbsoluteSize.X)
	return math.clamp((input.Position.X - left) / width, 0, 1)
end

local function piece(text, size, zindex)
	local label = UI.label(arena, text, { Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5), TextSize = math.floor(size * 0.8), ZIndex = zindex or 14 })
	return label
end

----------------------------------------------------------------------
-- THE GAMES: each returns the final score
----------------------------------------------------------------------
local GAMES = {}

function GAMES.catch(def)
	local x = 0.5
	local basket = piece("🧒", 72, 16)
	local connections = {
		UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				x = pointerX(input)
			end
		end),
		UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				x = pointerX(input)
			end
		end),
	}
	local items = {}
	local score, spawnIn = 0, 0.4
	frames(def.duration, function(dt, elapsed)
		spawnIn -= dt
		if spawnIn <= 0 then
			spawnIn = math.max(0.5, 0.9 - elapsed * 0.02)
			local good = math.random() < 0.8
			table.insert(items, { label = piece(good and "⚾" or "🧦", 44), x = 0.08 + math.random() * 0.84, y = -0.06, speed = 0.5 + elapsed * 0.02, good = good })
		end
		basket.Position = UDim2.new(x, 0, 0.9, 0)
		for index = #items, 1, -1 do
			local item = items[index]
			item.y += item.speed * dt
			item.label.Position = UDim2.fromScale(item.x, item.y)
			local caught = item.y > 0.8 and item.y < 0.97 and math.abs(item.x - x) < 0.09
			if caught or item.y > 1.08 then
				if caught then
					score = math.max(0, score + (item.good and 1 or -1))
					State.sound(item.good and "good" or "bad")
					UI.pop(basket, item.good and 1.25 or 0.7)
				end
				item.label:Destroy()
				table.remove(items, index)
			end
		end
		setScore(score, def.maxScore)
	end)
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	return math.min(score, def.maxScore)
end

function GAMES.target(def)
	local score, spawnIn = 0, 0.3
	frames(def.duration, function(dt, elapsed)
		spawnIn -= dt
		if spawnIn <= 0 then
			spawnIn = math.max(0.45, 0.78 - elapsed * 0.012)
			local size = math.floor(math.max(54, 76 - elapsed))
			local target = UI.new("TextButton", {
				Name = "Target",
				Size = UDim2.fromOffset(size, size),
				Position = UDim2.fromScale(0.1 + math.random() * 0.8, 0.14 + math.random() * 0.72),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Text = "🎯",
				TextSize = math.floor(size * 0.85),
				ZIndex = 15,
				Parent = arena,
			})
			local alive = true
			target.Activated:Connect(function()
				if alive then
					alive = false
					score += 1
					State.sound("good")
					setScore(score, def.maxScore)
					target:Destroy()
				end
			end)
			task.delay(math.max(0.8, 1.2 - elapsed * 0.015), function()
				if alive then
					alive = false
					target:Destroy()
				end
			end)
		end
		setScore(score, def.maxScore)
	end)
	return math.min(score, def.maxScore)
end

function GAMES.reaction(def)
	local pad = UI.new("TextButton", {
		Name = "Pad",
		Size = UDim2.new(1, -40, 1, -40),
		Position = UDim2.fromOffset(20, 20),
		BackgroundColor3 = C.red,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = UI.LoudFont,
		Text = "WAIT...",
		TextSize = 60,
		TextColor3 = C.text,
		ZIndex = 15,
		Parent = arena,
	})
	UI.corner(pad, 18)
	local rounds, total = 5, 0
	for round = 1, rounds do
		if cancelled then
			break
		end
		pad.BackgroundColor3 = C.red
		pad.Text = "WAIT...  (" .. round .. "/" .. rounds .. ")"
		local phase, tappedAt, early = "wait", nil, false
		local connection = pad.Activated:Connect(function()
			if phase == "wait" then
				early = true
			elseif phase == "go" and not tappedAt then
				tappedAt = os.clock()
			end
		end)
		local waitFor = 1 + math.random() * 2.2
		local start = os.clock()
		while os.clock() - start < waitFor and not early and not cancelled do
			RunService.RenderStepped:Wait()
		end
		local roundScore = 0
		if early then
			pad.Text = "TOO EARLY! 😬"
			State.sound("bad")
		elseif not cancelled then
			phase = "go"
			pad.BackgroundColor3 = C.goo
			pad.Text = "TAP!!!"
			State.sound("notify")
			local goAt = os.clock()
			while not tappedAt and os.clock() - goAt < 2 and not cancelled do
				RunService.RenderStepped:Wait()
			end
			local ms = tappedAt and (tappedAt - goAt) * 1000 or 2000
			-- 180 ms or faster = 100 points, 600 ms = 0 points
			roundScore = math.clamp(100 - (ms - 180) / 4.2, 0, 100)
			pad.Text = tappedAt and string.format("%d ms", ms) or "too slow!"
		end
		connection:Disconnect()
		total += roundScore
		setScore(total / round, def.maxScore)
		timeBar.set(1 - round / rounds)
		local pause = os.clock()
		while os.clock() - pause < 0.8 and not cancelled do
			RunService.RenderStepped:Wait()
		end
	end
	return math.floor(total / rounds)
end

function GAMES.soccer(def)
	local goal = UI.frame(arena, { Name = "Goal", Size = UDim2.fromScale(0.86, 0.42), Position = UDim2.fromScale(0.07, 0.06), Color = C.panel2, Corner = 10, ZIndex = 13 })
	UI.stroke(goal, 5, C.text)
	local goalie = piece("🧤", 70, 16)
	local ball = piece("⚽", 50, 17)
	local shoot = UI.button(arena, "SHOOT!", { Name = "Shoot", Size = UDim2.fromOffset(240, 60), Position = UDim2.new(0.5, -120, 1, -72), Color = C.goo, TextSize = 28, ZIndex = 18 })
	local score = 0
	for shot = 1, def.maxScore do
		if cancelled then
			break
		end
		local taken = false
		local connection = shoot.Activated:Connect(function()
			taken = true
		end)
		local t, phase = 0, math.random() * 6
		local goalieX, aimX = 0.5, 0.5
		while not taken and t < 6 and not cancelled do
			local dt = math.min(RunService.RenderStepped:Wait(), 0.1)
			t += dt
			goalieX = 0.5 + 0.33 * math.sin(t * (1.7 + shot * 0.35) + phase)
			aimX = 0.5 + 0.38 * math.sin(t * (2.4 + shot * 0.3))
			goalie.Position = UDim2.fromScale(goalieX, 0.3)
			ball.Position = UDim2.fromScale(aimX, 0.7)
			timeBar.set(1 - (shot - 1 + t / 6) / def.maxScore)
		end
		connection:Disconnect()
		if cancelled then
			break
		end
		local saved = math.abs(aimX - goalieX) < 0.14
		UI.tween(ball, 0.3, { Position = UDim2.fromScale(aimX, 0.28) })
		State.sound("jump")
		task.wait(0.32)
		if taken and not saved then
			score += 1
			flashMessage("GOAL!", C.goo)
			State.sound("good")
		else
			flashMessage(taken and "SAVED!" or "TOO SLOW!", C.red)
			State.sound("bad")
		end
		setScore(score, def.maxScore)
		task.wait(0.7)
	end
	return score
end

function GAMES.dance(def)
	local LANES = { "←", "↓", "↑", "→" }
	local KEYS = {
		[Enum.KeyCode.Left] = 1, [Enum.KeyCode.Down] = 2, [Enum.KeyCode.Up] = 3, [Enum.KeyCode.Right] = 4,
		[Enum.KeyCode.A] = 1, [Enum.KeyCode.S] = 2, [Enum.KeyCode.W] = 3, [Enum.KeyCode.D] = 4,
	}
	local HIT_Y = 0.74
	local laneColors = { C.pink, C.blue, C.goo, C.gold }
	UI.frame(arena, { Name = "HitLine", Size = UDim2.new(1, 0, 0, 6), Position = UDim2.fromScale(0, HIT_Y), Color = C.text, Corner = false, ZIndex = 13 })
	local arrows = {}
	local score = 0
	local function press(lane)
		local best, bestIndex
		for index, arrow in ipairs(arrows) do
			if arrow.lane == lane and math.abs(arrow.y - HIT_Y) < 0.1 and (not best or math.abs(arrow.y - HIT_Y) < math.abs(best.y - HIT_Y)) then
				best, bestIndex = arrow, index
			end
		end
		if best then
			score += 1
			best.label:Destroy()
			table.remove(arrows, bestIndex)
			State.sound("good")
			flashMessage("NICE!", laneColors[lane], 0.25)
		else
			State.sound("bad")
		end
		setScore(score, def.maxScore)
	end
	for lane = 1, 4 do
		UI.button(arena, LANES[lane], { Name = "Lane" .. lane, Size = UDim2.new(0.25, -8, 0, 64), Position = UDim2.new((lane - 1) * 0.25, 4, 1, -70), Color = laneColors[lane], TextSize = 36, ZIndex = 18, Silent = true }, function()
			press(lane)
		end)
	end
	local connection = UserInputService.InputBegan:Connect(function(input)
		local lane = KEYS[input.KeyCode]
		if lane then
			press(lane)
		end
	end)
	local spawned, spawnIn = 0, 0.6
	frames(def.duration, function(dt)
		spawnIn -= dt
		if spawnIn <= 0 and spawned < def.maxScore then
			spawnIn = 0.72
			spawned += 1
			local lane = math.random(1, 4)
			local label = piece(LANES[lane], 54, 15)
			label.TextColor3 = laneColors[lane]
			table.insert(arrows, { lane = lane, y = -0.06, label = label })
		end
		for index = #arrows, 1, -1 do
			local arrow = arrows[index]
			arrow.y += 0.52 * dt
			arrow.label.Position = UDim2.fromScale((arrow.lane - 0.5) * 0.25, arrow.y)
			if arrow.y > 0.92 then
				arrow.label:Destroy()
				table.remove(arrows, index)
			end
		end
	end)
	connection:Disconnect()
	return math.min(score, def.maxScore)
end

----------------------------------------------------------------------
-- Running a round
----------------------------------------------------------------------
local play

local function showResults(def, score, result)
	UI.clear(resultButtons)
	results.Visible = true
	UI.pop(results, 0.7)
	local ratio = result.ok and result.ratio or 0
	resultTitle.Text = ratio >= 0.95 and "PERFECT!" or (ratio >= 0.6 and "NICE!" or "GOOD TRY")
	resultScore.Text = def.name .. ": " .. math.floor(score) .. " / " .. def.maxScore
	if result.ok then
		resultReward.Text = string.format("+%d Goo Coins    +%d Age XP%s", result.coins, result.xp, (result.bonus or 1) > 1 and "\n(arcade bonus!)" or "")
		State.sound(ratio >= 0.6 and "rare" or "notify")
	else
		resultReward.Text = result.reason or "no reward this time"
	end
	UI.button(resultButtons, "Play again", { Size = UDim2.fromOffset(180, 48), Color = C.goo, TextSize = 20 }, function()
		results.Visible = false
		overlay.Visible = false
		task.spawn(play, def.id)
	end)
	UI.button(resultButtons, "Done", { Size = UDim2.fromOffset(180, 48), Color = C.sub, TextSize = 20 }, function()
		results.Visible = false
		overlay.Visible = false
	end)
end

function play(id)
	local def = MinigameSystem.get(id)
	if not def or playing then
		return
	end
	if def.world then
		State.toast("the Goo Obby is a real course - go to Room > Travel > Mini-Games and step on START", "info")
		return
	end
	playing = true
	local started = State.invoke("MinigameStart", id)
	if not started.ok then
		playing = false
		State.toast(started.reason or "can't play right now", "bad")
		return
	end
	State.close()
	cancelled = false
	results.Visible = false
	UI.clear(arena)
	overlay.Visible = true
	gameTitle.Text = def.icon .. " " .. def.name
	setScore(0, def.maxScore)
	timeBar.set(1)
	flashMessage("READY?", C.gold, 0.7)
	task.wait(0.75)

	local ok, score = pcall(GAMES[id], def)
	if not ok then
		warn("[MinigameUI] " .. tostring(score))
		score = 0
	end
	UI.clear(arena)
	message.Visible = false
	local result = State.invoke("MinigameFinish", started.token, score)
	playing = false
	showResults(def, score, result)
end

----------------------------------------------------------------------
-- Picker contents
----------------------------------------------------------------------
local function refresh()
	if not window.visible then
		return
	end
	local data = State.data
	energyBar.set(data.meters.energy / 100, string.format("⚡ Energy %d / 100   (each game costs %d)", math.floor(data.meters.energy + 0.5), Config.MinigameEnergyCost))
	UI.clear(picker)
	for index, def in ipairs(MinigameSystem.List) do
		local locked = data.age < def.minAge
		local row = UI.row(picker, { Name = "Game_" .. def.id, Size = UDim2.new(1, -12, 0, 62), LayoutOrder = index })
		UI.label(row, def.icon, { Size = UDim2.fromOffset(56, 62), TextSize = 34 })
		UI.label(row, def.name, { Size = UDim2.new(1, -240, 0, 26), Position = UDim2.fromOffset(60, 6), TextSize = 18, AlignX = Enum.TextXAlignment.Left })
		UI.label(row, def.desc, { Size = UDim2.new(1, -240, 0, 26), Position = UDim2.fromOffset(60, 32), TextSize = 12, Font = UI.BodyFont, Color = C.sub, AlignX = Enum.TextXAlignment.Left })
		local text = locked and ("🔒 Age " .. def.minAge) or (def.world and "at the arcade" or "PLAY")
		local button = UI.button(row, text, { Name = "Play", Size = UDim2.fromOffset(160, 44), Position = UDim2.new(1, -168, 0, 9), Color = C.pink, TextSize = 18 }, function()
			if not locked then
				task.spawn(play, def.id)
			end
		end)
		UI.setEnabled(button, not locked, C.pink)
	end
	UI.label(picker, "💡 playing at the Goo Arcade machines gives +25% rewards", { Size = UDim2.new(1, -12, 0, 26), TextSize = 12, Font = UI.BodyFont, Color = C.sub, LayoutOrder = 99 })
end

window.onShow(function(arg)
	refresh()
	-- arcade machines open this window with a game id: start it straight away
	if type(arg) == "string" and MinigameSystem.get(arg) then
		task.spawn(play, arg)
	end
end)
State.on("meters", refresh)
State.on("age", refresh)
