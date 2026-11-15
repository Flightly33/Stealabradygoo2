--[[
	Sounds
	Central sound table. Every entry uses a sound file that ships inside the
	Roblox client (rbxasset://), so the game has audio without you uploading or
	licensing anything. `speed` re-pitches a sound, which is where most of the
	"funny" comes from.

	TO USE YOUR OWN AUDIO: replace an id with "rbxassetid://123456" for any
	audio asset your experience has permission to use. Set Sounds.Music to an
	asset id to get background music (it is empty by default).

	If a built-in file is ever missing on some client, that one sound simply
	stays silent - nothing breaks.
]]

local Sounds = {}

Sounds.Music = "" -- e.g. "rbxassetid://1234567890"
Sounds.MusicVolume = 0.25

Sounds.List = {
	click = { id = "rbxasset://sounds/button.wav", volume = 0.5 },
	tab = { id = "rbxasset://sounds/switch.wav", volume = 0.4 },
	open = { id = "rbxasset://sounds/pageturn.wav", volume = 0.5 },
	coin = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, speed = 1.3 },
	error = { id = "rbxasset://sounds/collide.wav", volume = 0.4, speed = 0.7 },
	notify = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6 },
	ageUp = { id = "rbxasset://sounds/victory.wav", volume = 0.7 },
	ageUpGoofy = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.6, speed = 1.9 },
	item = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, speed = 0.8 },
	rare = { id = "rbxasset://sounds/victory.wav", volume = 0.6, speed = 1.3 },
	grail = { id = "rbxasset://sounds/victory.wav", volume = 0.9, speed = 0.7 },
	eat = { id = "rbxasset://sounds/snap.mp3", volume = 0.5, speed = 0.8 },
	splash = { id = "rbxasset://sounds/impact_water.mp3", volume = 0.5 },
	snore = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.3, speed = 0.45 },
	trip = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.5, speed = 1.5 },
	jump = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.4 },
	place = { id = "rbxasset://sounds/Kerplunk.wav", volume = 0.5 },
	remove = { id = "rbxasset://sounds/swoosh.wav", volume = 0.5 },
	camera = { id = "rbxasset://sounds/flashbulb.wav", volume = 0.6 },
	good = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, speed = 1.6 },
	bad = { id = "rbxasset://sounds/splat.wav", volume = 0.4 },
	event = { id = "rbxasset://sounds/bass.wav", volume = 0.6, speed = 1.2 },
	crate = { id = "rbxasset://sounds/clickfast.wav", volume = 0.5 },
	hype = { id = "rbxasset://sounds/button.wav", volume = 0.5, speed = 1.5 },
}

return Sounds
