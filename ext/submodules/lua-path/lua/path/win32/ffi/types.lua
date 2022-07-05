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

local ffi = require "ffi"

local C = ffi.C

local function pcdef(...)
  local ok, err = pcall( ffi.cdef, ... )
  if not ok then return nil, err end
  return err
end

local function pack(n, str)
  return [[
  #pragma pack(push)
  #pragma pack(1)
  ]] .. str ..[[
  #pragma pack(pop)
  ]]
end

local function ztrim(str)
  local pos = 1
  while true do
    pos = string.find(str, "\000\000", pos, true)
    if not pos then return str end
    if 0 ~= (pos % 2) then return string.sub(str, 1, pos - 1) end
    pos = pos + 1
  end
end

ffi.cdef [[
  static const int MAX_PATH = 260;
  typedef uint32_t DWORD;
  typedef char    CHAR;
  typedef wchar_t WCHAR;
  typedef uint32_t DEVICE_TYPE;
  typedef uint32_t ULONG;
  typedef void*    HANDLE;
  typedef void*    HLOCAL;
  typedef void*    LPVOID;
  typedef uint32_t BOOL;
]]

pcdef(pack(1, [[ // GET_FILEEX_INFO_LEVELS
  typedef enum _GET_FILEEX_INFO_LEVELS { 
    GetFileExInfoStandard,
    GetFileExMaxInfoLevel 
  } GET_FILEEX_INFO_LEVELS;
]]))

pcdef(pack(1, [[ // FILETIME
  typedef struct _FILETIME {
    DWORD dwLowDateTime;
    DWORD dwHighDateTime;
  } FILETIME, *PFILETIME;
]]))

pcdef(pack(1, [[ // WIN32_FILE_ATTRIBUTE_DATA
  typedef struct _WIN32_FILE_ATTRIBUTE_DATA {
    DWORD    dwFileAttributes;
    FILETIME ftCreationTime;
    FILETIME ftLastAccessTime;
    FILETIME ftLastWriteTime;
    DWORD    nFileSizeHigh;
    DWORD    nFileSizeLow;
  } WIN32_FILE_ATTRIBUTE_DATA, *PWIN32_FILE_ATTRIBUTE_DATA;
]]))

pcdef(pack(1, [[ // WIN32_FIND_DATAA
  typedef struct _WIN32_FIND_DATAA {
    DWORD    dwFileAttributes;
    FILETIME ftCreationTime;
    FILETIME ftLastAccessTime;
    FILETIME ftLastWriteTime;
    DWORD    nFileSizeHigh;
    DWORD    nFileSizeLow;
    DWORD    dwReserved0;
    DWORD    dwReserved1;
    CHAR     cFileName[MAX_PATH];
    CHAR     cAlternateFileName[14];
  } WIN32_FIND_DATAA, *PWIN32_FIND_DATAA;
]]))

pcdef(pack(1, [[ // WIN32_FIND_DATAW
  typedef struct _WIN32_FIND_DATAW {
    DWORD    dwFileAttributes;
    FILETIME ftCreationTime;
    FILETIME ftLastAccessTime;
    FILETIME ftLastWriteTime;
    DWORD    nFileSizeHigh;
    DWORD    nFileSizeLow;
    DWORD    dwReserved0;
    DWORD    dwReserved1;
    WCHAR    cFileName[MAX_PATH];
    WCHAR    cAlternateFileName[14];
  } WIN32_FIND_DATAW, *PWIN32_FIND_DATAW;
]]))

pcdef(pack(1, [[ // STORAGE_DEVICE_NUMBER
  typedef struct _STORAGE_DEVICE_NUMBER {
    DEVICE_TYPE DeviceType;
    ULONG       DeviceNumber;
    ULONG       PartitionNumber;
  } STORAGE_DEVICE_NUMBER, *PSTORAGE_DEVICE_NUMBER;
]]))

local CTYPES = {
  DWORD     = ffi.typeof("DWORD");
  PCHAR     = ffi.typeof("CHAR*");
  PWCHAR    = ffi.typeof("WCHAR*");
  VLA_CHAR  = ffi.typeof("CHAR[?]");
  VLA_WCHAR = ffi.typeof("WCHAR[?]");

  WIN32_FILE_ATTRIBUTE_DATA = ffi.typeof("WIN32_FILE_ATTRIBUTE_DATA");
  FILETIME                  = ffi.typeof("FILETIME");
  WIN32_FIND_DATAA          = ffi.typeof("WIN32_FIND_DATAA");
  WIN32_FIND_DATAW          = ffi.typeof("WIN32_FIND_DATAW");
  STORAGE_DEVICE_NUMBER     = ffi.typeof("STORAGE_DEVICE_NUMBER");
}

local c2lua 
c2lua = {

  WIN32_FILE_ATTRIBUTE_DATA = function(s) return {
    dwFileAttributes = s.dwFileAttributes;
    ftCreationTime   = {s.ftCreationTime.dwLowDateTime,   s.ftCreationTime.dwHighDateTime};
    ftLastAccessTime = {s.ftLastAccessTime.dwLowDateTime, s.ftLastAccessTime.dwHighDateTime};
    ftLastWriteTime  = {s.ftLastWriteTime.dwLowDateTime,  s.ftLastWriteTime.dwHighDateTime};
    nFileSize        = {s.nFileSizeLow,                   s.nFileSizeHigh};
  }end;

  WIN32_FIND_DATAA = function(s) 
    local res = c2lua.WIN32_FILE_ATTRIBUTE_DATA(s)
    res.cFileName = ffi.string(s.cFileName);
    return res
  end;

  WIN32_FIND_DATAW = function(s)
    local res = c2lua.WIN32_FILE_ATTRIBUTE_DATA(s)
    local pstr = ffi.cast(CTYPES.PCHAR, s.cFileName)
    local str = ffi.string(pstr, C.MAX_PATH * 2)
    res.cFileName = ztrim(str)
    return res
  end;

}

local _M = {
  INVALID_HANDLE   = ffi.cast("void*", -1);
  CTYPES           = CTYPES;
  CTYPE2LUA        = c2lua;
}

return _M
