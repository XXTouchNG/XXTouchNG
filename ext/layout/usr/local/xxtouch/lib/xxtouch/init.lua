do
    require("xxtouch.exprint")
    require("xxtouch.extable")
    require("xxtouch.exstring")

    alert = require("alert")
    accelerometer = require("accelerometer")
    app = require("app")
    file = require("file")
    ftp = require("ftp")  -- not yieldable
    http = require("http")  -- not yieldable
    memory = require("memory")
    monkey = require("monkey")
    pasteboard = require("pasteboard")
    touch = require("touch")
    key = require("key")
    samba = require("samba")  -- not yieldable
    screen = require("screen")
    image = require("image")
    device = require("device")
    sys = require("sys")
    proc = require("proc")
    thread = require("thread")
    utils = require("utils")

    require("xxtouch.exapp")
    require("xxtouch.exlog")
    require("xxtouch.exproc")
    require("xxtouch.exscreen")
    require("xxtouch.exsys")
    require("xxtouch.scheduler")

    if os.getenv("XXT_DEBUG_IP") then
        -- start debugger
        require("LuaPanda").start(os.getenv("XXT_DEBUG_IP") or "127.0.0.1", os.getenv("XXT_DEBUG_PORT") or 8818);
    end
end