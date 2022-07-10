local json = require "cjson.safe"
local lfs = require "lfs"
local socket = require("socket")
local udp_recieve_port = 35452

cc_path = "/var/mobile/Media/1ferver/cc"

os.execute(
    table.concat(
        {
            string.format("mkdir -p %s", cc_path),
            string.format("mkdir -p %s/data", cc_path),
            string.format("mkdir -p %s/log", cc_path)
        },
        ";"
    )
)

function sys.msleep(n)
    socket.select(nil, nil, n / 1000)
end
function sys.sleep(n)
    socket.select(nil, nil, n)
end

--[[建立UDP通讯]]
local udp_service = socket.udp()
udp_service:settimeout(0)
udp_service:setsockname("0.0.0.0", udp_recieve_port)

--[[创建用于储存的列表]]
local devices = {}
local http = {
    get = (function(host, port, path)
        local socket = require "socket"
        local socket_http = require "socket.http"
        socket_http.TIMEOUT = 5
        local ltn12 = require("ltn12")
        local response_body = {}
        local rep, code =
            socket_http.request {
            url = string.format("http://%s:%s/%s", host, port, path),
            method = "GET",
            sink = ltn12.sink.table(response_body)
        }
        return code, string.format("%s", response_body[1])
    end),
    post = (function(host, port, path, data, connect_timeout, timeout, headers)
        local curl = require("curl.safe")
        headers = (type(headers) == "table" and headers) or {}
        connect_timeout = (type(connect_timeout) == "number" and connect_timeout) or 2
        timeout = (type(timeout) == "number" and timeout) or 2

        local buffer = {}
        local function writef(s)
            buffer[#buffer + 1] = s
        end
        local code = 0
        pcall(
            function()
                local c = curl.easy():setopt(curl.OPT_URL, string.format("http://%s:%s/%s", host, tostring(math.floor(port)), path)):setopt(curl.OPT_CONNECTTIMEOUT, connect_timeout):setopt(curl.OPT_TIMEOUT, timeout)

                if (#headers > 0) then
                    c:setopt_httpheader(headers)
                end

                c:setopt_postfields(data):setopt_writefunction(writef):perform()

                code = c:getinfo(curl.INFO_RESPONSE_CODE)
                c:close()
            end
        )

        local body

        if (code == 0) then
            code = -1
        else
            body = table.concat(buffer)
        end
        return math.floor(code), body
    end)
}

local search_device = function()
    --[[获取本地通讯端口]]
    local f, err = io.open("/private/var/mobile/Media/1ferver/1ferver.conf", "r")
    if not f then
        print(err)
        return
    end
    local config = f:read("*a")
    f:close()
    local config_json = json.decode(config)
    local device_port = tostring(math.floor(config_json.port))

    local severlist = {}
    local ip, resolved = socket.dns.toip(socket.dns.gethostname())
    local code, device_info = http.post("127.0.0.1", device_port, "deviceinfo", "", "")
    if not device_info then
        return
    end
    local info_json = json.decode(device_info)
    local ip = info_json["data"]["wifi_ip"]
    local sender = socket.udp()
    sender:setsockname(ip, math.random(40000, 60000))
    sender:setoption("broadcast", true)
    sender:sendto('{"ip":"' .. ip .. '","port":' .. udp_recieve_port .. '}', "255.255.255.255", 46953)
    sender:close()
    while true do
        local receive = udp_service:receivefrom()
        if receive then
            local device_json = json.decode(receive)
            if not devices[device_json["deviceid"]] then
                device_json.check = false
                device_json.state = "无"
                device_json.log = {}
                devices[device_json["deviceid"]] = device_json
            end
        else
            break
        end
    end
end

local selected_script_file = ""

--[[/var/mobile/Media/1ferver/bin/1ferver dofile /var/mobile/Media/1ferver/bin/WebSocket_CC.lua]]
local ev = require "ev"
local loop = ev.Loop.default
local websocket = require "websocket"
local server =
    websocket.server.ev.listen {
    protocols = {
        ["XXTouch-CC-Web"] = function(ws)
            ws:on_message(
                function(ws, message, opcode)
                    if opcode ~= websocket.TEXT then
                        return
                    end
                    local jobj = json.decode(message)
                    if type(jobj) ~= "table" then
                        return
                    end
                    local web_log = function(_type, msg, title)
                        ws:send(
                            json.encode(
                                {
                                    method = "web_log",
                                    type = _type,
                                    message = msg,
                                    title = title
                                }
                            )
                        )
                    end

                    local method = {
                        ["getlog"] = function()
                            --[[日志]]
                            --[[
								{"method":"log"}
								{"method":"log","devices":{"e27ce83a6955959eea72d53f07fcc5c1ec5bfd54":"Fuck"}}
							--]]
                            local log = {}
                            for deviceid, info in pairs(devices) do
                                log[deviceid] = {
                                    state = info.state,
                                    log = info.log
                                }
                            end
                            ws:send(
                                json.encode(
                                    {
                                        ["method"] = "log",
                                        ["devices"] = log
                                    }
                                )
                            )
                        end,
                        ["check_devices"] = function()
                            --[[勾选设备]]
                            --[[
								{"method":"check_devices"}
								{"method":"check_devices","devices":["e27ce83a6955959eea72d53f07fcc5c1ec5bfd54"]}
							--]]
                            for _, d_info in pairs(devices) do
                                d_info.check = false
                            end
                            for _, deviceid in pairs(jobj["deviceid"]) do
                                if devices[deviceid] then
                                    devices[deviceid].check = true
                                end
                            end
                        end,
                        ["search"] = function()
                            --[[扫描]]
                            --[[
								{"method":"search"}
								{"method":"search","devices":{"e27ce83a6955959eea72d53f07fcc5c1ec5bfd54":{xxxxxxxxxxxxxxxxxxxx}}}
							--]]
                            search_device()
                            ws:send(
                                json.encode(
                                    {
                                        ["method"] = "devices",
                                        ["devices"] = devices
                                    }
                                )
                            )
                        end,
                        ["spawn"] = function()
                            --[[运行]]
                            --[[
								{
									"method":"spawn",
									"deviceid":["e27ce83a6955959eea72d53f07fcc5c1ec5bfd54"],
									"args": {
										"server_ip":"10.0.0.88" 
									},
									"script_data":""
								}
							--]]
                            local script_byte = jobj["script_hex"]:from_hex()
                            local spawn_args = jobj["args"] or {}
                            for _, deviceid in pairs(jobj["deviceid"]) do
                                if devices[deviceid] then
                                    local ip = devices[deviceid]["ip"]
                                    local port = tostring(math.floor(devices[deviceid]["port"]))
                                    local code, receive_message = http.post(ip, port, "spawn", script_byte, nil, nil, {"spawn_args: " .. json.encode(spawn_args)})
                                    local receive_message_json = json.decode(receive_message)
                                    if type(receive_message_json) == "table" then
                                        devices[deviceid].state = receive_message_json.message
                                    else
                                        devices[deviceid].state = "超时"
                                    end
                                end
                            end
                        end,
                        ["recycle"] = function()
                            --[[停止]]
                            --[[
								{
									"method":"spawn",
									"deviceid":["e27ce83a6955959eea72d53f07fcc5c1ec5bfd54"]
								}
							--]]
                            for _, deviceid in pairs(jobj["deviceid"]) do
                                if devices[deviceid] then
                                    local ip = devices[deviceid]["ip"]
                                    local port = tostring(math.floor(devices[deviceid]["port"]))
                                    local code, receive_message = http.post(ip, port, "recycle", "")
                                    local receive_message_json = json.decode(receive_message)
                                    if type(receive_message_json) == "table" then
                                        devices[deviceid].state = receive_message_json.message
                                    else
                                        devices[deviceid].state = "超时"
                                    end
                                end
                            end
                        end,
                        ["send_file"] = function()
                            --[[发送文件]]
                            --[[
								{
									"method":"send_file",
									"deviceid":[
										"e27ce83a6955959eea72d53f07fcc5c1ec5bfd54"
									],
									"path":"/",
									"file":[
										"xxx.xxt":"十六进制"
									]
								}
							--]]
                            for _, deviceid in pairs(jobj["deviceid"]) do
                                if devices[deviceid] then
                                    local ip = devices[deviceid]["ip"]
                                    local port = tostring(math.floor(devices[deviceid]["port"]))
                                    for file_name, file_data in pairs(jobj["file"]) do
                                        local send_data =
                                            json.encode(
                                            {
                                                ["filename"] = jobj["path"] .. "/" .. file_name,
                                                ["data"] = file_data:from_hex():base64_encode()
                                            }
                                        )
                                        local code, receive_message = http.post(ip, port, "write_file", send_data)
                                        local receive_message_json = json.decode(receive_message)
                                        if type(receive_message_json) == "table" then
                                            devices[deviceid].state = receive_message_json.message
                                        else
                                            devices[deviceid].state = "超时"
                                        end
                                    end
                                end
                            end
                        end,
                        ["detect.auth"] = function()
                            --[[检测授权]]
                            --[[
								{
									"method":"auth",
									"deviceid":[
										"e27ce83a6955959eea72d53f07fcc5c1ec5bfd54"
									]
								}
							--]]
                            for _, deviceid in pairs(jobj["deviceid"]) do
                                if devices[deviceid] then
                                    local ip = devices[deviceid]["ip"]
                                    local port = tostring(math.floor(devices[deviceid]["port"]))
                                    local _, receive_message = http.post(ip, port, "device_auth_info", "")
                                    local receive_message_json = json.decode(receive_message)
                                    if type(receive_message_json) == "table" then
                                        local b_timeout = (receive_message_json.data.expireDate - receive_message_json.data.nowDate) <= 0
                                        local tab = os.date("*t", receive_message_json.data.expireDate)
                                        local timeout_message = string.format("%s/%s/%s %s:%s:%s", tab.year, tab.month, tab.day, tab.hour, tab.min, tab.sec)
                                        if b_timeout then
                                            devices[deviceid].state = [[<span style="color:red;">]] .. timeout_message .. [[</span>]]
                                        else
                                            devices[deviceid].state = [[<span style="color:blue;">]] .. timeout_message .. [[</span>]]
                                        end
                                    else
                                        devices[deviceid].state = "超时"
                                    end
                                end
                            end
                        end,
                        ["auth"] = function()
                            --[[批量授权]]
                            --[[
								{
									"method":"auth",
									"additional":true;
									"deviceid":[
										"e27ce83a6955959eea72d53f07fcc5c1ec5bfd54"
									],
									"code":[
										"十六位授权码"
									]
								}
							--]]
                            local code_index = 1
                            local device_index = 1
                            local _success = {}
                            local _device_error = {}
                            local _key_error = {}
                            local _code = jobj["code"]

                            for _, deviceid in pairs(jobj["deviceid"]) do
                                if devices[deviceid] then
                                    local v = {devices[deviceid].tsversion:match("(%w+)%.(%w+)%.(%w+)%.(%w+)")}
                                    if tonumber(v[1]) < 1 then
                                        web_log("message", "请把所有设备升级高版本XXTouch。", "批量授权错误")
                                        return
                                    elseif tonumber(v[1]) == 1 then
                                        if tonumber(v[2]) < 1 then
                                            web_log("message", "请把所有设备升级高版本XXTouch。", "批量授权错误")
                                            return
                                        elseif tonumber(v[2]) == 1 then
                                            if tonumber(v[3]) < 3 then
                                                web_log("message", "请把所有设备升级高版本XXTouch。", "批量授权错误")
                                                return
                                            elseif tonumber(v[3]) == 3 then
                                                if tonumber(v[4]) < 1 then
                                                    web_log("message", "请把所有设备升级高版本XXTouch。", "批量授权错误")
                                                    return
                                                else
                                                end
                                            end
                                        end
                                    end
                                end
                            end

                            while true do
                                --[[防止超出范围]]
                                if device_index > #(jobj["deviceid"]) or code_index > #(jobj["code"]) then
                                    break
                                end
                                local deviceid = jobj["deviceid"][device_index]
                                local ip = devices[deviceid]["ip"]
                                local port = tostring(math.floor(devices[deviceid]["port"]))
                                local code = _code[code_index]

                                local _, receive_message = http.post(ip, port, "bind_code", string.format("code=%s&mustbeless=%s", code, ((jobj.mustbeless and 0) or 7 * 24 * 3600)))
                                local receive_json = json.decode(receive_message)
                                if type(receive_json) == "table" then
                                    if receive_json.code == 0 then
                                        --[[授权成功]]
                                        table.insert(_success, string.format("%s\t%s\t%s", deviceid, devices[deviceid].devsn, code))
                                        devices[deviceid].state = "授权成功"
                                        device_index = device_index + 1
                                        code_index = code_index + 1
                                    elseif receive_json.code == 1 then
                                        --[[链接服务器异常]]
                                        table.insert(_device_error, string.format("%s\t%s\t%s", deviceid, devices[deviceid].devsn, receive_json.message))
                                        devices[deviceid].state = receive_json.message
                                        device_index = device_index + 1
                                    elseif receive_json.code > 1 then
                                        --[[服务器异常]]
                                        table.insert(_device_error, string.format("%s\t%s\t%s", deviceid, devices[deviceid].devsn, receive_json.message))
                                        devices[deviceid].state = receive_json.message
                                        device_index = device_index + 1
                                    elseif receive_json.code == -9 then
                                        --[[设备授权时间超过规定时间范围外]]
                                        table.insert(_device_error, string.format("%s\t%s\t%s", deviceid, devices[deviceid].devsn, receive_json.message))
                                        devices[deviceid].state = receive_json.message
                                        device_index = device_index + 1
                                    elseif receive_json.code ~= -9 and receive_json.code < 0 then
                                        --[[key有问题]]
                                        table.insert(_key_error, string.format("%s\t%s", code, receive_json.message))
                                        devices[deviceid].state = receive_json.message
                                        code_index = code_index + 1
                                    end
                                else
                                    table.insert(_device_error, string.format("%s\t%s\t%s", deviceid, devices[deviceid].devsn, "设备访问超时"))
                                    device_index = device_index + 1
                                end
                            end

                            local unused = {}
                            for i = code_index, #_code do
                                table.insert(unused, _code[i])
                            end
                            local tab = os.date("*t", os.time())
                            local now_str = string.format("%s/%s/%s %s:%s:%s", tab.year, tab.month, tab.day, tab.hour, tab.min, tab.sec)
                            local message =
                                table.concat(
                                {
                                    now_str,
                                    "授权成功:",
                                    table.concat(_success, "\r\n"),
                                    "出错设备:",
                                    table.concat(_device_error, "\r\n"),
                                    "出错授权码:",
                                    table.concat(_key_error, "\r\n"),
                                    "未使用授权码:",
                                    table.concat(unused, "\r\n"),
                                    "==================================================================="
                                },
                                "\r\n"
                            )
                            local f = io.open(cc_path .. "/log/授权记录.log", "a")
                            f:write(message .. "\r\n")
                            f:close()
                            web_log("message", message .. '\r\n记录已储存在"' .. cc_path .. '/log/授权记录.log"', "批量授权结果")
                        end,
                        ["clear.log"] = function()
                            --[[清理日志]]
                            --[[
								{"method":"clear.log","devices":["e27ce83a6955959eea72d53f07fcc5c1ec5bfd54"]}
							--]]
                            for _, deviceid in pairs(jobj["deviceid"]) do
                                if devices[deviceid] then
                                    devices[deviceid].log = {}
                                    devices[deviceid].state = "清理成功"
                                end
                            end
                        end,
                        ["quit"] = function()
                            --[[退出监听]]
                            os.exit()
                        end
                    }
                    if method[jobj["method"]] then
                        method[jobj["method"]]()
                    else
                        web_log("error", string.format('不存在"%s"命令', jobj["method"]))
                    end
                end
            )
            ws:on_close(
                function()
                end
            )
        end,
        ["XXTouch-CC-Client"] = function(ws)
            ws:on_message(
                function(ws, message, opcode)
                    if opcode ~= websocket.TEXT then
                        return
                    end
                    local jobj = json.decode(message)
                    if type(jobj) ~= "table" then
                        return
                    end
                    local receive = function(s)
                        ws:send(json.encode(s))
                    end

                    local method = {
                        ["log"] = function()
                            --[[日志]]
                            if not devices[jobj["deviceid"]] then
                                return
                            end --[[非存在设备]]
                            if not type(jobj["message"]) == "table" then
                                return
                            end --[[非表]]
                            local t_log = devices[jobj["deviceid"]].log
                            for col, value in pairs(jobj["message"]) do
                                t_log[col] = value
                            end
                        end,
                        ["run"] = function()
                            --[[中控端运行脚本]]
                            local send = function(msg)
                                ws:send(msg)
                            end
                            local s, err = pcall(load(jobj["lua_script"]))
                            receive(
                                {
                                    ["success"] = s,
                                    ["message"] = err
                                }
                            )
                        end,
                        ["file.exists"] = function()
                            --[[判断文件存在与否]]
                            local attr = lfs.attributes(cc_path .. "/data/" .. jobj["path"])
                            if type(attr) == "table" then
                                receive({exists = true, mode = attr.mode})
                            else
                                receive({exists = false})
                            end
                        end,
                        ["file.take"] = function()
                            --[[读取第一行并删掉]]
                            local f = io.open(cc_path .. "/data/" .. jobj["path"], "rb")
                            if f then
                                local data = f:read("*a")
                                f:close()
                                local _rn = data:split("\r\n")
                                local _r = data:split("\r")
                                local _n = data:split("\n")
                                local data_table = (#_rn > 1 and _rn) or (#_r > 1 and _r) or (#_n > 1 and _n)
                                local rd = data_table[1]
                                table.remove(data_table, 1)
                                local f = io.open(cc_path .. "/data/" .. jobj["path"], "rb")
                                f:write(table.concat(data_table, "\r\n"))
                                f:close()
                                receive({data = rd:to_hex(), exists = true})
                            else
                                receive({exists = false})
                            end
                        end,
                        ["file.reads"] = function()
                            --[[读取所有内容]]
                            local f = io.open(cc_path .. "/data/" .. jobj["path"], "rb")
                            if f then
                                local data = f:read("*a")
                                f:close()
                                receive({data = data:to_hex(), exists = true})
                            else
                                receive({exists = false})
                            end
                        end,
                        ["file.writes"] = function()
                            --[[写入文件]]
                            local f = io.open(cc_path .. "/data/" .. jobj["path"], "wb")
                            if f then
                                f:write((jobj["data"]):from_hex())
                                f:close()
                                receive({success = true})
                            else
                                receive({success = false})
                            end
                        end,
                        ["file.appends"] = function()
                            --[[追加至文件尾部]]
                            local f = io.open(cc_path .. "/data/" .. jobj["path"], "a")
                            if f then
                                f:write((jobj["data"]):from_hex())
                                f:close()
                                receive({success = true})
                            else
                                receive({success = false})
                            end
                        end
                    }
                    if method[jobj["method"]] then
                        method[jobj["method"]]()
                    else
                        print("命令不存在")
                    end
                end
            )
            ws:on_close(
                function()
                end
            )
        end
    },
    port = 46969
}

loop:loop()
