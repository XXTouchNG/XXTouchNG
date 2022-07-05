local Log = require "log"
local Z   = require "log.writer.net.zmq._private.compat"

local zmq, zthreads = Z.zmq, Z.threads
local zstrerror, zassert = Z.strerror, Z.assert 
local ETERM = Z.ETERM
local zconnect, zbind = Z.connect, Z.bind

local log_ctx

local function context(ctx)
  -- we have to use same context for all writers
  if ctx and log_ctx then assert(ctx == log_ctx) end

  if log_ctx then return log_ctx end

  log_ctx = ctx or (zthreads and zthreads.get_parent_ctx()) or zassert(zmq.init(1))

  return log_ctx
end

local function socket(ctx, stype, is_srv, addr, timeout)
  local stypes = {
    PUSH = zmq.PUSH;
    PUB  = zmq.PUB;
  }
  stype = assert(stypes[stype], 'Unsupported socket type')
  timeout = timeout or 100
  ctx = context(ctx)

  local skt = ctx:socket(stype)
  if ctx.autoclose then ctx:autoclose(skt) end
  skt:set_sndtimeo(timeout)
  skt:set_linger(timeout)
  if is_srv then zassert(zbind(skt, addr)) 
  else zassert(zconnect(skt, addr)) end
  if not ctx.autoclose then
    Log.add_cleanup(function() skt:close() end)
  end
  return skt
end

local function init(stype, is_srv)
  local M = {}

  function M.new(ctx, addr, timeout) 
    if ctx and not Z.is_ctx(ctx) then
      ctx, addr, timeout = nil, ctx, addr
    end

    local skt = socket(ctx, stype, is_srv, addr, timeout)
    return function(fmt, ...) skt:send((fmt(...))) end
  end

  return M
end

return {
  init    = init;
  context = context;
}