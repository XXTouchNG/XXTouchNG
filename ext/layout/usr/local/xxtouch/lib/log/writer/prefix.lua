local M = {}

function M.new(prefix, writer)
  return function(fmt, msg, lvl, now)
    writer(fmt, prefix .. msg, lvl, now)
  end
end

return M
