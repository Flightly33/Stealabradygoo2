--[[
	GiftSystem
	As Brady grows up he gifts the PLAYER wearable pieces for their own avatar.
	These are purely cosmetic and are built out of parts by Builders/GiftBuilder
	(no catalog assets needed). One gift can be worn per slot.

	slot -> which avatar attachment it sits on:
	  Head = HatAttachment, Face = FaceFrontAttachment,
	  Neck = NeckAttachment, Back = BodyBackAttachment, Aura = BodyBackAttachment
]]

local GiftSystem = {}

local rgb = Color3.fromRGB

GiftSystem.Slots = { "Head", "Face", "Neck", "Back", "Aura" }

GiftSystem.List = {
	{ id = "gift_bucket", name = "Goo Bucket Hat", slot = "Head", age = 3, kind = "bucket", color = rgb(126, 232, 74), color2 = rgb(64, 168, 52),
		desc = "Little Brady made you match him." },
	{ id = "gift_backpack", name = "Kid Brady Backpack", slot = "Back", age = 5, kind = "backpack", color = rgb(70, 130, 230), color2 = rgb(126, 232, 74),
		desc = "he packed it with snacks. for himself." },
	{ id = "gift_chain", name = "Drippy Chain", slot = "Neck", age = 8, kind = "chain", color = rgb(215, 215, 220), color2 = rgb(126, 232, 74),
		desc = "your first chain. brady is proud." },
	{ id = "gift_shades", name = "Brady's Dark Shades", slot = "Face", age = 10, kind = "shades", color = rgb(25, 25, 28), color2 = rgb(16, 16, 18),
		desc = "a pair just like his signature shades. now you both can't see indoors." },
	{ id = "gift_headphones", name = "Teen Headphones", slot = "Head", age = 13, kind = "headphones", color = rgb(240, 240, 240), color2 = rgb(255, 90, 90),
		desc = "so you can ignore people together." },
	{ id = "gift_scarf", name = "Fashion Scarf", slot = "Neck", age = 16, kind = "scarf", color = rgb(150, 30, 40), color2 = rgb(236, 226, 200),
		desc = "it is not cold. it is fashion." },
	{ id = "gift_cape", name = "Archive Cape", slot = "Back", age = 18, kind = "cape", color = rgb(26, 26, 30), color2 = rgb(232, 66, 78),
		desc = "an original piece from brady's personal archive." },
	{ id = "gift_vintage_cap", name = "Vintage Goo Cap", slot = "Head", age = 21, kind = "cap", color = rgb(236, 226, 200), color2 = rgb(64, 168, 52),
		desc = "faded perfectly. smells like a thrift store." },
	{ id = "gift_crown", name = "Legendary Goo Crown", slot = "Head", age = 25, kind = "crown", color = rgb(255, 205, 60), color2 = rgb(126, 232, 74),
		desc = "you raised a legend. wear the proof." },
	{ id = "gift_aura", name = "Legendary Goo Aura", slot = "Aura", age = 25, kind = "aura", color = rgb(126, 232, 74), color2 = rgb(255, 205, 60),
		desc = "you are glowing. literally." },
}

GiftSystem.ById = {}
for _, gift in ipairs(GiftSystem.List) do
	GiftSystem.ById[gift.id] = gift
end

function GiftSystem.get(id)
	return GiftSystem.ById[id]
end

return GiftSystem
