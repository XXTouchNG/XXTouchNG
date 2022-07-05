local M = {}

function M.new()
  return function(msg)
    return msg
  end
end

return M