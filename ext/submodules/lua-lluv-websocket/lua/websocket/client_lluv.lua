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

local uv        = require 'lluv'
local ut        = require 'lluv.utils'
local websocket = require 'lluv.websocket'

local ocall     = function (f, ...) if f then return f(...) end end

local TEXT, BINARY = websocket.TEXT, websocket.BINARY

local Client = ut.class() do

local cleanup = function(self)
  if self._sock then self._sock:close() end
  self._sock = nil
end

local on_close = function(self, was_clean, code, reason)
  cleanup(self)
  ocall(self._on_close, self, was_clean, code, reason or '')
end

local on_error = function(self, err, dont_cleanup)
  if not dont_cleanup then cleanup(self) end

  ocall(self._on_error, self, err)
end

local on_open = function(self)
  self._state = 'OPEN'
  ocall(self._on_open, self)
end

local handle_socket_err = function(self, err)
  self._sock:close(function(self, clean, code, reason)
    on_error(self, err)
  end)
end

function Client:__init(ws)
  self._ws    = ws or {}

  self._on_send_done = function(sock, err)
    if err then handle_socket_err(self, err) end
  end

  return self
end

function Client:connect(url, proto)
  if self._sock then return end

  self._sock = websocket.new{ssl = self._ws.ssl, utf8 = self._ws.utf8,
    extensions = self._ws.extensions, auto_ping_response = self._ws.auto_ping_response,
  }

  self._sock:connect(url, proto, function(sock, err)
    if err then return on_error(self, err) end

    on_open(self)

    sock:start_read(function(sock, err, message, opcode)
      if err then
        return self._sock:close(function(sock, clean, code, reason)
          on_close(self, clean, code, reason)
        end)
      end

      if opcode == TEXT or opcode == BINARY then
        return ocall(self._on_message, self, message, opcode)
      end
    end)
  end)

  return self
end

function Client:on_close(handler)
  self._on_close = handler
end

function Client:on_error(handler)
  self._on_error = handler
end

function Client:on_open(handler)
  self._on_open = handler
end

function Client:on_message(handler)
  self._on_message = handler
end

function Client:send(message, opcode)
  self._sock:write(message, opcode, self._on_send_done)
end

function Client:close(code, reason, timeout)
  self._sock:close(code, reason, function(sock, clean, code, reason)
    on_close(self, clean, code, reason)
  end)

  return self
end

end

local ok, sync = pcall(require, 'websocket.client_lluv_sync')
if not ok then sync = nil end

return setmetatable({sync = sync},{__call = function(_, ...)
  return Client.new(...)
end})
