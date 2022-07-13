local _M = {}

local entitleme = require("xxtouch.entitleme")

_M.logout = entitleme.__logout
_M.account = entitleme.__account

_M.login = function(username, password)
    entitleme.__setup(username, password)

    if sys.language() ~= 'en' and sys.language() ~= 'en-US' then
        return false, "Unsupported language, only English is supported."
    end
    
    local prefs_id = 'com.apple.Preferences'

    sys.log('Quit all applications…')
    app.quit('*')
    sys.sleep(1)

    sys.log('Open Settings…')
    app.run(prefs_id)
    sys.sleep(2)

    if app.front_bid() ~= prefs_id then
        return false, "Preferences not launched."
    end

    sys.log('Search for “Next” button…')
    local x, y
    for _ = 1, 10, 1 do
        x, y = screen.ocr_search('Next')
        if x ~= -1 then
            break
        end
        sys.msleep(100)
    end
    if x == -1 then
        return false, "“Next” button not found."
    end

    sys.log('Tap on “Next” button…')
    touch.tap(x, y)
    sys.sleep(1)

    if app.front_bid() ~= prefs_id then
        return false, "Preferences not alive."
    end

    sys.log('Search for “Required” textfield…')
    for _ = 1, 10, 1 do
        x, y = screen.ocr_search('Required')
        if x ~= -1 then
            break
        end
        sys.msleep(100)
    end
    if x == -1 then
        return false, "“Required” textfield not found."
    end

    sys.log('Tap on “Required” textfield…')
    touch.tap(x, y)
    sys.sleep(1)

    if app.front_bid() ~= prefs_id then
        return false, "Preferences not alive."
    end

    sys.log('Send password text to that textfield…')
    key.send_text(password)
    sys.sleep(1)

::wait_for_login::
    if app.front_bid() ~= prefs_id then
        return false, "Preferences not alive."
    end

    sys.log('Search for “Next” button…')
    for _ = 1, 10, 1 do
        x, y = screen.ocr_search('Next')
        if x ~= -1 then
            break
        end
        sys.msleep(100)
    end
    if x == -1 then
        return false, "“Next” button not found."
    end

    sys.log('Tap on “Next” button…')
    touch.tap(x, y)
    sys.sleep(1)

    if app.front_bid() ~= prefs_id then
        return false, "Preferences not alive."
    end

    sys.log('Wait for AuthKit Daemon to login…')
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
        sys.log('Two-factor authentication required…')
        sys.sleep(1)

        if app.front_bid() ~= prefs_id then
            return false, "Preferences not alive."
        end

        sys.log('Search for “Other Options” button…')
        for _ = 1, 10, 1 do
            x, y = screen.ocr_search('Other Options')
            if x ~= -1 then
                break
            end
            sys.msleep(100)
        end
        if x == -1 then
            return false, "“Other Options” button not found."
        end

        sys.log('Tap on “Other Options” button…')
        touch.tap(x, y)
        sys.sleep(1)

        if app.front_bid() ~= prefs_id then
            return false, "Preferences not alive."
        end

        sys.log('Search for “Don’t Upgrade” button…')
        for _ = 1, 10, 1 do
            x, y = screen.ocr_match('Upgrade$')
            if x ~= -1 then
                break
            end
            sys.msleep(100)
        end
        if x == -1 then
            return false, "“Don’t Upgrade” button not found."
        end

        sys.log('Tap on “Don’t Upgrade” button…')
        touch.tap(x, y)
        sys.sleep(1)

        goto wait_for_login
    end

    if not final.succeed then
        return false, "Login failed (" .. final.domain .. ", " .. final.code .. "): " .. final.desc .. " Reason: " .. final.reason
    end

    sys.log('Login succeeded.')
    return true, nil
end

return _M