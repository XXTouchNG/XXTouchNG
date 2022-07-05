-- This is a compatibility layer for the legacy XXTouch library.

local _M = {}
local alert = require("alert")

_M.shake = alert.shake

_M.rotate_home_on_left = function ()
    alert.set_orientation(alert.ORIENTATION_HOME_ON_LEFT)
end

_M.rotate_home_on_right = function ()
    alert.set_orientation(alert.ORIENTATION_HOME_ON_RIGHT)
end

_M.rotate_home_on_up = function ()
    alert.set_orientation(alert.ORIENTATION_HOME_ON_UP)
end

_M.rotate_home_on_bottom = function ()
    alert.set_orientation(alert.ORIENTATION_HOME_ON_BOTTOM)
end

return _M
