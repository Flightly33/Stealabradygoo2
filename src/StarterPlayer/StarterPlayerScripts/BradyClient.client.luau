--[[
	BradyClient
	Everything visual about Bradys that only needs to exist on each player's
	screen: the procedural animation, speech bubbles, emote pop-ups, confetti
	and the low-graphics switch.
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Client = ReplicatedStorage:WaitForChild("Client")
local State = require(Client:WaitForChild("ClientState"))
local Animator = require(Client:WaitForChild("BradyAnimator"))

local localPlayer = Players.LocalPlayer
local TAG = "BradyGoo"
local FX_TAG = "BradyFx"

local rgb = Color3.fromRGB

Animator.start()

local function isMine(model)
	return model:GetAttribute("OwnerUserId") == localPlayer.UserId
end

----------------------------------------------------------------------
-- Billboards: speech bubbles + emoji emotes
----------------------------------------------------------------------
local function headOf(model)
	return model:FindFirstChild("Head")
end

local function showBubble(model)
	local head = headOf(model)
	local text = model:GetAttribute("SayText")
	if not head or type(text) ~= "string" or text == "" then
		return
	end
	-- Idle chatter can be switched off in Settings.
	if model:GetAttribute("SayIdle") and State.setting("chatter") == false then
		return
	end
	local old = head:FindFirstChild("Bubble")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Bubble"
	gui.Size = UDim2.fromScale(9, 1.9)
	gui.StudsOffsetWorldSpace = Vector3.new(0, head.Size.Y / 2 + 4.6, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.4, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = rgb(30, 27, 48)
	stroke.Parent = frame
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.92, 0.8)
	label.Position = UDim2.fromScale(0.04, 0.1)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = rgb(30, 27, 48)
	label.Parent = frame
	frame.Parent = gui
	gui.Parent = head
	Debris:AddItem(gui, 3.4)
end

-- A big emoji that floats up from his head.
local function emote(model, text, seconds)
	local head = headOf(model)
	if not head then
		return nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Emote"
	gui.Size = UDim2.fromScale(3, 3)
	gui.StudsOffsetWorldSpace = Vector3.new(1.6, head.Size.Y / 2 + 1, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	gui.Parent = head
	TweenService:Create(gui, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = Vector3.new(1.6, head.Size.Y / 2 + 3.4, 0),
	}):Play()
	Debris:AddItem(gui, seconds)
	return gui
end

local function confetti(model)
	local root = model.PrimaryPart
	if not root or State.setting("lowGfx") then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Confetti"
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(1.4, 2.4)
	emitter.Speed = NumberRange.new(22, 38)
	emitter.SpreadAngle = Vector2.new(38, 38)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0, -42, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-260, 260)
	emitter.Size = NumberSequence.new(0.45, 0.25)
	emitter.LightEmission = 0.4
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rgb(255, 90, 90)),
		ColorSequenceKeypoint.new(0.3, rgb(255, 220, 80)),
		ColorSequenceKeypoint.new(0.6, rgb(126, 232, 74)),
		ColorSequenceKeypoint.new(1, rgb(100, 200, 255)),
	})
	emitter.Parent = root
	emitter:Emit(70)
	Debris:AddItem(emitter, 3)
end

----------------------------------------------------------------------
-- Reactions to state changes (the animator tells us when a state starts)
----------------------------------------------------------------------
local EMOTES = {
	Sleep = { "💤", 30 },
	Dance = { "🎵", 3 },
	Embarrassed = { "💦", 2.5 },
	Shower = { "🫧", 4 },
	Brush = { "✨", 2.5 },
	ShoeClean = { "✨", 2.5 },
	Play = { "⭐", 3 },
	Mirror = { "😎", 2.5 },
	Excited = { "❗", 2 },
}

Animator.onStateChanged(function(model, state, old)
	local head = headOf(model)
	if head and old then
		local previous = head:FindFirstChild("Emote")
		if previous and (old == "Sleep" or state == "Idle") then
			previous:Destroy()
		end
	end
	local mine = isMine(model)
	if state == "Eat" then
		emote(model, model:GetAttribute("EatIcon") or "🍽️", 3)
		if mine then
			State.sound("eat")
		end
	elseif state == "Celebrate" then
		confetti(model)
	elseif state == "Trip" then
		emote(model, "💥", 1.2)
		if mine then
			State.sound("trip")
		end
	elseif state == "GrailSpawn" then
		emote(model, "🏆", 2.6)
		confetti(model)
		if mine then
			State.sound("grail")
		end
	elseif state == "Shower" and mine then
		State.sound("splash")
	end
	local def = EMOTES[state]
	if def then
		emote(model, def[1], def[2])
	end
end)

----------------------------------------------------------------------
-- Per-model hooks
----------------------------------------------------------------------
local hooked = {}

local function hook(model)
	if hooked[model] then
		return
	end
	hooked[model] = true
	model:GetAttributeChangedSignal("SaySeq"):Connect(function()
		showBubble(model)
	end)
	model.Destroying:Connect(function()
		hooked[model] = nil
	end)
end

for _, model in ipairs(CollectionService:GetTagged(TAG)) do
	hook(model)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(hook)

-- Server-triggered world effects.
State.listen("Effect", function(kind, payload)
	if kind == "Confetti" and type(payload) == "table" then
		for _, model in ipairs(CollectionService:GetTagged(TAG)) do
			if model:GetAttribute("OwnerUserId") == payload.userId then
				confetti(model)
			end
		end
	end
end)

----------------------------------------------------------------------
-- Low graphics mode: fewer animated Bradys, no clothing particles
----------------------------------------------------------------------
local function applyFx(instance, low)
	if instance:IsA("ParticleEmitter") or instance:IsA("PointLight") then
		instance.Enabled = not low
	end
end

local function applyLowGraphics(low)
	Animator.setLowGraphics(low == true)
	for _, instance in ipairs(CollectionService:GetTagged(FX_TAG)) do
		applyFx(instance, low == true)
	end
end

CollectionService:GetInstanceAddedSignal(FX_TAG):Connect(function(instance)
	applyFx(instance, State.setting("lowGfx") == true)
end)

State.on("settings", function(settings)
	applyLowGraphics(settings and settings.lowGfx)
end)
