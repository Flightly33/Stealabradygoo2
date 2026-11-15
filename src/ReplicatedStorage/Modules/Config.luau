--[[
	Config
	Every tuning number for Raise Brady Goo lives here so the game can be
	balanced without hunting through the systems.
]]

local Config = {}

Config.GameName = "Raise Brady Goo"

-- DataStore -----------------------------------------------------------
-- Change the name to wipe everybody's progress (useful while testing).
Config.DataStoreName = "RaiseBradyGoo_v1"
Config.AutosaveInterval = 120 -- seconds between autosaves
Config.SessionLockTimeout = 300 -- a lock older than this is treated as dead

-- New player ----------------------------------------------------------
Config.StartCoins = 150

-- Brady's needs (0-100). Decay is "points lost per second" while online.
Config.MeterDecay = { hunger = 1 / 11, clean = 1 / 16, energy = 1 / 24, fun = 1 / 13 }
Config.MeterTick = 5 -- how often decay is applied / synced
Config.SleepTick = 2 -- seconds between sleep ticks
Config.SleepEnergyPerTick = 5
Config.SleepXPPerTick = 3

-- Rebirth (prestige) --------------------------------------------------
Config.RebirthBonus = 0.25 -- +25% coins and XP per rebirth

-- Mini-games ----------------------------------------------------------
Config.MinigameEnergyCost = 8
Config.MinigameCooldown = 4
Config.ArcadeBonus = 1.25 -- reward multiplier when played at the arcade

-- Random events -------------------------------------------------------
Config.EventFirstDelay = { 100, 150 }
Config.EventDelay = { 150, 260 }

-- Fashion show --------------------------------------------------------
Config.FashionInterval = 240 -- seconds between shows
Config.FashionSignup = 40
Config.FashionWalkTime = 9
Config.FashionVoting = 20
Config.FashionResults = 10
Config.FashionMinAge = 5
Config.FashionWinCoins = 350
Config.FashionJoinCoins = 80
Config.TitleDuration = 15 * 60

-- Hidden collectibles -------------------------------------------------
Config.HiddenCoins = { 30, 70 }
Config.SecretSpawnInterval = 210 -- how often the server rolls for a secret item
Config.SecretSpawnChance = 0.4
Config.SecretLifetime = 120

-- Room ----------------------------------------------------------------
Config.GridSize = 2 -- studs per furniture grid cell
Config.MaxPlacedFurniture = 45
Config.MaxPlacedFurnitureWithPass = 100
Config.MaxFoodStack = 25
Config.MaxFoodStackWithPass = 99
Config.OutfitSlots = 3
Config.OutfitSlotsWithPass = 8

-- Plots ---------------------------------------------------------------
Config.PlotCount = 12
Config.PlotSize = 72

-- Follow / wander -----------------------------------------------------
Config.FollowMinAge = 3
Config.WanderInterval = { 4, 9 }
Config.BradyWalkSpeed = 7
Config.BradyFollowSpeed = 19

-- Testing -------------------------------------------------------------
-- When true, everyone is treated as owning every gamepass inside Studio.
Config.StudioOwnsAllPasses = false

return Config
