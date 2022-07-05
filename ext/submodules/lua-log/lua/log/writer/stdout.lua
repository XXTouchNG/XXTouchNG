local io = require "io"

local M = {}

function M.new()
  return function (fmt,...) io.stdout:write(fmt(...),'\n') end
end

return M