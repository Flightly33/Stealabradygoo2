--[[
	Util
	Small pure-Luau helpers shared by the server and the client.
	Nothing in here touches Roblox services, so it is safe to require anywhere.
]]

local Util = {}

----------------------------------------------------------------------
-- Signal: a tiny event object (Connect / Fire) so modules can talk to
-- each other without creating BindableEvent instances.
----------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local handlers = self._handlers
	local entry = { fn = fn }
	table.insert(handlers, entry)
	local connection = { Connected = true }
	function connection.Disconnect()
		if not connection.Connected then
			return
		end
		connection.Connected = false
		local index = table.find(handlers, entry)
		if index then
			table.remove(handlers, index)
		end
	end
	return connection
end

function Signal:Fire(...)
	-- Copy first so handlers can disconnect themselves while we iterate.
	for _, entry in ipairs(table.clone(self._handlers)) do
		task.spawn(entry.fn, ...)
	end
end

Util.Signal = Signal

----------------------------------------------------------------------
-- Tables
----------------------------------------------------------------------
function Util.deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = Util.deepCopy(v)
	end
	return copy
end

function Util.count(dict)
	local n = 0
	for _ in pairs(dict) do
		n += 1
	end
	return n
end

function Util.keys(dict)
	local list = {}
	for k in pairs(dict) do
		table.insert(list, k)
	end
	return list
end

----------------------------------------------------------------------
-- Numbers
----------------------------------------------------------------------
-- True only for real, finite numbers (rejects NaN / inf sent by exploiters).
function Util.isNumber(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Util.round(value)
	return math.floor(value + 0.5)
end

-- 1234567 -> "1,234,567"
function Util.commas(value)
	local text = tostring(math.floor(value))
	local formatted = text
	while true do
		local replaced
		formatted, replaced = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if replaced == 0 then
			break
		end
	end
	return formatted
end

-- 1234 -> "1,234"   1250000 -> "1.25M"
function Util.short(value)
	value = math.floor(value)
	if value < 100000 then
		return Util.commas(value)
	elseif value < 1000000 then
		return string.format("%.1fK", value / 1000)
	elseif value < 1000000000 then
		return string.format("%.2fM", value / 1000000)
	end
	return string.format("%.2fB", value / 1000000000)
end

-- 75 -> "1:15"
function Util.clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Day number in UTC. Used for daily rewards / daily tasks.
function Util.today()
	return os.time() // 86400
end

----------------------------------------------------------------------
-- Random
----------------------------------------------------------------------
-- Picks one entry from `list` where weightOf(entry) returns its weight.
function Util.weighted(list, weightOf, rng)
	local total = 0
	for _, entry in ipairs(list) do
		total += math.max(0, weightOf(entry))
	end
	if total <= 0 then
		return nil
	end
	local roll = (rng and rng:NextNumber() or math.random()) * total
	for _, entry in ipairs(list) do
		roll -= math.max(0, weightOf(entry))
		if roll <= 0 then
			return entry
		end
	end
	return list[#list]
end

function Util.pick(list, rng)
	if #list == 0 then
		return nil
	end
	local index = rng and rng:NextInteger(1, #list) or math.random(1, #list)
	return list[index]
end

return Util
