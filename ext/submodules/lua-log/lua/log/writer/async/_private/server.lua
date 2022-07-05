local function prequire(...) 
  local ok, mod = pcall(require, ...)
  return ok and mod, mod or nil
end

local llthreads = prequire "llthreads2"
if not llthreads then
  llthreads = require "llthreads"
end

local runstring = function(code, ...)
  code = [[do
    local string = require "string"
    local os = require "os"
    local loadstring = loadstring or load
    local lua_init = os.getenv("lua_init")
    if lua_init and #lua_init > 0 then
      if lua_init:sub(1,1) == '@' then dofile((lua_init:sub(2)))
      else assert(loadstring(lua_init))() end
    end
  end;]] .. code 
  return llthreads.new(code, ...)
end

local sleep do repeat
  local socket = prequire "socket"
  if socket then
    sleep = function(ms) socket.sleep(ms / 1000) end
    break
  end

  local ztimer = prequire "lzmq.timer"
  if ztimer then
    sleep = ztimer.sleep
    break
  end

  --@todo find another way (use os.execute("sleep " .. ms)) on *nix

  sleep = function() end
  break
until true end

local Worker = [=[
(function(server, maker, logformat, ...)
  local Log = require "log"
  local logformat = require(logformat).new()

  local loadstring = loadstring or load
  local writer = assert(loadstring(maker))()

  require(server).run(writer, Log.close, logformat, ...)
end)(...)
]=]

local function run_server(server, maker, logformat, ...)
  if type(maker) == 'function' then maker = string.dump(maker) end

  assert(type(server)    == 'string')
  assert(type(maker)     == 'string')
  assert(type(logformat) == 'string')

  local child_thread = assert(runstring(Worker, server, maker, logformat, ...))
  child_thread:start(true, true)
  sleep(500)
  return
end

local Z
local function run_zserver(server, maker, logformat, ctx, ...)
  Z = Z or require "log.writer.net.zmq._private.compat"

  if type(maker) == 'function' then maker = string.dump(maker) end

  assert(type(server)    == 'string')
  assert(type(maker)     == 'string')
  assert(type(logformat) == 'string')
  assert(Z.is_ctx(ctx))

  local zthreads  = assert(Z.threads)
  local child_thread = assert((zthreads.run or zthreads.runstring)(ctx, Worker, server, maker, logformat, ...))
  child_thread:start(true)
  return
end

local M = {}

M.run  = run_server
M.zrun = run_zserver

return M