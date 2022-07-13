local uv     = require "lluv"
local ssl    = require "lluv.ssl"
local config = require "./config"

local ctx = assert(ssl.context(config))

ctx:server():bind("127.0.0.1", 8881, function(srv, err)
  srv:listen(function(srv, err)
    if err then return print("Listen error", err) end
    local cli = srv:accept()
    cli:handshake(function(cli, err)
      if err then
        print("Handshake fail: ", err)
        return cli:close()
      end
      cli:write("loop test", cli.close)
    end)
  end)
end)

uv.run()
