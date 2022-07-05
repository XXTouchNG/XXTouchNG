local Z    = require "log.writer.net.zmq._private.compat"
local IMPL = require "log.writer.net.zmq._private.impl"

local zmq, ETERM, zstrerror, zassert, zrecv = Z.zmq, Z.ETERM, Z.strerror, Z.assert, Z.recv
local zerrcode = Z.errcode

local log_packer = require "log.logformat.proxy.pack"

local _M = {}

function _M.run(writer, final, logformat, ctx, stype, address, addr_sync)
  -- print(writer, logformat, ctx, stype, address, addr_sync)
  local stypes = {
    SUB  = zmq.SUB;
    PULL = zmq.PULL;
  }
  stype = assert(stypes[stype], 'Unsupported socket type')

  ctx = IMPL.context(ctx)

  local skt = zassert(ctx:socket(stype))
  zassert(skt:bind(address))

  if addr_sync then
    local skt_sync = zassert(ctx:socket(zmq.PAIR))
    zassert(skt_sync:connect(addr_sync))
    skt_sync:send("")
    skt_sync:close()
  end

  local unpack = log_packer.unpack

  while(true)do
    local msg, err = zrecv(skt)
    if msg then 
      local msg, lvl, now = unpack(msg)
      if msg and lvl and now then writer(logformat, msg, lvl, now) end
    else
      if zerrcode(err) == ETERM then break end
      io.stderr:write('log.writer.net.zmq.server: ', tostring(err), zstrerror(err), '\n')
    end
  end

  if final then final() end

  skt:close()
end

return _M