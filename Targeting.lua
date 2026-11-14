-- Targeting: decide where a reaction should be sent.
-- Valid destinations: WHISPER, SAY, PARTY, RAID, GUILD. Numbered chat channels are never used.
ReactWheel = ReactWheel or {}
local RW = ReactWheel

local Tg = { ctx = {} }
RW.Targeting = Tg

-- Record that something was heard. kind: WHISPER | GROUP | GUILD | SAY.
function Tg.Observe(kind, sender, now, S)
	local ctx = Tg.ctx
	if kind == "WHISPER" then
		if sender and not (S and S.ignore and S.ignore[RW.BaseName(sender)]) then
			ctx.whisper = { sender = sender, time = now }
			ctx.unstick = false
		end
	elseif kind == "GROUP" then ctx.group = now
	elseif kind == "GUILD" then ctx.guild = now
	elseif kind == "SAY" then ctx.say = now
	end
end

-- Called after a send so "stick to whisper" can release when the user picks another destination.
function Tg.OnSent(dest, S)
	if S and S.stickWhisper and dest ~= "WHISPER" then Tg.ctx.unstick = true end
end

-- Snapshot of the game state the engine needs.
function Tg.Env()
	local inRaid = (IsInRaid and IsInRaid()) or (GetNumRaidMembers and GetNumRaidMembers() > 0) or false
	local inParty = (IsInGroup and IsInGroup()) or (GetNumPartyMembers and GetNumPartyMembers() > 0) or false
	local target
	if UnitExists and UnitExists("target") and UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
		target = UnitName("target")
	end
	return {
		now = GetTime(),
		inRaid = inRaid and true or false,
		inParty = (inParty or inRaid) and true or false,
		inGuild = (IsInGuild and IsInGuild()) and true or false,
		targetName = target,
	}
end

local function cand(dest, target, label, reason, age)
	return { dest = dest, target = target, label = label, reason = reason, age = age }
end

local function key(c) return c.dest .. (c.target or "") end

-- Destination named explicitly (slot/wheel/global setting). Returns nil when unavailable.
function Tg.Fixed(dest, env)
	if dest == "SAY" then return cand("SAY", nil, "Say", "fixed")
	elseif dest == "PARTY" and env.inParty then return cand("PARTY", nil, "Party", "fixed")
	elseif dest == "RAID" and env.inRaid then return cand("RAID", nil, "Raid", "fixed")
	elseif dest == "GUILD" and env.inGuild then return cand("GUILD", nil, "Guild", "fixed")
	elseif dest == "WHISPER_TARGET" and env.targetName then
		return cand("WHISPER", env.targetName, "Whisper " .. env.targetName, "fixed")
	end
	return nil
end

-- Pick the destination. Returns the winning candidate plus .confidence ("high"/"low") and .alternatives.
function Tg.Decide(env, ctx, S)
	local now = env.now
	local w = ctx.whisper
	local wAge = w and (now - w.time)
	local fresh = w and ((S.stickWhisper and not ctx.unstick) or wAge <= S.whisperWindow)
	local stale = w and not fresh and wAge <= S.whisperWindow * 2
	local guildRecent = env.inGuild and ctx.guild and (now - ctx.guild) <= S.guildWindow
	local groupRecent = env.inParty and ctx.group and (now - ctx.group) <= S.groupWindow
	local sayRecent = ctx.say and (now - ctx.say) <= S.sayWindow

	local function whisperC()
		local age = math.floor(wAge)
		return cand("WHISPER", w.sender, "Whisper " .. RW.BaseName(w.sender),
			"whisper from " .. RW.BaseName(w.sender) .. " " .. age .. "s ago", age)
	end
	local function groupC()
		if env.inRaid then return cand("RAID", nil, "Raid", "in a raid") end
		if env.inParty then return cand("PARTY", nil, "Party", "in a party") end
	end
	local function guildC() if env.inGuild then return cand("GUILD", nil, "Guild", "guild chat") end end
	local function sayC() return cand("SAY", nil, "Say", "say") end
	local function targetC()
		if env.targetName then return cand("WHISPER", env.targetName, "Whisper " .. env.targetName, "your target") end
	end

	local winner, winRule
	for _, r in ipairs(S.rules) do
		if r.on then
			local c
			if r.id == "whisper" and fresh then c = whisperC()
			elseif r.id == "guild" and guildRecent then c = guildC(); if c then c.reason = "guild spoke recently" end
			elseif r.id == "group" then c = groupC()
			elseif r.id == "say" and sayRecent then c = sayC(); c.reason = "someone spoke in /say"
			elseif r.id == "target" then c = targetC()
			elseif r.id == "fallback" then c = sayC(); c.reason = "nothing else matched" end
			if c then winner, winRule = c, r.id break end
		end
	end
	if not winner then winner, winRule = sayC(), "fallback"; winner.reason = "nothing else matched" end

	local confidence = "high"
	if winRule == "whisper" then confidence = "high"
	elseif stale then confidence = "low"
	elseif guildRecent and groupRecent then confidence = "low"
	elseif winRule == "fallback" then confidence = "low" end

	-- alternatives: winner first, then every other destination that is currently possible
	local alts, seen = {}, {}
	local function add(c)
		if c and not seen[key(c)] then seen[key(c)] = true; alts[#alts + 1] = c end
	end
	add(winner)
	if w then
		local c = whisperC()
		if not fresh then c.reason = "older whisper from " .. RW.BaseName(w.sender) end
		add(c)
	end
	add(targetC())
	add(groupC())
	add(guildC())
	add(sayC())

	winner.confidence = confidence
	winner.rule = winRule
	winner.alternatives = alts
	return winner
end
