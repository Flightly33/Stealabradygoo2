--[[
	BradyAnimator (client)
	Animates every Brady in the world procedurally - no uploaded animation
	assets. The server only replicates a few attributes on each model:

	    State / Pose               what he is doing
	    IdleStyle / WalkStyle      which idle + walk he uses (changes with age
	                               and with special Archive / Grail pieces)
	    WalkFrom/To/Start/Dur      the straight line he is walking

	Each frame this module turns those into joint rotations. An animation is
	just a function that fills in six joint offsets:

	    W  waist (whole body)   N  neck
	    LS / RS  shoulders      LH / RH  hips

	Offsets are blended over time, so switching animations is always smooth.

	Angle cheat-sheet (Brady faces -Z):
	    arm / leg  +X = swing forward      head  +X = look up
	    right arm  +Z = raise outwards     left arm  -Z = raise outwards
	    waist      -X = lean forward       +Y = turn to his left

	PERFORMANCE: one RenderStepped connection for all Bradys, nothing is
	allocated per joint per frame beyond CFrames, and Bradys far from the
	camera are skipped entirely.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BradyAnimator = {}

local TAG = "BradyGoo"
local JOINTS = { W = "Waist", N = "Neck", LS = "LeftShoulder", RS = "RightShoulder", LH = "LeftHip", RH = "RightHip" }
local KEYS = { "W", "N", "LS", "RS", "LH", "RH" }
local IDENTITY = CFrame.new()

local rad, sin, cos, abs, min, max = math.rad, math.sin, math.cos, math.abs, math.min, math.max

local function A(x, y, z)
	return CFrame.Angles(rad(x or 0), rad(y or 0), rad(z or 0))
end

local function T(x, y, z)
	return CFrame.new(x or 0, y or 0, z or 0)
end

local entries = {} -- [model] = entry
local maxDistance = 140
local lowGraphics = false

-- Fired as (model, newState, oldState, entry) so BradyClient can add effects.
local stateListeners = {}
function BradyAnimator.onStateChanged(fn)
	table.insert(stateListeners, fn)
end

----------------------------------------------------------------------
-- IDLE STYLES            fn(o, t, T, e)   t = time in state, T = global time
----------------------------------------------------------------------
local IDLE = {}

-- Baby Brady sits on the floor and wobbles.
function IDLE.BabyWobble(o, _t, g, e)
	o.W = T(0, -(e.hip - 0.42 * e.S), 0) * A(sin(g * 2) * 6, 0, sin(g * 1.3) * 8)
	o.LH = A(84, 0, -14)
	o.RH = A(84, 0, 14)
	o.LS = A(20 + sin(g * 3.1) * 32, 0, -34)
	o.RS = A(20 + sin(g * 2.6 + 1) * 32, 0, 34)
	o.N = A(sin(g * 2.2) * 8, sin(g * 1.1) * 16, sin(g * 1.7) * 6)
end

function IDLE.Bouncy(o, _t, g, e)
	local bounce = abs(sin(g * 3.6))
	o.W = T(0, bounce * 0.16 * e.S, 0) * A(0, sin(g * 0.8) * 8, 0)
	o.LS = A(sin(g * 3.6) * 14, 0, -10 - bounce * 10)
	o.RS = A(-sin(g * 3.6) * 14, 0, 10 + bounce * 10)
	o.N = A(sin(g * 1.4) * 5, sin(g * 0.9) * 22, 0)
end

function IDLE.Cool(o, _t, g, e)
	o.W = T(sin(g * 1.2) * 0.05 * e.S, 0, 0) * A(2, sin(g * 0.6) * 5, sin(g * 1.2) * 3)
	o.LS = A(4, 0, -9)
	o.RS = A(4, 0, 9)
	o.LH = A(0, 0, -3)
	o.RH = A(0, 0, 3)
	o.N = A(sin(g * 4.2) * 5, sin(g * 0.5) * 14, 0) -- nodding to a beat only he can hear
end

-- Teen Brady stares at an invisible phone.
function IDLE.Slouch(o, _t, g)
	o.W = A(-9, 0, sin(g * 0.7) * 2)
	o.LH = A(9, 0, -2)
	o.RH = A(9, 0, 2)
	o.LS = A(58, 0, 22)
	o.RS = A(58 + sin(g * 6) * 3, 0, -22)
	o.N = A(-20 + sin(g * 0.8) * 3, sin(g * 0.4) * 10, 0)
end

function IDLE.Model(o, _t, g, e)
	o.W = T(0.06 * e.S, 0, 0) * A(4, sin(g * 0.6) * 7, -4)
	o.LH = A(14, 0, -3)
	o.RH = A(-4, 0, 5)
	o.LS = A(6, 0, -8)
	o.RS = A(-6, 0, 34)
	o.N = A(5, sin(g * 0.5) * 24, 3)
end

-- Almost motionless. Hands "in pockets". Every so often he checks his sleeve.
function IDLE.ArchiveLean(o, _t, g)
	local look = (g % 7) > 5.6 and 1 or 0
	o.W = A(6, 0, -2)
	o.LH = A(-6, 0, -4)
	o.RH = A(4, 0, 4)
	o.LS = A(10 + look * 70, 0, -12 + look * 30)
	o.RS = A(10, 0, 12)
	o.N = A(-12 - look * 10, sin(g * 0.3) * 12 + look * 25, 0)
end

-- Legendary Brady Goo hovers with his arms crossed.
function IDLE.Legend(o, _t, g, e)
	o.W = T(0, (0.28 + sin(g * 1.6) * 0.1) * e.S, 0) * A(3, sin(g * 0.4) * 8, 0)
	o.LS = A(72, 0, 46)
	o.RS = A(72, 0, -46)
	o.LH = A(-8, 0, -3)
	o.RH = A(-14, 0, 3)
	o.N = A(6, sin(g * 0.5) * 12, 0)
end

----------------------------------------------------------------------
-- WALK STYLES
----------------------------------------------------------------------
local WALK = {}

function WALK.Crawl(o, _t, g, e)
	local w = g * 9
	o.W = T(0, -(e.hip - 0.6 * e.S), 0) * A(-78, sin(w) * 5, 0)
	o.N = A(68, 0, 0)
	o.LS = A(82 + sin(w) * 30, 0, -8)
	o.RS = A(82 - sin(w) * 30, 0, 8)
	o.LH = A(66 - sin(w) * 26, 0, -6)
	o.RH = A(66 + sin(w) * 26, 0, 6)
end

function WALK.Waddle(o, _t, g, e)
	local w = g * 10
	o.W = T(0, abs(sin(w)) * 0.1 * e.S, 0) * A(0, 0, sin(w) * 11)
	o.LH = A(sin(w) * 26, 0, 0)
	o.RH = A(-sin(w) * 26, 0, 0)
	o.LS = A(0, 0, -48 + sin(w) * 12)
	o.RS = A(0, 0, 48 + sin(w) * 12)
	o.N = A(0, 0, -sin(w) * 8)
end

function WALK.Run(o, _t, g, e)
	local w = g * 13
	o.W = T(0, abs(sin(w)) * 0.22 * e.S, 0) * A(-12, sin(w) * 6, 0)
	o.LH = A(sin(w) * 48 + 10, 0, 0)
	o.RH = A(-sin(w) * 48 + 10, 0, 0)
	o.LS = A(-sin(w) * 58, 0, -8)
	o.RS = A(sin(w) * 58, 0, 8)
	o.N = A(8, 0, 0)
end

function WALK.Bop(o, _t, g, e)
	local w = g * 9
	o.W = T(0, abs(sin(w)) * 0.12 * e.S, 0) * A(-4, sin(w) * 9, sin(w) * 4)
	o.LH = A(sin(w) * 32 + 4, 0, 0)
	o.RH = A(-sin(w) * 32 + 4, 0, 0)
	o.LS = A(-sin(w) * 26, 0, -10)
	o.RS = A(sin(w) * 26, 0, 10)
	o.N = A(sin(w * 2) * 5, -sin(w) * 6, 0)
end

function WALK.Slouch(o, _t, g, e)
	local w = g * 7.5
	o.W = T(0, abs(sin(w)) * 0.05 * e.S, 0) * A(-13, 0, sin(w) * 2)
	o.LH = A(sin(w) * 26 + 13, 0, 0)
	o.RH = A(-sin(w) * 26 + 13, 0, 0)
	o.LS = A(14 - sin(w) * 8, 0, -4)
	o.RS = A(14 + sin(w) * 8, 0, 4)
	o.N = A(-18, 0, 0)
end

function WALK.Strut(o, _t, g, e)
	local w = g * 8
	o.W = T(sin(w) * 0.08 * e.S, abs(sin(w)) * 0.08 * e.S, 0) * A(3, sin(w) * 11, -sin(w) * 6)
	o.LH = A(sin(w) * 34 - 3, 0, 3)
	o.RH = A(-sin(w) * 34 - 3, 0, -3)
	o.LS = A(-sin(w) * 18, 0, -12)
	o.RS = A(sin(w) * 18, 0, 12)
	o.N = A(6, -sin(w) * 8, 0)
end

-- Slow, long strides, hands in pockets, head down. Very serious.
function WALK.ArchiveWalk(o, _t, g, e)
	local w = g * 5.5
	o.W = T(0, abs(sin(w)) * 0.05 * e.S, 0) * A(6, sin(w) * 4, 0)
	o.LH = A(sin(w) * 24 - 6, 0, 0)
	o.RH = A(-sin(w) * 24 - 6, 0, 0)
	o.LS = A(12, 0, -12)
	o.RS = A(12, 0, 12)
	o.N = A(-14, sin(w * 0.5) * 6, 0)
end

-- He does not walk. He glides.
function WALK.LegendWalk(o, _t, g, e)
	o.W = T(0, (0.4 + sin(g * 3) * 0.08) * e.S, 0) * A(-10, 0, sin(g * 2) * 3)
	o.LS = A(72, 0, 46)
	o.RS = A(72, 0, -46)
	o.LH = A(-16, 0, -2)
	o.RH = A(-26, 0, 2)
	o.N = A(12, 0, 0)
end

----------------------------------------------------------------------
-- POSES (mirror, fashion display, runway, random idle poses)
----------------------------------------------------------------------
local POSE = {}

function POSE.Wave(o, _t, g)
	o.W = A(0, 0, -3)
	o.RS = A(0, 0, 150 + sin(g * 9) * 18)
	o.LS = A(0, 0, -8)
	o.N = A(4, 0, 8)
end

function POSE.Peace(o, _t, g)
	o.W = A(0, -8, 5)
	o.RS = A(10, 0, 138 + sin(g * 2) * 3)
	o.LS = A(0, 0, -28)
	o.LH = A(0, 0, -6)
	o.N = A(4, 0, -12)
end

function POSE.Dab(o)
	o.W = A(-10, 10, -12)
	o.LS = A(128, 0, 62)
	o.RS = A(10, 0, 118)
	o.N = A(-34, 26, 0)
	o.LH = A(8, 0, -8)
	o.RH = A(8, 0, 8)
end

function POSE.HandsOnHips(o, _t, g)
	o.W = A(6 + sin(g * 1.5) * 1, 0, 0)
	o.LS = A(-12, 0, -40)
	o.RS = A(-12, 0, 40)
	o.LH = A(-6, 0, -9)
	o.RH = A(-6, 0, 9)
	o.N = A(8, 0, 0)
end

function POSE.Flex(o, _t, g)
	local pump = sin(g * 5) * 6
	o.W = A(4, 0, 0)
	o.LS = A(0, 0, -118 - pump)
	o.RS = A(0, 0, 118 + pump)
	o.LH = A(0, 0, -8)
	o.RH = A(0, 0, 8)
	o.N = A(10, 0, 0)
end

function POSE.Thinker(o, _t, g)
	o.W = A(-4, 0, 3)
	o.RS = A(118, 0, -40)
	o.LS = A(42, 0, 36)
	o.LH = A(8, 0, -2)
	o.N = A(-12 + sin(g * 1.2) * 2, 16, 0)
end

function POSE.ModelPose(o, _t, g)
	o.W = A(8, -16, -5)
	o.RS = A(-22, 0, 28)
	o.LS = A(10, 0, -32)
	o.LH = A(20, 0, -2)
	o.RH = A(-8, 0, 4)
	o.N = A(5, 30 + sin(g * 0.8) * 4, 0)
end

function POSE.ArchiveStance(o)
	o.W = A(-10, 0, 0)
	o.LS = A(14, 0, -12)
	o.RS = A(14, 0, 12)
	o.LH = A(10, 0, -9)
	o.RH = A(10, 0, 9)
	o.N = A(-18, 0, 0)
end

function POSE.Salute(o)
	o.W = A(3, 0, 0)
	o.RS = A(150, 0, -30)
	o.LS = A(0, 0, -4)
	o.N = A(6, 0, 0)
end

function POSE.LegendPose(o, _t, g, e)
	o.W = T(0, (0.6 + sin(g * 2) * 0.14) * e.S, 0) * A(4, 0, 0)
	o.LS = A(72, 0, 46)
	o.RS = A(72, 0, -46)
	o.LH = A(-10, 0, -3)
	o.RH = A(-18, 0, 3)
	o.N = A(10, 0, 0)
end

function POSE.GrailFloat(o, _t, g, e)
	o.W = T(0, (1.3 + sin(g * 1.8) * 0.2) * e.S, 0) * A(0, g * 40, 0)
	o.LH = A(72, 0, 36)
	o.RH = A(72, 0, -36)
	o.LS = A(0, 0, -62)
	o.RS = A(0, 0, 62)
	o.N = A(8, 0, 0)
end

function POSE.TPose(o)
	o.LS = A(0, 0, -90)
	o.RS = A(0, 0, 90)
end

function POSE.Griddy(o, _t, g, e)
	local w = g * 11
	o.W = T(0, abs(sin(w)) * 0.2 * e.S, 0) * A(-14, sin(w) * 8, 0)
	o.LH = A(max(0, sin(w)) * 70, 0, 0)
	o.RH = A(max(0, -sin(w)) * 70, 0, 0)
	o.LS = A(-30 + sin(w * 2) * 34, 0, -18)
	o.RS = A(-30 + sin(w * 2) * 34, 0, 18)
	o.N = A(10, 0, sin(w) * 6)
end

function POSE.Faint(o, t, g, e)
	if t < 0.9 then
		o.W = A(14, 0, 0)
		o.RS = A(150, 0, -34) -- back of the hand to the forehead
		o.N = A(22, 0, 0)
	else
		o.W = T(0, -(e.hip - 0.5 * e.S), 0) * A(90, 0, 0)
		o.LS = A(0, 0, -80)
		o.RS = A(0, 0, 80)
		o.LH = A(sin(g * 9) * 6, 0, -10)
		o.RH = A(0, 0, 10)
	end
end

----------------------------------------------------------------------
-- STATES
----------------------------------------------------------------------
local STATE = {}

function STATE.Pose(o, t, g, e)
	local pose = POSE[e.pose] or POSE.Peace
	pose(o, t, g, e)
end

-- Funny eating: an excited hop, then shovelling food into his face.
function STATE.Eat(o, t, g, e)
	if t < 0.55 then
		o.W = T(0, abs(sin(t * 11)) * 0.5 * e.S, 0)
		o.LS = A(0, 0, -150)
		o.RS = A(0, 0, 150)
		o.N = A(14, 0, 0)
	else
		local chew = sin(t * 13)
		o.W = A(-6, 0, chew * 2)
		o.RS = A(104 + chew * 22, 0, -26)
		o.LS = A(96 - chew * 22, 0, 26)
		o.N = A(-6 + chew * 7, 0, 0)
	end
end

-- Funny sleeping: flat on his back, one arm flopped out, a leg twitching.
function STATE.Sleep(o, _t, g, e)
	local breathe = sin(g * 1.6)
	o.W = T(0, -(e.hip - 0.5 * e.S) + breathe * 0.03 * e.S, 0) * A(90, 0, 0)
	o.LS = A(0, 0, -84)
	o.RS = A(38 + breathe * 4, 0, -24)
	o.LH = A(0, 0, -14)
	o.RH = A((g % 5) > 4.4 and sin(g * 30) * 16 or 0, 0, 12)
	o.N = A(0, 22, 0)
end

function STATE.Shower(o, t, g, e)
	local scrub = sin(t * 12)
	o.W = T(0, abs(sin(t * 5)) * 0.1 * e.S, 0) * A(0, t * 140, 0)
	o.LS = A(152, 0, -18 + scrub * 16)
	o.RS = A(152, 0, 18 - scrub * 16)
	o.N = A(8, 0, scrub * 5)
end

function STATE.Brush(o, t)
	local stroke = sin(t * 14)
	o.W = A(0, 0, -4)
	o.RS = A(162 + stroke * 12, 0, 12)
	o.LS = A(0, 0, -10)
	o.N = A(-4, 0, -12)
end

-- Bends over to scrub his shoes.
function STATE.ShoeClean(o, t)
	local scrub = sin(t * 12)
	o.W = A(-58, 0, 0)
	o.LH = A(58, 0, -6)
	o.RH = A(58, 0, 6)
	o.LS = A(76 + scrub * 14, 0, 8)
	o.RS = A(76 - scrub * 14, 0, -8)
	o.N = A(30, 0, 0)
end

function STATE.Play(o, t, _g, e)
	local w = t * 9
	o.W = T(0, abs(sin(w)) * 0.55 * e.S, 0) * A(0, sin(w * 0.5) * 20, 0)
	o.LS = A(sin(w) * 60, 0, -46)
	o.RS = A(-sin(w) * 60, 0, 46)
	o.LH = A(max(0, sin(w)) * 40, 0, -6)
	o.RH = A(max(0, -sin(w)) * 40, 0, 6)
	o.N = A(10, 0, sin(w) * 8)
end

function STATE.Dance(o, t, _g, e)
	local w = t * 8
	o.W = T(sin(w) * 0.28 * e.S, abs(sin(w)) * 0.24 * e.S, 0) * A(0, sin(w * 0.5) * 24, sin(w) * 9)
	o.LS = A(0, 0, -70 - sin(w) * 60)
	o.RS = A(0, 0, 70 - sin(w) * 60)
	o.LH = A(max(0, sin(w)) * 34, 0, -8)
	o.RH = A(max(0, -sin(w)) * 34, 0, 8)
	o.N = A(6, -sin(w * 0.5) * 16, sin(w) * 10)
end

-- Celebration: jumps with both arms up and spins once.
function STATE.Celebrate(o, t, _g, e)
	local spin = min(t, 1.1) / 1.1 * 360
	o.W = T(0, abs(sin(t * 6.5)) * 1.1 * e.S, 0) * A(0, spin, 0)
	o.LS = A(0, 0, -162 + sin(t * 18) * 14)
	o.RS = A(0, 0, 162 - sin(t * 18) * 14)
	o.LH = A(0, 0, -12)
	o.RH = A(0, 0, 12)
	o.N = A(16, 0, 0)
end

function STATE.Excited(o, t, _g, e)
	o.W = T(0, abs(sin(t * 12)) * 0.45 * e.S, 0)
	o.LS = A(0, 0, -140 + sin(t * 24) * 16)
	o.RS = A(0, 0, 140 - sin(t * 24) * 16)
	o.N = A(10, 0, 0)
end

-- Covers his face and shakes his head.
function STATE.Embarrassed(o, t)
	local shake = sin(t * 17) * 7
	o.W = A(-13, shake, 0)
	o.LH = A(13, 0, 6)
	o.RH = A(13, 0, -6)
	o.LS = A(128, 0, 28)
	o.RS = A(128, 0, -28)
	o.N = A(-24, shake, 0)
end

-- Admiring himself: turning side to side, hand on chin.
function STATE.Mirror(o, t)
	o.W = A(2, sin(t * 1.6) * 26, 0)
	o.RS = A(112, 0, -36)
	o.LS = A(-8, 0, -30)
	o.N = A(4, sin(t * 1.6) * 10, sin(t * 3.2) * 6)
end

-- Trip: stumble, face-plant, flail, get up, dust off.
function STATE.Trip(o, t, _g, e)
	if t < 0.22 then
		o.W = A(-34, 0, 0)
		o.LS = A(110, 0, -30)
		o.RS = A(110, 0, 30)
		o.LH = A(-30, 0, 0)
	elseif t < 1.35 then
		local flail = sin(t * 22)
		o.W = T(0, -(e.hip - 0.5 * e.S), 0) * A(-90, 0, 0)
		o.LS = A(172, 0, -24)
		o.RS = A(172, 0, 24)
		o.LH = A(-18 - flail * 22, 0, -8)
		o.RH = A(-18 + flail * 22, 0, 8)
		o.N = A(30, 0, 0)
	elseif t < 1.9 then
		o.W = T(0, -(e.hip * 0.45), 0) * A(-40, 0, 0)
		o.LS = A(70, 0, -10)
		o.RS = A(70, 0, 10)
		o.LH = A(70, 0, 0)
		o.RH = A(20, 0, 0)
	else
		local dust = sin(t * 20) * 14
		o.LS = A(30 + dust, 0, 24)
		o.RS = A(30 - dust, 0, -24)
		o.N = A(-10, sin(t * 6) * 18, 0)
	end
end

-- Special Grail spawn: drops in from the sky spinning, lands, strikes a pose.
function STATE.GrailSpawn(o, t, _g, e)
	if t < 1.5 then
		local height = (1.5 - t) / 1.5
		o.W = T(0, height * height * 22 * e.S, 0) * A(0, t * 720, 0)
		o.LS = A(0, 0, -90)
		o.RS = A(0, 0, 90)
		o.LH = A(0, 0, -10)
		o.RH = A(0, 0, 10)
	elseif t < 1.85 then
		o.W = T(0, -0.5 * e.S, 0) * A(-16, 0, 0) -- landing squat
		o.LS = A(0, 0, -50)
		o.RS = A(0, 0, 50)
		o.LH = A(34, 0, -14)
		o.RH = A(34, 0, 14)
	else
		o.W = A(6, 0, 0)
		o.LS = A(0, 0, -138)
		o.RS = A(0, 0, 138)
		o.N = A(14, 0, 0)
	end
end

BradyAnimator.Poses = POSE

----------------------------------------------------------------------
-- Entries
----------------------------------------------------------------------
local function register(model)
	if entries[model] then
		return
	end
	local root = model.PrimaryPart or model:FindFirstChild("Root")
	local torso = model:FindFirstChild("Torso")
	if not root or not torso then
		return
	end
	local entry = {
		model = model,
		root = root,
		motors = {},
		base = {},
		current = {},
		target = {},
		S = model:GetAttribute("Scale") or 1,
		hip = model:GetAttribute("HipHeight") or 2,
		state = nil,
		stateStart = os.clock(),
		phase = math.random() * 10,
		pos = root.CFrame.Position,
		wasWalking = false,
		blinkAt = os.clock() + 2 + math.random() * 3,
		face = nil,
	}
	local waist = root:FindFirstChild("Waist")
	local sources = { W = waist }
	for key, name in pairs(JOINTS) do
		local motor = sources[key] or torso:FindFirstChild(name)
		if not motor then
			return -- model is still replicating; a later frame will retry
		end
		entry.motors[key] = motor
		entry.base[key] = motor.C0
		entry.current[key] = IDENTITY
		entry.target[key] = IDENTITY
	end
	-- Face pieces (drawn with a SurfaceGui) for blinking / chewing.
	local head = model:FindFirstChild("Head")
	local faceGui = head and head:FindFirstChild("Face")
	if faceGui then
		local face = { eyes = {}, eyeSizes = {}, blush = {} }
		for _, name in ipairs({ "EyeL", "EyeR" }) do
			local eye = faceGui:FindFirstChild(name)
			if eye then
				table.insert(face.eyes, eye)
				table.insert(face.eyeSizes, eye.Size)
			end
		end
		face.mouth = faceGui:FindFirstChild("Mouth")
		face.mouthSize = face.mouth and face.mouth.Size
		for _, name in ipairs({ "BlushL", "BlushR" }) do
			local blush = faceGui:FindFirstChild(name)
			if blush then
				table.insert(face.blush, blush)
			end
		end
		entry.face = face
	end
	entries[model] = entry
end

local function unregister(model)
	entries[model] = nil
end

local function setEyes(face, openness)
	for index, eye in ipairs(face.eyes) do
		local size = face.eyeSizes[index]
		eye.Size = UDim2.new(size.X.Scale, 0, size.Y.Scale * openness, 0)
	end
end

local function updateFace(entry, state, t, now)
	local face = entry.face
	if not face then
		return
	end
	-- eyes
	if state == "Sleep" or (state == "Pose" and entry.pose == "Faint" and t > 0.9) then
		setEyes(face, 0.12)
	elseif state == "Celebrate" or state == "Excited" or state == "GrailSpawn" then
		setEyes(face, 1.25)
	else
		local sinceBlink = now - entry.blinkAt
		if sinceBlink >= 0 and sinceBlink < 0.13 then
			setEyes(face, 0.1)
		else
			setEyes(face, 1)
			if sinceBlink >= 0.13 then
				entry.blinkAt = now + 2.2 + math.random() * 3.5
			end
		end
	end
	-- mouth
	if face.mouth then
		local size = face.mouthSize
		local stretch = 1
		if state == "Eat" and t > 0.55 then
			stretch = 1 + abs(sin(t * 13)) * 1.6
		elseif state == "Celebrate" or state == "Excited" or state == "Play" or state == "Dance" then
			stretch = 2.2
		elseif state == "Sleep" then
			stretch = 1 + abs(sin(now * 1.6)) * 1.2 -- snoring
		end
		face.mouth.Size = UDim2.new(size.X.Scale, 0, size.Y.Scale * stretch, 0)
	end
	-- blush
	local embarrassed = state == "Embarrassed"
	for _, blush in ipairs(face.blush) do
		blush.Visible = embarrassed or blush:GetAttribute("Default") == true
	end
end

local scratch = {}

local function animate(entry, dt, now, serverNow)
	local model = entry.model
	local state = model:GetAttribute("State") or "Idle"
	entry.pose = model:GetAttribute("Pose")

	-- MOVEMENT along the walk line the server published ------------------
	local walking = false
	local duration = model:GetAttribute("WalkDur") or 0
	if duration > 0 then
		local from, to = model:GetAttribute("WalkFrom"), model:GetAttribute("WalkTo")
		local start = model:GetAttribute("WalkStart")
		if from and to and start then
			local alpha = (serverNow - start) / duration
			if alpha < 1 then
				walking = true
				local goal = from:Lerp(to, math.clamp(alpha, 0, 1))
				-- ease towards the goal so small network hiccups stay smooth
				if (goal - entry.pos).Magnitude > 12 then
					entry.pos = goal
				else
					entry.pos = entry.pos:Lerp(goal, 1 - math.exp(-16 * dt))
				end
				local direction = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
				local rootCFrame = entry.root.CFrame
				if direction.Magnitude > 0.05 then
					-- turn smoothly towards the walking direction
					rootCFrame = rootCFrame:Lerp(CFrame.lookAt(entry.pos, entry.pos + direction), 1 - math.exp(-12 * dt))
				end
				entry.root.CFrame = rootCFrame - rootCFrame.Position + entry.pos
			end
		end
	end
	if not walking then
		entry.pos = entry.root.CFrame.Position
	end
	entry.wasWalking = walking

	-- STATE bookkeeping --------------------------------------------------
	if state ~= entry.state then
		local old = entry.state
		entry.state = state
		entry.stateStart = now
		for _, listener in ipairs(stateListeners) do
			task.spawn(listener, model, state, old, entry)
		end
	end
	local t = now - entry.stateStart
	local g = now + entry.phase

	-- TARGET offsets -----------------------------------------------------
	local o = scratch
	for _, key in ipairs(KEYS) do
		o[key] = IDENTITY
	end
	local fn
	if state == "Idle" or state == "Walk" then
		if walking then
			fn = WALK[model:GetAttribute("WalkStyle")] or WALK.Bop
		else
			fn = IDLE[model:GetAttribute("IdleStyle")] or IDLE.Bouncy
		end
	else
		fn = STATE[state]
		if not fn then
			fn = walking and WALK.Bop or IDLE.Bouncy
		end
	end
	fn(o, t, g, entry)

	-- BLEND + APPLY ------------------------------------------------------
	local blend = 1 - math.exp(-((state == "Trip" or state == "GrailSpawn") and 22 or 13) * dt)
	for _, key in ipairs(KEYS) do
		local current = entry.current[key]:Lerp(o[key], blend)
		entry.current[key] = current
		entry.motors[key].C0 = entry.base[key] * current
	end

	if not lowGraphics then
		updateFace(entry, state, t, now)
	end
end

local frame = 0

local function step(dt)
	frame += 1
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPosition = camera.CFrame.Position
	local now = os.clock()
	local serverNow = Workspace:GetServerTimeNow()
	dt = math.min(dt, 0.1)
	for model, entry in pairs(entries) do
		if not model.Parent then
			entries[model] = nil
		else
			local distance = (entry.root.CFrame.Position - cameraPosition).Magnitude
			-- Far Bradys are skipped; mid-distance ones update every other frame.
			if distance <= maxDistance and (distance < 70 or frame % 2 == 0) then
				animate(entry, distance < 70 and dt or dt * 2, now, serverNow)
			end
		end
	end
end

function BradyAnimator.setLowGraphics(enabled)
	lowGraphics = enabled
	maxDistance = enabled and 70 or 140
end

function BradyAnimator.get(model)
	return entries[model]
end

local started = false

function BradyAnimator.start()
	if started then
		return
	end
	started = true
	for _, model in ipairs(CollectionService:GetTagged(TAG)) do
		register(model)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model)
		-- give the model's children a moment to replicate
		task.defer(register, model)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(unregister)
	-- Safety net: pick up any Brady that was not ready when it was tagged.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, model in ipairs(CollectionService:GetTagged(TAG)) do
				if not entries[model] and model.Parent then
					register(model)
				end
			end
		end
	end)
	RunService.RenderStepped:Connect(step)
end

-- Exposed for tests.
BradyAnimator._step = step
BradyAnimator._register = register
BradyAnimator.Idle, BradyAnimator.Walk, BradyAnimator.State = IDLE, WALK, STATE

return BradyAnimator
