local server = require "log.writer.async.server.udp"

local function create_writer(host, port, maker)
  if maker then
    server.run( host, port, maker, "log.logformat.default" )
  end

  local writer = require "log.writer.format".new(
    require "log.logformat.proxy".new(),
    require "log.writer.net.udp".new(host, port)
  )

  return writer
end

local M = {}

M.new = create_writer

return M