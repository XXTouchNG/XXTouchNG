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
local kernel32 = assert(alien.load("kernel32.dll"))
local MultiByteToWideChar_ = assert(kernel32.MultiByteToWideChar)
local WideCharToMultiByte_ = assert(kernel32.WideCharToMultiByte)
local GetLastError         = assert(kernel32.GetLastError)

local DWORD = "uint"
local WCHAR_SIZE = 2

-- int __stdcall MultiByteToWideChar(UINT cp, DWORD flag, const char* src, int srclen, wchar_t* dst, int dstlen);
MultiByteToWideChar_:types{abi="stdcall", ret = "int",
  "uint",   -- cp
  DWORD,    -- flag
  "string", -- src (const char*)
  "int",    -- srclen
  "string", -- dst (wchar_t*)
  "int"     -- dstlen
}

--int __stdcall WideCharToMultiByte(UINT cp, DWORD flag, const wchar_t* src, int srclen, char* dst, int dstlen, const char* defchar, int* used);
WideCharToMultiByte_:types{abi="stdcall", ret = "int", 
  "int",     -- cp
  DWORD,     -- flag
  "string",  -- src (const wchar_t*)
  "int",     -- srclen
  "string",  -- dst (char*)
  "int",     -- dstlen
  "pointer", -- defchar (char*)
  "pointer"  -- used(int*)
}

GetLastError:types{ret = DWORD, abi='stdcall'}

local function strnlen(data, n)
  if type(data) == 'string' then
    return #data
  end
  n = n or #data
  for i = 1, n do
    if data[i] == 0 then
      return i
    end
  end
  return n
end

local function wcsnlen(data, n)
  if type(data) == 'string' then
    return  math.ceil(#data/2)
  end
  n = n or #data
  for i = 1, (2 * n), 2 do
    if (data[i] == 0) and (data[i+1] == 0) then
      return math.floor( i / 2 )
    end
  end
  return n
end

local function MultiByteToWideChar(src, cp)
  local flag   = true
  local buflen = strnlen(src)
  local dst    = alien.buffer( WCHAR_SIZE * (buflen + 1) ) -- eos
  local ret = MultiByteToWideChar_(cp, 0, src, #src, dst, buflen)
  if ret < 0 then return nil, GetLastError() end
  if ret <= buflen then 
    dst[ret * WCHAR_SIZE    ] = 0
    dst[ret * WCHAR_SIZE + 1] = 0
    return dst, ret
  end
  dst    = alien.buffer(WCHAR_SIZE * 1)
  dst[0] = 0
  dst[1] = 0
  return dst,0
end

local function WideCharToMultiByte(src, cp)
  local srclen = wcsnlen(src)
  local buflen = (srclen + 1)
  while true do
    local dst = alien.buffer(buflen + 1) -- eof
    local ret = WideCharToMultiByte_(cp, 0, src, srclen, dst, buflen, nil, nil)
    if ret <= 0 then 
      local err = GetLastError()
      if err == 122 then -- buffer too small
        buflen = math.ceil(1.5 * buflen)
      else
        return nil, err
      end
    else
      if ret <= buflen then 
        return dst, ret
      end
    end
  end
  local dst = alien.buffer(1)
  dst[0] = 0
  return dst, 0
end

local function LUA_M2W(src, ...)
  if not src or #src == 0 then return src end
  local dst, dstlen = MultiByteToWideChar(src, ...)
  if not dst then return nil, dstlen end
  return dst:tostring(dstlen * WCHAR_SIZE)
end

local function LUA_W2M(src, ...)
  if not src or #src == 0 then return src end
  local dst, dstlen = WideCharToMultiByte(src, ...)
  if not dst then return nil, dstlen end
  return dst:tostring(dstlen)
end

local _M = {
  MultiByteToWideChar = MultiByteToWideChar;
  WideCharToMultiByte = WideCharToMultiByte;
  mbstowcs            = LUA_M2W;
  wcstombs            = LUA_W2M;
}

return _M