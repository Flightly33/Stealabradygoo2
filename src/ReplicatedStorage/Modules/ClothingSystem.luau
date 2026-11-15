--[[
	ClothingSystem
	The full wardrobe catalog + the rarity ladder.

	Every item is plain data. The `vis` table is a small recipe that
	Builders/BradyBuilder reads to assemble the piece out of parts, so adding a
	new item is just adding a row here - no modelling and no uploaded assets.

	Nothing here is a real brand: names and shapes are generic streetwear /
	vintage / "archive fashion" ideas on purpose.

	Item fields
	  id, name, slot, rarity, age (required Brady age), desc
	  price     Goo Coin price if it is sold in the shop (nil = not sold)
	  drop      false = never comes out of crates (starter, stage, secret items)
	  source    short text shown in the UI for how to get it
	  tags      used by fashion show judging: street / vintage / funny / luxury / sport
	  fx        particle effect key        walk / idle  animation overrides
	  pose      pose id this item unlocks  nameplate    special nameplate style
	  spawn     true = Brady does the special Grail spawn animation
]]

local ClothingSystem = {}

local rgb = Color3.fromRGB

----------------------------------------------------------------------
-- RARITIES
----------------------------------------------------------------------
ClothingSystem.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Archive", "Grail" }

ClothingSystem.Rarities = {
	Common = { order = 1, color = rgb(185, 190, 200), points = 1, sell = 15 },
	Uncommon = { order = 2, color = rgb(92, 214, 110), points = 2, sell = 40 },
	Rare = { order = 3, color = rgb(72, 150, 255), points = 4, sell = 120 },
	Epic = { order = 4, color = rgb(178, 92, 255), points = 7, sell = 350 },
	Legendary = { order = 5, color = rgb(255, 196, 46), points = 11, sell = 1000 },
	Archive = { order = 6, color = rgb(232, 66, 78), points = 16, sell = 2500 },
	Grail = { order = 7, color = rgb(255, 110, 225), points = 25, sell = 8000 },
}

----------------------------------------------------------------------
-- SLOTS (the inventory categories)
----------------------------------------------------------------------
ClothingSystem.Slots = { "Shirt", "Pants", "Shoes", "Jacket", "Accessory", "Hat", "Glasses", "Outfit", "Hair" }

ClothingSystem.SlotInfo = {
	Shirt = { plural = "Shirts", icon = "👕" },
	Pants = { plural = "Pants", icon = "👖" },
	Shoes = { plural = "Shoes", icon = "👟" },
	Jacket = { plural = "Jackets", icon = "🧥" },
	Accessory = { plural = "Accessories", icon = "📿" },
	Hat = { plural = "Hats", icon = "🧢" },
	Glasses = { plural = "Glasses", icon = "🕶️" },
	Outfit = { plural = "Full Outfits", icon = "✨" },
	Hair = { plural = "Hairstyles", icon = "💇" },
}

-- Signature colors
local GOO = rgb(126, 232, 74)
local GOO_DARK = rgb(64, 168, 52)
local WHITE = rgb(245, 245, 245)
local BLACK = rgb(28, 28, 32)
local CREAM = rgb(236, 226, 200)
local DENIM = rgb(72, 110, 170)
local GOLD = rgb(255, 205, 60)

ClothingSystem.GooColor = GOO

----------------------------------------------------------------------
-- CATALOG
----------------------------------------------------------------------
ClothingSystem.Items = {}
ClothingSystem.List = {}

local function add(item)
	assert(not ClothingSystem.Items[item.id], "Duplicate clothing id " .. item.id)
	assert(ClothingSystem.Rarities[item.rarity], "Bad rarity on " .. item.id)
	assert(ClothingSystem.SlotInfo[item.slot], "Bad slot on " .. item.id)
	item.age = item.age or 1
	item.tags = item.tags or {}
	if item.drop == nil then
		item.drop = true
	end
	if not item.source then
		item.source = item.price and "Shop" or "Crates"
	end
	ClothingSystem.Items[item.id] = item
	table.insert(ClothingSystem.List, item)
end

-- SHIRTS ------------------------------------------------------------------
add({ id = "plain_tee", name = "Plain White Tee", slot = "Shirt", rarity = "Common", age = 1, drop = false, source = "Starter",
	desc = "it's a shirt. it does shirt things.", vis = { color = WHITE, sleeves = "short" } })
add({ id = "goo_tee", name = "Goo Green Tee", slot = "Shirt", rarity = "Common", age = 1, price = 60,
	desc = "matches his hair. this was not an accident.", vis = { color = GOO, sleeves = "short", graphic = "goo", graphicColor = GOO_DARK } })
add({ id = "stripe_tee", name = "Stripey Tee", slot = "Shirt", rarity = "Common", age = 1, price = 90,
	desc = "where's brady? right here. wearing stripes.", vis = { color = WHITE, sleeves = "short", stripes = rgb(220, 60, 60) } })
add({ id = "smile_tee", name = "Smiley Tee", slot = "Shirt", rarity = "Uncommon", age = 3, price = 220, tags = { "funny" },
	desc = "the shirt is happier than he is.", vis = { color = rgb(255, 220, 70), sleeves = "short", graphic = "smile", graphicColor = BLACK } })
add({ id = "banana_tee", name = "Banana Top", slot = "Shirt", rarity = "Uncommon", age = 3, price = 250, tags = { "funny" },
	desc = "potassium-core.", vis = { color = rgb(255, 225, 60), sleeves = "none", graphic = "banana", graphicColor = rgb(120, 80, 30) } })
add({ id = "longsleeve_blk", name = "Black Longsleeve", slot = "Shirt", rarity = "Uncommon", age = 5, price = 300, tags = { "street" },
	desc = "mysterious. also hides juice stains.", vis = { color = BLACK, sleeves = "long" } })
add({ id = "layered_tee", name = "Layered Double Tee", slot = "Shirt", rarity = "Rare", age = 8, price = 800, tags = { "street" },
	desc = "two shirts. twice the fashion. simple math.", vis = { color = rgb(60, 60, 68), sleeves = "short", under = WHITE, graphic = "star", graphicColor = WHITE } })
add({ id = "flame_tee", name = "Flame Graphic Tee", slot = "Shirt", rarity = "Rare", age = 10, price = 950, tags = { "street", "funny" },
	desc = "adds +10 speed. (it does not.)", vis = { color = BLACK, sleeves = "short", graphic = "flame", graphicColor = rgb(255, 120, 30) } })
add({ id = "goo_jersey", name = "Oversized Goo Jersey", slot = "Shirt", rarity = "Epic", age = 13, price = 2400, tags = { "street", "sport" },
	desc = "number 00. plays for team drip.", vis = { color = rgb(40, 60, 150), sleeves = "short", oversized = true, graphic = "number", graphicColor = WHITE, stripes = GOLD } })
add({ id = "tour_tee", name = "Sun-Faded Tour Tee", slot = "Shirt", rarity = "Epic", age = 16, price = 3200, tags = { "vintage", "street" },
	desc = "GOO WORLD TOUR '98. he was not born yet.", vis = { color = rgb(92, 88, 84), sleeves = "short", oversized = true, graphic = "text", text = "GOO\nTOUR", graphicColor = CREAM } })
add({ id = "silk_shirt", name = "Midnight Silk Shirt", slot = "Shirt", rarity = "Legendary", age = 16, tags = { "luxury" }, fx = "sparkle",
	desc = "so smooth it left the chat.", vis = { color = rgb(26, 30, 70), sleeves = "long", sleeveColor = rgb(26, 30, 70), graphic = "star", graphicColor = GOLD, material = "Glass" } })
add({ id = "archive_knit", name = "Distressed Archive Knit", slot = "Shirt", rarity = "Archive", age = 18, tags = { "vintage", "luxury" }, fx = "dust",
	desc = "the holes are on purpose. the holes are the point.", vis = { color = rgb(210, 200, 180), sleeves = "long", oversized = true, holes = true, material = "Fabric" } })
add({ id = "grail_tee", name = "The 1-of-1 Goo Tee", slot = "Shirt", rarity = "Grail", age = 21, tags = { "luxury", "vintage" }, fx = "rainbow", nameplate = "Grail", spawn = true, pose = "GrailFloat",
	desc = "there is exactly one. somehow you have it.", vis = { color = WHITE, sleeves = "short", graphic = "goo", graphicColor = GOLD, stripes = rgb(255, 110, 225), material = "Neon" } })

-- PANTS -------------------------------------------------------------------
add({ id = "basic_jeans", name = "Basic Jeans", slot = "Pants", rarity = "Common", age = 1, drop = false, source = "Starter",
	desc = "jeans. the default setting of legs.", vis = { color = DENIM } })
add({ id = "khaki_shorts", name = "Khaki Shorts", slot = "Pants", rarity = "Common", age = 1, price = 70,
	desc = "certified dad at a barbecue.", vis = { color = rgb(196, 170, 120), length = 0.5 } })
add({ id = "pajama_pants", name = "Dino Pajama Pants", slot = "Pants", rarity = "Common", age = 1, price = 80, tags = { "funny" },
	desc = "rawr means 'i am comfortable' in dinosaur.", vis = { color = rgb(120, 200, 230), width = 1.15, plaid = rgb(80, 180, 90) } })
add({ id = "trackpants", name = "Track Pants", slot = "Pants", rarity = "Common", age = 3, price = 110, tags = { "sport" },
	desc = "has never been near a track.", vis = { color = BLACK, stripe = WHITE } })
add({ id = "cargo_pants", name = "Cargo Pants", slot = "Pants", rarity = "Uncommon", age = 5, price = 320, tags = { "street" },
	desc = "8 pockets. 0 things to put in them.", vis = { color = rgb(96, 110, 70), width = 1.15, pockets = true } })
add({ id = "ripped_jeans", name = "Ripped Jeans", slot = "Pants", rarity = "Uncommon", age = 8, price = 380, tags = { "street" },
	desc = "he paid extra for less pants.", vis = { color = rgb(120, 150, 200), patches = true } })
add({ id = "baggy_jeans", name = "Baggy Skater Jeans", slot = "Pants", rarity = "Rare", age = 8, price = 850, tags = { "street" },
	desc = "there is room for two more bradys in here.", vis = { color = rgb(60, 86, 140), width = 1.45 } })
add({ id = "plaid_pants", name = "Plaid Punk Pants", slot = "Pants", rarity = "Rare", age = 10, price = 900, tags = { "street", "vintage" },
	desc = "loud pants for a loud brady.", vis = { color = rgb(170, 40, 50), plaid = BLACK } })
add({ id = "parachute_pants", name = "Parachute Pants", slot = "Pants", rarity = "Epic", age = 13, price = 2300, tags = { "street" },
	desc = "swish swish swish swish swish.", vis = { color = rgb(70, 74, 82), width = 1.6, pockets = true, material = "Fabric" } })
add({ id = "waxed_denim", name = "Waxed Black Denim", slot = "Pants", rarity = "Epic", age = 16, price = 3000, tags = { "luxury", "street" },
	desc = "shiny. squeaky. serious.", vis = { color = rgb(20, 20, 24), width = 0.9, material = "Glass" } })
add({ id = "flare_denim", name = "Stacked Flare Denim", slot = "Pants", rarity = "Legendary", age = 16, tags = { "vintage", "luxury" }, fx = "sparkle",
	desc = "the stack on these is disrespectful.", vis = { color = rgb(40, 54, 90), flare = true, width = 1.05 } })
add({ id = "archive_cargos", name = "Strap-Heavy Archive Cargos", slot = "Pants", rarity = "Archive", age = 18, tags = { "vintage", "luxury", "street" }, fx = "dust",
	desc = "eleven straps. nobody knows what they hold up.", vis = { color = rgb(44, 44, 40), width = 1.5, pockets = true, straps = rgb(190, 190, 180), material = "Fabric" } })
add({ id = "grail_denim", name = "Hand-Painted Grail Denim", slot = "Pants", rarity = "Grail", age = 21, tags = { "vintage", "luxury" }, fx = "rainbow", nameplate = "Grail", spawn = true, pose = "GrailFloat",
	desc = "painted by hand. worn by a legend.", vis = { color = rgb(230, 230, 240), width = 1.35, flare = true, plaid = rgb(255, 110, 225), stripe = GOLD } })

-- SHOES (unlock at Little Brady, age 3) -----------------------------------
add({ id = "simple_sneakers", name = "Simple Sneakers", slot = "Shoes", rarity = "Common", age = 3, drop = false, source = "Age 3 reward",
	desc = "his very first pair. he will remember these.", vis = { color = WHITE, sole = rgb(220, 220, 220) } })
add({ id = "velcro_lights", name = "Velcro Light-Ups", slot = "Shoes", rarity = "Common", age = 3, price = 90, tags = { "funny" },
	desc = "they flash when he stomps. he stomps a lot.", vis = { color = rgb(60, 110, 230), sole = WHITE, glow = rgb(255, 60, 60) } })
add({ id = "canvas_highs", name = "Canvas High-Tops", slot = "Shoes", rarity = "Uncommon", age = 5, price = 280, tags = { "street" },
	desc = "a classic. scuffed on purpose.", vis = { color = BLACK, sole = WHITE, high = true } })
add({ id = "skate_shoes", name = "Chunky Skate Shoes", slot = "Shoes", rarity = "Uncommon", age = 8, price = 350, tags = { "street" },
	desc = "he does not own a skateboard.", vis = { color = rgb(90, 90, 100), sole = WHITE, chunk = 1.25 } })
add({ id = "dad_runner", name = "Dad Runner 9000", slot = "Shoes", rarity = "Rare", age = 10, price = 900, tags = { "funny", "sport" },
	desc = "maximum comfort. maximum lawn mowing energy.", vis = { color = rgb(235, 235, 235), sole = rgb(150, 170, 200), chunk = 1.3 } })
add({ id = "designer_sneakers", name = "Designer-ish Sneakers", slot = "Shoes", rarity = "Rare", age = 10, price = 1100, tags = { "street", "luxury" },
	desc = "legally distinct. emotionally expensive.", vis = { color = rgb(240, 240, 230), sole = rgb(200, 60, 60), chunk = 1.15 } })
add({ id = "cloud_slides", name = "Foam Cloud Slides", slot = "Shoes", rarity = "Epic", age = 13, price = 2200, tags = { "funny", "street" },
	desc = "like walking on a marshmallow.", vis = { color = rgb(214, 226, 190), sole = rgb(214, 226, 190), slide = true, chunk = 1.3 } })
add({ id = "combat_boots", name = "Stompy Combat Boots", slot = "Shoes", rarity = "Epic", age = 13, price = 2500, tags = { "street", "vintage" },
	desc = "every step is an announcement.", vis = { color = BLACK, sole = rgb(40, 40, 40), high = true, chunk = 1.2, platform = 0.12 } })
add({ id = "gold_kicks", name = "24K Kicks", slot = "Shoes", rarity = "Legendary", age = 16, tags = { "luxury" }, fx = "gold",
	desc = "do NOT step on these.", vis = { color = GOLD, sole = WHITE, chunk = 1.15, material = "Glass", glow = GOLD } })
add({ id = "split_toe_boots", name = "Split-Toe Archive Boots", slot = "Shoes", rarity = "Archive", age = 18, tags = { "vintage", "luxury" }, fx = "dust",
	desc = "yes the toe is split. no you can't ask why.", vis = { color = rgb(226, 220, 204), sole = rgb(60, 50, 40), high = true, split = true } })
add({ id = "platform_stompers", name = "Mega Platform Stompers", slot = "Shoes", rarity = "Archive", age = 21, tags = { "vintage", "luxury", "street" }, fx = "smoke", walk = "ArchiveWalk",
	desc = "adds six inches and infinite aura.", vis = { color = BLACK, sole = rgb(30, 30, 30), high = true, chunk = 1.35, platform = 0.45 } })
add({ id = "sample_pair", name = "Sample Pair 001", slot = "Shoes", rarity = "Grail", age = 21, tags = { "luxury", "street" }, fx = "rainbow", nameplate = "Grail", spawn = true, pose = "GrailFloat",
	desc = "never released. should not exist. on his feet.", vis = { color = WHITE, sole = rgb(255, 110, 225), chunk = 1.25, glow = rgb(120, 255, 255), material = "Neon" } })

-- JACKETS (unlock at Drippy Brady, age 8) ---------------------------------
add({ id = "zip_hoodie", name = "Zip Hoodie", slot = "Jacket", rarity = "Uncommon", age = 8, drop = false, source = "Age 8 reward", tags = { "street" },
	desc = "the hoodie that started it all.", vis = { color = rgb(120, 124, 132), hood = true } })
add({ id = "windbreaker", name = "Color-Block Windbreaker", slot = "Jacket", rarity = "Uncommon", age = 8, price = 400, tags = { "sport", "vintage" },
	desc = "the 90s called. he picked up.", vis = { color = rgb(60, 180, 190), sleeve = rgb(240, 90, 160), trim = rgb(255, 220, 70), collar = true } })
add({ id = "varsity", name = "Varsity Jacket", slot = "Jacket", rarity = "Uncommon", age = 8, price = 450, tags = { "street", "sport" },
	desc = "lettered in looking good.", vis = { color = rgb(150, 30, 40), sleeve = CREAM, trim = WHITE, collar = true } })
add({ id = "denim_jacket", name = "Oversized Denim Jacket", slot = "Jacket", rarity = "Rare", age = 10, price = 1000, tags = { "street", "vintage" },
	desc = "three sizes too big. perfect.", vis = { color = DENIM, bulk = 0.24, collar = true } })
add({ id = "big_puffer", name = "Big Puffer", slot = "Jacket", rarity = "Rare", age = 10, price = 1200, tags = { "street" },
	desc = "he is 60% jacket now.", vis = { color = rgb(240, 150, 40), bulk = 0.34, puffy = true, collar = true } })
add({ id = "flight_bomber", name = "Flight Bomber", slot = "Jacket", rarity = "Epic", age = 13, price = 2600, tags = { "street", "vintage" },
	desc = "has never flown. looks like he could.", vis = { color = rgb(70, 84, 56), trim = rgb(230, 120, 30), bulk = 0.22, collar = true } })
add({ id = "leather_jacket", name = "Cracked Leather Jacket", slot = "Jacket", rarity = "Epic", age = 16, price = 3400, tags = { "vintage", "luxury" },
	desc = "older than brady. cooler than brady.", vis = { color = rgb(40, 32, 28), collar = true, trim = rgb(180, 180, 180), material = "Slate" } })
add({ id = "faux_fur", name = "Big Boss Faux Fur", slot = "Jacket", rarity = "Legendary", age = 16, tags = { "luxury", "funny" }, fx = "sparkle",
	desc = "he walks in and the room gets quieter.", vis = { color = rgb(238, 232, 220), bulk = 0.38, length = 0.6, collar = rgb(255, 255, 255), material = "Sand" } })
add({ id = "vintage_goo_jacket", name = "Vintage Goo Jacket", slot = "Jacket", rarity = "Archive", age = 18, drop = false, source = "Age 18 reward", tags = { "vintage", "luxury" }, fx = "goo", idle = "ArchiveLean",
	desc = "Brady has officially entered his archive era.", vis = { color = rgb(52, 70, 46), sleeve = rgb(34, 44, 30), trim = GOO, bulk = 0.26, length = 0.35, collar = true, material = "Fabric" } })
add({ id = "parachute_bomber", name = "Parachute Cargo Bomber", slot = "Jacket", rarity = "Archive", age = 18, tags = { "vintage", "luxury", "street" }, fx = "dust",
	desc = "has more straps than a backpack store.", vis = { color = rgb(80, 82, 74), bulk = 0.36, puffy = true, straps = rgb(200, 200, 190), collar = true, material = "Fabric" } })
add({ id = "archive_trench", name = "Floor-Length Archive Trench", slot = "Jacket", rarity = "Archive", age = 21, tags = { "vintage", "luxury" }, fx = "smoke", walk = "ArchiveWalk", idle = "ArchiveLean",
	desc = "it drags on the floor. that is the look.", vis = { color = rgb(24, 24, 28), bulk = 0.2, length = 1.7, collar = true, material = "Fabric" } })
add({ id = "runway_sample", name = "Runway Sample Jacket '99", slot = "Jacket", rarity = "Grail", age = 21, tags = { "vintage", "luxury" }, fx = "rainbow", nameplate = "Grail", spawn = true, pose = "GrailFloat", walk = "LegendWalk",
	desc = "worn once on a runway. then lost. then found.", vis = { color = rgb(236, 236, 240), sleeve = rgb(255, 110, 225), trim = rgb(120, 255, 255), bulk = 0.3, length = 0.9, collar = true, material = "Glass" } })

-- ACCESSORIES (unlock at Trendy Brady, age 10) ----------------------------
add({ id = "goo_chain", name = "Lil Goo Chain", slot = "Accessory", rarity = "Uncommon", age = 10, drop = false, source = "Age 10 reward", tags = { "street" },
	desc = "small chain. big dreams.", vis = { kind = "chain", color = rgb(210, 210, 215), color2 = GOO, size = 1 } })
add({ id = "striped_scarf", name = "Stripey Scarf", slot = "Accessory", rarity = "Uncommon", age = 10, price = 380, tags = { "vintage" },
	desc = "it is not even cold.", vis = { kind = "scarf", color = rgb(200, 50, 50), color2 = CREAM } })
add({ id = "mini_backpack", name = "Mini Backpack", slot = "Accessory", rarity = "Uncommon", age = 10, price = 420, tags = { "street", "funny" },
	desc = "fits one (1) snack.", vis = { kind = "backpack", color = rgb(70, 130, 230), color2 = rgb(255, 220, 70) } })
add({ id = "crossbody_bag", name = "Crossbody Bag", slot = "Accessory", rarity = "Rare", age = 10, price = 1000, tags = { "street" },
	desc = "holds his phone, his snacks and his ego.", vis = { kind = "crossbody", color = BLACK, color2 = rgb(180, 180, 180) } })
add({ id = "chunky_headphones", name = "Chunky Headphones", slot = "Accessory", rarity = "Rare", age = 13, price = 1100, tags = { "street" },
	desc = "he can't hear you. he can't hear anyone.", vis = { kind = "headphones", color = rgb(240, 240, 240), color2 = rgb(255, 90, 90) } })
add({ id = "wallet_chain", name = "Wallet Chain", slot = "Accessory", rarity = "Epic", age = 16, price = 2600, tags = { "vintage", "street" },
	desc = "the wallet is empty. the chain is not.", vis = { kind = "walletchain", color = rgb(200, 200, 205) } })
add({ id = "ice_chain", name = "Iced Out Chain", slot = "Accessory", rarity = "Epic", age = 13, price = 2800, tags = { "luxury", "street" }, fx = "sparkle",
	desc = "blinding. literally. wear sunglasses.", vis = { kind = "chain", color = rgb(190, 235, 255), color2 = rgb(140, 220, 255), size = 1.5 } })
add({ id = "angel_wings", name = "Tiny Angel Wings", slot = "Accessory", rarity = "Legendary", age = 16, tags = { "funny", "luxury" }, fx = "sparkle",
	desc = "too small to fly. big enough to flex.", vis = { kind = "wings", color = WHITE, color2 = GOLD } })
add({ id = "archive_tote", name = "Deconstructed Archive Tote", slot = "Accessory", rarity = "Archive", age = 18, tags = { "vintage", "luxury" }, fx = "dust",
	desc = "a bag with no bottom. fashion.", vis = { kind = "tote", color = rgb(214, 204, 180), color2 = BLACK } })
add({ id = "grail_aura", name = "Grail Aura", slot = "Accessory", rarity = "Grail", age = 21, tags = { "luxury" }, fx = "rainbow", nameplate = "Grail", spawn = true, pose = "GrailFloat", idle = "Legend",
	desc = "you cannot buy aura. except this one. kind of.", vis = { kind = "aura", color = rgb(255, 110, 225), color2 = rgb(120, 255, 255) } })

-- HATS (unlock at Kid Brady, age 5) ---------------------------------------
add({ id = "beanie", name = "Goo Beanie", slot = "Hat", rarity = "Uncommon", age = 5, drop = false, source = "Age 5 reward", tags = { "street" },
	desc = "worn in summer. obviously.", vis = { kind = "beanie", color = GOO_DARK, color2 = WHITE } })
add({ id = "dad_cap", name = "Dad Cap", slot = "Hat", rarity = "Common", age = 5, price = 120,
	desc = "smells like a lawn.", vis = { kind = "cap", color = rgb(60, 80, 130), color2 = WHITE } })
add({ id = "backwards_cap", name = "Backwards Cap", slot = "Hat", rarity = "Uncommon", age = 5, price = 260, tags = { "street" },
	desc = "it's backwards so the drip goes forwards.", vis = { kind = "cap", color = rgb(220, 60, 60), color2 = BLACK, backwards = true } })
add({ id = "propeller_hat", name = "Propeller Hat", slot = "Hat", rarity = "Uncommon", age = 5, price = 300, tags = { "funny" },
	desc = "achieves lift-off at high speeds.", vis = { kind = "propeller", color = rgb(60, 130, 240), color2 = rgb(255, 80, 80) } })
add({ id = "bucket_hat", name = "Bucket Hat", slot = "Hat", rarity = "Uncommon", age = 8, price = 340, tags = { "street", "vintage" },
	desc = "it's a bucket. for his head.", vis = { kind = "bucket", color = rgb(230, 220, 190), color2 = rgb(200, 190, 160) } })
add({ id = "artsy_beret", name = "Artsy Beret", slot = "Hat", rarity = "Rare", age = 10, price = 900, tags = { "vintage", "luxury" },
	desc = "he says 'bonjour' now. it is unbearable.", vis = { kind = "beret", color = rgb(150, 30, 40) } })
add({ id = "trapper_hat", name = "Fuzzy Trapper Hat", slot = "Hat", rarity = "Rare", age = 13, price = 1000, tags = { "street", "funny" },
	desc = "ears: warm. vibes: immaculate.", vis = { kind = "trapper", color = rgb(120, 84, 56), color2 = CREAM } })
add({ id = "yeehaw_hat", name = "Yeehaw Hat", slot = "Hat", rarity = "Epic", age = 13, price = 2400, tags = { "funny", "vintage" },
	desc = "this town ain't big enough for this fit.", vis = { kind = "cowboy", color = rgb(150, 100, 60), color2 = rgb(90, 56, 30) } })
add({ id = "top_hat", name = "Fancy Top Hat", slot = "Hat", rarity = "Epic", age = 16, price = 3000, tags = { "luxury", "funny" },
	desc = "distinguished. dapper. slightly too tall.", vis = { kind = "tophat", color = BLACK, color2 = rgb(170, 40, 50) } })
add({ id = "drip_crown", name = "Drip King Crown", slot = "Hat", rarity = "Legendary", age = 16, tags = { "luxury" }, fx = "gold",
	desc = "heavy is the head. worth it.", vis = { kind = "crown", color = GOLD, color2 = rgb(230, 50, 70) } })
add({ id = "archive_hood", name = "Archive Knit Hood", slot = "Hat", rarity = "Archive", age = 18, tags = { "vintage", "luxury" }, fx = "dust",
	desc = "hand-knit by someone very serious.", vis = { kind = "hood", color = rgb(60, 58, 54), color2 = rgb(200, 192, 170) } })
add({ id = "certified_halo", name = "Certified Halo", slot = "Hat", rarity = "Grail", age = 21, tags = { "luxury" }, fx = "gold", nameplate = "Grail", spawn = true, pose = "GrailFloat",
	desc = "certified. verified. sanctified.", vis = { kind = "halo", color = rgb(255, 240, 150) } })

-- GLASSES (unlock at Teen Brady, age 13) ----------------------------------
add({ id = "round_glasses", name = "Round Glasses", slot = "Glasses", rarity = "Uncommon", age = 13, drop = false, source = "Age 13 reward", tags = { "vintage" },
	desc = "now he looks like he reads.", vis = { kind = "round", color = rgb(40, 40, 40), lens = rgb(200, 230, 255), clear = true } })
add({ id = "nerd_glasses", name = "Nerd Glasses", slot = "Glasses", rarity = "Uncommon", age = 13, price = 260, tags = { "funny" },
	desc = "um, actually, the fit is immaculate.", vis = { kind = "nerd", color = BLACK, lens = rgb(220, 240, 255), clear = true } })
add({ id = "cool_shades", name = "Cool Shades", slot = "Glasses", rarity = "Rare", age = 13, price = 950, tags = { "street" },
	desc = "indoors. at night. still wearing them.", vis = { kind = "shades", color = BLACK, lens = rgb(20, 20, 20) } })
add({ id = "tiny_shades", name = "Tiny Oval Shades", slot = "Glasses", rarity = "Rare", age = 13, price = 1050, tags = { "vintage", "street" },
	desc = "protects 4% of each eye.", vis = { kind = "tiny", color = rgb(60, 60, 60), lens = rgb(30, 30, 30) } })
add({ id = "star_glasses", name = "Star Glasses", slot = "Glasses", rarity = "Epic", age = 13, price = 2300, tags = { "funny" },
	desc = "he's a star. his glasses agree.", vis = { kind = "star", color = rgb(255, 210, 60), lens = rgb(255, 120, 200) } })
add({ id = "heart_shades", name = "Heart Shades", slot = "Glasses", rarity = "Epic", age = 16, price = 2500, tags = { "funny", "vintage" },
	desc = "in love with his own reflection.", vis = { kind = "heart", color = rgb(240, 60, 90), lens = rgb(255, 150, 170) } })
add({ id = "speed_visor", name = "Speed Visor", slot = "Glasses", rarity = "Epic", age = 16, price = 2900, tags = { "sport", "street" },
	desc = "makes him 0% faster and 100% cooler.", vis = { kind = "visor", color = rgb(230, 230, 235), lens = rgb(255, 120, 40) } })
add({ id = "gold_frames", name = "Gold Wire Frames", slot = "Glasses", rarity = "Legendary", age = 16, tags = { "luxury", "vintage" }, fx = "gold",
	desc = "thin frames. thick wallet.", vis = { kind = "round", color = GOLD, lens = rgb(255, 235, 180), clear = true } })
add({ id = "shield_shades", name = "Archive Shield Shades", slot = "Glasses", rarity = "Archive", age = 18, tags = { "vintage", "luxury" }, fx = "dust",
	desc = "one giant lens. zero peripheral vision.", vis = { kind = "visor", color = rgb(30, 30, 30), lens = rgb(60, 20, 20), tall = true } })
add({ id = "prototype_goggles", name = "Prototype Goggles", slot = "Glasses", rarity = "Grail", age = 21, tags = { "luxury" }, fx = "rainbow", nameplate = "Grail", spawn = true, pose = "GrailFloat",
	desc = "a prototype from a collection that never dropped.", vis = { kind = "goggles", color = rgb(230, 230, 235), lens = rgb(120, 255, 255) } })

-- FULL OUTFITS (unlock at Fashion Brady, age 16) ---------------------------
-- An equipped outfit visually replaces the shirt / pants / shoes / jacket slots.
add({ id = "tracksuit", name = "Full Goo Tracksuit", slot = "Outfit", rarity = "Rare", age = 16, drop = false, source = "Age 16 reward", tags = { "sport", "street" },
	desc = "matching top and bottom. he is now unstoppable.",
	vis = {
		shirt = { color = GOO_DARK, sleeves = "long", stripes = WHITE },
		pants = { color = GOO_DARK, stripe = WHITE },
		shoes = { color = WHITE, sole = GOO, chunk = 1.1 },
	} })
add({ id = "skater_set", name = "Skater Set", slot = "Outfit", rarity = "Epic", age = 16, price = 3600, tags = { "street" },
	desc = "still does not own a skateboard.",
	vis = {
		shirt = { color = rgb(240, 240, 240), sleeves = "short", under = BLACK, graphic = "flame", graphicColor = rgb(230, 60, 60), oversized = true },
		pants = { color = rgb(50, 70, 120), width = 1.45 },
		shoes = { color = BLACK, sole = WHITE, chunk = 1.25 },
		hat = { kind = "beanie", color = rgb(230, 60, 60), color2 = BLACK },
	} })
add({ id = "banana_suit", name = "Banana Suit", slot = "Outfit", rarity = "Epic", age = 16, price = 3500, tags = { "funny" },
	desc = "he is a banana. do not question the banana.",
	vis = {
		shirt = { color = rgb(255, 225, 60), sleeves = "long", oversized = true },
		pants = { color = rgb(255, 225, 60), width = 1.3 },
		shoes = { color = rgb(120, 80, 30), sole = rgb(90, 60, 20) },
		hat = { kind = "hood", color = rgb(255, 225, 60), color2 = rgb(120, 80, 30) },
	} })
add({ id = "sharp_suit", name = "Sharp Black Suit", slot = "Outfit", rarity = "Epic", age = 16, price = 4000, tags = { "luxury" },
	desc = "he has a meeting. with the mirror.",
	vis = {
		shirt = { color = WHITE, sleeves = "long", stripes = rgb(170, 40, 50) },
		pants = { color = rgb(24, 24, 28), width = 0.95 },
		shoes = { color = rgb(20, 20, 20), sole = rgb(50, 50, 50) },
		jacket = { color = rgb(24, 24, 28), collar = true, length = 0.2 },
	} })
add({ id = "monochrome_fit", name = "All-White Monochrome Fit", slot = "Outfit", rarity = "Legendary", age = 18, price = 9000, tags = { "luxury", "street" }, fx = "sparkle",
	desc = "do not let him near spaghetti.",
	vis = {
		shirt = { color = WHITE, sleeves = "long", oversized = true },
		pants = { color = WHITE, width = 1.3 },
		shoes = { color = WHITE, sole = WHITE, chunk = 1.25, glow = WHITE },
		jacket = { color = rgb(250, 250, 250), bulk = 0.26, length = 0.5, collar = true },
	} })
add({ id = "space_cowboy", name = "Space Cowboy Fit", slot = "Outfit", rarity = "Legendary", age = 18, tags = { "funny", "vintage" }, fx = "stars",
	desc = "yeehaw, but in zero gravity.",
	vis = {
		shirt = { color = rgb(40, 30, 90), sleeves = "long", graphic = "star", graphicColor = rgb(200, 220, 255) },
		pants = { color = rgb(200, 200, 215), flare = true, material = "Glass" },
		shoes = { color = rgb(200, 200, 215), sole = rgb(90, 60, 200), high = true, chunk = 1.15 },
		jacket = { color = rgb(200, 200, 215), trim = rgb(120, 90, 255), bulk = 0.2, collar = true, material = "Glass" },
		hat = { kind = "cowboy", color = rgb(200, 200, 215), color2 = rgb(120, 90, 255) },
	} })
add({ id = "vintage_royal", name = "Vintage Royalty Fit", slot = "Outfit", rarity = "Legendary", age = 21, drop = false, source = "Age 21 reward", tags = { "vintage", "luxury" }, fx = "gold",
	desc = "thrifted from a king. allegedly.",
	vis = {
		shirt = { color = rgb(110, 20, 40), sleeves = "long", graphic = "star", graphicColor = GOLD },
		pants = { color = rgb(40, 30, 30), width = 1.2, stripe = GOLD },
		shoes = { color = rgb(60, 30, 20), sole = GOLD, high = true },
		jacket = { color = rgb(110, 20, 40), trim = GOLD, bulk = 0.3, length = 1.1, collar = rgb(245, 240, 230), material = "Fabric" },
	} })
add({ id = "runway_look_7", name = "Runway Look No. 7", slot = "Outfit", rarity = "Archive", age = 18, tags = { "vintage", "luxury" }, fx = "smoke", walk = "ArchiveWalk", idle = "ArchiveLean",
	desc = "nobody understands it. everybody respects it.",
	vis = {
		shirt = { color = rgb(210, 200, 180), sleeves = "long", holes = true, oversized = true, material = "Fabric" },
		pants = { color = rgb(26, 26, 28), width = 1.7, straps = rgb(200, 200, 190), material = "Fabric" },
		shoes = { color = rgb(226, 220, 204), sole = rgb(40, 40, 40), high = true, split = true, platform = 0.2 },
		jacket = { color = rgb(26, 26, 28), bulk = 0.28, length = 1.4, collar = true, material = "Fabric" },
	} })
add({ id = "wasteland_nomad", name = "Wasteland Nomad Layers", slot = "Outfit", rarity = "Archive", age = 21, tags = { "vintage", "luxury" }, fx = "dust", walk = "ArchiveWalk", idle = "ArchiveLean",
	desc = "seven layers. each one a different shade of dust.",
	vis = {
		shirt = { color = rgb(150, 132, 104), sleeves = "long", holes = true, oversized = true, material = "Fabric" },
		pants = { color = rgb(96, 84, 66), width = 1.55, pockets = true, straps = rgb(60, 50, 40), material = "Fabric" },
		shoes = { color = rgb(70, 56, 40), sole = rgb(40, 32, 24), high = true, chunk = 1.3, platform = 0.15 },
		jacket = { color = rgb(120, 104, 80), sleeve = rgb(96, 84, 66), bulk = 0.34, length = 1.2, hood = true, material = "Fabric" },
		accessory = { kind = "scarf", color = rgb(180, 160, 120), color2 = rgb(96, 84, 66) },
	} })
add({ id = "legendary_goo", name = "Legendary Goo Drip", slot = "Outfit", rarity = "Legendary", age = 25, drop = false, source = "Age 25 reward", tags = { "luxury", "street", "vintage" }, fx = "goo", walk = "LegendWalk", idle = "Legend",
	desc = "the final form. gold, goo and zero doubts.",
	vis = {
		shirt = { color = BLACK, sleeves = "long", graphic = "goo", graphicColor = GOLD, oversized = true },
		pants = { color = BLACK, width = 1.5, stripe = GOLD, flare = true },
		shoes = { color = GOLD, sole = GOO, chunk = 1.3, platform = 0.2, glow = GOO, material = "Glass" },
		jacket = { color = rgb(30, 30, 34), trim = GOLD, sleeve = GOO_DARK, bulk = 0.32, length = 1.3, collar = GOLD, material = "Fabric" },
		accessory = { kind = "chain", color = GOLD, color2 = GOO, size = 1.6 },
	} })
add({ id = "the_grail_fit", name = "THE GRAIL FIT", slot = "Outfit", rarity = "Grail", age = 21, tags = { "vintage", "luxury", "street" }, fx = "rainbow", nameplate = "Grail", spawn = true, pose = "GrailFloat", walk = "LegendWalk", idle = "Legend",
	desc = "the one they write forum posts about.",
	vis = {
		shirt = { color = rgb(245, 245, 250), sleeves = "long", graphic = "goo", graphicColor = rgb(255, 110, 225), oversized = true, material = "Neon" },
		pants = { color = rgb(236, 236, 244), width = 1.7, flare = true, plaid = rgb(120, 255, 255), straps = rgb(255, 110, 225) },
		shoes = { color = WHITE, sole = rgb(120, 255, 255), chunk = 1.4, platform = 0.4, glow = rgb(255, 110, 225), material = "Neon" },
		jacket = { color = rgb(240, 240, 248), sleeve = rgb(120, 255, 255), trim = rgb(255, 110, 225), bulk = 0.36, length = 1.6, collar = rgb(255, 110, 225), material = "Glass" },
		accessory = { kind = "aura", color = rgb(255, 110, 225), color2 = rgb(120, 255, 255) },
	} })

-- HAIRSTYLES (customising unlocks at Kid Brady, age 5) ---------------------
-- Stage hairstyles are handed out for free as Brady grows.
add({ id = "hair_baby", name = "Baby Curl", slot = "Hair", rarity = "Common", age = 1, drop = false, source = "Baby Brady", desc = "one (1) curl.", vis = { style = "babycurl" } })
add({ id = "hair_bowl", name = "Bowl Cut", slot = "Hair", rarity = "Common", age = 3, drop = false, source = "Age 3 reward", desc = "mom did it herself. you can tell.", vis = { style = "bowl" } })
add({ id = "hair_spiky", name = "Spiky Kid Hair", slot = "Hair", rarity = "Common", age = 5, drop = false, source = "Age 5 reward", desc = "one entire tub of gel.", vis = { style = "spiky" } })
add({ id = "hair_swoop", name = "The Swoop", slot = "Hair", rarity = "Uncommon", age = 8, drop = false, source = "Age 8 reward", desc = "requires a head flick every 4 seconds.", vis = { style = "swoop" } })
add({ id = "hair_fluffy", name = "Fluffy Trendy Hair", slot = "Hair", rarity = "Uncommon", age = 10, drop = false, source = "Age 10 reward", desc = "fluffy hair. confirmed trendy.", vis = { style = "fluffy" } })
add({ id = "hair_fringe", name = "Teen Curtains", slot = "Hair", rarity = "Rare", age = 13, drop = false, source = "Age 13 reward", desc = "covers his eyes so he can't see his homework.", vis = { style = "curtains" } })
add({ id = "hair_slick", name = "Slick Back", slot = "Hair", rarity = "Rare", age = 16, drop = false, source = "Age 16 reward", desc = "aerodynamic.", vis = { style = "slick" } })
add({ id = "hair_layers", name = "Archive Layers", slot = "Hair", rarity = "Epic", age = 18, drop = false, source = "Age 18 reward", desc = "messy on purpose. took two hours.", vis = { style = "layers" } })
add({ id = "hair_shag", name = "Vintage Shag", slot = "Hair", rarity = "Epic", age = 21, drop = false, source = "Age 21 reward", desc = "business in the front. archive in the back.", vis = { style = "shag" } })
add({ id = "hair_legend", name = "Legendary Flow", slot = "Hair", rarity = "Legendary", age = 25, drop = false, source = "Age 25 reward", fx = "gold", desc = "golden tips. godly flow.", vis = { style = "legend", color2 = GOLD } })
-- Shop hairstyles
add({ id = "hair_buzz", name = "Buzz Cut", slot = "Hair", rarity = "Common", age = 5, price = 100, desc = "low maintenance king.", vis = { style = "buzz" } })
add({ id = "hair_mohawk", name = "Goo Mohawk", slot = "Hair", rarity = "Uncommon", age = 5, price = 300, tags = { "funny", "street" }, desc = "punk's not dead. it's just sticky.", vis = { style = "mohawk" } })
add({ id = "hair_puff", name = "Goo Puff", slot = "Hair", rarity = "Rare", age = 8, price = 800, desc = "big. round. glorious.", vis = { style = "puff" } })
add({ id = "hair_buns", name = "Space Buns", slot = "Hair", rarity = "Rare", age = 10, price = 900, tags = { "funny" }, desc = "two buns. double the antenna reception.", vis = { style = "buns" } })
add({ id = "hair_rockstar", name = "Rockstar Long Hair", slot = "Hair", rarity = "Epic", age = 13, price = 2200, tags = { "vintage" }, desc = "has never touched a guitar.", vis = { style = "long" } })
add({ id = "hair_bleach", name = "Bleached Tips", slot = "Hair", rarity = "Epic", age = 16, price = 2800, tags = { "vintage", "street" }, desc = "the year is 1999 forever.", vis = { style = "spiky", color2 = rgb(250, 240, 180) } })
add({ id = "hair_flame", name = "Flame Hair", slot = "Hair", rarity = "Legendary", age = 16, tags = { "funny" }, fx = "flame", desc = "his head is on fire. he's fine with it.", vis = { style = "mohawk", color = rgb(255, 120, 30), color2 = rgb(255, 220, 60) } })

-- SECRET ITEMS (hidden around the map - cosmetic collectibles) -------------
add({ id = "mystery_jacket", name = "Mystery Jacket", slot = "Jacket", rarity = "Archive", age = 1, drop = false, secret = true, source = "Secret: the Goo Cave", tags = { "vintage", "luxury" }, fx = "void",
	desc = "nobody knows who made it. nobody knows why it hums.", vis = { color = rgb(40, 20, 70), sleeve = rgb(20, 10, 40), trim = rgb(170, 90, 255), bulk = 0.28, length = 0.8, hood = true, material = "Fabric" } })
add({ id = "invisible_shoes", name = "Invisible Shoes", slot = "Shoes", rarity = "Legendary", age = 1, drop = false, secret = true, source = "Secret: rare world spawn", tags = { "funny" },
	desc = "trust me. they're there. they're fire.", vis = { color = WHITE, sole = WHITE, invisible = true } })
add({ id = "ancient_goo_hat", name = "Ancient Goo Hat", slot = "Hat", rarity = "Archive", age = 1, drop = false, secret = true, source = "Secret: rare world spawn", tags = { "vintage", "funny" }, fx = "goo",
	desc = "worn by the first brady. ten thousand years ago.", vis = { kind = "ancient", color = rgb(96, 132, 70), color2 = GOLD } })
add({ id = "golden_shopping_bag", name = "Golden Shopping Bag", slot = "Accessory", rarity = "Archive", age = 1, drop = false, secret = true, source = "Secret: rare world spawn", tags = { "luxury" }, fx = "gold",
	desc = "the bag costs more than what's inside.", vis = { kind = "tote", color = GOLD, color2 = WHITE, shiny = true } })
add({ id = "giant_goo_chain", name = "Giant Goo Chain", slot = "Accessory", rarity = "Legendary", age = 1, drop = false, secret = true, source = "Secret: rare world spawn", tags = { "funny", "street" }, fx = "goo",
	desc = "weighs 40 pounds. his neck is fine. probably.", vis = { kind = "chain", color = GOLD, color2 = GOO, size = 2.6 } })
add({ id = "golden_goo", name = "Golden Goo", slot = "Accessory", rarity = "Grail", age = 1, drop = false, secret = true, source = "Secret: ultra rare world spawn", tags = { "luxury", "funny" }, fx = "gold", nameplate = "Grail", pose = "GrailFloat",
	desc = "a blob of pure golden goo. it follows him around.", vis = { kind = "orb", color = GOLD, color2 = rgb(255, 240, 160) } })

----------------------------------------------------------------------
-- LOOKUPS
----------------------------------------------------------------------
ClothingSystem.BySlot = {}
ClothingSystem.ByRarity = {}
ClothingSystem.SecretIds = {}
for _, slot in ipairs(ClothingSystem.Slots) do
	ClothingSystem.BySlot[slot] = {}
end
for _, rarity in ipairs(ClothingSystem.RarityOrder) do
	ClothingSystem.ByRarity[rarity] = {}
end
for _, item in ipairs(ClothingSystem.List) do
	table.insert(ClothingSystem.BySlot[item.slot], item)
	table.insert(ClothingSystem.ByRarity[item.rarity], item)
	if item.secret then
		table.insert(ClothingSystem.SecretIds, item.id)
	end
end

function ClothingSystem.get(id)
	return ClothingSystem.Items[id]
end

function ClothingSystem.rarityColor(rarity)
	local info = ClothingSystem.Rarities[rarity]
	return info and info.color or Color3.new(1, 1, 1)
end

function ClothingSystem.rarityOrder(rarity)
	local info = ClothingSystem.Rarities[rarity]
	return info and info.order or 0
end

-- Sort helper: rarest first, then by age requirement, then name.
function ClothingSystem.sortItems(list)
	table.sort(list, function(a, b)
		local ra, rb = ClothingSystem.rarityOrder(a.rarity), ClothingSystem.rarityOrder(b.rarity)
		if ra ~= rb then
			return ra > rb
		end
		if a.age ~= b.age then
			return a.age < b.age
		end
		return a.name < b.name
	end)
	return list
end

-- The colour used for an item's inventory tile.
function ClothingSystem.swatch(item)
	local vis = item.vis
	if item.slot == "Outfit" then
		return (vis.jacket and vis.jacket.color) or vis.shirt.color
	elseif item.slot == "Hair" then
		return vis.color or GOO
	end
	return vis.color or GOO
end

return ClothingSystem
