local _M = {}

local entitleme = require("xxtouch.entitleme")
local app = require("app")
local sys = require("sys")
local touch = require("touch")
local key = require("key")

_M.logout = entitleme.__logout
_M.account = entitleme.__account

_M.login = function(username, password)
    entitleme.__setup(username, password)

    if sys.language() ~= 'en' and sys.language() ~= 'en-US' then
        return false, "Unsupported language, only English is supported."
    end
    
    local prefs_id = 'com.apple.Preferences'

    app.quit('*')
    app.run(prefs_id)
    sys.sleep(2)

    if app.front_bid() ~= prefs_id then
        return false, "Preferences not launched."
    end

    local x, y
    for _ = 1, 10, 1 do
        x, y = screen.ocr_search('Next', 0)
        if x ~= -1 then
            break
        end
        sys.msleep(100)
    end
    if x == -1 then
        return false, "Next button not found."
    end

    touch.tap(x, y)
    sys.sleep(1)

    if app.front_bid() ~= prefs_id then
        return false, "Preferences not alive."
    end

    for _ = 1, 10, 1 do
        x, y = screen.ocr_search('Required', 0)
        if x ~= -1 then
            break
        end
        sys.msleep(100)
    end
    if x == -1 then
        return false, "Required text field not found."
    end

    touch.tap(x, y)
    sys.sleep(1)

    if app.front_bid() ~= prefs_id then
        return false, "Preferences not alive."
    end

    key.send_text(password)
    sys.sleep(1)

::wait_for_login::
    if app.front_bid() ~= prefs_id then
        return false, "Preferences not alive."
    end

    for _ = 1, 10, 1 do
        x, y = screen.ocr_search('Next', 0)
        if x ~= -1 then
            break
        end
        sys.msleep(100)
    end
    if x == -1 then
        return false, "Next button not found."
    end

    touch.tap(x, y)
    sys.sleep(1)

    if app.front_bid() ~= prefs_id then
        return false, "Preferences not alive."
    end

    local final = nil
    for _ = 1, 120, 1 do
        local remote = entitleme.__query()
        if not remote then
            return false, "Invalid xpc response."
        end
        if not remote.processing then
            final = remote
            break
        end
        sys.msleep(500)
    end

    if not final then
        return false, "Timeout."
    end

    if final.code == 101 then
        -- Two-factor authentication
        sys.sleep(1)

        if app.front_bid() ~= prefs_id then
            return false, "Preferences not alive."
        end

        for _ = 1, 10, 1 do
            x, y = screen.ocr_search('Other Options', 0)
            if x ~= -1 then
                break
            end
            sys.msleep(100)
        end
        if x == -1 then
            return false, "Other Options button not found."
        end

        touch.tap(x, y)
        sys.sleep(1)

        if app.front_bid() ~= prefs_id then
            return false, "Preferences not alive."
        end

        for _ = 1, 10, 1 do
            x, y = screen.ocr_search('Don\'t Upgrade', 0)
            if x ~= -1 then
                break
            end
            sys.msleep(100)
        end
        if x == -1 then
            return false, "Don\'t Upgrade button not found."
        end

        touch.tap(x, y)
        sys.sleep(1)

        goto wait_for_login
    end

    if not final.succeed then
        return false, "Login failed (" .. final.domain .. ", " .. final.code .. "): " .. final.desc .. " Reason: " .. final.reason
    end

    return true, nil
end

return _M