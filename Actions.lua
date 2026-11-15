-- Actions: what happens when a slot is used (text, emote, slash command).
ReactWheel = ReactWheel or {}
local RW = ReactWheel

local SOUND_NAMES = { hover = "igMainMenuOptionCheckBoxOn", send = "igMainMenuOptionCheckBoxOff" }
local SOUND_KITS = { hover = "IG_MAINMENU_OPTION_CHECKBOX_ON", send = "IG_MAINMENU_OPTION_CHECKBOX_OFF" }
function RW.Sound(kind, S)
	S = S or RW.P().settings
	if not S.sounds or not PlaySound then return end
	pcall(PlaySound, (SOUNDKIT and SOUNDKIT[SOUND_KITS[kind]]) or SOUND_NAMES[kind])
end

-- Blizzard rule (patch 8.2.5 / Classic 1.13.3+): /say and /yell sent by an addon need a hardware event in the
-- outdoor world. We can't tell in advance whether a given click will count, so "auto" mode just tries to send
-- and, if the game refuses, quietly puts the line in the chat box (see QuietCall / OnActionBlocked).
function RW.SayNeedsChatBox(S)
	return S.sayMode == "prefill"
end

-- Run fn while the game's "Interface action failed because of an AddOn" popup is switched off. A refused
-- protected call isn't a Lua error (pcall can't see it): the game fires ADDON_ACTION_BLOCKED/FORBIDDEN and the
-- default UI answers with a popup. We take those frames off the event for the duration of the call and always
-- put them back; our own handler (RW.OnActionBlocked) still hears the event.
local BLOCK_EVENTS = { "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }
function RW.QuietCall(fn, ...)
	local held = {}
	if GetFramesRegisteredForEvent then
		for _, ev in ipairs(BLOCK_EVENTS) do
			for _, f in ipairs({ GetFramesRegisteredForEvent(ev) }) do
				if f ~= RW.eventFrame and f.UnregisterEvent then
					pcall(f.UnregisterEvent, f, ev)
					held[#held + 1] = { f, ev }
				end
			end
		end
	end
	local ok, err = pcall(fn, ...)
	-- put the popup back after a short delay in case the game announces the refusal a moment late
	local function restore() for _, h in ipairs(held) do pcall(h[1].RegisterEvent, h[1], h[2]) end end
	if #held > 0 and RW.After then RW.After(0.3, restore) else restore() end
	return ok, err
end

-- Does the slot need a chat destination at all? (emote-only and command slots do not)
function RW.NeedsDest(slot)
	if slot.command and slot.command ~= "" then return false end
	return slot.text ~= nil and slot.text ~= ""
end

function RW.IsEmpty(slot)
	return not slot or ((slot.text or "") == "" and (slot.command or "") == ""
		and (slot.emote or "") == "" and not slot.opensWheel)
end

-- Emote policy: per-slot "always" / "public" / "never"; default "public" = only where bystanders see it.
function RW.ShouldEmote(slot, dest, S)
	local when = slot.emoteWhen
	if when == "never" then return false end
	if when == "always" or dest == nil then return true end
	if dest == "SAY" or dest == "PARTY" or dest == "RAID" then return true end
	if dest == "WHISPER" then return S.emoteOnWhisper and true or false end
	if dest == "GUILD" then return S.emoteOnGuild and true or false end
	return false
end

-- %t = target name, %p = your name, %z = zone
function RW.Expand(text)
	if not text or not string.find(text, "%%") then return text end
	return (string.gsub(text, "%%([tpz])", function(c)
		if c == "t" then return (UnitName and UnitName("target")) or "" end
		if c == "p" then return (UnitName and UnitName("player")) or "" end
		return (GetZoneText and GetZoneText()) or ""
	end))
end

function RW.RunCommand(line)
	local eb = (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox) or ChatFrameEditBox
	if not eb or not ChatEdit_SendText then RW.Print("can't run: " .. line) return end
	local old = eb:GetText()
	eb:SetText(line)
	pcall(ChatEdit_SendText, eb, 0)
	eb:SetText(old or "")
end

-- The game blocked a chat send from us: hand the line to the player's chat box instead.
-- Put a message the game wouldn't let us send into the chat box, ready for the player to press Enter.
function RW.Fallback(dest, text)
	local prefix = (dest == "PARTY" and "/p ") or (dest == "RAID" and "/raid ") or (dest == "GUILD" and "/g ") or "/s "
	if ChatFrame_OpenChat then ChatFrame_OpenChat(prefix .. text) end
	if not RW.blockedHinted then
		RW.blockedHinted = true
		RW.Print("The game wouldn't let the addon send that from here, so it is in your chat box - press Enter. The addon tries to send directly every time and falls back like this when it can't.")
	end
end

-- The game announces a refused call with ADDON_ACTION_BLOCKED/FORBIDDEN while our call is still running.
function RW.OnActionBlocked(addon, func)
	local w, p = RW.sayWatch, RW.pendingSend
	if w and not w.done then
		w.done = true
		RW.Fallback("SAY", w.text)
	elseif p then
		RW.pendingSend = nil
		RW.Fallback(p.dest, p.text)
	end
end

-- Called when a CHAT_MSG_SAY arrives: if it is the line we just sent, the send worked.
function RW.NoteSay(text)
	local w = RW.sayWatch
	if w and not w.done and text == w.text then w.done = true end
end

-- Run the slot. cand is the chosen destination (nil for slots that need none).
function RW.Execute(slot, cand, S)
	S = S or RW.P().settings
	-- spam guard: ignore a second reaction that arrives within minInterval of the last one
	local now = GetTime()
	if (S.minInterval or 0) > 0 and RW.lastExec and now - RW.lastExec < S.minInterval then return false end
	RW.lastExec = now
	if slot.command and slot.command ~= "" then
		RW.RunCommand(RW.Expand(slot.command))
	elseif cand then
		local text = RW.Expand(slot.text or "")
		if text ~= "" then
			if cand.dest == "WHISPER" and cand.bnid and BNSendWhisper then
				BNSendWhisper(cand.bnid, text) -- Battle.net friend
			elseif cand.dest == "WHISPER" then
				SendChatMessage(text, "WHISPER", nil, cand.target)
			elseif cand.dest == "SAY" and RW.SayNeedsChatBox(S) and ChatFrame_OpenChat then
				ChatFrame_OpenChat("/s " .. text)
			else
				-- If the game refuses, ADDON_ACTION_* fires synchronously and RW.OnActionBlocked puts the
				-- line in the chat box instead. For /say that refusal is routine, so keep the popup quiet.
				RW.pendingSend = { dest = cand.dest, text = text }
				if cand.dest == "SAY" then
					-- A refused /say may arrive as an event, or as nothing at all. Cover both: if the event doesn't
					-- bring the fallback, check shortly afterwards whether our line showed up in chat.
					local watch = { text = text, done = false }
					RW.sayWatch = watch
					RW.QuietCall(SendChatMessage, text, "SAY")
					RW.After(0.8, function()
						if not watch.done then
							watch.done = true
							RW.Fallback("SAY", text)
						end
					end)
				else
					SendChatMessage(text, cand.dest)
				end
				RW.pendingSend = nil
			end
		end
	end
	if slot.emote and slot.emote ~= "" and DoEmote and RW.ShouldEmote(slot, cand and cand.dest, S) then
		DoEmote(slot.emote)
	end
	if cand then RW.Targeting.OnSent(cand.dest, S) end
	RW.Sound("send", S)
	return true
end
