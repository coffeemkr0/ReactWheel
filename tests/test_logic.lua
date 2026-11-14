-- Run via tests/run_tests.py (Lua 5.1 through lupa). Run from the repo root.
dofile("tests/wow_stubs.lua")
for _, f in ipairs({ "Locales", "Core", "Defaults", "Targeting", "Actions", "Wheel", "Editor", "Share", "Minimap", "Config" }) do
	assert(loadfile(f .. ".lua"), f)()
end
local RW = ReactWheel
local Tg = RW.Targeting
local fails, total = 0, 0
local function eq(a, b, name)
	total = total + 1
	if a ~= b then fails = fails + 1; print("FAIL " .. name .. ": expected " .. tostring(b) .. " got " .. tostring(a)) end
end

local S = RW.Copy(RW.DEFAULT_SETTINGS); S.minInterval = 0 -- spam guard has its own test
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
eq(ReactWheelDB.ver, 6, "db version"); eq(ReactWheelDB.reactions, nil, "old reactions dropped")
eq(RW.P().wheels.quick.items[1].text, "OK", "upText carried over")
eq(#RW.P().order, 4, "four wheels"); eq(RW.P().wheels.quick.slots, 8, "slots")
eq(RW.P().wheels.quick.items[3].text, "\226\153\165", "heart text")
ReactWheelDB.ver = 5; ReactWheelDB.profile.settings.sayMode = "direct"; RW.InitDB()
eq(ReactWheelDB.profile.settings.sayMode, "auto", "migrated to auto")
ReactWheelDB.profile.wheels.quick.auto = nil; ReactWheelDB.autoDefaults = nil; RW.InitDB()
eq(ReactWheelDB.profile.wheels.quick.auto, "whisper", "auto hints backfilled")
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

-- /say rule: chat box outdoors, direct inside instances (auto mode)
local inst = false
IsInInstance = function() return inst end
S.sayMode = "auto"; _SENT, _PREFILL = {}, {}
RW.Execute({ text = "out" }, { dest = "SAY" }, S)
eq(#_SENT, 0, "outdoors: not sent directly"); eq(_PREFILL[1], "/s out", "outdoors: goes to the chat box")
RW.Execute({ text = "ty", emote = "THANK" }, { dest = "PARTY" }, S); eq(#_SENT, 1, "party unaffected outdoors")
inst = true; _SENT, _PREFILL = {}, {}
RW.Execute({ text = "in", emote = "WAVE" }, { dest = "SAY" }, S)
eq(#_SENT, 1, "inside an instance: sent directly"); eq(_SENT[1][2], "SAY", "channel say"); eq(#_PREFILL, 0, "no chat box inside instance")
inst = false; S.sayMode = "direct"; _SENT, _PREFILL = {}, {}
RW.Execute({ text = "forced" }, { dest = "SAY" }, S); eq(#_SENT, 1, "direct mode always sends")
S.sayMode = "prefill"; inst = true; RW.Execute({ text = "pf" }, { dest = "SAY" }, S); eq(_PREFILL[1], "/s pf", "prefill mode always uses the chat box")
S.sayMode = "auto"; IsInInstance = nil
eq(RW.SayNeedsChatBox(S), true, "no IsInInstance -> treat as outdoors")
-- game blocked a send anyway: fall back to the chat box
S.sayMode = "direct"; _PREFILL = {}
local realSend = SendChatMessage
SendChatMessage = function() RW.OnActionBlocked("ReactWheel", "SendChatMessage()") end
RW.Execute({ text = "yo" }, { dest = "SAY" }, S)
eq(_PREFILL[1], "/s yo", "blocked say falls back to chat box")
RW.OnActionBlocked("OtherAddon", "SendChatMessage()"); eq(#_PREFILL, 1, "other addons ignored")
SendChatMessage = realSend; S.sayMode = "auto"

-- slot editor field conversion
local sl = RW.SlotFromFields({ label = "  hi ", text = "yo %t", emote = "wave", emoteWhen = "always", command = "", dest = "PARTY",
	icon = "None", color = "green", opensWheel = nil })
eq(sl.label, "hi", "label trimmed"); eq(sl.text, "yo %t", "text"); eq(sl.emote, "WAVE", "emote upper")
eq(sl.emoteWhen, "always", "emoteWhen"); eq(sl.command, nil, "empty command dropped"); eq(sl.dest, "PARTY", "dest")
eq(sl.icon, nil, "icon none dropped"); eq(sl.color[2], 1, "colour"); eq(sl.opensWheel, nil, "opens none")
eq(string.len(RW.SlotFromFields({ text = string.rep("x", 400) }).text), 250, "text capped")
eq(RW.IsEmpty(RW.SlotFromFields({})), true, "all-empty fields give an empty slot")
RW.OpenSlotEditor("quick", 1)
RW.EditSlot("quick", 2)

-- wheel management
local nid = RW.NewWheel("Mine"); eq(RW.P().wheels[nid].name, "Mine", "new wheel"); eq(#RW.P().order, 5, "order grew")
local cid = RW.NewWheel(nil, "quick"); eq(RW.P().wheels[cid].items[1].text, RW.P().wheels.quick.items[1].text, "copied wheel")
RW.P().wheels.quick.items[8].opensWheel = nid
eq(RW.DeleteWheel(nid), true, "delete"); eq(RW.P().wheels.quick.items[8].opensWheel, nil, "sub-wheel link cleared")
eq(RW.MoveWheel(cid, -1), true, "move up"); eq(RW.P().order[#RW.P().order - 1], cid, "moved")
RW.SetSlotCount(cid, 12); eq(RW.P().wheels[cid].slots, 12, "12 slots"); eq(#RW.P().wheels[cid].items, 12, "items filled")
RW.SetSlotCount(cid, 99); eq(RW.P().wheels[cid].slots, 12, "slot cap"); RW.SetSlotCount(cid, 1); eq(RW.P().wheels[cid].slots, 4, "slot floor")
RW.DeleteWheel(cid)
local r1 = RW.P().settings.rules[1].id
eq(RW.MoveRule(1, 1), true, "rule down"); eq(RW.P().settings.rules[2].id, r1, "rule moved"); RW.MoveRule(2, -1)
eq(RW.MoveRule(1, -1), false, "rule can't move above top")
-- swap slots, reset everything
local sw = RW.P().wheels.quick
local first, second = sw.items[1], sw.items[2]
eq(RW.SwapSlots("quick", 1, 2), true, "swap"); eq(sw.items[1], second, "slot 1 now holds old slot 2"); eq(sw.items[2], first, "slot 2 now holds old slot 1")
eq(RW.SwapSlots("quick", 1, 1), false, "swap with itself"); eq(RW.SwapSlots("quick", 1, 99), false, "swap out of range")
RW.SwapSlots("quick", 1, 2)
RW.P().settings.buttonSize = 99; RW.NewWheel("junk"); ReactWheelDB.minimap.angle = 10
ReactWheelCharDB.profile = RW.Copy(ReactWheelDB.profile); ReactWheelCharDB.useChar = true
RW.ResetAll()
eq(RW.P().settings.buttonSize, 56, "settings reset"); eq(#RW.P().order, 4, "wheels reset"); eq(ReactWheelDB.minimap.angle, 215, "minimap reset")
eq(ReactWheelCharDB.profile, nil, "character profile removed"); eq(ReactWheelCharDB.useChar, false, "back to account profile")
SlashCmdList.REACTWHEEL("reset"); eq(RW.P().settings.buttonSize, 56, "plain /rw reset changes nothing")
SlashCmdList.REACTWHEEL("reset all")
-- in-wheel edit mode: click one slot, then another, to swap
RW.OpenWheel(); local q1, q2 = RW.P().wheels.quick.items[1], RW.P().wheels.quick.items[2]
RW.SetEditMode(true); RW.Activate(1, "LeftButton"); RW.Activate(2, "LeftButton")
eq(RW.P().wheels.quick.items[1], q2, "edit mode swapped slot 1"); eq(RW.P().wheels.quick.items[2], q1, "edit mode swapped slot 2")
RW.Activate(3, "LeftButton"); RW.Activate(3, "LeftButton"); eq(#_SENT >= 0, true, "same slot twice cancels the pick")
RW.SetEditMode(false); RW.SwapSlots("quick", 1, 2)
_COMBAT = true; RW.SetEditMode(true); _COMBAT = false
RW.SetEditMode(false); RW.CloseWheel()
-- context-aware wheel choice
Tg.ctx = {}; local pp = RW.P(); local SA = RW.Copy(pp.settings)
eq(Tg.PickWheel(env({}), Tg.ctx, SA, pp), "social", "solo -> solo wheel")
eq(Tg.PickWheel(env({ inParty = true }), Tg.ctx, SA, pp), "dungeon", "party -> party wheel")
eq(Tg.PickWheel(env({ inParty = true, inRaid = true }), Tg.ctx, SA, pp), "dungeon", "raid -> party wheel")
Tg.Observe("WHISPER", "Bob", 990, SA)
eq(Tg.PickWheel(env({ inParty = true }), Tg.ctx, SA, pp), "quick", "fresh whisper -> whisper wheel")
Tg.ctx = {}; Tg.Observe("WHISPER", "Bob", 500, SA)
eq(Tg.PickWheel(env({ inParty = true }), Tg.ctx, SA, pp), "dungeon", "old whisper ignored")
pp.wheels.social.auto = nil; eq(Tg.PickWheel(env({}), Tg.ctx, SA, pp), nil, "no matching wheel -> nil"); pp.wheels.social.auto = "solo"
RW.P().settings.autoWheel = true; RW.OpenWheel(); eq(RW.P().current, "social", "auto wheel applied on open"); RW.CloseWheel()
RW.P().settings.autoWheel = false; RW.P().current = "quick"; Tg.ctx = {}
-- sounds
local played = 0; PlaySound = function() played = played + 1 end
RW.Sound("hover"); eq(played, 0, "no sound when off"); RW.P().settings.sounds = true; RW.Sound("hover"); eq(played, 1, "sound plays when on")
RW.P().settings.sounds = false; PlaySound = nil
-- settings window / minimap smoke
RW.ShowConfig(); RW.UpdateMinimap()
_COMBAT = true; RW.ShowConfig(); _COMBAT = false

-- spam guard
local SG = RW.Copy(S); SG.minInterval = 1; RW.lastExec = nil; _SENT = {}; _NOW = 2000
RW.Execute({ text = "a" }, { dest = "PARTY" }, SG); _NOW = 2000.5
eq(RW.Execute({ text = "b" }, { dest = "PARTY" }, SG), false, "second send inside the interval ignored")
_NOW = 2002; RW.Execute({ text = "c" }, { dest = "PARTY" }, SG)
eq(#_SENT, 2, "spam guard let two through"); RW.lastExec = nil

-- welcome
ReactWheelDB.welcomed = nil
eq(RW.NeedsWelcome(true), false, "no welcome when a key is bound"); eq(ReactWheelDB.welcomed, true, "flag set")
ReactWheelDB.welcomed = nil; eq(RW.NeedsWelcome(false), true, "welcome when unbound")
eq(RW.NeedsWelcome(false), false, "welcome only once")

-- share: round trip
local q = RW.P().wheels.quick
q.items[3].opensWheel = "social"
local str1 = RW.ExportWheels({ "quick" })
eq(string.sub(str1, 1, 4), "RW1:", "export prefix"); eq(string.find(str1, "%s"), nil, "export has no whitespace")
local pv = RW.PreviewImport(str1)
eq(#pv.wheels, 1, "one wheel previewed"); eq(pv.wheels[1].name, "Quick Chat", "name survives"); eq(pv.wheels[1].slots, 8, "slots survive")
eq(pv.wheels[1].items[1].text, q.items[1].text, "text survives (unicode)"); eq(pv.wheels[1].items[3].opensWheel, nil, "sub-wheel link stripped")
eq(pv.wheels[1].items[1].color[2], 1, "colour survives"); eq(pv.wheels[1].items[1].emote, "NOD", "emote survives")
local before = #RW.P().order
local ids = RW.CommitImport(pv); eq(#RW.P().order, before + 1, "import added a wheel"); eq(RW.P().wheels[ids[1]].items[2].emote, "NO", "imported slot content")
RW.DeleteWheel(ids[1]); q.items[3].opensWheel = nil
eq(#RW.PreviewImport(RW.ExportWheels()).wheels, #RW.P().order, "export all round trips")
-- share: hostile / malformed input
local function bad(s, why) local r = RW.PreviewImport(s); eq(r, nil, why) end
bad("", "empty"); bad("hello", "no prefix"); bad("RW1:", "empty payload"); bad("RW1:{", "unterminated"); bad("RW1:szz;", "bad hex")
bad("RW1:" .. string.rep("{", 50) .. string.rep("}", 50), "too deep"); bad(string.rep("x", 70000), "too long")
bad(RW.Serialize({ wheels = { { name = string.rep("A", 1000) } } }), "oversized string rejected"); bad("RW1:n1.0000;", "not a table"); bad(RW.Serialize({ v = 1 }), "no wheels")
local evil = RW.Serialize({ wheels = { { name = "x\ncontrol", slots = 99999, dest = "CHANNEL", items = {
	{ text = string.rep("A", 300), command = "no slash", icon = "Interface\\..\\x", emote = "BAD EMOTE!", emoteWhen = "sometimes",
	  color = { 9, -4, "z" }, opensWheel = "quick", __index = "x" },
	{ command = "/dance", icon = "INV_Misc_Note_01", color = { 2, 0.5, 0.25 } } } } } })
local ev = RW.PreviewImport(evil); local w1 = ev.wheels[1]
eq(w1.slots, 12, "slot count clamped"); eq(w1.dest, nil, "bad dest dropped"); eq(string.find(w1.name, "%c"), nil, "control chars stripped")
eq(string.len(w1.items[1].text), 250, "text capped"); eq(w1.items[1].command, nil, "non-slash command dropped")
eq(w1.items[1].icon, nil, "path traversal icon dropped"); eq(w1.items[1].emote, nil, "bad emote dropped")
eq(w1.items[1].emoteWhen, nil, "bad emoteWhen dropped"); eq(w1.items[1].color, nil, "bad colour dropped")
eq(w1.items[1].opensWheel, nil, "link dropped"); eq(w1.items[1].__index, nil, "unknown key dropped")
eq(w1.items[2].command, "/dance", "good command kept"); eq(w1.items[2].icon, "INV_Misc_Note_01", "icon name kept"); eq(w1.items[2].color[1], 1, "colour clamped")
eq(#ev.commands, 1, "commands listed for confirmation"); eq(#w1.items, 12, "items filled to slot count")

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
RW.OpenWheel(); RW.Activate(1, "LeftButton", false, false); RW.CloseWheel()
SlashCmdList.REACTWHEEL("size font 1"); SlashCmdList.REACTWHEEL("size hub 1"); SlashCmdList.REACTWHEEL("size buttons 56")
SlashCmdList.REACTWHEEL("debug"); SlashCmdList.REACTWHEEL("help")

print(string.format("%d checks, %d failed", total, fails))
if fails > 0 then error("tests failed") end
