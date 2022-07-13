------------------------------------------------------------------
--
--  Author: Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Copyright (C) 2016 Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Licensed according to the included 'LICENSE' document
--
--  This file is part of lua-split library.
--
------------------------------------------------------------------

---
-- @usage
-- split = require "split"
-- lines = split(str, '\r?\n')
-- key, val = split.first(str, '=', true)
-- a,b,c,d = split.unpack(str, ':', true)

local unpack = unpack or table.unpack

local function split(str, sep, plain)
  local b, res = 0, {}
  sep = sep or '%s+'

  assert(type(sep) == 'string')
  assert(type(str) == 'string')

  if #sep == 0 then
    for i = 1, #str do
      res[#res + 1] = string.sub(str, i, i)
    end
    return res
  end

  while b <= #str do
    local e, e2 = string.find(str, sep, b, plain)
    if e then
      res[#res + 1] = string.sub(str, b, e-1)
      b = e2 + 1
      if b > #str then res[#res + 1] = "" end
    else
      res[#res + 1] = string.sub(str, b)
      break
    end
  end
  return res
end

local function split_iter(str, sep, plain)
  sep = sep or '%s+'

  assert(type(sep) == 'string')
  assert(type(str) == 'string')

  if #sep == 0 then
    local i = 0
    return function()
      i = i + 1
      if i > #str then return end
      return (string.sub(str, i, i))
    end
  end

  local b, eol = 0
  return function()
    if b > #str then
      if eol then
        eol = nil
        return ""
      end
      return
    end

    local e, e2 = string.find(str, sep, b, plain)
    if e then
      local s = string.sub(str, b, e-1)
      b = e2 + 1
      if b > #str then eol = true end
      return s
    end

    local s = string.sub(str, b)
    b = #str + 1
    return s
  end
end

local function usplit(...) return unpack(split(...)) end

local function split_first(str, sep, plain)
  local e, e2 = string.find(str, sep, nil, plain)
  if e then
    return string.sub(str, 1, e - 1), string.sub(str, e2 + 1)
  end
  return str
end

return setmetatable({
  split      = split;
  unpack     = usplit;
  first      = split_first;
  iter       = split_iter;
},{
  __call = function(_, ...)
    return split(...)
  end
})