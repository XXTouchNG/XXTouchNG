var cc_server, cc_client, strVar = "";
strVar += 'local json = require "cjson.safe"\n', strVar += 'local lfs = require "lfs"\n', strVar += "local socket = require('socket')\n", strVar += "local udp_recieve_port = 35452\n", strVar += "\n", strVar += 'cc_path = "/var/mobile/Media/1ferver/cc"\n', strVar += "\n", strVar += "os.execute(\n", strVar += "	table.concat(\n", strVar += "		{\n", strVar += '			string.format("mkdir -p %s",cc_path),\n', strVar += '			string.format("mkdir -p %s/data",cc_path),\n', strVar += '			string.format("mkdir -p %s/log",cc_path),\n', strVar += "		},\n", strVar += "		';'\n", strVar += "	)\n", strVar += ")\n", strVar += "\n", strVar += "function sys.msleep(n) socket.select(nil, nil, n / 1000) end\n", strVar += "function sys.sleep(n) socket.select(nil, nil, n) end\n", strVar += "\n", strVar += "--[[建立UDP通讯]]\n", strVar += "local udp_service = socket.udp()\n", strVar += "udp_service:settimeout(0)\n", strVar += "udp_service:setsockname('*', udp_recieve_port)\n", strVar += "\n", strVar += "--[[创建用于储存的列表]]\n", strVar += "local devices = {}\n", strVar += "local http = {\n", strVar += "	get = (function(host, port, path)\n", strVar += '		local socket = require "socket"\n', strVar += '		local socket_http = require "socket.http"\n', strVar += "		socket_http.TIMEOUT = 5\n", strVar += '		local ltn12 = require("ltn12")\n', strVar += "		local response_body = {}\n", strVar += "		local rep , code = socket_http.request{\n", strVar += '			url = string.format("http://%s:%s/%s",host, port, path),\n', strVar += '			method = "GET",\n', strVar += "			sink = ltn12.sink.table(response_body),\n", strVar += "		}\n", strVar += "		return code, string.format('%s',response_body[1])\n", strVar += "	end),\n", strVar += "	post = (function(host, port, path, data, connect_timeout, timeout, headers)\n", strVar += '		local curl = require("curl.safe")\n', strVar += '		headers = (type(headers)=="table" and headers) or {}\n', strVar += '		connect_timeout = (type(connect_timeout)=="number" and connect_timeout) or 2\n', strVar += '		timeout = (type(timeout)=="number" and timeout) or 2\n', strVar += "\n", strVar += "		local buffer = {}\n", strVar += "		local function writef(s)\n", strVar += "			buffer[#buffer + 1] = s\n", strVar += "		end\n", strVar += "		local code = 0\n", strVar += "		pcall(function()\n", strVar += "			local c = curl.easy()\n", strVar += '				:setopt(curl.OPT_URL, string.format("http://%s:%s/%s",host, port, path))\n', strVar += "				:setopt(curl.OPT_CONNECTTIMEOUT, connect_timeout)\n", strVar += "				:setopt(curl.OPT_TIMEOUT, timeout)\n", strVar += "\n", strVar += "			if (#headers > 0) then\n", strVar += "				c:setopt_httpheader(headers)\n", strVar += "			end\n", strVar += "			\n", strVar += "			c:setopt_postfields(data)\n", strVar += "				:setopt_writefunction(writef)\n", strVar += "				:perform()\n", strVar += "\n", strVar += "			code = c:getinfo(curl.INFO_RESPONSE_CODE)\n", strVar += "			c:close()\n", strVar += "		end)\n", strVar += "		\n", strVar += "		local body\n", strVar += "		\n", strVar += "		if (code == 0) then\n", strVar += "			code = -1\n", strVar += "		else\n", strVar += "			body = table.concat(buffer)\n", strVar += "		end\n", strVar += "		return math.floor(code), body\n", strVar += "	end)\n", strVar += "}\n", strVar += "\n", strVar += "local search_device = function()	\n", strVar += "	--[[获取本地通讯端口]]\n", strVar += "	local f, err = io.open(\"/private/var/mobile/Media/1ferver/1ferver.conf\",'r')\n", strVar += "	if not f then print(err);return end\n", strVar += '	local config = f:read("*a")\n', strVar += "	f:close()\n", strVar += "	local config_json = json.decode(config)\n", strVar += "	local device_port = config_json.port\n", strVar += "	\n", strVar += "	local severlist = {}\n", strVar += "	local ip, resolved = socket.dns.toip(socket.dns.gethostname())\n", strVar += '	local code, device_info = http.post("127.0.0.1", device_port, "deviceinfo", "", "")\n', strVar += "	if not device_info then return end\n", strVar += "	local info_json = json.decode(device_info)\n", strVar += "	local ip = info_json['data']['wifi_ip']\n", strVar += "	local sender = socket.udp()\n", strVar += "	sender:setsockname(ip, math.random(40000, 60000))\n", strVar += '	sender:setoption("broadcast", true)\n', strVar += '	sender:sendto(\'{"ip":"\'..ip..\'","port":\'..udp_recieve_port..\'}\', "255.255.255.255", 46953)\n', strVar += "	sender:close()\n", strVar += "	while true do\n", strVar += "		local receive = udp_service:receivefrom()\n", strVar += "		if receive then\n", strVar += "			local device_json = json.decode(receive)\n", strVar += "			if not devices[device_json['deviceid']] then\n", strVar += "				device_json.check = false\n", strVar += '				device_json.state = "无"\n', strVar += "				device_json.log = {}\n", strVar += "				devices[device_json['deviceid']] = device_json\n", strVar += "			end\n", strVar += "		else\n", strVar += "			break\n", strVar += "		end\n", strVar += "	end\n", strVar += "end\n", strVar += "\n", strVar += "local selected_script_file = ''\n", strVar += "\n", strVar += "--[[/var/mobile/Media/1ferver/bin/1ferver dofile /var/mobile/Media/1ferver/bin/WebSocket_CC.lua]]\n", strVar += "\n", strVar += "local ev = require'ev'\n", strVar += "local loop = ev.Loop.default\n", strVar += "local websocket = require'websocket'\n", strVar += "local server = websocket.server.ev.listen\n", strVar += "{\n", strVar += "	protocols = {\n", strVar += "		['XXTouch-CC-Web'] = function(ws)\n", strVar += "			ws:on_message(\n", strVar += "				function(ws,message,opcode)\n", strVar += "					if opcode ~= websocket.TEXT then return end\n", strVar += "					local jobj = json.decode(message)\n", strVar += "					if type(jobj) ~= 'table' then return end\n", strVar += "					local web_log = function(_type,msg,title)\n", strVar += "						ws:send(\n", strVar += "							json.encode(\n", strVar += "								{\n", strVar += "									method = 'web_log',\n", strVar += "									type = _type,\n", strVar += "									message = msg,\n", strVar += "									title = title\n", strVar += "								}\n", strVar += "							)\n", strVar += "						)\n", strVar += "					end\n", strVar += "					\n", strVar += "					local method = {\n", strVar += "						['getlog'] = function()				--[[日志]]\n", strVar += "							--[[\n", strVar += '								{"method":"log"}\n', strVar += '								{"method":"log","devices":{"e27ce83a6955959eea72d53f07fcc5c1ec5bfd54":"Fuck"}}\n', strVar += "							--]]\n", strVar += "							local log = {}\n", strVar += "							for deviceid, info in pairs(devices) do\n", strVar += "								log[deviceid] = {\n", strVar += "									state = info.state,\n", strVar += "									log = info.log\n", strVar += "								}\n", strVar += "							end\n", strVar += "							ws:send(\n", strVar += "								json.encode(\n", strVar += "									{\n", strVar += "										['method'] = 'log',\n", strVar += "										['devices'] = log\n", strVar += "									}\n", strVar += "								)\n", strVar += "							)\n", strVar += "						end,\n", strVar += "						['check_devices'] = function()		--[[勾选设备]]\n", strVar += "							--[[\n", strVar += '								{"method":"check_devices"}\n', strVar += '								{"method":"check_devices","devices":["e27ce83a6955959eea72d53f07fcc5c1ec5bfd54"]}\n', strVar += "							--]]\n", strVar += "							for _, d_info in pairs(devices) do d_info.check = false end\n", strVar += '							for _, deviceid in pairs(jobj["deviceid"]) do\n', strVar += "								if devices[deviceid] then\n", strVar += "									devices[deviceid].check = true\n", strVar += "								end\n", strVar += "							end\n", strVar += "						end,\n", strVar += "						['search'] = function()				--[[扫描]]\n", strVar += "							--[[\n", strVar += '								{"method":"search"}\n', strVar += '								{"method":"search","devices":{"e27ce83a6955959eea72d53f07fcc5c1ec5bfd54":{xxxxxxxxxxxxxxxxxxxx}}}\n', strVar += "							--]]\n", strVar += "							search_device()\n", strVar += "							ws:send(\n", strVar += "								json.encode(\n", strVar += "									{\n", strVar += "										['method'] = 'devices',\n", strVar += "										['devices'] = devices\n", strVar += "									}\n", strVar += "								)\n", strVar += "							)\n", strVar += "						end,\n", strVar += "						['spawn'] = function()				--[[运行]]\n", strVar += "							--[[\n", strVar += "								{\n", strVar += '									"method":"spawn",\n', strVar += '									"deviceid":["e27ce83a6955959eea72d53f07fcc5c1ec5bfd54"],\n', strVar += '									"args": {\n', strVar += '										"server_ip":"10.0.0.88" \n', strVar += "									},\n", strVar += '									"script_data":""\n', strVar += "								}\n", strVar += "							--]]\n", strVar += "							local script_byte = jobj['script_hex']:from_hex()\n", strVar += "							local spawn_args = jobj['args'] or {}\n", strVar += "							for _, deviceid in pairs(jobj['deviceid']) do\n", strVar += "								if devices[deviceid] then\n", strVar += "									local ip = devices[deviceid]['ip']\n", strVar += "									local port = devices[deviceid]['port']\n", strVar += '									local code, receive_message = http.post(ip, port, "spawn", script_byte, nil, nil, {"spawn_args: " .. json.encode(spawn_args)})\n', strVar += "									local receive_message_json = json.decode(receive_message)\n", strVar += "									if type(receive_message_json) == 'table' then\n", strVar += "										devices[deviceid].state = receive_message_json.message\n", strVar += "									else\n", strVar += "										devices[deviceid].state = '超时'\n", strVar += "									end\n", strVar += "								end\n", strVar += "							end\n", strVar += "						end,\n", strVar += "						['recycle'] = function()			--[[停止]]\n", strVar += "							--[[\n", strVar += "								{\n", strVar += '									"method":"spawn",\n', strVar += '									"deviceid":["e27ce83a6955959eea72d53f07fcc5c1ec5bfd54"]\n', strVar += "								}\n", strVar += "							--]]\n", strVar += "							for _, deviceid in pairs(jobj['deviceid']) do\n", strVar += "								if devices[deviceid] then\n", strVar += "									local ip = devices[deviceid]['ip']\n", strVar += "									local port = devices[deviceid]['port']\n", strVar += '									local code, receive_message = http.post(ip, port, "recycle", "")\n', strVar += "									local receive_message_json = json.decode(receive_message)\n", strVar += "									if type(receive_message_json) == 'table' then\n", strVar += "										devices[deviceid].state = receive_message_json.message\n", strVar += "									else\n", strVar += "										devices[deviceid].state = '超时'\n", strVar += "									end\n", strVar += "								end\n", strVar += "							end\n", strVar += "						end,\n", strVar += "						['send_file'] = function()			--[[发送文件]]\n", strVar += "							--[[\n", strVar += "								{\n", strVar += '									"method":"send_file",\n', strVar += '									"deviceid":[\n', strVar += '										"e27ce83a6955959eea72d53f07fcc5c1ec5bfd54"\n', strVar += "									],\n", strVar += '									"path":"/",\n', strVar += '									"file":[\n', strVar += '										"xxx.xxt":"十六进制"\n', strVar += "									]\n", strVar += "								}\n", strVar += "							--]]\n", strVar += "							for _, deviceid in pairs(jobj['deviceid']) do\n", strVar += "								if devices[deviceid] then\n", strVar += "									local ip = devices[deviceid]['ip']\n", strVar += "									local port = devices[deviceid]['port']\n", strVar += "									for file_name, file_data in pairs(jobj['file']) do\n", strVar += "										local send_data = json.encode(\n", strVar += "											{\n", strVar += "												['filename'] = jobj['path'] .. '/' .. file_name,\n", strVar += "												['data'] = file_data:from_hex():base64_encode(),\n", strVar += "											}\n", strVar += "										)\n", strVar += '										local code, receive_message = http.post(ip, port, "write_file", send_data)\n', strVar += "										local receive_message_json = json.decode(receive_message)\n", strVar += "										if type(receive_message_json) == 'table' then\n", strVar += "											devices[deviceid].state = receive_message_json.message\n", strVar += "										else\n", strVar += "											devices[deviceid].state = '超时'\n", strVar += "										end\n", strVar += "									end\n", strVar += "								end\n", strVar += "							end\n", strVar += "						end,\n", strVar += "						['detect.auth'] = function()		--[[检测授权]]\n", strVar += "							--[[\n", strVar += "								{\n", strVar += '									"method":"auth",\n', strVar += '									"deviceid":[\n', strVar += '										"e27ce83a6955959eea72d53f07fcc5c1ec5bfd54"\n', strVar += "									]\n", strVar += "								}\n", strVar += "							--]]\n", strVar += "							for _, deviceid in pairs(jobj['deviceid']) do\n", strVar += "								if devices[deviceid] then\n", strVar += "									local ip = devices[deviceid]['ip']\n", strVar += "									local port = devices[deviceid]['port']\n", strVar += '									local _, receive_message = http.post(ip, port, "device_auth_info", "") \n', strVar += "									local receive_message_json = json.decode(receive_message)\n", strVar += "									if type(receive_message_json) == 'table' then\n", strVar += "										local b_timeout = (receive_message_json.data.expireDate - receive_message_json.data.nowDate) <= 0\n", strVar += '										local tab = os.date("*t", receive_message_json.data.expireDate)\n', strVar += "										local timeout_message = string.format('%s/%s/%s %s:%s:%s',tab.year,tab.month,tab.day,tab.hour,tab.min,tab.sec)\n", strVar += "										if b_timeout then\n", strVar += '											devices[deviceid].state = [[<span style="color:red;">]] .. timeout_message .. [[</span>]]\n', strVar += "										else\n", strVar += '											devices[deviceid].state = [[<span style="color:blue;">]] .. timeout_message .. [[</span>]]\n', strVar += "										end\n", strVar += "									else\n", strVar += "										devices[deviceid].state = '超时'\n", strVar += "									end\n", strVar += "								end\n", strVar += "							end\n", strVar += "						end,\n", strVar += "						['auth'] = function()				--[[批量授权]]\n", strVar += "							--[[\n", strVar += "								{\n", strVar += '									"method":"auth",\n', strVar += '									"additional":true;\n', strVar += '									"deviceid":[\n', strVar += '										"e27ce83a6955959eea72d53f07fcc5c1ec5bfd54"\n', strVar += "									],\n", strVar += '									"code":[\n', strVar += '										"十六位授权码"\n', strVar += "									]\n", strVar += "								}\n", strVar += "							--]]\n", strVar += "							local code_index = 1\n", strVar += "							local device_index = 1\n", strVar += "							local _success = {}\n", strVar += "							local _device_error = {}\n", strVar += "							local _key_error = {}\n", strVar += "							local _code = jobj['code']\n", strVar += "							\n", strVar += "							\n", strVar += "							for _, deviceid in pairs(jobj['deviceid']) do\n", strVar += "								if devices[deviceid] then\n", strVar += "									local v = {devices[deviceid].tsversion:match('(%w+)%.(%w+)%.(%w+)%.(%w+)')}\n", strVar += "									if tonumber(v[1]) < 1 then\n", strVar += '										web_log(\'message\',"请把所有设备升级高版本XXTouch。","批量授权错误")\n', strVar += "										return\n", strVar += "									elseif tonumber(v[1]) == 1 then\n", strVar += "										if tonumber(v[2]) < 1 then\n", strVar += '											web_log(\'message\',"请把所有设备升级高版本XXTouch。","批量授权错误")\n', strVar += "											return\n", strVar += "										elseif tonumber(v[2]) == 1 then\n", strVar += "											if tonumber(v[3]) < 3 then\n", strVar += '												web_log(\'message\',"请把所有设备升级高版本XXTouch。","批量授权错误")\n', strVar += "												return\n", strVar += "											elseif tonumber(v[3]) == 3 then\n", strVar += "												if tonumber(v[4]) < 1 then\n", strVar += '													web_log(\'message\',"请把所有设备升级高版本XXTouch。","批量授权错误")\n', strVar += "													return\n", strVar += "												else\n", strVar += "													\n", strVar += "												end\n", strVar += "											end\n", strVar += "										end\n", strVar += "									end\n", strVar += "								end\n", strVar += "							end\n", strVar += "							\n", strVar += "							while true do\n", strVar += "								--[[防止超出范围]]\n", strVar += "								if device_index > #(jobj['deviceid']) or code_index > #(jobj['code']) then break end\n", strVar += "								local deviceid = jobj['deviceid'][device_index]\n", strVar += "								local ip = devices[deviceid]['ip']\n", strVar += "								local port = devices[deviceid]['port']\n", strVar += "								local code = _code[code_index]\n", strVar += "								\n", strVar += "								local _, receive_message = http.post(\n", strVar += "									ip,\n", strVar += "									port,\n", strVar += '									"bind_code",\n', strVar += "									string.format(\n", strVar += '										"code=%s&mustbeless=%s",\n', strVar += "										code,\n", strVar += "										((jobj.mustbeless and 0) or 7 * 24 * 3600)\n", strVar += "									)\n", strVar += "								)\n", strVar += "								local receive_json = json.decode(receive_message)\n", strVar += "								if type(receive_json) == 'table' then\n", strVar += "									if receive_json.code == 0 then\n", strVar += "										--[[授权成功]]\n", strVar += '										table.insert(_success, string.format("%s\\t%s\\t%s", deviceid, devices[deviceid].devsn, code))\n', strVar += "										devices[deviceid].state = '授权成功'\n", strVar += "										device_index = device_index + 1\n", strVar += "										code_index = code_index + 1\n", strVar += "									elseif receive_json.code == 1 then\n", strVar += "										--[[链接服务器异常]]\n", strVar += '										table.insert(_device_error, string.format("%s\\t%s\\t%s", deviceid, devices[deviceid].devsn, receive_json.message))\n', strVar += "										devices[deviceid].state = receive_json.message\n", strVar += "										device_index = device_index + 1\n", strVar += "									elseif receive_json.code > 1 then\n", strVar += "										--[[服务器异常]]\n", strVar += '										table.insert(_device_error, string.format("%s\\t%s\\t%s", deviceid, devices[deviceid].devsn, receive_json.message))\n', strVar += "										devices[deviceid].state = receive_json.message\n", strVar += "										device_index = device_index + 1\n", strVar += "									elseif receive_json.code == -9 then\n", strVar += "										--[[设备授权时间超过规定时间范围外]]\n", strVar += '										table.insert(_device_error, string.format("%s\\t%s\\t%s", deviceid, devices[deviceid].devsn, receive_json.message))\n', strVar += "										devices[deviceid].state = receive_json.message\n", strVar += "										device_index = device_index + 1\n", strVar += "									elseif receive_json.code ~= -9 and receive_json.code < 0 then\n", strVar += "										--[[key有问题]]\n", strVar += '										table.insert(_key_error, string.format("%s\\t%s", code, receive_json.message))\n', strVar += "										devices[deviceid].state = receive_json.message\n", strVar += "										code_index = code_index + 1\n", strVar += "									end\n", strVar += "								else\n", strVar += '									table.insert(_device_error, string.format("%s\\t%s\\t%s", deviceid, devices[deviceid].devsn, "设备访问超时"))\n', strVar += "									device_index = device_index + 1\n", strVar += "								end\n", strVar += "							end\n", strVar += "							\n", strVar += "							local unused = {}\n", strVar += "							for i = code_index, #_code do\n", strVar += "								table.insert(unused, _code[i])\n", strVar += "							end\n", strVar += '							local tab = os.date("*t", os.time())\n', strVar += "							local now_str = string.format('%s/%s/%s %s:%s:%s',tab.year,tab.month,tab.day,tab.hour,tab.min,tab.sec)\n", strVar += "							local message = table.concat(\n", strVar += "								{\n", strVar += "									now_str,\n", strVar += '									"授权成功:",\n', strVar += "									table.concat(_success,'\\r\\n'),\n", strVar += '									"出错设备:",\n', strVar += "									table.concat(_device_error,'\\r\\n'),\n", strVar += '									"出错授权码:",\n', strVar += "									table.concat(_key_error,'\\r\\n'),\n", strVar += '									"未使用授权码:",\n', strVar += "									table.concat(unused,'\\r\\n'),\n", strVar += '									"==================================================================="\n', strVar += "								},\n", strVar += "								'\\r\\n'\n", strVar += "							)\n", strVar += "							local f = io.open(cc_path .. \"/log/授权记录.log\", 'a')\n", strVar += "							f:write(message .. '\\r\\n')\n", strVar += "							f:close()\n", strVar += '							web_log(\'message\',message .. "\\r\\n记录已储存在\\"" .. cc_path .. "/log/授权记录.log\\"","批量授权结果")\n', strVar += "						end,\n", strVar += "						['clear.log'] = function()			--[[清理日志]]\n", strVar += "							--[[\n", strVar += '								{"method":"clear.log","devices":["e27ce83a6955959eea72d53f07fcc5c1ec5bfd54"]}\n', strVar += "							--]]\n", strVar += "							for _, deviceid in pairs(jobj['deviceid']) do\n", strVar += "								if devices[deviceid] then\n", strVar += "									devices[deviceid].log = {}\n", strVar += '									devices[deviceid].state = "清理成功"\n', strVar += "								end\n", strVar += "							end\n", strVar += "						end,\n", strVar += "						['quit'] = function()				--[[退出监听]]\n", strVar += "							os.exit()\n", strVar += "						end,\n", strVar += "					}\n", strVar += "					if method[jobj['method']] then\n", strVar += "						method[jobj['method']]();\n", strVar += "					else\n", strVar += "						web_log('error',string.format('不存在\"%s\"命令',jobj['method']))\n", strVar += "					end\n", strVar += "					\n", strVar += "				end\n", strVar += "			)\n", strVar += "			ws:on_close(\n", strVar += "				function()\n", strVar += "					\n", strVar += "				end\n", strVar += "			)\n", strVar += "		end,\n", strVar += "		['XXTouch-CC-Client'] = function(ws)\n", strVar += "			ws:on_message(\n", strVar += "				function(ws,message,opcode)\n", strVar += "					if opcode ~= websocket.TEXT then return end\n", strVar += "					local jobj = json.decode(message)\n", strVar += "					if type(jobj) ~= 'table' then return end\n", strVar += "					local receive = function(s) ws:send(json.encode(s)) end\n", strVar += "					\n", strVar += "					local method = {\n", strVar += "						['log'] = function()										--[[日志]]\n", strVar += '							if not devices[jobj["deviceid"]] then return end		--[[非存在设备]]\n', strVar += "							if not type(jobj[\"message\"]) == 'table' then return end	--[[非表]]\n", strVar += '							local t_log = devices[jobj["deviceid"]].log\n', strVar += '							for col, value in pairs(jobj["message"]) do\n', strVar += "								t_log[col] = value\n", strVar += "							end\n", strVar += "						end,\n", strVar += "						['run'] = function()										--[[中控端运行脚本]]\n", strVar += "							local send = function(msg) ws:send(msg) end\n", strVar += '							local s, err = pcall(load(jobj["lua_script"]))\n', strVar += "							receive(\n", strVar += "								{\n", strVar += "									['success'] = s,\n", strVar += "									['message'] = err\n", strVar += "								}\n", strVar += "							)\n", strVar += "						end,\n", strVar += "						['file.exists'] = function()								--[[判断文件存在与否]]\n", strVar += '							local attr = lfs.attributes(cc_path .. "/data/" .. jobj["path"])\n', strVar += '							if type(attr) == "table" then\n', strVar += "								receive({exists = true,mode = attr.mode})\n", strVar += "							else\n", strVar += "								receive({exists = false})\n", strVar += "							end\n", strVar += "						end,\n", strVar += "						['file.take'] = function()									--[[读取第一行并删掉]]\n", strVar += '							local f = io.open(cc_path .. "/data/" .. jobj["path"], \'rb\')\n', strVar += "							if f then\n", strVar += '								local data = f:read("*a")\n', strVar += "								f:close()\n", strVar += '								local _rn = data:split("\\r\\n")\n', strVar += '								local _r = data:split("\\r")\n', strVar += '								local _n = data:split("\\n")\n', strVar += "								local data_table = (#_rn > 1 and _rn) or (#_r > 1 and _r) or (#_n > 1 and _n)\n", strVar += "								local rd = data_table[1]\n", strVar += "								table.remove(data_table,1)\n", strVar += '								local f = io.open(cc_path .. "/data/" .. jobj["path"], \'rb\')\n', strVar += "								f:write(table.concat(data_table,'\\r\\n'))\n", strVar += "								f:close()\n", strVar += "								receive({data = rd:to_hex() ,exists = true})\n", strVar += "							else\n", strVar += "								receive({exists = false})\n", strVar += "							end\n", strVar += "						end,\n", strVar += "						['file.reads'] = function()									--[[读取所有内容]]\n", strVar += '							local f = io.open(cc_path .. "/data/" .. jobj["path"], \'rb\')\n', strVar += "							if f then\n", strVar += '								local data = f:read("*a")\n', strVar += "								f:close()\n", strVar += "								receive({data = data:to_hex() ,exists = true})\n", strVar += "							else\n", strVar += "								receive({exists = false})\n", strVar += "							end\n", strVar += "						end,\n", strVar += "						['file.writes'] = function()								--[[写入文件]]\n", strVar += '							local f = io.open(cc_path .. "/data/" .. jobj["path"], \'wb\')\n', strVar += "							if f then\n", strVar += '								f:write((jobj["data"]):from_hex())\n', strVar += "								f:close()\n", strVar += "								receive({success = true})\n", strVar += "							else\n", strVar += "								receive({success = false})\n", strVar += "							end\n", strVar += "						end,\n", strVar += "						['file.appends'] = function()								--[[追加至文件尾部]]\n", strVar += '							local f = io.open(cc_path .. "/data/" .. jobj["path"], \'a\')\n', strVar += "							if f then\n", strVar += '								f:write((jobj["data"]):from_hex())\n', strVar += "								f:close()\n", strVar += "								receive({success = true})\n", strVar += "							else\n", strVar += "								receive({success = false})\n", strVar += "							end\n", strVar += "						end,\n", strVar += "					}\n", strVar += "					if method[jobj['method']] then\n", strVar += "						method[jobj['method']]();\n", strVar += "					else\n", strVar += '						print("命令不存在")\n', strVar += "					end\n", strVar += "				end\n", strVar += "			)\n", strVar += "			ws:on_close(\n", strVar += "				function()\n", strVar += "					\n", strVar += "				end\n", strVar += "			)\n", strVar += "		end\n", strVar += "	},\n", strVar += "	port = 46969\n", strVar += "}\n", strVar += "\n", strVar += "loop:loop()\n", cc_server = strVar, strVar = "", strVar += "local CC\n", strVar += "do\n", strVar += "	CC = {\n", strVar += "		sever_ip = (function()\n", strVar += "			local args = proc_take('spawn_args')\n", strVar += "			proc_put('spawn_args', args)\n", strVar += "			local args_json = json.decode(args)\n", strVar += "			return (type(args_json) == 'table' and args_json['server_ip']) or \"\"\n", strVar += "		end)(),\n", strVar += "		sever_port = 46969,\n", strVar += "		timeout = 3,\n", strVar += "		log = (function()\n", strVar += "			local log_table = {}\n", strVar += "			return function(message)\n", strVar += "				if type(message) == 'string' then\n", strVar += '					--[[传递字符串按照 "日志"]]\n', strVar += "					log_table['日志'] = message\n", strVar += "				elseif type(message) == 'table' then\n", strVar += "					--[[传递table 则根据内容进行写入临时表]]\n", strVar += "					for key, value in pairs(message) do\n", strVar += "						log_table[key] = value\n", strVar += "					end\n", strVar += "				else\n", strVar += "					--[[其它内容直接跳否定]]\n", strVar += "					return false\n", strVar += "				end\n", strVar += '				local websocket = require("websocket")\n', strVar += "				local wsc = websocket.client.new({timeout=CC.timeout})\n", strVar += "				local ok, err = wsc:connect(\n", strVar += "					string.format('ws://%s:%s',CC.sever_ip,CC.sever_port),\n", strVar += "					'XXTouch-CC-Client'\n", strVar += "				)\n", strVar += "				if not ok then\n", strVar += "					return false\n", strVar += "				else\n", strVar += "					local ok, was_clean, code, reason = wsc:send(\n", strVar += "						json.encode(\n", strVar += "							{\n", strVar += '								method = "log",\n', strVar += "								deviceid = device.udid(),\n", strVar += "								message = log_table\n", strVar += "							}\n", strVar += "						)\n", strVar += "					)\n", strVar += "					wsc:close()\n", strVar += "					return ok\n", strVar += "				end\n", strVar += "			end\n", strVar += "		end)(),\n", strVar += "		run = (function(lua_script,timeout)\n", strVar += '			local websocket = require("websocket")\n', strVar += "			local wsc = websocket.client.new({timeout = timeout or CC.timeout})\n", strVar += "			local ok, err = wsc:connect(\n", strVar += "				string.format('ws://%s:%s',CC.sever_ip,CC.sever_port),\n", strVar += "				'XXTouch-CC-Client'\n", strVar += "			)\n", strVar += "			if not ok then\n", strVar += "				return false\n", strVar += "			else\n", strVar += "				local ok, was_clean, code, reason = wsc:send(\n", strVar += "					json.encode(\n", strVar += "						{\n", strVar += '							method = "run",\n', strVar += "							lua_script = lua_script\n", strVar += "						}\n", strVar += "					)\n", strVar += "				)\n", strVar += "				local message, opcode, was_clean, code, reason = wsc:receive()\n", strVar += "				wsc:close()\n", strVar += "				if message then\n", strVar += "					local r_t = json.decode(message)\n", strVar += "					if r_t then return r_t.success end\n", strVar += "				end\n", strVar += "				return false\n", strVar += "			end\n", strVar += "		end),\n", strVar += "		file = {\n", strVar += "			_WebSocket_File = (function(t, timeout)\n", strVar += '				local websocket = require("websocket")\n', strVar += "				local wsc = websocket.client.new({timeout = timeout or CC.timeout})\n", strVar += "				local ok, err = wsc:connect(\n", strVar += "					string.format('ws://%s:%s',CC.sever_ip,CC.sever_port),\n", strVar += "					'XXTouch-CC-Client'\n", strVar += "				)\n", strVar += "				if not ok then\n", strVar += "					return false\n", strVar += "				else\n", strVar += "					local ok, was_clean, code, reason = wsc:send(\n", strVar += "						json.encode(t)\n", strVar += "					)\n", strVar += "					local message, opcode, was_clean, code, reason = wsc:receive()\n", strVar += '					nLog("rcve", message, opcode, was_clean, code, reason)\n', strVar += "					wsc:close()\n", strVar += "					return message\n", strVar += "				end\n", strVar += "			end),\n", strVar += "			exists = function(path, timeout)\n", strVar += '				local r = CC.file._WebSocket_File({method="file.exists",path=path}, timeout)\n', strVar += "				if not r then return false end\n", strVar += "				local r_t = json.decode(r)\n", strVar += "				if r_t and r_t.exists then\n", strVar += "					return r_t.mode\n", strVar += "				else\n", strVar += "					return nil\n", strVar += "				end\n", strVar += "			end,\n", strVar += "			take = function(path, timeout)\n", strVar += '				local r = CC.file._WebSocket_File({method="file.take",path=path}, timeout)\n', strVar += "				if not r then return false end\n", strVar += "				local r_t = json.decode(r)\n", strVar += "				if r_t and r_t.exists then\n", strVar += "					return r_t.data:from_hex()\n", strVar += "				else\n", strVar += "					return nil\n", strVar += "				end\n", strVar += "			end,\n", strVar += "			reads = function(path, timeout)\n", strVar += '				local r = CC.file._WebSocket_File({method="file.reads",path=path}, timeout)\n', strVar += "				if not r then return false end\n", strVar += "				local r_t = json.decode(r)\n", strVar += "				if r_t and r_t.exists then\n", strVar += "					return r_t.data:from_hex()\n", strVar += "				else\n", strVar += "					return nil\n", strVar += "				end\n", strVar += "			end,\n", strVar += "			writes = function(path, data, timeout)\n", strVar += '				local r = CC.file._WebSocket_File({method="file.writes",data=data:to_hex(),path=path}, timeout)\n', strVar += "				if not r then return false end\n", strVar += "				local r_t = json.decode(r)\n", strVar += "				if r_t and r_t.success then\n", strVar += "					return true\n", strVar += "				else\n", strVar += "					return nil\n", strVar += "				end\n", strVar += "			end,\n", strVar += "			appends = function(path, data, timeout)\n", strVar += '				local r = CC.file._WebSocket_File({method="file.appends",data=data:to_hex(),path=path}, timeout)\n', strVar += "				if not r then return false end\n", strVar += "				local r_t = json.decode(r)\n", strVar += "				if r_t and r_t.success then\n", strVar += "					return true\n", strVar += "				else\n", strVar += "					return nil\n", strVar += "				end\n", strVar += "			end,\n", strVar += "		}\n", strVar += "	}\n", strVar += "end\n", strVar += "--[=[\n", strVar += '	CC.log("内容")\n', strVar += "	\n", strVar += '	CC.log({["标题"] = "内容"})\n', strVar += "	\n", strVar += '	local b = CC.run("print(12312313)")\n', strVar += "	if b == false then --[[通讯超时]] end\n", strVar += "	\n", strVar += '	local b = CC.file.exists("临时文件.txt")\n', strVar += "	if b then\n", strVar += '		--[[ b 为类型 "file" 或者 "directory" ]]\n', strVar += "	elseif b == false then\n", strVar += "		--[[通讯超时]]\n", strVar += "	elseif b == nil then\n", strVar += "		--[[文件不存在]]\n", strVar += "	end\n", strVar += "	\n", strVar += '	local b = CC.file.take("临时文件.txt")\n', strVar += "	if b then\n", strVar += "		--[[ b 第一行的内容 ]]\n", strVar += "	elseif b == false then\n", strVar += "		--[[通讯超时]]\n", strVar += "	elseif b == nil then\n", strVar += "		--[[文件不存在]]\n", strVar += "	end\n", strVar += "	\n", strVar += "	\n", strVar += '	local b = CC.file.reads("临时文件.txt")\n', strVar += "	if b then\n", strVar += "		--[[ b 文件的内容 ]]\n", strVar += "	elseif b == false then\n", strVar += "		--[[通讯超时]]\n", strVar += "	elseif b == nil then\n", strVar += "		--[[文件不存在]]\n", strVar += "	end\n", strVar += "	\n", strVar += "	local b = CC.file.writes(\"临时文件.txt\",'测试内容\\r\\n测试内容2')\n", strVar += "	if b then\n", strVar += "		--[[写入成功]]\n", strVar += "	elseif b == false then\n", strVar += "		--[[通讯超时或失败]]\n", strVar += "	end\n", strVar += "	\n", strVar += "	local b = CC.file.appends(\"临时文件.txt\",'测试内容\\r\\n测试内容2')\n", strVar += "	if b then\n", strVar += "		--[[写入成功]]\n", strVar += "	elseif b == false then\n", strVar += "		--[[通讯超时或失败]]\n", strVar += "	end\n", strVar += "--]=]\n", strVar += "\n", cc_client = strVar, $(document).ready(function () {
    function a(a) {
        var d, c = "";
        for (d = 0; d < a.length; d++) c += b(a.charCodeAt(d).toString(16), 2);
        return c
    }

    function b(a, b) {
        for (var c = a.toString().length; b > c;) a = "0" + a, c++;
        return a
    }

    function c(a) {
        var b = document.createEvent("MouseEvents");
        b.initMouseEvent("click", !0, !1, window, 0, 0, 0, 0, 0, !1, !1, !1, !1, 0, null), a.dispatchEvent(b)
    }

    function d(a, b) {
        var d = window.URL || window.webkitURL || window,
            e = new Blob([b]),
            f = document.createElementNS("http://www.w3.org/1999/xhtml", "a");
        f.href = d.createObjectURL(e), f.download = a, c(f)
    }
    var e, f, g, h, i, k, l, m, n, o, p, q, r, s, t, u, v;
    $("#main-drawer a[href='./cc.html']").addClass("mdui-list-item-active"), e = "", f = "", g = !1, h = document.domain, i = new Array, new Array, k = function () {
        var a = new Array;
        return $.each($("#devices tbody tr"), function (b, c) {
            c.classList.contains("mdui-table-row-selected") && a.push(c.cells[3].innerHTML)
        }), a
    }, l = function () {
        var a = new Array;
        return $.each($("#devices tbody tr"), function (b, c) {
            c.classList.contains("mdui-table-row-selected") && a.push(c.cells[4].innerHTML)
        }), a
    }, m = new mdui.Dialog("#dialog_dropbox"), n = new mdui.Dialog("#dialog_auth"), o = document.getElementById("dropbox"), document.addEventListener("dragenter", function () {
        o.style.borderColor = "gray"
    }, !1), document.addEventListener("dragleave", function () {
        o.style.borderColor = "silver"
    }, !1), o.addEventListener("dragenter", function () {
        o.style.borderColor = "gray", o.style.backgroundColor = "white"
    }, !1), o.addEventListener("dragleave", function () {
        o.style.backgroundColor = "transparent"
    }, !1), o.addEventListener("dragenter", function (a) {
        a.stopPropagation(), a.preventDefault()
    }, !1), o.addEventListener("dragover", function (a) {
        a.stopPropagation(), a.preventDefault()
    }, !1), o.addEventListener("drop", function (a) {
        a.stopPropagation(), a.preventDefault(), p(a.dataTransfer.files)
    }, !1), p = function (b) {
        var g, c = b[0];
        c.size > 31457280 ? mdui.alert("请控制脚本在30M以内") : (g = new FileReader, g.readAsBinaryString(c), g.onload = function () {
            f = a(g.result), e = c.name, $("#scriptname").html(c.name)
        })
    }, $("#cc_api").attr("data-clipboard-text", cc_client), $("#search").on("click", function () {
        s({
            method: "search"
        })
    }), $("#spawn").on("click", function () {
        $("#dialog_dropbox").find("button").off("click"), $("#dialog_dropbox").find("button").on("click", function () {
            s({
                method: "spawn",
                deviceid: k(),
                args: {
                    server_ip: document.domain
                },
                script_hex: f
            })
        }), m.open()
    }), $("#recycle").on("click", function () {
        s({
            method: "recycle",
            deviceid: k()
        })
    }), $("#send_file").on("click", function () {
        $("#dialog_dropbox").find("button").off("click"), $("#dialog_dropbox").find("button").on("click", function () {
            var b = {
                method: "send_file",
                deviceid: k(),
                file: {},
                path: "/lua/scripts"
            };
            b.file[e] = f, s(b)
        }), m.open()
    }), $("#detect_auth").on("click", function () {
        s({
            method: "detect.auth",
            deviceid: k()
        })
    }), $("#dialog_auth_cancel").on("click", function () {
        n.close()
    }), $("#auth").on("click", function () {
        $("#dialog_auth_submit").off("click"), $("#dialog_auth_submit").on("click", function () {
            var b = new Array;
            $("#auth-code").val().trim().split("\n").forEach(function (a) {
                b.push(a)
            }), s({
                method: "auth",
                mustbeless: $("#mustbeless").is(":checked"),
                deviceid: k(),
                code: b
            }), n.close()
        }), n.open()
    }), $("#clear_log").on("click", function () {
        s({
            method: "clear.log",
            deviceid: k()
        })
    }), q = new Clipboard(".cptext"), q.on("success", function () {
        mdui.snackbar({
            message: "复制成功"
        })
    }), q.on("error", function () {
        mdui.snackbar({
            message: "复制失败，请手动复制"
        })
    }), s = function (a) {
        r.send(JSON.stringify(a))
    }, setInterval(function () {
        g && s({
            method: "getlog"
        })
    }, 500), $("#run_cc").on("click", function () {
        v()
    }), t = {}, u = function () {
        r = new WebSocket("ws://" + h + ":46969", "XXTouch-CC-Web");
        try {
            r.onopen = function () {
                s({
                    method: "search"
                }), $("#button_text").html("&#xe047;"), $("#run_cc").attr("mdui-tooltip", "{content: '停止服务'}"), g = !0
            }, r.onmessage = function (a) {
                var b = JSON.parse(a.data);
                switch (b.method) {
                    case "devices":
                        i = b.devices, $("#devices tbody").empty(), $.each(b.devices, function (a, b) {
                            var d, c = $("<tr></tr>");
                            b.check && c.addClass("mdui-table-row-selected"), c.append($('<td class="mdui-table-cell-checkbox"><label class="mdui-checkbox"><input type="checkbox"><i class="mdui-checkbox-icon"></i></label></td>'), $("<td>" + b.devname + "</td>"), $("<td>" + b.ip + "</td>"), $('<td style="display:none;">' + b.deviceid + "</td>"), $('<td style="display:none;">' + b.devsn + "</td>"), $("<td>" + b.state + "</td>")), $.each(t, function (a) {
                                b.log[a] ? c.append($("<td>" + b.log[a] + "</td>")) : c.append($("<td></td>"))
                            }), $.each(b.log, function (a) {
                                t[a] || (t[a] = !0, c.append($("<td>" + b.log[a] + "</td>")), $("#devices thead tr").append($("<th>" + a + "</th>")))
                            }), $("#devices tbody").append(c), mdui.updateTables(), d = "", $.each(k(), function (a, b) {
                                d += b + "\r\n"
                            }), $("#cp_deviceid").attr("data-clipboard-text", d), d = "", $.each(l(), function (a, b) {
                                d += b + "\r\n"
                            }), $("#cp_devsn").attr("data-clipboard-text", d), $("input").off("change"), $("input").on("change", function () {
                                var b, a = new Array;
                                $.each($("#devices tbody tr"), function (b, c) {
                                    c.classList.contains("mdui-table-row-selected") && a.push(c.cells[3].innerHTML)
                                }), s({
                                    method: "check_devices",
                                    deviceid: a
                                }), b = "", $.each(k(), function (a, c) {
                                    b += c + "\r\n"
                                }), $("#cp_deviceid").attr("data-clipboard-text", b), b = "", $.each(l(), function (a, c) {
                                    b += c + "\r\n"
                                }), $("#cp_devsn").attr("data-clipboard-text", b)
                            })
                        });
                        break;
                    case "log":
                        $.each(b.devices, function (a, b) {
                            i[a] && (i[a].state = b.state, i[a].log = b.log)
                        }), $.each($("#devices tbody tr"), function (a, b) {
                            var d, e, c = b.cells[3].innerText;
                            i[c] && (b.cells[5].innerHTML = i[c].state, d = i[c], e = 6, $.each(t, function (a) {
                                b.cells.length <= e && $(b).append($("<td>" + a + "</td>")), b.cells[e].innerHTML = d.log[a] ? d.log[a] : "", e += 1
                            }), $.each(d.log, function (a) {
                                t[a] || (t[a] = !0, $(b).append($("<td>" + d.log[a] + "</td>")), $("#devices thead tr").append($("<th>" + a + "</th>")))
                            }))
                        });
                        break;
                    case "web_log":
                        switch (b.type) {
                            case "message":
                                mdui.dialog({
                                    title: b.title,
                                    content: '<textarea class="mdui-center" style="margin:0 auto;width: 95%;height: 500px;">' + b.message + "</textarea>",
                                    buttons: [{
                                        text: "保存",
                                        onClick: function () {
                                            d("Auth_" + (new Date).valueOf() + ".txt", b.message)
                                        }
                                    }, {
                                        text: "确认"
                                    }]
                                });
                                break;
                            case "success":
                                mdui.snackbar({
                                    message: b.message
                                });
                                break;
                            case "error":
                                mdui.dialog({
                                    title: "错误",
                                    content: b.message,
                                    buttons: [{
                                        text: "确认"
                                    }]
                                })
                        }
                }
            }, r.onclose = function () {
                $("#button_text").html("&#xe037;"), $("#devices tbody").empty(), $("#run_cc").attr("mdui-tooltip", "{content: '启动服务'}"), g = !1, mdui.snackbar({
                    message: "服务未开启，点页面右上角的箭头可启动服务"
                })
            }
        } catch (a) {
            $("#button_text").html("&#xe037;"), $("#devices tbody").empty(), $("#run_cc").attr("mdui-tooltip", "{content: '启动服务'}"), g = !1, mdui.snackbar({
                message: "服务未开启，点页面右上角的箭头可启动服务"
            })
        }
    }, v = function () {
        g ? (s({
            method: "quit"
        }), $("#devices tbody").empty(), g = !1, $("#button_text").html("&#xe037;"), $("#run_cc").attr("mdui-tooltip", "{content: '启动服务'}")) : $.post("/write_file", JSON.stringify({
            filename: "/bin/cc.lua",
            data: Base64.encode(cc_server)
        }), function () {
            $.post("/command_spawn", "nohup lua /var/mobile/Media/1ferver/bin/cc.lua </dev/null >/dev/null 2>/dev/null &", function () {
                setTimeout(u, 1e3)
            }, "json").error(function () {
                mdui.snackbar({
                    message: "与设备通讯无法达成"
                })
            })
        }, "json").error(function () {
            mdui.snackbar({
                message: "与设备通讯无法达成"
            })
        })
    }, u()
});