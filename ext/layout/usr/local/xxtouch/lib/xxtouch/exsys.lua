-- This is a compatibility layer for the legacy XXTouch library.
do
    if not _G.LOG then
        require "exlog"
    end
    
    sys = require "sys"

    sys.input_text = function(text, press_enter)
        local pb = require "pasteboard"
        local key = require "key"
        pb.write(text)
        key.down("COMMAND")
        key.msleep(20)
        key.press("v")
        key.msleep(20)
        key.up("COMMAND")
        if press_enter == true then
            key.msleep(20)
            key.press("ENTER")
        end
    end

    sys.log = function(...)
        LOG.info(...)
    end
end
