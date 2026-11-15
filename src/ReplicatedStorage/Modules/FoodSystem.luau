--[[
	FoodSystem
	Everything Brady can eat. Cereal is free and unlimited so nobody can get
	stuck with a starving Brady and zero coins.
]]

local FoodSystem = {}

local rgb = Color3.fromRGB

FoodSystem.List = {
	{ id = "cereal", name = "Soggy Cereal", icon = "🥣", price = 0, free = true, hunger = 16, xp = 6, color = rgb(240, 220, 150),
		desc = "free. unlimited. slightly sad." },
	{ id = "fruit", name = "Fruit Bowl", icon = "🍎", price = 25, hunger = 24, xp = 14, color = rgb(230, 70, 60),
		desc = "healthy. he is suspicious of it." },
	{ id = "pizza", name = "Pizza Slice", icon = "🍕", price = 45, hunger = 36, xp = 22, color = rgb(245, 180, 70),
		desc = "the food pyramid is a triangle. so is pizza." },
	{ id = "burger", name = "Goo Burger", icon = "🍔", price = 70, hunger = 50, xp = 32, color = rgb(170, 110, 60),
		desc = "the green stuff is 'special sauce'." },
	{ id = "mystery", name = "Goofy Mystery Food", icon = "🧪", price = 110, hunger = 40, xp = 0, mystery = true, color = rgb(170, 90, 255),
		desc = "could be amazing. could be a mistake. 5 to 120 XP." },
	{ id = "cake", name = "Birthday Cake", icon = "🎂", price = 240, hunger = 70, xp = 90, minAge = 8, color = rgb(255, 170, 200),
		desc = "it is always somebody's birthday." },
	{ id = "sushi", name = "Fancy Sushi", icon = "🍣", price = 420, hunger = 60, xp = 170, minAge = 16, color = rgb(250, 140, 110),
		desc = "archive bradys only eat tiny expensive food." },
}

FoodSystem.ById = {}
for _, food in ipairs(FoodSystem.List) do
	FoodSystem.ById[food.id] = food
end

function FoodSystem.get(id)
	return FoodSystem.ById[id]
end

return FoodSystem
