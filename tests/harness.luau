--[[
	Test harness: a small fake Roblox engine that runs under Lune
	(https://lune-org.github.io/docs) so the game's real scripts can be
	executed and exercised outside Roblox Studio.

	What is real: Lune's `roblox` library gives genuine Instances with the
	actual Roblox class / property database, so a typo such as
	`part.Colour = ...` or assigning a Vector3 to a CFrame property fails here
	exactly like it would in Studio.

	What is faked (this file): the task scheduler (on a VIRTUAL clock, so an
	hour of gameplay runs in a moment), signals / events, RemoteEvents,
	DataStores, Players + characters, TweenService, input services, raycasts.

	It is a smoke-test tool, not a physics simulator: nothing renders, nothing
	collides, and anything the fakes do not model must still be checked in
	Studio.
]]

local roblox = require("@lune/roblox")
local luau = require("@lune/luau")

local H = {}

H.errors = {} -- uncaught errors raised inside game code
H.warnings = {} -- everything passed to warn()
H.prints = {}
H.kicks = {}
H.verbose = false

----------------------------------------------------------------------
-- Virtual clock + scheduler
----------------------------------------------------------------------
local clock = 1000
local EPOCH = 1900000000 -- virtual os.time() = EPOCH + clock
local timers = {}
local timerSeq = 0
local cancelled = setmetatable({}, { __mode = "k" })

local function report(err, thread)
	local text = tostring(err)
	if thread then
		text ..= "\n" .. debug.traceback(thread)
	end
	table.insert(H.errors, text)
	if H.verbose then
		print("[ERROR] " .. text)
	end
end

local function resume(thread, ...)
	if cancelled[thread] or coroutine.status(thread) ~= "suspended" then
		return
	end
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		report(err, thread)
	end
end

local function schedule(at, thread, args)
	timerSeq += 1
	table.insert(timers, { at = at, seq = timerSeq, thread = thread, args = args })
end

local task = {}

function task.spawn(f, ...)
	local thread = type(f) == "thread" and f or coroutine.create(f)
	resume(thread, ...)
	return thread
end

function task.defer(f, ...)
	local thread = type(f) == "thread" and f or coroutine.create(f)
	schedule(clock, thread, table.pack(...))
	return thread
end

function task.delay(seconds, f, ...)
	local thread = type(f) == "thread" and f or coroutine.create(f)
	schedule(clock + math.max(seconds or 0, 0), thread, table.pack(...))
	return thread
end

function task.wait(seconds)
	local thread = coroutine.running()
	local started = clock
	schedule(clock + math.max(seconds or 0, 0.02), thread, nil)
	coroutine.yield()
	return clock - started
end

function task.cancel(thread)
	cancelled[thread] = true
	if coroutine.status(thread) == "suspended" then
		pcall(coroutine.close, thread)
	end
end

function H.now()
	return clock
end

----------------------------------------------------------------------
-- Signals
----------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal

function Signal.new(name)
	return setmetatable({ name = name, handlers = {}, waiting = {} }, Signal)
end

function Signal:Connect(fn)
	assert(type(fn) == "function", "Connect expects a function (" .. tostring(self.name) .. ")")
	local connection = { Connected = true, fn = fn }
	local handlers = self.handlers
	function connection.Disconnect()
		connection.Connected = false
		local index = table.find(handlers, connection)
		if index then
			table.remove(handlers, index)
		end
	end
	table.insert(handlers, connection)
	return connection
end
Signal.ConnectParallel = Signal.Connect

function Signal:Once(fn)
	local connection
	connection = self:Connect(function(...)
		connection.Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Wait()
	table.insert(self.waiting, coroutine.running())
	return coroutine.yield()
end

function Signal:Fire(...)
	for _, connection in ipairs(table.clone(self.handlers)) do
		if connection.Connected then
			task.spawn(connection.fn, ...)
		end
	end
	local waiting = self.waiting
	self.waiting = {}
	for _, thread in ipairs(waiting) do
		resume(thread, ...)
	end
end

function Signal:count()
	return #self.handlers
end

H.Signal = Signal

-- Per-instance signal storage: signals[instance][name]
local instanceSignals = {}

local function signalOf(instance, name)
	local list = instanceSignals[instance]
	if not list then
		list = {}
		instanceSignals[instance] = list
	end
	local signal = list[name]
	if not signal then
		signal = Signal.new(name)
		list[name] = signal
	end
	return signal
end
H.signalOf = signalOf

local function event(className, name)
	roblox.implementProperty(className, name, function(self)
		return signalOf(self, name)
	end)
end

----------------------------------------------------------------------
-- Attribute / property watchers (polled after every scheduler step)
----------------------------------------------------------------------
local watchers = {}

local function watch(instance, kind, name)
	local key = kind .. ":" .. name
	local list = instanceSignals[instance]
	if list and list[key] then
		return list[key]
	end
	local signal = signalOf(instance, key)
	local ok, value = pcall(function()
		if kind == "attr" then
			return instance:GetAttribute(name)
		end
		return instance[name]
	end)
	table.insert(watchers, { instance = instance, kind = kind, name = name, last = ok and value or nil, signal = signal })
	return signal
end

local function pollWatchers()
	local index = 1
	while index <= #watchers do
		local w = watchers[index]
		local ok, value = pcall(function()
			if w.kind == "attr" then
				return w.instance:GetAttribute(w.name)
			end
			return w.instance[w.name]
		end)
		if not ok then
			table.remove(watchers, index) -- instance was destroyed
		else
			if value ~= w.last then
				w.last = value
				w.signal:Fire(value)
			end
			index += 1
		end
	end
end

----------------------------------------------------------------------
-- Frame signals
----------------------------------------------------------------------
local frameSignals = {
	Heartbeat = Signal.new("Heartbeat"),
	RenderStepped = Signal.new("RenderStepped"),
	Stepped = Signal.new("Stepped"),
	PreSimulation = Signal.new("PreSimulation"),
	PostSimulation = Signal.new("PostSimulation"),
	PreRender = Signal.new("PreRender"),
	PreAnimation = Signal.new("PreAnimation"),
}
local renderSteps = {}
H.frameStep = 0.1
local nextFrame = clock + H.frameStep

local function fireFrame(dt)
	frameSignals.Stepped:Fire(clock, dt)
	frameSignals.PreSimulation:Fire(dt)
	frameSignals.Heartbeat:Fire(dt)
	frameSignals.PostSimulation:Fire(dt)
	frameSignals.PreRender:Fire(dt)
	frameSignals.PreAnimation:Fire(dt)
	frameSignals.RenderStepped:Fire(dt)
	for _, fn in pairs(renderSteps) do
		task.spawn(fn, dt)
	end
end

-- Advance the virtual clock, running every timer that comes due.
function H.advance(seconds)
	local target = clock + seconds
	local guard = 0
	while true do
		-- earliest timer
		local bestIndex, best
		for index, timer in ipairs(timers) do
			if not best or timer.at < best.at or (timer.at == best.at and timer.seq < best.seq) then
				bestIndex, best = index, timer
			end
		end
		local nextAt = best and best.at or math.huge
		if nextFrame <= nextAt and nextFrame <= target then
			clock = math.max(clock, nextFrame)
			nextFrame += H.frameStep
			fireFrame(H.frameStep)
			pollWatchers()
		elseif best and best.at <= target then
			table.remove(timers, bestIndex)
			clock = math.max(clock, best.at)
			if best.args then
				resume(best.thread, table.unpack(best.args, 1, best.args.n))
			else
				resume(best.thread)
			end
			pollWatchers()
		else
			break
		end
		guard += 1
		if guard > 5e6 then
			error("H.advance: scheduler did not settle")
		end
	end
	clock = target
end

-- Run everything that is due right now without moving the clock much.
function H.flush()
	H.advance(0.05)
end

----------------------------------------------------------------------
-- The DataModel
----------------------------------------------------------------------
local game -- real Lune DataModel
local Players, Workspace

local function initDefaults(instance)
	if instance:IsA("GuiObject") then
		instance.AbsoluteSize = roblox.Vector2.new(120, 40)
		instance.AbsolutePosition = roblox.Vector2.new(100, 100)
		if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
			instance.TextBounds = roblox.Vector2.new(60, 20)
		end
		if instance:IsA("ScrollingFrame") then
			instance.AbsoluteCanvasSize = roblox.Vector2.new(120, 400)
			instance.AbsoluteWindowSize = roblox.Vector2.new(120, 40)
		end
	elseif instance:IsA("LayerCollector") then
		instance.AbsoluteSize = roblox.Vector2.new(1280, 720)
		instance.AbsolutePosition = roblox.Vector2.new(0, 0)
	elseif instance:IsA("UIGridStyleLayout") then
		instance.AbsoluteContentSize = roblox.Vector2.new(0, 0)
	elseif instance:IsA("Camera") then
		instance.ViewportSize = roblox.Vector2.new(1280, 720)
	elseif instance:IsA("Humanoid") then
		instance.Health = 100
	elseif instance:IsA("BasePart") then
		instance.Position = instance.CFrame.Position
	end
end
H.initDefaults = initDefaults

local InstanceLib = {}
function InstanceLib.new(className, parent)
	local instance = roblox.Instance.new(className)
	initDefaults(instance)
	if parent then
		instance.Parent = parent
	end
	return instance
end

----------------------------------------------------------------------
-- Class-level fakes
----------------------------------------------------------------------
local serverInvoke = {} -- [RemoteFunction] = callback
local clientInvoke = {}
H.clientLog = {} -- [player][remoteName] = { {args...}, ... }
H.localPlayer = nil

-- Arguments crossing the network lose functions / metatables. Copy them so
-- the tests notice when game code relies on shared table identity.
local function copyArg(value, depth)
	depth = depth or 0
	if type(value) == "table" then
		assert(depth < 20, "remote argument is too deeply nested")
		local copy = {}
		for k, v in pairs(value) do
			assert(type(k) == "string" or type(k) == "number", "remote table key must be a string or number")
			copy[k] = copyArg(v, depth + 1)
		end
		return copy
	elseif type(value) == "function" or type(value) == "thread" then
		error("cannot send a " .. type(value) .. " through a remote")
	end
	return value
end

local function copyArgs(...)
	local packed = table.pack(...)
	for i = 1, packed.n do
		packed[i] = copyArg(packed[i])
	end
	return table.unpack(packed, 1, packed.n)
end

local function logClient(player, remote, ...)
	local byPlayer = H.clientLog[player]
	if not byPlayer then
		byPlayer = {}
		H.clientLog[player] = byPlayer
	end
	local list = byPlayer[remote.Name]
	if not list then
		list = {}
		byPlayer[remote.Name] = list
	end
	table.insert(list, table.pack(...))
	if #list > 400 then
		table.remove(list, 1)
	end
end

local function setupClasses()
	-- Instance ----------------------------------------------------------
	roblox.implementMethod("Instance", "WaitForChild", function(self, name, _timeout)
		local child = self:FindFirstChild(name)
		if not child then
			report("WaitForChild would yield forever: " .. self:GetFullName() .. "." .. tostring(name))
		end
		return child
	end)
	roblox.implementMethod("Instance", "GetPropertyChangedSignal", function(self, property)
		return watch(self, "prop", property)
	end)
	roblox.implementMethod("Instance", "GetAttributeChangedSignal", function(self, attribute)
		return watch(self, "attr", attribute)
	end)
	for _, name in ipairs({ "Changed", "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "AncestryChanged", "Destroying", "AttributeChanged" }) do
		event("Instance", name)
	end

	-- Parts / models ----------------------------------------------------
	event("BasePart", "Touched")
	event("BasePart", "TouchEnded")
	local function modelRoot(model)
		return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	end
	roblox.implementMethod("Model", "GetPivot", function(self)
		local root = modelRoot(self)
		return root and root.CFrame or roblox.CFrame.new()
	end)
	roblox.implementMethod("Model", "PivotTo", function(self, target)
		assert(typeof(target) == "CFrame", "PivotTo expects a CFrame")
		local root = modelRoot(self)
		if not root then
			return
		end
		local delta = target * root.CFrame:Inverse()
		for _, descendant in ipairs(self:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.CFrame = delta * descendant.CFrame
				descendant.Position = descendant.CFrame.Position
			end
		end
	end)
	roblox.implementMethod("Model", "GetExtentsSize", function(_self)
		return roblox.Vector3.new(4, 6, 4)
	end)
	roblox.implementMethod("Model", "GetBoundingBox", function(self)
		local root = modelRoot(self)
		return root and root.CFrame or roblox.CFrame.new(), roblox.Vector3.new(4, 6, 4)
	end)
	roblox.implementMethod("BasePart", "GetPivot", function(self)
		return self.CFrame
	end)
	roblox.implementMethod("BasePart", "PivotTo", function(self, target)
		self.CFrame = target
		self.Position = target.Position
	end)

	-- Players -----------------------------------------------------------
	event("Players", "PlayerAdded")
	event("Players", "PlayerRemoving")
	roblox.implementMethod("Players", "GetPlayers", function(self)
		local list = {}
		for _, child in ipairs(self:GetChildren()) do
			if child.ClassName == "Player" then
				table.insert(list, child)
			end
		end
		return list
	end)
	roblox.implementMethod("Players", "GetPlayerByUserId", function(self, userId)
		for _, child in ipairs(self:GetChildren()) do
			if child.ClassName == "Player" and child.UserId == userId then
				return child
			end
		end
		return nil
	end)
	roblox.implementMethod("Players", "GetPlayerFromCharacter", function(self, character)
		if not character then
			return nil
		end
		for _, child in ipairs(self:GetChildren()) do
			if child.ClassName == "Player" and child.Character == character then
				return child
			end
		end
		return nil
	end)
	roblox.implementProperty("Players", "LocalPlayer", function()
		return H.localPlayer
	end)
	event("Player", "CharacterAdded")
	event("Player", "CharacterRemoving")
	event("Player", "Chatted")
	roblox.implementMethod("Player", "Kick", function(self, message)
		table.insert(H.kicks, { player = self.Name, message = message })
		H.removePlayer(self)
	end)
	roblox.implementMethod("Player", "GetMouse", function(_self)
		return { X = 640, Y = 360, Hit = roblox.CFrame.new(), Target = nil, Button1Down = Signal.new("Button1Down"), Move = Signal.new("Move") }
	end)
	roblox.implementMethod("Player", "LoadCharacter", function(_self) end)

	-- Remotes -----------------------------------------------------------
	event("RemoteEvent", "OnServerEvent")
	event("RemoteEvent", "OnClientEvent")
	roblox.implementMethod("RemoteEvent", "FireServer", function(self, ...)
		assert(H.localPlayer, "FireServer with no local player")
		signalOf(self, "OnServerEvent"):Fire(H.localPlayer, copyArgs(...))
	end)
	roblox.implementMethod("RemoteEvent", "FireClient", function(self, player, ...)
		assert(typeof(player) == "Instance" and player.ClassName == "Player", "FireClient: first argument must be a Player")
		logClient(player, self, copyArgs(...))
		if player == H.localPlayer then
			signalOf(self, "OnClientEvent"):Fire(copyArgs(...))
		end
	end)
	roblox.implementMethod("RemoteEvent", "FireAllClients", function(self, ...)
		for _, player in ipairs(Players:GetPlayers()) do
			logClient(player, self, copyArgs(...))
		end
		if H.localPlayer then
			signalOf(self, "OnClientEvent"):Fire(copyArgs(...))
		end
	end)
	roblox.implementProperty("RemoteFunction", "OnServerInvoke", function(self)
		return serverInvoke[self]
	end, function(self, callback)
		serverInvoke[self] = callback
	end)
	roblox.implementProperty("RemoteFunction", "OnClientInvoke", function(self)
		return clientInvoke[self]
	end, function(self, callback)
		clientInvoke[self] = callback
	end)
	roblox.implementMethod("RemoteFunction", "InvokeServer", function(self, ...)
		local callback = serverInvoke[self]
		assert(callback, "InvokeServer: no OnServerInvoke set for " .. self.Name)
		assert(H.localPlayer, "InvokeServer with no local player")
		return copyArgs(callback(H.localPlayer, copyArgs(...)))
	end)

	-- Prompts / humanoids / sounds / particles --------------------------
	for _, name in ipairs({ "Triggered", "TriggerEnded", "PromptShown", "PromptHidden", "PromptButtonHoldBegan", "PromptButtonHoldEnded" }) do
		event("ProximityPrompt", name)
	end
	for _, name in ipairs({ "Died", "Running", "StateChanged", "MoveToFinished", "Seated", "Jumping", "HealthChanged" }) do
		event("Humanoid", name)
	end
	roblox.implementMethod("Humanoid", "AddAccessory", function(self, accessory)
		assert(accessory:IsA("Accessory"), "AddAccessory expects an Accessory")
		accessory.Parent = self.Parent
	end)
	roblox.implementMethod("Humanoid", "MoveTo", function() end)
	roblox.implementMethod("Humanoid", "ChangeState", function() end)
	roblox.implementMethod("Humanoid", "GetAccessories", function(self)
		local list = {}
		for _, child in ipairs(self.Parent:GetChildren()) do
			if child:IsA("Accessory") then
				table.insert(list, child)
			end
		end
		return list
	end)
	event("Sound", "Ended")
	event("Sound", "Loaded")
	roblox.implementMethod("Sound", "Play", function() end)
	roblox.implementMethod("Sound", "Stop", function() end)
	roblox.implementMethod("Sound", "Pause", function() end)
	roblox.implementMethod("Sound", "Resume", function() end)
	roblox.implementMethod("ParticleEmitter", "Emit", function(_self, count)
		assert(count == nil or type(count) == "number", "Emit expects a number")
	end)
	roblox.implementMethod("ParticleEmitter", "Clear", function() end)

	-- GUI ---------------------------------------------------------------
	for _, name in ipairs({ "MouseEnter", "MouseLeave", "MouseMoved", "InputBegan", "InputChanged", "InputEnded", "TouchTap", "TouchLongPress", "SelectionGained", "SelectionLost" }) do
		event("GuiObject", name)
	end
	for _, name in ipairs({ "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "MouseButton2Click", "Activated" }) do
		event("GuiButton", name)
	end
	event("TextBox", "FocusLost")
	event("TextBox", "Focused")
	roblox.implementMethod("TextBox", "CaptureFocus", function() end)
	roblox.implementMethod("TextBox", "ReleaseFocus", function() end)
	roblox.implementMethod("GuiObject", "TweenPosition", function(self, position)
		self.Position = position
	end)
	roblox.implementMethod("GuiObject", "TweenSize", function(self, size)
		self.Size = size
	end)

	-- Camera / workspace ------------------------------------------------
	roblox.implementMethod("Camera", "ViewportPointToRay", function(self, _x, _y)
		return { Origin = self.CFrame.Position, Direction = roblox.Vector3.new(0.2, -0.7, -0.6).Unit }
	end)
	roblox.implementMethod("Camera", "ScreenPointToRay", function(self, _x, _y)
		return { Origin = self.CFrame.Position, Direction = roblox.Vector3.new(0.2, -0.7, -0.6).Unit }
	end)
	roblox.implementMethod("Camera", "WorldToViewportPoint", function(_self, _position)
		return roblox.Vector3.new(640, 360, 10), true
	end)
	roblox.implementMethod("Camera", "WorldToScreenPoint", function(_self, _position)
		return roblox.Vector3.new(640, 360, 10), true
	end)
	roblox.implementMethod("Workspace", "GetServerTimeNow", function()
		return clock
	end)
	roblox.implementMethod("Workspace", "Raycast", function(_self, origin, direction, _params)
		assert(typeof(origin) == "Vector3" and typeof(direction) == "Vector3", "Raycast expects two Vector3s")
		-- Only the ground plane (y = 0) exists for raycasts.
		if direction.Y < 0 and origin.Y > 0 then
			local t = origin.Y / -direction.Y
			if t <= 1 then
				return { Position = origin + direction * t, Normal = roblox.Vector3.new(0, 1, 0), Distance = (direction * t).Magnitude, Instance = nil, Material = roblox.Enum.Material.Grass }
			end
		end
		return nil
	end)

	-- Core GUI / sound service ------------------------------------------
	roblox.implementMethod("StarterGui", "SetCore", function() end)
	roblox.implementMethod("StarterGui", "SetCoreGuiEnabled", function() end)
	roblox.implementMethod("StarterGui", "GetCore", function()
		return nil
	end)
	roblox.implementMethod("SoundService", "PlayLocalSound", function() end)
end

----------------------------------------------------------------------
-- Table-based services
----------------------------------------------------------------------
local function typeTag(tbl, name)
	tbl.__type = name
	return tbl
end

local Random = {}
Random.__index = Random
function Random.new(seed)
	local state = math.floor(seed or (clock * 1000)) % 2147483646 + 1
	return setmetatable({ state = state, __type = "Random" }, Random)
end
local function nextUnit(self)
	self.state = (self.state * 48271) % 2147483647
	return self.state / 2147483647
end
function Random:NextNumber(min, max)
	local r = nextUnit(self)
	if min then
		return min + (max - min) * r
	end
	return r
end
function Random:NextInteger(min, max)
	return math.min(max, min + math.floor(nextUnit(self) * (max - min + 1)))
end
function Random:Shuffle(list)
	for i = #list, 2, -1 do
		local j = self:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
end
function Random:Clone()
	return setmetatable({ state = self.state, __type = "Random" }, Random)
end

local TweenInfo = {}
function TweenInfo.new(time, style, direction, repeatCount, reverses, delayTime)
	return typeTag({ Time = time or 1, EasingStyle = style, EasingDirection = direction, RepeatCount = repeatCount or 0, Reverses = reverses or false, DelayTime = delayTime or 0 }, "TweenInfo")
end

local RaycastParams = {}
function RaycastParams.new()
	return typeTag({ FilterType = roblox.Enum.RaycastFilterType.Exclude, FilterDescendantsInstances = {}, IgnoreWater = false }, "RaycastParams")
end

local OverlapParams = {}
function OverlapParams.new()
	return typeTag({ FilterDescendantsInstances = {} }, "OverlapParams")
end

local function makeTweenService()
	local service = {}
	function service:Create(instance, info, goals)
		assert(typeof(instance) == "Instance", "TweenService:Create expects an Instance")
		assert(type(info) == "table" and info.__type == "TweenInfo", "TweenService:Create expects a TweenInfo")
		assert(type(goals) == "table", "TweenService:Create expects a goal table")
		local tween = { Completed = Signal.new("Completed"), PlaybackState = roblox.Enum.PlaybackState.Begin, Instance = instance }
		function tween:Play()
			-- Applying the goals validates every property name and type.
			for property, value in pairs(goals) do
				instance[property] = value
			end
			task.delay(info.Time, function()
				self.PlaybackState = roblox.Enum.PlaybackState.Completed
				self.Completed:Fire(roblox.Enum.PlaybackState.Completed)
			end)
		end
		function tween:Cancel() end
		function tween:Pause() end
		function tween:Destroy() end
		return tween
	end
	return service
end

-- DataStore fake -------------------------------------------------------
H.stores = {} -- [storeName][key] = value
H.dataStoreDown = false -- make every call fail
H.dataStoreUnavailable = false -- make GetDataStore itself fail
H.dataStoreCalls = 0

local function validateStorable(value, path)
	local t = type(value)
	if t == "number" then
		assert(value == value and value ~= math.huge and value ~= -math.huge, "DataStore: NaN / inf at " .. path)
	elseif t == "table" then
		local count, arrayCount = 0, #value
		for k, v in pairs(value) do
			count += 1
			local kt = type(k)
			assert(kt == "string" or kt == "number", "DataStore: bad key type at " .. path)
			if kt == "number" then
				assert(k % 1 == 0 and k >= 1 and k <= arrayCount, "DataStore: sparse / mixed array at " .. path)
			end
			validateStorable(v, path .. "." .. tostring(k))
		end
		assert(arrayCount == 0 or count == arrayCount, "DataStore: table mixes array and dictionary keys at " .. path)
	elseif t ~= "string" and t ~= "boolean" and t ~= "nil" then
		error("DataStore: cannot store a " .. typeof(value) .. " at " .. path)
	end
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopy(v)
	end
	return copy
end
H.deepCopy = deepCopy
H.validateStorable = validateStorable

local function makeDataStoreService()
	local service = {}
	local function check()
		H.dataStoreCalls += 1
		if H.dataStoreDown then
			error("502: API Services rejected request (simulated outage)")
		end
	end
	function service:GetDataStore(name)
		if H.dataStoreUnavailable then
			error("403: Studio access to APIs is not allowed (simulated)")
		end
		local store = H.stores[name]
		if not store then
			store = {}
			H.stores[name] = store
		end
		local api = {}
		function api:GetAsync(key)
			check()
			return deepCopy(store[key])
		end
		function api:SetAsync(key, value)
			check()
			validateStorable(value, key)
			store[key] = deepCopy(value)
		end
		function api:UpdateAsync(key, transform)
			check()
			local result = transform(deepCopy(store[key]), nil)
			if result ~= nil then
				validateStorable(result, key)
				store[key] = deepCopy(result)
			end
			return deepCopy(store[key])
		end
		function api:RemoveAsync(key)
			check()
			store[key] = nil
		end
		return api
	end
	service.GetOrderedDataStore = service.GetDataStore
	return service
end

local tags = {} -- CollectionService: [tag] = signal
local function makeCollectionService()
	local service = {}
	function service:AddTag(instance, tag)
		instance:AddTag(tag)
		if tags[tag] then
			tags[tag]:Fire(instance)
		end
	end
	function service:RemoveTag(instance, tag)
		instance:RemoveTag(tag)
	end
	function service:HasTag(instance, tag)
		return instance:HasTag(tag)
	end
	function service:GetTagged(tag)
		local list = {}
		for _, root in ipairs({ Workspace, Players }) do
			for _, descendant in ipairs(root:GetDescendants()) do
				if descendant:HasTag(tag) then
					table.insert(list, descendant)
				end
			end
		end
		return list
	end
	function service:GetInstanceAddedSignal(tag)
		tags[tag] = tags[tag] or Signal.new("InstanceAdded:" .. tag)
		return tags[tag]
	end
	function service:GetInstanceRemovedSignal(tag)
		return Signal.new("InstanceRemoved:" .. tag)
	end
	return service
end

H.promptTriggered = Signal.new("PromptTriggered")
H.gamePassFinished = Signal.new("PromptGamePassPurchaseFinished")
H.ownedPasses = {} -- [userId][passId] = true
H.input = {
	InputBegan = Signal.new("InputBegan"),
	InputChanged = Signal.new("InputChanged"),
	InputEnded = Signal.new("InputEnded"),
	TouchTap = Signal.new("TouchTap"),
	TouchStarted = Signal.new("TouchStarted"),
	TouchMoved = Signal.new("TouchMoved"),
	TouchEnded = Signal.new("TouchEnded"),
	JumpRequest = Signal.new("JumpRequest"),
	LastInputTypeChanged = Signal.new("LastInputTypeChanged"),
}
H.screenshots = 0
H.closeCallbacks = {}

local function makeServices(side)
	local services = {}

	local runService = {}
	for name, signal in pairs(frameSignals) do
		runService[name] = signal
	end
	function runService:IsServer()
		return side == "server"
	end
	function runService:IsClient()
		return side == "client"
	end
	function runService:IsStudio()
		return H.isStudio == true
	end
	function runService:IsRunning()
		return true
	end
	function runService:BindToRenderStep(name, _priority, fn)
		renderSteps[name] = fn
	end
	function runService:UnbindFromRenderStep(name)
		renderSteps[name] = nil
	end
	services.RunService = runService

	services.TweenService = makeTweenService()
	services.DataStoreService = H.dataStoreService
	services.CollectionService = H.collectionService

	services.HttpService = {
		GenerateGUID = function(_self, _braces)
			timerSeq += 1
			return string.format("GUID-%08d-%04d", timerSeq, math.random(0, 9999))
		end,
		JSONEncode = function(_self, value)
			return require("@lune/serde").encode("json", value)
		end,
		JSONDecode = function(_self, text)
			return require("@lune/serde").decode("json", text)
		end,
	}

	services.MarketplaceService = {
		PromptGamePassPurchaseFinished = H.gamePassFinished,
		PromptProductPurchaseFinished = Signal.new("PromptProductPurchaseFinished"),
		UserOwnsGamePassAsync = function(_self, userId, passId)
			assert(type(userId) == "number" and type(passId) == "number", "UserOwnsGamePassAsync(userId, passId)")
			return H.ownedPasses[userId] ~= nil and H.ownedPasses[userId][passId] == true
		end,
		PromptGamePassPurchase = function(_self, player, passId)
			assert(typeof(player) == "Instance" and type(passId) == "number", "PromptGamePassPurchase(player, passId)")
		end,
		GetProductInfo = function()
			return { Name = "Pass", PriceInRobux = 99 }
		end,
	}

	services.Debris = {
		AddItem = function(_self, instance, lifetime)
			task.delay(lifetime or 10, function()
				pcall(function()
					instance:Destroy()
				end)
			end)
		end,
	}

	local input = {}
	for name, signal in pairs(H.input) do
		input[name] = signal
	end
	input.TouchEnabled = H.touchDevice == true
	input.KeyboardEnabled = H.touchDevice ~= true
	input.MouseEnabled = H.touchDevice ~= true
	input.GamepadEnabled = false
	input.MouseBehavior = roblox.Enum.MouseBehavior.Default
	function input:GetMouseLocation()
		return roblox.Vector2.new(640, 360)
	end
	function input:IsKeyDown()
		return false
	end
	function input:GetLastInputType()
		return roblox.Enum.UserInputType.MouseMovement
	end
	function input:GetFocusedTextBox()
		return nil
	end
	services.UserInputService = input

	services.ProximityPromptService = {
		PromptTriggered = H.promptTriggered,
		PromptShown = Signal.new("PromptShown"),
		PromptHidden = Signal.new("PromptHidden"),
		Enabled = true,
	}
	services.ContextActionService = {
		BindAction = function() end,
		UnbindAction = function() end,
	}
	services.GuiService = {
		GetGuiInset = function()
			return roblox.Vector2.new(0, 36), roblox.Vector2.new(0, 0)
		end,
		TopbarInset = roblox.Rect.new(0, 0, 1280, 36),
		MenuOpened = Signal.new("MenuOpened"),
		MenuClosed = Signal.new("MenuClosed"),
	}
	services.CaptureService = {
		CaptureScreenshot = function(_self, callback)
			H.screenshots += 1
			task.defer(callback, "rbxtemp://capture")
		end,
		PromptSaveCapturesToGallery = function(_self, _ids, callback)
			if callback then
				task.defer(callback, {})
			end
		end,
		CaptureBegan = Signal.new("CaptureBegan"),
		CaptureEnded = Signal.new("CaptureEnded"),
	}
	services.TextService = {
		GetTextSize = function()
			return roblox.Vector2.new(60, 20)
		end,
	}
	services.PolicyService = {
		GetPolicyInfoForPlayerAsync = function()
			return { ArePaidRandomItemsRestricted = false }
		end,
	}
	return services
end

local function makeGameProxy(services)
	local proxy = {}
	proxy.JobId = "test-server-1"
	proxy.PlaceId = 1
	proxy.GameId = 1
	proxy.Loaded = Signal.new("Loaded")
	function proxy:GetService(name)
		local service = services[name]
		if service then
			return service
		end
		return game:GetService(name)
	end
	function proxy:FindService(name)
		return self:GetService(name)
	end
	function proxy:BindToClose(fn)
		table.insert(H.closeCallbacks, fn)
	end
	function proxy:IsLoaded()
		return true
	end
	function proxy:FindFirstChild(name)
		return game:FindFirstChild(name)
	end
	function proxy:WaitForChild(name)
		return game:FindFirstChild(name)
	end
	function proxy:GetChildren()
		return game:GetChildren()
	end
	return setmetatable(proxy, {
		__index = function(_, key)
			-- game.Workspace, game.Players, game.ReplicatedStorage ...
			local ok, value = pcall(function()
				return game:GetService(key)
			end)
			if ok then
				return services[key] or value
			end
			error(tostring(key) .. " is not a valid member of DataModel")
		end,
	})
end

----------------------------------------------------------------------
-- Script environments
----------------------------------------------------------------------
local realTypeof = typeof

local function fakeTypeof(value)
	if type(value) == "table" then
		local tag = rawget(value, "__type")
		if tag then
			return tag
		end
		if getmetatable(value) == Signal then
			return "RBXScriptSignal"
		end
	end
	return realTypeof(value)
end

local sides = {}

local function makeSide(side)
	local services = makeServices(side)
	local env = {}
	local cache = {}
	local loading = {}

	local function load(scriptInstance)
		local scriptEnv = table.clone(env)
		scriptEnv.script = scriptInstance
		return luau.load(scriptInstance.Source, {
			debugName = scriptInstance:GetFullName(),
			environment = scriptEnv,
			injectGlobals = false,
		})
	end

	local function requireModule(module)
		if realTypeof(module) ~= "Instance" or module.ClassName ~= "ModuleScript" then
			error("require expects a ModuleScript, got " .. tostring(module), 2)
		end
		local entry = cache[module]
		if entry then
			return entry.value
		end
		if loading[module] then
			error("circular require of " .. module:GetFullName(), 2)
		end
		loading[module] = true
		local value = load(module)()
		loading[module] = nil
		if value == nil then
			error("ModuleScript did not return a value: " .. module:GetFullName(), 2)
		end
		cache[module] = { value = value }
		return value
	end

	-- standard library
	for _, name in ipairs({ "math", "string", "table", "coroutine", "bit32", "utf8", "buffer", "debug", "pcall", "xpcall", "error", "assert", "select", "type", "tostring", "tonumber", "ipairs", "pairs", "next", "unpack", "rawget", "rawset", "rawequal", "rawlen", "setmetatable", "getmetatable", "newproxy", "_VERSION", "gcinfo", "vector" }) do
		env[name] = (getfenv and getfenv(0) or _G)[name]
	end
	env.unpack = table.unpack
	env.task = task
	env.os = setmetatable({
		clock = function()
			return clock
		end,
		time = function(parts)
			if parts then
				return os.time(parts)
			end
			return EPOCH + math.floor(clock)
		end,
	}, { __index = os })
	env.tick = function()
		return EPOCH + clock
	end
	env.time = function()
		return clock
	end
	env.elapsedTime = env.time
	env.wait = task.wait
	env.spawn = task.spawn
	env.delay = task.delay
	env.typeof = fakeTypeof
	env.print = function(...)
		local parts = table.pack(...)
		for i = 1, parts.n do
			parts[i] = tostring(parts[i])
		end
		table.insert(H.prints, table.concat(parts, " "))
		if H.verbose then
			print("[" .. side .. "] " .. table.concat(parts, " "))
		end
	end
	env.warn = function(...)
		local parts = table.pack(...)
		for i = 1, parts.n do
			parts[i] = tostring(parts[i])
		end
		table.insert(H.warnings, table.concat(parts, " "))
		if H.verbose then
			print("[" .. side .. " WARN] " .. table.concat(parts, " "))
		end
	end
	env.require = requireModule
	env.game = makeGameProxy(services)
	env.workspace = Workspace
	env.Instance = InstanceLib
	env.Enum = roblox.Enum
	env.Random = Random
	env.TweenInfo = TweenInfo
	env.RaycastParams = RaycastParams
	env.OverlapParams = OverlapParams
	env.shared = {}
	env._G = {}
	for _, name in ipairs({ "Vector3", "Vector2", "CFrame", "Color3", "UDim", "UDim2", "NumberRange", "NumberSequence", "NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint", "Rect", "Ray", "Region3", "BrickColor", "Font", "PhysicalProperties", "Vector3int16", "Vector2int16", "Faces", "Axes" }) do
		env[name] = roblox[name]
	end

	local record = { env = env, services = services, require = requireModule, load = load, side = side }
	sides[side] = record
	return record
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------
-- Loads the Rojo-built place file and prepares both sides.
function H.boot(placeBytes, options)
	options = options or {}
	H.isStudio = options.studio == true
	H.touchDevice = options.touch == true
	game = roblox.deserializePlace(placeBytes)
	Players = game:GetService("Players")
	Workspace = game:GetService("Workspace")
	H.game, H.Players, H.Workspace = game, Players, Workspace
	H.ReplicatedStorage = game:GetService("ReplicatedStorage")
	H.ServerScriptService = game:GetService("ServerScriptService")

	setupClasses()
	H.dataStoreService = makeDataStoreService()
	H.collectionService = makeCollectionService()

	local camera = InstanceLib.new("Camera")
	camera.Name = "Camera"
	camera.Parent = Workspace
	Workspace.CurrentCamera = camera
	H.camera = camera

	makeSide("server")
	makeSide("client")
	H.server, H.client = sides.server, sides.client
	math.randomseed(options.seed or 1234)
end

-- Runs every Script under ServerScriptService.
function H.startServer()
	for _, descendant in ipairs(H.ServerScriptService:GetDescendants()) do
		if descendant.ClassName == "Script" then
			task.spawn(sides.server.load(descendant))
		end
	end
	H.flush()
end

local nextUserId = 100

local function buildCharacter(player, cframe)
	local character = InstanceLib.new("Model")
	character.Name = player.Name
	local function part(name, size, offset)
		local p = InstanceLib.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cframe * roblox.CFrame.new(offset)
		p.Position = p.CFrame.Position
		p.Parent = character
		return p
	end
	local hrp = part("HumanoidRootPart", roblox.Vector3.new(2, 2, 1), roblox.Vector3.new(0, 3, 0))
	local head = part("Head", roblox.Vector3.new(2, 1, 1), roblox.Vector3.new(0, 4.5, 0))
	local torso = part("UpperTorso", roblox.Vector3.new(2, 2, 1), roblox.Vector3.new(0, 3, 0))
	for _, name in ipairs({ "HatAttachment", "FaceFrontAttachment", "HairAttachment" }) do
		local attachment = InstanceLib.new("Attachment")
		attachment.Name = name
		attachment.Parent = head
	end
	for _, name in ipairs({ "NeckAttachment", "BodyBackAttachment", "BodyFrontAttachment" }) do
		local attachment = InstanceLib.new("Attachment")
		attachment.Name = name
		attachment.Parent = torso
	end
	local humanoid = InstanceLib.new("Humanoid")
	humanoid.Parent = character
	character.PrimaryPart = hrp
	character.Parent = Workspace
	return character
end

-- Adds a fake player (with a character) and fires PlayerAdded.
function H.addPlayer(name, options)
	options = options or {}
	nextUserId += 1
	local player = InstanceLib.new("Player")
	player.Name = name
	player.DisplayName = options.displayName or name
	player.UserId = options.userId or nextUserId
	local gui = InstanceLib.new("PlayerGui")
	gui.Parent = player
	local scripts = InstanceLib.new("PlayerScripts")
	scripts.Parent = player
	player.Character = buildCharacter(player, roblox.CFrame.new(0, 0, 30))
	player.Parent = Players
	if options["local"] then
		H.localPlayer = player
	end
	signalOf(Players, "PlayerAdded"):Fire(player)
	H.flush()
	return player
end

function H.removePlayer(player)
	if player.Parent ~= Players then
		return
	end
	signalOf(Players, "PlayerRemoving"):Fire(player)
	H.advance(0.5)
	local character = player.Character
	player.Parent = nil
	if character then
		character.Parent = nil
	end
	if H.localPlayer == player then
		H.localPlayer = nil
	end
end

-- Moves a fake player's character.
function H.movePlayer(player, position)
	local character = player.Character
	character:PivotTo(roblox.CFrame.new(position))
end

-- Simulates `player`'s character touching `part`.
function H.touch(part, player)
	signalOf(part, "Touched"):Fire(player.Character.HumanoidRootPart)
	H.flush()
end

-- Simulates a player triggering a ProximityPrompt.
function H.trigger(prompt, player)
	signalOf(prompt, "Triggered"):Fire(player)
	if player == H.localPlayer then
		H.promptTriggered:Fire(prompt, player)
	end
	H.flush()
end

-- Client -> server RemoteEvent as a specific player.
function H.fire(player, remoteName, ...)
	local remote = H.ReplicatedStorage.Remotes:FindFirstChild(remoteName)
	assert(remote, "no remote named " .. remoteName)
	signalOf(remote, "OnServerEvent"):Fire(player, copyArgs(...))
	H.advance(0.3) -- keeps test traffic under the server's rate limits
end

-- Client -> server RemoteFunction as a specific player.
function H.invoke(player, remoteName, ...)
	local remote = H.ReplicatedStorage.Remotes:FindFirstChild(remoteName)
	assert(remote, "no remote named " .. remoteName)
	local callback = serverInvoke[remote]
	assert(callback, "no OnServerInvoke for " .. remoteName)
	local args = table.pack(copyArgs(...))
	local result
	H.advance(0.4) -- keeps test traffic under the server's rate limits
	local thread = task.spawn(function()
		result = table.pack(callback(player, table.unpack(args, 1, args.n)))
	end)
	local guard = 0
	while coroutine.status(thread) ~= "dead" and guard < 2000 do
		H.advance(0.1)
		guard += 1
	end
	assert(result, "RemoteFunction " .. remoteName .. " never returned")
	return copyArgs(table.unpack(result, 1, result.n))
end

-- Last payload the server sent this player on a RemoteEvent.
function H.lastSent(player, remoteName)
	local byPlayer = H.clientLog[player]
	local list = byPlayer and byPlayer[remoteName]
	return list and list[#list] or nil
end

function H.sentCount(player, remoteName)
	local byPlayer = H.clientLog[player]
	local list = byPlayer and byPlayer[remoteName]
	return list and #list or 0
end

-- Copies StarterGui / StarterPlayerScripts to the local player and runs
-- every LocalScript, like Roblox does when a player joins.
function H.startClient()
	assert(H.localPlayer, "add a local player first")
	local player = H.localPlayer
	local started = {}
	local function prepare(container, target)
		for _, child in ipairs(container:GetChildren()) do
			local copy = child:Clone()
			initDefaults(copy)
			for _, descendant in ipairs(copy:GetDescendants()) do
				initDefaults(descendant)
			end
			copy.Parent = target
			if copy.ClassName == "LocalScript" then
				table.insert(started, copy)
			end
			for _, descendant in ipairs(copy:GetDescendants()) do
				if descendant.ClassName == "LocalScript" then
					table.insert(started, descendant)
				end
			end
		end
	end
	prepare(game:GetService("StarterGui"), player.PlayerGui)
	prepare(game:GetService("StarterPlayer").StarterPlayerScripts, player.PlayerScripts)
	for _, localScript in ipairs(started) do
		task.spawn(sides.client.load(localScript))
	end
	H.flush()
	return started
end

-- Fires a GuiButton's click events (what a tap / click does).
function H.click(button)
	signalOf(button, "MouseButton1Down"):Fire(0, 0)
	signalOf(button, "MouseButton1Up"):Fire(0, 0)
	signalOf(button, "MouseButton1Click"):Fire()
	signalOf(button, "Activated"):Fire({ UserInputType = roblox.Enum.UserInputType.MouseButton1, UserInputState = roblox.Enum.UserInputState.End, Position = roblox.Vector3.new(0, 0, 0) }, 1)
end

-- Runs game:BindToClose callbacks (server shutdown).
function H.shutdown()
	for _, fn in ipairs(H.closeCallbacks) do
		task.spawn(fn)
	end
	H.advance(30)
end

H.roblox = roblox
H.task = task

return H
