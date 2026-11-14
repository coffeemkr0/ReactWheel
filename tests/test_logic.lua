-- Run via tests/run_tests.py (Lua 5.1 through lupa). Run from the repo root.
dofile("tests/wow_stubs.lua")
for _, f in ipairs({ "Locales", "Core", "Defaults", "Targeting", "Actions", "Wheel" }) do
	assert(loadfile(f .. ".lua"), f)()
end
local RW = ReactWheel
local Tg = RW.Targeting
local fails, total = 0, 0
local function eq(a, b, name)
	total = total + 1
	if a ~= b then fails = fails + 1; print("FAIL " .. name .. ": expected " .. tostring(b) .. " got " .. tostring(a)) end
end

local S = RW.Copy(RW.DEFAULT_SETTINGS)
local function env(o)
	local e = { now = 1000, inRaid = false, inParty = false, inGuild = false }
	for k, v in pairs(o or {}) do e[k] = v end
	return e
end
local function fresh() Tg.ctx = {} end

-- fresh whisper beats group chatter
fresh(); Tg.Observe("WHISPER", "Bob-Realm", 990, S); Tg.Observe("GROUP", nil, 995, S)
local d = Tg.Decide(env({ inParty = true }), Tg.ctx, S)
eq(d.dest, "WHISPER", "whisper wins"); eq(d.target, "Bob-Realm", "whisper target"); eq(d.confidence, "high", "whisper high")

-- stale whisper: group wins but low confidence
fresh(); Tg.Observe("WHISPER", "Bob", 960, S)
d = Tg.Decide(env({ inParty = true }), Tg.ctx, S)
eq(d.dest, "PARTY", "stale -> party"); eq(d.confidence, "low", "stale low")
eq(d.alternatives[2].dest, "WHISPER", "stale whisper listed as alternative")

-- very old whisper is not mentioned as ambiguity
fresh(); Tg.Observe("WHISPER", "Bob", 800, S)
d = Tg.Decide(env({ inParty = true }), Tg.ctx, S)
eq(d.confidence, "high", "old whisper ignored")

-- grouped, no chat -> group, high
fresh(); d = Tg.Decide(env({ inParty = true }), Tg.ctx, S)
eq(d.dest, "PARTY", "party"); eq(d.confidence, "high", "party high")
d = Tg.Decide(env({ inParty = true, inRaid = true }), Tg.ctx, S)
eq(d.dest, "RAID", "raid")

-- guild + group both recent: guild rule first, low confidence, picker alternatives
fresh(); Tg.Observe("GUILD", nil, 995, S); Tg.Observe("GROUP", nil, 996, S)
d = Tg.Decide(env({ inParty = true, inGuild = true }), Tg.ctx, S)
eq(d.dest, "GUILD", "guild first"); eq(d.confidence, "low", "guild+group low")
eq(#d.alternatives, 3, "alts guild/party/say")

-- guild only
fresh(); Tg.Observe("GUILD", nil, 995, S)
d = Tg.Decide(env({ inGuild = true }), Tg.ctx, S)
eq(d.dest, "GUILD", "guild only"); eq(d.confidence, "high", "guild only high")

-- solo, nothing: say fallback, low; solo with /say heard: say, high
fresh(); d = Tg.Decide(env(), Tg.ctx, S)
eq(d.dest, "SAY", "fallback say"); eq(d.confidence, "low", "fallback low")
Tg.Observe("SAY", nil, 995, S)
d = Tg.Decide(env(), Tg.ctx, S)
eq(d.confidence, "high", "say heard high")

-- rule reordering: group above whisper
fresh(); Tg.Observe("WHISPER", "Bob", 990, S)
local S2 = RW.Copy(S)
S2.rules = { { id = "group", on = true }, { id = "whisper", on = true }, { id = "fallback", on = true } }
d = Tg.Decide(env({ inParty = true }), Tg.ctx, S2)
eq(d.dest, "PARTY", "reordered rules")

-- ignore list, self filter and stick-to-whisper
fresh(); local S3 = RW.Copy(S); S3.ignore = { Spammer = true }
Tg.Observe("WHISPER", "Spammer-Realm", 995, S3)
eq(Tg.ctx.whisper, nil, "ignored whisper not recorded")
S3.stickWhisper = true
Tg.Observe("WHISPER", "Bob", 500, S3)
eq(Tg.Decide(env({ inParty = true }), Tg.ctx, S3).dest, "WHISPER", "stick overrides window")
Tg.OnSent("PARTY", S3)
eq(Tg.Decide(env({ inParty = true }), Tg.ctx, S3).dest, "PARTY", "stick released after other send")

-- fixed destinations
local e = env({ inParty = true, inGuild = false, targetName = "Carl" })
eq(Tg.Fixed("PARTY", e).dest, "PARTY", "fixed party")
eq(Tg.Fixed("RAID", e), nil, "fixed raid unavailable")
eq(Tg.Fixed("GUILD", e), nil, "fixed guild unavailable")
eq(Tg.Fixed("WHISPER_TARGET", e).target, "Carl", "fixed whisper target")
eq(Tg.Fixed("SAY", e).dest, "SAY", "fixed say")

-- emote policy
local slot = { emote = "WAVE" }
eq(RW.ShouldEmote(slot, "SAY", S), true, "emote say")
eq(RW.ShouldEmote(slot, "WHISPER", S), false, "no emote whisper")
eq(RW.ShouldEmote(slot, "GUILD", S), false, "no emote guild")
S.emoteOnWhisper = true
eq(RW.ShouldEmote(slot, "WHISPER", S), true, "global whisper emote")
eq(RW.ShouldEmote({ emote = "X", emoteWhen = "never" }, "SAY", S), false, "never")
eq(RW.ShouldEmote({ emote = "X", emoteWhen = "always" }, "GUILD", S), true, "always")
eq(RW.ShouldEmote(slot, nil, S), true, "emote-only slot")
S.emoteOnWhisper = false

-- DB init + migration
ReactWheelDB = { ver = 3, reactions = { "x" }, upText = "OK" }
ReactWheelCharDB = nil
RW.InitDB()
eq(ReactWheelDB.ver, 5, "db version"); eq(ReactWheelDB.reactions, nil, "old reactions dropped")
eq(RW.P().wheels.quick.items[1].text, "OK", "upText carried over")
eq(#RW.P().order, 4, "four wheels"); eq(RW.P().wheels.quick.slots, 8, "slots")
eq(RW.P().wheels.quick.items[3].text, "\226\153\165", "heart text")
ReactWheelDB.ver = 4; ReactWheelDB.profile.settings.sayMode = "prefill"; RW.InitDB()
eq(ReactWheelDB.profile.settings.sayMode, "direct", "migrated to direct")
-- profiles
ReactWheelCharDB.profile = RW.Copy(ReactWheelDB.profile); ReactWheelCharDB.useChar = true
ReactWheelCharDB.profile.current = "social"
eq(RW.P().current, "social", "character profile in use")
ReactWheelCharDB.useChar = false
eq(RW.P().current, "quick", "account profile in use")

-- actions
eq(RW.NeedsDest({ text = "hi" }), true, "text needs dest")
eq(RW.NeedsDest({ text = "", emote = "DANCE" }), false, "emote only")
eq(RW.IsEmpty({}), true, "empty slot"); eq(RW.IsEmpty({ label = "x", text = "y" }), false, "filled")
eq(RW.Expand("hi %t at %z"), "hi  at Elwynn", "token expand without target")
_TARGET = "Dora"; eq(RW.Expand("hi %t"), "hi Dora", "token expand target")
_SENT, _EMOTES = {}, {}
RW.Execute({ text = "gg", emote = "CLAP" }, { dest = "PARTY" }, S)
eq(#_SENT, 1, "sent"); eq(_SENT[1][2], "PARTY", "channel"); eq(_EMOTES[1], "CLAP", "emote played")
RW.Execute({ text = "ty", emote = "THANK" }, { dest = "WHISPER", target = "Bob" }, S)
eq(_SENT[2][3], "Bob", "whisper target"); eq(#_EMOTES, 1, "no emote on whisper")

_SENT, _PREFILL = {}, {}
RW.Execute({ text = "hi", emote = "WAVE" }, { dest = "SAY" }, S)
eq(#_SENT, 1, "say sent directly by default"); eq(#_PREFILL, 0, "no prefill when not blocked")
-- simulate the game blocking the send: SendChatMessage raises ADDON_ACTION_* synchronously
local realSend = SendChatMessage
SendChatMessage = function() RW.OnActionBlocked("ReactWheel", "SendChatMessage()") end
RW.Execute({ text = "yo" }, { dest = "SAY" }, S)
eq(_PREFILL[1], "/s yo", "blocked say falls back to chat box")
RW.OnActionBlocked("OtherAddon", "SendChatMessage()"); eq(#_PREFILL, 1, "other addons ignored")
SendChatMessage = realSend
S.sayMode = "prefill"; RW.Execute({ text = "hi2" }, { dest = "SAY" }, S)
eq(_PREFILL[2], "/s hi2", "prefill mode"); S.sayMode = "direct"

-- UI smoke test (stubbed frames): open, page, close, activate
RW.OpenWheel()
RW.PageWheel(1); eq(RW.P().current, "dungeon", "paged forward")
RW.PageWheel(-1); eq(RW.P().current, "quick", "paged back")
Tg.ctx = {}; _SENT = {}
RW.Activate(4, "LeftButton", false, false)  -- LOL; solo, nothing heard -> low confidence, only 1-2 alts
RW.BindingUp(); RW.BindingDown(); RW.BindingDown()
_COMBAT = true; _PRINTED[#_PRINTED] = nil
RW.EditSlot("quick", 1)
eq(string.find(_PRINTED[#_PRINTED] or "", "combat") ~= nil, true, "edit locked in combat")
_COMBAT = false
SlashCmdList.REACTWHEEL("wheel social"); eq(RW.P().current, "social", "slash wheel")
SlashCmdList.REACTWHEEL("size font 2"); eq(RW.P().settings.fontScale, 2, "font scale set")
SlashCmdList.REACTWHEEL("size hub 9"); eq(RW.P().settings.hubScale, 2.5, "hub scale clamped")
SlashCmdList.REACTWHEEL("size buttons 80"); eq(RW.P().settings.buttonSize, 80, "button size")
RW.OpenWheel(); RW.PageWheel(1); RW.CloseWheel()
SlashCmdList.REACTWHEEL("size font 1"); SlashCmdList.REACTWHEEL("size hub 1"); SlashCmdList.REACTWHEEL("size buttons 56")
SlashCmdList.REACTWHEEL("debug"); SlashCmdList.REACTWHEEL("help")

print(string.format("%d checks, %d failed", total, fails))
if fails > 0 then error("tests failed") end
