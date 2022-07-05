# -*- coding: utf-8 -*-
import socket, json  

local_ip = '192.168.2.174'  # 电脑端地址
local_port = 31500

local = (local_ip, local_port)
remote = ("255.255.255.255", 46953)
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(local)

s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
s.sendto(json.dumps({"ip":local_ip, "port": local_port}).encode(), remote)

# 接收广播, 接收到的数据是 json 格式的
# ipv4 + ipv6, 过滤掉不需要的数据
while True:
    data, addr = s.recvfrom(2048)
    if not data:
        print("client has exist")
        break
    print("received", data, "from", addr)

s.close()
