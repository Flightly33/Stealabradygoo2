--[[
	DailyUI
	Pops the Daily Reward page open when a reward is waiting: shortly after
	joining, and again if the day rolls over while the player is online.
	(New players finish the tutorial first.)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = ReplicatedStorage:WaitForChild("Client")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local State = require(Client:WaitForChild("ClientState"))
local DailySystem = require(Modules:WaitForChild("DailySystem"))

State.wait()

local offeredDay = nil

local function offer()
	local data = State.data
	local today = State.session.day
	if not today or offeredDay == today or not data.tutorialDone then
		return
	end
	if DailySystem.canClaim(data.daily, today) and State.current == nil then
		offeredDay = today
		State.open("Collection", "Daily")
		State.toast("your daily reward is ready!", "good")
	end
end

task.delay(4, offer)
State.onSession("day", function()
	task.delay(2, offer)
end)
State.on("tutorialDone", function(done)
	if done then
		task.delay(6, offer)
	end
end)
