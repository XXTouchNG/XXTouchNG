--
--  Author: Alexey Melnichuk <mimir@newmail.ru>
--
--  Copyright (C) 2013-2014 Alexey Melnichuk <mimir@newmail.ru>
--
--  Licensed according to the included 'LICENCE' document
--
--  This file is part of lua-lzqm library.
--

--- Wraps the low-level threads object.
--
-- @module llthreads2.ex

--
-- Notes for lzmq.threads.ex
-- When you create zmq socket in child thread and your main thread crash
-- lua state could be deadlocked if you use attached thread because it calls
-- in gc  thread join or context destroy and no one could be done.
-- So by default for zmq more convinient use dettached joinable thread.
--
-- Example with deadlock
-- local thread = zthreads.xfork(function(pipe)
--   -- break when context destroy
--   while pipe:recv() do end
-- end):start(false, true)
--

--
-- Note! Define this function prior all `local` definitions
--       to prevent use upvalue by accident
--
local bootstrap_code = require"string".dump(function(lua_init, prelude, code, ...)
  local loadstring = loadstring or load
  local unpack     = table.unpack or unpack

  local function load_src(str)
    local f, n
    if str:sub(1,1) == '@' then
      n = str:sub(2)
      f = assert(loadfile(n))
    else
      n = '=(loadstring)'
      f = assert(loadstring(str))
    end
    return f, n
  end

  local function pack_n(...)
    return { n = select("#", ...), ... }
  end

  local function unpack_n(t)
    return unpack(t, 1, t.n)
  end

  if lua_init and #lua_init > 0 then
    local init = load_src(lua_init)
    init()
  end

  local args

  if prelude and #prelude > 0 then
    prelude = load_src(prelude)
    args = pack_n(prelude(...))
  else
    args = pack_n(...)
  end

  local func
  func, args[0] = load_src(code)

  rawset(_G, "arg", args)
  arg = args

  return func(unpack_n(args))
end)

local ok, llthreads = pcall(require, "llthreads2")
if not ok then llthreads = require"llthreads" end

local os        = require"os"
local string    = require"string"
local table     = require"table"

local setmetatable, tonumber, assert = setmetatable, tonumber, assert

-------------------------------------------------------------------------------
local LUA_INIT = "LUA_INIT" do

local lua_version_t
local function lua_version()
  if not lua_version_t then 
    local version = assert(_G._VERSION)
    local maj,min = version:match("^Lua (%d+)%.(%d+)$")
    if maj then                         lua_version_t = {tonumber(maj),tonumber(min)}
    elseif not math.mod then            lua_version_t = {5,2}
    elseif table.pack and not pack then lua_version_t = {5,2}
    else                                lua_version_t = {5,2} end
  end
  return lua_version_t[1], lua_version_t[2]
end

local LUA_MAJOR, LUA_MINOR = lua_version()
local IS_LUA_51 = (LUA_MAJOR == 5) and (LUA_MINOR == 1)

local LUA_INIT_VER
if not IS_LUA_51 then
  LUA_INIT_VER = LUA_INIT .. "_" .. LUA_MAJOR .. "_" .. LUA_MINOR
end

LUA_INIT = LUA_INIT_VER and os.getenv( LUA_INIT_VER ) or os.getenv( LUA_INIT ) or ""

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
local thread_mt = {} do
thread_mt.__index = thread_mt

--- Thread object.
--
-- @type thread

--- Start thread.
--
-- @tparam ?boolean detached
-- @tparam ?boolean joinable
-- @return self
function thread_mt:start(...)
  local ok, err
  if select("#", ...) == 0 then ok, err = self.thread:start(true, true)
  else                          ok, err = self.thread:start(...) end
  if not ok then return nil, err end
  return self
end

--- Join thread.
--
-- @tparam ?number timeout Windows suppurts arbitrary value, but POSIX supports only 0
function thread_mt:join(...)
  return self.thread:join(...)
end

--- Check if thread still working.
-- You can call `join` to get returned values if thiread is not alive.
function thread_mt:alive()
  return self.thread:alive()
end

--- Check if thread was started.
-- 
function thread_mt:started()
  return self.thread:started()
end

--- Check if thread is detached.
-- This function returns valid value only for started thread.
function thread_mt:detached()
  return self.thread:detached()
end

--- Check if thread is joinable.
-- This function returns valid value only for started thread.
function thread_mt:joinable()
  return self.thread:joinable()
end

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
local threads = {} do

local function new_thread(lua_init, prelude, code, ...)
  if type(lua_init) == "function" then
    lua_init = string.dump(lua_init)
  end

  if type(prelude) == "function" then
    prelude = string.dump(prelude)
  end

  if type(code) == "function" then
    code = string.dump(code)
  end

  local thread = llthreads.new(bootstrap_code, lua_init, prelude, code, ...)
  return setmetatable({
    thread = thread,
  }, thread_mt)
end

--- Create new thread object
-- 
-- @tparam string|function|THREAD_OPTIONS source thread source code.
--
threads.new = function (code, ...)
  assert(code)

  if type(code) == "table" then
    local source = assert(code.source or code[1])
    local init = (code.lua_init == nil) and LUA_INIT or code.lua_init
    return new_thread(init, code.prelude, source, ...)
  end

  return new_thread(LUA_INIT, nil, code, ...)
end

end
-------------------------------------------------------------------------------

--- A table describe threads constructor options.
--
-- @tfield string|function source thread source code (or first value of table)
-- @tfield ?string|function prelude thread prelude code. This code can change thread arguments.
--  e.g. it can remove some values or change their type.
-- @lua_init ?string|function|false by default child lua state try use LUA_INIT environment variable
--  just like regular lua interpretator.
--
-- @table THREAD_OPTIONS

return threads
