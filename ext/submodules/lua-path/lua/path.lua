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

local package = require "package"
local string  = require "string"
local table   = require "table"
local os      = require "os"
local io      = require "io"

local USE_ALIEN = true
local USE_FFI   = true
local USE_AFX   = true

local DIR_SEP = package.config:sub(1,1)
local IS_WINDOWS = DIR_SEP == '\\'

local PATH = {}

PATH.DIR_SEP    = DIR_SEP
PATH.IS_WINDOWS = IS_WINDOWS

--
-- PATH manipulation 

function PATH:unquote(P)
  if P:sub(1,1) == '"' and P:sub(-1,-1) == '"' then
    return (P:sub(2,-2))
  end
  return P
end

function PATH:quote(P)
  if P:find("%s") then
    return '"' .. P .. '"'
  end
  return P
end

function PATH:has_dir_end(P)
  return (string.find(P, '[\\/]$')) and true
end

function PATH:remove_dir_end(P)
  return (string.gsub(P, '[\\/]+$', ''))
end

function PATH:ensure_dir_end(P)
  return self:remove_dir_end(P) .. self.DIR_SEP 
end

function PATH:isunc(P)
  return (string.sub(P, 1, 2) == (self.DIR_SEP .. self.DIR_SEP)) and P
end

function PATH:normolize_sep(P)
  return (string.gsub(P, '\\', self.DIR_SEP):gsub('/', self.DIR_SEP))
end

PATH.normalize_sep = PATH.normolize_sep

function PATH:normolize(P)
  P = self:normolize_sep(P)
  local DIR_SEP = self.DIR_SEP

  local is_unc = self:isunc(P)
  while true do -- `/./` => `/`
    local n P,n = string.gsub(P, DIR_SEP .. '%.' .. DIR_SEP, DIR_SEP)
    if n == 0 then break end
  end
  while true do -- `//` => `/`
    local n P,n = string.gsub(P, DIR_SEP .. DIR_SEP, DIR_SEP)
    if n == 0 then break end
  end
  P = string.gsub(P, DIR_SEP .. '%.$', '')
  if (not IS_WINDOWS) and (P == '') then P = '/' end

  if is_unc then P = DIR_SEP .. P end

  local root, path = nil, P
  if is_unc then
    root, path = self:splitroot(P)
  end

  path = self:ensure_dir_end(path)
  while true do
    local first, last = string.find(path, DIR_SEP .. "[^".. DIR_SEP .. "]+" .. DIR_SEP .. '%.%.' .. DIR_SEP)
    if not first then break end
    path = string.sub(path, 1, first) .. string.sub(path, last+1)
  end
  P = path

  if root then -- unc
    assert(is_unc)
    P = P:gsub( '%.%.?' .. DIR_SEP , '')
    P = DIR_SEP .. DIR_SEP .. self:join(root, P)
  elseif self.IS_WINDOWS then 
    -- c:\..\foo => c:\foo
    -- \..\foo => \foo
    local root, path = self:splitroot(P)
    if root ~= '' or P:sub(1,1) == DIR_SEP then
      path = path:gsub( '%.%.?' .. DIR_SEP , '')
      P = self:join(root, path)
    end
  end

  if self.IS_WINDOWS and #P <= 3 and P:sub(2,2) == ':' then -- c: => c:\ or c:\ => c:\
    if #P == 2 then return P .. self.DIR_SEP end
    return P
  end

  if (not self.IS_WINDOWS) and (P == DIR_SEP) then return '/' end
  return self:remove_dir_end(P)
end

PATH.normalize = PATH.normolize

function PATH:join_(P1, P2)
  local ch = P2:sub(1,1)
  if (ch == '\\') or (ch == '/') then
    return self:remove_dir_end(P1) .. P2
  end
  return self:ensure_dir_end(P1) .. P2
end

function PATH:join(...)
  local t,n = {...}, select('#', ...)
  local r = t[1]
  for i = 2, #t do
    if self:isfullpath(t[i]) then
      r = t[i]
    else
      r = self:join_(r,t[i])
    end
  end
  return r
end

function PATH:splitext(P)
  local s1,s2 = string.match(P,"(.-[^\\/.])(%.[^\\/.]*)$")
  if s1 then return s1,s2 end
  return P, ''
end

function PATH:splitpath(P)
  return string.match(P,"^(.-)[\\/]?([^\\/]*)$")
end

function PATH:splitroot(P)
  if self.IS_WINDOWS then
    if self:isunc(P) then
      return string.match(P, [[^\\([^\/]+)[\]?(.*)$]])
    end
    if string.sub(P,2,2) == ':' then
      return string.sub(P,1,2), string.sub(P,4)
    end
    return '', P
  else
    if string.sub(P,1,1) == '/' then 
      return string.match(P,[[^/([^\/]+)[/]?(.*)$]])
    end
    return '', P
  end
end

function PATH:splitdrive(P)
  if self.IS_WINDOWS then
    return self:splitroot(P)
  end
  return '', P
end

function PATH:basename(P)
  local s1,s2 = self:splitpath(P)
  return s2
end

function PATH:dirname(P)
  return (self:splitpath(P))
end

function PATH:extension(P)
  local s1,s2 = self:splitext(P)
  return s2
end

function PATH:root(P)
  return (self:splitroot(P))
end

function PATH:isfullpath(P)
  return (self:root(P) ~= '') and P
end

function PATH:user_home()
  if IS_WINDOWS then
    return os.getenv('USERPROFILE') or PATH:join(os.getenv('HOMEDRIVE'), os.getenv('HOMEPATH'))
  end
  return os.getenv('HOME')
end

local function prequire(m) 
  local ok, err = pcall(require, m) 
  if not ok then return nil, err end
  return err
end

local fs = prequire "path.fs"

if fs then

--
-- PATH based on system 

local function assert_system(self)
  if PATH.IS_WINDOWS then assert(self.IS_WINDOWS) return end
  assert(not self.IS_WINDOWS)
end

if fs.flags then
  function PATH:flags(P, ...)
    assert_system(self)
    P = self:fullpath(P)
    return fs.flags(P, ...)
  end
end

function PATH:tmpdir()
  assert_system(self)
  return self:remove_dir_end(fs.tmpdir())
end

function PATH:tmpname()
  local P = os.tmpname()
  if self:dirname(P) == '' then
    P = self:join(self:tmpdir(), P)
  end
  return P
end

function PATH:size(P)
  assert_system(self)
  return fs.size(P)
end

function PATH:fullpath(P)
  if not self:isfullpath(P) then 
    P = self:normolize_sep(P)
    local ch1, ch2 = P:sub(1,1), P:sub(2,2)
    if ch1 == '~' then --  ~\temp
      P = self:join(self:user_home(), P:sub(2))
    elseif self.IS_WINDOWS and (ch1 == self.DIR_SEP) then -- \temp => c:\temp
      local root = self:root(self:currentdir())
      P = self:join(root, P)
    else
      P = self:join(self:currentdir(), P)
    end
  end

  return self:normolize(P)
end

function PATH:attrib(P, ...)
  assert_system(self)
  return fs.attributes(P, ...)
end

function PATH:exists(P)
  assert_system(self)
  return fs.exists(self:fullpath(P))
end

function PATH:isdir(P)
  assert_system(self)
  return fs.isdir(self:fullpath(P))
end

function PATH:isfile(P)
  assert_system(self)
  return fs.isfile(self:fullpath(P))
end

function PATH:islink(P)
  assert_system(self)
  return fs.islink(self:fullpath(P))
end

function PATH:ctime(P)
  assert_system(self)
  return fs.ctime(self:fullpath(P))
end

function PATH:mtime(P)
  assert_system(self)
  return fs.mtime(self:fullpath(P))
end

function PATH:atime(P)
  assert_system(self)
  return fs.atime(self:fullpath(P))
end

function PATH:touch(P, ...)
  assert_system(self)
  return fs.touch(self:fullpath(P), ...)
end

function PATH:currentdir()
  assert_system(self)
  return self:normolize(fs.currentdir())
end

function PATH:chdir(P)
  assert_system(self)
  return fs.chdir(self:fullpath(P))
end

function PATH:isempty(P)
  assert_system(self)
  local ok, err = fs.each_impl{
    file = self:ensure_dir_end(P), 
    callback = function() return 'pass' end;
  }
  if err then return nil, err end
  return ok ~= 'pass'
end

local date = prequire "date"
if date then
  local function make_getfiletime_as_date(fn)
    if date then
      return function(...)
        local t,e = fn(...)
        if not t then return nil, e end
        return date(t)
      end
    end
  end

  PATH.cdate = make_getfiletime_as_date( PATH.ctime );
  PATH.mdate = make_getfiletime_as_date( PATH.mtime );
  PATH.adate = make_getfiletime_as_date( PATH.atime );
end

function PATH:mkdir(P)
  assert_system(self)
  local P = self:fullpath(P)
  if self:exists(P) then return self:isdir(P) end
  local p = ''
  P = self:ensure_dir_end(P)
  for str in string.gmatch(P, '.-' .. self.DIR_SEP) do
    p = p .. str
    if self:exists(p) then
      if not self:isdir(p) then
        return nil, 'can not create ' .. p
      end
    else
      if IS_WINDOWS or p ~= DIR_SEP then
        local ok, err = fs.mkdir(self:remove_dir_end(p))
        if not ok then return nil, err .. ' ' .. p end
      end
    end
  end
  return P
end

function PATH:rmdir(P)
  assert_system(self)
  return fs.rmdir(self:fullpath(P))
end

function PATH:rename(from, to, force)
  assert_system(self)
  from = self:fullpath(from)
  to   = self:fullpath(to)
  return fs.move(from, to, force)
end

local each = require "path.findfile".load(function(opt)
  local has_dir_end = PATH:has_dir_end(opt.file)
  opt.file = PATH:fullpath(opt.file)
  if has_dir_end then opt.file = PATH:ensure_dir_end(opt.file) end
  return fs.each_impl(opt)
end)

function PATH:each(...)
  assert_system(self)
  return each(...)
end

local function copy_impl_batch(self, fs, src_dir, mask, dst_dir, opt)
  if not opt then opt = {} end

  local overwrite = opt.overwrite
  local accept    = opt.accept
  local onerror   = opt.error
  local chlen     = #fs.DIR_SEP
  local count     = 0

  local existed_dirs = {}
  local ok, err = fs.each_impl{file = src_dir .. fs.DIR_SEP .. mask,
    delay = opt.delay; recurse = opt.recurse; param = "pnm";
    skipdirs = opt.skipdirs; skipfiles = opt.skipfiles;
    callback = function(path, name, mode)
      local rel = string.sub(path, #src_dir + chlen + 1)
      if #rel > 0 then rel = rel .. fs.DIR_SEP .. name else rel = name end
      local dst = dst_dir .. fs.DIR_SEP .. rel
      local src = path .. fs.DIR_SEP .. name

      if accept then
        local ok = accept(src, dst, opt)
        if not ok then return end
      end

      local ok, err = true
      if mode == "directory" then
        if not existed_dirs[dst] then
          if not fs.isdir(dst) then
            ok, err = self:mkdir(dst)
          end
          existed_dirs[dst] = true
        end
      else
        local dir = self:splitpath(dst)
        if not existed_dirs[dir] then
          if not fs.isdir(dst) then
            ok, err = self:mkdir(dir)
          end
          existed_dirs[dir] = true
        end
        if ok then
          ok, err = fs.copy(src, dst, not overwrite)
        end
      end

      if not ok and onerror then
        if not onerror(err, src, dst, opt) then -- break
          return true
        end
      else
        count = count + 1
      end
    end;
  }
  if ok or err then return ok, err end
  return count
end

local function remove_impl_batch(fs, src_dir, mask, opt)
  if not opt then opt = {} end

  local overwrite = opt.overwrite
  local accept    = opt.accept
  local onerror   = opt.error
  local chlen     = #fs.DIR_SEP
  local count     = 0
  local delay     = (opt.delay == nil) and true or opt.delay

  local ok, err = fs.each_impl{file = src_dir .. fs.DIR_SEP .. mask,
    delay = delay; recurse = opt.recurse; reverse = true; param = "fm";
    skipdirs = opt.skipdirs; skipfiles = opt.skipfiles;
    callback = function(src, mode)
      if accept then
        local ok = accept(src, opt)
        if not ok then return end
      end

      local ok, err
      if mode == "directory" then ok, err = fs.rmdir(src)
      else ok, err = fs.remove(src) end

      if not ok and onerror then
        if not onerror(err, src, opt) then -- break
          return true
        end
      else
        count = count + 1
      end
    end;
  }
  if ok or err then return ok, err end
  return count
end

function PATH:remove_impl(P)
  if self:isdir(P) then return fs.rmdir(P) end
  return fs.remove(P)
end

function PATH:copy(from, to, opt)
  from = self:fullpath(from)
  to   = self:fullpath(to)

  if type(opt) == "boolean" then opt = {overwrite = opt} end

  local overwrite = opt and opt.overwrite
  local recurse   = opt and opt.recurse

  local src_dir, src_name = self:splitpath(from)
  if recurse or src_name:find("[*?]") then -- batch mode
    return copy_impl_batch(self, fs, src_dir, src_name, to, opt)
  end
  if self.mkdir then self:mkdir(self:dirname(to)) end
  return fs.copy(from, to, not not overwrite)
end

function PATH:remove(P, opt)
  assert_system(self)
  local P = self:fullpath(P)
  local dir, name = self:splitpath(P)
  if (opt and opt.recurse) or name:find("[*?]") then -- batch mode
    return remove_impl_batch(fs, dir, name, opt)
  end
  return self:remove_impl(P)
end

end -- fs 

do -- Python aliases
PATH.split    = PATH.splitpath
PATH.isabs    = PATH.isfullpath
PATH.normpath = PATH.normolize
PATH.abspath  = PATH.fullpath
PATH.getctime = PATH.ctime
PATH.getatime = PATH.atime
PATH.getmtime = PATH.mtime
PATH.getsize  = PATH.size
end

local function path_new(o)
  o = o or {}
  for k, f in pairs(PATH) do
    if type(f) == 'function' then
      o[k] = function(...)
        if o == ... then return f(...) end
        return f(o, ...)
      end
    else 
      o[k] = f
    end
  end
  return o
end

local function lock_table(t)
  return setmetatable(t,{
    __newindex = function()
      error("Can not change path library", 2)
    end;
    __metatable = "lua-path object";
  })
end

local M = path_new(require "path.module")

local path_cache = setmetatable({}, {__mode='v'})

function M.new(DIR_SEP)
  local is_win, sep

  if type(DIR_SEP) == 'string' then
    sep = DIR_SEP
    is_win = (DIR_SEP == '\\')
  elseif DIR_SEP ~= nil then
    assert(type(DIR_SEP) == 'boolean')
    is_win = DIR_SEP
    sep = is_win and '\\' or '/'
  else
    sep = M.DIR_SEP
    is_win = M.IS_WINDOWS
  end

  if M.DIR_SEP == sep then
    assert(M.IS_WINDOWS == is_win)
    return M
  end

  local o = path_cache[sep]

  if not o then
    o = path_new()
    o.DIR_SEP = sep
    o.IS_WINDOWS = is_win
    path_cache[sep] = lock_table(o)
  end

  return o
end

return lock_table(M)
