-- ReactWheel: radial quick-reaction menu for chat replies.
-- Written in Lua 5.0-compatible style (classic-era clients); also runs on newer clients.

BINDING_HEADER_REACTWHEEL = "ReactWheel"
BINDING_NAME_REACTWHEEL_SHOW = "Reaction wheel (hold)"
BINDING_NAME_HEADER_REACTWHEEL = "ReactWheel" -- some clients look the header up as a binding name

local DEFAULTS = { "+1", "LOL", "GG", "thx!", "<3", "brb", "o7", "?!" }
local RADIUS, DEADZONE, BTN = 110, 35, 64

local wheel, buttons, selected = nil, {}, nil
local reply = nil -- { type=, target= } of the last incoming message

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99ReactWheel:|r " .. msg)
end

local function Reactions()
	ReactWheelDB = ReactWheelDB or {}
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
		b.text:SetText(reactions[i])
		b.index = i
		b:SetScript("OnClick", function()
			local self = this or b
			Send(Reactions()[self.index])
			wheel:Hide()
		end)
		buttons[i] = b
	end

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

function ReactWheel_Release()
	if not wheel or not wheel:IsVisible() then return end
	wheel:Hide()
	if selected then Send(Reactions()[selected]) end
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
			if buttons[n] then buttons[n].text:SetText(text) end
			Print("slot " .. n .. " = " .. text)
			return
		end
	elseif cmd == "reset" then
		ReactWheelDB.reactions = nil
		Reactions()
		for i = 1, 8 do if buttons[i] then buttons[i].text:SetText(Reactions()[i]) end end
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
	Print("/rw set <1-8> <text>   /rw reset   /rw reply <auto|party|raid|say>")
end
