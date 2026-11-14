-- ReactWheel: radial quick-reaction menu for chat replies.
-- Written in Lua 5.0-compatible style (classic-era clients); also runs on newer clients.

BINDING_HEADER_REACTWHEEL = "ReactWheel"
BINDING_NAME_REACTWHEEL_SHOW = "Reaction wheel (hold)"
BINDING_NAME_HEADER_REACTWHEEL = "ReactWheel" -- some clients look the header up as a binding name

local DEFAULTS = { "{up}", "{down}", "LOL", "GG", "thx!", "<3", "brb", "?!" }
local DB_VERSION = 2
-- Icon slots: drawn as a picture on the wheel; the chat text sent is shown here.
local ICONS = {
	["{up}"]   = { tex = "Interface\\AddOns\\ReactWheel\\Textures\\ThumbsUp",   r = 0.3, g = 1,   b = 0.3, send = "+1" },
	["{down}"] = { tex = "Interface\\AddOns\\ReactWheel\\Textures\\ThumbsDown", r = 1,   g = 0.3, b = 0.3, send = "-1" },
}

local function Resolve(r)
	local ic = ICONS[r]
	if not ic then return r end
	local o = ReactWheelDB and ((r == "{up}" and ReactWheelDB.upText) or (r == "{down}" and ReactWheelDB.downText))
	return o or ic.send
end

local function Face(b, r)
	local ic = ICONS[r]
	if ic then
		b.icon:SetTexture(ic.tex)
		b.icon:SetVertexColor(ic.r, ic.g, ic.b)
		b.icon:Show()
		b.text:SetText("")
	else
		b.icon:Hide()
		b.text:SetText(r)
	end
end
local RADIUS, DEADZONE, BTN = 110, 35, 64

local wheel, buttons, selected = nil, {}, nil
local reply = nil -- { type=, target= } of the last incoming message

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99ReactWheel:|r " .. msg)
end

local function Reactions()
	ReactWheelDB = ReactWheelDB or {}
	if ReactWheelDB.ver ~= DB_VERSION then
		ReactWheelDB.reactions = nil -- defaults changed (thumbs up/down)
		ReactWheelDB.ver = DB_VERSION
	end
	if not ReactWheelDB.reactions then
		ReactWheelDB.reactions = {}
		for i = 1, 8 do ReactWheelDB.reactions[i] = DEFAULTS[i] end
	end
	return ReactWheelDB.reactions
end

-- Pick where the reaction goes: last incoming chat context, else group, else /say.
local function Destination()
	if reply then return reply.type, reply.target end
	if (GetNumRaidMembers and GetNumRaidMembers() > 0) or (IsInRaid and IsInRaid()) then return "RAID" end
	if (GetNumPartyMembers and GetNumPartyMembers() > 0) or (IsInGroup and IsInGroup()) then return "PARTY" end
	return "SAY"
end

local function Send(text)
	local t, target = Destination()
	if t == "WHISPER" then
		SendChatMessage(text, "WHISPER", nil, target)
	else
		SendChatMessage(text, t)
	end
end

local function Select(i)
	selected = i
	for n = 1, 8 do
		if buttons[n] then
			if n == i then buttons[n].hl:Show() else buttons[n].hl:Hide() end
		end
	end
	if wheel then
		local t, target = Destination()
		wheel.dest:SetText("-> " .. t .. (target and (" " .. target) or ""))
	end
end

local function KeyBase(k)
	if not k then return nil end
	local _, _, base = string.find(k, "([^%-]+)$")
	return string.upper(base or k)
end

local function IsWheelKey(k)
	local k1, k2 = GetBindingKey("REACTWHEEL_SHOW")
	k = KeyBase(k)
	return k and (k == KeyBase(k1) or k == KeyBase(k2))
end

-- True when the wheel key is a mouse button (no keyboard key-up to listen for).
local function BoundToMouse()
	local k1, k2 = GetBindingKey("REACTWHEEL_SHOW")
	local a, b = KeyBase(k1), KeyBase(k2)
	return (a and string.find(a, "BUTTON")) or (b and string.find(b, "BUTTON"))
end

local function Build()
	wheel = CreateFrame("Frame", "ReactWheelFrame", UIParent)
	wheel:SetWidth(RADIUS * 2 + BTN)
	wheel:SetHeight(RADIUS * 2 + BTN)
	wheel:SetFrameStrata("DIALOG")
	wheel:Hide()

	wheel.dest = wheel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	wheel.dest:SetPoint("CENTER", wheel, "CENTER", 0, 0)

	local reactions = Reactions()
	for i = 1, 8 do
		local ang = math.pi / 2 - (i - 1) * (math.pi / 4) -- start at top, go clockwise
		local b = CreateFrame("Button", "ReactWheelBtn" .. i, wheel)
		b:SetWidth(BTN)
		b:SetHeight(BTN)
		b:SetPoint("CENTER", wheel, "CENTER", math.cos(ang) * RADIUS, math.sin(ang) * RADIUS)
		b.bg = b:CreateTexture(nil, "BACKGROUND")
		b.bg:SetAllPoints(b)
		b.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
		b.bg:SetVertexColor(0, 0, 0, 0.7)
		b.hl = b:CreateTexture(nil, "ARTWORK")
		b.hl:SetAllPoints(b)
		b.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
		b.hl:SetVertexColor(0.2, 0.6, 1, 0.6)
		b.hl:Hide()
		b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
		b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
		b.icon = b:CreateTexture(nil, "OVERLAY")
		b.icon:SetWidth(44)
		b.icon:SetHeight(44)
		b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
		Face(b, reactions[i])
		b.index = i
		b:SetScript("OnClick", function()
			local self = this or b
			Send(Resolve(Reactions()[self.index]))
			wheel:Hide()
		end)
		buttons[i] = b
	end

	-- Release is detected on the frame itself: a key-up here counts as a real hardware
	-- event, which the game requires for sending SAY/etc. (binding key-up does not).
	wheel:EnableKeyboard(true)
	if wheel.SetPropagateKeyboardInput then wheel:SetPropagateKeyboardInput(true) end
	wheel:SetScript("OnKeyUp", function(f, k)
		if IsWheelKey(k or arg1) then ReactWheel_Release() end
	end)

	wheel:SetScript("OnUpdate", function()
		local cx, cy = wheel:GetCenter()
		local s = wheel:GetEffectiveScale()
		local mx, my = GetCursorPosition()
		local dx, dy = mx / s - cx, my / s - cy
		if dx * dx + dy * dy < DEADZONE * DEADZONE then
			if selected then Select(nil) end
			return
		end
		-- angle clockwise from top, 0..2pi
		local a = math.atan2(dx, dy)
		if a < 0 then a = a + 2 * math.pi end
		local i = math.floor(a / (math.pi / 4) + 0.5) + 1
		if i > 8 then i = 1 end
		if i ~= selected then Select(i) end
	end)
end

function ReactWheel_Open()
	if not wheel then Build() end
	local s = UIParent:GetEffectiveScale()
	local x, y = GetCursorPosition()
	wheel:ClearAllPoints()
	wheel:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s)
	selected = nil
	Select(nil)
	wheel:Show()
end

function ReactWheel_Release(fromBinding)
	if not wheel or not wheel:IsVisible() then return end
	if fromBinding and not BoundToMouse() then return end -- keyboard keys are handled by OnKeyUp
	wheel:Hide()
	if selected then Send(Resolve(Reactions()[selected])) end
end

-- Track who to reply to.
local tracker = CreateFrame("Frame")
local EVENTS = {
	CHAT_MSG_WHISPER = "WHISPER", CHAT_MSG_PARTY = "PARTY", CHAT_MSG_PARTY_LEADER = "PARTY",
	CHAT_MSG_RAID = "RAID", CHAT_MSG_RAID_LEADER = "RAID", CHAT_MSG_SAY = "SAY",
}
for ev in pairs(EVENTS) do pcall(tracker.RegisterEvent, tracker, ev) end -- skip events this client lacks
tracker:RegisterEvent("VARIABLES_LOADED")
tracker:SetScript("OnEvent", function(self, e, a1, a2, a3, a4, a5, a6, a7, a8)
	local ev = e or event
	local msg, sender = a1 or arg1, a2 or arg2
	if ev == "VARIABLES_LOADED" then Reactions() return end
	local t = EVENTS[ev]
	if not t then return end
	if t == "WHISPER" then
		reply = { type = "WHISPER", target = sender }
	else
		reply = { type = t }
	end
end)

-- /rw set <1-8> <text> | /rw reset | /rw reply <whisper|party|raid|guild|say|auto>
SLASH_REACTWHEEL1 = "/rw"
SLASH_REACTWHEEL2 = "/reactwheel"
SlashCmdList["REACTWHEEL"] = function(msg)
	msg = msg or ""
	local _, _, cmd, rest = string.find(msg, "^(%S*)%s*(.-)$")
	if cmd == "set" then
		local _, _, n, text = string.find(rest, "^(%d)%s+(.+)$")
		n = tonumber(n)
		if n and n >= 1 and n <= 8 then
			Reactions()[n] = text
			if buttons[n] then Face(buttons[n], text) end
			Print("slot " .. n .. " = " .. text)
			return
		end
	elseif cmd == "up" or cmd == "down" then
		ReactWheelDB[cmd .. "Text"] = (rest ~= "" and rest) or nil
		Print("thumbs " .. cmd .. " now sends: " .. Resolve(cmd == "up" and "{up}" or "{down}"))
		return
	elseif cmd == "reset" then
		ReactWheelDB.reactions = nil
		Reactions()
		for i = 1, 8 do if buttons[i] then Face(buttons[i], Reactions()[i]) end end
		Print("reactions reset")
		return
	elseif cmd == "reply" then
		local m = string.upper(rest)
		if m == "AUTO" or m == "" then reply = nil
		elseif m == "PARTY" or m == "RAID" or m == "SAY" then reply = { type = m }
		else Print("only auto, party, raid or say") return end
		Print("reply target: " .. (reply and m or "auto"))
		return
	end
	Print("Bind a key in Key Bindings > ReactWheel; hold, flick, release.")
	Print("Slot text may be {up} or {down} for thumbs icons.")
	Print("/rw up <text> / /rw down <text>  change what the thumbs send (empty = +1 / -1)")
	Print("/rw set <1-8> <text>   /rw reset   /rw reply <auto|party|raid|say>")
end
