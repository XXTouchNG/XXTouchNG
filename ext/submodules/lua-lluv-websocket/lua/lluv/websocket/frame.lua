-- Code based on https://github.com/lipp/lua-websockets

local string  = require "string"
local table   = require "table"
local math    = require "math"
local bit     = require "lluv.websocket.bit"
local tools   = require "lluv.websocket.tools"

local read_n_bytes, read_int16, read_int32, pack_bytes, pack_int16, pack_int32, bits =
  tools.read_n_bytes, tools.read_int16, tools.read_int32,
  tools.pack_bytes, tools.pack_int16, tools.pack_int32, tools.bits

local unpack  = unpack or table.unpack

local bit_0_3 = bits(0,1,2,3)
local bit_5   = bits(5)
local bit_4   = bits(4)
local bit_6   = bits(6)
local bit_7   = bits(7)
local bit_0_6 = bits(0,1,2,3,4,5,6)

local function xor_mask(encoded, pos, mask, payload, offset)
  local transformed, transformed_arr = {},{}
  local fin, m = pos+payload-1, #mask
  offset = offset or 0
  for p=pos,fin,2000 do
    local last = math.min(p+1999,fin)
    local original = {string.byte(encoded,p,last)}
    for i=1,#original do
      local j = (i + offset - 1) % m + 1
      transformed[i] = bit.bxor(original[i],mask[j])
    end
    local xored = string.char(unpack(transformed,1,#original))
    transformed_arr[#transformed_arr + 1] = xored
  end
  return table.concat(transformed_arr), (offset + payload) % m
end

local decode_by_pos = function(encoded, pos)
  pos = pos or 1
  local start = pos
  local size = #encoded
  local left = size - pos + 1

  if left < 2 then return nil, 2 - left, nil, start end

  local pos, header, payload = read_n_bytes(encoded, pos, 2)

  local masked = bit.band(payload, bit_7) ~= 0
  payload      = bit.band(payload, bit_0_6)

  left = size - pos + 1
  if payload > 125 then
    if payload == 126 then
      if left < 2 then
        return nil, 2 - left, nil, start
      end
      pos, payload = read_int16(encoded, pos)
    elseif payload == 127 then
      if left < 8 then
        return nil, 8 - left, nil, start
      end
      local high, low
      pos, high = read_int32(encoded, pos)
      pos, low  = read_int32(encoded, pos)
      payload = high * 2^32 + low
      if payload < 0xFFFF or payload > 2^53 then
        assert(false, 'INVALID PAYLOAD '..payload)
      end
    else
      assert(false, 'INVALID PAYLOAD ' .. payload)
    end
  end

  left = size - pos + 1
  local decoded
  if masked then
    local tail_size = (payload + 4) - left
    if tail_size > 0 then
      return nil, tail_size, nil, start
    end

    local m1,m2,m3,m4
    pos,m1,m2,m3,m4 = read_n_bytes(encoded, pos, 4)
    local mask = {m1,m2,m3,m4}

    decoded = xor_mask(encoded, pos, mask, payload)
    pos = pos + payload
  else
    local tail_size = payload - left
    if tail_size > 0 then
      return nil, tail_size, nil, start
    end

    decoded = string.sub(encoded, pos, pos + payload - 1)
    pos = pos + payload
  end

  local fin    = bit.band(header, bit_7) ~= 0
  local rsv1   = bit.band(header, bit_6) ~= 0
  local rsv2   = bit.band(header, bit_5) ~= 0
  local rsv3   = bit.band(header, bit_4) ~= 0
  local opcode = bit.band(header, bit_0_3)

  return decoded,fin,opcode,pos,masked,rsv1,rsv2,rsv3
end

local decode = function(encoded)
  local decoded, fin, opcode, pos, masked, rsv1, rsv2, rsv3 = decode_by_pos(encoded, 1)
  local rest
  if decoded then
    local rest = encoded:sub(pos)
    return decoded, fin, opcode, rest, masked, rsv1, rsv2, rsv3
  end
  return decoded, fin
end

local encode = function(data, opcode, masked, fin, rsv1, rsv2, rsv3)
  local header = bit.bor(opcode or 1, -- TEXT is default opcode
    rsv1 and bit_6 or 0,
    rsv2 and bit_5 or 0,
    rsv3 and bit_4 or 0
  )

  if fin == nil or fin == true then
    header = bit.bor(header, bit_7)
  end

  local payload = 0
  if masked then
    payload = bit.bor(payload,bit_7)
  end

  local len = #data
  if len < 126 then
    payload = bit.bor(payload,len)
    header  = pack_bytes(header, payload)
  elseif len <= 0xffff then
    payload = bit.bor(payload,126)
    header  = pack_bytes(header, payload,
      bit.rshift(len, 8), bit.band(len, 0xFF) -- pack_int16(len)
    )
  elseif len < 2^53 then
    local high = math.floor(len/2^32)
    local low = len - high*2^32
    payload = bit.bor(payload,127)
    header  = pack_bytes(header, payload) .. pack_int32(high) .. pack_int32(low)
  end

  local encoded
  if not masked then
    encoded = header .. data
  else
    local m1 = math.random(0,0xff)
    local m2 = math.random(0,0xff)
    local m3 = math.random(0,0xff)
    local m4 = math.random(0,0xff)
    local mask = {m1,m2,m3,m4}
    encoded = table.concat{
      header, pack_bytes(m1,m2,m3,m4),
      (xor_mask(data, 1, mask, #data))
    }
  end

  return encoded
end

local encode_close = function(code, reason)
  if code then
    local data = pack_int16(code)
    if reason then
      data = data..tostring(reason)
    end
    return data
  end
  return ''
end

local decode_close = function(data)
  local _, code, reason
  if data then
    if #data > 1 then
      _, code = read_int16(data, 1)
      if #data > 2 then
        reason = data:sub(3)
      end
    end
  end
  return code,reason
end

return {
  encode        = encode,
  decode_by_pos = decode_by_pos,
  decode        = decode,
  encode_close  = encode_close,
  decode_close  = decode_close,
  CONTINUATION  = 0,
  TEXT          = 1,
  BINARY        = 2,
  CLOSE         = 8,
  PING          = 9,
  PONG          = 10
}
