------------------------------------------------------------------
--
--  Author: Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Copyright (C) 2014-2017 Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Licensed according to the included 'LICENSE' document
--
--  This file is part of lua-lluv library.
--
------------------------------------------------------------------

----------------------------------------------------------------------------
-- Implementation of LuaSocket interface.
--
-- Known wont fix problem:
--  - send does not return number of sended bytes
--  - send may not detects closed socket
--  - send do not wait until large data will be sended
----------------------------------------------------------------------------

local trace -- = function(...) print(os.date("[LLS][%x %X]"), ...) end

local uv = require "lluv"
local ut = require "lluv.utils"

local function _check_resume(status, ...)
  if not status then return error(..., 3) end
  return ...
end

local function co_resume(...)
  return _check_resume(coroutine.resume(...))
end

local function CoGetAddrInfo(co, host, port)
  local terminated = false

  uv.getaddrinfo(host, port, {
    family   = "inet";
    socktype = "stream";
    protocol = "tcp";
  }, function(_, err, res)
    if terminated then return end

    if err then co_resume(co, nil, err)
    else co_resume(co, res) end
  end)

  local ok, err = coroutine.yield()
  terminated = true

  return ok, err 
end

local EOF = uv.error(uv.ERROR_UV, uv.EOF)

----------------------------------------------------------------------------
local BaseSock = ut.class() do

function BaseSock:__init()
  self._co    = assert(coroutine.running())

  self._timer = assert(uv.timer():start(1000, function(tm)
    tm:stop()
    self:_resume(nil, "timeout")
  end):stop())

  self._wait = {
    read   = false;
    write  = false;
  }

  self._err = "closed"

  return self
end

function BaseSock:_resume(...)
  return co_resume(self._co, ...)
end

function BaseSock:_yield(...)
  return coroutine.yield(...)
end

function BaseSock:_unset_wait()
  for k in pairs(self._wait) do self._wait[k] = false end
end

function BaseSock:_waiting(op)
  if op then
    assert(nil ~= self._wait[op])
    return not not self._wait[op]
  end

  for k, v in pairs(self._wait) do
    if v then return true end
  end
end

function BaseSock:_start(op)
  if self._timeout then
    self._timer:again(self._timeout * 1000)
  end

  assert(not self:_waiting())

  assert(self._wait[op] == false, op)
  self._wait[op] = true
end

function BaseSock:_stop(op)
  if self._timer then
    self._timer:stop()
  end
  self:_unset_wait(op)
end

function BaseSock:_on_io_error(err)
  if trace then trace("BaseSock:_on_io_error", err, self:_waiting()) end

  -- This function can be called to closed socket in case when
  -- * we start write operation but write callback not called yet
  -- * in this time we recv error in read operation
  --   read callback invoke `_on_io_error` which set `_sock` to nil
  -- * after that libuv invoke write callback with ECONNRESET error
  --   and write callback call _on_io_error again
  if not self._sock then return end

  if err then
    self._raw_err, err = err, "closed"
    self._err = err
  end

  self._sock:stop_read()
  self._sock:close(function()
    if trace then trace("BaseSock:_on_io_error:close", self:_waiting()) end
    if self:_waiting() then
      self:_resume(nil, err)
    end
  end)

  self._timer:close()
  self._sock, self._timer = nil
end

function BaseSock:attach(co)
  assert(not self:_waiting())
  self._co = co or coroutine.running()
  return self
end

function BaseSock:interrupt(...)
  if self._co and self:_waiting() and self._co ~= coroutine.running() then
    self:_resume(nil, ...)
  end
end

function BaseSock:settimeout(sec)
  if sec and (sec <= 0) then sec = nil end
  self._timeout = tonumber(sec)
  return self
end

function BaseSock:setoption()
  return nil, "NYI"
end

function BaseSock:getsockname()
  if not self._sock then return nil, self._err end

  return self._sock:getsockname()
end

function BaseSock:getpeername()
  if not self._sock then return nil, self._err end

  return self._sock:getpeername()
end

function BaseSock:getfd()
  if not self._sock then return -1 end
  return self._sock:fileno()
end

function BaseSock:socket()
  return self._sock
end

function BaseSock:close()
  if self._sock  then self._sock:close()  end
  if self._timer then self._timer:close() end
  self._sock, self._timer = nil
  return true
end

function BaseSock:shutdown()
  if not self._sock then return nil, self._err end

  local terminated
  self._sock:shutdown(function(cli, err)
    if terminated then return end
    if err then return self:_on_io_error(err) end
    return self:_resume(true)
  end)

  local ok, err = self:_yield()
  terminated = true

  if not ok then
    return nil, self._err
  end
  return ok, err
end

end
----------------------------------------------------------------------------

----------------------------------------------------------------------------
local TcpSock = ut.class(BaseSock) do
local super = ut.class.super(TcpSock)

local MAX_ACCEPT_COUNT = 10

function TcpSock:__init(s)
  self = assert(super(self, '__init'))

  self._buf   = assert(ut.Buffer.new("\r*\n", true))

  self._wait.conn   = false
  self._wait.accept = false

  if s then self._sock = s
  else self:_reset() end

  return self
end

function TcpSock:_start_read()
  self._sock:start_read(function(cli, err, data)
    if err then return self:_on_io_error(err) end

    if data then self._buf:append(data) end

    if self:_waiting("read") then return self:_resume(true) end
  end)
  return self
end

function TcpSock:_start_accept()
  if self._accept_list then return end

  self._accept_list = ut.Queue.new()

  self._sock:listen(function(srv, err)
    if err then return self:_on_io_error(err) end

    local cli, err = srv:accept()
    if not cli then return end

    while self._accept_list:size() > MAX_ACCEPT_COUNT do
      self._accept_list:pop():close()
    end

    self._accept_list:push(cli)

    if self:_waiting("accept") then
      return self:_resume(true, self._accept_list:pop())
    end
  end)

  return self
end

function TcpSock:receive(pat, prefix)
  if not self._sock then return nil, self._err end

  if prefix and type(pat) == 'number' then
    pat = pat - #prefix
    if pat <= 0 then return prefix end
  end

  pat = pat or "*l"
  if pat == "*r" then pat = nil end

  self:_start("read")

  if pat == "*a" then while true do
    local ok, err = self:_yield()

    if not ok then
      self:_stop("read")

      if err == 'timeout' then
        return nil, err, self._buf:read_all()
      end

      if err == 'closed' then
        return self._buf:read_all()
      end

      return nil, err
    end

  end end

  while true do
    local msg = self._buf:read(pat)
    if msg then
      self:_stop("read")
      if prefix then msg = prefix .. msg end
      return msg
    end

    local ok, err = self:_yield()
    if not ok then
      self:_stop("read")
      return nil, err, self._buf:read_all()
    end
  end
end

function TcpSock:send(data)
  if not self._sock then return nil, self._err end

  local terminated
  self:_start("write")
  self._sock:write(data, function(cli, err)
    if terminated then return end
    if err then return self:_on_io_error(err) end
    return self:_resume(true)
  end)

  local ok, err = self:_yield()
  terminated = true
  self:_stop("write")

  if not ok then
    return nil, self._err
  end
  return ok, err
end

function TcpSock:_reset()
  if self._sock then self._sock:close() end
  self._sock = uv.tcp()
end

function TcpSock:_connect(host, port)
  self:_start("conn")
  local res, err = CoGetAddrInfo(self._co, host, port)
  self:_stop("conn")

  if not res then return nil, err end

  local terminated, ok, err
  for i = 1, #res do
    self:_start("conn")

    self._sock:connect(res[i].address, res[i].port, function(cli, err)
      if terminated then return end
      return self:_resume(not err, err)
    end)

    ok, err = self:_yield()

    self:_stop("conn")

    if ok then break end

    self:_reset()
  end
  terminated = true

  if not ok then return nil, err end

  return self
end

function TcpSock:connect(host, port)
  local ok, err = self:_connect(host, port)
  if not ok then return nil, err end
  return self:_start_read()
end

function TcpSock:bind(host, port)
  if not self._sock then return nil, self._err end

  local ok, err = self._sock:bind(host, port)
  if not ok then
    self._sock:close()
    self._sock = uv.tcp()
    return nil, err
  end
  return self
end

function TcpSock:_accept()
  if not self._sock then return nil, self._err end

  self:_start_accept()

  local cli = self._accept_list:pop()
  if not cli then
    self:_start("accept")
    local ok, err = self:_yield()
    self:_stop("accept")
    if not ok then return nil, err end
    cli = err
  end

  return self.__class.new(cli)
end

function TcpSock:accept()
  local s, err = self:_accept()
  if not s then return nil, err end
  return s:_start_read()
end

function TcpSock:socket(clear)
  local s, b = self._sock, self._buf
  if clear then
    self._sock:stop_read()
    self._sock, self._buf = nil
    self:close()
  end
  return s, b
end

end
----------------------------------------------------------------------------

----------------------------------------------------------------------------
local UdpSock = ut.class(BaseSock) do
local super = ut.class.super(UdpSock)

function UdpSock:__init(s)
  self = assert(super(self, '__init'))

  self._buf   = assert(ut.Queue.new())

  if s then
    self._sock = s
    self:_start_read()
  else
    self._sock = assert(uv.udp())
  end

  self._peer = {}

  return self
end

function UdpSock:_start_read()
  if self._read_started then return end
  self._read_started = true
  self._sock:start_recv(function(cli, err, data, flag, host, port)
    if err then return self:_on_io_error(err) end

    if data and self:_is_peer(host, port) then
      self._buf:push{data, host, port}
    end

    if self:_waiting("read") then return self:_resume(true) end
  end)
  return self
end

function UdpSock:_is_peer(host, port)
  if not self._peer.host then return true end
  return (self._peer.host == host) and (self._peer.port == port)
end

function UdpSock:receivefrom(size)
  if not self._sock then return nil, self._err end

  while true do
    local data = self._buf:pop()
    if not data then break end
    if self:_is_peer(data[2], data[3]) then
      if size then return (data[1]:sub(1, size)), data[2], data[3] end
      return data[1], data[2], data[3]
    end
  end

  self:_start_read()

  self:_start("read")
  local ok, err = self:_yield()
  self:_stop("read")

  if not ok then return nil, err end

  assert(self._buf:size() > 0)

  local data = self._buf:pop()
  if size then return (data[1]:sub(1, size)), data[2], data[3] end
  return data[1], data[2], data[3]
end

function UdpSock:receive(...)
  local ok, host, port = self:receivefrom(...)
  if not ok then return nil, host end
  return ok
end

function UdpSock:sendto(data, host, port)
  if not self._sock then return nil, self._err end
  assert(host)
  assert(port)
  local terminated
  self:_start("write")
  self._sock:send(host, port, data, function(cli, err)
    if terminated then return end
    if err then return self:_on_io_error(err) end
    return self:_resume(true)
  end)

  local ok, err = self:_yield()
  terminated = true
  self:_stop("write")

  if not ok then
    return nil, self._err
  end
  return ok, err
end

function UdpSock:send(data)
  return self:sendto(data, assert(self:getpeername()))
end

function UdpSock:setsockname(host, port)
  if not self._sock then return nil, self._err end

  local ok, err = self._sock:bind(host, port)
  if not ok then
    self._sock:close()
    self._sock = uv.tcp()
    return nil, err
  end
  return self
end

function UdpSock:setpeername(host, port)
  if host == '*' then
    self._peer.host, self._peer.port = nil
  else
    self._peer.host = assert(host)
    self._peer.port = assert(port)
  end
  return self
end

function UdpSock:getpeername(host, port)
  return self._peer.host, self._peer.port
end

function TcpSock:socket(clear)
  local s, b = self._sock, self._buf
  if clear then
    self._sock:stop_recv()
    self._sock, self._buf = nil
    self:close()
  end
  return s, b
end

end
----------------------------------------------------------------------------

local function connect(host, port)
  local sok = TcpSock.new()
  local ok, err = sok:connect(host, port)
  if not ok then
    sok:close()
    return nil, err
  end
  return sok
end

local function bind(host, port)
  local sok = TcpSock.new()
  local ok, err = sok:bind(host, port)
  if not ok then
    sok:close()
    return nil, err
  end
  return sok
end

local SLEEP_TIMERS = {}

local function sleep(s)
  for co, timer in pairs(SLEEP_TIMERS) do
    if coroutine.status(co) == "dead" then
      timer:close()
      SLEEP_TIMERS[co] = nil
    end
  end

  if s <= 0 then return end

  local co = assert(coroutine.running())

  local timer = SLEEP_TIMERS[co]
  if not timer then
    timer = uv.timer():start(10000, function(self)
      self:stop()
      co_resume(co)
    end):stop()

    SLEEP_TIMERS[co] = timer
  end

  timer:again(math.floor(s * 1000))
  coroutine.yield()
end

local function toip(name)
  local res, err = CoGetAddrInfo(coroutine.running(), name)
  if not res then return nil, tostring(err) end
  return res[1].address, res
end

uv.signal_ignore(uv.SIGPIPE)

return {
  tcp     = TcpSock.new;
  udp     = UdpSock.new;
  connect = connect;
  bind    = bind;
  gettime = function() return math.floor(uv.now()/1000) end;
  sleep   = sleep;
  toip    = toip;

  _TcpSocket = TcpSock;
  _UdpSocket = UdpSock;
}
