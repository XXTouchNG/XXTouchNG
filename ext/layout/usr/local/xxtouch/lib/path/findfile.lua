------------------------------------------------------------------
--
--  Author: Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Copyright (C) 2013-2016 Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Licensed according to the included 'LICENCE' document
--
--  This file is part of lua-path library.
--
------------------------------------------------------------------

---
-- Implementation of afx.findfile

local string    = require "string"
local table     = require "table"
local coroutine = require "coroutine"
local PATH      = require "path.module"

local function load(findfile_t)

  local function clone(t) local o = {} for k,v in pairs(t) do o[k] = v end return o end

  local function findfile_ssf(str_file, str_params, func_callback, tbl_option)
    tbl_option = tbl_option and clone(tbl_option) or {}
    tbl_option.file = assert(str_file)
    tbl_option.param = assert(str_params)
    tbl_option.callback = assert(func_callback)
    return findfile_t(tbl_option)
  end

  local function findfile_ss(str_file, str_params, tbl_option)
    tbl_option = tbl_option and clone(tbl_option) or {}
    tbl_option.file = assert(str_file)
    tbl_option.param = assert(str_params)
    return findfile_t(tbl_option)
  end

  local function findfile_sf(str_file, func_callback, tbl_option)
    tbl_option = tbl_option and clone(tbl_option) or {}
    tbl_option.file = assert(str_file)
    tbl_option.callback = assert(func_callback)
    return findfile_t(tbl_option)
  end

  local function findfile_s(str_file, tbl_option)
    tbl_option = tbl_option and clone(tbl_option) or {}
    tbl_option.file = assert(str_file)
    return findfile_t(tbl_option)
  end

  local function findfile_f(func_callback, tbl_option)
    tbl_option = clone(assert(tbl_option)) -- need file
    tbl_option.callback = assert(func_callback)
    return findfile_t(tbl_option)
  end

  local function findfile(p1,p2,p3,p4)
    if type(p1) == 'string' then 
      if type(p2) == 'string' then
        if type(p3) == 'function' then
          return findfile_ssf(p1,p2,p3,p4)
        end
        return findfile_ss(p1,p2,p3)
      end
      if type(p2) == 'function' then
        return findfile_sf(p1,p2,p3)
      end
      return findfile_s(p1,p2)
    end
    if type(p1) == 'function' then
      return findfile_f(p1,p2)
    end
    return findfile_t(p1)
  end

  return findfile
end

return {load = load}