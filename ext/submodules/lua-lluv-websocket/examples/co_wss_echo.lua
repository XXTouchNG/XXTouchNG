local uv     = require "lluv"
local ut     = require "lluv.utils"
local socket = require "lluv.luasocket"
local WS     = require "websocket"

local extensions do
  local ok, deflate = pcall(require, "websocket.extensions.permessage-deflate")
  if ok then extensions = {deflate} end
end

local ssl = {
  protocol = "tlsv1_2",
  cafile   = "curl-ca-bundle.crt",
  verify   = {"peer", "fail_if_no_peer_cert"},
  options  = {"all", "no_sslv2"},
}

ut.corun(function()
  local cli = WS.client.lluv.sync{ssl = ssl, utf8 = true, extensions = extensions}

  print("Connect:", cli:connect("wss://echo.websocket.org", "echo"))
  for i = 1, 10 do
    cli:send("hello", (math.mod(i,2) == 0) and WS.BINARY or WS.TEXT)
    print("Message:", cli:receive())
    socket.sleep(1)
  end
  print("Close:", cli:close())
end)

uv.run()

