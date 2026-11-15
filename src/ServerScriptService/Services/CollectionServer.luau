--[[
	CollectionServer
	Hidden collectibles + collection book rewards.

	  * Hidden goo blobs: fixed spots around the map. Each player can collect
	    every blob once per day for Goo Coins and XP. Collecting is per-player,
	    so nobody can "steal" a blob from someone else.
	  * Secret items: every few minutes the server may spawn one extremely rare
	    cosmetic somewhere hard to reach. Anyone who touches it while it exists
	    gets it (once).
	  * The Mystery Jacket permanently waits in the secret Goo Cave.
	  * Finishing a collection lets you claim its reward exactly once.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage.Modules
local ClothingSystem = require(Modules.ClothingSystem)
local CollectionSystem = require(Modules.CollectionSystem)
local Config = require(Modules.Config)
local Util = require(Modules.Util)
local PartUtil = require(Modules.Builders.PartUtil)

local CollectionServer = {}

local S
local folder
local secretClock = 0
local activeSecret -- { model, itemId, expires }
local touchDebounce = {} -- [player] = os.clock()

local rgb = Color3.fromRGB

-- Rarer secrets have a smaller weight.
local SECRET_WEIGHTS = {
	giant_goo_chain = 5,
	invisible_shoes = 4,
	ancient_goo_hat = 4,
	golden_shopping_bag = 3,
	golden_goo = 1,
}

local function playerFromHit(hit)
	local character = hit and hit.Parent
	return character and Players:GetPlayerFromCharacter(character) or nil
end

local function debounce(player, seconds)
	local now = os.clock()
	if touchDebounce[player] and now - touchDebounce[player] < seconds then
		return false
	end
	touchDebounce[player] = now
	return true
end

----------------------------------------------------------------------
-- Hidden goo blobs
----------------------------------------------------------------------
local function resetHiddenIfNewDay(data)
	local today = Util.today()
	if data.daily.hiddenDay ~= today then
		data.daily.hiddenDay = today
		data.daily.hidden = {}
		return true
	end
	return false
end

local function collectHidden(player, index)
	local data = S.Data.get(player)
	if not data then
		return
	end
	resetHiddenIfNewDay(data)
	local key = tostring(index)
	if data.daily.hidden[key] then
		return
	end
	data.daily.hidden[key] = true
	S.Data.sync(player, "daily")
	local coins = S.Currency.add(player, S.Currency.scaled(player, math.random(Config.HiddenCoins[1], Config.HiddenCoins[2])), "hidden")
	local xp = S.Age.addXP(player, 20)
	S.Achievements.bump(player, "hidden", 1)
	S.Net.fire(player, "HiddenFound", index)
	S.Net.fire(player, "Effect", "Reward", { xp = xp, coins = coins, text = "HIDDEN GOO!" })
end

local function buildHidden()
	for index, cframe in ipairs(S.Map.hiddenSpots) do
		local blob = PartUtil.block(folder, {
			name = "HiddenGoo",
			size = Vector3.new(1.5, 1.5, 1.5),
			cframe = cframe * CFrame.new(0, 1, 0),
			color = rgb(126, 232, 74),
			material = "Neon",
			shape = "Ball",
			collide = false,
		})
		blob.CanTouch = true
		blob:SetAttribute("Index", index)
		CollectionService:AddTag(blob, "HiddenGoo")
		blob.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if player then
				collectHidden(player, index)
			end
		end)
	end
end

----------------------------------------------------------------------
-- Secret items
----------------------------------------------------------------------
local function buildPickup(name, cframe, color, itemId)
	local model = Instance.new("Model")
	model.Name = name
	local core = PartUtil.block(model, {
		name = "Core",
		size = Vector3.new(2, 2, 2),
		cframe = cframe * CFrame.new(0, 2, 0) * CFrame.Angles(math.rad(45), math.rad(45), 0),
		color = color,
		material = "Neon",
		collide = false,
	})
	core.CanTouch = true
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 14
	light.Brightness = 2
	light.Shadows = false
	light.Parent = core
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Rate = 14
	sparkles.Lifetime = NumberRange.new(1, 1.6)
	sparkles.Speed = NumberRange.new(1, 3)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new(0.5, 0)
	sparkles.Color = ColorSequence.new(color)
	sparkles.LightEmission = 1
	sparkles.Parent = core
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(5, 1.2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
	gui.MaxDistance = 45
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = "???"
	label.Parent = gui
	gui.Parent = core

	core.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		local data = player and S.Data.get(player)
		if not data or not debounce(player, 2) then
			return
		end
		if data.inventory[itemId] then
			S.Net.toast(player, "you already found this secret", "info")
			return
		end
		S.Clothing.grant(player, itemId, "secret")
		S.House.refreshDisplays(player)
	end)
	model.Parent = folder
	return model
end

local function spawnSecret()
	local options = {}
	for itemId, weight in pairs(SECRET_WEIGHTS) do
		table.insert(options, { id = itemId, weight = weight })
	end
	table.sort(options, function(a, b)
		return a.id < b.id
	end)
	local pick = Util.weighted(options, function(entry)
		return entry.weight
	end)
	local item = pick and ClothingSystem.get(pick.id)
	local spot = Util.pick(S.Map.secretSpots)
	if not item or not spot then
		return
	end
	activeSecret = {
		model = buildPickup("SecretItem", spot, ClothingSystem.rarityColor(item.rarity), item.id),
		itemId = item.id,
		expires = os.clock() + Config.SecretLifetime,
	}
	S.Net.fireAll("Notify", { text = "something rare is glowing somewhere on the map...", toast = true, kind = "rare" })
end

-- Called once a second from Main.
function CollectionServer.tick()
	if activeSecret and os.clock() >= activeSecret.expires then
		activeSecret.model:Destroy()
		activeSecret = nil
	end
	secretClock += 1
	if secretClock >= Config.SecretSpawnInterval then
		secretClock = 0
		if not activeSecret and #Players:GetPlayers() > 0 and math.random() < Config.SecretSpawnChance then
			spawnSecret()
		end
	end
end

----------------------------------------------------------------------
-- Collection book rewards
----------------------------------------------------------------------
local function claim(player, data, collectionId)
	local collection = type(collectionId) == "string" and CollectionSystem.ById[collectionId]
	if not collection then
		return
	end
	if data.collectionsClaimed[collectionId] then
		S.Net.toast(player, "already claimed", "bad")
		return
	end
	if not CollectionSystem.isComplete(data, collection) then
		S.Net.toast(player, "that collection isn't finished yet", "bad")
		return
	end
	data.collectionsClaimed[collectionId] = true -- flag first: no double claims
	S.Data.sync(player, "collectionsClaimed")
	local coins = S.Currency.add(player, collection.coins, "collection")
	local sub = "+" .. coins .. " Goo Coins"
	if collection.title then
		data.title = { name = collection.title, expires = os.time() + 7 * 86400 }
		S.Data.sync(player, "title")
		S.Brady.rebuild(player)
		S.Social.refreshTitle(player)
		sub ..= "  •  title: " .. collection.title
	end
	S.Net.notify(player, { text = string.upper(collection.name) .. " COMPLETE!", sub = sub, kind = "grail", sound = "grail", big = true })
	S.Net.fireAll("Effect", "Confetti", { userId = player.UserId })
end

function CollectionServer.init(services)
	S = services
	folder = Instance.new("Folder")
	folder.Name = "Collectibles"
	folder.Parent = Workspace
	S.Net.on("ClaimCollection", claim, 3)
end

function CollectionServer.start()
	buildHidden()
	-- The Mystery Jacket is always waiting in the secret cave.
	local jacket = ClothingSystem.get("mystery_jacket")
	buildPickup("MysteryJacket", S.Map.cavePedestal, ClothingSystem.rarityColor(jacket.rarity), jacket.id)
end

function CollectionServer.playerAdded(player, data)
	if resetHiddenIfNewDay(data) then
		S.Data.sync(player, "daily")
	end
end

function CollectionServer.playerRemoving(player)
	touchDebounce[player] = nil
end

-- Test helper.
function CollectionServer.forceSecret()
	if activeSecret then
		activeSecret.model:Destroy()
		activeSecret = nil
	end
	spawnSecret()
	return activeSecret
end

return CollectionServer
