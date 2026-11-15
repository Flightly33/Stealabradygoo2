--[[
	MinigameServer
	"Play with Brady". The UI mini-games run on the client, so the server
	treats the reported score as a claim to verify:

	  * a round must be STARTED through the server (energy is charged, a
	    one-time token is issued, a cooldown applies)
	  * the finish call must present that token, the round must have lasted a
	    believable time, and the score is clamped to the game's maximum
	  * rewards are computed here from the clamped score

	The Goo Obby is fully server-side: the server sees the start pad, every
	checkpoint in order and the finish pad being touched.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage.Modules
local AgeSystem = require(Modules.AgeSystem)
local Config = require(Modules.Config)
local Dialogue = require(Modules.Dialogue)
local MinigameSystem = require(Modules.MinigameSystem)

local MinigameServer = {}

local S
local sessions = {} -- [player] = { def, token, startedAt, bonus }
local lastFinish = {} -- [player] = os.clock()
local obbyRuns = {} -- [player] = { startedAt, checkpoint, serverStart }

local function nearArcade(player)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local arcade = S.Map.arcade
	return hrp ~= nil and (hrp.Position - arcade.center).Magnitude <= arcade.radius
end

-- Shared "is Brady able to play right now?" check. Returns a reason on failure.
local function canPlay(player, data, def)
	local session = S.Data.session(player)
	local rec = S.Brady.get(player)
	if not session or not rec then
		return "still loading..."
	end
	if data.age < def.minAge then
		return def.name .. " unlocks at age " .. def.minAge
	end
	if session.sleeping then
		return "Brady is asleep"
	end
	if rec.inShow then
		return "Brady is in a fashion show"
	end
	if data.meters.energy < Config.MinigameEnergyCost then
		return "Brady is too tired - put him to bed!"
	end
	if os.clock() - (lastFinish[player] or -100) < Config.MinigameCooldown then
		return "catch your breath for a second"
	end
	return nil
end

-- Pays out a finished round. Returns coins, xp, ratio.
local function payout(player, data, def, score, bonus)
	score = math.clamp(math.floor(score), 0, def.maxScore)
	local multiplier = AgeSystem.rewardMultiplier(data.age, data.rebirths) * bonus
	local coins, xp, ratio = MinigameSystem.rewards(def, score, multiplier)
	S.Care.addMeter(data, "fun", 25)
	S.Data.sync(player, "meters")
	coins = S.Currency.add(player, coins, "minigame")
	xp = S.Age.addXP(player, xp * bonus)
	S.Achievements.bump(player, "minigames", 1)
	if ratio >= 0.95 then
		S.Achievements.bump(player, "perfectGames", 1)
	end
	local rec = S.Brady.get(player)
	if rec then
		rec.busyUntil = 0
		if ratio >= 0.6 then
			S.Brady.act(rec, "Celebrate", 2.5)
			S.Brady.say(rec, Dialogue.pick("win"))
		else
			S.Brady.act(rec, "Idle", 0.1)
			S.Brady.say(rec, Dialogue.pick("lose"))
		end
	end
	lastFinish[player] = os.clock()
	return coins, xp, ratio
end

----------------------------------------------------------------------
-- UI mini-games
----------------------------------------------------------------------
local function start(player, data, gameId)
	local def = type(gameId) == "string" and MinigameSystem.get(gameId)
	if not def or def.world then
		return { ok = false, reason = "unknown game" }
	end
	if sessions[player] then
		sessions[player] = nil -- abandoning a round forfeits it
	end
	local reason = canPlay(player, data, def)
	if reason then
		return { ok = false, reason = reason }
	end
	S.Care.addMeter(data, "energy", -Config.MinigameEnergyCost)
	S.Data.sync(player, "meters")
	local bonus = nearArcade(player) and Config.ArcadeBonus or 1
	local token = HttpService:GenerateGUID(false)
	sessions[player] = { def = def, token = token, startedAt = os.clock(), bonus = bonus }
	local rec = S.Brady.get(player)
	if rec then
		S.Brady.act(rec, "Play", def.duration + 3)
		S.Brady.say(rec, Dialogue.pick("play"))
	end
	return { ok = true, token = token, bonus = bonus, duration = def.duration }
end

local function finish(player, data, token, score)
	local session = sessions[player]
	if not session or type(token) ~= "string" or token ~= session.token then
		return { ok = false, reason = "that round already ended" }
	end
	sessions[player] = nil
	local def = session.def
	if type(score) ~= "number" or score ~= score then
		score = 0
	end
	local elapsed = os.clock() - session.startedAt
	if elapsed < def.minTime then
		-- Finished impossibly fast (or quit early): only the minimum reward.
		score = 0
	elseif elapsed > def.duration + 45 then
		return { ok = false, reason = "that round timed out" }
	end
	local coins, xp, ratio = payout(player, data, def, score, session.bonus)
	return { ok = true, coins = coins, xp = xp, ratio = ratio, bonus = session.bonus }
end

----------------------------------------------------------------------
-- Goo Obby (world mini-game)
----------------------------------------------------------------------
local function playerFromHit(hit)
	local character = hit and hit.Parent
	return character and Players:GetPlayerFromCharacter(character) or nil
end

local function obbyTeleport(player, cframe)
	local character = player.Character
	if character and character.PrimaryPart then
		character:PivotTo(cframe * CFrame.new(0, 4, 0))
	end
end

local function setupObby()
	local obby = S.Map.obby
	local def = MinigameSystem.get("obby")
	local total = #obby.checkpoints

	obby.start.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		local data = player and S.Data.get(player)
		if not data or obbyRuns[player] then
			return
		end
		local reason = canPlay(player, data, def)
		if reason then
			if os.clock() - (lastFinish[player] or -100) >= Config.MinigameCooldown then
				lastFinish[player] = os.clock() - Config.MinigameCooldown + 2 -- throttle the message
				S.Net.toast(player, reason, "bad")
			end
			return
		end
		S.Care.addMeter(data, "energy", -Config.MinigameEnergyCost)
		S.Data.sync(player, "meters")
		obbyRuns[player] = { startedAt = os.clock(), checkpoint = 0 }
		S.Net.fire(player, "ObbyState", { running = true, startedAt = Workspace:GetServerTimeNow(), total = total })
	end)

	for index, checkpoint in ipairs(obby.checkpoints) do
		checkpoint.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			local run = player and obbyRuns[player]
			if run and run.checkpoint == index - 1 then
				run.checkpoint = index
				S.Net.fire(player, "ObbyState", { running = true, checkpoint = index, total = total })
			end
		end)
	end

	-- Falling into the goo sends you back to your last checkpoint (no dying).
	for _, kill in ipairs(obby.kill) do
		kill.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if not player then
				return
			end
			local run = obbyRuns[player]
			if run and run.checkpoint > 0 then
				obbyTeleport(player, obby.checkpoints[run.checkpoint].CFrame)
			else
				obbyTeleport(player, obby.respawn)
			end
		end)
	end

	obby.finish.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		local run = player and obbyRuns[player]
		local data = player and S.Data.get(player)
		if not run or not data or run.checkpoint < total then
			return
		end
		local elapsed = os.clock() - run.startedAt
		if elapsed < def.minTime then
			return -- nobody is that fast
		end
		obbyRuns[player] = nil
		-- 100 points at 20s or faster, sliding down to 20 points at 90s+.
		local score = math.clamp(100 - (elapsed - 20) * (80 / 70), 20, 100)
		local coins, xp = payout(player, data, def, score, 1)
		S.Net.fire(player, "ObbyState", { running = false, result = { time = elapsed, coins = coins, xp = xp } })
	end)
end

function MinigameServer.tick()
	local def = MinigameSystem.get("obby")
	for player, run in pairs(obbyRuns) do
		if os.clock() - run.startedAt > def.duration then
			obbyRuns[player] = nil
			S.Net.fire(player, "ObbyState", { running = false, timeout = true })
		end
	end
end

function MinigameServer.init(services)
	S = services
	S.Net.handle("MinigameStart", start, 3)
	S.Net.handle("MinigameFinish", finish, 3)
end

function MinigameServer.start()
	setupObby()
end

function MinigameServer.playerRemoving(player)
	sessions[player] = nil
	lastFinish[player] = nil
	obbyRuns[player] = nil
end

return MinigameServer
