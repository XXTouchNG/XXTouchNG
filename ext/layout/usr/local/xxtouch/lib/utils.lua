-- This is a compatibility layer for the legacy XXTouch library.

local _M = {}
local image = require("image")

_M.qr_encode = image.qr_encode

_M.launch_args = function ()
    return {
        path = os.getenv("XXT_ENTRYPOINT"),
        type = os.getenv("XXT_ENTRYTYPE" ),
    }
end

_M.is_launch_via_app = function ()
    return os.getenv("XXT_ENTRYTYPE") == "application"
end

return _M
