-- Config: the settings window (Wheels / Display / Targeting / Emotes tabs).
ReactWheel = ReactWheel or {}
local RW = ReactWheel

local frame
local tabs, tabButtons = {}, {}
local loading = false
local refreshers = {}
local ctr = 0
local selected -- wheel id selected in the Wheels tab

local function S() return RW.P().settings end
local function Name(prefix) ctr = ctr + 1; return "ReactWheelCfg" .. prefix .. ctr end
local function RefreshAll()
	local was = loading
	loading = true
	for _, r in ipairs(refreshers) do r() end
	loading = was
end
local function OnChanged() if RW.RefreshWheel then RW.RefreshWheel() end end

---------------------------------------------------------------------------
-- widgets (each registers a refresher that re-reads its value)
---------------------------------------------------------------------------
local function Text(parent, text, x, y, template)
	local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	fs:SetJustifyH("LEFT")
	fs:SetText(text)
	return fs
end

local function Slider(parent, label, x, y, min, max, step, get, set, fmt)
	local name = Name("Slider")
	local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
	s:SetWidth(210)
	s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	s:SetMinMaxValues(min, max)
	s:SetValueStep(step)
	local lo, hi, txt = _G[name .. "Low"], _G[name .. "High"], _G[name .. "Text"]
	if lo then lo:SetText(min) end
	if hi then hi:SetText(max) end
	local function caption(v) if txt then txt:SetText(label .. ": " .. string.format(fmt or "%d", v)) end end
	s:SetScript("OnValueChanged", function(_, v)
		caption(v)
		if loading then return end
		set(v)
		OnChanged()
	end)
	refreshers[#refreshers + 1] = function() s:SetValue(get()); caption(get()) end
	return s
end

local function Check(parent, label, x, y, get, set)
	local name = Name("Check")
	local c = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
	c:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	local t = _G[name .. "Text"]
	if t then t:SetText(label) end
	c:SetScript("OnClick", function()
		if loading then return end
		set(c:GetChecked() and true or false)
		OnChanged()
	end)
	refreshers[#refreshers + 1] = function() c:SetChecked(get() and true or false) end
	return c
end

-- left-click cycles forward, right-click backward
local function Cycle(parent, label, x, y, options, get, set, width, labelWidth)
	Text(parent, label, x, y - 5, "GameFontNormalSmall")
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetWidth(width or 150)
	b:SetHeight(22)
	b:SetPoint("TOPLEFT", parent, "TOPLEFT", x + (labelWidth or 160), y)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local function idx()
		local v = get()
		for i, o in ipairs(options) do if o[1] == v then return i end end
		return 1
	end
	b:SetScript("OnClick", function(_, button)
		local n, i = #options, idx()
		i = (button == "RightButton") and ((i - 2) % n) + 1 or (i % n) + 1
		set(options[i][1])
		b:SetText(options[i][2])
		OnChanged()
	end)
	refreshers[#refreshers + 1] = function() b:SetText(options[idx()][2]) end
	return b
end

local function Button(parent, text, x, y, w, fn)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetWidth(w)
	b:SetHeight(22)
	b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	b:SetText(text)
	b:SetScript("OnClick", fn)
	return b
end

local function Edit(parent, x, y, w, onEnter)
	local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	e:SetWidth(w)
	e:SetHeight(20)
	e:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	e:SetAutoFocus(false)
	e:SetScript("OnEscapePressed", function() e:ClearFocus() end)
	e:SetScript("OnEnterPressed", function() onEnter(e:GetText()); e:ClearFocus() end)
	e:SetScript("OnEditFocusLost", function() onEnter(e:GetText()) end)
	return e
end

---------------------------------------------------------------------------
-- Wheels tab
---------------------------------------------------------------------------
local wheelRows, slotButtons = {}, {}

local function Selected()
	local p = RW.P()
	if not (selected and p.wheels[selected]) then selected = p.order[1] end
	return p.wheels[selected], selected
end

local function RefreshWheels()
	local p = RW.P()
	local def = Selected()
	for i = 1, 14 do
		local r = wheelRows[i]
		local id = p.order[i]
		if id then
			r.id = id
			r:SetText((id == selected and "> " or "") .. p.wheels[id].name)
			r:Show()
		else
			r:Hide()
		end
	end
	frame.wheelName:SetText(def.name)
	local was = loading
	loading = true
	frame.wheelSlots:SetValue(def.slots)
	loading = was
	for i = 1, 12 do
		local b = slotButtons[i]
		if i <= def.slots then
			local s = def.items[i] or {}
			local label = (s.label and s.label ~= "" and s.label) or s.text or s.emote or ""
			if RW.IsEmpty(s) then label = "|cff777777+|r" end
			b:SetText(string.sub(label, 1, 9))
			b:Show()
		else
			b:Hide()
		end
	end
end

local function BuildWheelsTab(t)
	Text(t, "Wheels", 10, -8)
	for i = 1, 14 do
		local r = CreateFrame("Button", nil, t, "UIPanelButtonTemplate")
		r:SetWidth(140)
		r:SetHeight(20)
		r:SetPoint("TOPLEFT", t, "TOPLEFT", 10, -30 - (i - 1) * 21)
		r:SetScript("OnClick", function() selected = r.id; RefreshWheels() end)
		wheelRows[i] = r
	end
	Button(t, "New", 165, -30, 60, function() selected = RW.NewWheel(); RefreshWheels() end)
	Button(t, "Copy", 230, -30, 60, function() local _, id = Selected(); selected = RW.NewWheel(nil, id); RefreshWheels() end)
	Button(t, "Delete", 295, -30, 60, function()
		local _, id = Selected()
		if RW.DeleteWheel(id) then selected = nil; RefreshWheels(); OnChanged() else RW.Print("You need at least one wheel.") end
	end)
	Button(t, "Up", 360, -30, 40, function() local _, id = Selected(); RW.MoveWheel(id, -1); RefreshWheels() end)
	Button(t, "Down", 405, -30, 50, function() local _, id = Selected(); RW.MoveWheel(id, 1); RefreshWheels() end)

	Text(t, "Name", 165, -66, "GameFontNormalSmall")
	frame.wheelName = Edit(t, 215, -62, 145, function(txt)
		local def = Selected()
		if txt ~= "" and txt ~= def.name then def.name = txt; RefreshWheels(); OnChanged() end
	end)
	frame.wheelSlots = Slider(t, "Slots", 165, -100, 4, 12, 1,
		function() return (Selected()).slots end,
		function(v) local _, id = Selected(); RW.SetSlotCount(id, v); RefreshWheels() end)
	local destOpts = { { nil, "Smart reply" }, { "SAY", "Say" }, { "PARTY", "Party" }, { "RAID", "Raid" }, { "GUILD", "Guild" } }
	local autoOpts = { { nil, "Never" }, { "whisper", "After a whisper" }, { "party", "In a party / raid" }, { "solo", "When solo" } }
	Cycle(t, "Auto-opens", 165, -154, autoOpts, function() return (Selected()).auto end, function(v) (Selected()).auto = v end, 130)
	Cycle(t, "Wheel sends to", 165, -128, destOpts,
		function() return (Selected()).dest end, function(v) (Selected()).dest = v end, 130)

	Text(t, "Slots (click to edit; clockwise from the top)", 165, -186, "GameFontNormalSmall")
	for i = 1, 12 do
		local b = CreateFrame("Button", nil, t, "UIPanelButtonTemplate")
		b:SetWidth(66)
		b:SetHeight(26)
		local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
		b:SetPoint("TOPLEFT", t, "TOPLEFT", 165 + col * 70, -204 - row * 30)
		b:SetScript("OnClick", function() local _, id = Selected(); RW.EditSlot(id, i) end)
		slotButtons[i] = b
	end
	Button(t, "Open it", 372, -62, 70, function() local _, id = Selected(); RW.OpenWheel(id) end)
	refreshers[#refreshers + 1] = RefreshWheels
end

---------------------------------------------------------------------------
-- Display tab
---------------------------------------------------------------------------
local function BuildDisplayTab(t)
	Text(t, "Size", 10, -8)
	Slider(t, "Button size", 20, -40, 40, 110, 1, function() return S().buttonSize end, function(v) S().buttonSize = v end)
	Slider(t, "Text size", 20, -80, 0.7, 2.5, 0.1, function() return S().fontScale end, function(v) S().fontScale = v end, "%.1f")
	Slider(t, "Centre controls", 20, -120, 0.8, 2.5, 0.1, function() return S().hubScale end, function(v) S().hubScale = v end, "%.1f")
	Slider(t, "Minimum ring radius", 20, -160, 70, 200, 1, function() return S().radius end, function(v) S().radius = v end)
	Slider(t, "Whole wheel scale", 20, -200, 0.6, 2, 0.05, function() return S().scale end, function(v) S().scale = v end, "%.2f")
	Slider(t, "Pause between reactions (s)", 20, -240, 0, 3, 0.1, function() return S().minInterval end, function(v) S().minInterval = v end, "%.1f")

	Text(t, "Behaviour", 250, -8)
	Cycle(t, "Opening", 250, -34, { { "toggle", "Press to open / close" }, { "hold", "Hold to show" } },
		function() return S().openMode end, function(v) S().openMode = v end, 165, 72)
	Cycle(t, "Appears", 250, -62, { { "cursor", "At the cursor" }, { "center", "Screen centre" } },
		function() return S().openAt end, function(v) S().openAt = v end, 165, 72)
	Check(t, "Switch wheel to suit the situation", 250, -246, function() return S().autoWheel end, function(v) S().autoWheel = v end)
	Check(t, "Play sounds", 250, -270, function() return S().sounds end, function(v) S().sounds = v end)
	Check(t, "Show the minimap button", 250, -92,
		function() return not ReactWheelDB.minimap.hide end,
		function(v) ReactWheelDB.minimap.hide = not v; RW.UpdateMinimap() end)
	Cycle(t, "Wheels are", 250, -124, { { "account", "Shared by all characters" }, { "char", "Just this character" } },
		function() return (ReactWheelCharDB and ReactWheelCharDB.useChar) and "char" or "account" end,
		function(v)
			if v == "char" then
				if not ReactWheelCharDB.profile then ReactWheelCharDB.profile = RW.Copy(ReactWheelDB.profile) end
				ReactWheelCharDB.useChar = true
			else
				ReactWheelCharDB.useChar = false
			end
			selected = nil
			RefreshAll()
		end, 165, 72)
	Button(t, "Key bindings...", 250, -160, 130, function()
		local ok = pcall(function()
			if KeyBindingFrame_LoadUI then KeyBindingFrame_LoadUI() end
			ShowUIPanel(KeyBindingFrame)
		end)
		if not ok then RW.Print("Open Esc > Key Bindings and look for ReactWheel.") end
	end)
	local resetAll
	resetAll = Button(t, "Reset everything", 250, -220, 130, function()
		-- two clicks: the first arms the button, the second (within 5 s) does it
		if not resetAll.armed then
			resetAll.armed = GetTime()
			resetAll:SetText("Click again to confirm")
			return
		end
		resetAll.armed = nil
		resetAll:SetText("Reset everything")
		RW.ResetAll()
		RW.UpdateMinimap()
		selected = nil
		RefreshAll()
		OnChanged()
		RW.Print("Everything reset to defaults.")
	end)
	resetAll:SetWidth(150)
	resetAll:SetScript("OnUpdate", function()
		if resetAll.armed and GetTime() - resetAll.armed > 5 then
			resetAll.armed = nil
			resetAll:SetText("Reset everything")
		end
	end)
	Button(t, "Reset wheels", 250, -190, 130, function()
		RW.P().wheels, RW.P().order = RW.DefaultWheels()
		RW.P().current = RW.P().order[1]
		selected = nil
		RefreshAll()
		OnChanged()
		RW.Print("Wheels reset to the defaults.")
	end)
end

---------------------------------------------------------------------------
-- Targeting tab
---------------------------------------------------------------------------
local RULE_NAMES = {
	whisper = "A recent whisper", guild = "Recent guild chat", group = "Raid / party",
	say = "Recent /say nearby", target = "Whisper my target", fallback = "Otherwise: say",
}
local ruleRows = {}

local function RefreshRules()
	local r = S().rules
	for i = 1, 6 do
		local row = ruleRows[i]
		if r[i] then
			row.label:SetText(i .. ". " .. (RULE_NAMES[r[i].id] or r[i].id))
			row.check:SetChecked(r[i].on)
			row:Show()
		else
			row:Hide()
		end
	end
end

local function BuildTargetingTab(t)
	Text(t, "Where reactions go (smart reply)", 10, -8)
	Slider(t, "Whisper counts for (s)", 20, -40, 5, 120, 1, function() return S().whisperWindow end, function(v) S().whisperWindow = v end)
	Slider(t, "Guild chat counts for (s)", 20, -80, 5, 120, 1, function() return S().guildWindow end, function(v) S().guildWindow = v end)
	Slider(t, "Group chat counts for (s)", 20, -120, 5, 120, 1, function() return S().groupWindow end, function(v) S().groupWindow = v end)
	Slider(t, "/say counts for (s)", 20, -160, 5, 120, 1, function() return S().sayWindow end, function(v) S().sayWindow = v end)
	Check(t, "Keep replying to the last whisperer", 14, -190, function() return S().stickWhisper end, function(v) S().stickWhisper = v end)
	Cycle(t, "When unsure", 14, -222, { { "low", "Ask me where" }, { "never", "Use best guess" }, { "always", "Always ask" } },
		function() return S().askMode end, function(v) S().askMode = v end, 120)
	Cycle(t, "/say sending", 14, -250, { { "auto", "Auto (Enter outdoors)" }, { "direct", "Always direct" }, { "prefill", "Always chat box" } },
		function() return S().sayMode end, function(v) S().sayMode = v end, 170)

	Text(t, "Order of checks (first match wins)", 250, -8)
	for i = 1, 6 do
		local row = CreateFrame("Frame", nil, t)
		row:SetWidth(240)
		row:SetHeight(24)
		row:SetPoint("TOPLEFT", t, "TOPLEFT", 250, -32 - (i - 1) * 26)
		local cname = Name("Rule")
		row.check = CreateFrame("CheckButton", cname, row, "UICheckButtonTemplate")
		row.check:SetPoint("LEFT", row, "LEFT", 0, 0)
		row.check:SetScript("OnClick", function() S().rules[i].on = row.check:GetChecked() and true or false end)
		row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.label:SetPoint("LEFT", row, "LEFT", 30, 0)
		local up = Button(row, "^", 170, 0, 24, function() if RW.MoveRule(i, -1) then RefreshRules() end end)
		local dn = Button(row, "v", 198, 0, 24, function() if RW.MoveRule(i, 1) then RefreshRules() end end)
		up:ClearAllPoints(); up:SetPoint("RIGHT", row, "RIGHT", -30, 0)
		dn:ClearAllPoints(); dn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
		ruleRows[i] = row
	end
	refreshers[#refreshers + 1] = RefreshRules

	Text(t, "Ignore whispers from (comma separated)", 250, -196, "GameFontNormalSmall")
	frame.ignore = Edit(t, 250, -214, 230, function(txt)
		local ig = {}
		for name in string.gmatch(txt or "", "[^,%s]+") do ig[name] = true end
		S().ignore = ig
	end)
	refreshers[#refreshers + 1] = function()
		local names = {}
		for n in pairs(S().ignore or {}) do names[#names + 1] = n end
		table.sort(names)
		frame.ignore:SetText(table.concat(names, ", "))
	end

	frame.live = Text(t, "", 250, -244, "GameFontHighlightSmall")
	frame.live:SetWidth(240)
end

---------------------------------------------------------------------------
-- Emotes tab
---------------------------------------------------------------------------
local function BuildEmotesTab(t)
	Text(t, "Emotes", 10, -8)
	local info = Text(t, "Each reaction can also play an emote. Emotes are only seen by people near you, so by default they play only for say, party and raid. A slot can override this in its own editor.", 20, -34, "GameFontHighlightSmall")
	info:SetWidth(440)
	Check(t, "Also play the emote when replying to a whisper", 14, -90, function() return S().emoteOnWhisper end, function(v) S().emoteOnWhisper = v end)
	Check(t, "Also play the emote when sending to guild chat", 14, -120, function() return S().emoteOnGuild end, function(v) S().emoteOnGuild = v end)
end

---------------------------------------------------------------------------
-- Share tab (import / export)
---------------------------------------------------------------------------
local pendingImport

local function BuildShareTab(t)
	Text(t, "Share wheels", 10, -8)
	local info = Text(t, "Export gives you text to paste to a friend (or another character). To import, paste it into the box and press Import.", 20, -32, "GameFontHighlightSmall")
	info:SetWidth(450)
	frame.shareBox = CreateFrame("EditBox", nil, t, "InputBoxTemplate")
	frame.shareBox:SetWidth(440)
	frame.shareBox:SetHeight(24)
	frame.shareBox:SetPoint("TOPLEFT", t, "TOPLEFT", 20, -80)
	frame.shareBox:SetAutoFocus(false)
	frame.shareBox:SetMaxLetters(0)
	frame.shareBox:SetScript("OnEscapePressed", function() frame.shareBox:ClearFocus() end)
	frame.shareBox:SetScript("OnTextChanged", function() pendingImport = nil end)
	frame.shareStatus = Text(t, "", 20, -160, "GameFontHighlightSmall")
	frame.shareStatus:SetWidth(450)
	local function status(msg) frame.shareStatus:SetText(msg or "") end

	Button(t, "Export this wheel", 20, -112, 130, function()
		local _, id = Selected()
		frame.shareBox:SetText(RW.ExportWheels({ id }))
		frame.shareBox:HighlightText()
		frame.shareBox:SetFocus()
		status("Selected wheel exported. Press Ctrl+C to copy it.")
	end)
	Button(t, "Export all wheels", 156, -112, 130, function()
		frame.shareBox:SetText(RW.ExportWheels())
		frame.shareBox:HighlightText()
		frame.shareBox:SetFocus()
		status("All wheels exported. Press Ctrl+C to copy it.")
	end)
	Button(t, "Import", 292, -112, 80, function()
		local text = frame.shareBox:GetText()
		local result, err = RW.PreviewImport(text)
		if not result then status("|cffff6060" .. err .. "|r") pendingImport = nil return end
		if #result.commands > 0 and pendingImport ~= text then
			-- slash commands run as if you typed them: make the player look first
			pendingImport = text
			status("|cffffb030This import contains slash commands that run when you click them:|r\n" ..
				table.concat(result.commands, "\n", 1, math.min(#result.commands, 6)) ..
				"\nPress Import again to accept.")
			return
		end
		local ids = RW.CommitImport(result)
		pendingImport = nil
		selected = ids[1]
		RefreshAll()
		status("|cff60ff60Imported " .. #ids .. " wheel(s).|r")
	end)
end

---------------------------------------------------------------------------
-- frame and tabs
---------------------------------------------------------------------------
local function SelectTab(i)
	for k, t in ipairs(tabs) do
		if k == i then t:Show() else t:Hide() end
	end
	for k, b in ipairs(tabButtons) do
		if k == i then b:LockHighlight() else b:UnlockHighlight() end
	end
end

local function LiveText()
	if not (frame and frame:IsShown() and frame.live) then return end
	local ok, d = pcall(function() return RW.Targeting.Decide(RW.Targeting.Env(), RW.Targeting.ctx, S()) end)
	if ok and d then
		frame.live:SetText("Right now a reaction would go to:\n|cff60ff60" .. d.label .. "|r (" .. d.reason .. ")" ..
			(d.confidence == "low" and "\n|cffffb030unsure - you would be asked|r" or ""))
	end
end

local function Build()
	frame = CreateFrame("Frame", "ReactWheelConfig", UIParent)
	frame:SetWidth(520)
	frame:SetHeight(380)
	frame:SetFrameStrata("DIALOG")
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
	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -12)
	title:SetText("ReactWheel")
	local x = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	x:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
	frame:Hide()
	tinsert(UISpecialFrames, "ReactWheelConfig")

	local names = { "Wheels", "Display", "Targeting", "Emotes", "Share" }
	local builders = { BuildWheelsTab, BuildDisplayTab, BuildTargetingTab, BuildEmotesTab, BuildShareTab }
	for i, n in ipairs(names) do
		local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		b:SetWidth(92)
		b:SetHeight(24)
		b:SetPoint("TOPLEFT", frame, "TOPLEFT", 14 + (i - 1) * 96, -40)
		b:SetText(n)
		b:SetScript("OnClick", function() SelectTab(i) end)
		tabButtons[i] = b
		local t = CreateFrame("Frame", nil, frame)
		t:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -68)
		t:SetWidth(492)
		t:SetHeight(300)
		tabs[i] = t
		builders[i](t)
	end
	frame.elapsed = 0
	frame:SetScript("OnUpdate", function(_, dt)
		frame.elapsed = frame.elapsed + (dt or arg1 or 0)
		if frame.elapsed > 0.5 then frame.elapsed = 0; LiveText() end
	end)
end

function RW.ShowConfig()
	if RW.InCombat() then RW.Print("Settings are locked during combat.") return end
	if not frame then Build() end
	if frame:IsShown() then frame:Hide() return end
	RefreshAll()
	SelectTab(1)
	frame:Show()
	LiveText()
end

---------------------------------------------------------------------------
-- First-run welcome
---------------------------------------------------------------------------
local welcome
local function ShowWelcome()
	welcome = CreateFrame("Frame", "ReactWheelWelcome", UIParent)
	welcome:SetWidth(340)
	welcome:SetHeight(150)
	welcome:SetFrameStrata("DIALOG")
	welcome:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	welcome.bg = welcome:CreateTexture(nil, "BACKGROUND")
	welcome.bg:SetAllPoints(welcome)
	welcome.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
	welcome.bg:SetVertexColor(0.05, 0.05, 0.09, 0.97)
	Text(welcome, "Welcome to ReactWheel", 14, -12)
	local msg = Text(welcome, "Pick a key to open the wheel, then left-click a reaction to send it. Right-click a reaction to change it.", 14, -38, "GameFontHighlightSmall")
	msg:SetWidth(312)
	Button(welcome, "Set key...", 14, -100, 100, function()
		welcome:Hide()
		pcall(function()
			if KeyBindingFrame_LoadUI then KeyBindingFrame_LoadUI() end
			ShowUIPanel(KeyBindingFrame)
		end)
	end)
	Button(welcome, "Settings", 120, -100, 100, function() welcome:Hide(); RW.ShowConfig() end)
	Button(welcome, "Later", 226, -100, 100, function() welcome:Hide() end)
	tinsert(UISpecialFrames, "ReactWheelWelcome")
end

local wf = CreateFrame("Frame")
wf:RegisterEvent("PLAYER_LOGIN")
wf:SetScript("OnEvent", function()
	if ReactWheelDB and RW.NeedsWelcome(GetBindingKey("REACTWHEEL_SHOW") ~= nil) then
		RW.Print("Welcome! Set a key under Key Bindings > ReactWheel (or /rw config).")
		ShowWelcome()
	end
end)
