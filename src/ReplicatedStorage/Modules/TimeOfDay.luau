--[[
	TimeOfDay
	Shared rules for the day / night cycle. The SERVER sets up the lighting
	once (World/Environment); every CLIENT then animates the time of day
	locally from the shared server clock (LightingClient), so all players see
	the same time and the server sends nothing per frame.
]]

local Modules = script.Parent
local Config = require(Modules.Config)

local TimeOfDay = {}

local rgb = Color3.fromRGB

TimeOfDay.Tags = {
	NightFx = "NightFx", -- particle emitters only on at night (fireflies)
	NightLight = "NightLight", -- lights only on at night (street lamps)
	NightWindow = "NightWindow", -- glass that glows warm at night
}

TimeOfDay.Length = Config.DayLength

-- Lighting palettes LightingClient blends between.
TimeOfDay.Day = {
	brightness = 1.7,
	ambient = rgb(92, 94, 112),
	outdoor = rgb(142, 142, 158),
	tint = rgb(255, 250, 240),
	atmosphere = rgb(199, 214, 240),
	decay = rgb(110, 132, 178),
	exposure = -0.2,
	saturation = 0.2,
}
TimeOfDay.Night = {
	brightness = 0.8,
	ambient = rgb(70, 78, 122),
	outdoor = rgb(84, 92, 140),
	tint = rgb(196, 210, 255),
	atmosphere = rgb(70, 82, 130),
	decay = rgb(40, 46, 86),
	exposure = 0.2,
	saturation = 0.05,
}
-- Golden-hour tint blended in around sunrise / sunset.
TimeOfDay.Golden = rgb(255, 214, 170)

-- Server time -> clock hours. 75% of the cycle is daytime (6:30 - 18:30).
function TimeOfDay.clockAt(serverTime)
	local phase = (serverTime / TimeOfDay.Length + 0.25) % 1
	if phase < 0.75 then
		return 6.5 + phase / 0.75 * 12
	end
	return (18.5 + (phase - 0.75) / 0.25 * 12) % 24
end

-- 0 = full day, 1 = full night, with smooth dusk and dawn.
function TimeOfDay.nightAmount(clock)
	if clock >= 7.5 and clock <= 17.5 then
		return 0
	elseif clock >= 19 or clock <= 5.5 then
		return 1
	elseif clock > 17.5 then
		return (clock - 17.5) / 1.5
	end
	return 1 - (clock - 5.5) / 2
end

-- 0..1 strength of the golden-hour glow (peaks at sunrise / sunset).
function TimeOfDay.goldenAmount(clock)
	local function bump(center)
		return math.max(0, 1 - math.abs(clock - center) / 1.3)
	end
	return math.max(bump(6.6), bump(18))
end

return TimeOfDay
