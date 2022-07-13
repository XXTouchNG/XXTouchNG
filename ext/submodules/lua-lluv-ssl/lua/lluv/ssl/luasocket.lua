------------------------------------------------------------------
--
--  Author: Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Copyright (C) 2015 Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Licensed according to the included 'LICENSE' document
--
--  This file is part of lua-lluv-ssl library.
--
------------------------------------------------------------------

local uv     = require "lluv"
local ut     = require "lluv.utils"
local socket = require "lluv.luasocket"

local SslSocket = ut.class(socket._TcpSocket) do

function SslSocket:__init(p, ...)
  assert(p, "SSL Socket or SSL Context expected")

  if p.handshake then return self:__init_skt(p) end

  return self:__init_ctx(p, ...)
end

function SslSocket:__init_skt(skt)
  assert(SslSocket.__base.__init(self, skt))
  self._sock:stop_read()
  return self
end

function SslSocket:__init_ctx(ctx, mode)
  self._ssl_ctx  = ctx
  self._ssl_mode = mode
  self._ssl_ctor = mode and ctx.server or ctx.client

  assert(SslSocket.__base.__init(self))
  self._sock:stop_read()
  return self
end

function SslSocket:_reset()
  if self._sock then self._sock:close() end
  self._sock = assert(self._ssl_ctor(self._ssl_ctx))
end

function SslSocket:connect(host, port)
  local ok, err = self:_connect(host, port)
  if not ok then return nil, err end
  return self:handshake()
end

function SslSocket:accept()
  local cli, err = self:_accept()
  if not cli then return nil, err end
  return cli:handshake()
end

function SslSocket:handshake()
  if not self._sock then return nil, self._err end

  local terminated
  self:_start("write")
  self._sock:handshake(function(cli, err)
    if terminated then return end
    if err then return self:_on_io_error(err) end
    return self:_resume(true)
  end)

  local ok, err = self:_yield()
  terminated = true
  self:_stop("write")

  if not ok then
    self._sock:stop_read()
    return nil, self._err
  end

  local ok, err = self:_start_read()
  if not ok then return nil, err end

  return self
end

function SslSocket:__tostring()
  return "lluv.ssl.luasocket (" .. tostring(self._sock) .. ")"
end

function SslSocket:getpeercert()
  return self._sock:getpeercert()
end

function SslSocket:verifypeer()
  return self._sock:verifypeer()
end

end

local function new_ssl(ctx, mode)
  return SslSocket.new(ctx, mode)
end

local function wrap_ssl(skt, ctx, mode)
  if not skt.handshake then -- this is Lua-UV TCP Socket
    assert(ctx, "SSL Context expected")
    if mode then skt = ctx:server(skt)
    else skt = ctx:client(skt) end
  end

  return SslSocket.new(skt)
end

return {
  ssl  = new_ssl;
  wrap = wrap_ssl;

  _SslSocket = SslSocket;
}
