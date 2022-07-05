local server = require "log.writer.async._private.server"

local M = {}

M.run = function(host, port, maker, logformat)
  logformat = logformat or "log.logformat.default"
  server.run("log.writer.net.server.udp", maker, logformat, host, port)
end

return M