local uv     = require "lluv"
local ssl    = require "lluv.ssl"
local config = require "./config"

local ctx = assert(ssl.context(config))

local EOF = uv.error(uv.ERROR_UV, uv.EOF)

local function ping()
  ctx:client():connect("127.0.0.1", 8881, function(cli, err)
    if err then
      print("Connection fail:", err)
      return cli:close()
    end

    cli:start_read(function(cli, err, data)
      if err then
        print("Read ERROR:", err)
        return cli:close()
      end

      print("`".. data.. "`")
      cli:close(ping)
    end)

  end)
end

ping()

uv.run()