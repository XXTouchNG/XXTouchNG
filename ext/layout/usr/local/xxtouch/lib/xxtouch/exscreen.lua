-- This is a compatibility layer for the legacy XXTouch library.
do
    local screen = require "screen"
    local touch = require "touch"

    local _screen_init = screen.init
    screen.init = function (...)
        local orig = _screen_init(...)
        touch.init(...)
        return orig
    end

    local _screen_init_home_on_left = screen.init_home_on_left
    screen.init_home_on_left = function ()
        local orig = _screen_init_home_on_left()
        touch.init_home_on_left()
        return orig
    end

    local _screen_init_home_on_top = screen.init_home_on_top
    screen.init_home_on_top = function ()
        local orig = _screen_init_home_on_top()
        touch.init_home_on_top()
        return orig
    end

    local _screen_init_home_on_bottom = screen.init_home_on_bottom
    screen.init_home_on_bottom = function ()
        local orig = _screen_init_home_on_bottom()
        touch.init_home_on_bottom()
        return orig
    end

    local _screen_init_home_on_right = screen.init_home_on_right
    screen.init_home_on_right = function ()
        local orig = _screen_init_home_on_right()
        touch.init_home_on_right()
        return orig
    end
end
