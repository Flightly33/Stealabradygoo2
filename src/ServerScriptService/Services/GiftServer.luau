--[[
	GiftServer  (S.Gifts)
	The wearable pieces Brady gifts to the PLAYER as he grows up. The player
	chooses which ones to wear (one per slot); this service validates the
	choice and attaches the accessories to their avatar on every respawn.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local GiftSystem = require(Modules.GiftSystem)
local GiftBuilder = require(Modules.Builders.GiftBuilder)

local GiftServer = {}

local S
local connections = {}

-- Re-applies the equipped gifts to the player's current character.
function GiftServer.refresh(player)
	local data = S.Data.get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not humanoid then
		return
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") and string.sub(child.Name, 1, #GiftBuilder.Prefix) == GiftBuilder.Prefix then
			child:Destroy()
		end
	end
	for _, giftId in pairs(data.gifts.equipped) do
		local accessory = GiftBuilder.build(giftId)
		if accessory then
			humanoid:AddAccessory(accessory)
		end
	end
end

local function equip(player, data, giftId)
	local gift = type(giftId) == "string" and GiftSystem.get(giftId)
	if not gift or not data.gifts.owned[giftId] then
		return
	end
	data.gifts.equipped[gift.slot] = giftId
	S.Data.sync(player, "gifts")
	GiftServer.refresh(player)
end

local function unequip(player, data, slot)
	if type(slot) ~= "string" or data.gifts.equipped[slot] == nil then
		return
	end
	data.gifts.equipped[slot] = nil
	S.Data.sync(player, "gifts")
	GiftServer.refresh(player)
end

function GiftServer.init(services)
	S = services
	S.Net.on("EquipGift", equip, 6)
	S.Net.on("UnequipGift", unequip, 6)
end

function GiftServer.playerAdded(player)
	connections[player] = player.CharacterAdded:Connect(function(character)
		-- Wait for the avatar to finish loading before attaching anything.
		character:WaitForChild("Humanoid", 10)
		task.wait(0.5)
		if character.Parent then
			GiftServer.refresh(player)
			S.Social.refreshTitle(player)
		end
	end)
	if player.Character then
		GiftServer.refresh(player)
	end
end

function GiftServer.playerRemoving(player)
	if connections[player] then
		connections[player]:Disconnect()
		connections[player] = nil
	end
end

return GiftServer
