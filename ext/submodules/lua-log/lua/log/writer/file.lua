local LOG         = require "log"
local file_logger = require "log.writer.file.private.impl"

local M = {}

function M.new(opt)
  local logger = file_logger:new(opt)
  LOG.add_cleanup(function() logger:close() end)

  return function(fmt, msg, lvl, now)
    logger:write((fmt(msg, lvl, now)))
  end
end

return M