------------------------------------------------------------------
--
--  Author: Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Copyright (C) 2016 Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Licensed according to the included 'LICENSE' document
--
--  This file is part of lua-lluv-websocket library.
--
------------------------------------------------------------------

---
-- Implement LuaSocket API on top of WebSocket
--
-- socket:bind(url, application)
--  e.g. socket:bind("ws://127.0.0.1:5555", "echo")
--
-- socket:connect(url, application)
--  e.g. socket:connect("ws://127.0.0.1:5555", "echo")
--
-- socket:receive([pat])
--  supports only 2 patterns
--  `*r` - return any recived data (can return not full frame)
--  `*l` - return entire frame
--  also `receive` returns `opcode` and `fin`
-- 
-- socket:send(frame[, opcode])
-- 

local trace -- = function(...) print(os.date("[LWS][%x %X]"), ...) end

local uv     = require "lluv"
local ut     = require "lluv.utils"
local socket = require "lluv.luasocket"
local ws     = require "lluv.websocket"

local unpack    = unpack or table.unpack
local tconcat   = table.concat
local tappend   = function(t, v) t[#t + 1] = v return t end

local WsSocket = ut.class(socket._TcpSocket) do

local function is_sock(s)
  local ts = type(s)
  if ts == 'userdata' then return true end
  if ts ~= 'table' then return false end
  return 
    s.start_read and
    s.write      and
    s.connect    and
    true
end

local function is_ws_sock(s)
  return is_sock(s) and 
    s._client_handshake and
    s._server_handshake and
    true
end

function WsSocket:__init(p)
  if is_sock(p) then
    WsSocket.__base.__init(self, p)
  else
    self._ws_opt = p
    WsSocket.__base.__init(self)
  end
  return self
end

function WsSocket:_reset()
  if self._sock then self._sock:close() end
  self._sock = ws.new(self._ws_opt)
end

function WsSocket:_start_read()
  self._sock:start_read("*f", function(cli, err, data, opcode, fin)
    if err then return self:_on_io_error(err) end

    if data then self._buf:append{data, opcode, fin} end

    if self:_waiting("read") then return self:_resume(true) end
  end)
  self._frame = {}
  return self
end

function WsSocket:receive(mode)
  while true do
    local frame, err = WsSocket.__base.receive(self, '*r')

    if not frame then return nil, err end

    if mode == '*r' then return unpack(frame) end

    local opcode = frame[2]

    if opcode == ws.PING or opcode == ws.PONG then
      return frame[1], opcode, true
    end

    if not self._opcode then
      self._frame, self._opcode = {}, opcode
    end

    tappend(self._frame, frame[1])

    if frame[3] then
      local msg, opcode = tconcat(self._frame), self._opcode
      self._frame, self._opcode = nil
      return msg, opcode, true
    end
  end
end

function WsSocket:send(data, opcode, fin)
  if not self._sock then return nil, self._err end

  local terminated
  local function fn(cli, err)
    if trace then trace("SEND CB>", self, #data, opcode, fin, fn) end
    if terminated then return end
    if err then return self:_on_io_error(err) end
    return self:_resume(true)
  end;
  if trace then trace("SEND>", self, #data, opcode, fin, fn) end

  self:_start("write")
  self._sock:write(data, opcode, fin, fn)

  local ok, err = self:_yield()
  terminated = true
  self:_stop("write")

  if not ok then
    return nil, self._err
  end
  return ok, err
end

function WsSocket:_connect(url, proto)
  self:_start("conn")

  local terminated

  self._sock:connect(url, proto, function(sock, err, headers)
    if terminated then return end
    return self:_resume(not err, err, headers)
  end)

  local ok, err, headers = self:_yield()
  terminated = true
  self:_stop("conn")

  if not ok then
    self:_reset()
    return nil, err
  end

  return self, headers
end

function WsSocket:connect(host, port)
  local ok, err = self:_connect(host, port)
  if not ok then return nil, err end
  local headers = err
  ok, err = self:_start_read()
  if not ok then return nil, err end
  return self, headers
end

function WsSocket:accept()
  local cli, err = self:_accept()
  if not cli then return nil, err end
  return cli:handshake()
end

function WsSocket:handshake()
  if not self._sock then return nil, self._err end

  local terminated
  self:_start("write")

  self._sock:handshake(function(cli, err, protocol, headers)
    if terminated then return end
    if err then return self:_on_io_error(err) end
    return self:_resume(true, nil, protocol, headers)
  end)

  local ok, err = self:_yield()
  terminated = true
  self:_stop("write")

  if not ok then
    self._sock:stop_read()
    return nil, self._err
  end

  local ok, err, protocol, headers = self:_start_read()
  if not ok then return nil, err end

  return self, protocol, headers
end

function WsSocket:__tostring()
  return "lluv.ws.luasocket (" .. tostring(self._sock) .. ")"
end

function WsSocket:close(code, reason)
  if not self._sock then return true end

  -- we can support close from any thread only if we do not need do any IO
  -- it possible for server socket.
  -- for data socket we just close TCP but it is not correct WebSocket close
  local clean
  if (not self._accept_list) and (self._co == coroutine.running()) then
    -- assume this is not server socket so we try 
    -- do correct close handshake and wait until done
    local terminated
    local function fn(cli, clean, code, reason)
      if trace then trace("CLOSE CB>", self, clean, code, reason) end
      if terminated then return end
      return self:_resume(clean, code, reason)
    end;
    if trace then trace("CLOSE>", self, code, reason, fn) end
    self:_start("write")
    self._sock:close(code, reason, fn)

    clean, code, reason = self:_yield()
    terminated = true
    self:_stop("write")
  else
    -- this is server socket so we can just close socket
    clean = not not self._accept_list
    self._sock:close()
  end

  -- clean up lluv.luasocket data
  self._timer:close()

  self._sock, self._timer = nil

  return clean, code, reason
end

end

return {
  ws           = WsSocket.new;
  TEXT         = ws.TEXT;
  BINARY       = ws.BINARY;
  PING         = ws.PING;
  PONG         = ws.PONG;
  CONTINUATION = ws.CONTINUATION;
  CLOSE        = ws.CLOSE;

  _WsSocket = WsSocket
}