---
-- @module pop3.charset
-- @local
-- This is internal module to convert text from on charset to another

local function pass_thrue(str) return str end
local setmeta = setmetatable
local assert = assert

local function make_iconv(to,from) end

local meta = {__index = function(self, to)
  to = to:lower()
  self[to] = setmeta({},{__index = function(self,from)
    from = from:lower()
    if from == to then
      self[from] = pass_thrue
    else
      self[from] = make_iconv(to,from) or pass_thrue
    end
    return self[from];
  end})
  return self[to]
end;
__call = function(self, to, from)
  return self[to][from]
end;
}

local ok, iconv = pcall( require, "iconv" )
if ok then
  make_iconv = function (to,from)
    local c = iconv.new(to,from)
    return c and function(str)
      return c:iconv(str)
    end
  end
end

local M = {}

function M.pass_thrue_only()
  return not iconv
end

function M.supported(to, from)
  return M[to][from] ~= pass_thrue
end

function M.convert(to, from, str)
  return M[to][from](str)
end

setmeta(M, meta)

return M
