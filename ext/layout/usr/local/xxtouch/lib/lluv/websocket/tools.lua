-- Code based on https://github.com/lipp/lua-websockets

local bit = require'lluv.websocket.bit'

local function prequire(m)
  local ok, err = pcall(require, m)
  if ok then return err, m end
  return nil, err
end

local function orequire(...)
  for _, name in ipairs{...} do
    local mod = prequire(name)
    if mod then return mod, name end
  end
end

local function vrequire(...)
  local m, n = orequire(...)
  if m then return m, n end
  error("Can not fine any of this modules: " .. table.concat({...}, "/"), 2)
end

local function read_n_bytes(str, pos, n)
  return pos+n, string.byte(str, pos, pos + n - 1)
end

local function read_int16(str, pos)
  local a, b pos,a,b = read_n_bytes(str, pos, 2)
  return pos, bit.lshift(a, 8) + b
end

local function read_int32(str, pos)
  local a, b, c, d
  pos, a, b, c, d = read_n_bytes(str, pos, 4)
  return pos,
    bit.lshift(a, 24) + 
    bit.lshift(b, 16) + 
    bit.lshift(c, 8 ) + 
    d
end

local function pack_bytes(...)
  return string.char(...)
end

local function pack_int16(v)
  return pack_bytes(bit.rshift(v, 8), bit.band(v, 0xFF))
end

local function pack_int32(v)
  return pack_bytes(
    bit.band(bit.rshift(v, 24), 0xFF),
    bit.band(bit.rshift(v, 16), 0xFF),
    bit.band(bit.rshift(v,  8), 0xFF),
    bit.band(v, 0xFF)
  )
end

local bits = function(...)
  local n = 0
  for _,bitn in pairs{...} do n = n + 2^bitn end
  return n
end

-- used for generate key random ops
math.randomseed(os.time())

-- SHA1 hashing from luacrypto, lmd5 (previewsly is was ldigest) if available
local shalib, name = orequire('crypto', 'sha1', 'bgcrypto.sha1', 'digest')
local sha1_digest do

if name == 'sha1' then
  sha1_digest = function(str) return shalib.digest(str, true) end
elseif name == 'crypto' then
  sha1_digest = function(str) return shalib.digest('sha1', str, true) end
elseif name == 'bgcrypto.sha1' then
  sha1_digest = function(str) return shalib.digest(str) end
elseif name == 'digest' then
  if _G.sha1 and _G.sha1.digest then
    shalib = _G.sha1
    sha1_digest = function(str) return shalib.digest(str, true) end
  end
end

if not sha1_digest then
local rol, bxor, bor, band, bnot = bit.rol or bit.lrotate, bit.bxor, bit.bor, bit.band, bit.bnot
local srep, schar = string.rep, string.char

-- from wiki article, not particularly clever impl
sha1_digest = function(msg)
  local h0 = 0x67452301
  local h1 = 0xEFCDAB89
  local h2 = 0x98BADCFE
  local h3 = 0x10325476
  local h4 = 0xC3D2E1F0

  local bits = #msg * 8
  -- append b10000000
  msg = msg..schar(0x80)

  -- 64 bit length will be appended
  local bytes = #msg + 8

  -- 512 bit append stuff
  local fill_bytes = 64 - (bytes % 64)
  if fill_bytes ~= 64 then
    msg = msg..srep(schar(0),fill_bytes)
  end

  -- append 64 big endian length
  local high = math.floor(bits/2^32)
  local low = bits - high*2^32
  msg = msg..pack_int32(high)..pack_int32(low)

  assert(#msg % 64 == 0,#msg % 64)

  for j=1,#msg,64 do
    local chunk = msg:sub(j,j+63)
    assert(#chunk==64,#chunk)
    local words = {}
    local next = 1
    local word
    repeat
      next,word = read_int32(chunk, next)
      words[#words + 1] = word
    until next > 64
    assert(#words==16)
    for i=17,80 do
      words[i] = bxor(words[i-3],words[i-8],words[i-14],words[i-16])
      words[i] = rol(words[i],1)
    end
    local a = h0
    local b = h1
    local c = h2
    local d = h3
    local e = h4

    for i=1,80 do
      local k,f
      if i > 0 and i < 21 then
        f = bor(band(b,c),band(bnot(b),d))
        k = 0x5A827999
      elseif i > 20 and i < 41 then
        f = bxor(b,c,d)
        k = 0x6ED9EBA1
      elseif i > 40 and i < 61 then
        f = bor(band(b,c),band(b,d),band(c,d))
        k = 0x8F1BBCDC
      elseif i > 60 and i < 81 then
        f = bxor(b,c,d)
        k = 0xCA62C1D6
      end

      local temp = rol(a,5) + f + e + k + words[i]
      e = d
      d = c
      c = rol(b,30)
      b = a
      a = temp
    end

    h0 = h0 + a
    h1 = h1 + b
    h2 = h2 + c
    h3 = h3 + d
    h4 = h4 + e

  end

  -- necessary on sizeof(int) == 32 machines
  h0 = band(h0,0xffffffff)
  h1 = band(h1,0xffffffff)
  h2 = band(h2,0xffffffff)
  h3 = band(h3,0xffffffff)
  h4 = band(h4,0xffffffff)

  return pack_int32(h0)..pack_int32(h1)..pack_int32(h2)..pack_int32(h3)..pack_int32(h4)
end
end

end

local base, name = vrequire("mime", "base64", "basexx")
local base64 = {} if name == 'basexx' then
  base64.encode = function(str) return base.to_base64(str)   end
  base64.decode = function(str) return base.from_base64(str) end
elseif name == 'mime' then
  base64.encode = function(str) return base.b64(str)  end
  base64.decode = function(str) return base.ub64(str) end
elseif name == 'base64' then
  base64.encode = function(str) return base.encode(str)  end
  base64.decode = function(str) return base.decode(str) end
end

local DEFAULT_PORTS = {ws = 80, wss = 443, http = 80, https = 443}

local parse_url = function(url)
  local protocol, address, uri = url:match('^(%w+)://([^/]+)(.*)$')
  if not protocol then error('Invalid URL:'..url) end
  protocol = protocol:lower()
  local host, port = address:match("^(.+):(%d+)$")
  if not host then
    host = address
    port = DEFAULT_PORTS[protocol]
  end
  if not uri or uri == '' then uri = '/' end
  return protocol, host, tonumber(port), uri
end

local generate_key = function()
  local r1 = math.random(0,0xfffffff)
  local r2 = math.random(0,0xfffffff)
  local r3 = math.random(0,0xfffffff)
  local r4 = math.random(0,0xfffffff)
  local key = pack_int32(r1)..pack_int32(r2)..pack_int32(r3)..pack_int32(r4)
  assert(#key==16,#key)
  return base64.encode(key)
end

return {
  sha1         = sha1_digest,
  base64       = base64,
  parse_url    = parse_url,
  generate_key = generate_key,
  read_n_bytes = read_n_bytes;
  read_int16   = read_int16;
  read_int32   = read_int32;
  pack_bytes   = pack_bytes;
  pack_int16   = pack_int16;
  pack_int32   = pack_int32;
  bits         = bits;
}
