local wcwidth = require "wcwidth"
local filters = require "tui.filters"

local bit32 = require "bit32"
local band  = bit32.band
local bor   = bit32.bor
local bnot  = bit32.bnot

-- Overwrite default filter to add utf8
filters.default_chain = filters.make_chain {
    -- Always before CSI
    filters.mouse;
    -- These can be in any order
    filters.SS2;
    filters.SS3;
    filters.CSI;
    filters.OSC;
    filters.DCS;
    filters.SOS;
    filters.PM;
    filters.APC;
    -- Should be before ESC but after CSI and OSC
    filters.linux_quirks;
    filters.multibyte_UTF8;
}

local control_character_threshold = 0x020 -- Smaller than this is control.
local control_character_mask      = 0x1f  -- 0x20 - 1
local meta_character_threshold    = 0x07f -- Larger than this is Meta.
local control_character_bit       = 0x40  -- 0x000000, must be off.
local meta_character_bit          = 0x080 -- x0000000, must be on.
local largest_char                = 255   -- Largest character value.

local function ctrl_char(c)
    return c < control_character_threshold and band(c, 0x80) == 0
end

local function meta_char(c)
    return c > meta_character_threshold and c <= largest_char
end


local function ctrl(c)
    return string.char(band(c:byte(), control_character_mask))
end

-- Nobody really has a Meta key, use Esc instead
local function meta(c)
    return string.char(bor(c:byte(), meta_character_bit))
end

local function Esc(c)
    return "\27" .. c
end

local function unMeta(c)
    return string.char(band(c:byte(), bnot(meta_character_bit)))
end

local function unCtrl(c)
    return string.upper(string.char(bor(c:byte(), control_character_bit)))
end

-- Utf8 aware sub
string.utf8sub = require "utf8_simple".sub

string.utf8width = function(self)
    -- First remove color escape codes
    local str = self:gsub("\27%[%d+m", "")

    local len = 0

    for _, rune in utf8.codes(str) do
        local l = wcwidth(rune)
        if l >= 0 then
            len = len + l
        end
    end

    return len
end

string.utf8height = function(self, width)
    local height = 1
    for line in self:gmatch("([^\n]*)\n") do
        height = height + 1

        for _ = width, line:utf8width(), width do
            height = height + 1
        end
    end

    return height
end

return {
    isC = ctrl_char,
    isM = meta_char,
    C   = ctrl,
    M   = meta,
    Esc = Esc,
    unM = unMeta,
    unC = unCtrl,
}
