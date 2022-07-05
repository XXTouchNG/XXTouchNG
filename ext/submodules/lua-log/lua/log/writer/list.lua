local M = {}

function M.new(...)
  local writers = {...}
  return function(...)
    for i = 1, #writers do
      writers[i](...)
    end
  end
end

return M

