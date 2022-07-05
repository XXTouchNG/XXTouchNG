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

return function(lfs)
local os  = require "os"

local DIR_SEP = package.config:sub(1,1)
local IS_WINDOWS = DIR_SEP == '\\'

local _M = {
  DIR_SEP = DIR_SEP;
}

_M.currentdir = lfs.currentdir

_M.attributes = lfs.attributes

-- function _M.flags(P) end

local attrib = lfs.attributes

function _M.ctime(P)   return attrib(P,'change') end

function _M.atime(P)   return attrib(P,'access') end

function _M.mtime(P)   return attrib(P,'modification') end

function _M.size(P)    return attrib(P,'size') end

function _M.exists(P)  return attrib(P,'mode') ~= nil and P end

function _M.isdir(P)   return attrib(P,'mode') == 'directory' and P end

function _M.isfile(P)  return attrib(P,'mode') == 'file' and P end

function _M.islink(P)  return attrib(P,'mode') == 'link' and P end

_M.mkdir = lfs.mkdir

_M.rmdir = lfs.rmdir

_M.chdir = lfs.chdir

_M.link  = lfs.link

_M.setmode = lfs.setmode

function _M.copy(src, dst, force)
  if not IS_WINDOWS then
    if _M.isdir(src) or _M.isdir(dst) then
      return nil, 'can not copy directories'
    end
  end
  local f, err = io.open(src, 'rb')
  if not f then return nil, err end

  if not force then
    local t, err = io.open(dst, 'rb' )
    if t then 
      f:close()
      t:close()
      return nil, "file alredy exists"
    end
  end

  local t, err = io.open(dst, 'w+b')
  if not t then
    f:close()
    return nil, err
  end

  local CHUNK_SIZE = 4096
  while true do
    local chunk = f:read(CHUNK_SIZE)
    if not chunk then break end
    local ok, err = t:write(chunk)
    if not ok then
      t:close()
      f:close()
      return nil, err or "can not write"
    end
  end

  t:close()
  f:close()
  return true
end

function _M.move(src, dst, flags)
  if flags and _M.exists(dst) and _M.exists(src) then
    local ok, err = _M.remove(dst)
    -- do we have to remove dir?
    -- if not ok then ok, err = _M.rmdir(dst) end
    if not ok then return nil, err end
  end
  if (not IS_WINDOWS) and _M.exists(dst) then
    -- on windows os.rename return error when dst exists, 
    -- but on linux its just replace existed file
    return nil, "destination alredy exists"
  end
  return os.rename(src, dst)
end

function _M.remove(P)
  -- on windows os.remove can not remove dir
  if (not IS_WINDOWS) and _M.isdir(P) then
    return nil, "remove method can not remove dirs"
  end
  return os.remove(P)
end

local function splitpath(P) return string.match(P,"^(.-)[\\/]?([^\\/]*)$") end

function _M.tmpdir()
  if IS_WINDOWS then
    for _, p in ipairs{'TEMP', 'TMP'} do
      local dir = os.getenv(p)
      if dir and dir ~= '' then
        return dir
      end
    end
  end
  return (splitpath(os.tmpname()))
end

_M.dir = lfs.dir

_M.touch = lfs.touch

local function isdots(P)
  return P == '.' or P == '..'
end

local foreach_impl

local function do_foreach_recurse(base, match, callback, option)
  local dir_next, dir = lfs.dir(base)
  for name in dir_next, dir do if not isdots(name) then
    local path = base .. DIR_SEP .. name
    if _M.attributes(path,"mode") == "directory" then
      local ret, err = foreach_impl(path, match, callback, option)
      if ret or err then
        if dir then dir:close() end
        return ret, err
      end
    end
  end end
end

foreach_impl = function(base, match, callback, option)
  local tmp, origin_cb
  if option.delay then
    tmp, origin_cb, callback = {}, callback, function(base,name,fd) 
      table.insert(tmp, {base,name,fd})
    end;
  end

  if option.recurse and option.reverse == true then
    local ok, err = do_foreach_recurse(base, match, callback, option)
    if ok or err then return ok, err end
  end

  local dir_next, dir = lfs.dir(base)
  for name in dir_next, dir do if option.skipdots == false or not isdots(name) then
    local path = base .. DIR_SEP .. name
    local attr = _M.attributes(path)
    if not attr then return end

    if (option.skipdirs  and attr.mode == "directory")
       or (option.skipfiles and attr.mode == "file")
    then else
      if match(name) then
        local ret, err = callback(base, name, attr)
        if ret or err then
          if dir then dir:close() end
          return ret, err
        end
      end
    end

    local can_recurse = (not option.delay) and option.recurse and (option.reverse == nil)
    if can_recurse and attr.mode == "directory" and not isdots(name) then
      local ret, err = foreach_impl(path, match, callback, option)
      if ret or err then
        if dir then dir:close() end
        return ret, err
      end
    end
  end end

  if option.delay then
    for _, t in ipairs(tmp) do
      local ok, err = origin_cb(t[1], t[2], t[3])
      if ok or err then return ok, err end
    end
  end

  if option.recurse and (not option.reverse) then
    if option.delay or (option.reverse == false) then
      return do_foreach_recurse(base, match, origin_cb or callback, option)
    end
  end
end

local function filePat2rexPat(pat)
  if pat:find("[*?]") then
    local post = '$'
    if pat:find("*", 1, true) then 
      if pat:find(".", 1, true) then post = '[^.]*$'
      else post = '' end
    end
    pat = "^" .. pat:gsub("%.","%%."):gsub("%*",".*"):gsub("%?", ".?") .. post
  else
    pat = "^" .. pat:gsub("%.","%%.") .. "$"
  end
  if IS_WINDOWS then pat = pat:upper() end
  return pat
end

local function match_pat(pat)
  pat = filePat2rexPat(pat)
  return IS_WINDOWS
  and function(s) return nil ~= string.find(string.upper(s), pat) end
  or  function(s) return nil ~= string.find(s, pat)               end
end

function _M.foreach(base, callback, option)
  local base, mask = splitpath(base, DIR_SEP)
  if mask ~= '' then mask = match_pat(mask)
  else mask = function() return true end end
  return foreach_impl(base, mask, function(base, name, fd)
    return callback(base .. DIR_SEP .. name, fd)
  end, option or {})
end

local attribs = {
  f = function(base, name, fd) return base..DIR_SEP..name  end;
  p = function(base, name, fd) return base                 end;
  n = function(base, name, fd) return name                 end;
  m = function(base, name, fd) return fd.mode              end;
  a = function(base, name, fd) return fd                   end;
  z = function(base, name, fd) return fd.size              end;
  t = function(base, name, fd) return fd.modification      end;
  c = function(base, name, fd) return fd.change            end;
  l = function(base, name, fd) return fd.access            end;
}

local function make_attrib(str)
  local t = {}
  for i = 1, #str do 
    local ch = str:sub(i,i)
    local fn = attribs[ ch ]
    if not fn then return nil, 'unknown file attribute: ' .. ch end
    table.insert(t, fn)
  end

  return function(...)
    local res = {n = #t}
    for i, f in ipairs(t) do
      local ok, err = f(...)
      if ok == nil then return nil, err end
      table.insert(res, ok)
    end
    return res
  end
end

function _M.each_impl(option)
  if not option.file then return nil, 'no file mask present' end
  local base, mask = splitpath( option.file, DIR_SEP )
  if mask ~= '' then mask = match_pat(mask)
  else mask = function() return true end end

  local get_params, err = make_attrib(option.param or 'f')
  if not get_params then return nil, err end
  local unpack = unpack or table.unpack

  local filter = option.filter

  if option.callback then
    local callback = option.callback 

    local function cb(base, name, fd)
      local params = assert(get_params(base, name, fd))
      if filter and (not filter(unpack(params, 1, params.n))) then return end
      return callback(unpack(params, 1, params.n))
    end

    return foreach_impl(base, mask, cb, option)
  else
    local function cb(base, name, fd)
      local params = assert(get_params(base, name, fd))
      if filter and (not filter(unpack(params, 1, params.n))) then return end
      coroutine.yield(params)
    end
    local co = coroutine.create(function()
      foreach_impl(base, mask, cb, option)
    end)
    return function()
      local status, params = coroutine.resume(co)
      if status then if params then return unpack(params, 1, params.n) end
      else error(params, 2) end
    end
  end
end

local create_each = require "path.findfile".load

_M.each = create_each(_M.each_impl)

local function match_pat_selftest()

  local t = {
    ["*.txt"] = {
      [".txt"     ] = true;
      ["1.txt"    ] = true;
      ["1.txtdat" ] = true;
      [".txtdat"  ] = false;
      [".txt.dat" ] = false;
      [".dat.txt" ] = true;
    };
    ["*.txt*"] = {
      [".txt"     ] = true;
      ["1.txt"    ] = true;
      ["1.txtdat" ] = true;
      [".txtdat"  ] = true;
      [".txt.dat" ] = true;
      [".dat.txt" ] = true;
    };
    ["?.txt"] = {
      [".txt"     ] = true;
      ["1.txt"    ] = true;
      ["1.txtdat" ] = false;
      [".txtdat"  ] = false;
      [".txt.dat" ] = false;
      [".dat.txt" ] = false;
    };
    ["1?.txt"] = {
      [".txt"     ] = false;
      ["1.txt"    ] = true;
      ["1.txtdat" ] = false;
      [".txtdat"  ] = false;
      [".txt.dat" ] = false;
      [".dat.txt" ] = false;
    };
    ["1*.txt"] = {
      [".txt"     ] = false;
      ["1.txt"    ] = true;
      ["1.txtdat" ] = true;
      [".txtdat"  ] = false;
      [".txt.dat" ] = false;
      [".dat.txt" ] = false;
    };
  }

  local function test_match(pat, t)
    local cmp = match_pat(pat)
    for fname, status in pairs(t) do 
      if status ~= cmp(fname) then
        io.write("Pat: ", pat, " Name: ", fname, " Expected: ", tostring(status), " Got: ", tostring(cmp(fname)), "\n")
      end
    end
  end

  for k, v in pairs(t) do
    test_match(k,v)
  end

end

return _M
end