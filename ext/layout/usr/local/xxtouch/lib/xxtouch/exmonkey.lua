-- This is a compatibility layer for the legacy XXTouch library.
do
    local device = require "device"

    monkey = require "monkey"

    monkey.remote_inspector_on = device.remote_inspector_on

    monkey.remote_inspector_off = device.remote_inspector_off

    monkey.is_remote_inspector_on = device.is_remote_inspector_on

    monkey.remove_all_userscripts = clear_userscripts
end
