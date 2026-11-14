-- Minimal WoW API stubs so the addon files can be loaded and exercised outside the game.
local printed = {}
_PRINTED = printed
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) printed[#printed + 1] = m end }
SlashCmdList = {}
UISpecialFrames = {}
tinsert = table.insert
_NOW = 1000
function GetTime() return _NOW end
local me = "Tester"
function UnitName(u) if u == "player" then return me end if u == "target" then return _TARGET end end
function UnitExists(u) return u == "target" and _TARGET ~= nil end
function UnitIsPlayer() return true end
function UnitIsUnit() return false end
function InCombatLockdown() return _COMBAT or false end
function UnitAffectingCombat() return _COMBAT or false end
function GetCursorPosition() return 500, 400 end
function IsShiftKeyDown() return false end
function IsControlKeyDown() return false end
function GetZoneText() return "Elwynn" end
_SENT, _EMOTES = {}, {}
function SendChatMessage(t, ch, _, tgt) _SENT[#_SENT + 1] = { t, ch, tgt } end
function DoEmote(e) _EMOTES[#_EMOTES + 1] = e end

local proxy
local mt = {}
mt.__index = function(t, k)
	if k == "IsShown" or k == "IsVisible" then return function(self) return rawget(self, "_shown") or false end end
	if k == "Show" then return function(self) rawset(self, "_shown", true) end end
	if k == "Hide" then return function(self) rawset(self, "_shown", false) end end
	if k == "GetCenter" then return function() return 400, 300 end end
	if k == "GetEffectiveScale" then return function() return 1 end end
	if k == "GetWidth" or k == "GetHeight" then return function() return 1000 end end
	if k == "GetFrameLevel" then return function() return 10 end end
	if k == "GetText" then return function() return "" end end
	if k == "SetScript" then return function(self, name, fn) rawset(self, "_" .. name, fn) end end
	return function() return proxy() end
end
proxy = function() return setmetatable({}, mt) end
function CreateFrame() return proxy() end
UIParent = proxy()
GameTooltip = proxy()

_PREFILL = {}
function ChatFrame_OpenChat(m) _PREFILL[#_PREFILL + 1] = m end
