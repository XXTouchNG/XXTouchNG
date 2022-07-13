--- Implement class to decode mime messages
-- @module pop3.message 
--

local DEFAULT_CP_CONV = require "pop3.charset" .convert
local socket_mime     = require "mime" -- luasocket
local socket_ltn12    = require "ltn12" -- luasocket
local CP              = DEFAULT_CP_CONV
local CRLF            = '\r\n'

local DECODERS = {
  ['base64'] = function(nl) 
    local t = {
      -- socket_mime.normalize(), -- decode_content alwas set CRLF for this
      function(msg) return socket_mime.unb64('', msg) end,
    }
    if nl and nl ~= CRLF then
      table.insert(t, function(msg) return socket_mime.eol(0, msg, nl) end)
    end
    return socket_ltn12.filter.chain((unpack or table.unpack)(t))
  end;

  ['quoted-printable'] = function(nl) 
    local t = {
      -- socket_mime.normalize(), -- decode_content alwas set CRLF for this
      function(msg) return socket_mime.unqp('', msg) end,
    }
    if nl and nl ~= CRLF then
      table.insert(t, function(msg) return socket_mime.eol(0, msg, nl) end)
    end
    return socket_ltn12.filter.chain((unpack or table.unpack)(t))
  end;
}


local IS_WINDOWS = (package.config:sub(1,1) == '\\')

-------------------------------------------------------------------------
--
-------------------------------------------------------------------------

local function ltrim(s)
  return (string.gsub (s, "^%s+",""))
end

local function rtrim (s)
  return (string.gsub (s, "%s+$",""))
end

local function trim (s)
  return rtrim(ltrim (s))
end

local function clone (t)
  local u = {}
  for i, v in pairs (t) do
    u[i] = v
  end
  return u
end

local function slice(t, s, e)
  local u = {}
  for i = (s or 1), (e or #t) do
    u[i - s  + 1] = t[i]
  end
  return u
end

local function split(str, sep, plain)
  local b, res = 1, {}
  while b <= #str do
    local e, e2 = string.find(str, sep, b, plain)
    if e then
      table.insert(res, (string.sub(str, b, e-1)))
      b = e2 + 1
    else
      table.insert(res, (string.sub(str, b)))
      break
    end
  end
  return res
end

local decode_str = function (target_charset, base_charset, str)
  if str == nil then return nil end
  if not str:find([[=%?([%w-]+)%?(.)%?(.-)%?=]]) then
    if base_charset then
      return CP(target_charset, base_charset, str)
    end
    return str
  end

  str = str:gsub([[(%?=)%s*(=%?)]],'%1%2') -- Romove ws. Is it necessary?

  return (str:gsub([[=%?([%w-]+)%?(.)%?(.-)%?=]],function(codepage,encoding,data)
    encoding = encoding:upper()
    local algo
    if encoding == 'B'then
      algo = assert(DECODERS['base64'])
    elseif encoding == 'Q' then
      algo = assert(DECODERS['quoted-printable'])
    end
    if algo then 
      data = algo()(data)
      return CP(target_charset, codepage, data)
    end
  end))
end

local function as_date(str) return str end
-- if pcall( require, "date" ) then
--   as_date = function (str) local d = date(str) return d or str end
-- end

-------------------------------------------------------------------------
-- разбирает заголовки to, from и т.д  в список структур {name=;addr=}
--  оба параметра не обязытельные
local get_address_list do

local function prequire(...)
  local ok, mod = pcall(require, ...)
  return ok and mod, mod
end

local re = prequire "re"

if re then

local function try_load_get_address_list()
  -- @todo unquot quoted name
  local mail_pat = re.compile[[
    groups            <- (group (%s* ([,;] %s*)+ group)*) -> {}
    group             <- (
                            {:name: <phrase> :} %s* <addr>                  /
                            {:name: <uq_phrase> :} %s* "<" <addr_spec> ">"  /
                            <addr> %s* {:name: <phrase> :}                  /
                            "<" <addr_spec> ">" %s* {:name: <uq_phrase> :}  /
                            <addr>                                          /
                            {:name: <phrase> :}                              
                          ) -> {}

    uq_phrase          <- <uq_atom> (%s+ <uq_atom>)*
    uq_atom            <- [^<>,; ]+

    phrase            <- <word> ([%s.]+ <word>)* /  <quoted_string>
    word              <- <atom> ! <domain_addr>

    atom              <- [^] %c()<>@,;:\".[]+
    quoted_string     <- '"' ([^"\%nl] / "\" .)*  '"'

    addr              <- <addr_spec> / "<" <addr_spec> ">"
    addr_spec         <- {:addr: <addr_chars> <domain_addr> :}
    domain_addr       <- "@" <addr_chars>
    addr_chars        <- [_%a%d][-._%a%d]*
  ]]

  return function(str)
    if (not str) or (str == '') then
      return nil
    end
    return mail_pat:match(str)
  end
end

local ok, fn = pcall(try_load_get_address_list)

if ok then get_address_list = fn end

if get_address_list then -- test --
local cmp_t

local function cmp_v(v1,v2)
  local flag = true
  if type(v1) == 'table' then
    flag = (type(v2) == 'table') and cmp_t(v1, v2)
  else
    flag = (v1 == v2)
  end
  return flag
end

function cmp_t(t1,t2)
  for k in pairs(t2)do
    if t1[k] == nil then
      return false
    end
  end
  for k,v in pairs(t1)do
    if not cmp_v(t2[k],v) then 
      return false 
    end
  end
  return true
end

local tests = {}
local tests_index={}

local test = function(str, result) 
  local t 
  if type(result) == 'string' then
    local res = assert(tests_index[str])
    t = {result, result = res.result}
    assert(result ~= str)
    tests_index[result] = t;
  else
    t = {str,result=result}
    tests_index[str] = t;
  end
  return table.insert(tests,t)
end

assert(get_address_list() == nil)
assert(get_address_list('') == nil)

test([[aaa@mail.ru]],
  {{
      addr = "aaa@mail.ru"
  }}
)
test([[aaa@mail.ru]],[[<aaa@mail.ru>]])

test([["aaa@mail.ru"]],
  {{
      name = '"aaa@mail.ru"'
  }}
)

test([[Subscriber YPAG.RU <aaa@mail.ru>]],
  {{
      name = "Subscriber YPAG.RU",
      addr = "aaa@mail.ru"
  }}
)

test([[Subscriber YPAG.RU <aaa@mail.ru>]], [[<aaa@mail.ru> Subscriber YPAG.RU]])

test([["Subscriber YPAG.RU" <aaa@mail.ru>]],
  {{
      name = '"Subscriber YPAG.RU"',
      addr = "aaa@mail.ru"
  }}
)
test([["Subscriber YPAG.RU" <aaa@mail.ru>]],[[<aaa@mail.ru> "Subscriber YPAG.RU"]])

test([["Subscriber ;,YPAG.RU" <aaa@mail.ru>]],
  {{
      name = '"Subscriber ;,YPAG.RU"',
      addr = "aaa@mail.ru"
  }}
)

test([[Subscriber ;,YPAG.RU <aaa@mail.ru>]],
  {
    {
      name = "Subscriber"
    },
    {
      name = "YPAG.RU",
      addr = "aaa@mail.ru"
    }
  }
)

test([["Subscriber ;,YPAG.RU" <aaa@mail.ru>]],[[<aaa@mail.ru> "Subscriber ;,YPAG.RU"]])

test([[info@arenda-a.com, travel@mama-africa.ru; info@some.mail.domain.ru ]],
  {
    {
      addr = "info@arenda-a.com"
    },
    {
      addr = "travel@mama-africa.ru"
    },
    {
      addr = "info@some.mail.domain.ru"
    }
  }
)
test([[info@arenda-a.com, travel@mama-africa.ru; info@some.mail.domain.ru ]],
     [[<info@arenda-a.com>, travel@mama-africa.ru; info@some.mail.domain.ru ]])

test([["name@some.mail.domain.ru" <addr@some.mail.domain.ru>]],
  {
    {
      name = "\"name@some.mail.domain.ru\"",
      addr = "addr@some.mail.domain.ru"
    }
  }
)
test([[name@some.mail.domain.ru <addr@some.mail.domain.ru>]],
  {
    {
      name = "name@some.mail.domain.ru",
      addr = "addr@some.mail.domain.ru"
    }
  }
)

test([[MailList: рассылка номер 78236 <78236-response@maillist.ru>]],
  {
    {
      name = "MailList: рассылка номер 78236",
      addr = "78236-response@maillist.ru"
    }
  }
)

test([[<aaa@mail.ru>, "Info Mail List" <bbb@mail.ru>, Сакен Матов <saken@from.kz>, "Evgeny Zhembrovsky \(ezhembro\)" <ezhembro@cisco.com> ]],
  {
    {
      addr = "aaa@mail.ru"
    },
    {
      name = "\"Info Mail List\"",
      addr = "bbb@mail.ru"
    },
    {
      name = "Сакен Матов",
      addr = "saken@from.kz"
    },
    {
      name = "\"Evgeny Zhembrovsky \\(ezhembro\\)\"",
      addr = "ezhembro@cisco.com"
    }
  }
)

if POP3_SELF_TEST then
  local lunit = require"lunit"
  function test_pop3_messege_get_address_list()
    for _, test_case in ipairs(tests) do
      lunit.assert_true(cmp_t(get_address_list(test_case[1]),test_case.result),test_case[1])
    end
  end
end

if POP3_DEBUG then
  for _,test_case in ipairs(tests)do
    local res = get_address_list(test_case[1])
    if not cmp_v(res, test_case.result ) then
      require "pprint"
      print"----------------------------------------------"
      print("ERROR:", test_case[1])
      print"EXPECTED:"
      pprint(test_case.result)
      print"RESULT:"
      pprint(res)
    end
  end
end

--verify
for _,test_case in ipairs(tests)do
  local res = get_address_list(test_case[1])
  if not cmp_v(res, test_case.result) then
    get_address_list = nil
  end
end

end -- test --

end -- require "re" --
end -- get_address_list --
-------------------------------------------------------------------------

-------------------------------------------------------------------------
--
-------------------------------------------------------------------------

local DEFAULT_LOCAL_CP = 'utf-8'

if IS_WINDOWS then DEFAULT_LOCAL_CP = require("pop3.win.cp").GetLocalCPName() end

local DEFAULT_NL = IS_WINDOWS and CRLF or '\n'

local MIME_ERR_NO_BOUNDARY = "Malformed mime header. No boundary in content-type."
local MIME_ERR_BOUNDARY_TOO_LONG = "Malformed mime header. Boundary is too long."
local MIME_ERR_BOUNDARY_NOCLOSE = "Malformed mime header. Boundary is not closed."

-------------------------------------------------------------------------
--
-------------------------------------------------------------------------
local mime = {}
local mime_header  = {}
local mime_headers = {}
local mime_content = {}
local mime_content_multipart = {}

--------------------------------------------------------------------------
do -- mime_content_multipart

local mime_content_multipart_mt = {
  __index = function(self, k)
    if type(k) == 'number' then
      return self.content_[k]
    end
    return mime_content_multipart[k]
  end;

  __len = function(self)
    return #self.content_
  end;
}

function mime_content_multipart:parts()
  return #self.content_
end

setmetatable(mime_content_multipart,{__call = function (self, headers, msg, index_begin, index_end)
  assert(index_begin <= index_end)
  assert(index_end <= #msg)

  local boundary = headers:param('content-type', 'boundary')
  if not boundary then return nil, MIME_ERR_NO_BOUNDARY end
  boundary       = '--' .. boundary
  local boundary_close = boundary .. '--'

  if #boundary > 72 then return nil, MIME_ERR_BOUNDARY_TOO_LONG end

  local result = setmetatable({},mime_content_multipart_mt)
  result.is_multi = true
  result.content_ = {} -- array
  
  local i = index_begin
  while i <= index_end do
    while(i <= index_end)do
      if msg[i] == boundary or msg[i] == boundary_close then
        break
      end
      i = i + 1
    end
    if i > index_end then break end
    local line = msg[i]

    if line == (boundary_close) then 
      i = index_end + 1
      break
    end
    assert(line == boundary)

    i = i + 1
    local cstart = i
    while(i <= index_end)do
      if msg[i] == boundary or msg[i] == boundary_close then
        break
      end
      i = i + 1
    end
    if i > index_end then result.is_truncated = true end
    -- if i > index_end then return nil, MIME_ERR_BOUNDARY_NOCLOSE  end
    local cend = i - 1
    local content, err, i1, i2 = mime(msg, cstart, cend)
    if not content then 
      return nil, err, i1, i2 
    end
    table.insert(result.content_, content)
  end
  assert(i == (index_end + 1))
  return result, i
end})

end
--------------------------------------------------------------------------

--------------------------------------------------------------------------
do -- mime_content

function mime_content:as_string(sep)
  return table.concat(self.message_, sep or '', self.bound_[1], self.bound_[2])
end

function mime_content:as_table()
  return slice(self.message_, self.bound_[1], self.bound_[2])
end;

setmetatable(mime_content,{__call = function(self, mtype, headers, msg, index_begin, index_end)
  if  string.sub(mtype,1,9) == 'multipart' then
    return mime_content_multipart(headers, msg, index_begin, index_end)
  end

  local result = {} --clone(self)
  result.is_data  = true;
  result.message_ = msg;-- or create closure?
  result.bound_   = {index_begin, index_end};

  return setmetatable(result,
    { __tostring = self.as_string, __index = self }
  )
end})

end
--------------------------------------------------------------------------

--------------------------------------------------------------------------
do -- mime_header

function mime_header:value()
  return self.value_
end

function mime_header:key()
  return self.key_
end

function mime_header:param(key)
  return self.param_[key]
end

setmetatable(mime_header,{__call = function (self, str)
  local result = setmetatable({},{__index = self}) --clone(self)
  result.raw_   = str;
  result.value_ = "";
  result.param_ = {}


  local key_index = string.find(str, ":", 1, true)
  local key = key_index and (string.sub(str, 1, key_index-1)) or str
  key = string.lower(trim(key))
  result.key_ = key
  if not key_index then return result end
  str = rtrim(string.sub(str, key_index + 1))
  if string.sub(str, -1) ~= ';' then str = str .. ';' end

  local par_index = string.find(str, ';%s*[^%s=]+%s*=%s*.-;')
  local value = par_index and (string.sub(str, 1, par_index - 1)) or string.sub(str,1,-2)
  result.value_ = trim(value)
  -- result.value_ = string.lower(trim(value))
  if not par_index then return result end

  str = string.sub(str, par_index)
  local param = {}
  for key, value in string.gmatch(str, "[;]?%s*([^%s=]+)%s*=%s*(.-);") do
    if not string.find(key, [[^%?([%w-]+)%?(.)%?]]) then -- "?utf-8?B?..."=
      if string.sub(value, 1, 1) == '"' then
          value = string.sub(value, 2, -2 )
          value = string.gsub(value, '""', '"') --??
      else
        value = trim(value)
      end
      key = string.lower(trim(key)) -- trim just in case
      param[ key ] = value
    end
  end

  result.param_ = param;
  return result
end})

end
--------------------------------------------------------------------------

--------------------------------------------------------------------------
do -- mime_headers

function mime_headers:header(key)
  assert(key)
  key = string.lower(key)
  for i, h in ipairs (self.headers_) do
    if h:key() == key then
      return h
    end
  end
end

function mime_headers:value(key,def)
  local h = self:header(key)
  return h and h:value() or def
end

function mime_headers:param(key, param, def)
  local h = self:header(key)
  if h then return h:param(param) or def end
  return def
end

function mime_headers:headers(key)
  assert(key)
  key = string.lower(key)
  local result = {}
  for i, h in ipairs (self.headers_) do
    if h:key() == key then
      table.insert(result, h)
    end
  end
  return result
end

function mime_headers:as_table(key)
  key = key and string.lower(key)
  local result = {}
  for i, h in ipairs (self.headers_) do
    if (not key) or (h:key() == key) then
      if result[h:key()] == nil then
        result[h:key()] = h.raw_
      end
    end
  end
  return result
end

setmetatable(mime_headers,{__call = function (self, msg, index_begin, index_end)
  local buffer = {}
  local result = setmetatable({},{__index = self})

  result.headers_={} -- array

  for i = index_begin, index_end do
    local line = msg[i] or ""
    if line:find("^%s") then
      table.insert(buffer,ltrim(line))
    else
      if buffer[1] then
        local str = table.concat(buffer, " ")
        local header = mime_header(str)
        table.insert(result.headers_, header)
      end
      buffer = {rtrim(line)}
    end
    if line == "" then return result, i + 1 end
  end
  return result, index_end + 1
end})

end
--------------------------------------------------------------------------

--------------------------------------------------------------------------
do -- mime

---
-- @type mime

mime.cp_ = assert(DEFAULT_LOCAL_CP)
mime.eol_ = assert(DEFAULT_NL)

--- Return mime type
-- return value of 'content-type' header
function mime:type()
  return self.type_
end

--- Set target codepage 
-- This codepage use when need decode text data.
function mime:set_cp(cp)
  self:for_each(function(t) assert(t.cp_); t.cp_ = cp end)
end

--- Set target EOL
-- This EOL use when need decode text data.
function mime:set_eol(nl)
  self:for_each(function(t) assert(t.eol_); t.eol_ = nl end)
end

--- Retrun current codepage to decode.
-- This is not codepage message itself.
function mime:cp()
  return self.cp_
end

--- Retrun current EOL to decode.
-- This is not EOL message itself.
function mime:eol()
  return self.eol_
end

---
--
function mime:hvalue(key, def)
  return self.headers:value(key, def)
end

---
--
function mime:hparam(key, param, def)
  return self.headers:param(key, param, def)
end

---
--
function mime:header(key)
  return self.headers:header(key)
end

---
--
function mime:subject()
  return decode_str(self:cp(), self:charset(), self:hvalue("subject",''))
end

---
-- @treturn string
function mime:from()
  return decode_str(self:cp(), self:charset(), self:hvalue("from"))
end

---
-- @treturn string
function mime:to()
  return decode_str(self:cp(), self:charset(), self:hvalue("to"))
end

---
-- @treturn string
function mime:reply_to()
  return decode_str(self:cp(), self:charset(), self:hvalue("reply-to"))
end

if get_address_list then

---
-- Depends on lpeg library
-- @treturn table {{name=...,addr=...}, ...}
function mime:from_list()
  return get_address_list(self:from())
end

---
-- Depends on lpeg library
-- @treturn table {{name=...,addr=...}, ...}
function mime:to_list()
  return get_address_list(self:to())
end

---
-- Depends on lpeg library
-- @treturn table {{name=...,addr=...}, ...}
function mime:reply_list()
  return get_address_list(self:reply_to())
end

---
-- Depends on lpeg library
-- @treturn string address
-- @treturn string name
function mime:from_address()
  local t = self:from_list()
  if t then
    for _,k in ipairs(t) do
      if k and k.addr then
        return k.addr, k.name
      end
    end
  end
end

---
-- Depends on lpeg library
-- @treturn string address
-- @treturn string name
function mime:to_address()
  local t = self:to_list()
  if t then
    for _,k in ipairs(t) do
      if k and k.addr then
        return k.addr, k.name
      end
    end
  end
end

---
-- Depends on lpeg library
-- @treturn string address
-- @treturn string name
function mime:reply_address()
  local t = self:reply_list()
  if t then
    for _,k in ipairs(t) do
      if k and k.addr then
        return k.addr, k.name
      end
    end
  end

  return self:from_address()
end

end

function mime:as_string(nl)
  return table.concat(self.message_, nl or CRLF, self.bound_[1], self.bound_[2])
end

function mime:as_table()
  return slice(self.message_, self.bound_[1], self.bound_[2])
end

---
--
function mime:id()
  return self:hvalue("message-id", '')
end

---
--
function mime:date()
  local h = self:header("date")
  return h and as_date(h:value()) or ''
end

---
--
function mime:encoding()
  return self:hvalue("content-transfer-encoding")
end

---
--
function mime:charset()
  return self:hparam("content-type", "charset", self:cp())
end

---
--
function mime:content_name()
  local h = self:hparam("content-type", "name")
  if h then return decode_str(self:cp(), self:charset(), h) end
end

---
--
function mime:file_name()
  local h = self:hparam("content-disposition", "filename")
  if h then return decode_str(self:cp(), self:charset(), h) end
end

---
--
function mime:disposition()
  return self:hvalue("content-disposition")
end

---
--
function mime:is_application()
  return self:type():sub(1,11) == 'application'
end

---
--
function mime:is_text()
  return self:type():sub(1,4) == 'text'
end

---
--
function mime:is_rfc822()
  return self:type() == 'message/rfc822'
end

---
--
function mime:is_truncated()
  return self.content.is_truncated
end

---
--
function mime:is_multi()
  return self.content.is_multi
end

---
--
function mime:is_data()
  return self.content.is_data
end

---
--
function mime:is_binary()
  return (not self:is_text()) and (not self:is_multi())
end

---
--
function mime:is_attachment()
  local h = self:disposition()
  return h and h:sub(1,10):lower() == 'attachment'
end

---
--
function mime:for_each(fn, ...)
  fn(self, ...)
  if self:is_multi() then 
    for k, part in ipairs(self.content.content_) do
      fn(part, ...)
      if part:is_multi() then part:for_each(fn, ...) end
    end
  end
end

---
--
function mime:decode_content()
  assert(self.content)
  if self:is_data() then
    local data
    local encoding = self:encoding()
    if encoding then 
      local algo = DECODERS[encoding:lower()]
      if algo then 
        local content = self.content:as_string(CRLF)
        data = algo(self:is_text() and self:eol())( content )
      end
    end

    if self:is_text() then
      local charset = self:charset()
      data = data or self.content:as_string(self:eol())
      if charset then return CP(self:cp(), charset, data) end
      return data
    end

    if self:is_rfc822() then
      if data then
        data = split(data, CRLF, true)
        data = mime(data)
      else
        data = mime(self.content.message_, self.content.bound_[1], self.content.bound_[2])
      end
      return data
    end

    return data or self.content:as_string()
  end
  return self.content
end

local function grab_text(self)
  return{
    text        = self:decode_content(),
    type        = self:type(),
    disposition = self:disposition()
  }
end

local function grab_binary(self)
  local name = self:is_rfc822() and 'message' or 'data'
  return{
    [name]      = self:decode_content(),
    name        = self:content_name(),
    file_name   = self:file_name(),
    type        = self:type(),
    disposition = self:disposition()
  }
end

local function content_collector(self, dst)
  dst = dst or {}
  if self:is_binary() then
    table.insert( dst, grab_binary(self) )
  elseif self:is_text() then
    table.insert( dst, grab_text(self) )
  else
    assert(self:is_multi())
  end
end

local function if_collector(self, pred, grab, dst)
  dst = dst or {}
  if pred(self) then
    table.insert( dst, grab(self) )
  end
end

function mime:collect(collector,t)
  t = t or {}
  self:for_each(collector, t)
  return t
end

function mime:collect_if(pred, grab, t)
  t = t or {}
  self:for_each(if_collector, pred, grab, t)
  return t
end

---
--
function mime:full_content()
  return self:collect(content_collector)
end

--- Return all attachments from message
--
function mime:attachments()
  return self:collect_if(self.is_attachment, grab_binary)
end

--- Return all binary parts of message
--
function mime:objects()
  return self:collect_if(self.is_binary, grab_binary)
end

--- Return text part of message
--
function mime:text()
  return self:collect_if(self.is_text, grab_text)
end

setmetatable(mime,{__call = function (self, msg, index_begin, index_end)
  index_begin, index_end = index_begin or 1, index_end or #msg
  local result = setmetatable({},{__index = self}) -- clone(self)
  result.bound_   = {index_begin, index_end};
  result.message_ = msg;

  local headers, index = mime_headers(msg, index_begin, index_end)
  result.headers = headers
  result.type_ = result:hvalue('content-type', 'text/plain'):lower()
  local err
  result.content, err = mime_content(result:type(), headers, msg, index, index_end)
  if not result.content then 
    return nil, err, index_begin, index_end
  end
  return result
end})
end
--------------------------------------------------------------------------

local setmetatable = setmetatable
local M = {}

function M.set_cp(cp) DEFAULT_LOCAL_CP = cp end

-- conv(target_charset, base_charset, str)
function M.set_cp_converter(conv) CP = (conv or DEFAULT_CP_CONV) end

function M.set_eol(nl) DEFAULT_NL = nl end

function M.cp() return DEFAULT_LOCAL_CP end

function M.cp_converter() return CP end

function M.eol() return DEFAULT_NL end

setmetatable(M, {__call = function(self, msg, ...)
  if type(msg) == "string" then msg = split(msg, CRLF, true) end
  return mime(msg, ...)
end})

return M

--[[
mime
 |
 +- bound_ = {index_begin, index_end} -- full mime
 |
 +- message_ = msg 
 |
 +- type_ = hvalue 'content-type'
 |
 +- headers = array of mime header(mime_headers object)
 |
 +- content
     |
     \- mime_content           - for data part (text, file, image etc.)
        is_data  = true
        message_ = msg 
        bound_   = {index_begin, index_end}  -- only data (without headers)
     \- mime_content_multipart -  for multipart 
        is_multi = true
        content_ = array of mime 
--]]
