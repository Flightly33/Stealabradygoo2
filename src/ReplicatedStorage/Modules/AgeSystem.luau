--[[
	AgeSystem
	Brady's whole growth curve: how much Age XP each age costs, the ten named
	life stages, what every stage looks like, and what it unlocks.

	Pure data + math. The server (AgeServer) is the only thing that actually
	changes a player's XP; the client reads this module to draw the age bar.
]]

local AgeSystem = {}

AgeSystem.MaxAge = 25

----------------------------------------------------------------------
-- STAGES
-- `look` drives BradyBuilder + the client animator:
--   scale  overall size          head  head size multiplier (babies = huge head)
--   leg/arm/torso  limb length multipliers
--   hair   default hairstyle item id     face  face preset
--   idle / walk    animation style names (see Client/BradyAnimator)
-- `unlockSlot`  clothing category that opens at this stage
-- `rewards`     handed out by AgeServer exactly once when the stage is reached
----------------------------------------------------------------------
AgeSystem.Stages = {
	{
		age = 1,
		id = "Baby",
		name = "Baby Brady",
		blurb = "he cannot walk. he cannot talk. he is already judging your fit.",
		look = { scale = 0.52, head = 1.6, leg = 0.55, arm = 0.7, torso = 0.8, hair = "hair_baby", face = "Baby", idle = "BabyWobble", walk = "Crawl" },
		unlockSlot = nil,
		unlockText = "Shirts + Pants",
		interaction = "Feed, clean, sleep and play",
		rewards = { items = { "hair_baby", "plain_tee", "basic_jeans" }, furniture = "rug_goo", pose = "Wave" },
	},
	{
		age = 3,
		id = "Little",
		name = "Little Brady",
		blurb = "he can walk now. mostly into walls.",
		look = { scale = 0.62, head = 1.45, leg = 0.7, arm = 0.8, torso = 0.85, hair = "hair_bowl", face = "Little", idle = "Bouncy", walk = "Waddle" },
		unlockSlot = "Shoes",
		unlockText = "Shoes",
		interaction = "Take Brady outside + the Obby",
		rewards = { coins = 150, items = { "hair_bowl", "white_lowtops" }, furniture = "toy_blocks", gift = "gift_bucket", pose = "Peace" },
	},
	{
		age = 5,
		id = "Kid",
		name = "Kid Brady",
		blurb = "discovered hats. life will never be the same.",
		look = { scale = 0.72, head = 1.32, leg = 0.82, arm = 0.88, torso = 0.9, hair = "hair_spiky", face = "Kid", idle = "Bouncy", walk = "Run" },
		unlockSlot = "Hat",
		unlockText = "Hats + Hairstyles",
		interaction = "Fashion Shows + Goo Soccer",
		rewards = { coins = 300, items = { "hair_spiky", "beanie" }, furniture = "beanbag", gift = "gift_backpack", pose = "Dab" },
	},
	{
		age = 8,
		id = "Drippy",
		name = "Drippy Brady",
		blurb = "the curls came in. the first flannel went on. it begins.",
		look = { scale = 0.8, head = 1.22, leg = 0.9, arm = 0.92, torso = 0.94, hair = "hair_first_curls", face = "Drippy", idle = "Cool", walk = "Bop" },
		unlockSlot = "Jacket",
		unlockText = "Jackets",
		interaction = "Dance Battle mini-game",
		rewards = { coins = 500, items = { "hair_first_curls", "plaid_flannel" }, furniture = "neon_sign", gift = "gift_chain", pose = "HandsOnHips" },
	},
	{
		age = 10,
		id = "Trendy",
		name = "Trendy Brady",
		blurb = "he saw one outfit video and now he is unstoppable.",
		look = { scale = 0.87, head = 1.15, leg = 0.95, arm = 0.96, torso = 0.97, hair = "hair_fluffy_curls", face = "Trendy", idle = "Cool", walk = "Bop" },
		unlockSlot = "Accessory",
		unlockText = "Accessories",
		interaction = "Designer Drop crates",
		rewards = { coins = 800, items = { "hair_fluffy_curls", "statement_belt" }, furniture = "speaker", gift = "gift_shades", pose = "Flex" },
	},
	{
		age = 13,
		id = "Teen",
		name = "Teen Brady",
		blurb = "found his signature shades. has not taken them off since.",
		look = { scale = 0.96, head = 1.07, leg = 1.02, arm = 1.02, torso = 0.98, hair = "hair_teen_curls", face = "Teen", idle = "Slouch", walk = "Slouch" },
		unlockSlot = "Glasses",
		unlockText = "Glasses",
		interaction = "Fit checks from other players",
		rewards = { coins = 1200, items = { "hair_teen_curls", "dark_ovals" }, furniture = "gaming_setup", gift = "gift_headphones", pose = "CollarPop" },
	},
	{
		age = 16,
		id = "Fashion",
		name = "Fashion Brady",
		blurb = "grey crewneck. olive chinos. dark shades. the classic brady is born.",
		look = { scale = 1.03, head = 1.0, leg = 1.08, arm = 1.04, torso = 1.0, hair = "hair_brady_flow", face = "Fashion", idle = "Model", walk = "Strut" },
		unlockSlot = "Outfit",
		unlockText = "Full Outfits",
		interaction = "Coordinated full fits",
		rewards = { coins = 2000, items = { "hair_brady_flow", "malibu_fit" }, furniture = "clothing_rack", gift = "gift_scarf", pose = "WallLean" },
	},
	{
		age = 18,
		id = "Archive",
		name = "Archive Brady",
		blurb = "he no longer buys clothes. he 'acquires pieces'.",
		look = { scale = 1.08, head = 0.97, leg = 1.14, arm = 1.07, torso = 1.0, hair = "hair_archive_curls", face = "Archive", idle = "ArchiveLean", walk = "ArchiveWalk" },
		unlockSlot = nil,
		unlockText = "ARCHIVE rarity + the Archive Vault",
		interaction = "Archive Vault crates",
		rewards = { coins = 3500, items = { "hair_archive_curls", "vintage_goo_jacket" }, furniture = "sneaker_wall", gift = "gift_cape", pose = "HeadHold" },
	},
	{
		age = 21,
		id = "Vintage",
		name = "Vintage Brady",
		blurb = "vintage red crewneck, chrome kicks, hand behind the head. iconic.",
		look = { scale = 1.12, head = 0.95, leg = 1.16, arm = 1.08, torso = 1.02, hair = "hair_shag", face = "Vintage", idle = "ArchiveLean", walk = "Strut" },
		unlockSlot = nil,
		unlockText = "GRAIL hunting + the Grail Vault",
		interaction = "Grail Vault crates",
		rewards = { coins = 6000, items = { "hair_shag", "varsity_fit" }, furniture = "vinyl_player", gift = "gift_vintage_cap", pose = "Salute" },
	},
	{
		age = 25,
		id = "Legendary",
		name = "Legendary Brady Goo",
		blurb = "the most archive person on roblox. it is done.",
		look = { scale = 1.18, head = 0.95, leg = 1.18, arm = 1.1, torso = 1.04, hair = "hair_legend", face = "Legendary", idle = "Legend", walk = "LegendWalk" },
		unlockSlot = nil,
		unlockText = "Legendary Aura + Rebirth",
		interaction = "Rebirth Brady for permanent bonuses",
		rewards = { coins = 15000, items = { "hair_legend", "legendary_goo" }, furniture = "throne", gift = "gift_aura", gift2 = "gift_crown", pose = "LegendPose" },
	},
}

for index, stage in ipairs(AgeSystem.Stages) do
	stage.index = index
end

----------------------------------------------------------------------
-- POSES (used by the mirror + fashion display). `stage` = stage index needed.
-- `item` poses belong to a Grail item, `pass` poses to the Special Emotes pass.
----------------------------------------------------------------------
AgeSystem.Poses = {
	{ id = "Wave", name = "Wave", stage = 1 },
	{ id = "Peace", name = "Peace Sign", stage = 2 },
	{ id = "Dab", name = "Dab", stage = 3 },
	{ id = "HandsOnHips", name = "Hands On Hips", stage = 4 },
	{ id = "Flex", name = "Flex", stage = 5 },
	{ id = "Thinker", name = "The Thinker", stage = 6 },
	{ id = "ModelPose", name = "Model Lean", stage = 7 },
	{ id = "ArchiveStance", name = "Archive Stance", stage = 8 },
	{ id = "Salute", name = "Salute", stage = 9 },
	{ id = "LegendPose", name = "Legend", stage = 10 },
	-- signature poses taken from the real Brady's photos
	{ id = "CollarPop", name = "Collar Pop", stage = 6 },
	{ id = "WallLean", name = "Wall Lean", stage = 7 },
	{ id = "HeadHold", name = "The Brady", stage = 8 },
	{ id = "GrailFloat", name = "Grail Float", item = true },
	{ id = "TPose", name = "T-Pose", pass = "SpecialEmotes" },
	{ id = "Griddy", name = "Goo Shuffle", pass = "SpecialEmotes" },
	{ id = "Faint", name = "Dramatic Faint", pass = "SpecialEmotes" },
}

AgeSystem.PoseById = {}
for _, pose in ipairs(AgeSystem.Poses) do
	AgeSystem.PoseById[pose.id] = pose
end

-- Which stage index a clothing slot unlocks at (slots missing here are open from the start).
AgeSystem.SlotUnlockStage = { Shirt = 1, Pants = 1, Hair = 3 }
for index, stage in ipairs(AgeSystem.Stages) do
	if stage.unlockSlot then
		AgeSystem.SlotUnlockStage[stage.unlockSlot] = index
	end
end

----------------------------------------------------------------------
-- XP CURVE
----------------------------------------------------------------------
-- Age XP needed to go from `age` to `age + 1`.
function AgeSystem.xpToNext(age)
	if age >= AgeSystem.MaxAge then
		return math.huge
	end
	return math.floor(60 * age ^ 1.55 + 40)
end

-- Cumulative XP needed to BE a given age (age 1 = 0 XP).
local cumulative = { 0 }
for age = 2, AgeSystem.MaxAge do
	cumulative[age] = cumulative[age - 1] + AgeSystem.xpToNext(age - 1)
end

function AgeSystem.totalXPForAge(age)
	return cumulative[math.clamp(age, 1, AgeSystem.MaxAge)]
end

AgeSystem.MaxXP = cumulative[AgeSystem.MaxAge]

-- Returns: age, xp into the current age, xp needed for the next age.
function AgeSystem.ageFromXP(xp)
	xp = math.max(0, xp)
	local age = 1
	for candidate = AgeSystem.MaxAge, 1, -1 do
		if xp >= cumulative[candidate] then
			age = candidate
			break
		end
	end
	if age >= AgeSystem.MaxAge then
		return age, 0, 0
	end
	return age, xp - cumulative[age], AgeSystem.xpToNext(age)
end

----------------------------------------------------------------------
-- STAGE LOOKUPS
----------------------------------------------------------------------
function AgeSystem.getStageIndex(age)
	local index = 1
	for i, stage in ipairs(AgeSystem.Stages) do
		if age >= stage.age then
			index = i
		end
	end
	return index
end

function AgeSystem.getStage(age)
	return AgeSystem.Stages[AgeSystem.getStageIndex(age)]
end

function AgeSystem.getNextStage(age)
	return AgeSystem.Stages[AgeSystem.getStageIndex(age) + 1]
end

function AgeSystem.isSlotUnlocked(slot, age)
	local needed = AgeSystem.SlotUnlockStage[slot] or 1
	return AgeSystem.getStageIndex(age) >= needed
end

-- Age needed before a slot opens (for "unlocks at age N" labels).
function AgeSystem.slotUnlockAge(slot)
	local needed = AgeSystem.SlotUnlockStage[slot] or 1
	return AgeSystem.Stages[needed].age
end

----------------------------------------------------------------------
-- MULTIPLIERS
----------------------------------------------------------------------
-- Older Brady earns more per activity so late ages do not drag.
function AgeSystem.rewardMultiplier(age, rebirths)
	return (1 + 0.15 * (age - 1)) * (1 + 0.25 * (rebirths or 0))
end

-- Brady's mood (average of his meters) nudges XP between 0.75x and 1.25x.
function AgeSystem.moodMultiplier(meters)
	local average = (meters.hunger + meters.clean + meters.energy + meters.fun) / 4
	return 0.75 + 0.5 * math.clamp(average / 100, 0, 1)
end

function AgeSystem.moodName(meters)
	local average = (meters.hunger + meters.clean + meters.energy + meters.fun) / 4
	if average >= 80 then
		return "LOCKED IN", "😎"
	elseif average >= 55 then
		return "chillin", "🙂"
	elseif average >= 30 then
		return "kinda mid", "😐"
	end
	return "DOWN BAD", "😭"
end

-- The house interior grows 4 studs with every stage: 24 studs -> 60 studs.
function AgeSystem.houseSize(age)
	return 24 + 4 * (AgeSystem.getStageIndex(age) - 1)
end

-- Wall style / material set changes every two stages.
function AgeSystem.houseTier(age)
	return math.ceil(AgeSystem.getStageIndex(age) / 2)
end

AgeSystem.HouseNames = { "Starter Shack", "Cozy Crib", "Drip Den", "Fashion Loft", "Archive Mansion" }

return AgeSystem
