--[[
	MonetizationServer  (S.Passes)
	Checks which optional gamepasses a player owns. Ownership is always asked
	of Roblox on the SERVER (MarketplaceService), never taken from the client.

	Every pass is cosmetic or convenience only. With all pass ids left at 0
	(the default) nothing is for sale and the whole game still works.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage.Modules
local Config = require(Modules.Config)
local Monetization = require(Modules.Monetization)

local MonetizationServer = {}

local S

function MonetizationServer.has(player, key)
	local session = S.Data.session(player)
	return session ~= nil and session.passes[key] == true
end

local function refresh(player)
	local session = S.Data.session(player)
	if not session then
		return
	end
	local studioAll = Config.StudioOwnsAllPasses and RunService:IsStudio()
	for _, pass in ipairs(Monetization.Passes) do
		local owned = studioAll
		if not owned and pass.id > 0 then
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			owned = ok and result == true
		end
		session.passes[pass.key] = owned or nil
	end
	S.Data.syncSession(player, "passes")
end

function MonetizationServer.init(services)
	S = services
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local session = S.Data.session(player)
		if not session then
			return
		end
		for _, pass in ipairs(Monetization.Passes) do
			if pass.id == passId then
				session.passes[pass.key] = true
				S.Data.syncSession(player, "passes")
				S.Net.notify(player, { text = "PASS UNLOCKED!", sub = pass.name, kind = "good", sound = "rare" })
				S.Brady.rebuild(player)
			end
		end
	end)
end

function MonetizationServer.playerAdded(player)
	-- Ownership checks are web calls, so do not hold up the join for them.
	task.spawn(function()
		refresh(player)
		if S.Data.get(player) then
			S.Brady.rebuild(player)
		end
	end)
end

return MonetizationServer
