local memory = require("memory")
nLog(memory)

nLog("#1 获取运行中的应用程序进程 ID")
local status, app_proc_id = memory.get_process_id("info.pwfmfx.VividCounter")
nLog(app_proc_id)


--[[
    设定内存搜索范围
    设定内存搜索的范围，0 代表快速搜索，1 代表普通搜索
    快速搜索仅搜索堆、栈段，而普通搜索则搜索所有内存段，默认为普通搜索。

    memory.set_search_mode(搜索模式)
]]
nLog("#2 设定内存搜索范围")
memory.set_search_mode(0)  -- 快速搜索


--[[
    搜索应用内存
    搜索应用内存，支持数值模糊搜索与数值联合搜索。

    状态, 搜索结果数组或错误信息 = memory.search(应用PID, 是否为新搜索, 起始偏移地址, 待搜索的数据表, 全局搜索数据类型. 最大返回结果数量)
    
    应用PID（字符串）：运行中的进程ID，可以使用 app.pid_for_bid 来获取某个正在运行应用的 PID
    是否为新搜索（布尔型）：如果为 true，则从头开始搜索；如果为 false，则在上次搜索的结果中进行过滤搜索；搜索结果可以在服务重启前一直使用。
    起始偏移地址（整型）：进行内存搜索的起始位置。
    待搜索的数据表（表）：见下方说明。
    全局搜索数据类型（字符串）：若待搜索的数据表中，数据单元没有指定搜索的数据类型，将采用这个值进行填充。
    最大返回结果数量（整型）：搜索到指定数量的结果后，停止搜索。默认为 1024，0 为不限制。

    如果返回值中的状态为 false，说明搜索失败，失败信息保存在第二个参数中，可以打印获知。
]]
--[[
    待搜索的数据表格式:
    tb = {
        -- 以下 数组 填入几个搜索几次，大于 1 次即为联合搜索
        -- 第一次查询搜索数据：大于 lv，小于 hv，首次搜索 offset 无作用
        {
            ["lv"] = 1,         -- 模糊搜索，搜索内容 >= lv 值，不填 hv 为精确搜索，必填
            ["hv"] = 10,        -- 模糊搜索，搜索内容 <= hv 值，不填 hv 为精确搜索，可不填
            ["type"] = "U8"     -- 数据类型，指定这条数据用" 无符号的8位整数"的类型进行搜索，可不填，默认与 全局搜索类型 参数一致
        },
        -- 第二次查询搜索数据：大于 lv 2，小于 hv 10, 偏移 100（相对于第一次查询到结果地址 + 100）
        {
            ["lv"] = 2,         -- 模糊搜索，搜索内容 >= lv 值，不填 hv 为精确搜索，必填
            ["hv"] = 10,        -- 模糊搜索，搜索内容 <= hv 值，不填 hv 为精确搜索，可不填
            ["offset"] = 100,   -- 可不填，默认为0，不能为负数
            ["type"] = "I8"     -- 数据类型，指定这条数据用「有符号的8位整数」的类型进行搜索，可不填，默认与 全局搜索类型 参数一致
        },
        ...
        -- 第三、第四....
    }
]]
--[[
    支持的数据类型如下：
    I8:     有符号的8位整数
    I16:    有符号的16位整数
    I32:    有符号的32位整数
    I64:    有符号的64位整数
    U8:     无符号的8位整数
    U16:    无符号的16位整数
    U32:    无符号的32位整数
    U64:    无符号的64位整数
    F32:    有符号的32位浮点数
    F64:    有符号的64位浮点数
]]
nLog("#3-1 首次内存搜索")
for i=1,16 do
	touch.tap(100, 100)
    sys.msleep(500)
end
sys.msleep(1000)
local tb = {
    { lv = 16 },
}
local data
status, data = memory.search(
    app_proc_id,  -- 进程ID
    true,  -- 是否为新搜索
    0,  -- 起始地址
    tb,  -- 搜索表
    "U64"  -- 数据类型
)
nLog(status, #data)  -- 成功时 status 为 true，反之为 false
sys.msleep(1000)


nLog("#3-2 第二次内存搜索")
for i=1,10 do
	touch.tap(100, 100)
    sys.msleep(500)
end
sys.msleep(1000)
tb = {
    { lv = 26 },
}
status, data = memory.search(
    app_proc_id,  -- 进程ID
    false,  -- 是否为新搜索, 由于是第二次所以填 false
    0,  -- 起始地址
    tb,  -- 搜索表
    "U64"  -- 数据类型
)
nLog(status, #data)
sys.msleep(1000)


nLog("#3-3 第三次内存搜索")
for i=1,10 do
	touch.tap(100, 100)
    sys.msleep(500)
end
sys.msleep(1000)
tb = {
    { lv = 36 },
}
status, data = memory.search(
    app_proc_id,  -- 进程ID
    false,  -- 第三次搜索, 填 false
    0,  -- 起始地址
    tb,  -- 搜索表
    "U64"  -- 数据类型
)
nLog(status, #data)
sys.msleep(1000)
if #data ~= 1 then
    error("无法确定变化数据的唯一地址")
end


--[[
    读取应用内存
    以特定类型，读取指定应用指定内存地址上的数值。

    状态, 读取值或错误信息 = memory.read(应用PID, 读取地址, 值类型)

    如果返回值中的状态为 false，说明读取失败，失败信息保存在第二个参数中，可以打印获知。
]]
nLog("#4 读取应用内存")
local value
status, value = memory.read(app_proc_id, data[1], "U64")
nLog(status, value)
sys.msleep(1000)
if value ~= 36 then
    error("读取到的数据与搜索时得到的值不一致，数据发生变化，放弃修改")
end


--[[
    写入应用内存
    以特定类型，向指定应用指定内存地址上写入数值。
    
    状态，错误信息 = memory.write(应用PID, 写入地址, 欲写入的数值, 值类型)

    如果返回值中的状态为 false，说明写入失败，失败信息保存在第二个参数中，可以打印获知。
]]
nLog("#5 写入应用内存")
status = memory.write(app_proc_id, data[1], 992999, "U64")
nLog(status)
sys.msleep(1000)


touch.tap(100, 100)  -- 点一下才可以看到结果
sys.msleep(1000)
status, value = memory.read(app_proc_id, data[1], "U64")
nLog(status, value)
if value ~= 993000 then
    error("内存写入失败")
end
nLog("内存写入成功, 当前值为 "..value)
sys.msleep(3000)


--[[
    重置搜索结果
    清空搜索结果，下一次搜索将无条件视为全新搜索。
    这一方法能够释放搜索结果所占用的内存，并且阻止下一次脚本运行使用搜索结果。

    memory.reset_search()
]]
nLog("#6 重置搜索结果")
nLog(memory.reset_search())

