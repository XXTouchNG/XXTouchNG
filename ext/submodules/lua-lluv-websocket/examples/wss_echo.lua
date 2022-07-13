local uv = require"lluv"
local WS = require"websocket"

local ssl = {
  protocol = "tlsv1_2",
  cafile   = "curl-ca-bundle.crt",
  verify   = {"peer", "fail_if_no_peer_cert"},
  options  = {"all", "no_sslv2"},
}

local cli = WS.client.lluv{ssl = ssl} do

local timer = uv.timer():start(0, 5000, function()
  cli:send("ECHO")
end):stop()

cli:on_open(function(ws)
  print("Connected")
  timer:again()
end)

cli:on_error(function(ws, err)
  print("Error:", err)
end)

cli:on_message(function(ws, msg, code)
  print("Message:", msg)
end)

cli:connect("wss://echo.websocket.org", "echo")

end

uv.run()


