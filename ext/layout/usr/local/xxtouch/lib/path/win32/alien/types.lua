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
local autil = require "path.win32.alien.utils"

local function ztrim(str)
  local pos = 1
  while true do
    pos = string.find(str, "\000\000", pos, true)
    if not pos then return str end
    if 0 ~= (pos % 2) then return string.sub(str, 1, pos - 1) end
    pos = pos + 1
  end
end

assert( alien.sizeof("uint") == 4 )
assert( alien.sizeof("pointer") == alien.sizeof("size_t") )

local MAX_PATH    = 260
local CHAR        = function(N)  return "c" .. N end
local DWORD       = "I4"
local ULONG       = DWORD;
local DEVICE_TYPE = DWORD;

local FILETIME = autil.define_struct{
  {DWORD, "dwLowDateTime"  };
  {DWORD, "dwHighDateTime" };
}

local WIN32_FIND_DATAA = autil.define_struct{
  { DWORD           ,"dwFileAttributes"   };
  { FILETIME        ,"ftCreationTime"     };
  { FILETIME        ,"ftLastAccessTime"   };
  { FILETIME        ,"ftLastWriteTime"    };
  { DWORD           ,"nFileSizeHigh"      };
  { DWORD           ,"nFileSizeLow"       };
  { DWORD           ,"dwReserved0"        };
  { DWORD           ,"dwReserved1"        };
  { CHAR(MAX_PATH)  ,"cFileName"          };
  { CHAR(14)        ,"cAlternateFileName" };
}

local WIN32_FIND_DATAW = autil.define_struct{
  { DWORD           ,"dwFileAttributes"   };
  { FILETIME        ,"ftCreationTime"     };
  { FILETIME        ,"ftLastAccessTime"   };
  { FILETIME        ,"ftLastWriteTime"    };
  { DWORD           ,"nFileSizeHigh"      };
  { DWORD           ,"nFileSizeLow"       };
  { DWORD           ,"dwReserved0"        };
  { DWORD           ,"dwReserved1"        };
  { CHAR(2*MAX_PATH),"cFileName"          };
  { CHAR(2*14)      ,"cAlternateFileName" };
}

local WIN32_FILE_ATTRIBUTE_DATA = function(s) return {
  dwFileAttributes = s.dwFileAttributes;
  ftCreationTime   = {s.ftCreationTime.dwLowDateTime,   s.ftCreationTime.dwHighDateTime};
  ftLastAccessTime = {s.ftLastAccessTime.dwLowDateTime, s.ftLastAccessTime.dwHighDateTime};
  ftLastWriteTime  = {s.ftLastWriteTime.dwLowDateTime,  s.ftLastWriteTime.dwHighDateTime};
  nFileSize        = {s.nFileSizeLow,                   s.nFileSizeHigh};
}end;

local WIN32_FIND_DATAA2LUA = function(s) 
  local res = WIN32_FILE_ATTRIBUTE_DATA(s)
  res.cFileName = s.cFileName:gsub("%z.*$", "")
  return res
end;

local WIN32_FIND_DATAW2LUA = function(s)
  local res = WIN32_FILE_ATTRIBUTE_DATA(s)
  res.cFileName = ztrim(s.cFileName)
  return res
end;

local STORAGE_DEVICE_NUMBER = autil.define_struct{
  { DEVICE_TYPE , "DeviceType"      };
  { ULONG       , "DeviceNumber"    };
  { ULONG       , "PartitionNumber" };
}

local c2lua = {
  WIN32_FIND_DATAA = WIN32_FIND_DATAA2LUA;
  WIN32_FIND_DATAW = WIN32_FIND_DATAW2LUA;
}

local CTYPES = {
  HANDLE = "size_t";
  DWORD  = "uint";

  FILETIME = FILETIME;
  WIN32_FIND_DATAA      = WIN32_FIND_DATAA;
  WIN32_FIND_DATAW      = WIN32_FIND_DATAW;
  STORAGE_DEVICE_NUMBER = STORAGE_DEVICE_NUMBER;
}

return {
  CTYPES    = CTYPES;
  CTYPE2LUA = c2lua;
  INVALID_HANDLE = autil.cast(-1, CTYPES.HANDLE)
}