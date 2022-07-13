------------------------------------------------------------------
--
--  Author: Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Copyright (C) 2015 Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Licensed according to the included 'LICENSE' document
--
--  This file is part of lua-lluv-websocket library.
--
------------------------------------------------------------------

local uv     = require'lluv'
local ut     = require'lluv.utils'
local socket = require'lluv.websocket.luasocket'

local Client = ut.class() do

function Client:__init(ws)
  self._ws = ws or {}
  return self
end

function Client:connect(url, protocol)
  self._sock = socket.ws{ssl = self._ws.ssl, utf8 = self._ws.utf8,
    extensions = self._ws.extensions, auto_ping_response = self._ws.auto_ping_response,
  }

  if self._ws.timeout then
    self._sock:settimeout(self._ws.timeout)
  end

  local ok, err = self._sock:connect(url, protocol)
  if not ok then
    self._sock:close()
    self._sock = nil
    return nil, err
  end

  return self
end

function Client:send(data, opcode)
  local ok, err = self._sock:send(data, opcode)
  if ok then return true end
  return nil, err
end

function Client:receive()
  return self._sock:receive("*l")
end

function Client:close(code, reason)
  local code, reason = self._sock:close(code, reason)
  return code, reason
end

end

return function(...)
  return Client.new(...)
end
