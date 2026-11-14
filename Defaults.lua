-- Default settings and the starter wheels.
ReactWheel = ReactWheel or {}
local RW = ReactWheel

local TEX = "Interface\\AddOns\\ReactWheel\\Textures\\"
local HEART, CHECK, DOWN = "\226\153\165", "\226\136\154", "\226\150\188" -- U+2665, U+221A, U+25BC

RW.DEFAULT_SETTINGS = {
	openMode = "toggle",      -- "toggle" or "hold"
	openAt = "cursor",        -- "cursor" or "center"
	scale = 1,
	radius = 105,             -- minimum ring radius (grows automatically if buttons need room)
	buttonSize = 56,          -- slice button diameter (40-110)
	fontScale = 1,            -- text size on the slice buttons (0.7-2.5)
	hubScale = 1,             -- size of the centre controls and their text (0.8-2.5)
	defaultDest = "AUTO",
	minInterval = 0.5,        -- seconds between reactions (spam guard, 0 = off)
	sayMode = "direct",       -- "direct" (send, falling back to the chat box if the game blocks it) or "prefill" (always use the chat box)
	askMode = "low",          -- "low" (ask when unsure), "never", "always"
	whisperWindow = 30,       -- seconds a whisper counts as "fresh"
	guildWindow = 20,
	groupWindow = 20,
	sayWindow = 20,
	stickWhisper = false,
	ignore = {},
	emoteOnWhisper = false,
	emoteOnGuild = false,
	rules = {
		{ id = "whisper", on = true },
		{ id = "guild", on = true },
		{ id = "group", on = true },
		{ id = "say", on = true },
		{ id = "target", on = false },
		{ id = "fallback", on = true },
	},
	minimap = { hide = false, angle = 215 },
}

local function slot(label, text, emote, extra)
	local s = { label = label, text = text, emote = emote }
	if extra then for k, v in pairs(extra) do s[k] = v end end
	return s
end

function RW.DefaultWheels()
	local wheels = {
		quick = {
			name = "Quick Chat", slots = 8,
			items = {
				slot(nil, CHECK, "NOD", { icon = TEX .. "ThumbsUp", color = { 0.3, 1, 0.3 } }),
				slot(nil, DOWN, "NO", { icon = TEX .. "ThumbsDown", color = { 1, 0.3, 0.3 } }),
				slot(HEART, HEART, "LOVE", { color = { 1, 0.4, 0.5 } }),
				slot("LOL", "LOL", "LAUGH"),
				slot("GG", "GG", "CLAP"),
				slot("thanks!", "thanks!", "THANK"),
				slot("omw", "omw", "WAVE"),
				slot("what?", "what?", "CONFUSED"),
			},
		},
		dungeon = {
			name = "Dungeon / Raid", slots = 8,
			items = {
				slot("ready", "ready"),
				slot("wait", "wait"),
				slot("pull!", "pulling!", "CHARGE"),
				slot("rez?", "rez please"),
				slot("oom", "oom", "OOM"),
				slot("heal?", "heal please", "HEALME"),
				slot("sorry", "sorry!", "SORRY"),
				slot("nice", "nice!", "CHEER"),
			},
		},
		social = {
			name = "Social / Guild", slots = 8,
			items = {
				slot("gz!", "gz!", "CONGRATULATE"),
				slot("hi", "hi!", "HELLO"),
				slot("bye", "bye!", "BYE"),
				slot("nice", "nice!", "CHEER"),
				slot("lol", "lol", "LAUGH"),
				slot("o7", "o7", "SALUTE"),
				slot("welcome", "welcome!", "WELCOME"),
				slot(HEART, HEART, "LOVE", { color = { 1, 0.4, 0.5 } }),
			},
		},
		emotes = {
			name = "Emotes", slots = 8,
			items = {
				slot("dance", nil, "DANCE", { text = "" }),
				slot("wave", nil, "WAVE", { text = "" }),
				slot("cheer", nil, "CHEER", { text = "" }),
				slot("bow", nil, "BOW", { text = "" }),
				slot("salute", nil, "SALUTE", { text = "" }),
				slot("flex", nil, "FLEX", { text = "" }),
				slot("cry", nil, "CRY", { text = "" }),
				slot("laugh", nil, "LAUGH", { text = "" }),
			},
		},
	}
	return wheels, { "quick", "dungeon", "social", "emotes" }
end
