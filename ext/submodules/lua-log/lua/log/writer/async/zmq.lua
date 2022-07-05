local Z      = require "log.writer.net.zmq._private.compat"
local server = require "log.writer.async.server.zmq"

local function create_writer(ctx, addr, maker)
  if ctx and not Z.is_ctx(ctx) then
    ctx, addr, maker = nil, ctx, addr
  end

  if maker then
    server.run( ctx, addr, maker, "log.logformat.default" )
  end

  return require "log.writer.format".new(
    require "log.logformat.proxy".new(),
    require "log.writer.net.zmq.push".new(ctx, addr)
  )
end

local M = {}

M.new = create_writer

return M