local lpeg   = require "lpeg"
local table  = require "table"
local string = require "string"

local unpack = unpack or table.unpack

local HAS_A_FORMAT = pcall(string.format, '%a' , 10)

local P, C, Cs, Ct, Cp, S, R = lpeg.P, lpeg.C, lpeg.Cs, lpeg.Ct, lpeg.Cp, lpeg.S, lpeg.R

local any   = P(1)
local empty = P(0)

local esc   = P'%%'
local flags = S'-+ #0'
local digit = R'09'

local fsym         = S('cdiouxXeEfgGqs' .. (HAS_A_FORMAT and 'aA' or ''))
local width        = digit * digit + digit
local precision    = P'.' * (digit * digit + digit)
local format       = (flags + empty) * (width + empty) * (precision + empty) * (P'.' + empty)
local valid_format = P'%' * format * fsym
local valid_format_capture = Cs(valid_format)

local any_fsym     = any - (flags + digit + P'.')
local any_format   = P'%' * (flags + digit + P'.')^0 * any_fsym

local types = {
  c = 'number';
  d = 'number';
  i = 'number';
  o = 'number';
  u = 'number';
  x = 'number';
  X = 'number';
  a = 'number';
  A = 'number';
  e = 'number';
  E = 'number';
  f = 'number';
  g = 'number';
  G = 'number';
  q = 'string';
  s = 'string';
}

local function safe_format(protect_only_args, fmt, ...)
  local n, args = 0, {...}

  local function fix_fmt(f)
    local fmt = valid_format_capture:match(f)

    if not fmt then
      if protect_only_args then return end
      return '%' .. f
    end

    local typ = string.sub(fmt, -1)

    n = n + 1

    if types[typ] ~= type( args[n] ) then
      args[n], fmt = tostring(args[n]), '%s'
    end

    return fmt
  end

  local pattern = Cs((esc + any_format / fix_fmt + any) ^ 0)
  fmt = pattern:match(fmt)

  return string.format(fmt, unpack(args, 1, n))
end

local function buld_formatter(protect_only_args, no_warning)
  return function(...)
    local ok, msg = pcall(string.format, ...)
    if not ok then
      local err = msg
      msg = safe_format(protect_only_args, ...)
      if not no_warning then
        msg = msg .. ' - ' .. 'WARNING: Error formatting log message: ' .. err
      end
    end
    return msg
  end
end

return {
  new = buld_formatter
}
