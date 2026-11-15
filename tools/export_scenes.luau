--[[
	Dev tool: dumps the geometry the builders produce to JSON so
	tools/render_scenes.py can draw preview images without Roblox Studio.

	    rojo build default.project.json -o build/test.rbxl
	    lune run tools/export_scenes.luau
	    python3 tools/render_scenes.py
]]
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local H = require("../tests/harness")
local roblox = H.roblox

H.boot(fs.readFile("build/test.rbxl"), {})
local RS = H.ReplicatedStorage
local function shared(name)
	return H.server.require(RS.Modules:FindFirstChild(name) or RS.Modules.Builders:FindFirstChild(name))
end
local BradyBuilder = shared("BradyBuilder")
local FurnitureBuilder = shared("FurnitureBuilder")
local AgeSystem = shared("AgeSystem")

local function dump(root)
	local parts = {}
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.95 then
			local shape = "Block"
			if d.ClassName == "Part" then
				shape = d.Shape.Name
			end
			table.insert(parts, {
				name = d.Name,
				cf = { d.CFrame:GetComponents() },
				size = { d.Size.X, d.Size.Y, d.Size.Z },
				color = { d.Color.R, d.Color.G, d.Color.B },
				shape = shape,
				alpha = 1 - d.Transparency,
				neon = d.Material == roblox.Enum.Material.Neon,
			})
		end
	end
	return parts
end

local scenes = {}

-- Brady at each of the ten stages, wearing what that stage unlocks.
local FITS = {
	{ age = 1, label = "Age 1 - Baby Brady", equipped = {} },
	{ age = 3, label = "Age 3 - Little Brady", equipped = { Shirt = "goo_tee", Pants = "pajama_pants", Shoes = "velcro_lights" } },
	{ age = 5, label = "Age 5 - Kid Brady", equipped = { Shirt = "smile_tee", Pants = "khaki_shorts", Shoes = "canvas_highs", Hat = "propeller_hat" } },
	{ age = 8, label = "Age 8 - Drippy Brady", equipped = { Shirt = "layered_tee", Pants = "cargo_pants", Shoes = "skate_shoes", Jacket = "zip_hoodie", Hat = "beanie" } },
	{ age = 10, label = "Age 10 - Trendy Brady", equipped = { Shirt = "flame_tee", Pants = "baggy_jeans", Shoes = "designer_sneakers", Jacket = "big_puffer", Accessory = "goo_chain" } },
	{ age = 13, label = "Age 13 - Teen Brady", equipped = { Shirt = "goo_jersey", Pants = "parachute_pants", Shoes = "combat_boots", Glasses = "cool_shades", Accessory = "chunky_headphones" } },
	{ age = 16, label = "Age 16 - Fashion Brady", equipped = { Shirt = "tour_tee", Pants = "waxed_denim", Shoes = "gold_kicks", Jacket = "leather_jacket", Glasses = "tiny_shades", Accessory = "wallet_chain" } },
	{ age = 18, label = "Age 18 - Archive Brady", equipped = { Shirt = "archive_knit", Pants = "archive_cargos", Shoes = "split_toe_boots", Jacket = "vintage_goo_jacket", Glasses = "shield_shades", Accessory = "archive_tote" } },
	{ age = 21, label = "Age 21 - Vintage Brady", equipped = { Outfit = "vintage_royal", Hat = "drip_crown", Glasses = "gold_frames" } },
	{ age = 25, label = "Age 25 - Legendary Brady Goo", equipped = { Outfit = "legendary_goo", Hat = "certified_halo", Glasses = "prototype_goggles" } },
}
for index, fit in ipairs(FITS) do
	local stage = AgeSystem.getStage(fit.age)
	fit.equipped.Hair = fit.equipped.Hair or stage.look.hair
	local model = BradyBuilder.build({ age = fit.age, equipped = fit.equipped, preview = true })
	table.insert(scenes, { group = "stages", label = fit.label, parts = dump(model), order = index })
	model:Destroy()
end

local SPECIAL = {
	{ "THE GRAIL FIT", { Outfit = "the_grail_fit" } },
	{ "Runway Look No. 7", { Outfit = "runway_look_7", Hat = "archive_hood" } },
	{ "Banana Suit", { Outfit = "banana_suit", Glasses = "star_glasses" } },
	{ "Sharp Black Suit", { Outfit = "sharp_suit", Hat = "top_hat" } },
	{ "Space Cowboy", { Outfit = "space_cowboy" } },
	{ "No pants (embarrassed)", { Shirt = "plain_tee", Hat = "yeehaw_hat", Accessory = "angel_wings" } },
	{ "Archive trench + platforms", { Shirt = "longsleeve_blk", Pants = "flare_denim", Shoes = "platform_stompers", Jacket = "archive_trench", Accessory = "giant_goo_chain" } },
	{ "Secrets: golden goo + ancient hat", { Shirt = "silk_shirt", Pants = "plaid_pants", Shoes = "invisible_shoes", Jacket = "mystery_jacket", Hat = "ancient_goo_hat", Accessory = "golden_goo" } },
}
for index, entry in ipairs(SPECIAL) do
	entry[2].Hair = entry[2].Hair or "hair_layers"
	local model = BradyBuilder.build({ age = 25, equipped = entry[2], preview = true })
	table.insert(scenes, { group = "special", label = entry[1], parts = dump(model), order = index })
	model:Destroy()
end

-- Back views (hair / jackets / backpacks)
for index, entry in ipairs({ { 16, { Shirt = "plain_tee", Pants = "basic_jeans", Shoes = "simple_sneakers", Accessory = "mini_backpack", Hair = "hair_rockstar" } }, { 25, { Outfit = "the_grail_fit", Hair = "hair_legend" } } }) do
	local model = BradyBuilder.build({ age = entry[1], equipped = entry[2], preview = true })
	table.insert(scenes, { group = "back", label = "back view " .. index, parts = dump(model), order = index })
	model:Destroy()
end

for index, id in ipairs({ "couch", "gaming_setup", "sneaker_wall", "throne", "goo_fountain", "clothing_rack", "toy_dino", "vip_dj" }) do
	local model = FurnitureBuilder.build(id)
	table.insert(scenes, { group = "furniture", label = id, parts = dump(model), order = index })
	model:Destroy()
end

-- The world + a house, by booting the real server with one player.
H.startServer()
local player = H.addPlayer("Brady Fan", { ["local"] = true })
H.advance(2)
local Age = H.server.require(H.ServerScriptService.Services.AgeServer)
table.insert(scenes, { group = "world", label = "map", parts = dump(H.Workspace.Map), order = 1 })
table.insert(scenes, { group = "house", label = "Starter Shack (age 1)", parts = dump(H.Workspace.Houses), order = 1 })
local thread = H.task.spawn(function()
	Age.addXP(player, AgeSystem.MaxXP, { raw = true })
end)
H.advance(10)
table.insert(scenes, { group = "house", label = "Archive Mansion (age 25)", parts = dump(H.Workspace.Houses), order = 2 })

fs.writeFile("build/scenes.json", serde.encode("json", scenes))
print("wrote build/scenes.json with " .. #scenes .. " scenes; errors: " .. #H.errors)
