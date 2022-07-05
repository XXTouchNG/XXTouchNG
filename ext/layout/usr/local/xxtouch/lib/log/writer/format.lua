local M = {}

function M.new(newfmt, writer)
  return function(oldfmt, msg, lvl, now)
    writer(newfmt, msg, lvl, now)
  end
end

return M
