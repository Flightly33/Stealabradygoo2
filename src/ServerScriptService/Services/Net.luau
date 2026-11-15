--[[
	Net (server)
	Thin wrapper around the RemoteEvents / RemoteFunctions so every handler
	gets the same protection for free:

	  * the player's data must be loaded (handlers receive `data`)
	  * per-player rate limiting (stops remote spam / macro exploits)
	  * errors in one handler are caught and logged instead of breaking others

	Handlers still validate their own arguments - a client can send anything.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.Remotes)

local Net = {}

local dataService -- set by Net.init
local buckets = {} -- [player][remoteName] = { count, windowStart }

function Net.init(S)
	dataService = S.Data
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

-- Returns true when the call is allowed. `limit` = max calls per second.
local function allow(player, name, limit)
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local bucket = playerBuckets[name]
	local now = os.clock()
	if not bucket or now - bucket.start >= 1 then
		playerBuckets[name] = { count = 1, start = now }
		return true
	end
	bucket.count += 1
	return bucket.count <= limit
end

-- Listen to a client -> server RemoteEvent.
-- handler(player, data, ...) only runs when the player's data is loaded.
function Net.on(name, handler, limit)
	limit = limit or 8
	Remotes.event(name).OnServerEvent:Connect(function(player, ...)
		if not allow(player, name, limit) then
			return
		end
		local data = dataService.get(player)
		if not data then
			return
		end
		local ok, err = pcall(handler, player, data, ...)
		if not ok then
			warn(string.format("[Net] %s handler error for %s: %s", name, player.Name, tostring(err)))
		end
	end)
end

-- Answer a RemoteFunction. Always returns a table so the client never hangs.
function Net.handle(name, handler, limit)
	limit = limit or 6
	Remotes.func(name).OnServerInvoke = function(player, ...)
		if not allow(player, name, limit) then
			return { ok = false, reason = "slow down!" }
		end
		local data = dataService.get(player)
		if not data then
			return { ok = false, reason = "still loading..." }
		end
		local ok, result = pcall(handler, player, data, ...)
		if not ok then
			warn(string.format("[Net] %s handler error for %s: %s", name, player.Name, tostring(result)))
			return { ok = false, reason = "something went wrong" }
		end
		return result
	end
end

function Net.fire(player, name, ...)
	if player and player.Parent then
		Remotes.event(name):FireClient(player, ...)
	end
end

function Net.fireAll(name, ...)
	Remotes.event(name):FireAllClients(...)
end

-- Big centre-screen announcement.
-- payload = { text, sub, kind = "good"|"bad"|"rare"|"archive"|"grail"|"event", sound, big }
function Net.notify(player, payload)
	Net.fire(player, "Notify", payload)
end

-- Small message at the bottom of the screen.
function Net.toast(player, text, kind)
	Net.fire(player, "Notify", { text = text, toast = true, kind = kind or "info" })
end

return Net
