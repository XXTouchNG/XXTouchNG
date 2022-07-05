do
    require "extable"
    http = require "http"

    -- GET
    http.get("https://postman-echo.com/get?foo1=bar1&foo2=bar2", 10, {["user-agent"] = "Launcher"})

    -- POST (form-data)
    http.post("https://postman-echo.com/post", 10, {["user-agent"] = "Launcher", ["content-type"] = "application/x-www-form-urlencoded"}, "foo=bar&bar=foo")

    -- POST (json)
    http.post("https://postman-echo.com/post", 10, {["user-agent"] = "Launcher", ["content-type"] = "application/json"}, "{\"foo\":\"bar\",\"bar\":\"foo\"}")

    -- POST (binary)
    http.post("https://postman-echo.com/post", 10, {["user-agent"] = "Launcher", ["content-type"] = "application/octet-stream"}, "foo=bar&bar=foo")

    -- POST (multipart)
    http.post("https://postman-echo.com/post", 10, {["user-agent"] = "Launcher", ["content-type"] = "multipart/form-data; boundary=--boundary"}, "--boundary\r\nContent-Disposition: form-data; name=\"foo\"\r\n\r\nbar\r\n--boundary\r\nContent-Disposition: form-data; name=\"bar\"\r\n\r\nfoo\r\n--boundary--")

    -- HEAD
    http.head("https://postman-echo.com/head?foo1=bar1&foo2=bar2", 10, {["user-agent"] = "Launcher"})

    -- PUT
    http.put("https://postman-echo.com/put", 10, {["user-agent"] = "Launcher", ["content-type"] = "application/x-www-form-urlencoded"}, "foo=bar&bar=foo")

    -- DELETE
    http.delete("https://postman-echo.com/delete", 10, {["user-agent"] = "Launcher"})

    -- POST (download)
    http.download("https://82flex.com/jstcpweb/payload/JSTColorPicker.dmg", "JSTColorPicker1.dmg", 10, true, function (info)
        print(stringify(info))
    end)
end