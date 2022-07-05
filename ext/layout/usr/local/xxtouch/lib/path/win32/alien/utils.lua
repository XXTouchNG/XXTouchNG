------------------------------------------------------------------
--
--  Author: Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Copyright (C) 2013-2016 Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Licensed according to the included 'LICENCE' document
--
--  This file is part of lua-path library.
--
------------------------------------------------------------------

local alien = require "alien"

local STRUCT = {}
STRUCT.__index = STRUCT

local function define_struct(opt, t)
  if not t then t, opt = opt, nil end
  assert(type(t) == "table")
  assert(not opt or type(opt) == "table")

  local s_align = opt and opt.align or 1
  local off = 0
  local names, offsets, types,fields = {}, {}, {}, {}
  local fmt = ""

  for i, field in ipairs(t) do
    local ftype, fname
    local align = s_align
    if type(field) == "string" then
      ftype, fname = field, i
    elseif getmetatable(field) == STRUCT then
      ftype, fname = field, i
    else
      ftype, fname = field[1], field[2] or i
      align = field.align or align
    end
    off = math.ceil(off / align) * align
    table.insert(names, fname)
    offsets[fname] = off
    types[fname]   = ftype
    if type(ftype) == "string" then
      off = off + alien.size(ftype)
    else
      off = off + ftype.size_
    end
  end

  return setmetatable({
    names_   = names,
    offsets_ = offsets,
    types_   = types,
    size_    = off,
    fmt_     = fmt,
  }, STRUCT)
end

function STRUCT:new(t, ptr)
  local buffer_ = alien.buffer(ptr or self.size_)

  local function get(_,key)
    local off = self.offsets_[key]
    if not off then error("field " .. key .. " does not exist") end
    local ftype = assert(self.types_[key])

    if type(ftype) ~= "string" then
      local ptr = buffer_:topointer(off + 1)
      return ftype:new(nil, ptr)
    end

    local size  = alien.size(ftype)
    local str   = buffer_:tostring(size, off + 1)
    return alien.unpack(ftype, str)
  end

  local function set(_,key, val)
    local off = self.offsets_[key]
    if not off then error("field " .. key .. " does not exist") end
    local ftype = assert(self.types_[key])
    local ptr   = buffer_:topointer(off + 1)
    local size  = alien.size(ftype)
    local val   = alien.pack(ftype, val)
    alien.memmove( ptr, val, #val )
  end

  local o = setmetatable({}, {
    __index = get; __newindex = set;
    __call = function () return buffer_ end
  })

  if t then for k, v in pairs(t) do
    o[k] = v
  end end

  return o
end

local function self_struct_test()

  local S1 = define_struct{
    {"I4", "s1v1"};
    {"I4", "s1v2"};
  }

  local S2 = define_struct{
    {"I4", "s2v1"};
    {"I4", "s2v2"};
  }

  local SS = define_struct{
    {S1, "s1"};
    {S2, "s2"};
  }

  local s = SS:new()
  alien.memset(s(),0, SS.size_)
  assert(s.s1.s1v1 == 0)
  assert(s.s1.s1v2 == 0)
  assert(s.s2.s2v1 == 0)
  assert(s.s2.s2v2 == 0)
  assert(not pcall(function() return s.s1.s2v1 end))
  assert(not pcall(function() return s.s1.s1v3 end))
  assert(not pcall(function() return s.s3.s3v1 end))
  s.s1.s1v1 = 123
  s.s2.s2v1 = 456
  assert(s.s1.s1v1 == 123)
  assert(s.s1.s1v2 == 0)
  assert(s.s2.s2v1 == 456)
  assert(s.s2.s2v2 == 0)
end

self_struct_test()

local function cast(v,t)
  local tmp = alien.buffer(alien.sizeof(t))
  tmp:set(1, v, t)
  return tmp:get(1,t)
end

local gc_wrap, gc_null
if _VERSION >= 'Lua 5.2' then 
  local setmetatable = setmetatable
  gc_wrap = function(v, fn)
    return setmetatable({
      value = v;
    }, { __gc = function() fn(v) end})
  end

  gc_null = function(h)
    setmetatable(h, nil)
    return h.value
  end

else
  local debug        = require "debug"
  local newproxy     = newproxy
  local assert       = assert
  local setmetatable = setmetatable

  local function gc(fn)
    local p = assert(newproxy())
    assert(debug.setmetatable(p, { __gc = fn }))
    return p
  end

  gc_wrap = function(v, fn)
    return {
      value = v;
      _ = gc(function() fn(v) end);
    }
  end

  gc_null = function(h)
    debug.setmetatable(h._, nil)
    return h.value
  end

end

local _M = {
  define_struct = define_struct;
  cast          = cast;
  gc_wrap       = gc_wrap;
  gc_null       = gc_null;
}

return _M