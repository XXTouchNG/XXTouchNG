------------------------------------------------------------------
--
--  Author: Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Copyright (C) 2013-2018 Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Licensed according to the included 'LICENCE' document
--
--  This file is part of lua-path library.
--
------------------------------------------------------------------

local DIR_SEP = package.config:sub(1,1)
local IS_WINDOWS = DIR_SEP == '\\'

local function prequire(m) 
  local ok, err = pcall(require, m) 
  if not ok then return nil, err end
  return err
end

local fs

if not fs and IS_WINDOWS then
  local winfs = prequire"path.win32.fs"
  if winfs then
    local ok, mod = pcall(winfs.load, "ffi", "A")
    if not ok then ok, mod = pcall(winfs.load, "alien", "A") end
    fs = ok and mod
  end
end

if not fs and not IS_WINDOWS then
  fs = prequire"path.syscall.fs"
end

if not fs then
  fs = prequire"path.lfs.fs"
end

assert(fs, "you need installed LuaFileSystem or FFI/Alien (Windows only)")

return fs
