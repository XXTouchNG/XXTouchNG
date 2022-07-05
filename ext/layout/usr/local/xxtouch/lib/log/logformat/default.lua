local string = require "string"
local Log    = require "log"

local sformat = string.format
local function date_fmt(now)
  local Y, M, D = now:getdate()
  return sformat("%.4d-%.2d-%.2d %.2d:%.2d:%.2d", Y, M, D, now:gettime())
end

local M = {}

function M.new()
  return function (msg, lvl, now)
    return date_fmt(now) .. ' [' .. Log.LVL_NAMES[lvl] .. '] ' .. msg
  end
end

return M