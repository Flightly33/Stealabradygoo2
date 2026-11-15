--[[
	Dialogue
	Every short, meme-y thing Brady says. Keep lines tiny: they show in a
	speech bubble over his head for a few seconds.
]]

local Dialogue = {}

Dialogue.Lines = {
	-- random idle chatter, by stage id
	Baby = { "goo goo", "ga ga (fashionably)", "*drools*", "ba ba", "bib is mid", "*judging you*" },
	Little = { "why", "why?", "but why", "i can walk now", "shoes are cool", "watch this" },
	Kid = { "look at my hat", "i'm basically grown", "can we get snacks", "bro", "hats are my thing now" },
	Drippy = { "do you see the drip", "it's called fashion", "lowkey dripped out", "first drip. real drip." },
	Trendy = { "this is trending", "nah this is crazy", "outfit check", "everyone's wearing this" },
	Teen = { "mid.", "whatever", "the shades stay on", "it's not a phase", "literally me" },
	Fashion = { "this hallway is a runway", "fit check by the wall", "the silhouette. look at it.", "brady is locked in" },
	Archive = { "archive era", "it's a piece, not a jacket", "this is from '98", "you wouldn't know the designer" },
	Vintage = { "they don't make them like this anymore", "this crewneck is older than me", "true vintage only" },
	Legendary = { "i am the archive", "most archive person on roblox", "legendary.", "goo forever" },

	-- needs
	hungry = { "i'm starving", "feed me bro", "snack time??", "my stomach is yelling" },
	dirty = { "i stink", "bro i need a shower", "the fit is dirty", "something smells. it's me." },
	tired = { "so sleepy", "need. bed.", "*yawn*", "running on 1%" },
	bored = { "i'm bored", "play with me", "do something", "boooored" },

	-- reactions
	fed = { "YUMMY", "bussin", "10/10 would eat again", "*happy chewing*", "chef's kiss" },
	mysteryGood = { "WHAT WAS THAT. AGAIN.", "i can taste colors" },
	mysteryBad = { "that was a mistake", "why was it crunchy" },
	clean = { "squeaky clean", "fresh", "i smell like victory" },
	brushed = { "hair is laid", "not a strand out of place" },
	shoes = { "kicks are crispy", "no creases" },
	sleep = { "goodnight", "zzz", "five more minutes" },
	wake = { "i'm up i'm up", "what year is it", "best nap ever" },
	notTired = { "i'm not tired", "no bed. only vibes." },
	full = { "i'm full bro", "no more. please." },
	alreadyClean = { "i'm already clean", "you calling me dirty?" },
	play = { "LET'S GO", "again again", "that was fun" },
	win = { "TOO EASY", "we're so good at this", "W" },
	lose = { "we'll get 'em next time", "that was practice", "L (small)" },
	trip = { "i meant to do that", "who put that there", "ow" },
	pose = { "strike a pose", "*poses*", "camera ready" },
	mirror = { "looking good", "who's that? oh. me.", "mirror check" },

	-- fashion
	newItem = { "new piece!", "adding to the closet", "W pickup" },
	rareItem = { "NO WAY", "RARE PIECE", "let's GOOO" },
	archiveItem = { "ARCHIVE PIECE", "archive era", "this belongs in a museum" },
	grailItem = { "GRAIL FOUND", "GRAIL. GRAIL. GRAIL.", "i'm shaking" },
	badFit = { "bro what is this fit", "the fit is NOT it", "where are my pants", "i can't go out like this" },
	goodFit = { "the fit is insane", "brady is dripped out", "nah this is crazy", "certified" },
	ageUp = { "I'M OLDER", "leveling up", "new era", "growing up fr" },
	stageUp = { "NEW ERA UNLOCKED", "i feel different", "character development" },
	outside = { "touching grass", "fresh air hits different", "outside is cool" },
	follow = { "wait for me", "i'm coming", "road trip" },
	home = { "home sweet home", "back to the crib" },
	runway = { "runway time", "watch the walk", "this is my moment" },
	showWin = { "FASHION ICON", "best dressed, obviously", "the judges have taste" },
	showLose = { "robbed.", "the judges don't get it", "ahead of my time" },
	rebirth = { "we go again", "born again. drippier." },
}

function Dialogue.pick(key, rng)
	local lines = Dialogue.Lines[key]
	if not lines or #lines == 0 then
		return nil
	end
	local index = rng and rng:NextInteger(1, #lines) or math.random(1, #lines)
	return lines[index]
end

return Dialogue
