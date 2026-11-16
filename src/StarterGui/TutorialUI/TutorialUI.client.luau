--[[
	TutorialUI
	The first-time player experience (under a minute):

	  1. six short intro lines ("welcome to raise brady goo" ...)
	  2. guided steps that wait for the player to really do each thing:
	     feed Brady -> play with him -> earn Goo Coins -> open the wardrobe
	     -> equip clothing -> how ageing up works

	Each step watches the player's real data, so it advances the moment the
	action succeeds. Every step can be skipped, and the whole tutorial can be
	skipped. Finishing (or skipping) tells the server, which pays a one-time
	bonus and starts the random events.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = ReplicatedStorage:WaitForChild("Client")
local State = require(Client:WaitForChild("ClientState"))
local UI = require(Client:WaitForChild("UI"))

local gui = script.Parent
local C = UI.Colors

State.wait()

local INTRO = {
	"welcome to raise brady goo",
	"this is brady",
	"take care of him",
	"help him grow",
	"and eventually...",
	"make him the most archive person on roblox",
}

-- done(snapshot) returns true once the player has completed the step.
local STEPS = {
	{
		title = "1. FEED BRADY",
		text = "tap 🧒 Brady on the left, then 🍔 Feed, then FEED. (or use the kitchen in his room!)",
		done = function(start)
			return State.data.stats.feeds > start.feeds
		end,
	},
	{
		title = "2. PLAY WITH BRADY",
		text = "tap 🧒 Brady, then 🎮 Play, and pick a mini-game. playing gives Age XP and Goo Coins.",
		done = function(start)
			return State.data.stats.minigames > start.minigames
		end,
	},
	{
		title = "3. YOU EARNED GOO COINS!",
		text = "your coins are at the top of the screen. spend them in the 🛒 Shop on clothes, food and furniture.",
		auto = 5,
	},
	{
		title = "4. OPEN THE WARDROBE",
		text = "tap 👕 Closet on the left.",
		done = function()
			return State.current == "Wardrobe"
		end,
	},
	{
		title = "5. EQUIP CLOTHING",
		text = "tap Change next to Shirts and pick the Plain White Tee. he really needs a shirt.",
		done = function(start)
			return State.data.equipped.Shirt ~= nil and State.data.equipped.Shirt ~= start.shirt or State.data.equipped.Pants ~= start.pants
		end,
	},
	{
		title = "6. AGE HIM UP",
		text = "everything you do fills the AGE bar at the top. fill it and Brady grows up: new looks, new clothes, a bigger house. go make him archive.",
		final = true,
	},
}

----------------------------------------------------------------------
-- UI
----------------------------------------------------------------------
local dim = UI.frame(gui, { Name = "Dim", Color = C.dark, Transparency = 0.25, Corner = false, Visible = false, ZIndex = 1 })
dim.Active = true
local introLabel = UI.label(dim, "", { Name = "Intro", Size = UDim2.new(0.86, 0, 0, 160), Position = UDim2.fromScale(0.5, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), Font = UI.LoudFont, TextSize = 58, Color = C.goo, Outline = 5, ZIndex = 2 })
UI.autoScale(introLabel, "hud")
local skipAll = UI.button(dim, "skip tutorial", { Name = "SkipAll", Size = UDim2.fromOffset(200, 44), Position = UDim2.new(0.5, -100, 1, -70), Color = C.sub, TextSize = 18, ZIndex = 3 })

local card = UI.frame(gui, { Name = "Step", Size = UDim2.fromOffset(470, 150), Position = UDim2.new(1, -16, 1, -150), AnchorPoint = Vector2.new(1, 1), Color = C.bg, Corner = 18, Stroke = 4, StrokeColor = C.gold, Visible = false, ZIndex = 5 })
UI.autoScale(card, "hud")
local stepTitle = UI.label(card, "", { Name = "Title", Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 8), TextSize = 22, Color = C.gold, AlignX = Enum.TextXAlignment.Left, Outline = 2, ZIndex = 6 })
local stepText = UI.label(card, "", { Name = "Text", Size = UDim2.new(1, -24, 0, 62), Position = UDim2.fromOffset(12, 40), TextSize = 15, Font = UI.BodyFont, AlignX = Enum.TextXAlignment.Left, AlignY = Enum.TextYAlignment.Top, ZIndex = 6 })
local stepButton = UI.button(card, "skip step", { Name = "Next", Size = UDim2.fromOffset(150, 34), Position = UDim2.new(1, -162, 1, -42), Color = C.sub, TextSize = 15, Corner = 10, ZIndex = 6 })
local stepSkipAll = UI.button(card, "skip all", { Name = "SkipAll", Size = UDim2.fromOffset(110, 34), Position = UDim2.new(0, 12, 1, -42), Color = C.panel2, TextColor = C.sub, TextSize = 14, Corner = 10, ZIndex = 6 })
local arrow = UI.label(gui, "👈", { Name = "Arrow", Size = UDim2.fromOffset(70, 70), Position = UDim2.new(0, 190, 0.5, -30), TextSize = 56, ZIndex = 5 })
UI.autoScale(arrow, "hud")
arrow.Visible = false

local running = false
local skipRequested = false
local stepRequested = false

skipAll.Activated:Connect(function()
	skipRequested = true
end)
stepSkipAll.Activated:Connect(function()
	skipRequested = true
end)
stepButton.Activated:Connect(function()
	State.sound("click")
	stepRequested = true
end)

local function finish()
	dim.Visible = false
	card.Visible = false
	arrow.Visible = false
	running = false
	State.send("Tutorial", "Done")
end

local function run()
	if running then
		return
	end
	running = true
	skipRequested = false
	State.close()

	-- 1. intro lines
	dim.Visible = true
	for _, line in ipairs(INTRO) do
		if skipRequested then
			break
		end
		introLabel.Text = line
		UI.pop(introLabel, 0.6)
		State.sound("notify")
		local waited = 0
		while waited < 1.7 and not skipRequested do
			waited += task.wait(0.1)
		end
	end
	dim.Visible = false
	if skipRequested then
		finish()
		return
	end

	-- 2. guided steps
	card.Visible = true
	for _, step in ipairs(STEPS) do
		if skipRequested then
			break
		end
		stepRequested = false
		stepTitle.Text = step.title
		stepText.Text = step.text
		stepButton.Text = step.final and "LET'S GO!" or (step.auto and "got it" or "skip step")
		stepButton.BackgroundColor3 = (step.final or step.auto) and C.goo or C.sub
		arrow.Visible = step.done ~= nil
		UI.pop(card, 0.85)
		local start = {
			feeds = State.data.stats.feeds,
			minigames = State.data.stats.minigames,
			shirt = State.data.equipped.Shirt,
			pants = State.data.equipped.Pants,
		}
		local elapsed = 0
		while not skipRequested and not stepRequested do
			elapsed += task.wait(0.2)
			if step.done and step.done(start) then
				State.sound("good")
				break
			end
			if step.auto and elapsed >= step.auto then
				break
			end
			-- nudge the arrow so the player notices the menu buttons
			if arrow.Visible then
				arrow.Rotation = math.sin(elapsed * 6) * 12
			end
		end
	end
	finish()
end

-- Start for brand new players, and again if "Replay tutorial" is pressed.
State.on("tutorialDone", function(done)
	if done == false and not running then
		task.delay(1.5, function()
			if State.data.tutorialDone == false then
				run()
			end
		end)
	end
end)

