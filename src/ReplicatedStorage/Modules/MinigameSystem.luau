--[[
	MinigameSystem
	Definitions for the "Play with Brady" mini-games and the reward formula.

	The mini-games themselves run on the client (they are UI games), so the
	server never trusts the reported score blindly: it clamps the score to
	maxScore, checks the round lasted a believable amount of time, charges
	energy up front and enforces a cooldown. See Services/MinigameServer.
]]

local MinigameSystem = {}

-- duration  seconds the client game runs for
-- minTime   fastest a real round could possibly finish
-- maxScore  best score the game can produce
-- coins/xp  reward for a perfect score (before age multiplier)
MinigameSystem.List = {
	{ id = "catch", name = "Catch the Ball", icon = "⚾", minAge = 1, duration = 20, minTime = 12, maxScore = 20, coins = 34, xp = 46,
		desc = "drag Brady left and right. catch balls. dodge the socks." },
	{ id = "target", name = "Click the Target", icon = "🎯", minAge = 1, duration = 20, minTime = 12, maxScore = 25, coins = 34, xp = 46,
		desc = "tap the targets before they vanish." },
	{ id = "reaction", name = "Reaction Test", icon = "⚡", minAge = 1, duration = 25, minTime = 6, maxScore = 100, coins = 28, xp = 40,
		desc = "wait for green. tap as fast as you can. 5 rounds." },
	{ id = "obby", name = "Goo Obby", icon = "🏃", minAge = 3, duration = 120, minTime = 9, maxScore = 100, coins = 60, xp = 80, world = true,
		desc = "run the obstacle course in the mini-game area." },
	{ id = "soccer", name = "Goo Soccer", icon = "⚽", minAge = 5, duration = 40, minTime = 8, maxScore = 5, coins = 40, xp = 55,
		desc = "5 penalty kicks against a very sweaty goalie." },
	{ id = "dance", name = "Dance Battle", icon = "🕺", minAge = 8, duration = 25, minTime = 15, maxScore = 30, coins = 46, xp = 64,
		desc = "hit the arrows on the beat." },
}

MinigameSystem.ById = {}
for _, def in ipairs(MinigameSystem.List) do
	MinigameSystem.ById[def.id] = def
end

function MinigameSystem.get(id)
	return MinigameSystem.ById[id]
end

-- Reward for a score. `multiplier` = age multiplier * arcade bonus etc.
-- Even a terrible round pays a little so playing never feels wasted.
function MinigameSystem.rewards(def, score, multiplier)
	local ratio = math.clamp(score / def.maxScore, 0, 1)
	local coins = math.floor(def.coins * (0.15 + 0.85 * ratio) * multiplier + 0.5)
	local xp = math.floor(def.xp * (0.25 + 0.75 * ratio) + 0.5)
	return coins, xp, ratio
end

return MinigameSystem
