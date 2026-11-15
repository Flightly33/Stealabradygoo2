--[[
	AgeServer
	Age XP, ageing up, stage rewards and rebirth. Server authoritative: the
	client only ever receives the results.

	When Brady ages up:
	  * Goo Coins are paid
	  * reaching a new STAGE also unlocks a clothing category, a hairstyle,
	    clothing, a room item, a pose, a gift for the player's own avatar and a
	    bigger house
	  * Brady celebrates and the client plays the "BRADY AGED UP!" sequence

	Stage item rewards are idempotent: data.stageRewards[stage] is set before
	anything is handed out, so they cannot be claimed twice.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local AgeSystem = require(Modules.AgeSystem)
local ClothingSystem = require(Modules.ClothingSystem)
local CurrencySystem = require(Modules.CurrencySystem)
local Dialogue = require(Modules.Dialogue)
local FurnitureSystem = require(Modules.FurnitureSystem)
local GiftSystem = require(Modules.GiftSystem)
local InventorySystem = require(Modules.InventorySystem)

local AgeServer = {}

local S

-- Hair ids that are the default look of some stage.
local stageHair = {}
for _, stage in ipairs(AgeSystem.Stages) do
	stageHair[stage.look.hair] = true
end

-- Hands out everything a stage unlocks. Returns a list of text lines for the UI.
local function grantStageRewards(player, data, stage)
	local lines = {}
	local rewards = stage.rewards
	local key = tostring(stage.index)
	local firstTime = not data.stageRewards[key]
	data.stageRewards[key] = true

	if rewards.coins then
		local coins = math.floor(rewards.coins * (1 + 0.25 * data.rebirths))
		S.Currency.add(player, coins, "stage")
		table.insert(lines, "+" .. coins .. " Goo Coins")
	end
	table.insert(lines, "Unlocked: " .. stage.unlockText)
	if stage.interaction then
		table.insert(lines, "New: " .. stage.interaction)
	end

	if firstTime then
		for _, itemId in ipairs(rewards.items or {}) do
			local item = ClothingSystem.get(itemId)
			if item and not data.inventory[itemId] then
				data.inventory[itemId] = true
				table.insert(lines, "New " .. item.rarity .. " item: " .. item.name)
			end
		end
		if rewards.furniture and FurnitureSystem.get(rewards.furniture) then
			local owned = data.furniture.owned
			owned[rewards.furniture] = (owned[rewards.furniture] or 0) + 1
			table.insert(lines, "New room item: " .. FurnitureSystem.get(rewards.furniture).name)
		end
		for _, giftId in ipairs({ rewards.gift, rewards.gift2 }) do
			local gift = GiftSystem.get(giftId)
			if gift and not data.gifts.owned[giftId] then
				data.gifts.owned[giftId] = true
				table.insert(lines, "Brady gifted YOU: " .. gift.name)
			end
		end
		if rewards.pose and AgeSystem.PoseById[rewards.pose] then
			table.insert(lines, "New pose: " .. AgeSystem.PoseById[rewards.pose].name)
		end
	end

	-- Switch to the new stage's hairstyle unless the player picked a custom one.
	local hair = data.equipped.Hair
	if hair == nil or stageHair[hair] then
		data.equipped.Hair = stage.look.hair
	end
	S.Data.sync(player, "inventory", "equipped", "furniture", "gifts", "stageRewards")
	return lines
end

local function onAgeUp(player, data, newAge)
	local oldStage = AgeSystem.getStageIndex(data.age)
	data.age = newAge
	local stage = AgeSystem.getStage(newAge)
	local stageChanged = stage.index ~= oldStage

	local coins = math.floor(CurrencySystem.ageUpReward(newAge) * (1 + 0.25 * data.rebirths))
	S.Currency.add(player, coins, "ageUp")

	local lines = { "+" .. coins .. " Goo Coins" }
	if stageChanged then
		for _, line in ipairs(grantStageRewards(player, data, stage)) do
			table.insert(lines, line)
		end
	end

	S.Data.sync(player, "age", "ageXP")
	S.Net.fire(player, "AgeUp", {
		age = newAge,
		stageChanged = stageChanged,
		stageName = stage.name,
		blurb = stage.blurb,
		lines = lines,
	})

	-- A bigger house for a bigger Brady, then the new look.
	if stageChanged then
		S.House.upgrade(player)
		S.Gifts.refresh(player)
	end
	S.Brady.rebuild(player)
	local rec = S.Brady.get(player)
	if rec then
		S.Brady.act(rec, "Celebrate", 3.5)
		S.Brady.say(rec, Dialogue.pick(stageChanged and "stageUp" or "ageUp"))
	end
	S.Net.fireAll("Effect", "Confetti", { userId = player.UserId })
	S.Achievements.bump(player, "ageUps", 1)
end

-- Gives Age XP. `opts.raw` skips the age / mood multipliers.
-- Returns the XP actually awarded.
function AgeServer.addXP(player, base, opts)
	local data = S.Data.get(player)
	if not data or base <= 0 then
		return 0
	end
	if data.age >= AgeSystem.MaxAge then
		return 0
	end
	local amount = base
	if not (opts and opts.raw) then
		amount *= AgeSystem.rewardMultiplier(data.age, data.rebirths) * AgeSystem.moodMultiplier(data.meters)
	end
	amount = math.max(1, math.floor(amount + 0.5))
	data.ageXP = math.min(AgeSystem.MaxXP, data.ageXP + amount)

	local newAge = AgeSystem.ageFromXP(data.ageXP)
	if newAge > data.age then
		for age = data.age + 1, newAge do
			onAgeUp(player, data, age)
		end
	else
		S.Data.sync(player, "ageXP")
	end
	return amount
end

-- Rebirth: back to Baby Brady with a permanent +25% coin / XP bonus.
-- The wardrobe, furniture, coins and collections are all kept.
local function rebirth(player, data)
	if data.age < AgeSystem.MaxAge then
		S.Net.toast(player, "Brady must be Legendary (age 25) to rebirth", "bad")
		return
	end
	data.rebirths += 1
	data.ageXP = 0
	data.age = 1
	-- Take off anything Baby Brady is too young to wear.
	for slot, itemId in pairs(data.equipped) do
		if not InventorySystem.canEquip(data, itemId) then
			data.equipped[slot] = nil
		end
	end
	data.equipped.Hair = AgeSystem.Stages[1].look.hair
	data.meters = { hunger = 70, clean = 80, energy = 100, fun = 70 }
	S.Data.sync(player, "rebirths", "ageXP", "age", "equipped", "meters")

	S.Care.wake(player, true)
	S.House.upgrade(player)
	S.Brady.rebuild(player)
	local rec = S.Brady.get(player)
	if rec then
		S.Brady.act(rec, "Celebrate", 3.5)
		S.Brady.say(rec, Dialogue.pick("rebirth"))
	end
	S.Net.notify(player, {
		text = "BRADY WAS REBORN!",
		sub = "Rebirth " .. data.rebirths .. "  •  +" .. (data.rebirths * 25) .. "% coins and XP forever",
		kind = "grail",
		sound = "grail",
		big = true,
	})
	S.Net.fireAll("Effect", "Confetti", { userId = player.UserId })
	S.Achievements.check(player)
end

function AgeServer.init(services)
	S = services
	S.Net.on("Rebirth", rebirth, 1)
end

return AgeServer
