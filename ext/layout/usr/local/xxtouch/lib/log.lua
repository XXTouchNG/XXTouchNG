---
-- @module log
--

local _COPYRIGHT = "Copyright (C) 2013-2016 Alexey Melnichuk";
local _VERSION   = "0.1.7-dev"

local table  = require "table"
local string = require "string"
local date   = require "date"

local destroy_list = {}
local loggers_list = setmetatable({},{__mode = 'k'})
local emptyfn = function() end

local LOG_LVL = {
  EMERG     = 1;
  ALERT     = 2;
  FATAL     = 3;
  ERROR     = 4;
  WARNING   = 5;
  NOTICE    = 6;
  INFO      = 7;
  DEBUG     = 8;
  TRACE     = 9;
}

local writer_names = {}
local LOG_LVL_NAMES = {}
for k,v in pairs(LOG_LVL) do
  LOG_LVL_NAMES[v] = k 
  writer_names[v]  = k:lower()
end

local LOG_LVL_COUNT = #LOG_LVL_NAMES

local function lvl2number(lvl)
  if type(lvl) == 'number' then return lvl end
  if type(lvl) == 'string' then
    lvl = lvl:upper()
    local n
    if lvl == 'NONE' then n = 0 else n = LOG_LVL[ lvl ] end
    if not n then return nil, "unknown log level: '" .. lvl .. "'" end
    return n
  end

  return nil, 'unsupported log leve type: ' .. type(lvl)
end

local Log = {}
Log._COPYRIGHT = _COPYRIGHT
Log._NAME      = "log"
Log._VERSION   = _VERSION
Log._LICENSE   = "MIT"

Log.LVL = LOG_LVL
Log.LVL_NAMES = LOG_LVL_NAMES

Log.lvl2number = lvl2number

function Log.new(max_lvl, writer, formatter, logformat)
  if max_lvl and type(max_lvl) ~= 'number' and type(max_lvl) ~= 'string' then
    max_lvl, writer, formatter, logformat = nil, max_lvl, writer, formatter
  end

  max_lvl = assert(lvl2number ( max_lvl or LOG_LVL.INFO ) )

  if not writer then
    writer = require"log.writer.stdout".new()
  end

  if not formatter then
    formatter = require"log.formatter.default".new()
  end

  if not logformat then
    logformat = require"log.logformat.default".new()
  end

  local write = function (lvl, ... )
    local now = date()
    writer( logformat, formatter(...), lvl, now )
  end;

  local dump  = function(lvl, fn, ...)
    local now = date()
    writer( logformat, (fn(...) or ''), lvl, now )
  end

  local logger = {}

  function logger.writer() return writer end

  function logger.formatter() return formatter end

  function logger.format() return logformat end

  function logger.lvl() return max_lvl end

  function logger.set_writer(value)
    assert(value)
    writer, value = value, writer
    return value
  end

  function logger.set_formatter(value)
    assert(value)
    formatter, value = value, formatter
    return value
  end

  function logger.set_format(value)
    assert(value)
    logformat, value = value, logformat
    return value
  end

  function logger.log(lvl, ...)
    local err lvl, err = lvl2number(lvl)
    if not lvl then return nil, err end
    return write(lvl, ...)
  end

  function logger.dump(lvl, ...)
    local err lvl, err = lvl2number(lvl)
    if not lvl then return nil, err end
    return dump(lvl, ...)
  end

  function logger.set_lvl(lvl)
    local err lvl, err = lvl2number(lvl)
    if not lvl then return nil, err end 
    max_lvl = lvl
    for i = 1, max_lvl do logger[ writer_names[i]           ] = function(...) write(i, ...) end end
    for i = 1, max_lvl do logger[ writer_names[i] .. '_dump'] = function(...) dump(i, ...)  end end
    for i = max_lvl+1, LOG_LVL_COUNT  do logger[ writer_names[i]           ] = emptyfn end
    for i = max_lvl+1, LOG_LVL_COUNT  do logger[ writer_names[i] .. '_dump'] = emptyfn end
    return true
  end

  assert(logger.set_lvl(max_lvl))

  loggers_list[logger] = true;

  return logger
end

function Log.add_cleanup(fn)
  assert(type(fn)=='function')
  for k,v in ipairs(destroy_list) do
    if v == fn then return end
  end
  table.insert(destroy_list, 1, fn)
  return fn
end

function Log.remove_cleanup(fn)
  for k,v in ipairs(destroy_list) do
    if v == fn then 
      table.remove(destroy_list, k)
      break
    end
  end
end

function Log.close()
  for k,fn in ipairs(destroy_list) do pcall(fn) end
  for logger in pairs(loggers_list) do
    logger.fotal   = emptyfn;
    logger.error   = emptyfn;
    logger.warning = emptyfn;
    logger.info    = emptyfn;
    logger.notice  = emptyfn;
    logger.debug   = emptyfn;
    logger.closed  = true;
    loggers_list[logger] =  nil
  end
  destroy_list = {}
end

return Log
