
-- Simple (and incomplete) Unicode I/O layer.

local iconv = require("iconv")

local m = { }
local mti = { }
local mt = { __index = mti }

function m.open(fname, mode, tocharset, fromcharset)
  assert(mode == "r" or mode == "rb", "Only read modes are supported yet")
  local cd = assert(iconv.new(tocharset, fromcharset), "Bad charset")
  local fp = io.open(fname, mode)
  if not fp then
    return nil
  end
  local o =  { fp = fp, cd = cd }
  setmetatable(o, mt)
  return o;
end

function mti.read(fp, mod)
  assert(fp and fp.fp and fp.cd, "Bad file descriptor")
  local ret = fp.fp:read(mod)
  if ret then
    return fp.cd:iconv(ret)  -- returns: string, error code
  else
    return nil
  end
end

function mti.close(fp)
  assert(fp and fp.fp, "Bad file descriptor")
  fp.fp:close()
end

return m
