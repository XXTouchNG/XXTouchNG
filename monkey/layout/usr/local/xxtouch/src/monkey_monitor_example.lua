local monkey = require("monkey")  -- 引入 monkey 模块

-- 此例程展示了如何在 JS 中使用 `TamperMonkey.postMessage` 发送脚本消息，
-- 以及如何在 Lua 中使用 `monkey.list_userscript_messages` 接收脚本消息，
-- 从而避免频繁注入 JS 脚本，从而提高程序通信性能。
function monkey_monitor_test()
    
    monkey.remove_all_userscripts()  -- 移除其他用户脚本
    monkey.add_userscript(
        { ["host"] = "www.bing.com" },  -- 精确匹配，匹配表
        [[
            var timer = window.setInterval(function () {
                if (document.getElementById('sb_form')) {
                    window.clearInterval(timer);  // 记得停止定时器
                    TamperMonkey.postMessage({
                        type: 'loaded',
                        id: 'sb_form',
                    });  // 发送用户脚本消息到 TamperMonkey
                }
            }, 1000);  // 设置定时器，每 1 秒检查一次
        ]],  -- 需要执行的脚本内容，检查 sb_form 元素是否出现在页面上
        true,  -- 是否在加载完成后立即执行, 若为 `false` 则在网页加载开始前执行.
        true   -- 是否仅在主帧框中执行, 若为 `false` 则在所有 `iframe` 中也得到执行.
    )  -- 添加检查 sb_form 是否存在的用户脚本
    
    sys.msleep(1000)  -- 等待 1 秒
    app.open_url("https://www.bing.com/")  -- 打开网页
    sys.msleep(1000)  -- 等待 1 秒

    while true do  -- 循环检查，自己处理检查次数
        local msg = monkey.list_userscript_messages({["host"] = "www.bing.com"})  -- 获取用户脚本消息，这个不是注入，消耗比注入小很多
        msg = msg[#msg]  -- 获取最后一条消息
        if msg["body"] ~= nil then  -- 如果消息不为空
            if msg["body"]["type"] == "loaded" and msg["body"]["id"] == "sb_form" then  -- 如果消息类型为 loaded，并且 id 为 sb_form
                break  -- 跳出循环
            end
        end
        sys.msleep(1000)  -- 等待 1 秒
    end

    -- sb_form 已经出现在页面上，可以继续执行了

end

monkey_monitor_test()  -- 执行测试

