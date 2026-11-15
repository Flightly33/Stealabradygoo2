--[[
	EventSystem
	Definitions for the random events that pop up every few minutes.
	Each one is a short interactive task; Services/EventServer runs them.

	task kinds
	  findObject  a prop spawns near the house, the owner grabs it
	  feed        feed Brady
	  openBox     open the mystery box that appeared in the room
	  goPark      walk to the park with Brady following
	  hype        mash the HYPE button
	  haircut     choose KEEP or FIX (fix = brush his hair)
	  changeFit   change pieces of his outfit
]]

local EventSystem = {}

EventSystem.List = {
	{ id = "LostShoes", title = "BRADY LOST HIS SHOES", task = "findObject", duration = 80, weight = 10, minAge = 3,
		desc = "his shoes are somewhere around the house. go grab them!", coins = 60, xp = 50,
		say = "bro where are my shoes", win = "SHOES SECURED" },
	{ id = "Hungry", title = "BRADY IS HUNGRY", task = "feed", duration = 60, weight = 12, minAge = 1,
		desc = "feed him before he gets hangry!", coins = 40, xp = 40,
		say = "i'm literally starving", win = "CRISIS AVERTED" },
	{ id = "FoundGrail", title = "BRADY FOUND A GRAIL", task = "openBox", duration = 90, weight = 6, minAge = 5,
		desc = "a mystery box appeared in his room. open it!", coins = 30, xp = 60,
		say = "GRAIL FOUND", win = "BOX OPENED" },
	{ id = "GoOutside", title = "BRADY WANTS TO GO OUTSIDE", task = "goPark", duration = 150, weight = 9, minAge = 3,
		desc = "take Brady to the park. he will follow you!", coins = 90, xp = 90,
		say = "i need to touch grass", win = "GRASS TOUCHED" },
	{ id = "InsaneFit", title = "BRADY'S FIT IS INSANE", task = "hype", duration = 20, weight = 9, minAge = 1, goal = 15,
		desc = "hype him up! smash the HYPE button 15 times!", coins = 50, xp = 45,
		say = "nah this is crazy", win = "HYPE DELIVERED" },
	{ id = "NewHaircut", title = "BRADY GOT A NEW HAIRCUT", task = "haircut", duration = 45, weight = 8, minAge = 3,
		desc = "keep it... or brush it back to normal?", coins = 45, xp = 45,
		say = "do you like it? be honest", win = "HAIR HANDLED" },
	{ id = "FashionCrisis", title = "BRADY IS HAVING A FASHION CRISIS", task = "changeFit", duration = 75, weight = 9, minAge = 1, goal = 2,
		desc = "open the wardrobe and change 2 pieces of his fit!", coins = 60, xp = 60,
		say = "the fit is NOT it", win = "FIT FIXED" },
}

EventSystem.ById = {}
for _, def in ipairs(EventSystem.List) do
	EventSystem.ById[def.id] = def
end

function EventSystem.get(id)
	return EventSystem.ById[id]
end

-- Events available for a given Brady age.
function EventSystem.eligible(age)
	local list = {}
	for _, def in ipairs(EventSystem.List) do
		if age >= def.minAge then
			table.insert(list, def)
		end
	end
	return list
end

return EventSystem
