--[[
	FashionServer
	Runs the fashion show on a loop for the whole server:

	    Idle -> Signup -> Runway (each Brady walks) -> Voting -> Results

	Scoring = judges (FashionSystem.judgeScore, based on the category) plus a
	big bonus for every real player vote. Bot contestants fill empty slots so
	a show is still fun when you are the only one online. Players can never
	vote for their own Brady and get exactly one vote.

	The winner earns Goo Coins and a temporary title shown on nameplates.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage.Modules
local ClothingSystem = require(Modules.ClothingSystem)
local Config = require(Modules.Config)
local Dialogue = require(Modules.Dialogue)
local FashionSystem = require(Modules.FashionSystem)
local InventorySystem = require(Modules.InventorySystem)
local Util = require(Modules.Util)

local FashionServer = {}

local S
local MAX_CONTESTANTS = 8
local BOT_NAMES = { "Rival Brady", "Thrift Lord", "Drip Goblin", "Archive Andy", "Brady Clone #2", "Lil Hanger", "Sock Sandal Steve" }

local state = {
	phase = "Idle",
	category = nil,
	endsAt = 0, -- server time the current phase ends
	nextAt = 0, -- server time the next show starts
	contestants = {},
	current = 0,
	results = nil,
}
local contestants = {} -- full records (the broadcast only gets a summary)
local votes = {} -- [voter Player] = contestant id
local nextId = 0

local function now()
	return Workspace:GetServerTimeNow()
end

local function summary()
	local list = {}
	for _, c in ipairs(contestants) do
		table.insert(list, { id = c.id, name = c.name, isBot = c.isBot, userId = c.player and c.player.UserId or 0 })
	end
	return {
		phase = state.phase,
		category = state.category,
		endsAt = state.endsAt,
		nextAt = state.nextAt,
		contestants = list,
		current = state.current,
		results = state.results,
	}
end

local function broadcast()
	S.Net.fireAll("FashionState", summary())
end

local function setPhase(phase, duration)
	state.phase = phase
	state.endsAt = now() + (duration or 0)
	broadcast()
end

local function findContestant(player)
	for index, c in ipairs(contestants) do
		if c.player == player then
			return c, index
		end
	end
	return nil
end

----------------------------------------------------------------------
-- Joining / leaving
----------------------------------------------------------------------
local function join(player)
	local data = S.Data.get(player)
	local session = S.Data.session(player)
	local rec = S.Brady.get(player)
	if not data or not session or not rec then
		return
	end
	if state.phase ~= "Signup" then
		S.Net.toast(player, "sign-ups open when the next show is announced", "bad")
		return
	end
	if findContestant(player) then
		return
	end
	if data.age < Config.FashionMinAge then
		S.Net.toast(player, "Brady can enter fashion shows at age " .. Config.FashionMinAge, "bad")
		return
	end
	if session.sleeping then
		S.Net.toast(player, "wake Brady up first!", "bad")
		return
	end
	if #contestants >= MAX_CONTESTANTS then
		S.Net.toast(player, "this show is full", "bad")
		return
	end
	nextId += 1
	local c = { id = "c" .. nextId, name = player.DisplayName, player = player, rec = rec, isBot = false, votes = 0, judge = 0 }
	table.insert(contestants, c)

	-- Brady heads backstage, the player gets a front-row spot.
	S.Care.mirror(player, false)
	rec.following = false
	session.following = false
	S.Data.syncSession(player, "following")
	rec.inShow = true
	S.Brady.setState(rec, "Idle")
	S.Brady.place(rec, S.Map.runway.backstage[#contestants])
	S.Brady.say(rec, Dialogue.pick("runway"))
	S.House.teleportTo(player, S.Map.runway.audience)
	S.Achievements.bump(player, "showsJoined", 1)
	S.Net.toast(player, "Brady is entered! Category: " .. state.category.name, "good")
	broadcast()
end

local function releaseContestant(c)
	if c.isBot then
		S.Brady.remove(c.rec)
	elseif c.player and c.player.Parent and S.Brady.get(c.player) == c.rec then
		c.rec.inShow = false
		S.Brady.setState(c.rec, "Idle")
		S.Brady.sendHome(c.player)
	end
end

local function leave(player)
	local c, index = findContestant(player)
	if not c or state.phase ~= "Signup" then
		return
	end
	table.remove(contestants, index)
	releaseContestant(c)
	broadcast()
end

local function vote(player, contestantId)
	if state.phase ~= "Voting" or type(contestantId) ~= "string" then
		return
	end
	for _, c in ipairs(contestants) do
		if c.id == contestantId then
			if c.player == player then
				S.Net.toast(player, "you can't vote for your own Brady!", "bad")
				return
			end
			votes[player] = contestantId
			S.Net.toast(player, "voted for " .. c.name, "good")
			return
		end
	end
end

----------------------------------------------------------------------
-- Bots
----------------------------------------------------------------------
local function botOutfit(age)
	local equipped = {}
	for _, slot in ipairs({ "Shirt", "Pants", "Shoes", "Jacket", "Hat", "Glasses", "Accessory" }) do
		local chance = (slot == "Shirt" or slot == "Pants" or slot == "Shoes") and 1 or 0.55
		if math.random() < chance then
			local options = {}
			for _, item in ipairs(ClothingSystem.BySlot[slot]) do
				if item.age <= age and not item.secret and item.rarity ~= "Grail" and (item.rarity ~= "Archive" or math.random() < 0.15) then
					table.insert(options, item)
				end
			end
			local pick = Util.pick(options)
			if pick then
				equipped[slot] = pick.id
			end
		end
	end
	return equipped
end

local function addBots()
	local totalAge, humans = 0, 0
	for _, c in ipairs(contestants) do
		local data = c.player and S.Data.get(c.player)
		if data then
			totalAge += data.age
			humans += 1
		end
	end
	local botAge = math.max(Config.FashionMinAge, math.floor(totalAge / math.max(1, humans)))
	local names = table.clone(BOT_NAMES)
	while #contestants < 3 do
		nextId += 1
		local name = table.remove(names, math.random(1, #names))
		local equipped = botOutfit(botAge)
		local rec = S.Brady.spawnNPC({ age = botAge, equipped = equipped, ownerName = name }, S.Map.runway.backstage[#contestants + 1])
		rec.inShow = true
		table.insert(contestants, { id = "c" .. nextId, name = name, rec = rec, isBot = true, equipped = equipped, votes = 0, judge = 0 })
	end
end

----------------------------------------------------------------------
-- The show
----------------------------------------------------------------------
local function alive(c)
	return c.isBot or (c.player and c.player.Parent ~= nil and S.Brady.get(c.player) == c.rec)
end

local function equippedOf(c)
	if c.isBot then
		return c.equipped
	end
	local data = S.Data.get(c.player)
	return data and data.equipped or {}
end

local function runwayWalk(index, c)
	local runway = S.Map.runway
	local rec = c.rec
	S.Brady.setState(rec, "Idle")
	S.Brady.place(rec, runway.stageStart)
	local out = S.Brady.walkTo(rec, runway.runwayEnd, 9)
	task.wait(out + 0.2)
	if not alive(c) then
		return
	end
	-- Strike a pose at the end of the runway.
	local pose = "Peace"
	if not c.isBot then
		local data = S.Data.get(c.player)
		local session = S.Data.session(c.player)
		if data and session then
			local poses = InventorySystem.unlockedPoses(data, session.passes)
			pose = poses[#poses].id
		end
	end
	S.Brady.act(rec, "Pose", 2.2, pose)
	task.wait(2.4)
	if not alive(c) then
		return
	end
	local back = S.Brady.walkTo(rec, runway.stageStart.Position, 11)
	task.wait(back + 0.2)
	if alive(c) then
		S.Brady.place(rec, runway.lineup[index])
	end
end

local function runShow()
	local category = Util.pick(FashionSystem.Categories)
	state.category = { id = category.id, name = category.name, hint = category.hint, title = category.title }
	state.results = nil
	state.current = 0
	contestants = {}
	votes = {}
	setPhase("Signup", Config.FashionSignup)
	S.Net.fireAll("Notify", { text = "FASHION SHOW STARTING!", sub = category.name .. "  •  open the Fashion Show menu to enter", kind = "event", sound = "event" })
	task.wait(Config.FashionSignup)

	-- Drop anyone who left during sign-up.
	for index = #contestants, 1, -1 do
		if not alive(contestants[index]) then
			table.remove(contestants, index)
		end
	end
	if #contestants == 0 then
		state.phase = "Idle"
		return -- nobody entered: skip this one
	end
	addBots()

	-- RUNWAY
	setPhase("Runway", #contestants * Config.FashionWalkTime)
	for index, c in ipairs(contestants) do
		if alive(c) then
			state.current = index
			state.endsAt = now() + (#contestants - index + 1) * Config.FashionWalkTime
			broadcast()
			runwayWalk(index, c)
		end
	end
	state.current = 0

	-- VOTING
	setPhase("Voting", Config.FashionVoting)
	task.wait(Config.FashionVoting)

	-- RESULTS
	for voter, contestantId in pairs(votes) do
		if voter.Parent then
			for _, c in ipairs(contestants) do
				if c.id == contestantId then
					c.votes += 1
				end
			end
		end
	end
	local best = 1
	for _, c in ipairs(contestants) do
		c.judge = alive(c) and FashionSystem.judgeScore(category.id, equippedOf(c)) or 0
		best = math.max(best, c.judge)
	end
	for _, c in ipairs(contestants) do
		c.score = alive(c) and FashionSystem.finalScore(c.judge, c.votes, best) or -1
	end
	table.sort(contestants, function(a, b)
		return a.score > b.score
	end)
	local results = {}
	for place, c in ipairs(contestants) do
		table.insert(results, { id = c.id, name = c.name, isBot = c.isBot, votes = c.votes, score = math.floor(c.score), place = place })
	end
	state.results = results

	local winner = contestants[1]
	for place, c in ipairs(contestants) do
		if not c.isBot and alive(c) then
			local player = c.player
			local data = S.Data.get(player)
			if place == 1 then
				local coins = S.Currency.add(player, S.Currency.scaled(player, Config.FashionWinCoins), "fashion")
				local xp = S.Age.addXP(player, 150)
				data.title = { name = category.title, expires = os.time() + Config.TitleDuration }
				S.Data.sync(player, "title")
				S.Achievements.bump(player, "showsWon", 1)
				S.Net.notify(player, { text = "YOU WON " .. string.upper(category.name) .. "!", sub = "+" .. coins .. " Goo Coins  +" .. xp .. " XP  •  title: " .. category.title, kind = "grail", sound = "grail", big = true })
				S.Brady.rebuild(player) -- shows the new title on his nameplate
				S.Social.refreshTitle(player)
				S.Brady.act(c.rec, "Celebrate", 4)
				S.Brady.say(c.rec, Dialogue.pick("showWin"))
				S.Net.fireAll("Effect", "Confetti", { userId = player.UserId })
			else
				local coins = S.Currency.add(player, S.Currency.scaled(player, Config.FashionJoinCoins), "fashion")
				local xp = S.Age.addXP(player, 60)
				S.Net.notify(player, { text = "PLACE #" .. place, sub = "+" .. coins .. " Goo Coins  +" .. xp .. " XP  •  " .. winner.name .. " won", kind = "info", sound = "notify" })
				S.Brady.say(c.rec, Dialogue.pick("showLose"))
			end
		end
	end
	if winner.isBot then
		S.Brady.act(winner.rec, "Celebrate", 4)
	end
	setPhase("Results", Config.FashionResults)
	task.wait(Config.FashionResults)

	for _, c in ipairs(contestants) do
		releaseContestant(c)
	end
	contestants = {}
	votes = {}
end

function FashionServer.start()
	task.spawn(function()
		while true do
			state.phase = "Idle"
			state.nextAt = now() + Config.FashionInterval
			state.contestants = {}
			broadcast()
			task.wait(Config.FashionInterval)
			if #Players:GetPlayers() > 0 then
				local ok, err = pcall(runShow)
				if not ok then
					warn("[FashionServer] show error: " .. tostring(err))
					for _, c in ipairs(contestants) do
						pcall(releaseContestant, c)
					end
					contestants = {}
					votes = {}
				end
			end
		end
	end)

	-- The physical sign-up kiosk next to the runway.
	local signup = S.Map.runway.signup
	if signup then
		signup.Triggered:Connect(function(player)
			if S.Data.get(player) then
				if state.phase == "Signup" then
					join(player)
				else
					S.Net.fire(player, "OpenPanel", "Fashion")
				end
			end
		end)
	end
end

function FashionServer.init(services)
	S = services
	S.Net.on("Fashion", function(player, _data, action, arg)
		if action == "Join" then
			join(player)
		elseif action == "Leave" then
			leave(player)
		elseif action == "Vote" then
			vote(player, arg)
		elseif action == "Sync" then
			-- a client that just finished loading asks for the current state
			S.Net.fire(player, "FashionState", summary())
		end
	end, 5)
end

function FashionServer.playerAdded(player)
	S.Net.fire(player, "FashionState", summary())
end

function FashionServer.playerRemoving(player)
	votes[player] = nil
	local _, index = findContestant(player)
	if index and state.phase == "Signup" then
		table.remove(contestants, index)
	end
	-- During the show the contestant is skipped by alive() instead.
end

function FashionServer.phase()
	return state.phase
end

return FashionServer
