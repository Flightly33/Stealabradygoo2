--[[
	InventorySystem
	Pure helper functions that read a player's data table.

	The SERVER uses these to validate every equip request. The CLIENT uses the
	exact same functions to decide what to grey out, so the UI and the rules
	can never disagree. Nothing in here mutates data on the client's behalf:
	changes only ever happen in ServerScriptService/Services/ClothingServer.
]]

local Modules = script.Parent
local AgeSystem = require(Modules.AgeSystem)
local ClothingSystem = require(Modules.ClothingSystem)

local InventorySystem = {}

function InventorySystem.owns(data, itemId)
	return data.inventory[itemId] == true
end

-- Can this player put this item on Brady right now?
function InventorySystem.canEquip(data, itemId)
	local item = ClothingSystem.get(itemId)
	if not item then
		return false, "that item does not exist"
	end
	if not InventorySystem.owns(data, itemId) then
		return false, "you don't own that"
	end
	if not AgeSystem.isSlotUnlocked(item.slot, data.age) then
		return false, ClothingSystem.SlotInfo[item.slot].plural .. " unlock at age " .. AgeSystem.slotUnlockAge(item.slot)
	end
	if data.age < item.age then
		return false, "Brady must be age " .. item.age
	end
	return true
end

function InventorySystem.isEquipped(data, itemId)
	local item = ClothingSystem.get(itemId)
	return item ~= nil and data.equipped[item.slot] == itemId
end

-- Owned items, optionally filtered to one slot, rarest first.
function InventorySystem.ownedItems(data, slot)
	local list = {}
	for itemId in pairs(data.inventory) do
		local item = ClothingSystem.get(itemId)
		if item and (slot == nil or item.slot == slot) then
			table.insert(list, item)
		end
	end
	return ClothingSystem.sortItems(list)
end

function InventorySystem.countOwned(data, predicate)
	local n = 0
	for itemId in pairs(data.inventory) do
		local item = ClothingSystem.get(itemId)
		if item and (predicate == nil or predicate(item)) then
			n += 1
		end
	end
	return n
end

function InventorySystem.countRarity(data, rarity)
	return InventorySystem.countOwned(data, function(item)
		return item.rarity == rarity
	end)
end

-- List of the item definitions Brady is currently wearing.
function InventorySystem.equippedItems(equipped)
	local list = {}
	for _, slot in ipairs(ClothingSystem.Slots) do
		local item = equipped[slot] and ClothingSystem.get(equipped[slot])
		if item then
			table.insert(list, item)
		end
	end
	return list
end

-- "Drip score": how fashionable the current fit is. Used for the fashion
-- show judges, event rewards and the "BRADY IS DRIPPED OUT!" popup.
function InventorySystem.dripScore(equipped)
	local score = 0
	for _, item in ipairs(InventorySystem.equippedItems(equipped)) do
		local points = ClothingSystem.Rarities[item.rarity].points
		if item.slot == "Outfit" then
			points *= 3 -- a full outfit covers several slots
		elseif item.slot == "Hair" then
			points *= 0.5
		end
		if item.fx then
			points += 2
		end
		score += points
	end
	return score
end

-- A fit is "bad" when Brady is missing basics. He gets embarrassed about it.
function InventorySystem.isBadFit(equipped)
	if equipped.Outfit then
		return false
	end
	return equipped.Shirt == nil or equipped.Pants == nil
end

-- Highest rarity currently worn (for nameplates / titles).
function InventorySystem.bestRarity(equipped)
	local best, bestOrder = nil, 0
	for _, item in ipairs(InventorySystem.equippedItems(equipped)) do
		local order = ClothingSystem.rarityOrder(item.rarity)
		if order > bestOrder then
			best, bestOrder = item.rarity, order
		end
	end
	return best
end

-- Walk / idle animation overrides + nameplate style from special pieces.
function InventorySystem.specials(equipped)
	local result = { walk = nil, idle = nil, nameplate = nil, spawn = false }
	local bestWalk, bestIdle = 0, 0
	for _, item in ipairs(InventorySystem.equippedItems(equipped)) do
		local order = ClothingSystem.rarityOrder(item.rarity)
		if item.walk and order > bestWalk then
			result.walk, bestWalk = item.walk, order
		end
		if item.idle and order > bestIdle then
			result.idle, bestIdle = item.idle, order
		end
		if item.nameplate then
			result.nameplate = item.nameplate
		end
		if item.spawn then
			result.spawn = true
		end
	end
	return result
end

-- Poses the player may use: stage poses + Grail item poses + pass poses.
function InventorySystem.unlockedPoses(data, passes)
	local stageIndex = AgeSystem.getStageIndex(data.age)
	local itemPoses = {}
	for itemId in pairs(data.inventory) do
		local item = ClothingSystem.get(itemId)
		if item and item.pose then
			itemPoses[item.pose] = true
		end
	end
	local list = {}
	for _, pose in ipairs(AgeSystem.Poses) do
		local unlocked
		if pose.stage then
			unlocked = stageIndex >= pose.stage
		elseif pose.item then
			unlocked = itemPoses[pose.id] == true
		elseif pose.pass then
			unlocked = passes ~= nil and passes[pose.pass] == true
		end
		if unlocked then
			table.insert(list, pose)
		end
	end
	return list
end

function InventorySystem.isPoseUnlocked(data, passes, poseId)
	for _, pose in ipairs(InventorySystem.unlockedPoses(data, passes)) do
		if pose.id == poseId then
			return true
		end
	end
	return false
end

return InventorySystem
