-- Wheel: the radial menu. Click a slice to send, right-click to customize.
ReactWheel = ReactWheel or {}
local RW = ReactWheel

local TEX = "Interface\\AddOns\\ReactWheel\\Textures\\"
local MAXSLOTS = 12

local wheel, catcher, picker
local slotFrames = {}
local state = {
	shown = nil,    -- id of the wheel being displayed
	stack = {},     -- ids to go back to after opening a sub-wheel
	n = 8, radius = 105, btn = 56, hub = 48, fs = 1,
	edit = false, swapFrom = nil,
	hover = nil, inHub = false,
	override = nil, -- destination pinned by clicking the hub
	altIndex = 1,
	decision = nil, tick = 0,
	picking = false, pending = nil,
}

local function P() return RW.P() end
local function Def() return P().wheels[state.shown] end

local function IconPath(icon)
	if not icon or icon == "" then return nil end
	if string.find(icon, "\\", 1, true) or string.find(icon, "/", 1, true) then return icon end
	return "Interface\\Icons\\" .. icon
end

local function SlotName(slot)
	if not slot then return "" end
	if slot.label and slot.label ~= "" then return slot.label end
	return slot.text or slot.emote or ""
end

local function CandText(c)
	local s = c.label
	if c.age then s = s .. " (" .. c.age .. "s)" end
	return s
end

---------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------
local function Face(f, slot)
	if RW.IsEmpty(slot) then
		f.icon:Hide()
		f.text:SetFont("Fonts\\ARIALN.TTF", 20 * state.fs)
		f.text:SetText("+")
		f.text:SetTextColor(0.45, 0.45, 0.45)
		return
	end
	local c = slot.color or { 1, 1, 1 }
	local path = IconPath(slot.icon)
	if path then
		f.icon:SetTexture(path)
		if slot.color then f.icon:SetVertexColor(c[1], c[2], c[3]) else f.icon:SetVertexColor(1, 1, 1) end
		f.icon:Show()
		f.text:SetText("")
	else
		local label = SlotName(slot)
		local len = string.len(label)
		f.icon:Hide()
		f.text:SetFont("Fonts\\ARIALN.TTF", ((len <= 3 and 20) or (len <= 6 and 15) or 12) * state.fs)
		f.text:SetText(label)
		f.text:SetTextColor(c[1], c[2], c[3])
	end
end

local function SetHover(idx)
	if idx and idx ~= state.hover then RW.Sound("hover") end
	state.hover = idx
	for i = 1, MAXSLOTS do
		local f = slotFrames[i]
		if i == idx then f.hl:Show() else f.hl:Hide() end
	end
	local def = Def()
	if idx and def and not RW.IsEmpty(def.items[idx]) then
		wheel.name:SetText(SlotName(def.items[idx]))
	elseif def then
		wheel.name:SetText(def.name)
	end
end

local function Font(fs, size) fs:SetFont("Fonts\\ARIALN.TTF", size) end

-- Size and place the centre controls; everything scales with the "hubScale" setting.
local function LayoutHub(hs)
	local h = state.hub
	wheel.hubBg:SetWidth(h * 2)
	wheel.hubBg:SetHeight(h * 2)
	Font(wheel.name, 12 * hs)
	Font(wheel.dest, 11 * hs)
	Font(wheel.pageText, 10 * hs)
	wheel.name:ClearAllPoints()
	wheel.name:SetPoint("CENTER", wheel, "CENTER", 0, 24 * hs)
	wheel.destBtn:SetWidth(h * 2 - 8)
	wheel.destBtn:SetHeight(18 * hs)
	wheel.destBtn:ClearAllPoints()
	wheel.destBtn:SetPoint("CENTER", wheel, "CENTER", 0, 6 * hs)
	wheel.pageText:ClearAllPoints()
	wheel.pageText:SetPoint("CENTER", wheel, "CENTER", 0, -12 * hs)
	for _, b in ipairs({ wheel.prev, wheel.next, wheel.close }) do
		b:SetWidth(20 * hs)
		b:SetHeight(18 * hs)
		Font(b.t, 14 * hs)
	end
	wheel.prev:ClearAllPoints()
	wheel.prev:SetPoint("CENTER", wheel, "CENTER", -30 * hs, -12 * hs)
	wheel.next:ClearAllPoints()
	wheel.next:SetPoint("CENTER", wheel, "CENTER", 30 * hs, -12 * hs)
	wheel.close:ClearAllPoints()
	wheel.close:SetPoint("CENTER", wheel, "CENTER", 0, -31 * hs)
	picker:SetScale(math.max(1, hs))
end

local function UpdateHub()
	local p = P()
	local pos, count = 1, #p.order
	for i, id in ipairs(p.order) do if id == state.shown then pos = i end end
	wheel.pageText:SetText(pos .. "/" .. count)
	if count > 1 then wheel.prev:Show(); wheel.next:Show() else wheel.prev:Hide(); wheel.next:Hide() end
	wheel.close.t:SetText(#state.stack > 0 and "<" or "x")
end

-- Swap mode (armed from the right-click menu): the chosen slice turns green, the others orange.
local function EditVisuals()
	for i = 1, MAXSLOTS do
		local f = slotFrames[i]
		if state.edit and i == state.swapFrom then f.ring:SetVertexColor(0.3, 1, 0.3, 1)
		elseif state.edit then f.ring:SetVertexColor(1, 0.65, 0.1, 1)
		else f.ring:SetVertexColor(0.4, 0.45, 0.55, 1) end
	end
end

local function Render()
	local def = Def()
	local S = P().settings
	local hs = S.hubScale or 1
	state.n = def.slots
	state.fs = S.fontScale or 1
	state.btn = S.buttonSize or 56
	state.hub = 48 * hs
	-- keep the ring clear of the centre controls and of neighbouring buttons
	local minR = math.max(state.hub + state.btn / 2 + 8, state.btn * state.n / (2 * math.pi) + 4)
	state.radius = math.max(S.radius, minR)
	local size = 2 * (state.radius + state.btn / 2 + 4)
	LayoutHub(hs)
	wheel:SetWidth(size)
	wheel:SetHeight(size)
	local step = 2 * math.pi / state.n
	for i = 1, MAXSLOTS do
		local f = slotFrames[i]
		f:SetWidth(state.btn)
		f:SetHeight(state.btn)
		f.icon:SetWidth(state.btn - 14)
		f.icon:SetHeight(state.btn - 14)
		if i <= state.n then
			local a = (i - 1) * step -- clockwise from the top
			f:ClearAllPoints()
			f:SetPoint("CENTER", wheel, "CENTER", math.sin(a) * state.radius, math.cos(a) * state.radius)
			Face(f, def.items[i])
			f:Show()
		else
			f:Hide()
		end
	end
	SetHover(nil)
	UpdateHub()
	EditVisuals()
end

local function RefreshDecision()
	if state.edit then
		wheel.dest:SetText("|cffffa020swap: click where to move it|r")
		return
	end
	local S = P().settings
	local dec = RW.Targeting.Decide(RW.Targeting.Env(), RW.Targeting.ctx, S)
	state.decision = dec
	local shownCand, color = dec, (dec.confidence == "low") and "|cffffb030" or "|cff60ff60"
	if state.override then shownCand, color = state.override, "|cff60c0ff" end
	wheel.dest:SetText(color .. "-> " .. CandText(shownCand) .. "|r")
end

---------------------------------------------------------------------------
-- Destination choice
---------------------------------------------------------------------------
local function HidePicker()
	state.picking = false
	state.pending = nil
	if picker then picker:Hide() end
end

local function ShowPicker(slot, dec)
	state.picking = true
	state.pending = slot
	local n = math.min(#dec.alternatives, 5)
	for i = 1, 5 do
		local b = picker.buttons[i]
		if i <= n then
			local c = dec.alternatives[i]
			b.cand = c
			b:SetText((i == 1 and "|cff60ff60" or "") .. CandText(c) .. (i == 1 and "|r" or ""))
			b:Show()
		else
			b:Hide()
		end
	end
	picker:SetHeight(34 + n * 24)
	picker:Show()
	SetHover(nil)
end

-- Work out where this click should go: a candidate, or "ASK" plus the decision.
local function ChooseDest(slot, shift, ctrl)
	local p = P()
	local S = p.settings
	local env = RW.Targeting.Env()
	local dec = RW.Targeting.Decide(env, RW.Targeting.ctx, S)
	if ctrl then return "ASK", dec end
	if shift then return dec.alternatives[2] or dec end
	local def = Def()
	local fixed = slot.dest or def.dest or S.defaultDest
	if fixed and fixed ~= "AUTO" then
		local c = RW.Targeting.Fixed(fixed, env)
		if c then return c end
		RW.Print("'" .. fixed .. "' isn't available right now - using smart reply.")
	end
	if state.override then return state.override end
	if (S.askMode == "always" or (S.askMode == "low" and dec.confidence == "low")) and #dec.alternatives >= 2 then
		return "ASK", dec
	end
	return dec
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------
function RW.CloseWheel()
	if wheel and wheel:IsShown() then wheel:Hide() end
end

-- Right-click menu on a slice
local slotMenu
function RW.HideSlotMenu()
	if slotMenu and slotMenu:IsShown() then slotMenu:Hide() return true end
	return false
end

function RW.ShowSlotMenu(idx)
	if RW.InCombat() then RW.Print("Editing is locked during combat.") return end
	if not slotMenu then
		slotMenu = CreateFrame("Frame", "ReactWheelSlotMenu", UIParent)
		slotMenu:SetFrameStrata("FULLSCREEN_DIALOG")
		slotMenu:SetWidth(190)
		slotMenu:SetHeight(58)
		slotMenu.bg = slotMenu:CreateTexture(nil, "BACKGROUND")
		slotMenu.bg:SetAllPoints(slotMenu)
		slotMenu.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
		slotMenu.bg:SetVertexColor(0.05, 0.05, 0.09, 0.97)
		slotMenu.items = {}
		local function item(i, text, fn)
			local b = CreateFrame("Button", nil, slotMenu)
			b:SetWidth(190)
			b:SetHeight(22)
			b:SetPoint("TOPLEFT", slotMenu, "TOPLEFT", 0, -6 - (i - 1) * 22)
			b.t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			b.t:SetPoint("LEFT", b, "LEFT", 10, 0)
			b.t:SetText(text)
			b.hl = b:CreateTexture(nil, "HIGHLIGHT")
			b.hl:SetAllPoints(b)
			b.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
			b.hl:SetVertexColor(0.3, 0.5, 1, 0.3)
			b:SetScript("OnClick", function() slotMenu:Hide(); fn(slotMenu.idx) end)
			slotMenu.items[i] = b
		end
		item(1, "Slot settings...", function(i) RW.EditSlot(state.shown, i) end)
		item(2, "Swap with another slot...", function(i) RW.BeginSwap(i) end)
	end
	slotMenu.idx = idx
	slotMenu:ClearAllPoints()
	local es = UIParent:GetEffectiveScale()
	local x, y = GetCursorPosition()
	slotMenu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / es + 6, y / es - 6)
	slotMenu:Show()
end

function RW.Activate(idx, button, shift, ctrl)
	local def = Def()
	if state.edit then
		-- a swap is armed: another slice completes it; the same slice or a right-click cancels
		if button ~= "RightButton" and idx ~= state.swapFrom then
			RW.SwapSlots(state.shown, state.swapFrom, idx)
			RW.CancelSwap()
			Render()
		else
			RW.CancelSwap()
		end
		return
	end
	local slot = def.items[idx]
	if button == "RightButton" then
		RW.ShowSlotMenu(idx)
		return
	end
	if RW.IsEmpty(slot) then
		RW.EditSlot(state.shown, idx)
		return
	end
	if slot.opensWheel and P().wheels[slot.opensWheel] then
		state.stack[#state.stack + 1] = state.shown
		state.shown = slot.opensWheel
		Render()
		return
	end
	if not RW.NeedsDest(slot) then
		RW.Execute(slot, nil)
		RW.CloseWheel()
		return
	end
	local c, dec = ChooseDest(slot, shift, ctrl)
	if c == "ASK" then
		ShowPicker(slot, dec)
		return
	end
	RW.Execute(slot, c)
	RW.CloseWheel()
end

function RW.EditSlot(wheelId, idx)
	if RW.InCombat() then RW.Print("Editing is locked during combat.") return end
	if RW.OpenSlotEditor then RW.OpenSlotEditor(wheelId, idx)
	else RW.Print("The slot editor arrives in the next update.") end
end

function RW.PageWheel(delta)
	local p = P()
	if not (wheel and wheel:IsShown()) then RW.OpenWheel() end
	local pos = 1
	for i, id in ipairs(p.order) do if id == state.shown then pos = i end end
	local n = #p.order
	pos = ((pos - 1 + delta) % n) + 1
	state.stack = {}
	state.shown = p.order[pos]
	p.current = state.shown
	state.override, state.altIndex = nil, 1
	HidePicker()
	Render()
	RefreshDecision()
end

function RW.BindingDown()
	local S = P().settings
	if wheel and wheel:IsShown() then
		if S.openMode ~= "hold" then RW.CloseWheel() end
	else
		RW.OpenWheel()
	end
end

function RW.BindingUp()
	if wheel and wheel:IsShown() and P().settings.openMode == "hold" then RW.CloseWheel() end
end

---------------------------------------------------------------------------
-- Frame construction
---------------------------------------------------------------------------
local function MiniButton(parent, text, w, h)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(w)
	b:SetHeight(h)
	b.t = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	b.t:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.t:SetText(text)
	b:SetScript("OnEnter", function() b.t:SetTextColor(1, 1, 1) end)
	b:SetScript("OnLeave", function() b.t:SetTextColor(1, 0.82, 0) end)
	return b
end

local function BuildPicker()
	picker = CreateFrame("Frame", "ReactWheelPicker", wheel)
	picker:SetWidth(170)
	picker:SetHeight(160)
	picker:SetPoint("CENTER", wheel, "CENTER", 0, 0)
	picker:SetFrameLevel(wheel:GetFrameLevel() + 20)
	picker:EnableMouse(true)
	picker.bg = picker:CreateTexture(nil, "BACKGROUND")
	picker.bg:SetAllPoints(picker)
	picker.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
	picker.bg:SetVertexColor(0.04, 0.04, 0.07, 0.95)
	picker.title = picker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	picker.title:SetPoint("TOP", picker, "TOP", 0, -8)
	picker.title:SetText("Send to:")
	picker.buttons = {}
	for i = 1, 5 do
		local b = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
		b:SetWidth(150)
		b:SetHeight(22)
		b:SetPoint("TOP", picker, "TOP", 0, -26 - (i - 1) * 24)
		b:SetScript("OnClick", function()
			local slot, c = state.pending, b.cand
			HidePicker()
			if slot and c then
				RW.Execute(slot, c)
				RW.CloseWheel()
			end
		end)
		picker.buttons[i] = b
	end
	picker:Hide()
end

local function Build()
	catcher = CreateFrame("Button", "ReactWheelCatcher", UIParent)
	catcher:SetAllPoints(UIParent)
	catcher:SetFrameStrata("DIALOG")
	catcher:SetFrameLevel(1)
	catcher:EnableMouse(true)
	catcher:EnableMouseWheel(true)
	catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	catcher:SetScript("OnClick", function() if RW.HideSlotMenu() then return end RW.CloseWheel() end)
	catcher:SetScript("OnMouseWheel", function(_, d) RW.PageWheel(d > 0 and -1 or 1) end)
	catcher:Hide()

	wheel = CreateFrame("Frame", "ReactWheelFrame", UIParent)
	wheel:SetFrameStrata("DIALOG")
	wheel:SetFrameLevel(10)
	wheel:SetWidth(280)
	wheel:SetHeight(280)
	wheel:EnableMouse(true)
	wheel:EnableMouseWheel(true)
	wheel:Hide()
	tinsert(UISpecialFrames, "ReactWheelFrame") -- Esc closes it

	-- hub
	wheel.hubBg = wheel:CreateTexture(nil, "BACKGROUND")
		wheel.hubBg:SetPoint("CENTER", wheel, "CENTER", 0, 0)
	wheel.hubBg:SetTexture(TEX .. "Circle")
	wheel.hubBg:SetVertexColor(0.03, 0.03, 0.06, 0.9)
	wheel.name = wheel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	wheel.name:SetPoint("CENTER", wheel, "CENTER", 0, 24)
	wheel.dest = wheel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	wheel.destBtn = CreateFrame("Button", nil, wheel)
	wheel.destBtn:SetWidth(88)
	wheel.destBtn:SetHeight(18)
	wheel.destBtn:SetPoint("CENTER", wheel, "CENTER", 0, 6)
	wheel.dest:SetPoint("CENTER", wheel.destBtn, "CENTER", 0, 0)
	wheel.destBtn:SetScript("OnClick", function()
		-- click the destination to cycle through the alternatives for the reactions you pick next
		local dec = state.decision
		if not dec then return end
		state.altIndex = (state.altIndex % #dec.alternatives) + 1
		state.override = (state.altIndex > 1) and dec.alternatives[state.altIndex] or nil
		RefreshDecision()
	end)
	wheel.destBtn:SetScript("OnEnter", function()
		if GameTooltip then
			GameTooltip:SetOwner(wheel.destBtn, "ANCHOR_BOTTOM")
			local d = state.decision
			GameTooltip:AddLine("Sending to", 1, 0.82, 0)
			if d then GameTooltip:AddLine(d.reason, 1, 1, 1) end
			GameTooltip:AddLine("Click to switch destination", 0.6, 0.6, 0.6)
			GameTooltip:Show()
		end
	end)
	wheel.destBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

	wheel.prev = MiniButton(wheel, "<", 16, 16)
	wheel.prev:SetPoint("CENTER", wheel, "CENTER", -30, -12)
	wheel.prev:SetScript("OnClick", function() RW.PageWheel(-1) end)
	wheel.next = MiniButton(wheel, ">", 16, 16)
	wheel.next:SetPoint("CENTER", wheel, "CENTER", 30, -12)
	wheel.next:SetScript("OnClick", function() RW.PageWheel(1) end)
	wheel.pageText = wheel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	wheel.pageText:SetPoint("CENTER", wheel, "CENTER", 0, -12)
	wheel.close = MiniButton(wheel, "x", 18, 16)
	wheel.close:SetPoint("CENTER", wheel, "CENTER", 0, -31)
	wheel.close:SetScript("OnClick", function()
		if #state.stack > 0 then
			state.shown = table.remove(state.stack)
			Render()
		else
			RW.CloseWheel()
		end
	end)

	-- slots
	for i = 1, MAXSLOTS do
		local f = CreateFrame("Frame", nil, wheel)
		f:SetWidth(56)
		f:SetHeight(56)
		f.bg = f:CreateTexture(nil, "BACKGROUND")
		f.bg:SetAllPoints(f)
		f.bg:SetTexture(TEX .. "Circle")
		f.bg:SetVertexColor(0.05, 0.05, 0.09, 0.88)
		f.ring = f:CreateTexture(nil, "BORDER")
		f.ring:SetAllPoints(f)
		f.ring:SetTexture(TEX .. "Ring")
		f.ring:SetVertexColor(0.4, 0.45, 0.55, 1)
		f.hl = f:CreateTexture(nil, "ARTWORK")
		f.hl:SetAllPoints(f)
		f.hl:SetTexture(TEX .. "Circle")
		f.hl:SetVertexColor(0.2, 0.55, 1, 0.6)
		f.hl:Hide()
		f.icon = f:CreateTexture(nil, "OVERLAY")
		f.icon:SetWidth(42)
		f.icon:SetHeight(42)
		f.icon:SetPoint("CENTER", f, "CENTER", 0, 0)
		f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		f.text:SetPoint("CENTER", f, "CENTER", 0, 0)
		slotFrames[i] = f
	end

	BuildPicker()

	wheel:SetScript("OnUpdate", function()
		if state.picking then return end
		local cx, cy = wheel:GetCenter()
		if not cx then return end
		local es = wheel:GetEffectiveScale()
		local mx, my = GetCursorPosition()
		local dx, dy = mx / es - cx, my / es - cy
		local d = math.sqrt(dx * dx + dy * dy)
		local idx
		state.inHub = d <= state.hub + 4
		if d > state.hub + 4 and d <= state.radius + state.btn / 2 + 6 then
			local a = math.atan2(dx, dy)
			if a < 0 then a = a + 2 * math.pi end
			idx = math.floor(a / (2 * math.pi / state.n) + 0.5) % state.n + 1
		end
		if idx ~= state.hover then SetHover(idx) end
		local now = GetTime()
		if now - state.tick > 0.2 then
			state.tick = now
			RefreshDecision()
		end
	end)

	wheel:SetScript("OnMouseUp", function(_, button)
		if RW.HideSlotMenu() then return end -- the click only dismisses the menu
		if state.picking then HidePicker() return end
		if state.edit and not state.hover then RW.CancelSwap() return end
		if state.hover then
			RW.Activate(state.hover, button, IsShiftKeyDown(), IsControlKeyDown())
		elseif button == "RightButton" or not state.inHub then
			RW.CloseWheel()
		end
	end)
	wheel:SetScript("OnMouseWheel", function(_, d) RW.PageWheel(d > 0 and -1 or 1) end)
	wheel:SetScript("OnHide", function()
		catcher:Hide()
		HidePicker()
		state.override, state.altIndex, state.stack = nil, 1, {}
		state.edit, state.swapFrom = false, nil
		RW.HideSlotMenu()
	end)
end

function RW.BeginSwap(idx)
	if RW.InCombat() then RW.Print("Editing is locked during combat.") return end
	state.edit = true
	state.swapFrom = idx
	if wheel then EditVisuals(); RefreshDecision() end
end

function RW.CancelSwap()
	state.edit = false
	state.swapFrom = nil
	if wheel then EditVisuals(); RefreshDecision() end
end

function RW.RefreshWheel()
	if wheel and wheel:IsShown() then Render() end
end

function RW.OpenWheel(id)
	if not wheel then Build() end
	local p = P()
	local S = p.settings
	if not id and S.autoWheel then id = RW.Targeting.PickWheel(RW.Targeting.Env(), RW.Targeting.ctx, S, p) end
	id = id or p.current
	if not p.wheels[id] then id = p.order[1] end
	p.current = id
	state.shown = id
	state.stack, state.override, state.altIndex = {}, nil, 1
	HidePicker()
	wheel:SetScale(S.scale or 1)
	Render()
	wheel:ClearAllPoints()
	if S.openAt == "center" then
		wheel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	else
		local es = wheel:GetEffectiveScale()
		local x, y = GetCursorPosition()
		local half = state.radius + state.btn / 2 + 4
		local w = UIParent:GetWidth() * UIParent:GetEffectiveScale() / es
		local h = UIParent:GetHeight() * UIParent:GetEffectiveScale() / es
		x = math.max(half, math.min(w - half, x / es))
		y = math.max(half, math.min(h - half, y / es))
		wheel:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	end
	RefreshDecision()
	catcher:Show()
	wheel:Show()
end
