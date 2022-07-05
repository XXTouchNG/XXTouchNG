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

local CP_ACP            = 0           -- default to ANSI code page
local CP_OEM            = 1           -- default to OEM  code page
local CP_MAC            = 2           -- default to MAC  code page
local CP_THREAD_ACP     = 3           -- current thread's ANSI code page
local CP_SYMBOL         = 42          -- SYMBOL translations
local CP_UTF7           = 65000       -- UTF-7 translation
local CP_UTF8           = 65001       -- UTF-8 translation

local LOADED = {}

local function load(type)
  if LOADED[type] then return LOADED[type] end
  local IMPL = require("path.win32." .. type ..".wcs")


  local wcstoutf8 = function (str) return IMPL.wcstombs(str, CP_UTF8) end
  local utf8towcs = function (str) return IMPL.mbstowcs(str, CP_UTF8) end

  local wcstoansi = function (str) return IMPL.wcstombs(str, CP_ACP)  end
  local ansitowcs = function (str) return IMPL.mbstowcs(str, CP_ACP)  end

  local wcstooem  = function (str) return IMPL.wcstombs(str, CP_OEM) end
  local oemtowcs  = function (str) return IMPL.mbstowcs(str, CP_OEM) end

  local _M = {
    MultiByteToWideChar = IMPL.MultiByteToWideChar;
    WideCharToMultiByte = IMPL.WideCharToMultiByte;
    mbstowcs            = IMPL.mbstowcs;
    wcstombs            = IMPL.wcstombs;
    wcstoutf8           = wcstoutf8;
    utf8towcs           = utf8towcs;
    wcstoansi           = wcstoansi;
    ansitowcs           = ansitowcs;
    wcstooem            = wcstooem;
    oemtowcs            = oemtowcs;
    CP = {
      ACP        = CP_ACP;
      OEM        = CP_OEM;
      MAC        = CP_MAC;
      THREAD_ACP = CP_THREAD_ACP;
      SYMBOL     = CP_SYMBOL;
      UTF7       = CP_UTF7;
      UTF8       = CP_UTF8;
    }
  }

  LOADED[type] = _M
  return _M
end

return {
  load = load
}