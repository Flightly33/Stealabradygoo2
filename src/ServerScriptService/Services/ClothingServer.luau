--[[
	ClothingServer
	Item ownership and what Brady is wearing. The client sends "please equip
	X"; this service checks ownership, the age requirement and whether the
	category is unlocked before anything changes. Players can only ever touch
	their own inventory - there is no trading or stealing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local Config = require(Modules.Config)
local ClothingSystem = require(Modules.ClothingSystem)
local CurrencySystem = require(Modules.CurrencySystem)
local Dialogue = require(Modules.Dialogue)
local InventorySystem = require(Modules.InventorySystem)

local ClothingServer = {}

local S
local lastDripPopup = {} -- [player] = os.clock()

-- Gives a clothing item. Duplicates are converted into Goo Coins.
-- Returns { isNew, refund, item } or nil for an unknown id.
function ClothingServer.grant(player, itemId, source, silent)
	local data = S.Data.get(player)
	local item = ClothingSystem.get(itemId)
	if not data or not item then
		return nil
	end
	if data.inventory[itemId] then
		local refund = CurrencySystem.sellValue(item.rarity)
		S.Currency.add(player, refund, "duplicate")
		if not silent then
			S.Net.fire(player, "ItemGranted", { kind = "clothing", id = itemId, isNew = false, refund = refund, source = source })
		end
		return { isNew = false, refund = refund, item = item }
	end

	data.inventory[itemId] = true
	S.Data.sync(player, "inventory")
	if not silent then
		S.Net.fire(player, "ItemGranted", { kind = "clothing", id = itemId, isNew = true, source = source })
	end

	-- Brady reacts: he dances for anything Rare or better.
	local rec = S.Brady.get(player)
	if rec then
		local order = ClothingSystem.rarityOrder(item.rarity)
		if item.rarity == "Grail" then
			S.Brady.say(rec, Dialogue.pick("grailItem"))
		elseif item.rarity == "Archive" then
			S.Brady.say(rec, Dialogue.pick("archiveItem"))
		elseif order >= 3 then
			S.Brady.say(rec, Dialogue.pick("rareItem"))
		else
			S.Brady.say(rec, Dialogue.pick("newItem"))
		end
		if order >= 3 and not S.Brady.isBusy(rec) and not S.Data.session(player).sleeping then
			S.Brady.act(rec, "Dance", 3.5)
		end
	end
	S.Achievements.check(player)
	return { isNew = true, refund = 0, item = item }
end

-- Runs after any change to data.equipped.
local function afterFitChange(player, data)
	S.Data.sync(player, "equipped")
	S.Brady.rebuild(player)
	S.Events.hook(player, "equip")
	S.Care.onClothesChanged(player)

	local rec = S.Brady.get(player)
	if not rec or S.Brady.isBusy(rec) or S.Data.session(player).sleeping then
		return
	end
	if InventorySystem.isBadFit(data.equipped) then
		-- Brady gets embarrassed when the fit is missing the basics.
		S.Brady.act(rec, "Embarrassed", 3)
		S.Brady.say(rec, Dialogue.pick("badFit"))
		return
	end
	local drip = InventorySystem.dripScore(data.equipped)
	local now = os.clock()
	if drip >= 24 and now - (lastDripPopup[player] or -1000) > 90 then
		lastDripPopup[player] = now
		S.Net.notify(player, { text = "BRADY IS DRIPPED OUT!", sub = "drip score " .. math.floor(drip), kind = "rare", sound = "good" })
		S.Brady.say(rec, Dialogue.pick("goodFit"))
		S.Brady.act(rec, "Pose", 2.5, "Flex")
	end
end

local function equip(player, data, itemId)
	if type(itemId) ~= "string" then
		return
	end
	local ok, reason = InventorySystem.canEquip(data, itemId)
	if not ok then
		S.Net.toast(player, reason, "bad")
		return
	end
	local item = ClothingSystem.get(itemId)
	if data.equipped[item.slot] == itemId then
		return
	end
	data.equipped[item.slot] = itemId
	afterFitChange(player, data)
end

local function unequip(player, data, slot)
	if type(slot) ~= "string" or not ClothingSystem.SlotInfo[slot] then
		return
	end
	if data.equipped[slot] == nil then
		return
	end
	data.equipped[slot] = nil
	afterFitChange(player, data)
end

local function outfitSlots(player)
	return S.Passes.has(player, "ExtraOutfits") and Config.OutfitSlotsWithPass or Config.OutfitSlots
end

local function validIndex(player, index)
	return type(index) == "number" and index % 1 == 0 and index >= 1 and index <= outfitSlots(player)
end

local function saveOutfit(player, data, index)
	if not validIndex(player, index) then
		S.Net.toast(player, "that outfit slot is locked", "bad")
		return
	end
	local copy = {}
	for slot, itemId in pairs(data.equipped) do
		copy[slot] = itemId
	end
	data.outfits[tostring(index)] = copy
	S.Data.sync(player, "outfits")
	S.Net.toast(player, "Outfit " .. index .. " saved!", "good")
end

local function loadOutfit(player, data, index)
	if not validIndex(player, index) then
		return
	end
	local outfit = data.outfits[tostring(index)]
	if not outfit then
		S.Net.toast(player, "that outfit slot is empty", "bad")
		return
	end
	local equipped = {}
	for slot, itemId in pairs(outfit) do
		-- Re-validated on load: the item must still be owned and wearable.
		local item = ClothingSystem.get(itemId)
		if item and item.slot == slot and InventorySystem.canEquip(data, itemId) then
			equipped[slot] = itemId
		end
	end
	data.equipped = equipped
	afterFitChange(player, data)
	S.Net.toast(player, "Outfit " .. index .. " equipped!", "good")
end

function ClothingServer.init(services)
	S = services
	S.Net.on("Equip", equip, 10)
	S.Net.on("Unequip", unequip, 10)
	S.Net.on("SaveOutfit", saveOutfit, 4)
	S.Net.on("LoadOutfit", loadOutfit, 4)
end

function ClothingServer.playerRemoving(player)
	lastDripPopup[player] = nil
end

return ClothingServer
