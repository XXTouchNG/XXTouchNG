local Log = require "log"

local M = {}

function M.new(max_lvl, writer)
  max_lvl = assert(Log.lvl2number(max_lvl))
  return function(fmt, msg, lvl, now)
    if lvl <= max_lvl then writer(fmt, msg, lvl, now) end
  end
end

return M