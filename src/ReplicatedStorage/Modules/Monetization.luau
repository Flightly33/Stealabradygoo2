--[[
	Monetization
	Optional, cosmetic / convenience-only gamepasses. Nothing here is needed to
	progress, there is no way to buy Goo Coins, and no pass affects fashion
	show judging.

	HOW TO TURN A PASS ON
	  1. Publish the game, open Creator Dashboard > your experience >
	     Monetization > Passes and create the pass.
	  2. Copy its numeric ID into the matching `id` below.
	A pass whose id is 0 is simply treated as "not for sale yet".
]]

local Monetization = {}

Monetization.Passes = {
	{ key = "ExtraOutfits", id = 0, name = "Extra Outfit Slots", icon = "👔",
		desc = "Save 8 outfits in the wardrobe instead of 3." },
	{ key = "VIPDecor", id = 0, name = "VIP Room Decorations", icon = "💎",
		desc = "Unlocks the VIP decoration set in the room shop." },
	{ key = "ExtraStorage", id = 0, name = "Extra Storage", icon = "📦",
		desc = "Place up to 100 pieces of furniture and stack 99 of each food." },
	{ key = "SpecialEmotes", id = 0, name = "Special Emotes", icon = "🕺",
		desc = "Three extra poses for Brady: T-Pose, Goo Shuffle and Dramatic Faint." },
	{ key = "FastDecorating", id = 0, name = "Faster Room Customizing", icon = "⚡",
		desc = "Keep placing the same furniture without reopening the menu." },
	{ key = "CosmeticEffects", id = 0, name = "Cosmetic Effects", icon = "🌈",
		desc = "Pick a sparkle, goo or rainbow trail aura for Brady. Looks only." },
}

Monetization.ByKey = {}
for _, pass in ipairs(Monetization.Passes) do
	Monetization.ByKey[pass.key] = pass
end

-- Auras the Cosmetic Effects pass lets you choose (fx keys from BradyBuilder).
Monetization.Auras = { "none", "sparkle", "goo", "rainbow", "stars" }

return Monetization
