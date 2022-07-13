#!/usr/bin/env lua

function usage()
    print("usage: appstore.lua [login|logout|account]")
    os.exit(1)
end

if #arg < 1 then
    usage()
end

local appstore = require ("appstore")

if arg[1] == 'login' then
    if #arg < 3 then
        print("usage: appstore.lua login <username> <password>")
        os.exit(1)
    end

    local username = arg[2]
    local password = arg[3]

    appstore.login(username, password)
elseif arg[1] == 'logout' then
    appstore.logout()
elseif arg[1] == 'account' then
    print(stringify(appstore.account()))
else
    usage()
end
