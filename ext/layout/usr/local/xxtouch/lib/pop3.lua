---
-- POP3 client library for Lua
-- @module pop3
--

--- Connect to server.
-- Internal function. By default used luasocket.connect.
-- User can provide custom function. 
-- Create new `Connection` object and connect to server
-- @function connect 
-- @param host
-- @param port
-- @return `Connection` object that can be used for send/recive data.
-- @see new

--- 
-- Internal type used by `pop3` object.
-- This type can be provided by user via custom `pop3.connect` method.
-- @type Connection

--- Recive data.
--
-- @function Connection:receive
-- @tparam string pattern must support only "*l" pattern
-- @treturn string recived string without eol

--- Send data.
--
-- @function Connection:send
-- @tparam string msg data to send
-- @return not false

--- Set timeout to io functions.
-- 
-- @function Connection:settimeout
-- @tparam number tm timeout to io functions in seconds
-- @return not false

--- Close and destroy `Connection` object.
--
-- @function Connection:close
-- 
-- @return not false

--- @section end -- Connection

--- 
-- @function ConnectCtor
-- @tparam string host
-- @tparam string|number port
-- @treturn Connection

local function prequire(...)
  local ok, mod = pcall(require, ...)
  return ok and mod, mod
end

local message = prequire "pop3.message"

local DEBUG = 
-- function(...) print(...) io.flush() end or
function(...)  end

local b64enc, b64dec

local mime = prequire "mime"
if mime then b64enc,b64dec = mime.b64, mime.unb64
else local base64 = prequire "base64"
if base64 then b64enc,b64dec = base64.encode, base64.decode
end end

local md5_hmac, md5_digest, md5_sum do

-- LuaCrypto
if not md5_digest then
  local crypto = prequire "crypto"
  if crypto then
    local digest = crypto.evp and crypto.evp.digest or crypto.digest
    if digest then 
      md5_digest = function (str)
        return digest("md5", str)
      end
    end

    if crypto.hmac and crypto.hmac.digest then
      md5_hmac = function (key,value)
        return crypto.hmac.digest("md5", value, key)
      end
    end
  end
end

-- lua-openssl
if not md5_digest then
  local openssl = prequire "openssl"
  if openssl then
    if openssl.digest and openssl.digest.digest then
      md5_digest = function (str)
        return openssl.digest.digest("md5", str)
      end
    end

    if openssl.hmac and openssl.hmac.digest then
      md5_hmac = function (key,value)
        return openssl.hmac.digest("md5", value, key)
      end
    end
  end
end

-- lmd5 (old version)
if not md5_digest and prequire "digest" then
  if md5 then
    md5_digest = function (str) return md5.digest(str)       end
    md5_sum    = function (str) return md5.digest(str, true) end
  end
end

-- lmd5 or lua-md5
if not md5_digest then
  local md5 = prequire "md5"
  if md5 then 
    if md5.digest then
      md5_digest = function(str) return md5.digest(str)       end
      md5_sum    = function(str) return md5.digest(str, true) end
    elseif md5.sumhexa then
      md5_digest = function(str) return md5.sumhexa(str)   end
      md5_sum    = function(str) return md5.sum(str, true) end
    end
  end
end

-- Implement custom HMAC
if md5_digest and not md5_hmac then
  local bit = prequire("bit") or prequire("bit32")
  if bit then
    local bxor = bit.bxor

    local function hmac_key( hash, blocksize, key )
      if key:len() > blocksize then key = hash( key, true ) end
      key = key .. string.char( 0 ):rep( blocksize - key:len() )
      return key
    end

    local function hmac_xor(str, b)
      return str:gsub( '.', function( ch ) 
        return string.char( bxor( ch:byte(), b ) ) 
      end)
    end

    local function hmac(hash, key, value, raw)
      local blocksize = 64
      local hash_dig, hash_sum
      if     hash == 'md5'  then hash_dig, hash_sum = md5_digest, md5_sum
      -- elseif hash == 'sha1' then hash = assert(sha1.digest)
      else error("not supported.") end

      local key = hmac_key(hash, blocksize, key )
      local ikeypad = hmac_xor(key, 54)
      local okeypad = hmac_xor(key, 92)
      return hash_dig( okeypad .. hash_sum( ikeypad .. value ), raw)
    end

    md5_hmac = function (key, value)
      return hmac('md5', key, value)
    end
  end
end

end

local default_connect = function()
  return nil, 'default network transport is not loaded'
end

local socket  = prequire "socket"
if socket then default_connect = socket.connect end

local tls_connect 
if socket then 
  local ok, ssl = pcall (require, "ssl")
  if ok then 

    local tls_cfg = {
      protocol = "tlsv1",
      options  = "all",
      verify   = "none",
      mode     = "client"
    }

    function tls_connect(host, port)
      local cnn, err = socket.connect(host,port)
      if not cnn then return nil, err end

      local scnn, err  = ssl.wrap(cnn, tls_cfg)
      if not scnn then
        cnn:close()
        return nil, err
      end

      local ok,err = scnn:dohandshake()
      if not ok then
        scnn:close()
        return nil,err
      end
      return scnn
    end;

  end
end

---
-- @local 
-- @return true  
-- @return false - error execute command
-- @return nil   - error parse response
local function pars_response(resp)
  local code, info = string.match(resp,"%s*(%S*)(.*)%s*")
  -- SASL GET ONLY "+"/"-"
  if code == '+OK' or code == '+' then
    return true, info
  elseif code == '-ERR' or code == '-' then
    return false, info
  end
  return nil, resp
end

local function split_2_numbers(data)
  local n1, n2 = string.match(data, "%s*(%S+)%s+(%S+)")
  return tonumber(n1), tonumber(n2)
end

local function split_1_number(data)
  local n1,s= string.match(data, "%s*(%S+)%s*(%S*)")
  return tonumber(n1),s
end

---
-- @type pop3

local pop3 = {}
pop3.__index = pop3

function pop3:new(connect_ctor)
  return setmetatable({cnn_fn_ = connect_ctor},self)
end

-- Transport layer

--- Set default connection constructor
-- @tparam ConnectCtor connect_ctor 
function pop3:set_connect_fn(connect_ctor)
  self.cnn_fn_ = connect_ctor
end

--- Open new session with POP3 server.
-- 
-- @tparam ConnectCtor cnn_fn 
-- @tparam string host
-- @tparam string|number port
-- @tparam[opt] number timeout
-- @return true if session established
function pop3:open_with(cnn_fn, host, port, timeout)
  if self:is_open() then
    return true
  end

  local cnn, err = cnn_fn(host,port)
  if not cnn then return nil, err end
  if timeout then
    cnn:settimeout(timeout)
  end
  self.cnn = cnn
  self.is_auth_ = false

  local code, data = self:response()
  if not code then 
    self:close()
    return nil, data 
  end
  self.apop_nonce = string.match(data, "(<[^<>]+>)")
  return true
end

--- Open new session with POP3 server.
-- 
-- @tparam string host
-- @tparam string|number port
-- @tparam[opt] number timeout
-- @return true if session established
function pop3:open(...)
  return self:open_with(self.cnn_fn_ or default_connect, ...)
end

if tls_connect then

function pop3:open_tls(...)
  return self:open_with(tls_connect,...)
end

end

--- Close session with POP3 server.
-- Try send QUIT command and close connection
--
-- @return nothing if session not opened otherwise true
function pop3:close()
  if self.close_progress_ then return end
  if not self:is_open() then  return  end
  self.close_progress_ = true
  self:cmd("QUIT")
  assert(self.cnn)
  self.cnn:close()
  self.cnn             = nil
  self.is_auth_        = nil
  self.apop_nonce      = nil
  self.close_progress_ = nil
  self.is_secure_      = nil
  return true
end
pop3.quit = pop3.close

function pop3:recv(...)
  local ok,err = self.cnn:receive(...)
  if not ok then self:close() end
  return ok,err
end

function pop3:send(...)
  local ok,err = self.cnn:send(...)
  if not ok then self:close() end
  return ok,err
end

-- low level function

function pop3:response()
  assert(self:is_open())
  local resp, err = self:recv('*l')
  if not resp then return nil, err end
  DEBUG("POP3 RESPONSE : ", resp)
  return pars_response(resp)
end

function pop3:cmd(command, ...)
  assert(self:is_open())
  if ... then
    command = command .. ' ' .. table.concat({...}, ' ')
  end
  DEBUG("POP3 REQUEST  : ", command)
  command = command .. "\r\n"
  local ok, err = self:send(command)
  if not ok then return nil, err end
  return self:response()
end

function pop3:cmd_cb(fn, ...)
  local status, data = self:cmd(...)
  if not status then return nil, data end
  while true do
    local data, err = self:recv("*l")
    if not data then return nil,err end
    if data == '.' then break end
    data, err = fn(data)
    if not data then return nil,err end
  end
  return true
end

function pop3:cmd_ex(...)
  local all = {}
  local fn = function(line) table.insert(all,line) return true end
  local ok, err = self:cmd_cb(fn, ...)
  if not ok then return nil, err end
  return all
end

-- object and server info

--- 
-- @return true if session is opened otherwise false
function pop3:is_open()
  return self.cnn ~= nil
end

--- 
-- @return true if session in transaction stage otherwise false
function pop3:is_auth()
  return self.is_auth_ == true
end

function pop3:is_secure()
  return self.is_secure_
end

--- 
-- @return true if session support apop authentication otherwise false
function pop3:has_apop()
  assert(self:is_open())
  if self.apop_nonce then return true end
  return false
end

-- auth

--- POP3 authentication.
-- 
-- @return true if authentication passed
function pop3:auth(username, password)
  assert(not self:is_auth())
  local ok, err = self:cmd("USER",username)
  if not ok then return ok, err end
  ok, err = self:cmd("PASS", password)
  self.is_auth_ = ok
  return ok,err
end

if md5_digest then

--- POP3 APOP authentication.
-- Supports only if detected md5 digest function
--
-- return true if authentication passed
function pop3:auth_apop(username, password)
  assert(not self:is_auth())
  assert(self.apop_nonce)
  local dig = md5_digest(self.apop_nonce .. password)
  local ok, err = self:cmd("APOP", username, dig)
  self.is_auth_ = ok
  return ok,err
end

end

if b64enc then

--- POP3 AUTH PLAIN authentication.
-- Supports only if detected base64 encode/decode functions
--
-- @return true if authentication passed
function pop3:auth_plain(username, password)
  local auth64 = b64enc(
    username .. "\0" .. 
    username .. "\0" .. 
    password
  )
  local ok, err = self:cmd("AUTH PLAIN", auth64)
  self.is_auth_ = ok
  return ok,err
end

--- POP3 AUTH LOGIN authentication.
-- Supports only if detected base64 encode/decode functions
--
-- return true if authentication passed
function pop3:auth_login(username, password)
  local user64 = b64enc(username)
  local pw64   = b64enc(password)
  local status, data = self:cmd("AUTH LOGIN")
  if not status then return nil,data end
  
  data = b64dec(data)
  if data:upper() ~= "USERNAME:" then 
    return false, "Wrong Response:" .. data
  end

  status, data = self:cmd(user64)
  if not status then return nil,data end

  data = b64dec(data)
  if data:upper() ~= "PASSWORD:" then 
    return false, "Wrong Response:" .. data
  end

  status, data = self:cmd(pw64)
  self.is_auth_ = status
  return status, data
end

end

if md5_hmac and b64enc then

--- POP3 AUTH CRAM-MD5 authentication.
-- Supports only if detected base64 encode/decode and md5 hmac functions
--
-- @function auth_cmd5
-- @return true if authentication passed

function pop3:auth_crammd5(username, password)
  local status, data = self:cmd("AUTH CRAM-MD5")
  if not status then return nil, data end

  local nonce = b64dec(data)
  DEBUG("CMD5-CHALLENGE:", nonce)
  local dig   = md5_hmac(password, nonce)
  DEBUG("CMD5-HMAC(SECRET):", dig)
  local str   = b64enc(username.. ' ' .. dig)
  DEBUG("CMD5-RESPONSE:", dig)
  
  local ok, err = self:cmd(str)
  self.is_auth_ = ok
  return ok,err
end
pop3.auth_cmd5 = pop3.auth_crammd5

end

-- commands

--- Execute STAT command.
--
-- @treturn number number of messages
-- @treturn number size of messages
function pop3:stat()
  assert(self:is_auth())
  local status, data = self:cmd("STAT")
  if not status then return nil, data end
  local count, size = split_2_numbers(data)
  if not (count and size) then
    return nil, "Wrong Response:" .. data
  end
  return count, size 
end

--- Execute NOOP command.
--
-- @return true
function pop3:noop()
  assert(self:is_auth())
  return self:cmd("NOOP")
end

--- Execute DELE command.
--
-- @tparam string msgid
-- @return true
function pop3:dele(msgid)
  assert(self:is_auth())
  assert(msgid)
  return self:cmd("DELE",msgid)
end

--- Execute RSET command.
--
-- @return true
function pop3:rset()
  assert(self:is_auth())
  return self:cmd("RSET")
end

--- Execute LIST command.
--
-- @tparam[opt] string msgid
-- @return message number and size if msgid was given.
-- @treturn table {[msgNo] = msgSize} for all messages.
function pop3:list(msgid)
  assert(self:is_auth())

  if msgid then
    local status, data = self:cmd("LIST",msgid)
    if not status then return nil,data end
    local no, size = split_2_numbers(data)
    if not (no and size) then
      return nil, "Wrong Response:" .. data
    end
    return no,size
  end

  local t,i = {},0
  local fn = function(data)
    local no, size = split_2_numbers(data)
    if not (no and size) then
      return nil, "Wrong Response:" .. data
    end
    t[no]=size
    i = i + 1
    return true
  end
  local ok, err = self:cmd_cb(fn, "LIST")
  if not ok then return nil, err end
  return t, i
end

--- Execute UIDL command.
--
-- @tparam[opt] string msgid
-- @return message number and ID if msgid was given.
-- @treturn table {[msgNo] = msgID} for all messages.
function pop3:uidl(msgid)
  assert(self:is_auth())

  if msgid then
    local status, data = self:cmd("UIDL",msgid)
    if not status then return nil,data end
    local no, id = split_1_number(data)
    if not (no and id) then
      return nil, "Wrong Response:" .. data
    end
    return no,id
  end

  local t,i = {},0
  local fn = function(data)
    local no, id = split_1_number(data)
    if not (no and id) then
      return nil, "Wrong Response:" .. data
    end
    t[no]=id
    i = i + 1
    return true
  end

  local ok, err = self:cmd_cb(fn, "UIDL")
  if not ok then return nil, err end
  return t, i
end

--- Execute RETR command.
--
-- @tparam string msgid
-- @treturn table {line1, line2, ...} raw message (line by line)
function pop3:retr(msgid)
  assert(self:is_auth())
  assert(msgid)
  return self:cmd_ex("RETR",msgid)
end

--- Execute TOP command.
--
-- @tparam string msgid
-- @tparam number n
-- @treturn table {line1, line2, ..., lineN} raw message (line by line)
function pop3:top(msgid, n)
  assert(self:is_auth())
  assert(msgid)
  assert(n)
  return self:cmd_ex("TOP", msgid, n)
end

--- Execute CAPA command.
-- This command also add to result APOP flag.
-- @treturn table {APOP=true,EXPIRE="NEVER",SASL={LOGIN=true;PLAIN=true}} options returned by command.
function pop3:capa()
  assert(self:is_open())
  local capas = {}
  if self.apop_nonce then capas.APOP = true end

  local fn = function(line) 
    local capability = string.sub(line, string.find(line, "[%w-]+"))
    capability = capability:upper()
    line = string.sub(line, #capability + 1)
    capas[capability] = true
    local args = {}
    local w
    for w in string.gmatch(line, "[%w-]+") do
      table.insert(args, w)
    end
    if #args == 1 then 
      capas[capability] = args[1]
    elseif #args > 1 then
      local t = {}
      capas[capability] = t
      for _,a in ipairs(args) do
        t[a:upper()] = true
      end
    end
    return true 
  end
  local ok, err = self:cmd_cb(fn, "CAPA")
  if not ok then return nil, err end
  return capas
end

-- Retrive message object
if message then

--- Return message as `pop3.message` object
--@treturn pop3.message
--@see pop3.pop3:retr
function pop3:message(msgid)
  local msg, err = self:retr(msgid)
  if not msg then return nil, err end
  return message(msg)
end

end

-- iterators

function pop3:make_iter(fn)
  local lst, err = self:list()
  if not lst then error(err) end
  local k = nil
  
  local iter
  iter = function ()
    k = next(lst, k)
    if not k then return nil end

    -- skip deleted messages ?
    local status, err = self:cmd("LIST",k)
    if status == false then return iter() end -- next message
    if not status then return error(err) end
    local no, size = split_2_numbers(err)
    if not (no and size) then return error("Wrong Response:" .. err) end
    assert(no == k)

    local data, err = fn(self, k, size)
    if not data then error(err) end

    return k, data
  end

  return iter
end

--- Create iterator based on retr method.
--
-- @see pop3.pop3:retr
function pop3:retrs()
  return self:make_iter(self.retr)
end

--- Create iterator based on top method.
-- @tparam number n
-- @see pop3.pop3:top
function pop3:tops(n)
  return self:make_iter(function(self, msgid)
    return self:top(msgid, n)
  end)
end

--- Create iterator based on message method.
--
-- @see pop3.pop3:message
function pop3:messages()
  return self:make_iter(self.message)
end

--- @section end
local M = require "pop3.module"

--- Create new `pop3` object.
--
-- @function pop3.new
-- @tparam[opt=default_connect] ConnectCtor conn_ctor
-- @treturn `pop3` object
function M.new(...)
  return pop3:new(...)
end

M.message = message

return M