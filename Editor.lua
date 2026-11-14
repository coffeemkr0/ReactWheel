-- Editor: the popup for customizing one slot (opened by right-clicking a slice).
ReactWheel = ReactWheel or {}
local RW = ReactWheel

local EMOTES = { "", "WAVE", "CHEER", "CLAP", "LAUGH", "THANK", "NOD", "NO", "YES", "LOVE", "KISS", "HUG", "BOW",
	"SALUTE", "DANCE", "FLEX", "CRY", "CONFUSED", "SORRY", "CHARGE", "OOM", "HEALME", "HELLO", "BYE", "WELCOME",
	"CONGRATULATE", "ROAR", "SHRUG", "POINT", "SMILE", "GRIN", "SIGH", "SLEEP", "VICTORY", "APPLAUD", "BEG",
	"BLUSH", "CHICKEN", "LISTEN", "RUDE", "SHY", "SURPRISED", "WINK", "TIRED", "TALK", "SALUTE" }

local EMOTE_WHEN = {
	{ nil, "Default (only where seen)" }, { "public", "Say / party / raid" }, { "always", "Always" }, { "never", "Never" },
}
local DESTS = {
	{ nil, "Wheel default" }, { "AUTO", "Smart reply" }, { "SAY", "Say" }, { "PARTY", "Party" },
	{ "RAID", "Raid" }, { "GUILD", "Guild" }, { "WHISPER_TARGET", "Whisper my target" },
}
local COLORS = {
	{ nil, "White" }, { "green", "Green" }, { "red", "Red" }, { "pink", "Pink" }, { "blue", "Blue" }, { "gold", "Gold" },
}
local COLOR_RGB = {
	green = { 0.3, 1, 0.3 }, red = { 1, 0.3, 0.3 }, pink = { 1, 0.4, 0.5 }, blue = { 0.4, 0.7, 1 }, gold = { 1, 0.82, 0.2 },
}

local function ColorName(rgb)
	if not rgb then return nil end
	for name, c in pairs(COLOR_RGB) do
		if math.abs(c[1] - rgb[1]) < 0.01 and math.abs(c[2] - rgb[2]) < 0.01 and math.abs(c[3] - rgb[3]) < 0.01 then return name end
	end
	return nil
end

local function Trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end

-- Turn the editor's field values into a slot table (pure; unit tested).
-- f = { label, text, emote, emoteWhen, command, dest, icon, color, opensWheel }
function RW.SlotFromFields(f, old)
	local s = {}
	local function put(k, v) if v ~= nil and v ~= "" then s[k] = v end end
	put("label", Trim(f.label))
	put("text", Trim(f.text))
	put("emote", string.upper(Trim(f.emote)))
	put("emoteWhen", f.emoteWhen)
	put("command", Trim(f.command))
	put("dest", f.dest)
	local icon = Trim(f.icon)
	if string.lower(icon) == "none" then icon = "" end
	put("icon", icon)
	if f.color and COLOR_RGB[f.color] then s.color = { COLOR_RGB[f.color][1], COLOR_RGB[f.color][2], COLOR_RGB[f.color][3] } end
	put("opensWheel", f.opensWheel)
	if string.len(s.text or "") > 250 then s.text = string.sub(s.text, 1, 250) end
	return s
end

local frame
local cur = { wheel = nil, idx = nil }

---------------------------------------------------------------------------
-- tiny widgets
---------------------------------------------------------------------------
local function Label(parent, text, y)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y)
	fs:SetText(text)
	return fs
end

local function Edit(parent, y, width)
	local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	e:SetWidth(width or 190)
	e:SetHeight(20)
	e:SetPoint("TOPLEFT", parent, "TOPLEFT", 150, y + 3)
	e:SetAutoFocus(false)
	e:SetMaxLetters(250)
	e:SetScript("OnEscapePressed", function() e:ClearFocus() end)
	e:SetScript("OnEnterPressed", function() e:ClearFocus() end)
	return e
end

-- Button that cycles through { {value, label}, ... } on left-click (right-click goes back).
local function Cycle(parent, y, options, width)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetWidth(width or 190)
	b:SetHeight(22)
	b:SetPoint("TOPLEFT", parent, "TOPLEFT", 150, y + 4)
	b.options, b.i = options, 1
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local function show() b:SetText(b.options[b.i][2]) end
	function b.Set(value)
		b.i = 1
		for i, o in ipairs(b.options) do if o[1] == value then b.i = i end end
		show()
	end
	function b.Get() return b.options[b.i][1] end
	b:SetScript("OnClick", function(_, button)
		local n = #b.options
		if button == "RightButton" then b.i = ((b.i - 2) % n) + 1 else b.i = (b.i % n) + 1 end
		show()
		if b.onChange then b.onChange() end
	end)
	show()
	return b
end

---------------------------------------------------------------------------
-- frame
---------------------------------------------------------------------------
local function Collect()
	return {
		label = frame.label:GetText(), text = frame.text:GetText(), emote = frame.emote:GetText(),
		emoteWhen = frame.emoteWhen.Get(), command = frame.command:GetText(), dest = frame.dest.Get(),
		icon = frame.icon:GetText(), color = frame.color.Get(), opensWheel = frame.opens.Get(),
	}
end

local function UpdatePreview()
	local icon = Trim(frame.icon:GetText())
	if icon == "" or string.lower(icon) == "none" then
		frame.preview:Hide()
		return
	end
	if not (string.find(icon, "\\", 1, true) or string.find(icon, "/", 1, true)) then icon = "Interface\\Icons\\" .. icon end
	frame.preview:SetTexture(icon)
	frame.preview:Show()
end

local function Fill(slot)
	slot = slot or {}
	frame.label:SetText(slot.label or "")
	frame.text:SetText(slot.text or "")
	frame.emote:SetText(slot.emote or "")
	frame.emoteWhen.Set(slot.emoteWhen)
	frame.command:SetText(slot.command or "")
	frame.dest.Set(slot.dest)
	frame.icon:SetText(slot.icon or "")
	frame.color.Set(ColorName(slot.color))
	frame.opens.Set(slot.opensWheel)
	UpdatePreview()
end

local function WheelOptions()
	local opts = { { nil, "(none - send a reaction)" } }
	local p = RW.P()
	for _, id in ipairs(p.order) do
		if id ~= cur.wheel then opts[#opts + 1] = { id, "Open: " .. p.wheels[id].name } end
	end
	return opts
end

local function Build()
	frame = CreateFrame("Frame", "ReactWheelEditor", UIParent)
	frame:SetWidth(360)
	frame:SetHeight(440)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function() frame:StartMoving() end)
	frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
	frame.bg = frame:CreateTexture(nil, "BACKGROUND")
	frame.bg:SetAllPoints(frame)
	frame.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
	frame.bg:SetVertexColor(0.05, 0.05, 0.09, 0.97)
	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.title:SetPoint("TOP", frame, "TOP", 0, -12)
	frame:Hide()
	tinsert(UISpecialFrames, "ReactWheelEditor")

	local x = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	x:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)

	local y = -42
	local function row(text) Label(frame, text, y - 4); local at = y; y = y - 32; return at end

	frame.label = Edit(frame, row("Label (on the wheel)"))
	frame.text = Edit(frame, row("Chat text"))
	frame.emote = Edit(frame, row("Emote"), 150)
	local ey = y + 32
	local pick = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	pick:SetWidth(36)
	pick:SetHeight(22)
	pick:SetPoint("TOPLEFT", frame, "TOPLEFT", 306, ey + 4)
	pick:SetText("...")
	pick:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	pick:SetScript("OnClick", function(_, button)
		local cur = string.upper(Trim(frame.emote:GetText()))
		local n, at = #EMOTES, 1
		for i, e in ipairs(EMOTES) do if e == cur then at = i end end
		at = (button == "RightButton") and ((at - 2) % n) + 1 or (at % n) + 1
		frame.emote:SetText(EMOTES[at])
	end)
	frame.emoteWhen = Cycle(frame, row("Play emote when"), EMOTE_WHEN)
	frame.command = Edit(frame, row("Slash command (instead)"))
	frame.dest = Cycle(frame, row("Send to"), DESTS)
	frame.icon = Edit(frame, row("Icon (name/path)"), 150)
	frame.preview = frame:CreateTexture(nil, "ARTWORK")
	frame.preview:SetWidth(24)
	frame.preview:SetHeight(24)
	frame.preview:SetPoint("TOPLEFT", frame, "TOPLEFT", 312, y + 32 - 1)
	frame.icon:SetScript("OnTextChanged", function() UpdatePreview() end)
	frame.color = Cycle(frame, row("Colour"), COLORS)
	frame.opens = Cycle(frame, row("Opens another wheel"), { { nil, "(none)" } })

	local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, y + 6)
	hint:SetWidth(328)
	hint:SetJustifyH("LEFT")
	hint:SetText("Tokens in text: %t target, %p you, %z zone. Click a selector to change it (right-click goes back). Icon: e.g. INV_Misc_Note_01, or leave empty for text.")

	local function button(text, left, w, fn)
		local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		b:SetWidth(w)
		b:SetHeight(24)
		b:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", left, 14)
		b:SetText(text)
		b:SetScript("OnClick", fn)
		return b
	end
	button("Save", 16, 80, function()
		local p = RW.P()
		local def = p.wheels[cur.wheel]
		if def then
			def.items[cur.idx] = RW.SlotFromFields(Collect())
			RW.RefreshWheel()
		end
		frame:Hide()
	end)
	button("Test", 102, 70, function()
		local s = RW.SlotFromFields(Collect())
		local S = RW.P().settings
		local cand
		if RW.NeedsDest(s) then cand = RW.Targeting.Decide(RW.Targeting.Env(), RW.Targeting.ctx, S) end
		RW.Execute(s, cand, S)
	end)
	button("Clear", 178, 70, function()
		local def = RW.P().wheels[cur.wheel]
		if def then def.items[cur.idx] = {}; RW.RefreshWheel() end
		frame:Hide()
	end)
	button("Cancel", 254, 90, function() frame:Hide() end)
end

function RW.OpenSlotEditor(wheelId, idx)
	if not frame then Build() end
	local p = RW.P()
	local def = p.wheels[wheelId]
	if not def then return end
	cur.wheel, cur.idx = wheelId, idx
	frame.title:SetText(def.name .. " - slot " .. idx)
	frame.opens.options = WheelOptions()
	Fill(def.items[idx])
	frame:Show()
end
