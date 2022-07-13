local uv = require"lluv"
local WS = require"websocket"

local cli = WS.client.lluv() do

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

cli:connect("ws://echo.websocket.org", "echo")

end

uv.run()


