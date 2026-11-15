--[[
	ClientState
	The client's read-only copy of the player's profile plus a tiny message
	bus the separate UI scripts use to talk to each other.

	Every LocalScript requires this same module, so they all share one state:

	    local State = require(ReplicatedStorage.Client.ClientState)
	    local data = State.wait()              -- yields until the profile arrives
	    State.on("coins", function(coins) end) -- runs now and on every change
	    State.open("Shop", "Food")             -- ask the Shop window to open

	The data here is only for DISPLAY. Changing it does nothing: the server
	owns the real profile and re-sends any key that changes.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("Remotes"))
local Sounds = require(Modules:WaitForChild("Sounds"))
local Util = require(Modules:WaitForChild("Util"))

local ClientState = {}

ClientState.data = nil -- the saved profile (coins, age, inventory...)
ClientState.session = {} -- non-saved state (passes, sleeping, following, day)
ClientState.fashion = nil -- latest fashion show state
ClientState.event = nil -- active random event (or nil)
ClientState.current = nil -- name of the open window
ClientState.currentArg = nil

ClientState.changed = Util.Signal.new() -- (key, value) for profile keys
ClientState.sessionChanged = Util.Signal.new() -- (key, value)
ClientState.panelChanged = Util.Signal.new() -- (name | nil, arg)
ClientState.notified = Util.Signal.new() -- (payload) centre-screen messages
ClientState.fashionChanged = Util.Signal.new() -- (state)
ClientState.eventChanged = Util.Signal.new() -- (event | nil)
ClientState.loaded = Util.Signal.new()

local started = false
local sounds = {}

local function start()
	if started then
		return
	end
	started = true

	Remotes.event("DataUpdate").OnClientEvent:Connect(function(update)
		if not ClientState.data then
			return -- the initial snapshot will include it
		end
		if update.data then
			for key, value in pairs(update.data) do
				ClientState.data[key] = value
				ClientState.changed:Fire(key, value)
			end
		end
		if update.session then
			for key, value in pairs(update.session) do
				ClientState.session[key] = value
				ClientState.sessionChanged:Fire(key, value)
			end
		end
	end)
	Remotes.event("Notify").OnClientEvent:Connect(function(payload)
		ClientState.notified:Fire(payload)
	end)
	Remotes.event("FashionState").OnClientEvent:Connect(function(state)
		ClientState.fashion = state
		ClientState.fashionChanged:Fire(state)
	end)
	Remotes.event("EventUpdate").OnClientEvent:Connect(function(event)
		ClientState.event = event
		ClientState.eventChanged:Fire(event)
	end)
	Remotes.event("OpenPanel").OnClientEvent:Connect(function(name, arg)
		ClientState.open(name, arg)
	end)

	task.spawn(function()
		local getData = Remotes.func("GetData")
		local snapshot
		repeat
			local ok, result = pcall(function()
				return getData:InvokeServer()
			end)
			snapshot = ok and result or nil
			if not snapshot then
				task.wait(1)
			end
		until snapshot
		ClientState.data = snapshot.data
		ClientState.session = snapshot.session or {}
		ClientState.loaded:Fire(ClientState.data)
		-- ask for the fashion show state now that we are listening
		Remotes.event("Fashion"):FireServer("Sync")
	end)
end

-- Yields until the profile has arrived, then returns it.
function ClientState.wait()
	start()
	while not ClientState.data do
		task.wait(0.1)
	end
	return ClientState.data
end

-- Run fn(value) now (once loaded) and again whenever that profile key changes.
function ClientState.on(key, fn)
	local connection = ClientState.changed:Connect(function(changedKey, value)
		if changedKey == key then
			fn(value)
		end
	end)
	task.spawn(function()
		ClientState.wait()
		fn(ClientState.data[key])
	end)
	return connection
end

function ClientState.onSession(key, fn)
	local connection = ClientState.sessionChanged:Connect(function(changedKey, value)
		if changedKey == key then
			fn(value)
		end
	end)
	task.spawn(function()
		ClientState.wait()
		fn(ClientState.session[key])
	end)
	return connection
end

-- Window management: only one window is open at a time.
function ClientState.open(name, arg)
	ClientState.current = name
	ClientState.currentArg = arg
	ClientState.panelChanged:Fire(name, arg)
end

function ClientState.close()
	if ClientState.current ~= nil then
		ClientState.open(nil)
	end
end

function ClientState.toggle(name, arg)
	if ClientState.current == name then
		ClientState.close()
	else
		ClientState.open(name, arg)
	end
end

-- Small message at the bottom of the screen.
function ClientState.toast(text, kind)
	ClientState.notified:Fire({ text = text, toast = true, kind = kind or "info" })
end

-- Big centre-screen message.
function ClientState.announce(payload)
	ClientState.notified:Fire(payload)
end

function ClientState.passes()
	return ClientState.session.passes or {}
end

function ClientState.hasPass(key)
	return ClientState.passes()[key] == true
end

-- The local player's own Brady model (or nil while it is being rebuilt).
function ClientState.myBrady()
	local userId = Players.LocalPlayer.UserId
	for _, model in ipairs(CollectionService:GetTagged("BradyGoo")) do
		if model:GetAttribute("OwnerUserId") == userId and model.Parent then
			return model
		end
	end
	return nil
end

function ClientState.setting(key)
	local data = ClientState.data
	return data and data.settings and data.settings[key]
end

-- Plays a UI sound from Modules/Sounds (respects the SFX setting).
function ClientState.sound(name)
	if ClientState.setting("sfx") == false then
		return
	end
	local def = Sounds.List[name]
	if not def then
		return
	end
	local sound = sounds[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "Sfx_" .. name
		sound.SoundId = def.id
		sound.Volume = def.volume or 0.5
		sound.PlaybackSpeed = def.speed or 1
		sound.Parent = SoundService
		sounds[name] = sound
	end
	sound:Play()
end

-- Convenience wrappers so UI scripts do not all need the Remotes module.
function ClientState.send(remoteName, ...)
	Remotes.event(remoteName):FireServer(...)
end

function ClientState.invoke(remoteName, ...)
	local args = table.pack(...)
	local ok, result = pcall(function()
		return Remotes.func(remoteName):InvokeServer(table.unpack(args, 1, args.n))
	end)
	if ok and type(result) == "table" then
		return result
	end
	return { ok = false, reason = "no response from the server" }
end

function ClientState.listen(remoteName, fn)
	return Remotes.event(remoteName).OnClientEvent:Connect(fn)
end

return ClientState
