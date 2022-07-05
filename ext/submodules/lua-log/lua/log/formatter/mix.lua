---
-- compatiable with lualogging
--

local M = {}

function M.new(default)
  if not default then
    default = require "log.formatter.format".new()
  end

  return function(...)
    if type((...)) == 'function' then
      return (...)(select(2, ...))
    end

    if select('#', ...) < 2 then
      return tostring((...))
    end

    return default(...)
  end
end

return M