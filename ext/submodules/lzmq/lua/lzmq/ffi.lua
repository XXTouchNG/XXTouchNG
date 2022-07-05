--
--  Author: Alexey Melnichuk <mimir@newmail.ru>
--
--  Copyright (C) 2013-2017 Alexey Melnichuk <mimir@newmail.ru>
--
--  Licensed according to the included 'LICENCE' document
--
--  This file is part of lua-lzqm library.
--

local LZMQ_VERSION   = "0.4.5-dev"
local LZMQ_NAME      = "lzmq.ffi"
local LZMQ_LICENSE   = "MIT"
local LZMQ_COPYRIGHT = "Copyright (c) 2013-2017 Alexey Melnichuk"

local lua_version_t
local function lua_version()
  if not lua_version_t then 
    local version = rawget(_G,"_VERSION")
    local maj,min = version:match("^Lua (%d+)%.(%d+)$")
    if maj then                         lua_version_t = {tonumber(maj),tonumber(min)}
    elseif not math.mod then            lua_version_t = {5,2}
    elseif table.pack and not pack then lua_version_t = {5,2}
    else                                lua_version_t = {5,2} end
  end
  return lua_version_t[1], lua_version_t[2]
end

local LUA_MAJOR, LUA_MINOR = lua_version()
local HAS_GC_TABLE = (LUA_MAJOR > 5) or ((LUA_MAJOR == 5) and (LUA_MINOR >= 2))

local api = require "lzmq.ffi.api"
local ffi = require "ffi"
local bit = api.bit

local make_weak_k do
  local mt = {__mode = "k"}
  make_weak_k = function() 
    return setmetatable({}, mt)
  end
end

local make_weak_kv do
  local mt = {__mode = "kv"}
  make_weak_kv = function() 
    return setmetatable({}, mt)
  end
end

local function bintohex(str)
  return (string.gsub(str, ".", function(p)
    return (string.format("%.2x", string.byte(p)))
  end))
end

local function ptrtohex(ptr)
  return bintohex(api.ptrtostr(ptr))
end

local function hashid(obj)
  obj = tostring(obj)
  return string.match(obj, ': (%x+)$') or obj
end

local FLAGS = api.FLAGS
local ERRORS = api.ERRORS
local ZMQ_LINGER = api.SOCKET_OPTIONS.ZMQ_LINGER[1]
local ZMQ_POLLIN = FLAGS.ZMQ_POLLIN


local unpack = unpack or table.unpack

local zmq     = {}
local Error   = {}
local Context = {}
local Socket  = {}
local Message = {}
local Poller  = {}
local StopWatch = {}

local NAME_PREFIX = "LuaZMQ: "

local function zerror(...) return Error:new(...) end

do -- Error
Error.__index = Error

local ERROR_CATEGORY = "ZMQ"

function Error:new(no)
  local o = setmetatable({
    errno = no or api.zmq_errno();
  }, self)
  return o
end

function Error:no()
  return self.errno
end

function Error:msg()
  return api.zmq_strerror(self.errno)
end

function Error:mnemo()
  return api.zmq_mnemoerror(self.errno)
end
Error.name = Error.mnemo

function Error:category()
  return ERROR_CATEGORY
end
Error.cat = Error.category

function Error:__eq(rhs)
  return self:no() == rhs:no()
end

function Error:__tostring()
  return string.format("[%s][%s] %s (%d)", ERROR_CATEGORY, self:mnemo(), self:msg(), self:no())
end

end

do -- Context
Context.__index = Context

local function check_context(self)
  assert(not self:closed())
  if self.shutdowned then assert(not self:shutdowned()) end
end

function Context:new(ptr)
  local ctx, opt
  if ptr then
    if(type(ptr) == 'table')then
      opt,ptr = ptr
    else
      ctx = api.deserialize_ptr(ptr)
      assert(ptr == api.serialize_ptr(ctx)) -- ensure correct convert
    end
  end
  if not ctx then
    ctx = api.zmq_ctx_new()
    if not ctx then return nil, zerror() end
  end

  local o = setmetatable({
    _private = {
      owner   = not ptr;
      sockets = make_weak_kv();
      ctx     = ctx;
      scount  = 0;
      hash    = ptrtohex(ctx);
    }
  }, self)

  if not HAS_GC_TABLE then
    ffi.gc(ctx, function() o:destroy() end)
  end

  if opt then
    for k, v in pairs(opt) do
      if type(k) == 'string' then
        local fn = o['set_' .. k]
        if fn then
          local ok, err = fn(o, v)
          if not ok then
            o:destroy()
            return nil, err
          end
        end
      end
    end
  end

  return o
end

if HAS_GC_TABLE then

-- wothout __gc method on socket object this counter is not correct
function Context:_inc_socket_count(n)
  assert((n == 1) or (n == -1))
  self._private.scount = self._private.scount + n
  assert(self._private.scount >= 0)
end

else

function Context:_inc_socket_count(n)
  assert((n == 1) or (n == -1))
end

end

function Context:_remove_socket(skt)
  self._private.sockets[skt:handle()] = nil
end

function Context:closed()
  return not self._private.ctx
end

local function Context_cleanup(self, linger)
  for _, skt in pairs(self._private.sockets) do
    skt:close(linger)
  end
  -- lua can remove skt from sockets but do not call finalizer
  -- for skt._private.skt so we enforce gc
  -- collectgarbage("collect")
  -- collectgarbage("collect")
end

function Context:destroy(linger)
  if self:closed() then return true end
  Context_cleanup(self, linger)

  if self._private.on_close then
    pcall(self._private.on_close)
  end

  if self._private.owner then
    api.zmq_ctx_term(self._private.ctx)
  end
  self._private.ctx = nil
  return true
end

Context.__gc = Context.destroy

function Context:on_close(fn)
  self._private.on_close = fn
  return true
end

if api.zmq_ctx_shutdown then

function Context:shutdown(linger)
  check_context(self)
  Context_cleanup(self, linger)

  if self._private.owner then
    api.zmq_ctx_shutdown(self._private.ctx)
  end
  self._private.shutdown = true
  return true
end

function Context:shutdowned()
  return not not self._private.shutdown
end

end

Context.term = Context.destroy

function Context:handle()
  check_context(self)
  return self._private.ctx
end

function Context:get(option)
  check_context(self)
  return api.zmq_ctx_get(self._private.ctx, option)
end

function Context:set(option, value)
  check_context(self)
  local ret = api.zmq_ctx_set(self._private.ctx, option, value)
  if ret == -1 then return nil, zerror() end
  return true
end

function Context:lightuserdata()
  check_context(self)
  local ptr = api.serialize_ptr(self._private.ctx)
  assert(self._private.ctx == api.deserialize_ptr(ptr))
  return ptr
end

for optname, optid in pairs(api.CONTEXT_OPTIONS) do
  local name = optname:sub(4):lower()
  Context["get" .. name] = function(self)
    return self:get(optid)
  end

  Context["set" .. name] = function(self, value)
    return self:set(optid, value)
  end
end

local SNAMES = {}
for n, v in pairs(api.SOCKET_TYPES) do
  n = string.sub(n, 5)
  SNAMES[n] = v
  SNAMES[v] = n
end

function Context:socket(stype, opt)
  check_context(self)
  if type(stype) == "table" then
    stype, opt = stype[1], stype
  end
  if type(stype) == "string" then
    stype = assert(SNAMES[stype], "Unknown socket type")
  end
  local skt = api.zmq_socket(self._private.ctx, stype)
  if not skt then return nil, zerror() end
  local o = setmetatable({
    _private = {
      ctx = self;
      skt = skt;
      hash = ptrtohex(skt);
      socket_type = SNAMES[stype] or string.format('%d', stype);
    }
  },Socket)
  self:_inc_socket_count(1)

  -- if not HAS_GC_TABLE then
  --   ffi.gc(skt, function() o:close() end)
  -- end

  if opt then
    for k, v in pairs(opt) do
      if type(k) == 'string' then
        local fn = o['set_' .. k]
        if fn then
          local ok, err, ext = fn(o, v)
          if not ok then
            o:close()
            return nil, err, ext
          end
        end
      end
    end

    if opt.bind then
      local ok, err, ext = o:bind(opt.bind)
      if not ok then
        o:close()
        return ok, err, ext
      end
    end

    if opt.connect then
      local ok, err, ext = o:connect(opt.connect)
      if not ok then
        o:close()
        return ok, err, ext
      end
    end

  end

  self:autoclose(o)
  return o
end

function Context:autoclose(skt)
  check_context(self)
  assert(self == skt._private.ctx)
  if not skt:closed() then
    self._private.sockets[skt:handle()] = skt
  end
  return true
end

-- wothout __gc method on socket object we can not support counter.
if HAS_GC_TABLE then
  function Context:socket_count()
    check_context(self)
    return self._private.scount
  end
else
  function Context:socket_count()
    check_context(self)
    local cnt = 0
    for _ in pairs(self._private.sockets) do
      cnt = cnt + 1;
    end
    return cnt
  end
end

function Context:__tostring()
  local str = string.format('%sContext (%s)',
    NAME_PREFIX, self._private.hash
  )
  if self:closed() then
    str = str .. ' - closed'
  end
  return str
end

end

do -- Socket
Socket.__index = Socket

-- we need only one zmq_msg_t struct to handle all recv
local tmp_msg = ffi.new(api.zmq_msg_t)

function Socket:closed()
  return not self._private.skt
end

function Socket:close(linger)
  if self:closed() then return true end

  if self._private.on_close then
    pcall(self._private.on_close)
  end

  if not self._private.dont_destroy then
    if self._private.ctx then
      self._private.ctx:_remove_socket(self)
      self._private.ctx:_inc_socket_count(-1)
    end

    if linger then
      api.zmq_skt_setopt_int(self._private.skt, ZMQ_LINGER, linger)
    end

    api.zmq_close(self._private.skt)
  end

  self._private.skt = nil
  self._private.ctx = nil
  return true
end

Socket.__gc = Socket.close

function Socket:handle()
  return self._private.skt
end

function Socket:reset_handle(h, own, close)
  local skt = self._private.skt

  if self._private.ctx then
    self._private.ctx:_remove_socket(self)
  end

  self._private.skt = assert(api.deserialize_ptr(h))
  if own ~= nil then 
    self._private.dont_destroy = not own
  end

  if not self._private.dont_destroy then
    ffi.gc(self._private.skt, api.zmq_close)
  end

  if self._private.ctx then
    self._private.ctx:autoclose(self)
  end

  if close then
    api.zmq_close(skt)
    return true
  end

  return api.serialize_ptr(ffi.gc(skt, nil))
end

function Socket:lightuserdata()
  return api.serialize_ptr(self:handle())
end

local function gen_skt_bind(bind)
  return function(self, addr)
    assert(not self:closed())
    if type(addr) == 'string' then
      local ret = bind(self._private.skt, addr)
      if -1 == ret then return nil, zerror() end
      return true
    end
    assert(type(addr) == 'table')
    for _, a in ipairs(addr) do
      local ret = bind(self._private.skt, a)
      if -1 == ret then return nil, zerror(), a end
    end
    return true
  end
end

Socket.bind       = gen_skt_bind(api.zmq_bind       )
Socket.unbind     = gen_skt_bind(api.zmq_unbind     )
Socket.connect    = gen_skt_bind(api.zmq_connect    )
Socket.disconnect = gen_skt_bind(api.zmq_disconnect )

local RANDOM_PORT_BASE = 0xC000
local RANDOM_PORT_MAX  = 0xFFFF

function Socket:bind_to_random_port(address, port, tries)
  port  = port or RANDOM_PORT_BASE
  tries = tries or (RANDOM_PORT_MAX - port + 1)

  assert(type(address) == 'string')
  assert((port > 0) and (port <= RANDOM_PORT_MAX), "invalid port number")
  assert(tries > 0, "invalid max tries value")

  local ok, err
  while((port <= RANDOM_PORT_MAX)and(tries > 0))do
    local a = address .. ':' .. tostring(port)
    ok, err = self:bind(a)
    if ok then return port end

    if (err:no() ~= ERRORS.EADDRINUSE) and (err:no() ~= ERRORS.EACCES) then
      local msg = err:msg()
      if msg ~= "Address in use" then 
        if not msg:lower():find("address .- in use") then
          break
        end
      end
    end

    port, tries = port + 1, tries - 1
  end

  return nil, err or zerror(ERRORS.EINVAL)
end

function Socket:send(msg, flags)
  assert(not self:closed())
  local ret = api.zmq_send(self._private.skt, msg, flags)
  if ret == -1 then return nil, zerror() end
  return true
end

function Socket:recv(flags)
  assert(not self:closed())
  local msg = api.zmq_msg_init(tmp_msg)
  if not msg then return nil, zerror() end
  local ret = api.zmq_msg_recv(msg, self._private.skt, flags)
  if ret == -1 then
    api.zmq_msg_close(msg)
    return nil, zerror()
  end
  local data = api.zmq_msg_get_data(msg)
  local more = api.zmq_msg_more(msg)
  api.zmq_msg_close(msg)
  return data, more ~= 0
end

function Socket:send_all(msg, flags, i, n)
  flags = flags or 0
  i = i or 1
  n = n or #msg
  assert(n >= i, "invalid range")

  if(flags ~= 0) and (flags ~= FLAGS.ZMQ_SNDMORE) then
    return nil, zerror(ERRORS.ENOTSUP)
  end
  for i = i, n - 1 do
    local str = assert(msg[i])
    local ok, err = self:send(str, FLAGS.ZMQ_SNDMORE)
    if not ok then return nil, err, i end
  end
  local ok, err = self:send(msg[n], flags)
  if not ok then return nil, err, n end
  return true
end

Socket.send_multipart = Socket.send_all

function Socket:sendx(...)
  return self:send_all({...}, 0, 1, select("#", ...))
end

function Socket:sendx_more(...)
  return self:send_all({...}, FLAGS.ZMQ_SNDMORE, 1, select("#", ...))
end

function Socket:sendv(...)
  local msg = table.concat{...}
  return self:send(msg, 0)
end

function Socket:sendv_more(...)
  local msg = table.concat{...}
  return self:send(msg, FLAGS.ZMQ_SNDMORE)
end

function Socket:send_more(msg, flags)
  flags = bit.bor(flags or 0, FLAGS.ZMQ_SNDMORE)
  return self:send(msg, flags)
end

function Socket:send_msg(msg, flags)
  return msg:send(self, flags)
end

function Socket:recv_all(flags)
  local res = {}
  while true do
    local data, more = self:recv(flags)
    if not data then return nil, more end
    table.insert(res, data)
    if not more then break end
  end
  return res
end

Socket.recv_multipart = Socket.recv_all

function Socket:recvx(flags)
  local ok, err, t = self:recv_all(flags)
  if not ok then
    if t then return nil, err, unpack(t) end
    return nil, err
  end
  return unpack(ok)
end

function Socket:recv_len(len, flags)
  assert(not self:closed())
  assert(type(len) == "number")
  assert(len >= 0)

  local data, len = api.zmq_recv(self._private.skt, len, flags)
  if not data then return nil, zerror() end

  return data, self:more(), len
end

function Socket:recv_msg(msg, flags)
  return msg:recv(self, flags)
end

function Socket:recv_new_msg(flags)
  local msg = Message:new()
  local ok, err = msg:recv(self, flags)
  if not ok then
    msg:close()
    return nil, err
  end
  return msg, err
end

if api.zmq_recv_event then
function Socket:recv_event(flags)
  assert(not self:closed())
  local event, value, address = api.zmq_recv_event(self._private.skt, flags)
  if not event then return nil, zerror() end
  return event, value, address
end
end

local function gen_getopt(getopt)
  return function(self, option)
    assert(not self:closed())
    local val = getopt(self._private.skt, option)
    if not val then return nil, zerror() end
    return val
  end
end

local function gen_setopt(setopt)
  return function(self, option, value)
    assert(not self:closed())
    local ret = setopt(self._private.skt, option, value)
    if -1 == ret then return nil, zerror() end
    return true
  end
end

Socket.getopt_int = gen_getopt(api.zmq_skt_getopt_int)
Socket.getopt_fdt = gen_getopt(api.zmq_skt_getopt_fdt)
Socket.getopt_i64 = gen_getopt(api.zmq_skt_getopt_i64)
Socket.getopt_u64 = gen_getopt(api.zmq_skt_getopt_u64)
Socket.getopt_str = gen_getopt(api.zmq_skt_getopt_str)
Socket.setopt_int = gen_setopt(api.zmq_skt_setopt_int)
Socket.setopt_i64 = gen_setopt(api.zmq_skt_setopt_i64)
Socket.setopt_u64 = gen_setopt(api.zmq_skt_setopt_u64)
Socket.setopt_str = gen_setopt(api.zmq_skt_setopt_str)

function Socket:setopt_str_arr(optname, optval)
  if type(optval) == "string" then
    return self:setopt_str(optname, optval)
  end
  assert(type(optval) == "table")
  for _, str in ipairs(optval) do
    local ok, err = self:setopt_str(optname, str)
    if not ok then return nil, err, str end
  end
  return true
end

for optname, params in pairs(api.SOCKET_OPTIONS) do
  local name    = optname:sub(5):lower()
  local optid   = params[1]
  local getname = "getopt_" .. params[3]
  local setname = "setopt_" .. params[3]
  local get = function(self) return self[getname](self, optid) end
  local set = function(self, value) return self[setname](self, optid, value) end
  if params[2] == "RW" then
    Socket["get_"..name], Socket["set_"..name] = get, set
  elseif params[2] == "RO" then
    Socket[name], Socket["get_"..name] = get, get
  elseif params[2] == "WO" then
    Socket[name], Socket["set_"..name] = set, set
  else
    error("Unknown rw mode: " .. params[2])
  end
end

if api.SOCKET_OPTIONS.ZMQ_IDENTITY_FD then

Socket.get_identity_fd = function(self, id)
  assert(type(id) == 'string')

  local val = api.zmq_skt_getopt_identity_fd(
    self._private.skt,
    api.SOCKET_OPTIONS.ZMQ_IDENTITY_FD[1],
    id
  )
  if not val then return nil, zerror() end
  return val
end

Socket.identity_fd = Socket.get_identity_fd

end

function Socket:more()
  local more, err = self:rcvmore()
  if not more then return nil, err end
  return more ~= 0
end

function Socket:on_close(fn)
  assert(not self:closed())
  self._private.on_close = fn
  return true
end

function Socket:context()
  return self._private.ctx
end

function Socket:monitor(addr, events)
  if type(addr) == 'number' then
    events, addr = addr
  end

  if not addr then
    addr = "inproc://lzmq.monitor." .. ptrtohex(self._private.skt)
  end

  events = events or api.EVENTS.ZMQ_EVENT_ALL

  local ret = api.zmq_socket_monitor(self._private.skt, addr, events)
  if -1 == ret then return nil, zerror() end

  return addr
end

function Socket:reset_monitor()
  local ret = api.zmq_socket_monitor(self._private.skt, api.NULL, 0)
  if -1 == ret then return nil, zerror() end

  return true
end

local poll_item = ffi.new(api.vla_pollitem_t, 1)

function Socket:poll(timeout, events)
  timeout = timeout or -1
  events  = events or ZMQ_POLLIN

  poll_item[0].socket  = self._private.skt
  poll_item[0].fd      = 0
  poll_item[0].events  = events
  poll_item[0].revents = 0

  local ret = api.zmq_poll(poll_item, 1, timeout)

  poll_item[0].socket  = api.NULL
  local revents = poll_item[0].revents

  if ret == -1 then return nil, zerror() end

  return (bit.band(events, revents) ~= 0), revents
end

function Socket:has_event(...)
  assert(select("#", ...) > 0)

  local events, err = self:events()
  if not events then return nil, err end

  local res = {...}
  for i = 1, #res do res[i] = (0 ~= bit.band(res[i], events)) end

  return unpack(res)
end

function Socket:__tostring()
  local str = string.format('%sSocket[%s] (%s)',
    NAME_PREFIX, self._private.socket_type, self._private.hash
  )
  if self:closed() then
    str = str .. ' - closed'
  end
  return str
end

end

do -- Message
Message.__index = Message

-- we need only one zmq_msg_t struct to handle resize Message.
-- Because of ffi.gc is too slow tmp_msg is always set 
-- ffi.gc(tmp_msg, api.zmq_msg_close).
-- Double call zmq_msg_close is valid.
local tmp_msg = ffi.gc(api.zmq_msg_init(), api.zmq_msg_close)
api.zmq_msg_close(tmp_msg);api.zmq_msg_close(tmp_msg);

function Message:new(str_or_len)
  local msg
  if not str_or_len then
    msg = api.zmq_msg_init()
  elseif type(str_or_len) == "number" then
    msg = api.zmq_msg_init_size(str_or_len)
  else
    msg = api.zmq_msg_init_string(str_or_len)
  end
  if not msg then return nil, zerror() end
  return Message:wrap(msg)
end

function Message:wrap(msg)
  return setmetatable({
    _private = {
      msg = ffi.gc(msg, api.zmq_msg_close);
    }
  }, self)
end

function Message:closed()
  return not self._private.msg
end

function Message:close()
  if self:closed() then return true end
  api.zmq_msg_close(ffi.gc(self._private.msg, nil))
  self._private.msg = nil
  return true
end

function Message:handle()
  return self._private.msg
end

local function gen_move(move)
  return function (self, ...)
    assert(not self:closed())
    if select("#", ...) > 0 then assert((...)) end
    local msg = ...
    if not msg then
      msg = move(self._private.msg)
      if not msg then return nil, zerror() end
      msg = Message:wrap(msg)
    elseif getmetatable(msg) == Message then
      if not move(self._private.msg, msg._private.msg) then
        return nil, zerror()
      end
      msg = self
    else
      if not move(self._private.msg, msg) then
        return nil, zerror()
      end
      msg = self
    end
    return msg
  end
end

Message.move = gen_move(api.zmq_msg_move)
Message.copy = gen_move(api.zmq_msg_copy)

function Message:size()
  assert(not self:closed())
  return api.zmq_msg_size(self._private.msg)
end

function Message:set_size(nsize)
  assert(not self:closed())
  local osize = self:size()
  if nsize == osize then return true end
  local msg = api.zmq_msg_init_size(tmp_msg, nsize)
  if nsize > osize then nsize = osize end

  if nsize > 0 then
    ffi.copy(
      api.zmq_msg_data(msg),
      api.zmq_msg_data(self._private.msg),
      nsize
    )
  end

  tmp_msg = self._private.msg
  api.zmq_msg_close(tmp_msg)

  -- we do not need set ffi.gc because of tmp_msg already set this
  self._private.msg = msg
  return true
end

function Message:data()
  assert(not self:closed())
  return api.zmq_msg_get_data(self._private.msg)
end

function Message:set_data(pos, str)
  if not str then str, pos = pos end
  pos = pos or 1
  assert(pos > 0)

  local nsize = pos + #str - 1
  local osize = self:size()
  if nsize <= osize then
    ffi.copy(
      api.zmq_msg_data(self._private.msg, pos - 1),
      str, #str
    )
    return true
  end
  local msg = api.zmq_msg_init_size(tmp_msg, nsize)
  if not msg then return nil, zerror() end
  if osize > pos then osize = pos end
  if osize > 0 then
    ffi.copy(
      api.zmq_msg_data(msg),
      api.zmq_msg_data(self._private.msg),
      osize
    )
  end
  ffi.copy(api.zmq_msg_data(msg, pos - 1),str)

  tmp_msg = self._private.msg
  api.zmq_msg_close(tmp_msg)

  -- we do not need set ffi.gc because of tmp_msg already set this
  self._private.msg = msg
  return true
end

function Message:send(skt, flags)
  assert(not self:closed())
  if getmetatable(skt) == Socket then
    skt = skt:handle()
  end
  local ret = api.zmq_msg_send(self._private.msg, skt, flags or 0)
  if ret == -1 then return nil, zerror() end
  return true
end

function Message:send_more(skt, flags)
  flags = bit.bor(flags or 0, FLAGS.ZMQ_SNDMORE)
  return self:send(skt, flags)
end

function Message:recv(skt, flags)
  assert(not self:closed())
  if getmetatable(skt) == Socket then
    skt = skt:handle()
  end
  local ret = api.zmq_msg_recv(self._private.msg, skt, flags or 0)
  if ret == -1 then return nil, zerror() end
  local more = api.zmq_msg_more(self._private.msg)
  return self, more ~= 0
end

function Message:pointer(...)
  assert(not self:closed())
  local ptr = api.zmq_msg_data(self._private.msg, ...)
  return ptr
end

function Message:set(option, value)
  assert(not self:closed())
  local ret = api.zmq_msg_set(self._private.msg, option, value)
  if ret == -1 then return nil, zerror() end
  return true
end

function Message:get(option)
  assert(not self:closed())
  local ret = api.zmq_msg_get(self._private.msg, option)
  if ret == -1 then return nil, zerror() end
  return ret
end

for optname, params in pairs(api.MESSAGE_OPTIONS) do
  local name    = optname:sub(5):lower()
  local optid   = params[1]
  local get     = function(self) return self:get(optid) end
  local set     = function(self, value) return self:set(optid, value) end

  if params[2] == "RW" then
    Message["get_"..name], Message["set_"..name] = get, set
  elseif params[2] == "RO" then
    Message[name], Message["get_"..name] = get, get
  elseif params[2] == "WO" then
    Message[name], Message["set_"..name] = set, set
  else
    error("Unknown rw mode: " .. params[2])
  end
end

-- define after MESSAGE_OPTIONS to overwrite ZMQ_MORE option

function Message:more()
  assert(not self:closed())
  return api.zmq_msg_more(self._private.msg) ~= 0
end

if api.zmq_msg_gets then

function Message:gets(option)
  assert(not self:closed())
  local value = api.zmq_msg_gets(self._private.msg, option)
  if not value then return nil, zerror() end
  return value
end

end

Message.__tostring = Message.data

end

do -- Poller
Poller.__index = Poller

function Poller:new(n)
  assert((n or 0) >= 0)

  local o = {
    _private = {
      items   = n and ffi.new(api.vla_pollitem_t, n);
      size    = n or 0;
      nitems  = 0;
      sockets = {};
    }
  }
  o._private.hash = hashid(o)

  return setmetatable(o,self)
end

-- ensure that there n empty items
function Poller:ensure(n)
  local empty = self._private.size - self._private.nitems
  if n <= empty then return true end
  local new = ffi.new(api.vla_pollitem_t, self._private.size + (n - empty))
  if self._private.items then
    ffi.copy(new, self._private.items, ffi.sizeof(api.zmq_pollitem_t) * self._private.nitems)
  end
  self._private.items = new
  return true
end

local function get_socket(skt)
  if type(skt) == "number" then
    return skt
  end

  if skt.socket then
     return skt:socket()
  end

  return skt
end

local function skt2id(skt)
  if type(skt) == "number" then
    return skt
  end
  return api.serialize_ptr(skt:handle())
end

local function item2id(item)
  if item.socket == api.NULL then
    return item.fd
  end
  return api.serialize_ptr(item.socket)
end

-- Poller.add method assume that zmq socket does not contain
-- `socket` method. So it can use this method to retreive real
-- zmq socket from any object that provide this method.
assert(Socket.socket == nil)

function Poller:add(skt, events, cb)
  assert(type(events) == 'number')
  assert(cb)
  self:ensure(1)
  local n = self._private.nitems
  local s = get_socket(skt)
  local h = skt2id(s)
  if type(s) == "number" then
    self._private.items[n].socket = api.NULL
    self._private.items[n].fd     = s
  else
    self._private.items[n].socket = s:handle()
    self._private.items[n].fd     = 0
  end
  self._private.items[n].events  = events
  self._private.items[n].revents = 0
  self._private.sockets[h] = {skt, cb, n}
  self._private.nitems = n + 1
  return true
end

function Poller:remove(skt)
  local items, nitems, sockets = self._private.items, self._private.nitems, self._private.sockets
  local h = skt2id(get_socket(skt))
  local params = sockets[h]
  if not params  then return true end

  sockets[h] = nil

  if nitems == 0 then return true end
  local skt_no =  params[3]
  assert(skt_no < nitems)
  
  nitems = nitems - 1
  self._private.nitems = nitems

  -- if we remove last socket
  if skt_no == nitems then return true end

  -- find last struct in array and copy it to removed item
  local last_item  = items[ nitems ]
  local last_param = sockets[ item2id(last_item) ]

  last_param[3] = skt_no
  items[ skt_no ].socket = last_item.socket
  items[ skt_no ].fd     = last_item.fd
  items[ skt_no ].events = last_item.events

  return true
end

function Poller:modify(skt, events, cb)
  if events ~= 0 and cb then
    local h = skt2id(skt)
    local params = self._private.sockets[h]
    if not params then return self:add(skt, events, cb) end
    self._private.items[ params[3] ].events  = events
    params[2] = cb
  else
    self:remove(skt)
  end
end

function Poller:count()
  return self._private.nitems
end

function Poller:poll(timeout)
  assert(type(timeout) == 'number')

  local items, nitems = self._private.items, self._private.nitems
  local ret = api.zmq_poll(items, nitems, timeout)
  if ret == -1 then return nil, zerror() end
  local n = 0
  for i = nitems-1, 0, -1 do
    local item = items[i]
    if item.revents ~= 0 then
      local params = self._private.sockets[item2id(item)]
      if params then
        params[2](params[1], item.revents)
      end
      n = n + 1
    end
  end
  return n
end

function Poller:start()
  local status, err
  self._private.is_running = true
  while self._private.is_running do
    status, err = self:poll(-1)
    if not status then
      return nil, err
    end
  end
  return true
end

function Poller:stop()
  self._private.is_running = nil
end

function Poller:__tostring()
  return string.format('%sPoller (%s)',
    NAME_PREFIX, self._private.hash
  )
end

end

do -- StopWatch

StopWatch.__index = StopWatch

function StopWatch:new()
  return setmetatable({
    _private = {}
  }, self)
end

function StopWatch:start()
  assert(not self._private.timer, "timer alrady started")
  self._private.timer = api.zmq_stopwatch_start()
  return self
end

function StopWatch:stop()
  assert(self._private.timer, "timer not started")
  local elapsed = api.zmq_stopwatch_stop(self._private.timer)
  self._private.timer = nil
  return elapsed
end

function StopWatch:close()
  if self._private.timer then
    api.zmq_stopwatch_stop(self._private.timer)
    self._private.timer = nil
  end
  return true
end

end

do -- zmq

zmq._VERSION   = LZMQ_VERSION
zmq._NAME      = LZMQ_NAME
zmq._LICENSE   = LZMQ_LICENSE
zmq._COPYRIGHT = LZMQ_COPYRIGHT

function zmq.version(unpack)
  local mj,mn,pt = api.zmq_version()
  if mj then
    if unpack then return mj,mn,pt end
    return {mj,mn,pt}
  end
  return nil, zerror()
end

function zmq.context(opt)
  return Context:new(opt)
end

function zmq.init(n)
  return zmq.context{io_threads = n}
end  

function zmq.init_ctx(ctx)
  return Context:new(ctx)
end

function zmq.init_socket(skt)
  local o = setmetatable({
    _private = {
      dont_destroy = true;
      skt          = api.deserialize_ptr(skt);
    }
  },Socket)

  return o
end

local real_assert = assert
function zmq.assert(...)
  if ... then return ... end
  local err = select(2, ...)
  if getmetatable(err) == Error then error(tostring(err), 2) end
  if type(err) == 'number'      then error(zmq.strerror(err), 2) end
  return error(err or "assertion failed!", 2)
end

function zmq.error(no)
  return Error:new(no)
end

function zmq.strerror(no)
  return string.format("[%s] %s (%d)", 
    api.zmq_mnemoerror(no),
    api.zmq_strerror(no),
    no
  )
end

function zmq.msg_init()          return Message:new()     end

function zmq.msg_init_size(size) return Message:new(size) end

function zmq.msg_init_data(str)  return Message:new(str)  end

for name, value in pairs(api.SOCKET_TYPES)       do zmq[ name:sub(5) ] = value end
for name, value in pairs(api.CONTEXT_OPTIONS)    do zmq[ name:sub(5) ] = value end
for name, value in pairs(api.SOCKET_OPTIONS)     do zmq[ name:sub(5) ] = value[1] end
for name, value in pairs(api.MESSAGE_OPTIONS)    do zmq[ name:sub(5) ] = value[1] end
for name, value in pairs(api.FLAGS)              do zmq[ name:sub(5) ] = value end
for name, value in pairs(api.DEVICE)             do zmq[ name:sub(5) ] = value end
for name, value in pairs(api.SECURITY_MECHANISM) do zmq[ name:sub(5) ] = value end
for name, value in pairs(api.EVENTS)             do zmq[ name:sub(5) ] = value end

zmq.errors = {}
for name, value in pairs(api.ERRORS) do 
  zmq[ name ] = value
  zmq.errors[name]  = value
  zmq.errors[value] = name
end

zmq.poller = {
  new = function(n) return Poller:new(n) end
}

function zmq.device(dtype, frontend, backend)
  local ret = api.zmq_device(dtype, frontend:handle(), backend:handle())
  if ret == -1 then return nil, zerror() end
  return true
end

function zmq.proxy(frontend, backend, capture)
  capture = capture and capture:handle() or api.NULL
  local ret = api.zmq_proxy(frontend:handle(), backend:handle(), capture)
  if ret == -1 then return nil, zerror() end
  return true
end

if api.zmq_proxy_steerable then

function zmq.proxy_steerable(frontend, backend, capture, control)
  capture = capture and capture:handle() or api.NULL
  control = control and control:handle() or api.NULL
  local ret = api.zmq_proxy_steerable(frontend:handle(), backend:handle(), capture, control)
  if ret == -1 then return nil, zerror() end
  return true
end

end

zmq.z85_encode = api.zmq_z85_encode

zmq.z85_decode = api.zmq_z85_decode

if api.zmq_curve_keypair then

function zmq.curve_keypair(...)
  local pub, sec = api.zmq_curve_keypair(...)
  if pub == -1 then return nil, zerror() end
  return pub, sec
end

end

if api.zmq_curve_public then

function zmq.curve_public(...)
  local pub = api.zmq_curve_public(...)
  if pub == -1 then return nil, zerror() end
  return pub
end

end

zmq.utils = {
  stopwatch = function() return StopWatch:new() end
}

end

return zmq
