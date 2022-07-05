-- This is a compatibility layer for the legacy XXTouch library.
do
    local alert = require "alert"
    local sys = require "sys"

    app = require "app"

    app.input_text = function(text)
        return alert.input_text(text)
    end

    app.pop_banner = function(section, title, message)
        assert(app.localized_name(section) ~= nil, "specified app does not exist")
        local device = require "device"
        device.pop_banner(section, title, message)
    end

    app.quit = function(bid)
        if app.front_bid() == bid or bid == "*" then
            local succeed = alert.suspend(bid)  -- ensure the suspend target
            if succeed then
                sys.msleep(2000)  -- give app some time to quit
            end
        end
        sys.suspend(bid)  -- remove the app from the main switcher
    end

    app.set_orientation = alert.set_orientation
end
