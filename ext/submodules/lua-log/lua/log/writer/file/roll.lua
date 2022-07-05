local file = require "log.writer.file"

local M = {}

function M.new(log_dir, log_name, roll_count, max_size)
  return file.new{
    log_dir        = log_dir, 
    log_name       = log_name,
    max_size       = max_size or 10 * 1024 * 1024,
    roll_count     = assert(roll_count),
    close_file     = false,
    flush_interval = 1,
    reuse          = true,
  }
end

return M

