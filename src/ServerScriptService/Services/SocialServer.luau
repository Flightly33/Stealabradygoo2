--[[
	SocialServer
	Multiplayer features that only READ other players' progress:
	  * GetProfile  - inspect another player's Brady, outfit and collection
	  * Visit       - teleport to someone's house or a map location
	  * Hype        - give another Brady's fit some hype
	Plus small per-player things: settings, tutorial completion, the title over
	the player's head.

	Nothing here can change another player's items or coins.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local AgeSystem = require(Modules.AgeSystem)
local CollectionSystem = require(Modules.CollectionSystem)
local CurrencySystem = require(Modules.CurrencySystem)
local DataManager = require(Modules.DataManager)
local Dialogue = require(Modules.Dialogue)
local FashionSystem = require(Modules.FashionSystem)
local InventorySystem = require(Modules.InventorySystem)
local Monetization = require(Modules.Monetization)

local SocialServer = {}

local S
local hypeCooldown = {} -- [player][targetUserId] = os.clock()
local photoCooldown = {}

-- Public summary of a player's progress (safe to show anyone).
local function getProfile(_player, _data, userId)
	local target = type(userId) == "number" and Players:GetPlayerByUserId(userId)
	local data = target and S.Data.get(target)
	if not data then
		return { ok = false, reason = "that player left" }
	end
	local stage = AgeSystem.getStage(data.age)
	local title = S.Brady.activeTitle(data)
	return {
		ok = true,
		userId = userId,
		name = target.DisplayName,
		age = data.age,
		stageName = stage.name,
		rebirths = data.rebirths,
		equipped = data.equipped,
		drip = math.floor(InventorySystem.dripScore(data.equipped)),
		items = InventorySystem.countOwned(data),
		archive = InventorySystem.countRarity(data, "Archive"),
		grail = InventorySystem.countRarity(data, "Grail"),
		collection = CollectionSystem.totalPercent(data),
		title = title and title.name or nil,
		hypes = data.stats.hypes,
		wins = data.stats.showsWon,
	}
end

local function visit(player, _data, target)
	local map = S.Map
	local destination
	if target == "Home" then
		destination = S.House.doorstep(player)
	elseif target == "Plaza" then
		destination = map.spawn
	elseif target == "Runway" then
		destination = map.runway.audience
	elseif target == "Shop" then
		destination = map.store.entrance
	elseif target == "Arcade" then
		destination = map.arcade.entrance
	elseif target == "Park" then
		destination = map.park.entrance
	elseif target == "Food" then
		destination = map.food.entrance
	elseif type(target) == "number" then
		local other = Players:GetPlayerByUserId(target)
		if other and S.House.get(other) then
			destination = S.House.doorstep(other)
		else
			S.Net.toast(player, "that player left", "bad")
			return
		end
	end
	if destination then
		S.House.teleportTo(player, destination)
	end
end

local function hype(player, _data, userId)
	local target = type(userId) == "number" and Players:GetPlayerByUserId(userId)
	if not target or target == player or not S.Data.get(target) then
		return
	end
	local list = hypeCooldown[player]
	if not list then
		list = {}
		hypeCooldown[player] = list
	end
	local now = os.clock()
	if list[userId] and now - list[userId] < 300 then
		S.Net.toast(player, "you already hyped that fit - try again later", "bad")
		return
	end
	list[userId] = now
	S.Achievements.bump(target, "hypes", 1)
	S.Net.toast(target, player.DisplayName .. " hyped Brady's fit!", "good")
	S.Net.toast(player, "hype sent!", "good")
	local rec = S.Brady.get(target)
	if rec and not S.Brady.isBusy(rec) and not rec.persist and not rec.inShow then
		S.Brady.act(rec, "Celebrate", 2)
		S.Brady.say(rec, Dialogue.pick("goodFit"))
	end
end

local function setting(player, data, key, value)
	if type(key) ~= "string" then
		return
	end
	local default = DataManager.SettingDefaults[key]
	if default == nil or type(value) ~= type(default) then
		return
	end
	if key == "aura" then
		if not table.find(Monetization.Auras, value) then
			return
		end
		if value ~= "none" and not S.Passes.has(player, "CosmeticEffects") then
			S.Net.toast(player, "auras need the Cosmetic Effects pass", "bad")
			return
		end
	end
	data.settings[key] = value
	S.Data.sync(player, "settings")
	if key == "aura" then
		S.Brady.rebuild(player)
	end
end

local function tutorial(player, data, action)
	if action == "Done" and not data.tutorialDone then
		data.tutorialDone = true -- flag first: the bonus is one-time
		S.Data.sync(player, "tutorialDone")
		local coins = S.Currency.add(player, CurrencySystem.Rewards.TutorialDone, "tutorial")
		S.Net.notify(player, { text = "TUTORIAL COMPLETE!", sub = "+" .. coins .. " Goo Coins. now go raise brady.", kind = "good", sound = "rare" })
	elseif action == "Replay" then
		data.tutorialDone = false
		S.Data.sync(player, "tutorialDone")
	elseif action == "Photo" then
		-- mirror screenshot taken (only counts once every 30s)
		local now = os.clock()
		if now - (photoCooldown[player] or -100) >= 30 then
			photoCooldown[player] = now
			S.Achievements.bump(player, "photos", 1)
		end
	end
end

-- Title floating over the PLAYER's head (Brady has his own nameplate).
function SocialServer.refreshTitle(player)
	local data = S.Data.get(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not data or not head then
		return
	end
	local existing = head:FindFirstChild("BradyTitle")
	if existing then
		existing:Destroy()
	end
	local title = S.Brady.activeTitle(data)
	local stars = string.rep("★", math.min(data.rebirths, 5))
	if not title and stars == "" then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "BradyTitle"
	gui.Size = UDim2.fromScale(7, 1)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0.25
	label.TextColor3 = title and (FashionSystem.TitleColors[title.name] or Color3.fromRGB(255, 205, 60)) or Color3.fromRGB(255, 205, 60)
	label.Text = (stars ~= "" and stars .. " " or "") .. (title and title.name or "")
	label.Parent = gui
	gui.Parent = head
end

function SocialServer.init(services)
	S = services
	S.Net.handle("GetProfile", getProfile, 4)
	S.Net.on("Visit", visit, 2)
	S.Net.on("Hype", hype, 2)
	S.Net.on("Setting", setting, 6)
	S.Net.on("Tutorial", tutorial, 4)
end

function SocialServer.playerAdded(player)
	SocialServer.refreshTitle(player)
end

function SocialServer.playerRemoving(player)
	hypeCooldown[player] = nil
	photoCooldown[player] = nil
end

return SocialServer
