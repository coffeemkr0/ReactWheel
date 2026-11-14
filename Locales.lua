-- Strings and binding labels (enUS).
ReactWheel = ReactWheel or {}
local RW = ReactWheel

RW.L = setmetatable({}, { __index = function(_, k) return k end })

BINDING_HEADER_REACTWHEEL = "ReactWheel"
BINDING_NAME_HEADER_REACTWHEEL = "ReactWheel" -- some clients look the header up as a binding name
BINDING_NAME_REACTWHEEL_SHOW = "Reaction wheel (open / hold)"
BINDING_NAME_REACTWHEEL_NEXT = "Reaction wheel: next wheel"
BINDING_NAME_REACTWHEEL_PREV = "Reaction wheel: previous wheel"
BINDING_NAME_REACTWHEEL_CONFIG = "Reaction wheel: open settings"
