local ts = require("ts")
local json = ts.json

local CashApp = require("CashApp")

-- 测试请求
dialog(json.encode(CashApp.Hello({ ["question"] = "whoami" })))

-- 获取数据更新时间戳
dialog(CashApp.GetLoadedAt())

-- 获取余额
dialog(CashApp.GetBalance())

-- 获取 $CashTag URL
dialog(CashApp.GetCashTagURL())

-- 获取卡片信息
dialog(json.encode(CashApp.GetIssuedCard()))

-- 获取直存直取账户信息
dialog(json.encode(CashApp.GetDirectDepositAccount()))


