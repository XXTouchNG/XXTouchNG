local uv     = require "lluv"
local ut     = require "lluv.utils"
local socket = require "lluv.luasocket"
local WS     = require "websocket"

ut.corun(function()
  local cli = WS.client.lluv.sync{}
  print("Connect:", cli:connect("ws://echo.websocket.org", "echo"))
  for i = 1, 10 do
    cli:send("hello", (math.mod(i,2) == 0) and WS.BINARY or WS.TEXT)
    print("Message:", cli:receive())
    socket.sleep(1)
  end
  print("Close:", cli:close())
end)

uv.run()

