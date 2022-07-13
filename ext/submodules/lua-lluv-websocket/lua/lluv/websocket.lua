------------------------------------------------------------------
--
--  Author: Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Copyright (C) 2015-2016 Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Licensed according to the included 'LICENSE' document
--
--  This file is part of lua-lluv-websocket library.
--
------------------------------------------------------------------

local trace -- = function(...) print(os.date("[WS ][%x %X]"), ...) end

local function prequire(mod)
  local ok, err = pcall(require, mod)
  if not ok then return nil, err end
  return err, mod
end

local uv         = require "lluv"
local ut         = require "lluv.utils"
local tools      = require "lluv.websocket.tools"
local frame      = require "lluv.websocket.frame"
local handshake  = require "lluv.websocket.handshake"
local WSError    = require "lluv.websocket.error"
local Extensions = prequire"websocket.extensions"

local ok, ssl   = pcall(require, 'lluv.ssl')
if not ok then ssl = nil end

local WSError_handshake_faild = WSError.raise_handshake_faild
local WSError_EOF             = WSError.raise_EOF
local WSError_ESTATE          = WSError.raise_ESTATE
local WSError_ENOSUP          = WSError.raise_ENOSUP
local WSError_EOVERFLOW       = WSError.raise_EOVERFLOW

local CONTINUATION = frame.CONTINUATION
local TEXT         = frame.TEXT
local BINARY       = frame.BINARY
local CLOSE        = frame.CLOSE
local PING         = frame.PING
local PONG         = frame.PONG

local FRAME_NAMES = {
  [CONTINUATION ] = 'CONTINUATION';
  [TEXT         ] = 'TEXT';
  [BINARY       ] = 'BINARY';
  [CLOSE        ] = 'CLOSE';
  [PING         ] = 'PING';
  [PONG         ] = 'PONG';
}

local function frame_name(opcode)
  return FRAME_NAMES[opcode] or "UNKNOWN (" .. tostring(opcode) .. ")"
end

local function text(msg)
  if msg then 
    return string.format("[0x%.8X]", #msg) .. (#msg > 50 and (msg:sub(1, 50) .."...") or msg)
  end
  return "[   NULL   ]"
end

local function hex(msg, N)
  N = N or 50
  if msg then
    return string.format("[0x%.8X]", #msg) .. 
      string.gsub(msg:sub(1, N), ".", function(ch)
        return string.format("%.2x ", string.byte(ch))
      end) ..
      (#msg > N and "..." or "")
  end
  return "[   NULL   ]"
end

local function is_data_opcode(c)
  return c == TEXT or c == BINARY or c == CONTINUATION
end

local tconcat   = table.concat
local tappend   = function(t, v) t[#t + 1] = v return t end

------------------------------------------------------------------
local SizedBuffer = ut.class(ut.Buffer) do
local base = SizedBuffer.__base

function SizedBuffer:__init(buffer)
  assert(base.__init(self))
  self._size = self._size or 0

  while buffer do
    local chunk = buffer:read_some()
    if not chunk then break end
    self:append(chunk)
  end

  return self
end

if not SizedBuffer.size then

function SizedBuffer:read_line(...)
  error('Unsupported method')
end

function SizedBuffer:read_n(...)
  local data = base.read_n(self, ...)
  if data then self._size = self._size - #data end
  return data
end

function SizedBuffer:read_some()
  local data = base.read_some(self)
  if data then self._size = self._size - #data end
  return data
end

function SizedBuffer:read_all(...)
  local data = base.read_all(self, ...)
  if data then self._size = self._size - #data end
  return data
end

function SizedBuffer:append(data)
  if data then
    self._size = self._size + #data
    base.append(self, data)
  end
  return self
end

function SizedBuffer:prepend(data)
  if data then
    self._size = self._size + #data
    base.prepend(self, data)
  end
  return self
end

function SizedBuffer:size()
  return self._size
end

end

end
------------------------------------------------------------------

------------------------------------------------------------------
local decode_write_args, on_raw_data_by_pos, on_raw_data_by_chunk
local WSSocket = ut.class() do

-- State:
-- CLOSED not connected or closed handshake
-- WAIT_DATA data transfer mode
-- WAIT_CLOSE client call close method and we wait timeout or response
--    it different from HOST_SHUTDOWN because we can not do read.
-- PEER_SHUTDOWN we recv CLOSE frame but client do not call close method 
--          we do not send CLOSE yet. We do not read input any more
-- HOST_SHUTDOWN we send CLOSE frame but client do not call close method 
--          we wait response and stop read messages. But we still can read
--          data frames.
-- LISTEN - this is server socket so it does not do any WebSocket protocol
--

local function is_sock(s)
  local ts = type(s)
  if ts == 'userdata' then return true end
  if ts ~= 'table' then return false end
  return 
    s.start_read and
    s.write      and
    s.connect    and
    s.shutdown   and
    true
end

local function protocol_error(self, code, msg, read_cb, shutdown, read_err)
  self._code, self._reason = code or 1002, msg or 'Protocol error'
  local encoded = frame.encode_close(self._code, self._reason)

  if shutdown then -- no wait close response
    self:_stop_read()
    self:write(encoded, CLOSE, function()
      if self._sock then self._sock:shutdown() end
    end)
    self._state = 'CLOSED'
  else
    -- we call read callback so we have to prevent second call of read callback
    -- But we have to continue read to wait CLOSE response so we can not stop_read
    self._read_cb = nil
    self:write(encoded, CLOSE)
    self._state = 'HOST_SHUTDOWN'
  end

  return read_cb and read_cb(self, read_err or WSError_EOF(self._code, self._reason))
end

function WSSocket:__init(opt, s)
  if is_sock(opt) then s, opt = opt end
  opt = opt or {}

  self._sock       = s or uv.tcp()
  self._frames     = {}
  self._opcode     = nil
  self._origin     = nil
  self._ready      = nil
  self._state      = 'CLOSED' -- no connection
  self._buffer     = nil
  self._wait_size  = nil
  self._timeout    = opt.timeout
  self._protocols  = opt.protocols
  self._extensions = nil
  self._last_rsv1  = nil
  self._last_rsv2  = nil
  self._last_rsv3  = nil
  self._auto_ping_response = opt.auto_ping_response
  self._max_buffer_size    = opt.max_buffer_size

  if opt.extensions then
    for _, ext in ipairs(opt.extensions) do
      local ext_opt
      if type(ext) == 'table' then
        if ext[1] and not ext.name then
          -- this is pair e.g. {deflate, {client_max_window_bits=10}}
          ext, ext_opt = ext[1], ext[2]
        end
        self:register(ext, ext_opt)
      end
    end
  end

  if opt.utf8 then
    if opt.utf8 == true then
      self._validator = require"lluv.websocket.utf8".validator()
    else
      assert(type(opt.utf8.next)     == 'function')
      assert(type(opt.utf8.validate) == 'function')
      self._validator = opt.utf8
    end
  end

  if opt.ssl then
    if type(opt.ssl.server) == 'function' then
      self._ssl = opt.ssl
    else
      if not ssl then error("Unsupport WSS protocol") end
      self._ssl = assert(ssl.context(opt.ssl))
    end
  end

  self._on_write = function(_, err, cb)
    if trace then trace("WRITE>", err or 'PASS', cb) end
    cb(self, err)
  end

  return self
end

local function dns_request(host, cb)
  uv.getaddrinfo(host, nil, {
    socktype = "stream";
    protocol = "tcp";
  }, cb)
end

function WSSocket:connect(url, proto, cb)
  assert(self._sock)

  if self._state ~= "CLOSED" then
    uv.defer(cb, self, WSError_ESTATE("wrong state"))
  end

  self._state = "CONNECTING"

  local key, req

  local protocol, host, port, uri = tools.parse_url(url)

  -- to support http proxy
  if protocol == 'http'  then protocol = 'ws' end
  if protocol == 'https' then protocol = 'wss' end

  if protocol ~= 'ws' and protocol ~= 'wss'  then
    return uv.defer(cb, self, WSError_ENOSUP("bad protocol - " .. protocol))
  end

  if protocol == 'wss' then
    if not self._ssl then
      return uv.defer(cb, self, WSError_ENOSUP("unsuported protocol - " .. protocol))
    end
    self._sock = assert(self._ssl:client(self._sock))
  end

  dns_request(host, function(_, err, res)
    if err then return cb(self, err) end

    local ip = res[1]

    if trace then
      trace("Resolve " .. host .. " to " .. ip.address)
      trace("Connecting to " .. ip.address .. ":" .. port)
    end

    self._sock:connect(ip.address, port, function(sock, err)
      if err then return cb(self, err) end

      if trace then trace("Connected to " .. ip.address .. ":" .. port) end

      self:_client_handshake(key, req, cb)
    end)
  end)

  local extensions 
  if self._extensions then
    extensions = self._extensions:offer()
  end

  key = tools.generate_key()

  req = handshake.upgrade_request{
    key        = key,
    host       = host,
    port       = port,
    protocols  = {proto or ''},
    origin     = self._origin,
    uri        = uri,
    extensions = extensions,
  }

  return self
end

decode_write_args = function(msg, opcode, fin, cb)
  if not cb then
    local topcode =  type(opcode)
    if topcode == 'number' then
      if type(fin) == 'function' then
        fin, cb = true, fin
      elseif fin == nil then
        fin = true
      end
    elseif topcode == 'boolean' then
      fin, cb, opcode = opcode, fin
    elseif topcode == 'function' then
      opcode, fin, cb = nil, true, opcode
    else
      if opcode == nil then
        if type(fin) == 'function' then
          fin, cb = true, fin
        elseif fin == nil then
          fin = true
        end
        opcode = nil
      else
        fin, opcode = fin
      end
    end
  else
    if fin == nil then fin = true end
  end

  return msg, opcode or TEXT, not not fin, cb
end

local function frame_encode(self, msg, opcode, fin, allows)
  local rsv1, rsv2, rsv3 = false, false, false

  if opcode == BINARY or opcode == TEXT or opcode == CONTINUATION then
    if self._extensions then
      msg, rsv1, rsv2, rsv3 = self._extensions:encode(msg, opcode, fin, allows)
      if not msg then
        if rsv1 then if trace then trace("ENCODE>", rsv1) end end
        return
      end
    end

    if (msg == '') and (opcode == CONTINUATION) and (not fin) then
      return
    end
  end

  if trace then trace("TX>", self._state, frame_name(opcode), fin, self._masked, rsv1, rsv2, rsv3, text(msg)) end

  local encoded = frame.encode(msg, opcode, self._masked, fin, rsv1, rsv2, rsv3)

  return encoded
end

function WSSocket:write(msg, opcode, fin, cb)
  msg, opcode, fin, cb = decode_write_args(msg, opcode, fin, cb)

  if self._state == 'HOST_SHUTDOWN' or self._state == 'CLOSED' then
    if cb then uv.defer(cb, self, WSError_EOF(self._code or 1006, self._reason or 'Wrong state')) end
    return
  end

  local encoded
  if type(msg) == "table" then
    if msg[1] then
      encoded = {frame_encode(self, msg[1], opcode, fin and 1 == #msg)}
      for i = 2, #msg do
        local fin = (fin and i == #msg)
        if fin or #msg[i] > 0 then
          tappend(encoded, frame_encode(self, msg[i], CONTINUATION, fin and i == #msg))
        end
      end
    else
      encoded = frame_encode(self, '', opcode, fin)
    end
  else
    encoded = frame_encode(self, msg, opcode, fin)
  end

  if encoded and #encoded > 0 then
    local ok, err
    if not cb then ok, err = self._sock:write(encoded)
    else ok, err = self._sock:write(encoded, self._on_write, cb) end

    if trace then
      if type(encoded) == 'table' then
        encoded = table.concat(encoded)
      end
      trace("WS RAW TX>", self._state, cb, hex(encoded))
    end

    if not ok then return nil, err end
  end

  return self
end

function WSSocket:ready(mask, buffer)
  if type(buffer) == "string" then
    self._buffer = SizedBuffer.new()
    self._buffer:append(buffer)
  else
    self._buffer = SizedBuffer.new(buffer)
  end

  self._ready  = true
  self._state  = "WAIT_DATA"
  self._masked = mask
  return self
end

function WSSocket:_client_handshake(key, req, cb)
  self._sock:write(req, function(sock, err)
    if err then
      self._state = 'FAILED'
      self._sock:shutdown()
      return cb(self, err)
    end
  end)

  local expected_accept
  local buffer = ut.Buffer.new('\r\n\r\n')
  self._sock:start_read(function(sock, err, data)
    if err then
      self._state = 'FAILED'
      self._sock:stop_read():shutdown()
      return cb(self, err)
    end

    if trace then trace("WS HS RX>", hex(data)) end

    buffer:append(data)
    local response = buffer:read("*l")
    if not response then
      if self._max_buffer_size and (buffer:size() > self._max_buffer_size) then
        sock:stop_read()
        err = WSError_EOVERFLOW('buffer overflow on client handshake')
        protocol_error(self, 1011, "Internal error", cb, true, err)
      end
      return
    end
    sock:stop_read()

    if trace then trace("WS HS >", "stop read") end

    local headers = handshake.http_headers(response .. '\r\n\r\n')
    if headers['sec-websocket-accept'] ~= expected_accept then
      self._state = 'FAILED'
      self._sock:shutdown()
      err = WSError_handshake_faild(response)
      return cb(self, err)
    end

    self:ready(true, buffer)

    if trace then trace("WS HS DONE>", "buffer size:", self._buffer:size()) end

    if self._extensions then
      local ok, err = self._extensions:accept(headers['sec-websocket-extensions'])
      if not ok then
        if err then return protocol_error(self, 1010, "Unsupported extension", cb, false, err) end
        self._extensions = nil
      end
    end

    cb(self, nil, headers)
  end)

  expected_accept = handshake.sec_websocket_accept(key)
end

function WSSocket:handshake(cb)
  if self._sock.handshake then
    self._sock:handshake(function(sock, err)
      if err then
        self._state = 'FAILED'
        self._sock:shutdown()
        return cb(self, err)
      end
      self:_server_handshake(cb)
    end)
    return
  end

  self:_server_handshake(cb)
end

function WSSocket:_server_handshake(cb)
  local buffer = ut.Buffer.new('\r\n\r\n')

  assert(type(self._protocols) == 'table')

  self._sock:start_read(function(sock, err, data)
    if err then
      self._state = 'FAILED'
      self._sock:stop_read():shutdown()
      return cb(self, err)
    end

    if trace then trace("WS RAW RX>", "HANDSHAKE", text(data)) end

    buffer:append(data)
    local request = buffer:read("*l")
    if not request then
      if self._max_buffer_size and  (buffer:size() > self._max_buffer_size) then
        self._state = 'FAILED'
        self._sock:stop_read():shutdown()
        err = WSError_EOVERFLOW('buffer overflow on server handshake')
        return cb(self, err)
      end
      return
    end
    sock:stop_read()

    if trace then trace("RX>", "HANDSHAKE", text(request)) end
    if trace then
      local msg = buffer:read_all()
      buffer:append(msg)
      trace("HANDSHAKE ADDITIONAL DATA:", hex(msg))
    end

    request = request .. '\r\n'

    local response, protocol, extensions = handshake.accept_upgrade(request, self._protocols)
    if not response then
      self._state = 'FAILED'
      self._sock:shutdown()
      err = WSError_handshake_faild(request)
      return cb(self, err)
    end

    local response_error
    if self._extensions then
      local resp, err = self._extensions:response(extensions)
      if resp then
        tappend(response, 'Sec-WebSocket-Extensions: ' .. resp)
      elseif err then
        response_error = err
        response = {"HTTP/1.1 400 " .. err:msg()}
      end
    end

    response = tconcat(tappend(response, '\r\n'), '\r\n')

    if trace then trace("TX>", "HANDSHAKE", text(response)) end

    local headers
    sock:write(response, function(sock, err)
      if err or response_error then
        self._state = 'FAILED'
        self._sock:stop_read():shutdown()
        return cb(self, err or response_error)
      end

      self:ready(false, buffer)

      cb(self, nil, protocol, headers)
    end)
    headers = handshake.http_headers(request)
  end)
end

function WSSocket:_close(clean, code, reason, cb)
  assert(self._sock)

  if self._timer then
    self._timer:close()
    self._timer = nil
  end

  if cb then
    self._sock:close(function(_, ...) cb(self, clean, code, reason) end)
  else
    self._sock:close()
  end

  self._state, self._sock = 'CLOSED'
end

local function start_close_timer(self, timeout)
  assert(not self._timer)
  assert(self._state == 'WAIT_CLOSE')
  self._timer = uv.timer():start((timeout or 3) * 1000, function()
    self:_close(false, 1006, 'timeout', self._on_close)
  end)
end

function WSSocket:close(code, reason, cb)
  if trace then trace('CLOSE>', self._state) end

  if not self._sock then return end

  if type(code) == 'function' then
    cb, code, reason = code
  elseif type(reason) == 'function' then
    cb, reason = reason
  end

  if self._state == 'PEER_SHUTDOWN' then
    code, reason = code or self._code, reason or self._reason
  end

  code, reason = code or 1000, reason or ''

  -- not connected or no handshake
  if not self._ready then
    return self:_close(true, code, reason, cb)
  end

  -- we already send/recv CLOSE or this is server socket so we do 
  -- not need do any close handshake
  if self._state == 'CLOSED' or self._state == 'LISTEN' then
    return self:_close(true, self._code, self._reason, cb)
  end

  -- IO error or interrupted connection
  if (self._state == 'FAILED') or (self._state == 'CONNECTING') then 
    return self:_close(false, code, reason, cb)
  end

  -- We in regular data or recv CLOSE
  -- We should send CLOSE
  if self._state == 'WAIT_DATA' or self._state == 'PEER_SHUTDOWN' then
    local encoded = frame.encode_close(code, reason)
    self:write(encoded, CLOSE, function()
      if self._state == 'PEER_SHUTDOWN' then
        return self:_close(true, self._code, self._reason, cb)
      end
    end)
  end

  -- We in regular data transfer state or we already send CLOSE
  -- We should wait CLOSE response
  if self._state == 'WAIT_DATA' or self._state == 'HOST_SHUTDOWN' then 

    self._state = 'WAIT_CLOSE'

    start_close_timer(self, 3) --! @todo fix hardcoded timeout

    self:_stop_read():_start_read(function()end)

    self._on_close, self._code, self._reason = cb, code, reason

    return
  end

  -- We send CLOSE and wait response
  if self._state == 'WAIT_CLOSE' then
    -- double close
    return nil, 'double close'
  end
end

local validate_frame = function(self, cb, decoded, fin, opcode, masked, rsv1, rsv2, rsv3)
  if self._masked == masked then
    if self._state == 'WAIT_DATA' then
      protocol_error(self, 1002, "Invalid masked bit", cb)
    end
    return false
  end

  if rsv1 or rsv2 or rsv3 then -- Invalid frame
    if not self:_validate_frame(opcode, rsv1, rsv2, rsv3) then
      if self._state == 'WAIT_DATA' then
        protocol_error(self, 1002, "Invalid reserved bit", cb)
      end
      return false
    end
  end

  return true
end

local CLOSE_CODES = {
  [1000] = true;
  [1001] = true;
  [1002] = true;
  [1003] = true;
  [1007] = true;
  [1008] = true;
  [1009] = true;
  [1010] = true;
  [1011] = true;
}

local on_control = function(self, mode, cb, decoded, fin, opcode, masked, rsv1, rsv2, rsv3)
  if not fin then
    if self._state == 'WAIT_DATA' then
      protocol_error(self, 1002, "Fragmented control", cb)
    end
    return
  end

  if opcode == CLOSE then
    local valid = true
    if #decoded >= 126 then
      self._code, self._reason = 1002, 'Too long payload'
      valid = false
    elseif #decoded > 0 then
      self._code, self._reason = frame.decode_close(decoded)
      local ncode = tonumber(self._code)
      if self._reason and #self._reason > 0 and
        self._validator and not self._validator:validate(self._reason)
      then
        self._code, self._reason = 1007, 'Invalid UTF8 character'
        valid = false
      end
      if (not ncode or ncode < 1000)
        or (ncode <  3000 and not CLOSE_CODES[ncode])
      then
        self._code, self._reason = 1002, 'Invalid status code'
        valid = false
      end
    else
      self._code, self._reason = 1000, ''
    end

    -- after CLOSE peer can not send any data
    --! @check may be we can use read callback to detect TCP EOF?
    self._sock:stop_read()

    if not valid then
      -- On autobahntestsuite preffered way to handle invalid 
      -- CLOSE for Server is drop TCP connections

      if self._state == 'WAIT_DATA' then
        if self._masked then -- client send response
          return protocol_error(self, self._code, self._reason, cb)
        end
        -- server shutdown connection
        self._state = 'CLOSED'
        self._sock:shutdown()
        return cb(self, WSError_EOF(self._code, self._reason))
      end

      if self._state == 'WAIT_CLOSE' then
        self:_close(false, self._code, self._reason, self._on_close)
      end

      self._state = 'CLOSED'
      self._sock:shutdown()
      return
    end

    -- User already call `close` method
    if self._state == 'WAIT_CLOSE' then
      return self:_close(true, self._code, self._reason, self._on_close)
    end

    -- We already send CLOSE so WS connection is closed
    -- underlying TCP connection may be still active
    -- but we do not need do any IO
    if self._state == 'HOST_SHUTDOWN' then
      self._state = 'CLOSED'
      return
    end

    -- remote side send CLOSE
    -- RFC 4655
    -- It SHOULD do (response CLOSE) so as soon as practical. An endpoint 
    -- MAY delay sending a Close frame until its current message is sent
    self._state = 'PEER_SHUTDOWN'

    return cb(self, WSError_EOF(self._code, self._reason))
  elseif opcode == PING then
    if self._state == 'WAIT_DATA' then
      if #decoded >= 126 then
        return protocol_error(self, 1002, "Too long payload", cb)
      end
      if self._auto_ping_response then
        self:write(decoded, PONG)
      else
        cb(self, nil, decoded, opcode, true)
      end
    end
  elseif opcode == PONG then
    if self._state == 'WAIT_DATA' then
      cb(self, nil, decoded, opcode, true)
    end
  else
    if self._state == 'WAIT_DATA' then
      protocol_error(self, 1002, "Invalid opcode", cb)
    end
  end

end

local on_data = function(self, mode, cb, decoded, fin, opcode, masked, rsv1, rsv2, rsv3)
  if self._state ~= 'WAIT_DATA' then
    self._frames, self._opcode = nil
    return
  end

  if not self._opcode then
    if opcode == CONTINUATION then
      return protocol_error(self, 1002, "Unexpected continuation frame", cb, true)
    else
      self._frames, self._opcode = (mode == '*f') or {}, opcode
      self._last_rsv1,self._last_rsv2,self._last_rsv3 = rsv1, rsv2, rsv3
    end
  else
    if opcode ~= CONTINUATION then
      return protocol_error(self, 1002, "Unexpected data frame", cb, true)
    end
  end

  if self._extensions then
    local err
    decoded, err = self._extensions:decode(decoded, opcode, fin, self._last_rsv1, self._last_rsv2, self._last_rsv3)
    if not decoded then
      if err then
        if trace then trace("DECODE>", err) end
        return protocol_error(self, 1010, "error proceed data using extensinos", cb, true)
      end
      return
    end
  end

  if self._validator and self._opcode == TEXT then
    if not self._validator:next(decoded, fin) then
      return protocol_error(self, 1007, "Invalid UTF8 character", cb)
    end
  end

  if fin == true then
    self._last_rsv1,self._last_rsv2,self._last_rsv3 = nil
  end

  if mode == '*f' then
    if fin == true then
      self._frames, self._opcode = nil
    end
    cb(self, nil, decoded, opcode, fin)
  else
    if #decoded > 0 then
      tappend(self._frames, decoded)
    end
    if fin == true then
      local f, c = self._frames, self._opcode
      self._frames, self._opcode = nil

      if mode == '*s' then f = table.concat(f) end

      cb(self, nil, f, c, fin)
    end
  end
end

local function stub()end

local on_raw_data_1 do

local function next_frame(self)
  local encoded = self._buffer:read_some()

  while encoded do
    local decoded, fin, opcode, rest, masked, rsv1, rsv2, rsv3 = frame.decode(encoded)
    if decoded then
      self._wait_size = nil
      self._buffer:prepend(rest)
      return decoded, fin, opcode, masked, rsv1, rsv2, rsv3
    end

    if self._buffer:size() < fin then
      self._buffer:prepend(encoded)
      self._wait_size = fin + #encoded
      return
    end

    local chunk = self._buffer:read_n(fin)

    encoded = encoded .. chunk
  end
end

on_raw_data_1 = function(self, data, cb, mode)
  if self._wait_size and self._buffer:size() < self._wait_size then
    return
  end

  while self._sock and (self._read_cb == cb or self._state == 'HOST_SHUTDOWN' or self._state == 'WAIT_CLOSE') do
    if trace then trace("RAW_ITER>", self._state) end

    local decoded, fin, opcode, masked, rsv1, rsv2, rsv3 = next_frame(self)

    if not decoded then break end

    if trace then trace("RX>", self._state, frame_name(opcode), fin, masked, text(decoded), rsv1, rsv2, rsv3) end

    if validate_frame(self, cb, decoded, fin, opcode, masked, rsv1, rsv2, rsv3) then
      local handler = is_data_opcode(opcode) and on_data or on_control
      handler(self, mode, self._read_cb or stub, decoded, fin, opcode, masked, rsv1, rsv2, rsv3)
    end
  end
end

end

local on_raw_data_2 = function(self, data, cb, mode)
  if self._wait_size and self._buffer:size() < self._wait_size then
    return
  end

  local pos, encoded = 1, self._buffer:read_all()

  while self._sock and (self._read_cb == cb or self._state == 'HOST_SHUTDOWN' or self._state == 'WAIT_CLOSE') do
    if trace then trace("RAW_ITER>", self._state) end

    local decoded, fin, opcode, masked, rsv1, rsv2, rsv3

    decoded, fin, opcode, pos, masked, rsv1, rsv2, rsv3 = frame.decode_by_pos(encoded, pos)

    if not decoded then
      self._wait_size = fin
      break
    end

    self._wait_size = nil -- we can set it to 2 because header size >= 2

    if trace then trace("RX>", self._state, frame_name(opcode), fin, masked, text(decoded), rsv1, rsv2, rsv3) end

    if validate_frame(self, cb, decoded, fin, opcode, masked, rsv1, rsv2, rsv3) then
      local handler = is_data_opcode(opcode) and on_data or on_control
      handler(self, mode, self._read_cb or stub, decoded, fin, opcode, masked, rsv1, rsv2, rsv3)
    end
  end

  local rest = string.sub(encoded, pos)
  self._buffer:prepend(rest)
end

WSSocket._on_raw_data = on_raw_data_2

-- export to be able run tests
on_raw_data_by_pos, on_raw_data_by_chunk = on_raw_data_1, on_raw_data_2

function WSSocket:_start_read(mode, cb)
  if type(mode) == 'function' then
    cb, mode = mode
  end

  mode = mode or '*s'

  assert(mode == '*t' or mode == '*s' or mode == '*f', mode)

  assert(cb)

  local function do_read(cli, err, data)
    if data then
      if trace then trace("WS RAW RX>", self._state, cb, self._buffer:size(), self._wait_size, hex(data)) end
      self._buffer:append(data)
      if self._max_buffer_size and (self._buffer:size() > self._max_buffer_size) then
        err = WSError_EOVERFLOW('buffer overflow')
      end
    end

    if trace and err then trace("WS RAW RX>", self._state, cb, err) end

    if err then
      local read_cb = self._read_cb
      self:_stop_read()
      self._sock:shutdown()

      if self._state == 'WAIT_CLOSE' then
        self:_close(false, self._code, self._reason, self._on_close)
      else
        self._state = 'CLOSED'
      end

      if read_cb == cb then cb(self, err) end

      return 
    end

    -- we call it when user wait data
    -- or e.g. when we get protocol error, send CLOSE to remote side
    -- and wait CLOSE response. We already call user callback but library
    -- should proceed control messages
    self:_on_raw_data(data, cb, mode)
  end

  if self._read_cb then
    if self._read_cb == cb then return end
    self:_stop_read()
  end

  self._read_cb = cb

  if not self._buffer:empty() then
    uv.defer(do_read, self._sock, nil, '')
  end

  self._sock:start_read(do_read)

  return self
end

function WSSocket:start_read(...)
  if self._state ~= 'WAIT_DATA' then return end

  return self:_start_read(...)
end

function WSSocket:_stop_read()
  self._sock:stop_read()
  self._read_cb = nil
  return self
end

function WSSocket:stop_read()
  if self._state ~= 'WAIT_DATA' then return end

  return self:_stop_read()
end

function WSSocket:shutdown(code, reason, cb)
  if trace then trace('SHUTDOWN>', self._state) end

  if not self._sock then return end

  if not(
       self._state == 'WAIT_DATA'
    or self._state == 'PEER_SHUTDOWN'
  ) then
    return
  end

  if type(code) == 'function' then
    cb, code, reason = code
  elseif type(reason) == 'function' then
    cb, reason = reason
  end

  if self._state == 'WAIT_DATA' then
    self._code, self._reason = code or 1000, reason or ''
  end

  local encoded = frame.encode_close(self._code or 1000, self._reason or '')
  self:write(encoded, CLOSE, function()
    if self._sock then self._sock:shutdown(cb) end
  end)

  if self._state == 'PEER_SHUTDOWN' then
    self._state = 'CLOSED'
  elseif self._state == 'WAIT_CLOSE' then
    self._state = 'HOST_SHUTDOWN'
  end
end

function WSSocket:bind(url, protocols, cb)
  if type(protocols) == 'function' then
    cb, protocols = protocols
  end

  self._protocols = protocols or self._protocols
  if not self._protocols then error("No protocols") end

  if type(self._protocols) == 'string' then self._protocols = {self._protocols} end

  assert(type(self._protocols) == 'table')

  local protocol, host, port, uri = tools.parse_url(url)

  if protocol ~= 'ws' and protocol ~= 'wss'  then
    local err = WSError_ENOSUP("bad protocol - " .. protocol)
    if cb then
      uv.defer(cb, self, err)
      return self
    end
    return nil, err
  end

  if protocol == 'wss' and not self._ssl then
    local err = WSError_ENOSUP("unsuported protocol - " .. protocol)
    if cb then
      uv.defer(cb, self, err)
      return self
    end
    return nil, err
  end

  self._is_wss = (protocol == 'wss')

  local ok, err
  if cb then
    ok, err = self._sock:bind(host, port, function(_, ...) cb(self, ...) end)
  else
    ok, err = self._sock:bind(host, port)
  end
  if not ok then return nil, err end
  return self
end

function WSSocket:accept()
  local cli, err = self._sock:accept()
  if not cli then return nil, err end
  if self._is_wss then cli = assert(self._ssl:server(cli)) end
  local sock = WSSocket.new({
    protocols = self._protocols;
    utf8      = self._validator and self._validator.new();
    auto_ping_response = self._auto_ping_response;
    max_buffer_size = self._max_buffer_size;
  }, cli)

  sock._extensions = self._extensions

  return sock
end

function WSSocket:listen(cb)
  self._state = 'LISTEN'

  local ok, err = self._sock:listen(function(_, ...)
    cb(self, ...)
  end)

  if not ok then return nil, err end

  return self
end

function WSSocket:__tostring()
  return "Lua-UV websocket (" .. tostring(self._sock) .. ")"
end

function WSSocket:getsockname()
  return self._sock:getsockname()
end

function WSSocket:getpeername()
  return self._sock:getpeername()
end

function WSSocket:register(...)
  if not Extensions then
    return nil, 'Extension module not installed'
  end

  if not self._extensions then
    self._extensions = Extensions.new()
  end
  self._extensions:reg(...)
  return self
end

function WSSocket:_validate_frame(opcode, rsv1, rsv2, rsv3)
  return self._extensions and self._extensions:validate_frame(opcode, rsv1, rsv2, rsv3)
end

end
------------------------------------------------------------------

local function self_test()

  do -- decode_write_args 
  local function dummy()end

  local msg, opcode, fin, cb = decode_write_args("") do
  assert(msg    == ""  , "`" .. tostring(msg   ) .. "` type: " .. type(msg   ) )
  assert(opcode == TEXT, "`" .. tostring(opcode) .. "` type: " .. type(opcode) )
  assert(fin    == true, "`" .. tostring(fin   ) .. "` type: " .. type(fin   ) )
  assert(cb     == nil , "`" .. tostring(cb    ) .. "` type: " .. type(cb    ) )
  end

  local msg, opcode, fin, cb = decode_write_args("", BINARY) do
  assert(msg    == ""  ,   "`" .. tostring(msg   ) .. "` type: " .. type(msg   ) )
  assert(opcode == BINARY, "`" .. tostring(opcode) .. "` type: " .. type(opcode) )
  assert(fin    == true,   "`" .. tostring(fin   ) .. "` type: " .. type(fin   ) )
  assert(cb     == nil ,   "`" .. tostring(cb    ) .. "` type: " .. type(cb    ) )
  end

  local msg, opcode, fin, cb = decode_write_args("", BINARY, false) do
  assert(msg    == ""  ,   "`" .. tostring(msg   ) .. "` type: " .. type(msg   ) )
  assert(opcode == BINARY, "`" .. tostring(opcode) .. "` type: " .. type(opcode) )
  assert(fin    == false,  "`" .. tostring(fin   ) .. "` type: " .. type(fin   ) )
  assert(cb     == nil ,   "`" .. tostring(cb    ) .. "` type: " .. type(cb    ) )
  end

  local msg, opcode, fin, cb = decode_write_args("", BINARY, dummy) do
  assert(msg    == ""  ,   "`" .. tostring(msg   ) .. "` type: " .. type(msg   ) )
  assert(opcode == BINARY, "`" .. tostring(opcode) .. "` type: " .. type(opcode) )
  assert(fin    == true,   "`" .. tostring(fin   ) .. "` type: " .. type(fin   ) )
  assert(cb     == dummy , "`" .. tostring(cb    ) .. "` type: " .. type(cb    ) )
  end

  local msg, opcode, fin, cb = decode_write_args("", false) do
  assert(msg    == ""  ,   "`" .. tostring(msg   ) .. "` type: " .. type(msg   ) )
  assert(opcode == TEXT,   "`" .. tostring(opcode) .. "` type: " .. type(opcode) )
  assert(fin    == false,  "`" .. tostring(fin   ) .. "` type: " .. type(fin   ) )
  assert(cb     == nil,    "`" .. tostring(cb    ) .. "` type: " .. type(cb    ) )
  end

  local msg, opcode, fin, cb = decode_write_args("", false,  dummy) do
  assert(msg    == ""  ,   "`" .. tostring(msg   ) .. "` type: " .. type(msg   ) )
  assert(opcode == TEXT,   "`" .. tostring(opcode) .. "` type: " .. type(opcode) )
  assert(fin    == false,  "`" .. tostring(fin   ) .. "` type: " .. type(fin   ) )
  assert(cb     == dummy , "`" .. tostring(cb    ) .. "` type: " .. type(cb    ) )
  end

  local msg, opcode, fin, cb = decode_write_args("", dummy) do
  assert(msg    == ""  ,   "`" .. tostring(msg   ) .. "` type: " .. type(msg   ) )
  assert(opcode == TEXT,   "`" .. tostring(opcode) .. "` type: " .. type(opcode) )
  assert(fin    == true,   "`" .. tostring(fin   ) .. "` type: " .. type(fin   ) )
  assert(cb     == dummy , "`" .. tostring(cb    ) .. "` type: " .. type(cb    ) )
  end

  local msg, opcode, fin, cb = decode_write_args("", nil, dummy) do
  assert(msg    == ""  ,  "`" .. tostring(msg   ) .. "` type: " .. type(msg   ) )
  assert(opcode == TEXT,  "`" .. tostring(opcode) .. "` type: " .. type(opcode) )
  assert(fin    == true,  "`" .. tostring(fin   ) .. "` type: " .. type(fin   ) )
  assert(cb     == dummy, "`" .. tostring(cb    ) .. "` type: " .. type(cb    ) )
  end

  local msg, opcode, fin, cb = decode_write_args("", nil, false) do
  assert(msg    == ""  ,   "`" .. tostring(msg   ) .. "` type: " .. type(msg   ) )
  assert(opcode == TEXT,   "`" .. tostring(opcode) .. "` type: " .. type(opcode) )
  assert(fin    == false,  "`" .. tostring(fin   ) .. "` type: " .. type(fin   ) )
  assert(cb     == nil,    "`" .. tostring(cb    ) .. "` type: " .. type(cb    ) )
  end

  local msg, opcode, fin, cb = decode_write_args("", nil, nil, dummy) do
  assert(msg    == ""  ,   "`" .. tostring(msg   ) .. "` type: " .. type(msg   ) )
  assert(opcode == TEXT,   "`" .. tostring(opcode) .. "` type: " .. type(opcode) )
  assert(fin    == true,   "`" .. tostring(fin   ) .. "` type: " .. type(fin   ) )
  assert(cb     == dummy,  "`" .. tostring(cb    ) .. "` type: " .. type(cb    ) )
  end

  local msg, opcode, fin, cb = decode_write_args("", nil, false, dummy) do
  assert(msg    == ""  ,   "`" .. tostring(msg   ) .. "` type: " .. type(msg   ) )
  assert(opcode == TEXT,   "`" .. tostring(opcode) .. "` type: " .. type(opcode) )
  assert(fin    == false,  "`" .. tostring(fin   ) .. "` type: " .. type(fin   ) )
  assert(cb     == dummy,  "`" .. tostring(cb    ) .. "` type: " .. type(cb    ) )
  end

  end

end

local WebSocket = setmetatable({
  new = WSSocket.new;

  TEXT         = TEXT;
  BINARY       = BINARY;
  PING         = PING;
  PONG         = PONG;

  CONTINUATION = CONTINUATION;
  CLOSE        = CLOSE;

  Extensions   = Extensions;

  -- !!! NOT PUBLIC API !!! --
  __self_test            = self_test;
  __on_raw_data_by_pos   = on_raw_data_by_pos;
  __on_raw_data_by_chunk = on_raw_data_by_chunk;
}, {__call = function(self, ...) return WSSocket.new(...) end})

return WebSocket