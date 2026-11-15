--[[
	DataServer
	Loads, saves and replicates every player's profile. Server only.

	RELIABILITY FEATURES
	  * Session locking. When a profile is loaded the DataStore record is
	    stamped with this server's id. Another server that sees a fresh lock
	    waits and retries instead of loading stale data. This is what stops
	    item / coin duplication when someone hops servers faster than the old
	    server can save.
	  * UpdateAsync everywhere (never a blind SetAsync) so a save can refuse to
	    overwrite a record that a newer session has taken over.
	  * Loaded data always goes through DataManager.reconcile(), which repairs
	    missing / corrupt fields. A record that is not even a table is backed
	    up under a "Corrupt_" key before a fresh profile is created.
	  * If loading FAILS (DataStore outage) the player is kicked rather than
	    given a blank profile that would overwrite their real one.
	  * Autosave on an interval, save on leave, save everyone on shutdown.

	STUDIO NOTE: if "Enable Studio Access to API Services" is off (or the place
	is unpublished) DataStores are unavailable. In Studio only, the game then
	runs with temporary in-memory profiles and prints a warning.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage.Modules
local Config = require(Modules.Config)
local DataManager = require(Modules.DataManager)
local Remotes = require(Modules.Remotes)
local Util = require(Modules.Util)

local DataServer = {}

local S
local store -- the DataStore, or nil when running in memory-only mode
local memoryOnly = false
local jobId = game.JobId ~= "" and game.JobId or ("studio-" .. HttpService:GenerateGUID(false))

-- [player] = { data, session, key, ready, lastSave, saving }
local profiles = {}

local function keyFor(userId)
	return "Player_" .. tostring(userId)
end

----------------------------------------------------------------------
-- DataStore access
----------------------------------------------------------------------
local function openStore()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok and result then
		store = result
		return
	end
	if RunService:IsStudio() then
		memoryOnly = true
		warn("[DataServer] DataStores are unavailable in this Studio session - progress will NOT be saved. "
			.. "Publish the place and enable Game Settings > Security > 'Enable Studio Access to API Services'.")
	else
		warn("[DataServer] Could not open the DataStore: " .. tostring(result))
	end
end

-- Returns: rawData (may be nil for a new player), success
local function loadRecord(userId)
	if memoryOnly then
		return nil, true
	end
	if not store then
		return nil, false
	end
	local key = keyFor(userId)
	for attempt = 1, 6 do
		local record, lockedElsewhere
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(stored)
				-- NOTE: this callback must never yield.
				if type(stored) ~= "table" then
					stored = { data = stored }
				end
				local lock = stored.lock
				if type(lock) == "table" and lock.job ~= jobId and os.time() - (tonumber(lock.t) or 0) < Config.SessionLockTimeout then
					lockedElsewhere = true
					record = nil
					return nil -- cancel: another server still owns this profile
				end
				lockedElsewhere = false
				stored.lock = { job = jobId, t = os.time() }
				record = stored
				return stored
			end)
		end)
		if ok and record then
			return record.data, true
		end
		if not ok then
			warn(string.format("[DataServer] load attempt %d failed for %d: %s", attempt, userId, tostring(err)))
		end
		-- Locked elsewhere usually means the previous server is still saving.
		task.wait(lockedElsewhere and 5 or math.min(2 ^ attempt, 12))
	end
	return nil, false
end

-- Writes a profile. `release` clears the session lock (player is leaving).
local function saveRecord(profile, release)
	if memoryOnly or not store then
		return true
	end
	local payload = Util.deepCopy(profile.data)
	payload.lastSeen = os.time()
	for attempt = 1, 3 do
		local takenOver = false
		local ok, err = pcall(function()
			store:UpdateAsync(profile.key, function(stored)
				if type(stored) ~= "table" then
					stored = {}
				end
				local lock = stored.lock
				if type(lock) == "table" and lock.job ~= jobId then
					-- Our lock expired and a newer session owns the record.
					-- Never overwrite its data.
					takenOver = true
					return nil
				end
				stored.data = payload
				stored.saved = os.time()
				stored.lock = (not release) and { job = jobId, t = os.time() } or nil
				return stored
			end)
		end)
		if ok then
			if takenOver then
				warn("[DataServer] save skipped - profile is owned by a newer session: " .. profile.key)
			end
			return not takenOver
		end
		warn(string.format("[DataServer] save attempt %d failed for %s: %s", attempt, profile.key, tostring(err)))
		task.wait(2 * attempt)
	end
	return false
end

local function backupCorrupt(userId, raw)
	if memoryOnly or not store then
		return
	end
	pcall(function()
		store:SetAsync("Corrupt_" .. tostring(userId) .. "_" .. tostring(os.time()), { raw = tostring(raw) })
	end)
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------
function DataServer.init(services)
	S = services
	openStore()

	-- The client asks for its profile once; wait until it is ready.
	Remotes.func("GetData").OnServerInvoke = function(player)
		local deadline = os.clock() + 45
		while os.clock() < deadline and player.Parent do
			local profile = profiles[player]
			if profile and profile.ready then
				return { data = profile.data, session = profile.session }
			end
			task.wait(0.25)
		end
		return nil
	end
end

function DataServer.isMemoryOnly()
	return memoryOnly
end

-- Loads a player's profile (yields). Returns data, or nil if the player was kicked.
function DataServer.load(player)
	local raw, ok = loadRecord(player.UserId)
	if not player.Parent then
		-- Left while loading: release the lock we may have just taken.
		if ok and not memoryOnly and store then
			pcall(function()
				store:UpdateAsync(keyFor(player.UserId), function(stored)
					if type(stored) == "table" and type(stored.lock) == "table" and stored.lock.job == jobId then
						stored.lock = nil
						return stored
					end
					return nil
				end)
			end)
		end
		return nil
	end
	if not ok then
		player:Kick("Raise Brady Goo could not load your save data. Your progress is safe - please rejoin in a minute.")
		return nil
	end
	if raw ~= nil and type(raw) ~= "table" then
		backupCorrupt(player.UserId, raw)
		raw = nil
	end
	local data = DataManager.reconcile(raw)
	local profile = {
		data = data,
		session = { passes = {}, sleeping = false, following = false, day = Util.today(), isNew = raw == nil },
		key = keyFor(player.UserId),
		ready = false,
		lastSave = os.clock() + math.random() * 20, -- staggers autosaves
	}
	profiles[player] = profile

	-- Leaderboard (the Roblox player list shows these).
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local age = Instance.new("IntValue")
	age.Name = "Age"
	age.Value = data.age
	age.Parent = leaderstats
	local coins = Instance.new("IntValue")
	coins.Name = "Goo Coins"
	coins.Value = data.coins
	coins.Parent = leaderstats
	leaderstats.Parent = player
	profile.leaderAge, profile.leaderCoins = age, coins

	return data
end

-- Called by Main once every service has finished setting the player up.
function DataServer.markReady(player)
	local profile = profiles[player]
	if profile then
		profile.ready = true
	end
end

function DataServer.get(player)
	local profile = profiles[player]
	return profile and profile.data or nil
end

function DataServer.session(player)
	local profile = profiles[player]
	return profile and profile.session or nil
end

-- Iterate loaded players: for player, data, session in DataServer.each() do
function DataServer.each()
	local list = {}
	for player, profile in pairs(profiles) do
		table.insert(list, { player, profile.data, profile.session })
	end
	local index = 0
	return function()
		index += 1
		local entry = list[index]
		if entry then
			return entry[1], entry[2], entry[3]
		end
		return nil
	end
end

-- Send changed top-level keys of the saved data to the owning client.
function DataServer.sync(player, ...)
	local profile = profiles[player]
	if not profile then
		return
	end
	local changes = {}
	for _, key in ipairs({ ... }) do
		changes[key] = profile.data[key]
		if key == "coins" and profile.leaderCoins then
			profile.leaderCoins.Value = profile.data.coins
		elseif key == "age" and profile.leaderAge then
			profile.leaderAge.Value = profile.data.age
		end
	end
	if profile.ready then
		S.Net.fire(player, "DataUpdate", { data = changes })
	end
end

-- Same, for the non-saved session table (passes, sleeping, following...).
function DataServer.syncSession(player, ...)
	local profile = profiles[player]
	if not profile then
		return
	end
	local changes = {}
	for _, key in ipairs({ ... }) do
		local value = profile.session[key]
		changes[key] = value == nil and false or value
	end
	if profile.ready then
		S.Net.fire(player, "DataUpdate", { session = changes })
	end
end

function DataServer.save(player, release)
	local profile = profiles[player]
	if not profile or profile.saving then
		return false
	end
	profile.saving = true
	local ok = saveRecord(profile, release)
	profile.saving = false
	profile.lastSave = os.clock()
	return ok
end

-- Final save when a player leaves, then forget the profile.
function DataServer.release(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	-- Wait for an autosave that is mid-flight so the final save is not skipped.
	local deadline = os.clock() + 10
	while profile.saving and os.clock() < deadline do
		task.wait(0.1)
	end
	profile.saving = true
	saveRecord(profile, true)
	profiles[player] = nil
end

-- Autosave check, called once a second from Main.
function DataServer.tick()
	local now = os.clock()
	for player, profile in pairs(profiles) do
		if profile.ready and not profile.saving and now - profile.lastSave >= Config.AutosaveInterval then
			profile.lastSave = now
			task.spawn(DataServer.save, player, false)
		end
	end
end

-- Server shutdown: save everybody in parallel and wait for them.
function DataServer.shutdown()
	local pending = 0
	for player in pairs(profiles) do
		pending += 1
		task.spawn(function()
			DataServer.release(player)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end

function DataServer.playerCount()
	return #Players:GetPlayers()
end

return DataServer
