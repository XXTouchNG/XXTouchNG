-- Code based on https://github.com/lipp/lua-websockets

local tools = require 'lluv.websocket.tools'
local sha1, base64 = tools.sha1, tools.base64

local guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

local function tappend(t, v)
  t[#t+1]=v
  return t
end

local function trim(s)
  return string.match(s, "^%s*(.-)%s*$")
end

local function unquote(s)
  if string.sub(s, 1, 1) == '"' then
    s = string.sub(s, 2, -2)
    s = string.gsub(s, "\\(.)", "%1")
  end
  return s
end

local function enqute(s)
  if string.find(s, '[ ",;]') then
    s = '"' .. string.gsub(s, '"', '\\"') .. '"'
  end
  return s
end

------------------------------------------------------------------
local split = {} do
function split.iter(str, sep, plain)
  local b, eol = 0
  return function()
    if b > #str then
      if eol then eol = nil return "" end
      return
    end

    local e, e2 = string.find(str, sep, b, plain)
    if e then
      local s = string.sub(str, b, e-1)
      b = e2 + 1
      if b > #str then eol = true end
      return s
    end

    local s = string.sub(str, b)
    b = #str + 1
    return s
  end
end

function split.first(str, sep, plain)
  local e, e2 = string.find(str, sep, nil, plain)
  if e then
    return string.sub(str, 1, e - 1), string.sub(str, e2 + 1)
  end
  return str
end
end
------------------------------------------------------------------

local sec_websocket_accept = function(sec_websocket_key)
  local a = sec_websocket_key .. guid
  local sha1 = sha1(a)
  assert((#sha1 % 2) == 0)
  return base64.encode(sha1)
end

local http_headers = function(request)
  local header, request = split.first(request, '\r\n')

  local headers = {}
  local method, uri = string.match(header, '^(%S+)%s*(.-)%s*HTTP/1%.1')
  if method then -- accept
    headers['@method'] = method
    headers['@uri'] = uri
  elseif not string.match(header, '^%s*HTTP/1%.1') then
    return headers
  end

  for line in split.iter(request, '\r\n') do
    if line == '' then break end

    local name, val = split.first(line, '%s*:%s*')
    if name and val then
      val  = trim(val)
      name = string.lower(name)
      if not string.match(name, 'sec%-websocket') then
        val = string.lower(val)
      end

      if not headers[name] then
        headers[name] = val
      else
        headers[name] = headers[name]..', '..val
      end
    else
      --! @fixme return error so server can just shutdown connections
      assert(false, line..'('..#line..')')
    end
  end

  return headers, request:match('\r\n\r\n(.*)')
end

local upgrade_request = function(req)
  local lines = {
    string.format('GET %s HTTP/1.1', req.uri or '/'),
    'Host: ' .. req.host,
    'Upgrade: websocket',
    'Connection: Upgrade',
    'Sec-WebSocket-Key: ' .. req.key,
    'Sec-WebSocket-Version: 13',
  }

  if req.protocols and #req.protocols > 0 then
    local h = ''
    for i = 1, #req.protocols do
      h = h .. (i > 1 and ', ' or '') .. enqute(req.protocols[i])
    end
    lines[#lines + 1] =  'Sec-WebSocket-Protocol: ' .. h
  end

  if req.origin then
    lines[#lines + 1] = 'Origin: ' .. req.origin
  end

  if req.port and req.port ~= 80 then
    lines[2] = string.format('Host: %s:%d', req.host, req.port)
  end

  if req.extensions and #req.extensions > 0 then
    lines[#lines + 1] = 'Sec-WebSocket-Extensions: ' .. req.extensions
  end

  lines[#lines + 1] = '\r\n'
  return table.concat(lines,'\r\n')
end

local accept_upgrade = function(request, protocols)
  local headers = http_headers(request)

  if not headers['upgrade'] or
     not headers['connection'] or
     not headers['sec-websocket-key'] or
     not headers['sec-websocket-version'] or
     unquote(headers['upgrade']) ~= 'websocket'
  then
    return nil,'HTTP/1.1 400 Bad Request\r\n\r\n'
  end

  local accept
  for connection in split.iter(headers['connection'], "%s*,%s*") do
    if unquote(connection) == 'upgrade' then
      accept = true
      break
    end
  end

  if not accept then return nil,'HTTP/1.1 400 Bad Request\r\n\r\n' end

  if unquote(headers['sec-websocket-version']) ~= '13' then
    return nil, 'HTTP/1.1 400 Bad Request\r\nSec-WebSocket-Version: 13\r\n\r\n'
  end

  local prot
  if headers['sec-websocket-protocol'] then
    for protocol in split.iter(headers['sec-websocket-protocol'], "%s*,%s*") do
      protocol = unquote(protocol)
      for _,supported in ipairs(protocols) do
        if supported == protocol then
          prot = protocol
          break
        end
      end
      if prot then break end
    end
  end

  local accept_key = sec_websocket_accept(headers['sec-websocket-key'])

  local response = {
    'HTTP/1.1 101 Switching Protocols',
    'Upgrade: websocket',
    'Connection: '           .. headers['connection'],
    'Sec-WebSocket-Accept: ' .. accept_key,
  }

  if prot then tappend(response, 'Sec-WebSocket-Protocol: ' .. enqute(prot)) end

  return response, prot, headers['sec-websocket-extensions']
end

return {
  sec_websocket_accept = sec_websocket_accept,
  http_headers = http_headers,
  accept_upgrade = accept_upgrade,
  upgrade_request = upgrade_request,
}