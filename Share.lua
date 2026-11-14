-- Share: export wheels to a pasteable string and import them back, with strict validation.
-- The string is data only: it is parsed by our own parser (never loaded as code) and every
-- field is rebuilt from a whitelist, so a hostile string can't inject anything.
ReactWheel = ReactWheel or {}
local RW = ReactWheel

local PREFIX = "RW1:"
local MAX_INPUT, MAX_NODES, MAX_DEPTH, MAX_STR = 60000, 6000, 6, 400

---------------------------------------------------------------------------
-- encoding: s<hex>;  n<number>;  t  f  {<k><v>...}
---------------------------------------------------------------------------
local function hex(s)
	return (string.gsub(s, ".", function(c) return string.format("%02x", string.byte(c)) end))
end

local function enc(v, out)
	local t = type(v)
	if t == "string" then out[#out + 1] = "s" .. hex(v) .. ";"
	elseif t == "number" then out[#out + 1] = "n" .. string.format("%.4f", v) .. ";"
	elseif t == "boolean" then out[#out + 1] = v and "t" or "f"
	elseif t == "table" then
		out[#out + 1] = "{"
		for k, x in pairs(v) do
			if type(k) == "string" or type(k) == "number" then enc(k, out); enc(x, out) end
		end
		out[#out + 1] = "}"
	end
end

function RW.Serialize(data)
	local out = {}
	enc(data, out)
	return PREFIX .. table.concat(out)
end

-- returns value, nextPos  (or nil, errorMessage)
local function dec(s, pos, depth, budget)
	budget.n = budget.n + 1
	if budget.n > MAX_NODES then return nil, "too large" end
	local c = string.sub(s, pos, pos)
	if c == "s" then
		local h, e = string.match(s, "^s(%x*);()", pos)
		if not h or string.len(h) % 2 == 1 or string.len(h) > MAX_STR * 2 then return nil, "bad string" end
		return (string.gsub(h, "%x%x", function(x) return string.char(tonumber(x, 16)) end)), e
	elseif c == "n" then
		local num, e = string.match(s, "^n(%-?%d+%.?%d*);()", pos)
		if not num then return nil, "bad number" end
		return tonumber(num), e
	elseif c == "t" then return true, pos + 1
	elseif c == "f" then return false, pos + 1
	elseif c == "{" then
		if depth >= MAX_DEPTH then return nil, "too deep" end
		local t, p = {}, pos + 1
		while true do
			if string.sub(s, p, p) == "}" then return t, p + 1 end
			if p > string.len(s) then return nil, "unterminated" end
			local k, kp = dec(s, p, depth + 1, budget)
			if k == nil then return nil, kp end
			if type(k) == "table" or type(k) == "boolean" then return nil, "bad key" end
			local v, vp = dec(s, kp, depth + 1, budget)
			if v == nil then return nil, vp end
			t[k] = v
			p = vp
		end
	end
	return nil, "unexpected data"
end

function RW.Parse(str)
	str = string.gsub(str or "", "%s+", "")
	if string.len(str) > MAX_INPUT then return nil, "That text is too long to be a wheel." end
	if string.sub(str, 1, string.len(PREFIX)) ~= PREFIX then return nil, "That doesn't look like an exported wheel (it should start with RW1:)." end
	local v, e = dec(str, string.len(PREFIX) + 1, 0, { n = 0 })
	if v == nil then return nil, "The text is damaged (" .. tostring(e) .. ")." end
	if type(v) ~= "table" then return nil, "The text is damaged." end
	return v
end

---------------------------------------------------------------------------
-- validation: rebuild everything from whitelisted fields
---------------------------------------------------------------------------
local DEST_OK = { AUTO = true, SAY = true, PARTY = true, RAID = true, GUILD = true, WHISPER_TARGET = true }
local WHEN_OK = { always = true, public = true, never = true }

local function str(v, max)
	if type(v) ~= "string" then return nil end
	v = string.gsub(v, "[%c]", "")
	if v == "" then return nil end
	return string.sub(v, 1, max)
end

local function SanitizeIcon(v)
	v = str(v, 120)
	if not v then return nil end
	if string.find(v, "^[%w_]+$") then return v end -- a plain icon name
	if string.find(v, "^Interface[\\/]") and not string.find(v, "%.%.") then return v end
	return nil
end

function RW.SanitizeSlot(s)
	local o = {}
	if type(s) ~= "table" then return o end
	o.label = str(s.label, 20)
	o.text = str(s.text, 250)
	local e = str(s.emote, 24)
	if e and string.find(e, "^[%a]+$") then o.emote = string.upper(e) end
	if WHEN_OK[s.emoteWhen] then o.emoteWhen = s.emoteWhen end
	o.command = str(s.command, 250)
	if o.command and string.sub(o.command, 1, 1) ~= "/" then o.command = nil end
	if DEST_OK[s.dest] then o.dest = s.dest end
	o.icon = SanitizeIcon(s.icon)
	if type(s.color) == "table" then
		local r, g, b = tonumber(s.color[1]), tonumber(s.color[2]), tonumber(s.color[3])
		if r and g and b then
			o.color = { math.max(0, math.min(1, r)), math.max(0, math.min(1, g)), math.max(0, math.min(1, b)) }
		end
	end
	-- opensWheel links are never imported: ids don't exist on the receiving side
	return o
end

function RW.SanitizeWheel(w)
	if type(w) ~= "table" then return nil end
	local clean = { name = str(w.name, 40) or "Imported wheel", items = {} }
	local n = tonumber(w.slots) or 8
	clean.slots = math.max(4, math.min(12, math.floor(n + 0.5)))
	if DEST_OK[w.dest] then clean.dest = w.dest end
	local commands = {}
	for i = 1, clean.slots do
		local s = RW.SanitizeSlot(type(w.items) == "table" and w.items[i] or nil)
		clean.items[i] = s
		if s.command then commands[#commands + 1] = s.command end
	end
	return clean, commands
end

-- Build the export string for a list of wheel ids (nil = all wheels).
function RW.ExportWheels(ids)
	local p = RW.P()
	local list = {}
	for _, id in ipairs(ids or p.order) do
		local w = p.wheels[id]
		if w then
			local c = RW.Copy(w)
			for _, s in pairs(c.items) do s.opensWheel = nil end
			list[#list + 1] = c
		end
	end
	return RW.Serialize({ v = 1, wheels = list })
end

-- Validate an import string without changing anything.
-- Returns { wheels = {...clean...}, commands = {...} } or nil, message
function RW.PreviewImport(str)
	local data, err = RW.Parse(str)
	if not data then return nil, err end
	if type(data.wheels) ~= "table" then return nil, "No wheels found in that text." end
	local result, count = { wheels = {}, commands = {} }, 0
	for i = 1, 12 do
		local w = data.wheels[i]
		if w == nil then break end
		local clean, cmds = RW.SanitizeWheel(w)
		if clean then
			result.wheels[#result.wheels + 1] = clean
			for _, c in ipairs(cmds) do result.commands[#result.commands + 1] = c end
			count = count + 1
		end
	end
	if count == 0 then return nil, "No wheels found in that text." end
	return result
end

-- Add previewed wheels to the current profile. Returns the new ids.
function RW.CommitImport(result)
	local p = RW.P()
	local ids = {}
	for _, w in ipairs(result.wheels) do
		local id = RW.NewWheel(w.name)
		local dst = p.wheels[id]
		dst.slots, dst.items, dst.dest = w.slots, RW.Copy(w.items), w.dest
		ids[#ids + 1] = id
	end
	return ids
end
