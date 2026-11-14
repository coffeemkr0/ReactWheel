-- Minimap button: left-click opens settings, right-click shows a wheel menu, drag to move.
ReactWheel = ReactWheel or {}
local RW = ReactWheel

local button, menu

local function Place()
	local m = ReactWheelDB and ReactWheelDB.minimap
	if not (button and m) then return end
	local a = math.rad(m.angle or 215)
	local r = (Minimap:GetWidth() / 2) + 5
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function BuildMenu()
	menu = CreateFrame("Frame", "ReactWheelMinimapMenu", UIParent)
	menu:SetFrameStrata("FULLSCREEN_DIALOG")
	menu:SetWidth(170)
	menu.bg = menu:CreateTexture(nil, "BACKGROUND")
	menu.bg:SetAllPoints(menu)
	menu.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
	menu.bg:SetVertexColor(0.05, 0.05, 0.09, 0.96)
	menu.items = {}
	menu:Hide()
	tinsert(UISpecialFrames, "ReactWheelMinimapMenu")
end

local function Item(i, text, fn)
	local b = menu.items[i]
	if not b then
		b = CreateFrame("Button", nil, menu)
		b:SetHeight(20)
		b.t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		b.t:SetPoint("LEFT", b, "LEFT", 10, 0)
		b.hl = b:CreateTexture(nil, "HIGHLIGHT")
		b.hl:SetAllPoints(b)
		b.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
		b.hl:SetVertexColor(0.3, 0.5, 1, 0.3)
		menu.items[i] = b
	end
	b:SetWidth(170)
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", menu, "TOPLEFT", 0, -6 - (i - 1) * 20)
	b.t:SetText(text)
	b:SetScript("OnClick", function() menu:Hide(); fn() end)
	b:Show()
end

local function ShowMenu()
	if not menu then BuildMenu() end
	local p = RW.P()
	local n = 0
	for _, id in ipairs(p.order) do
		n = n + 1
		Item(n, "Open: " .. p.wheels[id].name, function() RW.OpenWheel(id) end)
	end
	n = n + 1; Item(n, "Settings...", function() RW.OpenConfig() end)
	for i = n + 1, #menu.items do menu.items[i]:Hide() end
	menu:SetHeight(12 + n * 20)
	menu:ClearAllPoints()
	local es = UIParent:GetEffectiveScale()
	local x, y = GetCursorPosition()
	menu:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", x / es + 10, y / es + 10)
	menu:Show()
end

local function Build()
	button = CreateFrame("Button", "ReactWheelMinimapButton", Minimap)
	button:SetWidth(31)
	button:SetHeight(31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetWidth(53)
	border:SetHeight(53)
	border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetWidth(20)
	icon:SetHeight(20)
	icon:SetPoint("CENTER", button, "CENTER", 0, 1)
	icon:SetTexture("Interface\\AddOns\\ReactWheel\\Textures\\MinimapIcon")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	button:SetScript("OnClick", function(_, b)
		-- releasing the mouse after a drag also counts as a click: ignore that one
		if button.dragging or (button.lastDrag and GetTime() - button.lastDrag < 0.3) then return end
		if b == "RightButton" then ShowMenu() else RW.OpenConfig() end
	end)
	button:SetScript("OnDragStart", function()
		button.dragging = true
		button:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local es = Minimap:GetEffectiveScale()
			local cx, cy = GetCursorPosition()
			ReactWheelDB.minimap.angle = math.deg(math.atan2(cy / es - my, cx / es - mx))
			Place()
		end)
	end)
	button:SetScript("OnDragStop", function()
		button:SetScript("OnUpdate", nil)
		button.dragging = false
		button.lastDrag = GetTime()
	end)
	button:SetScript("OnEnter", function()
		GameTooltip:SetOwner(button, "ANCHOR_LEFT")
		GameTooltip:AddLine("ReactWheel", 1, 0.82, 0)
		GameTooltip:AddLine("Left-click: settings", 1, 1, 1)
		GameTooltip:AddLine("Right-click: open a wheel", 1, 1, 1)
		GameTooltip:AddLine("Drag: move this button", 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Place()
end

function RW.UpdateMinimap()
	if not ReactWheelDB or not ReactWheelDB.minimap then return end
	if not button then Build() end
	if ReactWheelDB.minimap.hide then button:Hide() else button:Show(); Place() end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function() RW.UpdateMinimap() end)
