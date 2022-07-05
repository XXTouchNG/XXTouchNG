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

local ffi   = require "ffi"
local types = require "path.win32.ffi.types"

ffi.cdef[[
  DWORD  __stdcall GetCurrentDirectoryA( DWORD nBufferLength, CHAR* lpBuffer);
  DWORD  __stdcall GetCurrentDirectoryW( DWORD nBufferLength, CHAR* lpBuffer);
  BOOL   __stdcall SetCurrentDirectoryA(const CHAR* lpPathName);
  BOOL   __stdcall SetCurrentDirectoryW(const CHAR* lpPathName);
  DWORD  __stdcall GetTempPathA(DWORD n, CHAR* buf);
  DWORD  __stdcall GetTempPathW(DWORD n, CHAR* buf);
  DWORD  __stdcall GetFileAttributesExA(const CHAR* lpFileName, GET_FILEEX_INFO_LEVELS fInfoLevelId, void* lpFileInformation);
  DWORD  __stdcall GetFileAttributesExW(const CHAR* lpFileName, GET_FILEEX_INFO_LEVELS fInfoLevelId, void* lpFileInformation);
  BOOL   __stdcall CopyFileA(const CHAR* src, const CHAR* dst, BOOL flag);
  BOOL   __stdcall CopyFileW(const CHAR* src, const CHAR* dst, BOOL flag);
  HANDLE __stdcall FindFirstFileA(const CHAR*  pattern, WIN32_FIND_DATAA* fd);
  HANDLE __stdcall FindFirstFileW(const CHAR*  pattern, WIN32_FIND_DATAW* fd);
  int    __stdcall FindNextFileA(HANDLE ff, WIN32_FIND_DATAA* fd);
  int    __stdcall FindNextFileW(HANDLE ff, WIN32_FIND_DATAW* fd);
  int    __stdcall FindClose(HANDLE ff);
  DWORD  __stdcall GetLastError();
  BOOL   __stdcall RemoveDirectoryA(const CHAR* src);
  BOOL   __stdcall RemoveDirectoryW(const CHAR* src);
  BOOL   __stdcall MoveFileExA(const CHAR* src, const CHAR* dst, DWORD flags);
  BOOL   __stdcall MoveFileExW(const CHAR* src, const CHAR* dst, DWORD flags);
  BOOL   __stdcall DeleteFileA(const CHAR* src);
  BOOL   __stdcall DeleteFileW(const CHAR* src);
  BOOL   __stdcall CreateDirectoryA(const CHAR* src, void* lpSecurityAttributes);
  BOOL   __stdcall CreateDirectoryW(const CHAR* src, void* lpSecurityAttributes);

  HANDLE __stdcall CreateFileA(const CHAR* lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode, void* lpSecurityAttributes,
    DWORD dwCreationDisposition, DWORD dwFlagsAndAttributes, HANDLE hTemplateFile
  );

  HANDLE __stdcall CreateFileW(const CHAR* lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode, void* lpSecurityAttributes,
    DWORD dwCreationDisposition, DWORD dwFlagsAndAttributes, HANDLE hTemplateFile
  );

  BOOL   __stdcall SetFileTime(HANDLE hFile, const FILETIME *lpCreationTime, const FILETIME *lpLastAccessTime,const FILETIME *lpLastWriteTime);

  BOOL   __stdcall CloseHandle(HANDLE hObject);

  DWORD  __stdcall FormatMessageA(DWORD dwFlags, void* lpSource, DWORD dwMessageId, DWORD dwLanguageId, LPVOID lpBuffer, DWORD nSize, void *Arguments);
  DWORD  __stdcall FormatMessageW(DWORD dwFlags, void* lpSource, DWORD dwMessageId, DWORD dwLanguageId, LPVOID lpBuffer, DWORD nSize, void *Arguments);
  HLOCAL __stdcall LocalFree( HLOCAL hMem );

  BOOL   __stdcall DeviceIoControl(HANDLE hDevice, DWORD dwIoControlCode, void* lpInBuffer, DWORD nInBufferSize, void* lpOutBuffer, DWORD nOutBufferSize, DWORD* lpBytesReturned, void* lpOverlapped);
]]

local C = ffi.C
local CTYPES           = types.CTYPES
local CTYPE2LUA        = types.CTYPE2LUA
local WIN32_FIND_DATAA = CTYPES.WIN32_FIND_DATAA
local WIN32_FIND_DATAW = CTYPES.WIN32_FIND_DATAW
local FILETIME         = CTYPES.FILETIME
local INVALID_HANDLE   = types.INVALID_HANDLE
local NULL             = ffi.cast("void*", 0)
local NULLSTR          = ffi.cast("CHAR*", NULL)

local function GetCurrentDirectory(u)
  local n = (u and C.GetCurrentDirectoryW or C.GetCurrentDirectoryA)(0,NULLSTR)
  if n == 0 then
    local err = C.GetLastError()
    return nil, err
  end

  local buf = ffi.new(CTYPES.VLA_CHAR, u and 2*n or n)

  n = (u and C.GetCurrentDirectoryW or C.GetCurrentDirectoryA)(n, buf)
  if n == 0 then
    local err = C.GetLastError()
    return nil, err
  end
  return ffi.string(buf, u and 2*n or n)
end

local function SetCurrentDirectory(u, P)
  local ret
  if u then ret = C.SetCurrentDirectoryW(P .. "\0")
  else ret = C.SetCurrentDirectoryA(P) end
  if ret == 0 then
    local err = C.GetLastError()
    return nil, err
  end
  return true
end

local function GetTempPath(u)
  local n = (u and C.GetTempPathW or C.GetTempPathA)(0,NULLSTR)
  if n == 0 then
    local err = C.GetLastError()
    return nil, err
  end

  local buf = ffi.new(CTYPES.VLA_CHAR, u and 2*n or n)

  n = (u and C.GetTempPathW or C.GetTempPathA)(n, buf)
  if n == 0 then
    local err = C.GetLastError()
    return nil, err
  end
  return ffi.string(buf, u and 2*n or n)
end

local function GetFileAttributesEx(u, P)
  local ret, info
  if u then 
    info = WIN32_FIND_DATAW()
    ret = C.GetFileAttributesExW(P .. "\0", C.GetFileExInfoStandard, info)
  else
    info = WIN32_FIND_DATAA()
    ret = C.GetFileAttributesExA(P, C.GetFileExInfoStandard, info)
  end
  if ret == 0 then
    local err = C.GetLastError()
    return nil, err
  end
  return info
end

local function CopyFile(u, src, dst, flag)
  local ret
  if u then ret = C.CopyFileW(src .. "\0", dst .. "\0", flag and 1 or 0)
  else ret = C.CopyFileA(src, dst, flag and 1 or 0) end
  if ret == 0 then
    local err = C.GetLastError()
    return nil, err
  end
  return true
end

local function FindFirstFile(u, P)
  local ret, fd, err
  if u then
    fd = WIN32_FIND_DATAW()
    ret = C.FindFirstFileW(P .. "\0", fd)
  else
    fd  = WIN32_FIND_DATAA()
    ret = C.FindFirstFileA(P, fd)
  end
  if ret == INVALID_HANDLE then
    local err = C.GetLastError()
    return nil, err
  end
  ffi.gc(ret, C.FindClose)
  return ret, fd
end

local function FindNextFile(u, h, fd)
  local ret
  if u then ret = C.FindNextFileW(h, fd)
  else ret = C.FindNextFileA(h, fd) end
  return ret
end

local function FindClose(h)
  C.FindClose(ffi.gc(h, nil))
end

local function RemoveDirectory(u, src)
  local ret
  if u then ret = C.RemoveDirectoryW(src .. "\0")
  else ret = C.RemoveDirectoryA(src) end
  if ret == 0 then
    local err = C.GetLastError()
    return nil, err
  end
  return true
end

local function DeleteFile(u, src)
  local ret
  if u then ret = C.DeleteFileW(src .. "\0")
  else ret = C.DeleteFileA(src) end
  if ret == 0 then
    local err = C.GetLastError()
    return nil, err
  end
  return true
end

local function MoveFileEx(u, src, dst, flag)
  local ret
  if u then ret = C.MoveFileExW(src .. "\0", dst .. "\0", flag and flag or 0)
  else ret = C.MoveFileExA(src, dst, flag and flag or 0) end
  if ret == 0 then
    local err = C.GetLastError()
    return nil, err
  end
  return true
end

local function CreateDirectory(u, src)
  local ret
  if u then ret = C.CreateDirectoryW(src .. "\0",NULL)
  else ret = C.CreateDirectoryA(src,NULL) end
  if ret == 0 then
    local err = C.GetLastError()
    return nil, err
  end
  return true
end

local function CreateFile(u, P, access, share, sec, mode, attr, template)
  local p = P
  if u then p = p .. "\0" end

  local h = (u and C.CreateFileW or C.CreateFileA)(
    p, access, share, sec or NULL, mode, attr, template or NULL
  );

  if INVALID_HANDLE == h then
    local err = C.GetLastError()
    return nil, err
  end

  return ffi.gc(h, C.CloseHandle)
end

local function CloseHandle(h)
  return C.CloseHandle(ffi.gc(h, nil))
end

local function newft(t)
  if not t then return ffi.cast("FILETIME*", NULL) end
  local v = FILETIME()
  v.dwLowDateTime, v.dwHighDateTime = t[1], t[2]
  return v
end

local function SetFileTime(h, c, a, m)
  local ctime, atime, mtime = newft(c), newft(a), newft(m)
  local ret = C.SetFileTime(h, ctime, atime, mtime)
  if ret ~= 0 then return true end
  return nil, C.GetLastError()
end

local FORMAT_MESSAGE_ALLOCATE_BUFFER = 0x00000100
local FORMAT_MESSAGE_IGNORE_INSERTS  = 0x00000200
local FORMAT_MESSAGE_FROM_STRING     = 0x00000400
local FORMAT_MESSAGE_FROM_HMODULE    = 0x00000800
local FORMAT_MESSAGE_FROM_SYSTEM     = 0x00001000
local FORMAT_MESSAGE_ARGUMENT_ARRAY  = 0x00002000
local FORMAT_MESSAGE_MAX_WIDTH_MASK  = 0x000000FF

local function ErrorMessage(u, dwErr, lang)
  local lpMsgBuf = ffi.new("LPVOID[1]", 0);
  lang = lang or 0
  local ret = (u and C.FormatMessageW or C.FormatMessageA)(
    FORMAT_MESSAGE_ALLOCATE_BUFFER + FORMAT_MESSAGE_FROM_SYSTEM + FORMAT_MESSAGE_IGNORE_INSERTS,
    NULL, dwErr, lang, lpMsgBuf, 0, NULL
  );

  if ret == 0 then
    local err = C.GetLastError() 
    return "", err
  end

  local str = ffi.cast(CTYPES.PCHAR, lpMsgBuf[0])
  str = ffi.string(str, u and 2 * ret or ret);
  ret = C.LocalFree(lpMsgBuf[0]);
  return str;
end

local function DeviceIoControl(h, code, inBuffer, inBufferSize, outBuffer, outBufferSize)
  if inBuffer  == nil then inBuffer,  inBufferSize  = NULL, 0 end
  if outBuffer == nil then outBuffer, outBufferSize = NULL, 0 end
  local dwTmp = ffi.new("DWORD[1]", 0)
  local ret   = C.DeviceIoControl(h, code,
    inBuffer, inBufferSize, outBuffer, outBufferSize,
    dwTmp, NULL
  )
  if ret == 0 then
    local err = C.GetLastError()
    return nil, err
  end

  return ret, dwTmp[0]
end

local FILE_FLAG_NO_BUFFERING           = 0x20000000
local FILE_ATTRIBUTE_NORMAL            = 0x00000080
local FILE_SHARE_READ                  = 0x00000001
local FILE_SHARE_WRITE                 = 0x00000002
local OPEN_EXISTING                    = 3
local IOCTL_STORAGE_GET_DEVICE_NUMBER  = 0x2D1080

local function DiskNumber(u, P)
  local p
  if u then p = "\\\0\\\0.\0\\\0" .. P .. "\0"
  else p = "\\\\.\\" .. P end

  -- Open partition
  local hPart, err = CreateFile(u, p, 0,
    FILE_SHARE_READ + FILE_SHARE_WRITE, NULL, OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL + FILE_FLAG_NO_BUFFERING, NULL
  );

  if not hPart then return nil, err end

  local Info = CTYPES.STORAGE_DEVICE_NUMBER();
  local Info_size = ffi.sizeof(CTYPES.STORAGE_DEVICE_NUMBER)

  local ret, dwTmp = DeviceIoControl(hPart, IOCTL_STORAGE_GET_DEVICE_NUMBER, 
    NULL, 0, Info, Info_size
  )
  if not ret then err = dwTmp end
  if dwTmp ~= Info_size then ret, err = nil, C.GetLastError() end

  CloseHandle(hPart)
  if not ret then return nil, err end
  return {
    Info.DeviceType,
    Info.DeviceNumber,
    Info.PartitionNumber,
  }
end

return {
  A = {
    GetCurrentDirectory   = function(...) return GetCurrentDirectory(false, ...) end;
    SetCurrentDirectory   = function(...) return SetCurrentDirectory(false, ...) end;
    GetTempPath           = function(...) return GetTempPath        (false, ...) end;
    GetFileAttributesEx   = function(...) return GetFileAttributesEx(false, ...) end;
    CopyFile              = function(...) return CopyFile           (false, ...) end;
    FindFirstFile         = function(...) return FindFirstFile      (false, ...) end;
    FindNextFile          = function(...) return FindNextFile       (false, ...) end;
    RemoveDirectory       = function(...) return RemoveDirectory    (false, ...) end;
    DeleteFile            = function(...) return DeleteFile         (false, ...) end;
    CreateDirectory       = function(...) return CreateDirectory    (false, ...) end;
    CreateFile            = function(...) return CreateFile         (false, ...) end;
    MoveFileEx            = function(...) return MoveFileEx         (false, ...) end;
    ErrorMessage          = function(...) return ErrorMessage       (false, ...) end;
    DiskNumber            = function(...) return DiskNumber         (false, ...) end;
    FindClose             = FindClose;
    CloseHandle           = CloseHandle;
    SetFileTime           = SetFileTime;
    DeviceIoControl       = DeviceIoControl;
    WIN32_FIND_DATA2TABLE = CTYPE2LUA.WIN32_FIND_DATAA;
    DIR_SEP               = "\\";
    ANY_MASK              = "*";
  };
  W = {
    GetCurrentDirectory   = function(...) return GetCurrentDirectory(true, ...) end;
    SetCurrentDirectory   = function(...) return SetCurrentDirectory(true, ...) end;
    GetTempPath           = function(...) return GetTempPath        (true, ...) end;
    GetFileAttributesEx   = function(...) return GetFileAttributesEx(true, ...) end;
    CopyFile              = function(...) return CopyFile           (true, ...) end;
    FindFirstFile         = function(...) return FindFirstFile      (true, ...) end;
    FindNextFile          = function(...) return FindNextFile       (true, ...) end;
    RemoveDirectory       = function(...) return RemoveDirectory    (true, ...) end;
    DeleteFile            = function(...) return DeleteFile         (true, ...) end;
    CreateDirectory       = function(...) return CreateDirectory    (true, ...) end;
    CreateFile            = function(...) return CreateFile         (true, ...) end;
    MoveFileEx            = function(...) return MoveFileEx         (true, ...) end;
    ErrorMessage          = function(...) return ErrorMessage       (true, ...) end;
    DiskNumber            = function(...) return DiskNumber         (true, ...) end;
    FindClose             = FindClose;
    CloseHandle           = CloseHandle;
    SetFileTime           = SetFileTime;
    DeviceIoControl       = DeviceIoControl;
    WIN32_FIND_DATA2TABLE = CTYPE2LUA.WIN32_FIND_DATAW;
    DIR_SEP               = "\\\000";
    ANY_MASK              = "*\000";
  };
}