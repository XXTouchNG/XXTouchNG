------------------------------------------------------------------
--
--  Author: Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Copyright (C) 2015 Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Licensed according to the included 'LICENSE' document
--
--  This file is part of lua-lluv-poll-zmq library.
--
------------------------------------------------------------------

local uv  = require "lluv"
local ut  = require "lluv.utils"

-- This allows do not load zmq library
-- and we can use only OO interface of socket object
local ZMQ_POLLIN = 1

local uv_poll_zmq = ut.class() do

function uv_poll_zmq:__init(s)
  self._s = s
  self._h = uv.poll_socket(s:fd())
  return self
end

local function on_poll(self, err, events)
  if err then cb(self, err, self._s) else
    while self._read_cb and self._h:active() and not self._s:closed() do
      local ok, err = self._s:has_event(events)
      if ok == nil then self._read_cb(self, err, self._s) break end
      if ok then self._read_cb(self, nil, self._s) else break end
    end
  end

  if self._s:closed() then self._h:close() end
end

function uv_poll_zmq:start(events, cb)
  if not cb then cb, events = events end
  events = events or ZMQ_POLLIN
  self._read_cb = cb

  self._h:start(function(handle, err) on_poll(self, err, events) end)

  -- For `inproc` socket without this call socket never get in signal state.
  local ok, err = self._s:has_event(events)
  if ok == nil then
    -- context already terminated
    uv.defer(on_poll, self, err, events)
  elseif ok then
    -- socket already has events
    uv.defer(on_poll, self, nil, events)
  end

  return self
end

function uv_poll_zmq:stop()
  self._h:stop()
  self._read_cb = nil
  return self
end

function uv_poll_zmq:close(...)
  self._h:close(...)
  return self
end

end

return setmetatable({},{
  __call = function(_, ...)
    return uv_poll_zmq.new(...)
  end;
})
