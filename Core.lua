-- Core: namespace, saved variables, profiles, chat observation, slash commands.
ReactWheel = ReactWheel or {}
local RW = ReactWheel

RW.DB_VERSION = 5
RW.debug = false
RW.sayUnlocked = false -- becomes true once /say has gone out this session (see Actions.lua)

function RW.Print(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99ReactWheel:|r " .. tostring(msg))
	end
end

function RW.Copy(v)
	if type(v) ~= "table" then return v end
	local t = {}
	for k, x in pairs(v) do t[k] = RW.Copy(x) end
	return t
end

-- Fill keys missing from dst with copies from src (recursing into non-array tables).
local function fill(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then
			dst[k] = RW.Copy(v)
		elseif type(v) == "table" and type(dst[k]) == "table" and v[1] == nil then
			fill(dst[k], v)
		end
	end
end
RW.FillDefaults = fill

function RW.BaseName(n)
	if not n then return nil end
	return string.match(n, "^([^%-]+)") or n
end

function RW.InCombat()
	if InCombatLockdown and InCombatLockdown() then return true end
	return UnitAffectingCombat and UnitAffectingCombat("player") and true or false
end

---------------------------------------------------------------------------
-- Profiles: account-wide by default, optional per-character copy.
---------------------------------------------------------------------------
function RW.NewProfile()
	local wheels, order = RW.DefaultWheels()
	return { wheels = wheels, order = order, current = order[1], settings = RW.Copy(RW.DEFAULT_SETTINGS) }
end

function RW.P()
	if ReactWheelCharDB and ReactWheelCharDB.useChar and ReactWheelCharDB.profile then
		return ReactWheelCharDB.profile
	end
	return ReactWheelDB.profile
end

local function Sanitize(p)
	fill(p.settings, RW.DEFAULT_SETTINGS)
	if not p.wheels[p.current] then p.current = p.order[1] end
	for _, w in pairs(p.wheels) do
		w.items = w.items or {}
		w.slots = math.max(4, math.min(12, w.slots or 8))
	end
end

---------------------------------------------------------------------------
-- Wheel management (used by the settings window)
---------------------------------------------------------------------------
function RW.NewWheel(name, copyFrom)
	local p = RW.P()
	local n = 1
	while p.wheels["w" .. n] do n = n + 1 end
	local id = "w" .. n
	if copyFrom and p.wheels[copyFrom] then
		p.wheels[id] = RW.Copy(p.wheels[copyFrom])
		p.wheels[id].name = name or (p.wheels[copyFrom].name .. " copy")
	else
		p.wheels[id] = { name = name or "New wheel", slots = 8, items = {} }
	end
	p.order[#p.order + 1] = id
	return id
end

function RW.DeleteWheel(id)
	local p = RW.P()
	if #p.order <= 1 or not p.wheels[id] then return false end
	p.wheels[id] = nil
	for i, w in ipairs(p.order) do if w == id then table.remove(p.order, i) break end end
	for _, w in pairs(p.wheels) do
		for _, s in pairs(w.items) do if s.opensWheel == id then s.opensWheel = nil end end
	end
	if p.current == id then p.current = p.order[1] end
	return true
end

function RW.MoveWheel(id, delta)
	local o = RW.P().order
	for i, w in ipairs(o) do
		if w == id then
			local j = i + delta
			if j < 1 or j > #o then return false end
			o[i], o[j] = o[j], o[i]
			return true
		end
	end
	return false
end

function RW.SetSlotCount(id, n)
	local w = RW.P().wheels[id]
	if not w then return end
	w.slots = math.max(4, math.min(12, math.floor(n + 0.5)))
	for i = 1, w.slots do w.items[i] = w.items[i] or {} end
end

function RW.SwapSlots(id, a, b)
	local w = RW.P().wheels[id]
	if not w or a == b or a < 1 or b < 1 or a > w.slots or b > w.slots then return false end
	w.items[a] = w.items[a] or {}
	w.items[b] = w.items[b] or {}
	w.items[a], w.items[b] = w.items[b], w.items[a]
	return true
end

-- Put everything back to factory state: all wheels and settings, this character's own copy, minimap position.
function RW.ResetAll()
	ReactWheelDB.profile = RW.NewProfile()
	ReactWheelDB.minimap = { hide = false, angle = 215 }
	ReactWheelCharDB.profile = nil
	ReactWheelCharDB.useChar = false
	RW.Targeting.ctx = {}
end

function RW.MoveRule(index, delta)
	local r = RW.P().settings.rules
	local j = index + delta
	if j < 1 or j > #r then return false end
	r[index], r[j] = r[j], r[index]
	return true
end

function RW.InitDB()
	ReactWheelDB = ReactWheelDB or {}
	ReactWheelCharDB = ReactWheelCharDB or {}
	local db = ReactWheelDB
	db.minimap = db.minimap or { hide = false, angle = 215 }
	if not db.profile then
		local p = RW.NewProfile()
		-- carry over customised thumbs text from the pre-1.0 versions
		if db.upText then p.wheels.quick.items[1].text = db.upText end
		if db.downText then p.wheels.quick.items[2].text = db.downText end
		db.profile = p
	end
	db.reactions, db.upText, db.downText = nil, nil, nil
	if (db.ver or 0) < 5 then
		-- v5: direct sending (with block fallback) is the default again
		local function fix(p) if p and p.settings then p.settings.sayMode = "direct" end end
		fix(db.profile); fix(ReactWheelCharDB.profile)
	end
	db.ver = RW.DB_VERSION
	Sanitize(db.profile)
	if ReactWheelCharDB.profile then Sanitize(ReactWheelCharDB.profile) end
end

---------------------------------------------------------------------------
-- Chat observation (feeds the targeting engine). Numbered channels are ignored.
---------------------------------------------------------------------------
local OBSERVED = {
	CHAT_MSG_WHISPER = "WHISPER",
	CHAT_MSG_PARTY = "GROUP", CHAT_MSG_PARTY_LEADER = "GROUP",
	CHAT_MSG_RAID = "GROUP", CHAT_MSG_RAID_LEADER = "GROUP",
	CHAT_MSG_INSTANCE_CHAT = "GROUP", CHAT_MSG_INSTANCE_CHAT_LEADER = "GROUP",
	CHAT_MSG_BATTLEGROUND = "GROUP", CHAT_MSG_BATTLEGROUND_LEADER = "GROUP",
	CHAT_MSG_GUILD = "GUILD",
	CHAT_MSG_SAY = "SAY",
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("VARIABLES_LOADED")
for _, ev in ipairs({ "ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED" }) do pcall(frame.RegisterEvent, frame, ev) end
for ev in pairs(OBSERVED) do pcall(frame.RegisterEvent, frame, ev) end -- skip events this client lacks
RW.OnEvent = function(_, event, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12)
	if event == "VARIABLES_LOADED" then RW.InitDB() return end
	if event == "ADDON_ACTION_FORBIDDEN" or event == "ADDON_ACTION_BLOCKED" then RW.OnActionBlocked(a1, a2) return end
	local kind = OBSERVED[event]
	if not kind or not ReactWheelDB or not ReactWheelDB.profile then return end
	if event == "CHAT_MSG_SAY" and not RW.sayUnlocked then
		-- the game accepts our /say once a /say has gone out this session; recognise ours by sender, by GUID,
		-- or by the exact line we put in the chat box
		local mine = RW.BaseName(a2) == UnitName("player") or (a12 and UnitGUID and a12 == UnitGUID("player"))
		local pf = RW.lastPrefill
		if mine or (pf and a1 == pf.text and GetTime() - pf.time < 300) then RW.sayUnlocked = true end
	end
	if RW.BaseName(a2) == UnitName("player") then return end -- our own messages say nothing about who to answer
	RW.Targeting.Observe(kind, a2, GetTime(), RW.P().settings)
end
frame:SetScript("OnEvent", RW.OnEvent)

---------------------------------------------------------------------------
-- First-run welcome: shown once, only when the wheel has no key bound yet.
---------------------------------------------------------------------------
function RW.NeedsWelcome(hasBinding)
	if ReactWheelDB.welcomed then return false end
	ReactWheelDB.welcomed = true -- never nag twice, whatever the answer
	return not hasBinding
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function Help()
	RW.Print("Bind a key under Key Bindings > ReactWheel, then press it to open the wheel.")
	RW.Print("Left-click a slice to send it, right-click to edit it, Esc to close. Scroll to change wheels.")
	RW.Print("/rw config | /rw wheel <name or number> | /rw profile <account|char> | /rw say <prefill|direct> | /rw size | /rw debug | /rw reset")
end

function RW.OpenConfig()
	if RW.ShowConfig then RW.ShowConfig() else RW.Print("The settings window arrives in the next update.") end
end

SLASH_REACTWHEEL1 = "/rw"
SLASH_REACTWHEEL2 = "/reactwheel"
SlashCmdList["REACTWHEEL"] = function(msg)
	local cmd, rest = string.match(msg or "", "^(%S*)%s*(.-)$")
	cmd = string.lower(cmd or "")
	if cmd == "" or cmd == "config" then
		RW.OpenConfig()
	elseif cmd == "wheel" then
		local p = RW.P()
		local id = p.wheels[rest] and rest
		if not id then
			local n = tonumber(rest)
			if n and p.order[n] then id = p.order[n] end
		end
		if not id then
			for _, wid in ipairs(p.order) do
				if string.lower(p.wheels[wid].name) == string.lower(rest) then id = wid end
			end
		end
		if id then RW.OpenWheel(id) else RW.Print("No wheel called '" .. rest .. "'.") end
	elseif cmd == "profile" then
		rest = string.lower(rest)
		if rest == "char" or rest == "character" then
			if not ReactWheelCharDB.profile then ReactWheelCharDB.profile = RW.Copy(ReactWheelDB.profile) end
			ReactWheelCharDB.useChar = true
			RW.Print("This character now uses its own wheels.")
		elseif rest == "account" then
			ReactWheelCharDB.useChar = false
			RW.Print("This character now uses the account-wide wheels.")
		else
			RW.Print("Using " .. ((ReactWheelCharDB.useChar and "character") or "account-wide") .. " wheels. /rw profile <account|char>")
		end
	elseif cmd == "debug" then
		RW.debug = not RW.debug
		RW.Print("debug " .. (RW.debug and "on" or "off"))
		if RW.debug then
			local d = RW.Targeting.Decide(RW.Targeting.Env(), RW.Targeting.ctx, RW.P().settings)
			RW.Print("direct /say unlocked: " .. tostring(RW.sayUnlocked))
			RW.Print("would send to: " .. d.label .. " (" .. d.reason .. ", confidence " .. d.confidence .. ")")
		end
	elseif cmd == "size" then
		-- /rw size buttons|font|hub <number>
		local what, num = string.match(rest, "^(%a+)%s+([%d%.]+)$")
		num = tonumber(num)
		local S = RW.P().settings
		local map = { buttons = { "buttonSize", 40, 110 }, font = { "fontScale", 0.7, 2.5 }, hub = { "hubScale", 0.8, 2.5 } }
		local m = what and map[what]
		if m and num then
			S[m[1]] = math.max(m[2], math.min(m[3], num))
			RW.Print(what .. " = " .. S[m[1]])
			if RW.RefreshWheel then RW.RefreshWheel() end
		else
			RW.Print("/rw size buttons <40-110> | font <0.7-2.5> | hub <0.8-2.5>   (now " ..
				S.buttonSize .. " / " .. S.fontScale .. " / " .. S.hubScale .. ")")
		end
	elseif cmd == "say" then
		rest = string.lower(rest)
		if rest == "direct" or rest == "prefill" then
			RW.P().settings.sayMode = rest
			RW.Print("say mode: " .. rest)
		else
			RW.Print("say mode is '" .. RW.P().settings.sayMode .. "'. /rw say <prefill|direct>")
		end
	elseif cmd == "reset" then
		if string.lower(rest) == "all" then
			RW.ResetAll()
			if RW.UpdateMinimap then RW.UpdateMinimap() end
			RW.Print("Everything reset to defaults.")
		else
			RW.Print("This resets ALL wheels and settings. Type /rw reset all to confirm.")
		end
	else
		Help()
	end
end
