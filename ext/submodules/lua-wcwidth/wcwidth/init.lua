--
-- wcwidth.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Distributed under terms of the MIT license.
--

--
-- Divides a number by two, and rounds it up to the next odd number.
--
local halfodd = (function ()
   -- Lua 5.3 has bit shift operators and integer division.
   local ok, f = pcall(function ()
      return load("return function (x) return (x >> 1) | 1 end")()
   end)
   if ok then return f end
   -- Try using a bitwise manipulation module.
   for _, name in ipairs { "bit", "bit32" } do
      local ok, m = pcall(require, name)
      if ok then
         local rshift, bor = m.rshift, m.bor
         return function (x) return bor(rshift(x, 1), 1) end
      end
   end
   -- Fall-back using the math library.
   -- Lua 5.1 has math.mod() instead of the "%" operator.
   local floor = math.floor
   if (pcall(function () return load("return 10 % 3")() == 4 end)) then
      return function (x)
         local r = floor(x / 2)
         return (r % 2 == 0) and r + 1 or r
      end
   end
   local mod = math.mod or function (x, d)
      while x > d do x = x - d end
      return x
   end
   return function (x)
      local r = floor(x / 2)
      return mod(r, 2) == 0 and r + 1 or r
   end
end)()

local function _lookup(rune, table)
   local l, r = 1, #table
   while l <= r do
      local m = halfodd(l + r)
      -- Invariants:
      -- assert(l % 2 == 1, "lower bound index is not odd")
      -- assert(r % 2 == 0, "upper bound index is not even")
      -- assert(m % 2 == 1, "middle point index is not odd")
      if rune < table[m] then
         r = m - 1
      elseif rune > table[m + 1] then
         l = m + 2
      else
         return 1
      end
   end
   return 0
end

local _tab_zero = require "wcwidth.zerotab"
local _tab_wide = require "wcwidth.widetab"

local function wcwidth (rune)
   if rune == 0 or
      rune == 0x034F or
      rune == 0x2028 or
      rune == 0x2029 or
      (0x200B <= rune and rune <= 0x200F) or
      (0x202A <= rune and rune <= 0x202E) or
      (0x2060 <= rune and rune <= 0x2063)
   then
      return 0
   end

   -- C0/C1 control characters
   if rune < 32 or (0x07F <= rune and rune < 0x0A0) then
      return -1
   end

   -- Combining characters with zero width
   if _lookup(rune, _tab_zero) == 1 then
      return 0
   end

   return 1 + _lookup(rune, _tab_wide)
end

return wcwidth
