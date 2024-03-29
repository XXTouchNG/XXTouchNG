do
    -- check integrity of the entire xxtouch toolkit
    (function ()

        local protected_binaries = {
            "/usr/lib/liblua.dylib",
            "/usr/local/lib/libalerthelper.dylib",
            "/usr/local/lib/libauthpolicy.dylib",
            "/usr/local/lib/libdebugwindow.dylib",
            "/usr/local/lib/libdeviceconfigurator.dylib",
            "/usr/local/lib/libentitleme.dylib",
            "/usr/local/lib/libhidrecorder.dylib",
            "/usr/local/lib/libprocqueue.dylib",
            "/usr/local/lib/libscreencapture.dylib",
            "/usr/local/lib/libsimulatetouch.dylib",
            "/usr/local/lib/libsupervisor.dylib",
            "/usr/local/lib/libtampermonkey.dylib",
            "/usr/local/lib/libtfcontainermanager.dylib",
            "/usr/local/lib/libtfcookiesmanager.dylib",
            "/usr/local/xxtouch/bin/add1s",
            "/usr/local/xxtouch/bin/hidrecorder",
            "/usr/local/xxtouch/bin/lua",
            "/usr/local/xxtouch/bin/luac",
            "/usr/local/xxtouch/bin/ohmyjetsam",
            "/usr/local/xxtouch/bin/procqueued",
            "/usr/local/xxtouch/bin/simulatetouchd",
            "/usr/local/xxtouch/bin/supervisord",
            "/usr/local/xxtouch/bin/tfcontainermanagerd",
            "/usr/local/xxtouch/bin/webserv",
            "/Applications/XXTExplorer.app/XXTExplorer",
        }

        local auth = require("xxtouch.auth")

        if auth._VERSION:sub(-string.len('+debug')) == '+debug' then
            return
        end

        for _, path in ipairs(protected_binaries) do
            local signature = auth.code_signature(path)
            assert(signature ~= nil, "Failed integrity check: " .. path)
            assert(signature.certificates ~= nil, "Failed integrity check: " .. path)
            assert(#signature.certificates == 3, "Failed integrity check: " .. path)
            assert(signature.certificates[1].CommonName == "", "Failed integrity check: " .. path)
            assert(
                signature.certificates[2].CommonName == "Developer ID Certification Authority" or
                signature.certificates[2].CommonName == "Apple Worldwide Developer Relations Certification Authority",
                "Failed integrity check: " .. path)
            assert(signature.certificates[3].CommonName == "Apple Root CA", "Failed integrity check: " .. path)
        end

    end)()

    require("xxtouch.exprint")
    require("xxtouch.extable")
    require("xxtouch.exstring")

    alert         = require("alert")
    accelerometer = require("accelerometer")
    app           = require("app")
    appstore      = require("appstore")
    cookies       = require("cookies")
    file          = require("file")
    ftp           = require("ftp")    -- not yieldable
    http          = require("http")   -- not yieldable
    memory        = require("memory")
    monkey        = require("monkey")
    pasteboard    = require("pasteboard")
    touch         = require("touch")
    key           = require("key")
    samba         = require("samba")  -- not yieldable
    screen        = require("screen")
    image         = require("image")
    device        = require("device")
    sys           = require("sys")
    proc          = require("proc")
    thread        = require("thread")
    utils         = require("utils")

    require("xxtouch.exapp")
    require("xxtouch.exlog")
    require("xxtouch.exmonkey")
    require("xxtouch.exproc")
    require("xxtouch.exscreen")
    require("xxtouch.exsys")
    require("xxtouch.scheduler")

    if os.getenv("XXT_DEBUG_IP") then
        -- start debugger
        require("LuaPanda").start(os.getenv("XXT_DEBUG_IP") or "127.0.0.1", os.getenv("XXT_DEBUG_PORT") or 8818);
    end
end