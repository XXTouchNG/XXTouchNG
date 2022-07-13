local function thread(pipe)
  local uv    = require "lluv"
  local ut    = require "lluv.utils"
  uv.poll_zmq = require "lluv.poll_zmq"

  uv.poll_zmq(pipe):start(function(handle, err, pipe)
    if err then
      print("Poll error:", err)
      return handle:close()
    end

    print("Pipe recv:", pipe:recvx())
  end)

  uv.timer():start(1000, function()
    print("LibUV timer")
  end)

  uv.run()
end

local zth = require "lzmq.threads"
local ztm = require "lzmq.timer"

local actor = zth.xactor(thread):start()

for i = 1, 5 do
  actor:send("Hello #" .. i)
  ztm.sleep(1000)
end
