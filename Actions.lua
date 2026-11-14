-- Actions: what happens when a slot is used (text, emote, slash command).
ReactWheel = ReactWheel or {}
local RW = ReactWheel

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
function RW.OnActionBlocked(addon, func)
	local p = RW.pendingSend
	if not p or addon ~= "ReactWheel" or not (func and string.find(func, "SendChatMessage", 1, true)) then return end
	RW.pendingSend = nil
	RW.sayUnlocked = false -- the lock is back; use the chat box until the player says something
	local prefix = (p.dest == "SAY" and "/s ") or (p.dest == "PARTY" and "/p ") or (p.dest == "RAID" and "/raid ")
		or (p.dest == "GUILD" and "/g ") or "/s "
	if ChatFrame_OpenChat then ChatFrame_OpenChat(prefix .. p.text) end
	if not RW.blockedHinted then
		RW.blockedHinted = true
		RW.Print("The game blocked that message - press Enter to send it. Typing any chat message yourself first usually lifts the block.")
	end
end

-- Run the slot. cand is the chosen destination (nil for slots that need none).
function RW.Execute(slot, cand, S)
	S = S or RW.P().settings
	if slot.command and slot.command ~= "" then
		RW.RunCommand(RW.Expand(slot.command))
	elseif cand then
		local text = RW.Expand(slot.text or "")
		if text ~= "" then
			if cand.dest == "WHISPER" then
				SendChatMessage(text, "WHISPER", nil, cand.target)
			elseif cand.dest == "SAY" and (S.sayMode == "prefill" or not RW.sayUnlocked) and ChatFrame_OpenChat then
				-- The game refuses addon-sent /say until a /say has gone out this session, so type it into
				-- the chat box; once the player presses Enter that unlocks direct sending (see Core.lua).
				ChatFrame_OpenChat("/s " .. text)
				if S.sayMode ~= "prefill" and not RW.sayHinted then
					RW.sayHinted = true
					RW.Print("Press Enter to send this /say. After that, /say reactions send directly.")
				end
			else
				-- The game sometimes refuses addon-sent chat (observed for /say until the player has
				-- typed a message themselves). When it does, ADDON_ACTION_* fires synchronously and
				-- RW.OnActionBlocked puts the line in the chat box instead.
				RW.pendingSend = { dest = cand.dest, text = text }
				SendChatMessage(text, cand.dest)
				RW.pendingSend = nil
			end
		end
	end
	if slot.emote and slot.emote ~= "" and DoEmote and RW.ShouldEmote(slot, cand and cand.dest, S) then
		DoEmote(slot.emote)
	end
	if cand then RW.Targeting.OnSent(cand.dest, S) end
end
