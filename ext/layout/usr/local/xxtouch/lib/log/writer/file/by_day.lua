local file = require "log.writer.file"

local M = {}

function M.new(log_dir, log_name, max_rows)
  return file.new{
    log_dir        = log_dir, 
    log_name       = log_name,
    max_rows       = max_rows,
    by_day         = true,
    close_file     = false,
    flush_interval = 1,
  }
end

return M

