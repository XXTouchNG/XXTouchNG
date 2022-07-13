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

local SSL = {
  _NAME      = "lluv.ssl";
  _VERSION   = "0.1.3-dev";
  _COPYRIGHT = "Copyright (C) 2015-2016 Alexey Melnichuk";
  _LICENSE   = "MIT";
}

local trace -- = function(...) print(os.date("[SSL][%x %X]"), ...) end

local traceback
if trace then
  local ok, stp = pcall(require, "StackTracePlus")
  if ok then traceback = stp.stacktrace
  else traceback = debug.traceback end
end

local uv  = require "lluv"
local ut  = require "lluv.utils"
local ssl = require "openssl"

local function text(msg)
  if msg then 
    return string.format("[0x%.8X]", #msg) .. (#msg > 50 and (msg:sub(1, 50) .."...") or msg)
  end
  return "[   NULL   ]"
end

local function hex(msg)
  local n = 50
  if msg then
    return string.format("[%.10d]", #msg) .. 
      string.gsub(msg:sub(1, n), ".", function(ch)
        return string.format("%.2x ", string.byte(ch))
      end) ..
      (#msg > n and "..." or "")
  end
  return "[   NULL   ]"
end

local function load(path)
  local f, err = io.open(path,'rb')
  if not f then return nil, err end
  local c = f:read('*a')
  f:close()
  return c
end

local function load_key(key, path, ...)
  local data, err = load(path)
  if not data then return nil, err end
  return key.read(data, ...)
end

local function chunks(msg, chunk_size, len)
  len = len or #msg
  return function(_, b)
    b = b + chunk_size
    if b > len then return nil end
    local e = b + chunk_size - 1
    if e > len then e = len end
    return b, (string.sub(msg, b, e))
  end, nil, -chunk_size + 1
end

local unpack = table.unpack or unpack

local function clone(t, o)
  o = o or {}
  for k, v in pairs(t) do
    o[k] = v
  end
  return o
end

local verify_map = {
  none                 = ssl.ssl.none;
  peer                 = ssl.ssl.peer;
  once                 = ssl.ssl.once;
  fail                 = ssl.ssl.fail;
  client_once          = ssl.ssl.once;
  fail_if_no_peer_cert = ssl.ssl.fail;
}

local verify_set = {
  [ssl.ssl.none or true] = true;
  [ssl.ssl.peer or true] = true;
  [ssl.ssl.once or true] = true;
  [ssl.ssl.fail or true] = true;
}
verify_set[true] = nil

local function verify_value(v)
  if type(v) == "string" then
    return assert(verify_map[v], "unknown verify value:" .. v)
  end
  assert(verify_set[v], "unknown verify value:" .. v)
  return v
end

-- opt is LuaSEC compatiable table
local function make_ctx(opt)
  local proto = opt.protocol or 'TLSv1'
  proto = proto:sub(1,3):upper() .. proto:sub(4)

  local ctx, err = ssl.ssl.ctx_new(proto, opt.ciphers)
  if not ctx then return nil, err end

  local password = opt.password
  if type(password) == 'function' then password = password() end

  local xkey, xcert
  if opt.key then
    xkey, err = load_key(ssl.pkey, opt.key, true, 'pem', password)
    if not xkey then return nil, err end

    if opt.certificate then
      xcert, err = load_key(ssl.x509, opt.certificate)
    end

    if not xcert then
      xkey:close()
      return nil, err
    end

    ctx:use(xkey, xcert)
  end

  if opt.cafile then
    local ok, err = ctx:verify_locations(opt.cafile, opt.capath)
    if not ok then return nil, err end
  end

  if opt.verify then
    local flags

    -- in 1.0 vesion `verify_mode` support array as flags
    -- but after that it support only integer as flags
    if ssl.ssl.fail and ssl.ssl.peer then
      flags = 0
      if type(opt.verify) ~= 'table' then
        flags = verify_value(opt.verify)
      else
        for _, v in ipairs(opt.verify) do
          flags = flags + verify_value(v)
        end
      end
    else
      flags = opt.verify
    end

    if (type(opt.verify) == 'table') and (opt.verify.callback) then
      ctx:verify_mode(flags, opt.verify.callback)
    else
      ctx:verify_mode(flags)
    end
  end

  if opt.options and #opt.options > 0 then
    for i = 1, #opt.options do
      local name = opt.options[i]
      assert(ssl.ssl[name], "unkown option:" .. tostring(name))
    end
    ctx:options(unpack(opt.options))
  end

  if opt.verifyext then
    local t = {}
    for k, v in pairs(opt.verifyext) do
      t[k] = string.gsub(v, 'lsec_', '')
    end
    ctx:set_cert_verify(t)
  end

  if opt.dhparam then
    ctx:set_tmp('dh',opt.dhparam)
  end

  if opt.curve then
    ctx:set_tmp('ecdh',opt.curve)
  end

  return ctx
end

local SSLError = ut.class() do

function SSLError:__init(no, name, msg, ext)
  self._no   = no
  self._name = name
  self._msg  = msg or ''
  self._ext  = ext or ''
  return self
end

function SSLError:cat() return 'OPENSSL' end

function SSLError:no()  return self._no    end

function SSLError:name() return self._name end

function SSLError:msg() return self._msg   end

function SSLError:ext() return self._ext   end

function SSLError:__tostring()
  return string.format("[%s][%s] %s (%d) - %s",
    self:cat(), self:name(), self:msg(), self:no(), self:ext()
  )
end

end

local function ssl_last_error()
  local no, reason, lib, fn = ssl.error()
  if not no then return end
  if not fn then local _
    _, _, lib, fn, reason = ut.usplit(reason, ":", true)
  end
  return no, reason, lib, fn
end

local function ssl_error_info(err)
  assert(err)
  local no, reason, lib, fn = ssl.error(err)
  assert(err == no)
  if not fn then local _
    _, _, lib, fn, reason = ut.usplit(reason, ":", true)
  end
  return no, reason, lib, fn
end

local function ssl_clear_error()
  ssl.error(true)
end

local function OpenSSL_WrapError(no, msg)
  local no, reason, lib, fn = ssl_error_info(no)
  msg = msg .. ": " .. reason
  local ext = lib .. "/" .. fn
  return SSLError.new(no, "ESSL", msg, ext)
end

local function OpenSSL_TryError(msg)
  local no, reason, lib, fn = ssl_last_error()
  if no then
    msg = msg .. ": " .. reason
    local ext = lib .. "/" .. fn
    return SSLError.new(no, "ESSL", msg, ext)
  end
end

local function OpenSSL_Error(msg, ext)
  return OpenSSL_TryError(msg) or SSLError.new(-1, "ESSL", msg, ext)
end

local function OpenSSL_EOF(msg, ext)
  return OpenSSL_TryError(msg) or SSLError.new(-2, "EOF", msg, ext)
end

local SSLDecoder = ut.class() do

local Buffer = ut.class(ut.Buffer) do

local base = Buffer.__base

function Buffer:read_some(n)
  local chunk = base.read_some(self)
  if n and chunk and #chunk > n then
    local tail
    chunk, tail = chunk:sub(1, n), chunk:sub(n+1)
    self:prepend(tail)
  end
  return chunk
end

end

local BUFFER_SIZE = 8192
local ICHUNK_SIZE = BUFFER_SIZE
local OCHUNK_SIZE = BUFFER_SIZE

function SSLDecoder:__init(ctx, mode)
  self._ibuffer = Buffer.new()
  self._obuffer = Buffer.new()

  self._inp  = ssl.bio.mem(BUFFER_SIZE)
  self._out  = ssl.bio.mem(BUFFER_SIZE)
  self._ssl  = ctx:_ssl(self._inp, self._out, mode)

  return self
end

-- Put `input` data from IO layer to decoder
function SSLDecoder:input(data)
  if trace then trace("SSL IN DEC>", hex(data)) end
  self._ibuffer:append(data)
  return self
end

-- read already decoded data from ssl
function SSLDecoder:_in_read()
  local chunk, err = self._ssl:read()
  if not chunk then
    if chunk == nil then err = OpenSSL_TryError("SSLDecoder:input:read error")
    elseif err == 0 then err = OpenSSL_EOF("End of SSL input stream")
    else chunk, err = nil end --! @check what can we do here?
    return chunk, err
  end

  if #chunk > 0 then return chunk end
end

-- write next chunk of data to ssl to decode
function SSLDecoder:_in_write(chunk)
  local n, err = self._inp:write(chunk)

  if not n then
    self._ibuffer:prepend(chunk)
    err = OpenSSL_WrapError(err, "SSLDecoder:input:write error")
    return nil, err
  end

  if n < #chunk then
    self._ibuffer:prepend((chunk:sub(n+1)))
  end

  return n
end

-- read decoded input data
function SSLDecoder:read()
  ssl_clear_error()

  local chunk, err = self:_in_read()
  if chunk then return chunk end
  if err then return nil, err end

  while not self._ibuffer:empty() do
    chunk = self._ibuffer:read_some(ICHUNK_SIZE)

    local n, err = self:_in_write(chunk)

    if trace then trace("SSL TX DEC>", n, err, hex(chunk)) end

    if not n then return nil, err end

    chunk, err = self:_in_read()
    if chunk then return chunk end
    if err then return nil, err end
  end

  return
end

function SSLDecoder:has_read()
  local i, o = self._inp:pending()
  if i > 0 then return true end
  return self._ibuffer:empty()
end

-- write data to encode
function SSLDecoder:write(data)
  self._obuffer:append(data)
  return self
end

-- read next chunk already encoded data
function SSLDecoder:_out_read()
  local chunk, err = self._out:read()
  if not chunk then
    err = OpenSSL_WrapError(err, "SSLDecoder:output:read error")
    return nil, err
  end

  if #chunk > 0 then
    return chunk
  end
end

-- write next chunk to ssl to encode
function SSLDecoder:_out_write(chunk)
  local n, err = self._ssl:write(chunk)

  if not n then
    self._obuffer:prepend(chunk)
    if n == nil     then err = OpenSSL_TryError("SSLDecoder:output:write error")
    elseif err == 0 then err = OpenSSL_EOF("End of SSL output stream")
    else n, err = nil end --! @check what can we do here?
    return nil, err
  end

  if n < #chunk then
    self._obuffer:prepend((chunk:sub(n+1)))
  end

  return n
end

-- read next chank of output data to IO layer
function SSLDecoder:output()
  ssl_clear_error()

  local chunk, err = self:_out_read()
  if chunk then return chunk end
  if err then return nil, err end

  while not self._obuffer:empty() do
    chunk = self._obuffer:read_some(OCHUNK_SIZE)

    local n, err = self:_out_write(chunk)

    if trace then trace("SSL TX ENC>", n, err, hex(chunk)) end

    if not n then return nil, err end

    chunk, err = self:_out_read()
    if chunk then return chunk end
    if err then return nil, err end
  end

  return
end

-- write next chunk of data to do handshake
function SSLDecoder:handshake_write(data)
  return self._inp:write(data)
end

-- do handshake and next chunk to sendout
function SSLDecoder:handshake()
  local ret, err = self._ssl:handshake()
  if ret == nil then
    return nil, OpenSSL_Error("Handshake error")
  end
  return ret, err
end

function SSLDecoder:ssl()
  return self._ssl
end

function SSLDecoder:close()
  self._inp:close()
  self._out:close()
  self._out, self._out, self._ssl = nil
end

end

local SSLSocket = ut.class() do

local BUFFER_SIZE = 8192
local ICHUNK_SIZE = BUFFER_SIZE
local OCHUNK_SIZE = BUFFER_SIZE

function SSLSocket:__init(ctx, mode, socket)
  self._ctx  = assert(ctx)
  self._skt  = socket or uv.tcp()
  self._mode = (mode == 'server')
  self._dec  = SSLDecoder.new(self._ctx, self._mode)
  self._on_write  = function(_, err, cb) cb(self, err) end
  self._on_write2 = function(_, err, ctx) ctx[1](self, err, ctx[2]) end
  return self
end

function SSLSocket:_invoke_handshake_cb(defer, cb, ...)
  if self._handshake_done then return end
  self._handshake_done = true
  self._skt:stop_read()
  if defer then return uv.defer(cb, self, ...) end
  return cb(self, ...)
end

function SSLSocket:handshake(cb)
  -- self._handshake_done needs when
  -- we recv first chank of handshake and send first part of response
  -- if in this moment we get read error (e.g. EOF) we invoke callback
  -- from `start_read`. After that we get also error in `write` callback
  -- (in function `_handshake`) and shold not call same callback there

  self._handshake_done = false
  self._skt:start_read(function(cli, err, chunk)
    if err then
      return self:_invoke_handshake_cb(false, cb, err)
    end
    self._dec:handshake_write(chunk)
    self:_handshake(cb)
  end)
  self:_handshake(cb)
end

function SSLSocket:_handshake(cb)
  local ret, err = self._dec:handshake()
  if ret == nil then
    return self:_invoke_handshake_cb(true, cb, err)
  end

  local msg = {}
  while true do
    local chunk, err = self._dec:output()
    if not chunk then 
      if err then
        return self:_invoke_handshake_cb(true, cb, err)
      end
      break
    end
    msg[#msg + 1] = chunk
  end

  local handshake_done, write_pending = ret, false
  if #msg > 0 then
    write_pending = true
    self._skt:write(msg, function(_, err)
      if err then
        return self:_invoke_handshake_cb(false, cb, err)
      end

      -- if we send last chank of handshake
      if handshake_done then
        return self:_invoke_handshake_cb(false, cb)
      end

      return self:_handshake(cb)
    end)
  end

  -- not ready
  if ret == false then return end

  self._skt:stop_read()

  if not write_pending then
    return self:_invoke_handshake_cb(true, cb)
  end
end

function SSLSocket:close(cb)
  if not self._skt then return end
  if cb then self._skt:close(cb) else self._skt:close() end
  self._dec:close()
  self._skt, self._dec, self._read_cb = nil
end

function SSLSocket:_reading(cb)
  return
    self._read_cb == cb
    and not self:closed()
    and self:active()
end

function SSLSocket:start_read(cb)
  assert(cb)

  if trace then trace("SSL >", "START READ:", cb) end

  local function do_read(cli, err, data)
    if data then
      if trace then trace("SSL RAW RX>", os.time(), hex(data)) end
      self._dec:input(data)
    end

    if self._read_cb ~= cb then return end

    if err then
      self:stop_read()
      return cb(self, err)
    end

    while self:_reading(cb) do
      local chunk, err = self._dec:read()
      if not chunk then
        if err then
          if trace then trace("SSL RX>", os.time(), cb, nil, err) end
          self:stop_read()
          return cb(self, err)
        end
        return
      end
      if trace then trace("SSL RX>", os.time(), self._read_cb, hex(chunk)) end
      cb(self, nil, chunk)
    end
  end

  if self._read_cb then
    if self._read_cb == cb then return end
    self:stop_read()
  end

  self._read_cb = cb

  if self._dec:has_read() then
    uv.defer(do_read, self._skt, nil, '')
  end

  self._skt:start_read(do_read)

  return self
end

function SSLSocket:stop_read()
  local ok, err = self._skt:stop_read()

  if trace then trace("SSL >", "STOP READ:", self._read_cb, ok, err) end

  if not ok then return nil, err end

  self._read_cb = nil

  return self
end

function SSLSocket:write(data, cb, ctx)
  if type(data) == 'string' then
    if trace then trace("SSL TX>", os.time(), hex(data)) end
    self._dec:write(data)
  else
    for i = 1, #data do
      if trace then trace("SSL TX>", os.time(), hex(data[i])) end
      self._dec:write(data[i])
    end
  end

  local msg = {}
  while true do
    local chunk, err = self._dec:output()
    if not chunk then 
      if err then
        if trace then trace("SSL RAW TX>", os.time(), nil, err) end
        if not cb then return nil, err end
        uv.defer(self, cb, err)
        return self
      end
      break
    end
    if trace then trace("SSL RAW TX>", os.time(), hex(chunk)) end
    msg[#msg + 1] = chunk
  end

  if #msg > 0 then
    if #msg == 1 then msg = msg[1] end
    if cb then
      if ctx == nil then self._skt:write(msg, self._on_write, cb)
      else self._skt:write(msg, self._on_write2, {cb, ctx}) end
    else
      self._skt:write(msg)
    end
  elseif cb then
    uv.defer(self, cb)
  end

  return self
end

function SSLSocket:connect(host, port, cb)
  self._skt:connect(host, port, function(cli, err)
    if err then return cb(self, err) end
    self:handshake(cb)
  end)
end

function SSLSocket:bind(host, port, cb)
  if cb then
    self._skt:bind(host, port, function(cli, err)
      if err then return cb(self, err) end
      cb(self)
    end)
  end
  local ok, err = self._skt:bind(host, port)
  if not ok then return nil, err end
  return self
end

function SSLSocket:accept()
  local cli, err = self._skt:accept()
  if not cli then return nil, err end
  return self._ctx:server(cli)
end

function SSLSocket:listen(cb)
  self._skt:listen(function(cli, ...) cb(self, ...) end)
  return self
end

function SSLSocket:loop()
  return self._skt:loop()
end

function SSLSocket:closed()
  return not self._skt
end

function SSLSocket:ref()
  return self._skt:ref()
end

function SSLSocket:unref()
  return self._skt:unref()
end

function SSLSocket:has_ref()
  return self._skt:has_ref()
end

function SSLSocket:active()
  return self._skt:active()
end

function SSLSocket:closing()
  return self._skt:closing()
end

function SSLSocket:send_buffer_size()
  return self._skt:send_buffer_size()
end

function SSLSocket:recv_buffer_size()
  return self._skt:recv_buffer_size()
end

function SSLSocket:lock()
  self._skt:lock()
  return self
end

function SSLSocket:unlock()
  self._skt:unlock()
  return self
end

function SSLSocket:locked()
  return self._skt:locked()
end

function SSLSocket:__tostring()
  return "Lua-UV ssl (" .. tostring(self._skt) .. ")"
end

function SSLSocket:shutdown(cb)
  if not self._shutdowned then
    self._dec:ssl():shutdown()
    if cb then self._skt:shutdown(cb)
    else self._skt:shutdown() end
    self._shutdowned = true
  end
end

function SSLSocket:getsockname()
  return self._skt:getsockname()
end

function SSLSocket:getpeername()
  return self._skt:getpeername()
end

function SSLSocket:getpeercert()
  return self._dec:ssl():peer()
end

function SSLSocket:verifypeer()
  local c, s = self:getpeercert()
  if not c then
    local err = OpenSSL_Error("Authorize error(peer certificate)")
    return nil, err
  end

  local ok, err = self._dec:ssl():getpeerverification()
  if not ok then
    err = OpenSSL_Error("Authorize error(authorization failed)")
    return nil, err
  end

  return c, s
end

end

local SSLContext = ut.class() do

function SSLContext:__init(cfg)
  local ctx, err = make_ctx(cfg)
  if not ctx then return nil, err end
  self._ctx  = ctx
  return self
end

function SSLContext:_ssl(...)
  return self._ctx:ssl(...)
end

function SSLContext:client(socket)
  return SSLSocket.new(self, "client", socket)
end

function SSLContext:server(socket)
  return SSLSocket.new(self, "server", socket)
end

function SSLContext:__tostring()
  return "Lua-UV ssl context (" .. tostring(self._ctx) .. ")"
end

end

SSL = clone(SSL, {
  context  = function(...) return SSLContext.new(...) end
})

return SSL