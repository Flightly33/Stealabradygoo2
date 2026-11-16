--[[
	LightingClient
	Runs the day / night cycle on each player's screen.

	  * The time of day comes from the shared server clock, so every player
	    sees the same sky, but nothing is sent over the network per frame.
	  * Dusk and dawn blend the lighting, atmosphere and colour grade between
	    the day and night palettes in Modules/TimeOfDay, with a golden glow
	    at sunrise and sunset.
	  * At night street lamps and string lights switch on, house and shop
	    windows glow warm, and fireflies come out.
	  * Settings: "Day & night" off = permanent sunny afternoon.
	    "Low graphics" turns off depth of field, sun rays and clouds.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Client = ReplicatedStorage:WaitForChild("Client")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local State = require(Client:WaitForChild("ClientState"))
local TimeOfDay = require(Modules:WaitForChild("TimeOfDay"))

local DAY, NIGHT, TAGS = TimeOfDay.Day, TimeOfDay.Night, TimeOfDay.Tags
local WINDOW_GLOW = Color3.fromRGB(255, 212, 150)

local isNight = nil -- unknown until the first update

local function lerp(a, b, t)
	return a + (b - a) * t
end

----------------------------------------------------------------------
-- Night switches
----------------------------------------------------------------------
local function applyLight(light, night)
	if light:IsA("Light") then
		light.Enabled = night
	end
end

local function applyFx(emitter, night)
	if emitter:IsA("ParticleEmitter") then
		emitter.Enabled = night
	end
end

local function applyWindow(part, night)
	if not part:IsA("BasePart") then
		return
	end
	if part:GetAttribute("DayMaterial") == nil then
		-- remember the daytime look (attributes set on the client stay local)
		part:SetAttribute("DayMaterial", part.Material.Name)
		part:SetAttribute("DayColor", part.Color)
		part:SetAttribute("DayTransparency", part.Transparency)
	end
	if night then
		part.Material = Enum.Material.Neon
		part.Color = WINDOW_GLOW
		part.Transparency = 0.2
	else
		part.Material = Enum.Material[part:GetAttribute("DayMaterial")]
		part.Color = part:GetAttribute("DayColor")
		part.Transparency = part:GetAttribute("DayTransparency")
	end
end

local function setNight(night)
	if isNight == night then
		return
	end
	isNight = night
	for _, light in ipairs(CollectionService:GetTagged(TAGS.NightLight)) do
		applyLight(light, night)
	end
	for _, emitter in ipairs(CollectionService:GetTagged(TAGS.NightFx)) do
		applyFx(emitter, night)
	end
	for _, part in ipairs(CollectionService:GetTagged(TAGS.NightWindow)) do
		applyWindow(part, night)
	end
end

-- Houses are rebuilt as Brady grows: new lamps / windows join the current state.
CollectionService:GetInstanceAddedSignal(TAGS.NightLight):Connect(function(light)
	applyLight(light, isNight == true)
end)
CollectionService:GetInstanceAddedSignal(TAGS.NightFx):Connect(function(emitter)
	applyFx(emitter, isNight == true)
end)
CollectionService:GetInstanceAddedSignal(TAGS.NightWindow):Connect(function(part)
	if isNight then
		applyWindow(part, true)
	end
end)

----------------------------------------------------------------------
-- Graphics quality
----------------------------------------------------------------------
local function applyQuality(low)
	local dof = Lighting:FindFirstChild("DepthOfField")
	local rays = Lighting:FindFirstChild("SunRays")
	local bloom = Lighting:FindFirstChild("Bloom")
	if dof then
		dof.Enabled = not low
	end
	if rays then
		rays.Enabled = not low
	end
	if bloom then
		bloom.Intensity = low and 0.15 or 0.3
	end
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	local clouds = terrain and terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds.Enabled = not low
	end
end

State.on("settings", function(settings)
	applyQuality(settings and settings.lowGfx == true)
end)

----------------------------------------------------------------------
-- The cycle
----------------------------------------------------------------------
local function update()
	local cycle = State.setting("dayNight") ~= false
	local clock = cycle and TimeOfDay.clockAt(Workspace:GetServerTimeNow()) or 14
	local n = TimeOfDay.nightAmount(clock)
	local golden = cycle and TimeOfDay.goldenAmount(clock) or 0

	Lighting.ClockTime = clock
	Lighting.Brightness = lerp(DAY.brightness, NIGHT.brightness, n)
	Lighting.Ambient = DAY.ambient:Lerp(NIGHT.ambient, n)
	Lighting.OutdoorAmbient = DAY.outdoor:Lerp(NIGHT.outdoor, n)
	Lighting.ExposureCompensation = lerp(DAY.exposure, NIGHT.exposure, n)

	local grade = Lighting:FindFirstChild("Grade")
	if grade then
		grade.TintColor = DAY.tint:Lerp(NIGHT.tint, n):Lerp(TimeOfDay.Golden, golden * 0.6)
		grade.Saturation = lerp(DAY.saturation, NIGHT.saturation, n) + golden * 0.08
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Color = DAY.atmosphere:Lerp(NIGHT.atmosphere, n):Lerp(TimeOfDay.Golden, golden * 0.5)
		atmosphere.Decay = DAY.decay:Lerp(NIGHT.decay, n)
	end

	-- small hysteresis so lights don't flicker right at the threshold
	if isNight then
		setNight(n > 0.35)
	else
		setNight(n > 0.55)
	end
end

State.wait()
update()
task.spawn(function()
	while true do
		task.wait(0.1)
		local ok, err = pcall(update)
		if not ok then
			warn("[LightingClient] " .. tostring(err))
			task.wait(5)
		end
	end
end)
