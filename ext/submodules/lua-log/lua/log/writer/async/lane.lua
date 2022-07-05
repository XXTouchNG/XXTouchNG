local server = require "log.writer.async.server.lane"
local packer = require "log.logformat.proxy.pack"

local function create_writer(channel, maker)
  if maker then
    server.run( channel, maker, "log.logformat.default" )
  end

  local queue = server.channel()
  local pack  = packer.pack

  return function(fmt, ...)
    local msg = pack(...)
    queue:send(channel, msg)
  end
end

local M = {}

M.new = create_writer

return M