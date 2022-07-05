local packer = require "log.logformat.proxy.pack"

local M = {}

function M.new()
  return function (now, lvl, msg)
    return packer.pack(now, lvl, msg)
  end
end

return M