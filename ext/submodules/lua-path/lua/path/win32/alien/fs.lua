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
local types = require "path.win32.alien.types"

local CTYPES           = types.CTYPES
local CTYPE2LUA        = types.CTYPE2LUA
local DWORD            = CTYPES.DWORD
local HANDLE           = CTYPES.HANDLE
local FILETIME         = CTYPES.FILETIME
local BOOL             = "uint"
local INVALID_HANDLE   = types.INVALID_HANDLE
local LPVOID           = "pointer"
local LPDWORD          = "ref " .. DWORD

local NULL             = nil
local WIN32_FIND_DATAA = CTYPES.WIN32_FIND_DATAA
local WIN32_FIND_DATAW = CTYPES.WIN32_FIND_DATAW

local kernel32             = assert(alien.load("kernel32.dll"))
local GetCurrentDirectoryA = assert(kernel32.GetCurrentDirectoryA)
local GetCurrentDirectoryW = assert(kernel32.GetCurrentDirectoryW)
local SetCurrentDirectoryA = assert(kernel32.SetCurrentDirectoryA)
local SetCurrentDirectoryW = assert(kernel32.SetCurrentDirectoryW)
local GetTempPathA         = assert(kernel32.GetTempPathA)
local GetTempPathW         = assert(kernel32.GetTempPathW)
local GetFileAttributesExA = assert(kernel32.GetFileAttributesExA)
local GetFileAttributesExW = assert(kernel32.GetFileAttributesExW)
local CopyFileA            = assert(kernel32.CopyFileA)
local CopyFileW            = assert(kernel32.CopyFileW)
local GetLastError         = assert(kernel32.GetLastError)
local FindFirstFileA       = assert(kernel32.FindFirstFileA)
local FindFirstFileW       = assert(kernel32.FindFirstFileW)
local FindNextFileA        = assert(kernel32.FindNextFileA)
local FindNextFileW        = assert(kernel32.FindNextFileW)
local FindClose_           = assert(kernel32.FindClose)
local RemoveDirectoryA     = assert(kernel32.RemoveDirectoryA)
local RemoveDirectoryW     = assert(kernel32.RemoveDirectoryW)
local CreateDirectoryA     = assert(kernel32.CreateDirectoryA)
local CreateDirectoryW     = assert(kernel32.CreateDirectoryW)
local MoveFileExA          = assert(kernel32.MoveFileExA)
local MoveFileExW          = assert(kernel32.MoveFileExW)
local DeleteFileA          = assert(kernel32.DeleteFileA)
local DeleteFileW          = assert(kernel32.DeleteFileW)
local CreateFileA          = assert(kernel32.CreateFileA)
local CreateFileW          = assert(kernel32.CreateFileW)
local CloseHandle_         = assert(kernel32.CloseHandle)
local SetFileTime_         = assert(kernel32.SetFileTime)
local FormatMessageA       = assert(kernel32.FormatMessageA)
local FormatMessageW       = assert(kernel32.FormatMessageW)
local LocalFree            = assert(kernel32.LocalFree)
local DeviceIoControl_     = assert(kernel32.DeviceIoControl)

GetCurrentDirectoryA:types{abi="stdcall", ret = DWORD, DWORD, LPVOID}
GetCurrentDirectoryW:types{abi="stdcall", ret = DWORD, DWORD, LPVOID}

SetCurrentDirectoryA:types{abi="stdcall", ret = BOOL, LPVOID}
SetCurrentDirectoryW:types{abi="stdcall", ret = BOOL, LPVOID}

CopyFileA:types{abi="stdcall", ret = BOOL, LPVOID, LPVOID, BOOL}
CopyFileW:types{abi="stdcall", ret = BOOL, LPVOID, LPVOID, BOOL}

GetTempPathA:types{abi="stdcall", ret = DWORD, DWORD, LPVOID}
GetTempPathW:types{abi="stdcall", ret = DWORD, DWORD, LPVOID}

GetFileAttributesExA:types{abi="stdcall", ret = DWORD, LPVOID, "int", LPVOID}
GetFileAttributesExW:types{abi="stdcall", ret = DWORD, LPVOID, "int", LPVOID}

FindFirstFileA:types{abi="stdcall", ret = HANDLE, LPVOID, LPVOID}
FindFirstFileW:types{abi="stdcall", ret = HANDLE, LPVOID, LPVOID}

FindNextFileA:types {abi="stdcall", ret = "int", HANDLE, LPVOID }
FindNextFileW:types {abi="stdcall", ret = "int", HANDLE, LPVOID }

FindClose_:types{abi="stdcall", ret = "int", HANDLE }

RemoveDirectoryA:types{abi="stdcall", ret = BOOL, LPVOID}
RemoveDirectoryW:types{abi="stdcall", ret = BOOL, LPVOID}

CreateDirectoryA:types{abi="stdcall", ret = BOOL, LPVOID, LPVOID}
CreateDirectoryW:types{abi="stdcall", ret = BOOL, LPVOID, LPVOID}

DeleteFileA:types{abi="stdcall", ret = BOOL, LPVOID}
DeleteFileW:types{abi="stdcall", ret = BOOL, LPVOID}

MoveFileExA:types{abi="stdcall", ret = BOOL, LPVOID, LPVOID, DWORD}
MoveFileExW:types{abi="stdcall", ret = BOOL, LPVOID, LPVOID, DWORD}

CreateFileA:types    {abi="stdcall", ret = HANDLE, LPVOID, DWORD, DWORD, LPVOID, DWORD, DWORD, LPVOID};
CreateFileW:types    {abi="stdcall", ret = HANDLE, LPVOID, DWORD, DWORD, LPVOID, DWORD, DWORD, LPVOID};

CloseHandle_:types   {abi="stdcall", ret = BOOL, HANDLE};

SetFileTime_:types   {abi="stdcall", ret = BOOL, HANDLE, LPVOID, LPVOID, LPVOID};

GetLastError:types{abi="stdcall", ret = DWORD}

FormatMessageW:types{abi="stdcall", ret = DWORD, DWORD, LPVOID, DWORD, DWORD, LPVOID, DWORD, LPVOID};
FormatMessageA:types{abi="stdcall", ret = DWORD, DWORD, LPVOID, DWORD, DWORD, LPVOID, DWORD, LPVOID};

LocalFree:types{abi="stdcall", ret = LPVOID, LPVOID};

DeviceIoControl_:types{abi="stdcall", ret = BOOL, HANDLE, DWORD, LPVOID, DWORD, LPVOID, DWORD, LPDWORD, LPVOID}

local function GetCurrentDirectory(u)
  local n = (u and GetCurrentDirectoryW or GetCurrentDirectoryA)(0, NULL)
  if n == 0 then
    local err = GetLastError()
    return nil, err
  end
  local buf = alien.buffer(u and n*2 or n)
  n = (u and GetCurrentDirectoryW or GetCurrentDirectoryA)(n, buf)
  if n == 0 then
    local err = GetLastError()
    return nil, err
  end
  return buf:tostring(u and n*2 or n )
end

local function SetCurrentDirectory(u, P)
  local ret
  if u then ret = SetCurrentDirectoryW(P .. "\0")
  else ret = SetCurrentDirectoryA(P) end
  if ret == 0 then
    local err = GetLastError()
    return nil, err
  end
  return true
end

local function GetTempPath(u)
  local n = (u and GetTempPathW or GetTempPathA)(0, NULL)
  if n == 0 then
    local err = GetLastError()
    return nil, err
  end
  local buf = alien.buffer(u and n*2 or n)
  n = (u and GetTempPathW or GetTempPathA)(n, buf)
  if n == 0 then
    local err = GetLastError()
    return nil, err
  end
  return buf:tostring(u and n*2 or n )
end

local function CopyFile(u, src, dst, flag)
  local ret
  if u then ret = CopyFileW(src .. "\0", dst .. "\0", flag and 1 or 0)
  else ret = CopyFileA(src, dst, flag and 1 or 0) end
  if ret == 0 then
    local err = GetLastError()
    return nil, err
  end
  return true
end

local function GetFileAttributesEx(u, P)
  local ret, info
  if u then 
    info = WIN32_FIND_DATAW:new()
    ret = GetFileAttributesExW(P .. "\0", 0, info())
  else
    info = WIN32_FIND_DATAA:new()
    ret = GetFileAttributesExA(P, 0, info())
  end
  if ret == 0 then
    local err = GetLastError()
    return nil, err
  end
  return info
end

local function FindClose(h)
  FindClose_(autil.gc_null(h))
end

local function FindFirstFile(u, P)
  local ret, fd, err
  if u then
    fd  = WIN32_FIND_DATAW:new()
    ret = FindFirstFileW(P .. "\0", fd())
  else
    fd  = WIN32_FIND_DATAA:new()
    ret = FindFirstFileA(P, fd())
  end

  if ret == INVALID_HANDLE then
    local err = GetLastError()
    return nil, err
  end

  ret = autil.gc_wrap(ret, FindClose_)
  return ret, fd
end

local function FindNextFile(u, h, fd)
  local ret
  if u then ret = FindNextFileW(h.value, fd())
  else ret = FindNextFileA(h.value, fd()) end
  return ret
end

local function RemoveDirectory(u, src)
  local ret
  if u then ret = RemoveDirectoryW(src .. "\0")
  else ret = RemoveDirectoryA(src) end
  if ret == 0 then
    local err = GetLastError()
    return nil, err
  end
  return true
end

local function CreateDirectory(u, src)
  local ret
  if u then ret = CreateDirectoryW(src .. "\0", NULL)
  else ret = CreateDirectoryA(src, NULL) end
  if ret == 0 then
    local err = GetLastError()
    return nil, err
  end
  return true
end

local function MoveFileEx(u, src, dst, flag)
  local ret
  if u then ret = MoveFileExW(src .. "\0", dst .. "\0", flag and flag or 0)
  else ret = MoveFileExA(src, dst, flag and flag or 0) end
  if ret == 0 then
    local err = GetLastError()
    return nil, err
  end
  return true
end

local function DeleteFile(u, src)
  local ret
  if u then ret = DeleteFileW(src .. "\0")
  else ret = DeleteFileA(src) end
  if ret == 0 then
    local err = GetLastError()
    return nil, err
  end
  return true
end

local function CloseHandle(h)
  return CloseHandle_(autil.gc_null(h))
end

local function CreateFile(u, P, access, share, sec, mode, attr, template)
  local p = P
  if u then p = p .. "\0" end

  local h = (u and CreateFileW or CreateFileA)(
    p, access, share, sec or NULL, mode, attr, template or NULL
  );

  if INVALID_HANDLE == h then
    local err = GetLastError()
    return nil, err
  end

  return autil.gc_wrap(h, CloseHandle_)
end

local function newft(t)
  if not t then return NULL end
  local v = FILETIME:new()
  v.dwLowDateTime, v.dwHighDateTime = t[1], t[2]
  return v
end

local function SetFileTime(h, c, a, m)
  local ctime, atime, mtime = newft(c), newft(a), newft(m)
  local ret = SetFileTime_(h.value, ctime and ctime(), atime and atime(), mtime and mtime())
  if ret ~= 0 then return true end
  return nil, GetLastError()
end

local FORMAT_MESSAGE_ALLOCATE_BUFFER = 0x00000100
local FORMAT_MESSAGE_IGNORE_INSERTS  = 0x00000200
local FORMAT_MESSAGE_FROM_STRING     = 0x00000400
local FORMAT_MESSAGE_FROM_HMODULE    = 0x00000800
local FORMAT_MESSAGE_FROM_SYSTEM     = 0x00001000
local FORMAT_MESSAGE_ARGUMENT_ARRAY  = 0x00002000
local FORMAT_MESSAGE_MAX_WIDTH_MASK  = 0x000000FF

local function ErrorMessage(u, dwErr, lang)
  local lpMsgBuf = alien.array(LPVOID, 1)
  lang = lang or 0
  local ret = (u and FormatMessageW or FormatMessageA)(
    FORMAT_MESSAGE_ALLOCATE_BUFFER + FORMAT_MESSAGE_FROM_SYSTEM + FORMAT_MESSAGE_IGNORE_INSERTS,
    NULL, dwErr, lang, lpMsgBuf.buffer, 0, NULL
  );

  if ret == 0 then
    local err = GetLastError() 
    return "", err
  end

  local str = alien.tostring(lpMsgBuf[1], ret)
  ret = LocalFree(lpMsgBuf[1]);
  return str;
end

local function DeviceIoControl(h, code, inBuffer, inBufferSize, outBuffer, outBufferSize)
  if inBuffer  == nil then inBuffer,  inBufferSize  = NULL, 0 end
  if outBuffer == nil then outBuffer, outBufferSize = NULL, 0 end
  local ret, dwTmp = DeviceIoControl_(h.value, code,
    inBuffer, inBufferSize, outBuffer, outBufferSize,
    0, NULL
  )
  if ret == 0 then
    local err = GetLastError()
    return nil, err
  end
  return ret, dwTmp
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

  local Info = CTYPES.STORAGE_DEVICE_NUMBER:new();
  local Info_size = CTYPES.STORAGE_DEVICE_NUMBER.size_

  local ret, dwTmp = DeviceIoControl(hPart, IOCTL_STORAGE_GET_DEVICE_NUMBER, 
    NULL, 0, Info(), Info_size
  )
  if not ret then err = dwTmp end
  if dwTmp ~= Info_size then ret, err = nil, GetLastError() end

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