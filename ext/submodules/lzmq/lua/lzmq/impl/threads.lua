--
--  Author: Alexey Melnichuk <mimir@newmail.ru>
--
--  Copyright (C) 2013-2014 Alexey Melnichuk <mimir@newmail.ru>
--
--  Licensed according to the included 'LICENCE' document
--
--  This file is part of lua-lzqm library.
--

--
-- zmq.thread wraps the low-level threads object & a zmq context.
--

local T = string.dump

local run_starter = {
  prelude = T(function(ZMQ_NAME, ctx, ...)
    local zmq      = require(ZMQ_NAME)
    local zthreads = require(ZMQ_NAME .. ".threads")

    if ctx then
      ctx = zmq.init_ctx(ctx)
      zthreads.set_context(ctx)
    end

    return ...
  end)
}

local fork_starter = {
  prelude = T(function(ZMQ_NAME, ctx, endpoint, ...)
    local zmq      = require(ZMQ_NAME)
    local zthreads = require(ZMQ_NAME .. ".threads")

    assert(ctx)
    assert(endpoint)

    ctx = zmq.init_ctx(ctx)
    zthreads.set_context(ctx)

    local pipe = zmq.assert(ctx:socket{zmq.PAIR, connect = endpoint})
    return pipe, ...
  end)
}

local function rand_bytes(n)
  local t = {}
  for i = 1, n do t[i] = string.char( math.random(string.byte('a'), string.byte('z')) ) end
  return table.concat(t)
end

local actor_mt = {} do

actor_mt.__index = function(self, k)
  local v = actor_mt[k]
  if v ~= nil then
    return v
  end

  v = self._thread[k]
  if v ~= nil then
    local f = function(self, ...) return self._thread[k](self._thread, ...) end
    self[k] = f
    return f
  end

  v = self._pipe[k]
  if v ~= nil then
    local f = function(self, ...) return self._pipe[k](self._pipe, ...) end
    self[k] = f
    return f
  end
end

function actor_mt:start(...)
  local ok, err = self._thread:start(...)
  if not ok then return nil, err end
  return self, err
end

function actor_mt:socket()
  return self._pipe
end

function actor_mt:endpoint()
   return self._endpoint
end

function actor_mt:close()
  self._pipe:close()
  self._thread:join()
end

end

local function actor_new(thread, pipe, endpoint)
  local o = setmetatable({
    _thread = thread;
    _pipe   = pipe;
    _endpoint = endpoint;
  }, actor_mt)

  return o
end

local string  = require"string"
local Threads = require"lzmq.llthreads.ex"

return function(ZMQ_NAME)

local zmq = require(ZMQ_NAME)

-- for inproc or ipc
local function create_local_pipe_address(namespace)
  return "lzmq.pipe." .. namespace .. "." .. rand_bytes(10)
end
local function create_tcp_pipe_address(_)
  return "127.0.0.1:*"
end

local supported_transports = {
  ipc    = create_local_pipe_address,
  inproc = create_local_pipe_address,
  tcp    = create_tcp_pipe_address
}

local function create_pipe_address(transport, namespace)
  local fun = supported_transports[transport]
  assert(fun, "unsupported transport " .. transport)
  return fun(namespace)
end

local function create_pipe_endpoint(transport, address)
  return transport .. "://" .. address
end

local function strip_trailing_null_char(str)
  -- remove null terminated char if exists
  if str:byte(-1) == 0 then
     return str:sub(1,-2)
  else
     return str
  end
end

local function extract_endpoint(pipe, transport, pipe_endpoint)
  if transport == "inproc" then
     return pipe_endpoint
  elseif transport == "ipc" or transport == "tcp" then
     return strip_trailing_null_char(pipe:last_endpoint())
  else
     error("unsupported transport " .. transport)
  end
end

local function split_transport(ep)
  local transport, address = string.match(ep, "^(%w+)://(.+)$")
  if not transport then transport = ep end
  return transport, address
end

local function make_pipe(ctx, opt)
  opt = type(opt) == "table" and opt or {}
  local pipe = ctx:socket(zmq.PAIR)

  local transport, address
  if opt.pipe then
    assert(type(opt.pipe) == 'string', 'Currently supports only string type')
    transport, address = split_transport(opt.pipe)
  else
    transport = "inproc"
  end
  address = address or create_pipe_address(transport, pipe:fd())

  local pipe_endpoint = create_pipe_endpoint(transport, address)
  local ok, err = pipe:bind(pipe_endpoint)
  if not ok then
    pipe:close()
    return nil, err
  end
  return pipe, extract_endpoint(pipe, transport, pipe_endpoint)
end

local function thread_opts(code, opt)
  if type(code) == "table" then
    local source   = assert(code[1] or code.source)
    local lua_init = code.lua_init or opt.lua_init
    local prelude  = opt.prelude
    if code.prelude then
      --! @todo support user prelude as `@filename`
      local user_prelude = code.prelude
      if type(user_prelude) == 'function' then
        user_prelude = T(user_prelude)
      end
      if type(prelude) == 'function' then
        prelude = T(prelude)
      end

      prelude = string.format([[
        local loadstring = loadstring or load
        local prelude1 = loadstring(%q)
        local prelude2 = loadstring(%q)
        return prelude1(prelude2(...))
      ]], user_prelude, prelude)
    end
    return {source = source, prelude = prelude, lua_init = lua_init}
  end

  return {
     source = assert(code),
     prelude = opt.prelude,
     lua_init = opt.lua_init
  }
end

local function actor_assert(thread, pipe, endpoint)
  if not thread then return nil, pipe end
  return actor_new(thread, pipe, endpoint)
end

local zthreads = {}

function zthreads.run(ctx, opts, ...)
  if ctx then ctx = ctx:lightuserdata() end
  return Threads.new(thread_opts(opts, run_starter), ZMQ_NAME, ctx, ...)
end

function zthreads.fork(ctx, opt, ...)
  local pipe, endpoint = make_pipe(ctx, opt)
  if not pipe then return nil, endpoint end

  ctx = ctx:lightuserdata()
  local thread, err = Threads.new(thread_opts(opt, fork_starter), ZMQ_NAME, ctx, endpoint, ...)
  if not thread then
    pipe:close()
    return nil, err
  end
  return thread, pipe, endpoint
end

function zthreads.actor(...)
  return actor_assert(zthreads.fork(...))
end

function zthreads.xrun(...)
  return zthreads.run(zthreads.context(), ...)
end

function zthreads.xfork(...)
  return zthreads.fork(zthreads.context(), ...)
end

function zthreads.xactor(...)
  return zthreads.actor(zthreads.context(), ...)
end

local global_context = nil
function zthreads.set_context(ctx)
  assert(ctx)

  if global_context == ctx then return end

  assert(global_context == nil, 'global_context already setted')

  global_context = ctx
end

function zthreads.context()
  if not global_context then global_context = zmq.assert(zmq.context()) end
  return global_context
end

-- compatibility functions

zthreads.get_parent_ctx = zthreads.context

zthreads.set_parent_ctx = zthreads.set_context

return zthreads

end
