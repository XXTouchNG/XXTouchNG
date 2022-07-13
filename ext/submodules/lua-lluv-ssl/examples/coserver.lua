local uv     = require "lluv"
local ut     = require "lluv.utils"
local ssl    = require "lluv.ssl"
local socket = require "lluv.ssl.luasocket"
local config = require "./config"

local ctx = assert(ssl.context(config))

ut.corun(function()
  local srv = socket.ssl(ctx, true)
  print("Bind  ", srv:bind("127.0.0.1", 8881))
  while true do
    local cli, err = srv:accept()
    if cli then
      cli:send("hello loop")
      cli:close()
    end
  end
  srv:close()
end)

uv.run()
