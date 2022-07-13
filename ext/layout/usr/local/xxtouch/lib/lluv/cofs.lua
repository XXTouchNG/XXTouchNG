------------------------------------------------------------------
--
--  Author: Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Copyright (C) 2014-2017 Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Licensed according to the included 'LICENSE' document
--
--  This file is part of lua-lluv library.
--
------------------------------------------------------------------
--
-- Known limitations
--  * `text` mode supports only for `*l` pattern.
--           Any other patterns works only as binary
--  * file:read does not support `*n` pattern (convert string to number)
--  * file:write supports only strings
--  * file:lines/fs.lines does not works on Lua 5.1 (yield from iterator)
--
--! @usage
-- ut.corun(function()
--   local f = cofs.open('test.txt', 'rb+')
--   f:read("*l", "*l")
--   f:seek('end')
--   f:write('\nhello', 'world')
-- end)

local uv = require "lluv"
local ut = require "lluv.utils"

local is_windows = (string.sub(package.config, 1, 1) == '\\')

local unpack = unpack or table.unpack

local function _check_resume(status, ...)
  if not status then return error(..., 3) end
  return ...
end

local function co_resume(...)
  return _check_resume(coroutine.resume(...))
end

local function co_yield(...)
  return coroutine.yield(...)
end

local EOF = uv.error(uv.ERROR_UV, uv.EOF)

local TEXT_EOL   = is_windows and "\r\n" or "\n"

local BINARY_EOL = "\n"

local BUFFER_SIZE = 4096

local File = ut.class() do

function File:__init()
  self._co   = assert(coroutine.running())
  self._buf  = uv.buffer(BUFFER_SIZE)
  self._wait = false

  return self
end

function File:__tostring()
  local hash
  if self._fd then
    hash = string.match(tostring(self._fd), '%((.-)%)$')
  else
    hash = 'closed'
  end

  return string.format('Lua-UV cofs.file (%s)', hash)
end

function File:_resume(...)
  return co_resume(self._co, ...)
end

local function yield_ret(self, ...)
  self._wait = false
  return ...
end

function File:_yield(...)
  self._wait = true
  return yield_ret(self, coroutine.yield(...))
end

function File:attach(co)
  self._co = co or coroutine.running()
  return self
end

function File:interrupt(...)
  if self._co and self._wait and self._co ~= coroutine.running() then
    self:_resume(nil, ...)
  end
end

function File:open(path, mode)
  local terminated

  self._eol = string.find(mode, 'b', nil, true) and BINARY_EOL or TEXT_EOL

  -- uv suppots only binary mode
  mode = mode:gsub('[bt]', '')

  uv.fs_open(path, mode, function(file, err, path)
    if terminated then
      if file and not err then
        file:close()
      end
      return
    end

    if err then
      self:_resume(nil, err)
      return
    end

    self:_resume(file, path)
  end)

  local fd, err = self:_yield()
  terminated = true

  if not fd then return nil, err end

  self._fd, self._pos = fd, 0

  return self
end

function File:close()
  local terminated

  self._fd:close(function(file, err, result)
    if terminated then return end

    if err then return self:_resume(nil, err) end

    self:_resume(result)
  end)

  local ok, err = self:_yield()
  terminated = true

  self._fd, self._pos, self._stat = nil

  return ok, err
end

function File:_read_some(n)
  local terminated

  n = n or self._buf:size()

  assert(n <= self._buf:size())

  self._fd:read(self._buf, self._pos, 0, n, function(file, err, buffer, size)
    if terminated then return end

    if err then return self:_resume(nil, err) end

    if size == 0 then return self:_resume() end

    self._pos = self._pos + size
    self:_resume(buffer:to_s(size))
  end)

  local ok, err = self:_yield()
  terminated = true

  if not ok then return nil, err end

  return ok
end

function File:read_n(n)
  local chunk_size = self._buf:size()
  if n <= chunk_size then
    return self:_read_some(n)
  end
  local res = {}
  while n > 0 do
    local chunk, err = self:_read_some(math.min(chunk_size, n))
    if not chunk then
      if err then return nil, err, table.concat(res) end
      break
    end
    if #chunk == 0 then break end
    n = n - #chunk
    res[#res + 1] = chunk
  end
  if #res == 0 then return nil end
  return table.concat(res)
end

function File:read_all()
  return self:read_n(math.huge)
end

function File:read_line(keep)
  local res = ''
  while true do
    local chunk, err = self:_read_some()
    if not chunk then
      if err then return nil, err end
      if #res > 0 then return res end
      return nil -- EOF
    end
    if chunk == '' then return res end

    res = res .. chunk
    local i = string.find(res, self._eol, nil, true)

    if i then
      local rest_size = #res - (i - 1 + #self._eol)
      self._pos = self._pos - rest_size

      if keep then i = i + #self._eol end
      return string.sub(res, 1, i - 1)
    end
  end
end

function File:read_pat(pat)
  if pat == '*a'           then return self:read_all()      end
  if pat == nil            then return self:read_line()     end
  if pat == '*l'           then return self:read_line()     end
  if pat == '*L'           then return self:read_line(true) end
  if type(pat) == 'number' then return self:read_n(pat)     end

  error("invalid format '" .. tostring(pat), 2)
end

function File:read(p, ...)
  if not ... then return self:read_pat(p) end

  local res, i = {}, 1
  repeat
    local chunk, err = self:read_pat(p)
    if err and (not chunk) then return nil, err end
    res[i] = chunk
    p = select(i, ...)
    i = i + 1
  until not p

  return unpack(res, 1, i - 1)
end

local function lines(self)
  return self:read_line()
end

function File:lines()
  return lines, self
end

function File:write_string(str)
  local terminated

  self._fd:write(str, self._pos, function(file, err, ...)
    if terminated then return end

    if err then return self:_resume(nil, err) end

    self._pos = self._pos + #str

    self:_resume(...)
  end)

  local ok, err = self:_yield()
  terminated = true

  if not ok then return nil, err end

  return true
end

function File:write(s, ...)
  if not ... then return self:write_string(s) end

  local i = 1
  repeat
    local ok, err = self:write_string(s)
    if err and (not ok) then return nil, err end
    s = select(i, ...)
    i = i + 1
  until not s

  return true
end

function File:size()
  local stat, err = self:stat()
  if not stat then return nil, err end

  local size = stat.size

  return size
end

function File:seek(whence, offset)
  whence = whence or 'cur'
  offset = offset or 0

  local pos

  if whence == 'set' then
    pos = offset
  elseif whence == 'cur' then
    pos = self._pos + offset
  elseif whence == 'end' then
    local size, err = self:size()
    if not size then return nil, err end
    pos = size + offset
  else
    error("invalid option '" .. tostring(whence) .. "'", 2)
  end

  self._pos = math.max(0, pos)

  return self._pos
end

local function call_fs(self, fn, ...)
  local args, n = {...}, select('#', ...) + 1

  local terminated

  args[n] = function(file, err, ...)
    if terminated then return end

    if err then return self:_resume(nil, err) end

    self:_resume(...)
  end

  fn(self._fd, unpack(args, 1, n))

  local ok, err = self:_yield()

  terminated = true

  if not ok then return nil, err end

  return ok
end

function File:stat()
  return call_fs(self, self._fd.stat)
end

function File:sync()
  return call_fs(self, self._fd.sync)
end

function File:datasync()
  return call_fs(self, self._fd.datasync)
end

function File:truncate(offset)
  return call_fs(self, self._fd.truncate, offset or 0)
end

function File:chown(uid, gid)
  return call_fs(self, self._fd.chown, uid, gid)
end

function File:chmod(mod)
  return call_fs(self, self._fd.chmod, mod)
end

function File:utime(atime, mtime)
  return call_fs(self, self._fd.utime, atime, mtime)
end

end

local cofs = {}

local function call_fs(fn, ...)
  local co = coroutine.running()

  local args, n = {...}, select('#', ...) + 1

  local terminated

  args[n] = function(loop, err, ...)
    if terminated then return end

    if err then return co_resume(co, nil, err) end

    co_resume(co, ...)
  end

  fn(path, unpack(args, 1, n))

  local ok, err = co_yield()
  terminated = true

  return ok, err
end

function cofs.open(...)
  local file = File.new()
  return file:open(...)
end

function cofs.unlink(path)
  return call_fs(uv.fs_unlink, path)
end

function cofs.mkdtemp(path)
  return call_fs(uv.fs_mkdtemp, path)
end

function cofs.mkdir(path, mode)
  return call_fs(uv.fs_mkdir, path)
end

function cofs.rmdir(path)
  return call_fs(uv.fs_rmdir, path)
end

function cofs.scandir(path, flags)
  return call_fs(uv.fs_scandir, path, flags)
end

function cofs.stat(path)
  return call_fs(uv.fs_stat, path)
end

function cofs.lstat(path)
  return call_fs(uv.fs_lstat, path)
end

function cofs.rename(path, new)
  return call_fs(uv.fs_scandir, path, new)
end

function cofs.chmod(path, mode)
  return call_fs(uv.fs_chmod, path, mode)
end

function cofs.utime(path, atime, mtime)
  return call_fs(uv.fs_utime, path, atime, mtime)
end

function cofs.symlink(path, new)
  return call_fs(uv.fs_symlink, path, new)
end

function cofs.readlink(path)
  return call_fs(uv.fs_readlink, path)
end

function cofs.chown(path, uid, gid)
  return call_fs(uv.fs_chown, path, uid, gid)
end

function cofs.access(path, flags)
  return call_fs(uv.fs_access, path, flags)
end

function cofs.type(f)
  if getmetatable(f) ~= File then return nil end
  if f._fd then return 'file' end
  return 'closed file'
end

local function lines(file)
  local line = file:read_line()
  if not line then file:close() end
  return line
end

function cofs.lines(f)
  local file, err = cofs.open(f, 'r')
  if not file then error(tostring(err), 2) end
  return lines, file
end

return cofs
