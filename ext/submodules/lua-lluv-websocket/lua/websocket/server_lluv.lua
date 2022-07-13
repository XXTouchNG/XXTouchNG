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

local tconcat   = table.concat
local tappend   = function(t, v) t[#t + 1] = v return t end
local DummyLogger do
  local dummy = function() end

  DummyLogger = {
    info    = dummy;
    warning = dummy;
    error   = dummy;
    debug   = dummy;
    trace   = dummy;
  }
end

local function ocall(f, ...)
  if f then return f(...) end
end

local Client = ut.class() do

local TEXT, BINARY = websocket.TEXT, websocket.BINARY

local send     = function(self, msg, opcode, cb)
  if not cb then return self._sock:write(msg, opcode) end
  return self._sock:write(msg, opcode, cb)
end

local on_error = function(self, err)
  if self._clients[self._proto] ~= nil then self._clients[self._proto][self] = nil end

  ocall(self._on_error, self, err)
end

local on_close = function(self, was_clean, code, reason)
  if self._clients[self._proto] ~= nil then self._clients[self._proto][self] = nil end

  ocall(self._on_close, self, was_clean, code, reason or '')
end

function Client:__init(listener, sock, protocol)
  self._sock                    = assert(sock)
  self._proto                   = protocol
  self._started                 = false
  self._close_timer             = nil
  self._logger                  = listener:logger()
  self._clients                 = listener._clients -- reference to all clients on server
  self._clients[protocol][self] = true -- register self on server
  return self
end

function Client:on_error(handler)
  self._on_error = handler
  return self
end

function Client:on_message(handler)
  self._on_message = handler
  return self
end

function Client:on_close(handler)
  self._on_close = handler
  return self
end

function Client:send(message, opcode, cb)
  if cb then return send(self, message, opcode, function(sock, err)
    cb(self, err)
  end) end
  return send(self, message, opcode)
end

function Client:broadcast(...)
  for client in pairs(self._clients[self._proto]) do
    client:send(...)
  end
end

function Client:close(code, reason, timeout)
  if self._clients[self._proto] ~= nil then self._clients[self._proto][self] = nil end

  self._sock:close(code, reason, function(sock, clean, code, reason)
    on_close(self, clean, code, reason)
  end)

  return self
end

function Client:start()
  self._sock:start_read(function(sock, err, message, opcode)
    if err then
      return self._sock:close(function(sock, clean, code, reason)
        on_close(self, clean, code, reason, err)
      end)
    end

    return ocall(self._on_message, self, message, opcode)
  end)
end

end

local Listener = ut.class() do

local function on_error(self, err)
  self:logger().error('Websocket listen error:', err)
  ocall(self._on_error, self, err)
end

local function on_new_client(self, cli)
  cli:handshake(function(cli, err, protocol)
    if err then
      return on_error(self, 'Websocket Handshake failed: ' .. tostring(err))
    end

    self:logger().info('Handshake done:', protocol)

    local protocol_handler, protocol_index
    if protocol and self._handlers[protocol] then
      protocol_index   = protocol
      protocol_handler = self._handlers[protocol]
    elseif self._default_handler then
      -- true is the 'magic' index for the default handler
      protocol_index   = true
      protocol_handler = self._default_handler
    else
      cli:close()
      return on_error(self, 'Websocket Handshake failed: bad protocol - ' .. tostring(protocol))
    end

    self:logger().info('New client', protocol or 'default')

    local new_client = Client.new(self, cli, protocol_index)

    protocol_handler(new_client)

    new_client:start()
  end)
end

function Listener:__init(opts)
  assert(opts and (opts.protocols or opts.default))

  self._clients         = {[true] = {}}

  local handlers, protocols = {}, {}
  if opts.protocols then
    for protocol, handler in pairs(opts.protocols) do
      self._clients[protocol] = {}
      tappend(protocols, protocol)
      handlers[protocol] = handler
    end
  end

  self._protocols       = protocols
  self._handlers        = handlers
  self._default_handler = opts.default

  self._logger          = opts.logger or DummyLogger

  sock = websocket.new{ssl = opts.ssl, utf8 = opts.utf8,
    extensions = opts.extensions, auto_ping_response = opts.auto_ping_response,
  }

  local url = opts.url or ("ws://" .. (opts.interface or "*") .. ":" .. (opts.port or "80"))

  local ok, err = sock:bind(url, self._protocols)
  if not ok then
    sock:close()
    return nil, err
  end

  local h, p = sock:getsockname()
  self:logger().info("Server bind on: ", h .. ":" .. p)

  self._sock = sock

  sock:listen(function(sock, err)
    local cli, err = sock:accept()
    assert(cli, tostring(err))

    self:logger().info('New connection:', cli:getpeername())

    on_new_client(self, cli)
  end)

  return self
end

function Listener:close(keep_clients)
  if not self._sock then return end

  self._sock:close()
  if not keep_clients then
    for protocol, clients in pairs(self._clients) do
      for client in pairs(clients) do
        client:close()
      end
    end
  end
  self._sock = nil
end

function Listener:logger()
  return self._logger
end

function Listener:set_logger(logger)
  self._logger = logger or DummyLogger
  return self
end

function Listener:close(keep_clients)
  if not self._sock then return end
  self._sock:close()
  if not keep_clients then
    for protocol, clients in pairs(self._clients) do
      for client in pairs(clients) do
        client:close()
      end
    end
  end
end

function Listener:on_error(handler)
  self._on_error = handler
  return self
end

end

local function listen(...)
  return Listener.new(...)
end

return {
  listen = listen
}
