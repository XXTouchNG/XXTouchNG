local table = require "table"

local M = {}

function M.new(sep)
  sep = sep or ' '

  return function (...)
    local argc,argv = select('#', ...), {...}
    for i = 1, argc do argv[i] = tostring(argv[i]) end
    return (table.concat(argv, sep))
  end
end

return M

