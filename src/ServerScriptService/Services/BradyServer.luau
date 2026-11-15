--[[
	BradyServer
	Owns every Brady model in the world: building / rebuilding it when his age
	or outfit changes, where he is, what he is doing, and his goofy idle life
	(wandering, tripping, posing, talking to himself).

	HOW MOVEMENT WORKS (cheap + smooth)
	The server never moves Brady every frame. To walk somewhere it writes four
	attributes on the model (WalkFrom, WalkTo, WalkStart, WalkDur) once; every
	client then slides him along that line locally in Client/BradyAnimator.
	The server can still ask "where is he right now?" with Brady.position(),
	which evaluates the same line. When the walk ends the real Root part is
	moved to the destination.

	HOW ANIMATION WORKS
	The server only sets a "State" attribute (Idle, Walk, Eat, Sleep, Dance,
	Trip, Pose...). Each client animates the joints for that state itself, so
	animation costs the server nothing and needs no uploaded animation assets.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage.Modules
local AgeSystem = require(Modules.AgeSystem)
local Config = require(Modules.Config)
local Dialogue = require(Modules.Dialogue)
local FashionSystem = require(Modules.FashionSystem)
local InventorySystem = require(Modules.InventorySystem)
local BradyBuilder = require(Modules.Builders.BradyBuilder)
local PartUtil = require(Modules.Builders.PartUtil)

local BradyServer = {}

local S
local recs = {} -- [player] = rec
local folder

local UP = Vector3.new(0, 1, 0)

local function flatUnit(v, fallback)
	local flat = Vector3.new(v.X, 0, v.Z)
	if flat.Magnitude < 0.01 then
		return fallback or Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

local function newRec(owner)
	return {
		owner = owner,
		model = nil,
		root = nil,
		pos = Vector3.new(),
		look = Vector3.new(0, 0, -1),
		walk = nil,
		walkToken = 0,
		state = "Idle",
		persist = nil, -- { state, pose } for long-running states (Sleep, Mirror, Pose)
		token = 0,
		busyUntil = 0,
		nextWander = os.clock() + 4,
		following = false,
		inShow = false,
		saySeq = 0,
		noShoes = false,
		hairOverride = nil,
		hadSpawnFx = false,
	}
end

----------------------------------------------------------------------
-- Position / movement
----------------------------------------------------------------------
-- Where Brady is right now (evaluates the current walk line).
function BradyServer.position(rec)
	local walk = rec.walk
	if walk then
		local alpha = math.clamp((Workspace:GetServerTimeNow() - walk.t0) / walk.dur, 0, 1)
		return walk.from:Lerp(walk.to, alpha)
	end
	return rec.pos
end

function BradyServer.cframe(rec)
	local pos = BradyServer.position(rec)
	return CFrame.lookAt(pos, pos + rec.look, UP)
end

local function applyRoot(rec)
	if rec.root then
		rec.root.CFrame = CFrame.lookAt(rec.pos, rec.pos + rec.look, UP)
	end
	if rec.model then
		rec.model:SetAttribute("WalkDur", 0)
	end
end

local function setStateAttribute(rec, state, pose)
	rec.state = state
	if rec.model then
		rec.model:SetAttribute("Pose", pose or "")
		rec.model:SetAttribute("State", state)
	end
end

-- Stops a walk where he currently stands.
function BradyServer.stop(rec)
	if rec.walk then
		rec.pos = BradyServer.position(rec)
		rec.walk = nil
		rec.walkToken += 1
		applyRoot(rec)
		if rec.state == "Walk" then
			setStateAttribute(rec, "Idle")
		end
	end
end

-- Teleports Brady to a CFrame (position + facing).
function BradyServer.place(rec, cframe)
	rec.walk = nil
	rec.walkToken += 1
	rec.pos = cframe.Position
	rec.look = flatUnit(cframe.LookVector, rec.look)
	applyRoot(rec)
	if rec.state == "Walk" then
		setStateAttribute(rec, "Idle")
	end
end

-- Starts a straight-line walk. Returns how long it will take (seconds).
function BradyServer.walkTo(rec, target, speed)
	if not rec.model then
		return 0
	end
	local from = BradyServer.position(rec)
	local delta = target - from
	local distance = delta.Magnitude
	if distance < 0.3 then
		return 0
	end
	local duration = distance / (speed or Config.BradyWalkSpeed)
	rec.walkToken += 1
	local token = rec.walkToken
	rec.walk = { from = from, to = target, t0 = Workspace:GetServerTimeNow(), dur = duration }
	rec.look = flatUnit(delta, rec.look)

	local model = rec.model
	model:SetAttribute("WalkFrom", from)
	model:SetAttribute("WalkTo", target)
	model:SetAttribute("WalkStart", rec.walk.t0)
	model:SetAttribute("WalkDur", duration)
	if rec.state == "Idle" then
		setStateAttribute(rec, "Walk")
	end

	task.delay(duration, function()
		if rec.walkToken ~= token or not rec.walk then
			return
		end
		rec.pos = rec.walk.to
		rec.walk = nil
		applyRoot(rec)
		if rec.state == "Walk" then
			setStateAttribute(rec, "Idle")
		end
	end)
	return duration
end

----------------------------------------------------------------------
-- States
----------------------------------------------------------------------
function BradyServer.isBusy(rec)
	return os.clock() < rec.busyUntil
end

-- A long-running state that stays until changed (Sleep, Mirror, Pose...).
-- Pass "Idle" to clear it.
function BradyServer.setState(rec, state, pose)
	rec.token += 1
	rec.persist = state ~= "Idle" and { state = state, pose = pose } or nil
	if state ~= "Walk" then
		BradyServer.stop(rec)
	end
	setStateAttribute(rec, state, pose)
end

-- A timed action (Eat, Dance, Trip, Celebrate...). Afterwards he returns to
-- whatever long-running state he was in, or Idle.
-- `soft` actions are idle fluff (random poses, trips): they do NOT mark Brady
-- as busy, so the player can always interrupt them by feeding / cleaning him.
function BradyServer.act(rec, state, duration, pose, soft)
	if not rec.model then
		return
	end
	rec.token += 1
	local token = rec.token
	if not soft then
		rec.busyUntil = math.max(rec.busyUntil, os.clock() + duration)
	end
	BradyServer.stop(rec)
	setStateAttribute(rec, state, pose)
	task.delay(duration, function()
		if rec.token ~= token or not rec.model then
			return
		end
		if rec.persist then
			setStateAttribute(rec, rec.persist.state, rec.persist.pose)
		else
			setStateAttribute(rec, "Idle")
		end
	end)
end

-- Walks to a spot, then performs a state there.
-- persistent = true keeps the state (Sleep / Mirror) until setState("Idle").
function BradyServer.performAt(rec, cframe, state, duration, pose, persistent, soft)
	if not rec.model then
		return 0
	end
	rec.token += 1
	local token = rec.token
	rec.persist = nil
	if rec.state ~= "Idle" and rec.state ~= "Walk" then
		setStateAttribute(rec, "Idle")
	end
	local distance = (cframe.Position - BradyServer.position(rec)).Magnitude
	local travel = 0
	if distance > 45 then
		BradyServer.place(rec, cframe)
	else
		travel = BradyServer.walkTo(rec, cframe.Position, 14)
	end
	if not soft then
		rec.busyUntil = math.max(rec.busyUntil, os.clock() + travel + (duration or 0.5))
	end
	task.delay(travel, function()
		if rec.token ~= token or not rec.model then
			return
		end
		BradyServer.place(rec, cframe)
		if persistent then
			BradyServer.setState(rec, state, pose)
		else
			BradyServer.act(rec, state, duration, pose, soft)
		end
	end)
	return travel
end

-- Speech bubble. `idle` chatter can be muted by a client setting.
function BradyServer.say(rec, text, idle)
	if not rec.model or not text then
		return
	end
	rec.saySeq += 1
	rec.model:SetAttribute("SayIdle", idle == true)
	rec.model:SetAttribute("SayText", text)
	rec.model:SetAttribute("SaySeq", rec.saySeq)
end

----------------------------------------------------------------------
-- Building
----------------------------------------------------------------------
local function activeTitle(data)
	local title = data.title
	if title and title.name ~= "" and title.expires > os.time() then
		return { name = title.name, color = FashionSystem.TitleColors[title.name] }
	end
	return nil
end

BradyServer.activeTitle = activeTitle

local function attachModel(rec, model, promptText)
	local old = rec.model
	local cframe = BradyServer.cframe(rec)
	model:PivotTo(cframe)
	-- Carry the live state over to the new model so nothing visibly resets.
	model:SetAttribute("State", rec.state)
	model:SetAttribute("Pose", old and old:GetAttribute("Pose") or "")
	model:SetAttribute("SaySeq", rec.saySeq)
	if rec.walk then
		model:SetAttribute("WalkFrom", rec.walk.from)
		model:SetAttribute("WalkTo", rec.walk.to)
		model:SetAttribute("WalkStart", rec.walk.t0)
		model:SetAttribute("WalkDur", rec.walk.dur)
	else
		model:SetAttribute("WalkDur", 0)
	end
	if promptText then
		local prompt = PartUtil.prompt(model.PrimaryPart, "Check Fit", promptText, { distance = 8, name = "InspectPrompt" })
		prompt:SetAttribute("OwnerUserId", model:GetAttribute("OwnerUserId"))
	end
	rec.model = model
	rec.root = model.PrimaryPart
	model.Parent = folder
	if old then
		old:Destroy()
	end
end

-- Rebuilds a player's Brady from their current data (age + outfit).
function BradyServer.rebuild(player)
	local rec = recs[player]
	local data = S.Data.get(player)
	if not rec or not data then
		return
	end
	local aura = S.Passes.has(player, "CosmeticEffects") and data.settings.aura or nil
	local model = BradyBuilder.build({
		age = data.age,
		equipped = data.equipped,
		ownerName = player.DisplayName,
		ownerUserId = player.UserId,
		title = activeTitle(data),
		rebirths = data.rebirths,
		hairOverride = rec.hairOverride,
		noShoes = rec.noShoes,
		aura = aura,
	})
	attachModel(rec, model, player.DisplayName .. "'s Brady")

	-- Grail pieces get a special spawn animation the first time they go on.
	local hasSpawnFx = InventorySystem.specials(data.equipped).spawn
	if hasSpawnFx and not rec.hadSpawnFx and not BradyServer.isBusy(rec) and not rec.persist then
		BradyServer.act(rec, "GrailSpawn", 2.6)
	end
	rec.hadSpawnFx = hasSpawnFx
end

function BradyServer.get(player)
	return recs[player]
end

-- Fashion show bots: a Brady with no owner.
function BradyServer.spawnNPC(spec, cframe)
	local rec = newRec(nil)
	rec.npc = true
	rec.pos = cframe.Position
	rec.look = flatUnit(cframe.LookVector)
	spec.ownerUserId = 0
	attachModel(rec, BradyBuilder.build(spec), nil)
	return rec
end

function BradyServer.remove(rec)
	rec.walkToken += 1
	rec.token += 1
	if rec.model then
		rec.model:Destroy()
		rec.model = nil
		rec.root = nil
	end
end

----------------------------------------------------------------------
-- Following the player around the map
----------------------------------------------------------------------
function BradyServer.isHome(player)
	local rec = recs[player]
	return rec ~= nil and S.House.isInside(player, BradyServer.position(rec), 1)
end

function BradyServer.sendHome(player)
	local rec = recs[player]
	if not rec then
		return
	end
	rec.following = false
	local session = S.Data.session(player)
	if session then
		session.following = false
		S.Data.syncSession(player, "following")
	end
	BradyServer.place(rec, S.House.homeCFrame(player))
end

function BradyServer.setFollowing(player, following)
	local rec = recs[player]
	local session = S.Data.session(player)
	if not rec or not session then
		return
	end
	if following then
		rec.following = true
		session.following = true
		S.Data.syncSession(player, "following")
		BradyServer.say(rec, Dialogue.pick("follow"))
	else
		BradyServer.sendHome(player)
		BradyServer.say(rec, Dialogue.pick("home"))
	end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundBelow(position, ignore)
	rayParams.FilterDescendantsInstances = ignore
	local result = Workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), rayParams)
	if result then
		return result.Position.Y
	end
	return nil
end

local function updateFollow(player, rec)
	if rec.inShow or rec.persist or BradyServer.isBusy(rec) then
		return
	end
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local behind = hrp.Position - flatUnit(hrp.CFrame.LookVector) * 4.5 + flatUnit(hrp.CFrame.RightVector, Vector3.new(1, 0, 0)) * 2.5
	local groundY = groundBelow(behind, { folder, character }) or (hrp.Position.Y - 3)
	local target = Vector3.new(behind.X, groundY, behind.Z)
	local current = BradyServer.position(rec)
	local distance = (target - current).Magnitude
	if distance > 70 then
		BradyServer.place(rec, CFrame.lookAt(target, target + flatUnit(hrp.CFrame.LookVector), UP))
	elseif distance > 3 then
		BradyServer.walkTo(rec, target, Config.BradyFollowSpeed)
	end
end

----------------------------------------------------------------------
-- Idle life: wandering + random funny behaviour
----------------------------------------------------------------------
local function needLine(data)
	local m = data.meters
	if m.hunger < 25 then
		return Dialogue.pick("hungry")
	elseif m.energy < 20 then
		return Dialogue.pick("tired")
	elseif m.clean < 25 then
		return Dialogue.pick("dirty")
	elseif m.fun < 25 then
		return Dialogue.pick("bored")
	end
	return nil
end

local function idleBehaviour(player, rec, data)
	local roll = math.random()
	local stage = AgeSystem.getStage(data.age)
	if roll < 0.08 then
		-- Brady randomly trips
		BradyServer.act(rec, "Trip", 2.4, nil, true)
		BradyServer.say(rec, Dialogue.pick("trip"), true)
	elseif roll < 0.17 then
		-- Brady randomly poses for no reason
		local poses = InventorySystem.unlockedPoses(data, S.Data.session(player).passes)
		local pose = poses[math.random(1, #poses)]
		BradyServer.act(rec, "Pose", 2.6, pose.id, true)
		BradyServer.say(rec, Dialogue.pick("pose"), true)
	elseif roll < 0.24 then
		-- Brady checks himself out in the mirror
		BradyServer.performAt(rec, S.House.stationCFrame(player, "Mirror"), "Mirror", 3, nil, false, true)
		BradyServer.say(rec, Dialogue.pick("mirror"), true)
	elseif roll < 0.5 then
		BradyServer.say(rec, needLine(data) or Dialogue.pick(stage.id), true)
	else
		local spot = S.House.randomSpot(player)
		if spot then
			BradyServer.walkTo(rec, spot, Config.BradyWalkSpeed * (0.7 + stage.look.scale * 0.5))
		end
	end
	rec.nextWander = os.clock() + math.random(Config.WanderInterval[1], Config.WanderInterval[2])
end

-- Called once a second from Main.
function BradyServer.tick()
	local now = os.clock()
	for player, rec in pairs(recs) do
		if rec.model and rec.state == "Idle" and not rec.following and not rec.inShow and now >= rec.nextWander and not BradyServer.isBusy(rec) then
			local data = S.Data.get(player)
			if data then
				idleBehaviour(player, rec, data)
			end
		end
	end
end

----------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------
function BradyServer.init(services)
	S = services
	folder = Instance.new("Folder")
	folder.Name = "Bradys"
	folder.Parent = Workspace
	BradyServer.folder = folder
end

function BradyServer.start()
	-- Follow updates run a little faster than the main 1s tick.
	task.spawn(function()
		while true do
			task.wait(0.35)
			for player, rec in pairs(recs) do
				if rec.following and rec.model then
					local ok, err = pcall(updateFollow, player, rec)
					if not ok then
						warn("[BradyServer] follow error: " .. tostring(err))
					end
				end
			end
		end
	end)
end

function BradyServer.playerAdded(player)
	local rec = newRec(player)
	local home = S.House.homeCFrame(player)
	rec.pos = home.Position
	rec.look = flatUnit(home.LookVector)
	recs[player] = rec
	BradyServer.rebuild(player)
end

function BradyServer.playerRemoving(player)
	local rec = recs[player]
	if rec then
		recs[player] = nil
		BradyServer.remove(rec)
	end
end

function BradyServer.count()
	local n = 0
	for _ in pairs(recs) do
		n += 1
	end
	return n
end

-- (kept for services that want to iterate every live Brady)
function BradyServer.all()
	return recs
end

-- Only used for sanity checks.
function BradyServer.playerOf(model)
	local userId = model:GetAttribute("OwnerUserId")
	return userId and Players:GetPlayerByUserId(userId) or nil
end

return BradyServer
