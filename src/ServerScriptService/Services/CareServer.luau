--[[
	CareServer
	Taking care of Brady: feeding, cleaning, sleeping, toys, the mirror and
	follow mode, plus the slow decay of his four meters.

	Every action is checked here (does the player own the food, is the meter
	already full, is Brady asleep / busy, is the cooldown over) before any XP
	or Goo Coins are given, so spamming the remote earns nothing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local Config = require(Modules.Config)
local CurrencySystem = require(Modules.CurrencySystem)
local Dialogue = require(Modules.Dialogue)
local FoodSystem = require(Modules.FoodSystem)
local InventorySystem = require(Modules.InventorySystem)

local CareServer = {}

local S
local cooldowns = {} -- [player][key] = os.clock() of last use
local lowWarned = {} -- [player][meter] = true once warned
local poseIndex = {} -- [player] = index into unlocked poses (fashion podium)
local meterClock, sleepClock = 0, 0

local function ready(player, key, seconds)
	local list = cooldowns[player]
	if not list then
		list = {}
		cooldowns[player] = list
	end
	local now = os.clock()
	if list[key] and now - list[key] < seconds then
		return false
	end
	list[key] = now
	return true
end

local function addMeter(data, key, amount)
	data.meters[key] = math.clamp(data.meters[key] + amount, 0, 100)
end

-- Pays XP + coins for an activity and shows the little reward popup.
local function reward(player, baseXP, baseCoins)
	local xp = S.Age.addXP(player, baseXP)
	local coins = baseCoins > 0 and S.Currency.add(player, S.Currency.scaled(player, baseCoins), "care") or 0
	S.Net.fire(player, "Effect", "Reward", { xp = xp, coins = coins })
	return xp, coins
end

-- Common "can Brady do something right now?" check.
local function available(player, allowAsleep)
	local rec = S.Brady.get(player)
	local session = S.Data.session(player)
	if not rec or not session or not rec.model then
		return nil
	end
	if rec.inShow then
		S.Net.toast(player, "Brady is on the runway right now", "bad")
		return nil
	end
	if session.sleeping and not allowAsleep then
		S.Net.toast(player, "shhh... Brady is asleep", "bad")
		return nil
	end
	if S.Brady.isBusy(rec) then
		S.Net.toast(player, "Brady is busy", "bad")
		return nil
	end
	return rec, session
end

----------------------------------------------------------------------
-- FEED
----------------------------------------------------------------------
local function feed(player, data, foodId)
	local food = type(foodId) == "string" and FoodSystem.get(foodId)
	if not food then
		return
	end
	local rec = available(player)
	if not rec then
		return
	end
	if data.age < (food.minAge or 1) then
		S.Net.toast(player, food.name .. " unlocks at age " .. food.minAge, "bad")
		return
	end
	if data.meters.hunger >= 97 then
		S.Brady.say(rec, Dialogue.pick("full"))
		S.Net.toast(player, "Brady is full!", "bad")
		return
	end
	if not food.free then
		if (data.food[foodId] or 0) <= 0 then
			S.Net.toast(player, "you're out of " .. food.name .. " - buy more in the Shop", "bad")
			return
		end
		data.food[foodId] -= 1
	end

	local xp = food.xp
	local line = Dialogue.pick("fed")
	if food.mystery then
		-- Goofy mystery food: could be amazing, could be a mistake.
		xp = math.random(5, 120)
		line = Dialogue.pick(xp >= 60 and "mysteryGood" or "mysteryBad")
	end
	addMeter(data, "hunger", food.hunger)
	rec.model:SetAttribute("EatIcon", food.icon)
	S.Brady.act(rec, "Eat", 3.2)
	S.Brady.say(rec, line)
	S.Data.sync(player, "food", "meters")
	reward(player, xp, CurrencySystem.Rewards.Feed)
	S.Achievements.bump(player, "feeds", 1)
	S.Events.hook(player, "feed")
end

----------------------------------------------------------------------
-- CLEAN
----------------------------------------------------------------------
local function shower(player, data)
	local rec = available(player)
	if not rec then
		return
	end
	if not S.Brady.isHome(player) then
		S.Net.toast(player, "Brady needs to be home to shower", "bad")
		return
	end
	if data.meters.clean >= 95 then
		S.Brady.say(rec, Dialogue.pick("alreadyClean"))
		S.Net.toast(player, "Brady is already clean", "bad")
		return
	end
	local travel = S.Brady.performAt(rec, S.House.stationCFrame(player, "Shower"), "Shower", 4)
	task.delay(travel, function()
		S.House.runShower(player, 4)
	end)
	addMeter(data, "clean", 65)
	S.Brady.say(rec, Dialogue.pick("clean"))
	S.Data.sync(player, "meters")
	reward(player, 30, CurrencySystem.Rewards.Shower)
	S.Achievements.bump(player, "cleans", 1)
end

local function brushHair(player, data, atSink)
	local rec = available(player)
	if not rec then
		return
	end
	if not ready(player, "brush", 15) then
		S.Net.toast(player, "his hair is still perfect", "bad")
		return
	end
	if atSink and S.Brady.isHome(player) then
		S.Brady.performAt(rec, S.House.stationCFrame(player, "Sink"), "Brush", 2.6)
	else
		S.Brady.act(rec, "Brush", 2.6)
	end
	addMeter(data, "clean", 18)
	S.Brady.say(rec, Dialogue.pick("brushed"))
	S.Data.sync(player, "meters")
	reward(player, 14, CurrencySystem.Rewards.BrushHair)
	S.Achievements.bump(player, "cleans", 1)
	S.Events.hook(player, "brush")
end

local function cleanShoes(player, data, atMat)
	local rec = available(player)
	if not rec then
		return
	end
	if not data.equipped.Shoes and not data.equipped.Outfit then
		S.Net.toast(player, "he isn't wearing shoes??", "bad")
		return
	end
	if not ready(player, "shoes", 15) then
		S.Net.toast(player, "his shoes are already spotless", "bad")
		return
	end
	if atMat and S.Brady.isHome(player) then
		S.Brady.performAt(rec, S.House.stationCFrame(player, "ShoeMat"), "ShoeClean", 2.6)
	else
		S.Brady.act(rec, "ShoeClean", 2.6)
	end
	addMeter(data, "clean", 14)
	S.Brady.say(rec, Dialogue.pick("shoes"))
	S.Data.sync(player, "meters")
	reward(player, 12, CurrencySystem.Rewards.CleanShoes)
	S.Achievements.bump(player, "cleans", 1)
end

-- Changing his clothes also freshens him up a little (with a cooldown).
function CareServer.onClothesChanged(player)
	local data = S.Data.get(player)
	if not data or not ready(player, "clothes", 45) then
		return
	end
	addMeter(data, "clean", 6)
	S.Data.sync(player, "meters")
	reward(player, 8, CurrencySystem.Rewards.ChangeClothes)
	S.Achievements.bump(player, "cleans", 1)
end

----------------------------------------------------------------------
-- SLEEP
----------------------------------------------------------------------
function CareServer.wake(player, silent)
	local rec = S.Brady.get(player)
	local session = S.Data.session(player)
	if not rec or not session or not session.sleeping then
		return
	end
	session.sleeping = false
	S.Data.syncSession(player, "sleeping")
	S.Brady.setState(rec, "Idle")
	-- Hop off the bed onto the floor next to it.
	local h = S.House.size(player) / 2
	S.Brady.place(rec, S.House.origin(player) * CFrame.lookAt(Vector3.new(-h + 8.5, 0, -h + 5.2), Vector3.new(0, 0, 0)))
	if not silent then
		S.Brady.say(rec, Dialogue.pick("wake"))
	end
end

local function sleep(player, data)
	local rec, session = available(player)
	if not rec then
		return
	end
	if not S.Brady.isHome(player) then
		S.Net.toast(player, "Brady needs to be home to sleep", "bad")
		return
	end
	if data.meters.energy >= 92 then
		S.Brady.say(rec, Dialogue.pick("notTired"))
		S.Net.toast(player, "Brady isn't tired", "bad")
		return
	end
	rec.following = false
	session.following = false
	session.sleeping = true
	S.Data.syncSession(player, "sleeping", "following")
	S.Brady.performAt(rec, S.House.stationCFrame(player, "Bed"), "Sleep", nil, nil, true)
	S.Brady.say(rec, Dialogue.pick("sleep"))
	S.Achievements.bump(player, "sleeps", 1)
end

function CareServer.toggleSleep(player)
	local data = S.Data.get(player)
	local session = S.Data.session(player)
	if not data or not session then
		return
	end
	if session.sleeping then
		CareServer.wake(player)
	else
		sleep(player, data)
	end
end

----------------------------------------------------------------------
-- TOYS / POSES / MIRROR / FOLLOW
----------------------------------------------------------------------
function CareServer.playToy(player, _furnitureId)
	local data = S.Data.get(player)
	local rec = available(player)
	if not rec or not data then
		return
	end
	if data.meters.energy < 5 then
		S.Brady.say(rec, Dialogue.pick("tired"))
		S.Net.toast(player, "Brady is too tired to play", "bad")
		return
	end
	if not ready(player, "toy", 25) then
		S.Net.toast(player, "give him a second!", "bad")
		return
	end
	addMeter(data, "fun", 22)
	addMeter(data, "energy", -4)
	S.Brady.act(rec, "Play", 3)
	S.Brady.say(rec, Dialogue.pick("play"))
	S.Data.sync(player, "meters")
	reward(player, 16, CurrencySystem.Rewards.PlayToy)
end

-- Mirror mode: Brady stands at the mirror and holds poses.
function CareServer.mirror(player, enter)
	local session = S.Data.session(player)
	if not session then
		return
	end
	if enter then
		local rec = available(player)
		if not rec then
			return
		end
		session.mirror = true
		local spot = S.House.stationCFrame(player, "Mirror")
		S.Brady.performAt(rec, spot, "Mirror", nil, nil, true)
		S.Brady.say(rec, Dialogue.pick("mirror"))
		S.Net.fire(player, "OpenPanel", "Mirror", spot)
	else
		local rec = S.Brady.get(player)
		if session.mirror and rec then
			session.mirror = false
			if rec.persist and not session.sleeping then
				S.Brady.setState(rec, "Idle")
			end
		end
	end
end

local function setPose(player, data, poseId)
	local session = S.Data.session(player)
	local rec = S.Brady.get(player)
	if type(poseId) ~= "string" or not session or not rec or session.sleeping or rec.inShow then
		return
	end
	if not InventorySystem.isPoseUnlocked(data, session.passes, poseId) then
		S.Net.toast(player, "that pose is locked", "bad")
		return
	end
	if session.mirror then
		S.Brady.setState(rec, "Pose", poseId) -- holds until another pose / exit
	elseif not S.Brady.isBusy(rec) then
		S.Brady.act(rec, "Pose", 3.5, poseId)
	end
	if ready(player, "poseFun", 20) then
		addMeter(data, "fun", 4)
		S.Data.sync(player, "meters")
	end
end

-- The fashion display podium cycles through unlocked poses.
function CareServer.podiumPose(player)
	local data = S.Data.get(player)
	local rec, session = available(player)
	if not rec or not data then
		return
	end
	local poses = InventorySystem.unlockedPoses(data, session.passes)
	local index = (poseIndex[player] or 0) % #poses + 1
	poseIndex[player] = index
	S.Brady.performAt(rec, S.House.stationCFrame(player, "Podium"), "Pose", 5, poses[index].id)
	S.Brady.say(rec, Dialogue.pick("pose"))
end

local function follow(player, data, enabled)
	local rec, session = available(player)
	if not rec then
		return
	end
	if enabled == true then
		if data.age < Config.FollowMinAge then
			S.Net.toast(player, "Brady can go outside at age " .. Config.FollowMinAge, "bad")
			return
		end
		S.Brady.setFollowing(player, true)
	elseif session.following then
		S.Brady.setFollowing(player, false)
	end
end

-- Teleport a following Brady right next to the player.
local function call(player)
	local rec, session = available(player)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not rec or not hrp then
		return
	end
	if not session.following then
		S.Net.toast(player, "turn on 'Follow me' first", "bad")
		return
	end
	local spot = hrp.CFrame * CFrame.new(3, -3, 0)
	S.Brady.place(rec, CFrame.lookAt(spot.Position, spot.Position + hrp.CFrame.LookVector))
end

-- Entry point used by the station prompts in the house.
function CareServer.perform(player, action, arg)
	local data = S.Data.get(player)
	if not data then
		return
	end
	if action == "Feed" then
		feed(player, data, arg)
	elseif action == "Shower" then
		shower(player, data)
	elseif action == "BrushHair" then
		brushHair(player, data, true)
	elseif action == "CleanShoes" then
		cleanShoes(player, data, true)
	end
end

----------------------------------------------------------------------
-- Remote + ticking
----------------------------------------------------------------------
local function onCare(player, data, action, arg)
	if action == "Feed" then
		feed(player, data, arg)
	elseif action == "Shower" then
		shower(player, data)
	elseif action == "BrushHair" then
		brushHair(player, data, true)
	elseif action == "CleanShoes" then
		cleanShoes(player, data, true)
	elseif action == "Sleep" then
		if not S.Data.session(player).sleeping then
			sleep(player, data)
		end
	elseif action == "Wake" then
		CareServer.wake(player)
	elseif action == "Follow" then
		follow(player, data, arg)
	elseif action == "Call" then
		call(player)
	end
end

local function warnLow(player, data, rec)
	local warned = lowWarned[player]
	if not warned then
		warned = {}
		lowWarned[player] = warned
	end
	local lines = { hunger = "hungry", clean = "dirty", energy = "tired", fun = "bored" }
	for meter, key in pairs(lines) do
		local value = data.meters[meter]
		if value < 20 and not warned[meter] then
			warned[meter] = true
			S.Net.toast(player, "Brady is " .. (meter == "fun" and "bored" or key) .. "!", "bad")
			if rec and rec.state == "Idle" then
				S.Brady.say(rec, Dialogue.pick(key))
			end
		elseif value > 40 then
			warned[meter] = nil
		end
	end
end

-- Called once a second from Main.
function CareServer.tick()
	meterClock += 1
	sleepClock += 1
	local doMeters = meterClock >= Config.MeterTick
	local doSleep = sleepClock >= Config.SleepTick
	if doMeters then
		meterClock = 0
	end
	if doSleep then
		sleepClock = 0
	end
	if not doMeters and not doSleep then
		return
	end
	for player, data, session in S.Data.each() do
		local rec = S.Brady.get(player)
		if doSleep and session.sleeping then
			addMeter(data, "energy", Config.SleepEnergyPerTick)
			S.Age.addXP(player, Config.SleepXPPerTick)
			S.Data.sync(player, "meters")
			if data.meters.energy >= 100 then
				CareServer.wake(player)
				S.Net.toast(player, "Brady woke up fully rested!", "good")
			end
		end
		if doMeters then
			local seconds = Config.MeterTick
			local factor = session.sleeping and 0.4 or 1
			addMeter(data, "hunger", -Config.MeterDecay.hunger * seconds * factor)
			addMeter(data, "clean", -Config.MeterDecay.clean * seconds * factor)
			addMeter(data, "fun", -Config.MeterDecay.fun * seconds * factor)
			if not session.sleeping then
				addMeter(data, "energy", -Config.MeterDecay.energy * seconds)
			end
			S.Data.sync(player, "meters")
			warnLow(player, data, rec)
		end
	end
end

function CareServer.init(services)
	S = services
	S.Net.on("Care", onCare, 6)
	S.Net.on("SetPose", setPose, 5)
	S.Net.on("Mirror", function(player, _data, enter)
		CareServer.mirror(player, enter == true)
	end, 4)
end

function CareServer.playerRemoving(player)
	cooldowns[player] = nil
	lowWarned[player] = nil
	poseIndex[player] = nil
end

-- Exposed so mini-games can use / refill meters.
CareServer.addMeter = addMeter

return CareServer
