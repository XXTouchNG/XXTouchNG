local uv     = require "lluv"
local ut     = require "lluv.utils"
local ssl    = require "lluv.ssl"
local socket = require "lluv.ssl.luasocket"
local config = require "./config"

local ctx = assert(ssl.context(config))

ut.corun(function()
  while true do
    local cli = socket.ssl(ctx)
    local ok, err = cli:connect("127.0.0.1", 8881)
    if not ok then
      print("Connect fail:", err)
      break
    end
    print("Recv:", cli:receive("*a"))
    cli:close()
  end
end)

uv.run()
