--[[
	EventServer
	Random events: every few minutes each player gets a short interactive task
	("BRADY LOST HIS SHOES", "BRADY IS HUNGRY", ...). The server decides when
	an event starts, tracks progress through hooks from the other services and
	pays the reward itself - the client only draws the banner.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage.Modules
local ClothingSystem = require(Modules.ClothingSystem)
local Config = require(Modules.Config)
local Dialogue = require(Modules.Dialogue)
local EventSystem = require(Modules.EventSystem)
local InventorySystem = require(Modules.InventorySystem)
local ShopSystem = require(Modules.ShopSystem)
local Util = require(Modules.Util)
local PartUtil = require(Modules.Builders.PartUtil)

local EventServer = {}

local S
local active = {} -- [player] = { def, endsAt, progress, goal, props, ... }
local nextAt = {} -- [player] = os.clock() time of the next event
local folder

local rgb = Color3.fromRGB

local function schedule(player, range)
	nextAt[player] = os.clock() + math.random(range[1], range[2])
end

local function send(player)
	local event = active[player]
	if not event then
		S.Net.fire(player, "EventUpdate", nil)
		return
	end
	S.Net.fire(player, "EventUpdate", {
		id = event.def.id,
		title = event.def.title,
		desc = event.desc or event.def.desc,
		task = event.def.task,
		endsAt = event.endsAtServer,
		progress = event.progress,
		goal = event.goal,
		choice = event.choice,
	})
end

local function cleanup(player, event)
	for _, prop in ipairs(event.props) do
		prop:Destroy()
	end
	local rec = S.Brady.get(player)
	if rec then
		local changed = false
		if rec.noShoes then
			rec.noShoes = false
			changed = true
		end
		if rec.hairOverride then
			rec.hairOverride = nil
			changed = true
		end
		if changed then
			S.Brady.rebuild(player)
		end
	end
end

local function finish(player, success, extraCoins)
	local event = active[player]
	if not event then
		return
	end
	active[player] = nil
	cleanup(player, event)
	schedule(player, Config.EventDelay)
	S.Net.fire(player, "EventUpdate", nil)
	local rec = S.Brady.get(player)
	if success then
		local coins = S.Currency.add(player, S.Currency.scaled(player, event.def.coins) + (extraCoins or 0), "event")
		local xp = S.Age.addXP(player, event.def.xp)
		S.Achievements.bump(player, "events", 1)
		S.Net.notify(player, { text = event.def.win .. "!", sub = "+" .. coins .. " Goo Coins   +" .. xp .. " Age XP", kind = "good", sound = "good" })
		if rec and not S.Brady.isBusy(rec) and not rec.persist then
			S.Brady.act(rec, "Celebrate", 2.5)
		end
	else
		S.Net.toast(player, "event missed... brady is disappointed", "bad")
	end
end

-- A grabbable prop with a prompt that only the owner can use.
local function spawnProp(player, event, name, position, color, actionText, onGrab)
	local model = Instance.new("Model")
	model.Name = name
	local core = PartUtil.block(model, { name = "Core", size = Vector3.new(1.6, 1.6, 1.6), cframe = CFrame.new(position + Vector3.new(0, 1.2, 0)), color = color, material = "Neon", collide = false })
	PartUtil.block(model, { name = "Glow", size = Vector3.new(0.2, 3, 3), cframe = CFrame.new(position + Vector3.new(0, 0.12, 0)) * PartUtil.UP, color = color, material = "Neon", shape = "Cylinder", transparency = 0.5, collide = false })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 12
	light.Brightness = 1.5
	light.Shadows = false
	light.Parent = core
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Rate = 12
	sparkles.Lifetime = NumberRange.new(0.8, 1.4)
	sparkles.Speed = NumberRange.new(1, 3)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new(0.4, 0)
	sparkles.Color = ColorSequence.new(color)
	sparkles.LightEmission = 1
	sparkles.Parent = core
	local prompt = PartUtil.prompt(core, actionText, name, { distance = 10, name = "EventPrompt" })
	prompt:SetAttribute("OwnerUserId", player.UserId)
	game:GetService("CollectionService"):AddTag(prompt, "OwnerPrompt")
	prompt.Triggered:Connect(function(who)
		if who == player and active[player] == event then
			onGrab()
		end
	end)
	model.Parent = folder
	table.insert(event.props, model)
	return model
end

----------------------------------------------------------------------
-- Starting events
----------------------------------------------------------------------
local starters = {}

function starters.LostShoes(player, data, event)
	local rec = S.Brady.get(player)
	rec.noShoes = true
	S.Brady.rebuild(player)
	-- Hide the shoes inside the room or out in the front yard.
	local origin = S.House.origin(player)
	local h = S.House.size(player) / 2
	local spot
	if math.random() < 0.5 then
		spot = S.House.randomSpot(player)
	end
	if not spot then
		local side = math.random() < 0.5 and -1 or 1
		spot = (origin * CFrame.new(side * math.random(6, math.floor(h)), -1, h + math.random(5, 9))).Position
	end
	spawnProp(player, event, "Brady's Shoes", spot, rgb(255, 255, 255), "Grab Shoes", function()
		finish(player, true)
	end)
end

function starters.Hungry(player, data)
	data.meters.hunger = math.min(data.meters.hunger, 12)
	S.Data.sync(player, "meters")
end

function starters.FoundGrail(player, _data, event)
	local spot = S.House.randomSpot(player) or S.House.homeCFrame(player).Position
	spawnProp(player, event, "Mystery Box", spot, rgb(255, 110, 225), "Open", function()
		local item = ShopSystem.roll(ShopSystem.EventBox)
		if item then
			S.Clothing.grant(player, item.id, "event")
		end
		finish(player, true)
	end)
end

function starters.GoOutside(player)
	S.Brady.setFollowing(player, true)
end

function starters.InsaneFit(player)
	local rec = S.Brady.get(player)
	S.Brady.act(rec, "Dance", 6)
end

function starters.NewHaircut(player, data, event)
	local rec = S.Brady.get(player)
	local current = data.equipped.Hair
	local options = {}
	for _, item in ipairs(ClothingSystem.BySlot.Hair) do
		if item.id ~= current and item.id ~= "hair_baby" then
			table.insert(options, item)
		end
	end
	local pick = Util.pick(options)
	event.hair = pick.id
	event.desc = "he got '" .. pick.name .. "'. KEEP it or FIX it?"
	rec.hairOverride = pick.id
	S.Brady.rebuild(player)
end

function starters.FashionCrisis(player)
	local rec = S.Brady.get(player)
	S.Brady.act(rec, "Embarrassed", 5)
end

local function canStart(player, data, def)
	if def.id == "LostShoes" then
		return data.equipped.Shoes ~= nil or data.equipped.Outfit ~= nil
	elseif def.id == "FashionCrisis" then
		return InventorySystem.countOwned(data) >= 4
	elseif def.id == "Hungry" then
		return data.meters.hunger < 80
	end
	return true
end

local function start(player, data, def)
	local event = {
		def = def,
		endsAt = os.clock() + def.duration,
		endsAtServer = Workspace:GetServerTimeNow() + def.duration,
		progress = 0,
		goal = def.goal or 1,
		props = {},
	}
	active[player] = event
	local rec = S.Brady.get(player)
	if rec then
		S.Brady.say(rec, def.say)
	end
	local starter = starters[def.id]
	if starter then
		starter(player, data, event)
	end
	S.Net.notify(player, { text = def.title, sub = event.desc or def.desc, kind = "event", sound = "event", big = true })
	send(player)
end

----------------------------------------------------------------------
-- Hooks from other services + the EventAction remote
----------------------------------------------------------------------
function EventServer.hook(player, name)
	local event = active[player]
	if not event then
		return
	end
	local id = event.def.id
	if name == "feed" and id == "Hungry" then
		finish(player, true)
	elseif name == "equip" and id == "FashionCrisis" then
		event.progress += 1
		if event.progress >= event.goal then
			finish(player, true)
		else
			send(player)
		end
	elseif name == "brush" and id == "NewHaircut" and event.choice == "fix" then
		finish(player, true)
	end
end

local function onAction(player, data, action)
	local event = active[player]
	if not event or type(action) ~= "string" then
		return
	end
	local id = event.def.id
	if id == "InsaneFit" and action == "Hype" then
		event.progress += 1
		if event.progress >= event.goal then
			-- Better fits earn a bigger hype bonus.
			finish(player, true, math.floor(InventorySystem.dripScore(data.equipped) * 3))
		elseif event.progress % 3 == 0 then
			send(player)
		end
	elseif id == "NewHaircut" and event.choice == nil then
		if action == "Keep" then
			local hairId = event.hair
			local owned = data.inventory[hairId]
			if not owned and math.random() < 0.3 then
				S.Clothing.grant(player, hairId, "event")
				owned = true
			end
			if owned and InventorySystem.canEquip(data, hairId) then
				data.equipped.Hair = hairId
				S.Data.sync(player, "equipped")
				S.Net.toast(player, "the new cut is here to stay!", "good")
			else
				S.Net.toast(player, "...it grew back overnight. classic.", "info")
			end
			finish(player, true)
		elseif action == "Fix" then
			event.choice = "fix"
			event.desc = "brush his hair to fix it! (Brady menu > Clean, or the sink)"
			send(player)
		end
	end
end

-- Called once a second from Main.
function EventServer.tick()
	local now = os.clock()
	for player, data, session in S.Data.each() do
		local event = active[player]
		if event then
			if now >= event.endsAt then
				finish(player, false)
			elseif event.def.id == "GoOutside" then
				local rec = S.Brady.get(player)
				local character = player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				local park = S.Map.park
				if rec and hrp and (hrp.Position - park.center).Magnitude <= park.radius and (S.Brady.position(rec) - hrp.Position).Magnitude < 30 then
					S.Brady.say(rec, Dialogue.pick("outside"))
					S.Care.addMeter(data, "fun", 20)
					S.Data.sync(player, "meters")
					finish(player, true)
				end
			end
		elseif nextAt[player] and now >= nextAt[player] then
			local rec = S.Brady.get(player)
			local busy = not data.tutorialDone or session.sleeping or session.mirror or not rec or rec.inShow or S.Brady.isBusy(rec)
			if busy then
				nextAt[player] = now + 20 -- try again shortly
			else
				local options = {}
				for _, def in ipairs(EventSystem.eligible(data.age)) do
					if canStart(player, data, def) then
						table.insert(options, def)
					end
				end
				local def = Util.weighted(options, function(entry)
					return entry.weight
				end)
				if def then
					start(player, data, def)
				else
					schedule(player, Config.EventDelay)
				end
			end
		end
	end
end

function EventServer.init(services)
	S = services
	folder = Instance.new("Folder")
	folder.Name = "EventProps"
	folder.Parent = Workspace
	S.Net.on("EventAction", onAction, 20)
end

function EventServer.playerAdded(player)
	schedule(player, Config.EventFirstDelay)
end

function EventServer.playerRemoving(player)
	local event = active[player]
	if event then
		for _, prop in ipairs(event.props) do
			prop:Destroy()
		end
	end
	active[player] = nil
	nextAt[player] = nil
end

-- Test / admin helper: start a specific event right now.
function EventServer.force(player, eventId)
	local data = S.Data.get(player)
	local def = EventSystem.get(eventId)
	if data and def and not active[player] then
		start(player, data, def)
		return true
	end
	return false
end

function EventServer.current(player)
	return active[player]
end

return EventServer
