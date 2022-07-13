local string = require "string"
local table  = require "table"
local math   = require "math"

local function prequire(...)
  local ok, mod = pcall(require, ...)
  if not ok then return nil, mod end
  return mod
end

local lua_version do

local lua_version_t
lua_version = function()
  if not lua_version_t then 
    local version = assert(_VERSION)
    local maj, min = version:match("^Lua (%d+)%.(%d+)$")
    if maj then                         lua_version_t = {tonumber(maj),tonumber(min)}
    elseif math.type    then            lua_version_t = {5,3}
    elseif not math.mod then            lua_version_t = {5,2}
    elseif table.pack and not pack then lua_version_t = {5,2}
    else                                lua_version_t = {5,2} end
  end
  return lua_version_t[1], lua_version_t[2]
end

end

local LUA_MAJOR, LUA_MINOR = lua_version()

local LUA_VER_NUM = LUA_MAJOR * 100 + LUA_MINOR

local load_bit, load_bit32

if LUA_VER_NUM < 503 then
  load_bit = function()
    return assert(prequire("bit32") or prequire("bit"), "can not find bit library!")
  end
  load_bit32 = load_bit
else
  local BIT_LUA_5_3 = [[
  local bit = {}

  function bit.bnot(a)
    return ~a
  end

  function bit.bor(a, b, ...)
    a = a | b
    if ... then return bit.bor(a, ...) end
    return a
  end

  function bit.band(a, b, ...)
    a = a & b
    if ... then return bit.band(a, ...) end
    return a
  end

  function bit.bxor(a, b, ...)
    a = a ~ b
    if ... then return bit.bxor(a, ...) end
    return a
  end

  function bit.lshift(a, b)
    return a << b
  end

  function bit.rshift(a, b)
    return a >> b
  end

  local function rrotate(bits, a, b)
    local d = a & 2^b-1
    return (d << (bits-b)) | a >> b
  end

  local function lrotate(bits, a, b)
    local mask = (2^b-1) << (bits - b)
    d = (a & mask) >> (bits - b)
    a = (a & ~mask) << b
    return d | a
  end

  function bit.rrotate(...)
    return rrotate(64, ...)
  end

  function bit.lrotate(...)
    return lrotate(64, ...)
  end

  local function wrap32(f) 
    return function(...) return f(...) & 0xFFFFFFFF end
  end

  local bit32 = {}
  for k, v in pairs(bit) do
    bit32[k] = wrap32(v)
  end

  function bit32.rrotate(...)
    return rrotate(32, ...)
  end

  function bit32.lrotate(...)
    return lrotate(32, ...)
  end

  return {
    bit   = bit;
    bit32 = bit32;
  }
  ]]

  local bit_loader = assert(load(BIT_LUA_5_3))

  load_bit = function()
    return assert(bit_loader()).bit
  end

  load_bit32 = function()
    return assert(bit_loader()).bit32
  end
end

local bit = load_bit32()

return bit