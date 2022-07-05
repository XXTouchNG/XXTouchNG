local socket = require("socket")

local function create_socket(host, port, timeout)
  local skt = assert(socket.udp())
  assert(skt:settimeout(timeout or 0.1))
  assert(skt:setpeername(host, port))
  return skt
end

local M = {}

function M.new(host, port, timeout) 
  local skt = create_socket(host, port, timeout)
  return function(fmt, ...) skt:send((fmt( ... ))) end
end

return M