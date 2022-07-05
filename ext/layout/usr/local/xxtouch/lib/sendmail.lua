-- sendmail.lua v0.1.6-dev (2021-07)

-- Copyright (c) 2013-2021 Alexey Melnichuk
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.

------------------------------------------------------------
local DEFAULT_CHARSET = 'windows-1251'
local DEFAULT_ENCODE  = 'base64'
local DEFAULT_HEADERS = {
  ['x-mailer'] = 'Cool mailer'
}
local DEFAULT_OPTIONS = {
  confirm_sending = false;
}
------------------------------------------------------------

local smtp   = require("socket.smtp")
local socket = require("socket")
local ltn12  = require("ltn12")
local mime   = require("mime")
local string = require("string")
local table  = require("table")
local io     = require("io")

local function basename(f)
  return (string.match(f, "[^\\/]+$"))
end

local function split(str, sep, plain)
  local b, res = 1, {}
  while b <= #str do
    local e, e2 = string.find(str, sep, b, plain)
    if e then
      res[#res + 1] = string.sub(str, b, e-1)
      b = e2 + 1
    else
      res[#res + 1] = string.sub(str, b)
      break
    end
  end
  return res
end

local function append(dst, src)
  for k,v in pairs(src) do 
    dst[k] = v
  end
  return dst
end

local function clone(t)
  return append({}, t)
end

local function string_trim(s)
  return (string.match(s, '^%s*(.-)%s*$'))
end

local function prequire(name)
  local ok, mod = pcall(require, name)
  if not ok then return nil, mod end
  return mod, name
end

local ENCODERS = {
  ['base64']           = function(msg) return mime.b64(msg) end,
  ['quoted-printable'] = function(msg) return mime.qp (msg) end,
}

local function encoders(t)
  if t == nil then
    return ENCODERS['none']
  end
  local e = ENCODERS[t:lower()]
  if not e then return nil, 'unknown encode type :' .. t end
  return e
end

local function encode_title(title)
  local charset = DEFAULT_CHARSET
  local encode  = DEFAULT_ENCODE

  if type(title) == 'table' then
    charset  = title.charset or charset
    encode   = title.encode or encode
    title    = title[1] or title.title
  end

  if title and #title > 0 then
    local encoder, err = encoders(encode)
    if not encoder then return nil, err end
    local str = encoder(title)
    if str then return "=?" .. charset .. "?" .. encode:sub(1,1) .. "?" .. str .. "?=" end
    return title
  else 
    return ""
  end
end

local function make_t_File (fileName)
  local src
  local name 
  local mime_type   = 'application/octet-stream'
  local disposition = 'attachment'
  local encode      = 'base64'
  local headers     = {}

  if type(fileName) == 'string' then
    local fh, err = io.open(fileName, "rb")
    if not fh then return nil, err end
    src = ltn12.source.file(fh)
    name = basename(fileName)
  elseif type(fileName) == 'table' then
    name = fileName.name
    local path = fileName.path
    local data = fileName.data
    local file = fileName.file
          src  = fileName.source
    if (not name) and path then name = basename(path) end
    if not name then return nil, 'file name require' end
    if data then src = ltn12.source.string(data)
    elseif file then
      if io.type(file) then
        src = ltn12.source.file(file)
      else
        src = file
      end
    elseif path then 
      local fh, err = io.open(path, "rb")
      if not fh then return nil, err end
      src = ltn12.source.file(fh)
    elseif not src then return nil, 'need file/path/data/source' end
    mime_type   = fileName.mime_type   or mime_type
    disposition = fileName.disposition or disposition
    encode      = fileName.encode      or encode
    if fileName.headers then append(headers, fileName.headers) end
  end

  name = encode_title(name)

  assert(src)
  assert(name)
  local encoder, err = mime.encode(encode)
  if not encoder then return nil, err end

  return {
    headers = append(headers, {
      ["content-type"]              = mime_type   .. '; name="'    .. name ..'"',
      ["content-disposition"]       = disposition .. '; filename="'.. name ..'"',
      ["content-transfer-encoding"] = encode,
    }),
    body = ltn12.source.chain(src,
      ltn12.filter.chain(encoder,mime.wrap(encode))
    )
  }
end

local function make_t_Text(data, mime_type, charset, encode)
  local headers = {}
  if type(data) == 'table' then
    charset   = data.charset   or charset
    encode    = data.encode    or encode
    mime_type = data.mime_type or mime_type
    if data.headers then append(headers, data.headers) end
    data      = data[1]        or data.data
  end

  data = data or ''

  local src
  if encode:lower() == '8bit' then src = mime.eol(0, data)
  else
    local encoder, err = mime.encode(encode)
    if not encoder then return nil, err end
    src = ltn12.source.chain(ltn12.source.string(data),
      ltn12.filter.chain(encoder,mime.wrap(encode))
    )
  end
  return {
    headers = append(headers, {
      ["content-type"] = mime_type .. '; charset="' .. charset .. '"',
      ["content-transfer-encoding"] = encode,
    });
    body = src;
  }
end

local function make_t_Body(message)
  assert(message)
  local body = {}
  body.preamble = message.preamble
  body.epilogue = message.epilogue

  if message.text then
    local t, err = make_t_Text(message.text, 'text/plain', DEFAULT_CHARSET, '8bit')
    if not t then return nil, err end
    table.insert(body, t)
  end

  if message.html then
    local t, err = make_t_Text(message.html, 'text/html', DEFAULT_CHARSET, DEFAULT_ENCODE)
    if not t then return nil, err end
    table.insert(body, t)
  end

  if message.file then
    local files = message.file
    if type(files) == "string"  then files = {files} end
    if files.name or files.path then files = {files} end
    for _, file in ipairs(files) do
      local t, err = make_t_File(file)
      if not t then return nil, err end
      table.insert(body, t);
    end
  end

  return body
end

local function make_t_to(to,options)
  local to_ = {}

  local address = to.address
  if type(address) == "string" then
    address = split(address, '%s*[,;]%s*')
  end

  for _,addr in ipairs(address) do 
    addr = "<" .. addr .. ">"
    if options.confirm_sending then
      addr = addr .. " NOTIFY=SUCCESS,FAILURE"
    end
    table.insert(to_,addr)
  end
  return to_
end

local function make_from(t)
  local str = encode_title(t)
  if t.address then str = str .. '<' .. t.address .. '>' end
  return str 
end

local find_cafile do

-- based on  http://curl.haxx.se/docs/sslcerts.html

local DEFAULT_CA_NAME = "curl-ca-bundle.crt"

local function find_ca_by_env()
  local env = setmetatable({},{__index = function(_, name) return os.getenv(name) end})

  if env.SSL_CERT_DIR then return nil, env.SSL_CERT_DIR end

  if env.SSL_CERT_FILE then return env.SSL_CERT_FILE  end
end

local function find_ca_by_fs(name)
  local path = prequire "path"
  if not (path and path.IS_WINDOWS) then return name end

  if name then
    if path.isfile(name)        then return name end
    if path.dirname(name) ~= "" then return name end
  else name = DEFAULT_CA_NAME end

  local env = setmetatable({},{__index = function(_, name) return os.getenv(name) end})

  local paths = {
    '.',
    path.join(env.windir, "System32"),
    path.join(env.windir, "SysWOW64"),
    env.windir,
  }
  for _, p in ipairs(split(env.path, ';', true)) do paths[#paths + 1] = p end

  for _, p in ipairs(paths) do
    p = path.join(path.fullpath(p), name)
    if path.isfile(p) then
      return p
    end
  end
end

local function has(t,k)
  if type(t) == "table" then
    for _, v in ipairs(t) do
      if k == v then return true end
    end
    return false
  end
  return t == k
end

find_cafile = function(params)
  if has(params.verify, "none") then return end

  local cafile, capath = params.cafile, params.capath
  if cafile or capath then
    if cafile then cafile = find_ca_by_fs(cafile) or cafile end
    return cafile, capath
  end

  cafile, capath = find_ca_by_env()
  if cafile or capath then return cafile, capath end

  cafile = find_ca_by_fs()

  return cafile
end

end

local luasec_create do local ssl = prequire "ssl" if ssl then

luasec_create = function(params)
  assert(params)

  if params == true then params = {}
  elseif type(params) == 'string' then params = {protocol = params}
  else params = clone(params) end

  params.mode      = params.mode     or "client"
  params.protocol  = params.protocol or "tlsv1"
  params.verify    = params.verify   or {"peer", "fail_if_no_peer_cert"}
  params.options   = params.options  or "all"

  assert(params.mode == "client")

  local cafile, capath = find_cafile(params)
  if cafile or capath then
    params.cafile, params.capath = cafile, capath
  end

  return function()
    local sock = socket.tcp()

    return setmetatable({
      connect = function(_, host, port)
        local r, e = sock:connect(host, port)
        if not r then return r, e end
        r, e = ssl.wrap(sock, params)
        if not r then return r, e end
        sock = r
        return sock:dohandshake()
      end
    }, {
      __index = function(t,n)
        local fn = function(_, ...)
          return sock[n](sock, ...)
        end
        t[n] = fn
        return fn
      end
    })
  end
end

end end

--------------------------------------------------------
-- make message for smtp.send
--[[!---------------------------------------------------

@param from = address or {
   title / [1]   = string;
   address = string;
   charset = string;
   encode  = string;
}

@param to = address(string) or {
   title / [1] = string;
   address     = string/array of strings
   charset = string;
   encode  = string;
}

@param smtp_server = address or {
   address  = string,
   user     = string,
   password = string,
}

@param message = {
   subject =  title or {
     title / [1]   = string;
     charset = string;
     encode  = string;
   }

   text  = text or {
     data / [1]   = string;
     charset   = string;
     encode    = string;
     mime_type = string
     headers   = table;
   }

   html  = text or {
     data / [1]   = string;
     charset   = string;
     encode    = string;
     mime_type = string
     headers   = table;
   }

   file = file path (string)
   file = {
      name = string;

      -- one of them
      path = string;
      data = string;
      file = file handle(io.file);

     charset   = string;
     encode    = string;
     mime_type = string
     headers   = table;
   }

   preamble = string;
   epilogue = string;
}

@param options = {
  confirm_sending = true
}

@param engine = string (luasocket or curl)

@param curl = {
  handle = <Lua-cURL Easy>,
  async  = boolean,
}
--!]]
local function CreateMail(from, to, smtp_server, message, options)

  options = options or DEFAULT_OPTIONS 
  if type(from)        == 'string' then  from        = { address = from }        end
  if type(to)          == 'string' then  to          = { address = to }          end
  if type(smtp_server) == 'string' then  smtp_server = { address = smtp_server } end
  if not message then  message = {}
  elseif type(message) == 'string' then  message = { subject = message }
  elseif message[1] then
    message = clone(message)
    if not message.subject then 
      message[1], message.subject = nil, message[1]
      if message[2] and not message.text then
        message[2], message.text = nil, message[2]
      end
    elseif not message.text then
      message[1], message.text = nil, message[1]
    end
  end

  -- This headers uses only by mail clients. smtp.send ignores them.
  local headers = clone(DEFAULT_HEADERS)

  local err
  headers['from'], err  = make_from(from)
  if not headers['from'] then return nil, err end

  headers['to'], err = encode_title(to)
  if not headers['to'] then return nil, err end

  to = make_t_to(to, options)
  if (not to and not to[1]) then return nil, 'unknown recipient' end
  headers['to'] = headers['to'] .. (to[1]:match('%b<>') or '')

  if options.confirm_sending then
    headers['Return-Receipt-To']="<" .. (from.address or '') .. ">"
  end

  local source = {}
  if message then
    if message.headers then 
      headers = append(clone(message.headers), headers)
    end

    headers.subject, err = encode_title(message.subject)
    if not headers.subject then
      return nil, err
    end

    local body, err = make_t_Body(message)
    if not body then return nil, err end
    source.body = body
  end
  source.headers = headers
  return {
    from     = from.address and "<" .. from.address .. ">" or '',
    rcpt     = to,
    server   = smtp_server.address,
    user     = smtp_server.user,
    password = smtp_server.password,
    source   = smtp.message(source)
  }
end

local sendmail_curl do

local curl_adjust_ltn12_source = function(fn)
  return function()
    local chunk, err = fn()
    if err and not chunk then
      return nil, err
    end
    return chunk
  end
end

local function curl_set_verify(curl, c, verify)
  if type(verify) == 'string' then
    verify = {verify}
  end

  local flags = {}
  for i = 1, #verify do
    local flag = verify[i]
    flags [flag] = true
  end

  if flags.none then
    c:setopt{
      ssl_verifyhost = false;
      ssl_verifypeer = false;
    }
  elseif flags.host or flags.peer then
    c:setopt{
      ssl_verifyhost = false;
      ssl_verifypeer = false;
    }
    if flags.host then
      c:setopt_ssl_verifyhost(true)
    end
  
    if flags.peer then
      c:setopt_ssl_verifypeer(true)
    end
  end

  flags.none, flags.host, flags.peer = nil

  local flag = next(flags)
  if flag then
    return nil, 'unsupported verify flag: ' .. tostring(flag)
  end

  return true
end

local function curl_set_proto(curl, c, protocol)
  local proto = protocol:sub(1,3):upper() .. protocol:sub(4):lower()
  proto = curl["SSLVERSION_" .. proto]

  if not proto then
    return nil, 'unsupportted protocol: ' .. protocol
  end

  return c:setopt_sslversion(proto)
end

local function curl_set_ssl(curl, c, ssl)
  local ok, err
  if ssl.verify then 
    ok, err = curl_set_verify(curl, c, ssl.verify)
    if not ok then return nil, err end
  end

  ok, err = curl_set_proto(curl, c, ssl.protocol or "TLSv1")
  if not ok then return nil, err end

  if ssl.ciphers then
    ok, err = c:setopt_ssl_cipher_list(ssl.ciphers)
    if not ok then return nil, err end
  end

  if ssl.key then
    ok, err = c:setopt_sslkey(ssl.key)
    if not ok then return nil, err end
  end

  if ssl.certificate then
    ok, err = c:setopt_sslcert(ssl.certificate)
    if not ok then return nil, err end
  end

  local cafile, capath = find_cafile(ssl)

  if capath then
    ok, err = c:setopt_capath(capath)
    if not ok then return nil, err end
  end

  if cafile then
    ok, err = c:setopt_cainfo(cafile)
    if not ok then return nil, err end
  end

  return true
end

local curl
sendmail_curl = function(params, msg)
  curl = curl or require "cURL.safe"
  local url, ssl, port

  if params and params.server then
    ssl = params.server.ssl
    port = params.server.port
  end

  if ssl then
    if ssl == true then
      ssl = {}
    elseif type(ssl) == 'string' then
      ssl = {protocol = ssl}
    else
      ssl = clone(ssl)
    end
    ssl.protocol  = ssl.protocol or "tlsv1"
    ssl.verify    = ssl.verify   or "peer"
  end

  url = (ssl and "smtps://" or "smtp://") .. msg.server
  if port then url = url .. ":" .. tostring(port) end

  local async = params.curl and params.curl.async

  local c, close_c

  if params.curl and params.curl.handle then
    c = params.curl.handle
  else
    c = curl.easy()
    close_c = true
  end

  local ok, err = c:setopt{
    url            = url;
    mail_from      = msg.from;
    mail_rcpt      = msg.rcpt;
    username       = msg.user;
    password       = msg.password;
    upload         = true;
    readfunction   = curl_adjust_ltn12_source(msg.source);
  }
  if not ok then
    if close_c then c:close() end
    return nil, err
  end

  if ssl then
    ok, err = curl_set_ssl(curl, c, ssl)
    if not ok then
      if close_c then c:close() end
      return nil, err
    end
  end

  if async then
    return c, msg
  end

  -- local response
  -- easy:setopt_headerfunction(function(h)
  --   -- this cath the last response from the server.
  --   -- in case of forbid_reuse option is set it will be response for the QUIT command
  --   response = h
  -- end)

  -- if any address e.g. invalid then all operation is fail.
  ok, err = c:perform()
  if not ok then
    if close_c then c:close() end
    return nil, err
  end

  local status, err = c:getinfo_response_code()
  if close_c then c:close() end

  if not status then
    return nil, err
  end

  -- not sure that it possible. Seems libcurl raises error in this case
  -- But just in case.
  if not (status >= 200 and status < 300) then
    return nil, string.format('%d Unknown error', status)
  end
  
  return (type(msg.rcpt) == 'table') and #msg.rcpt or 1
end

end

local sendmail_luasocket do

sendmail_luasocket = function(msg, smtp_server)
  if type(smtp_server) == 'table' then
    local smtp_port = smtp_server.port

    local create_socket = smtp_server.create
    if smtp_server.ssl then
      smtp_port = smtp_port or 465

      if not create_socket then
        if not luasec_create then return nil, "SSL not supported" end
        local err create_socket, err = luasec_create(smtp_server.ssl)
        if not create_socket then return nil, err end
      else
        local base_create_socket = create_socket
        create_socket = function()
          return base_create_socket(smtp_server.ssl)
        end;
      end
    end

    msg.port   = smtp_port
    msg.create = create_socket
  end

  return smtp.send(msg)
end

end

local function sendmail(...)
  local params, from, to, server, message, options

  if type((...)) == 'table' and select('#', ...) == 1 then
    params = ...
    from, to, server, message, options = 
      params.from, params.to, params.server, params.message, params.options
  else
    from, to, server, message, options = ...
  end

  local msg, err = CreateMail(from, to, server, message, options)
  if not msg then return nil, err end

  if params and params.engine == 'curl' then
    return sendmail_curl(params, msg)
  end

  if params and params.engine and params.engine ~= 'luasocket' then
    return nil, 'unsupported engine: ' .. tostring(params.engine)
  end

  return sendmail_luasocket(msg, server)
end

return sendmail