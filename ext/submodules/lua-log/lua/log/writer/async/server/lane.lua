local on_lane_create = function()
  local loadstring = loadstring or load
  local lua_init = os.getenv("lua_init")
  if lua_init and #lua_init > 0 then
    if lua_init:sub(1,1) == '@' then dofile(lua_init:sub(2))
    else assert(loadstring(lua_init))() end
  end
end

local LOG   = require "log"
local lanes = require "lanes".configure{
  with_timers     = false,
  on_state_create = on_lane_create,
}
local pack  = require "log.logformat.proxy.pack".pack

local queue

local function context()
  queue = queue or assert(lanes.linda())
  return queue
end

local function log_thread_fn(maker, logformat, channel)
  local log_packer = require "log.logformat.proxy.pack"
  local logformat  = require (logformat).new()
  local unpack     = log_packer.unpack

  local loadstring = loadstring or load
  local writer = assert(assert(loadstring(maker))())
  while(true)do
    local key, val = queue:receive(1.0, channel)
    -- print(maker, channel, key, val)
    if not (key and val) then key, val = nil, 'timeout' end
    if key then 
      local msg, lvl, now = unpack(val)
      if msg and lvl and now then writer(logformat, msg, lvl, now) end
    else
      if val ~= 'timeout' then
        io.stderror:write('lane_logger: ', val)
      end
    end
  end
end

local function start_log_thread(...)
  local fn = assert(lanes.gen("*", log_thread_fn))
  return assert(fn(...))
end

local M = {}

M.run = function(channel, maker, logformat)
  logformat = logformat or "log.logformat.default"
  context() -- init context
  local child_thread = start_log_thread(maker, logformat, channel)
  LOG.add_cleanup(function() child_thread:cancel(60) end)
end

M.channel = context

return M