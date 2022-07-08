-- 简介: alert 是一个辅助脚本处理 UIKit 系统内建弹窗及 Safari 网页弹窗的 Lua 模块.
local alert = require("alert")

function alert_helper_test(step)
    
    if step == nil or step == "1" then
        nLog("#1 列出可用函数")
    	nLog(alert)
    end
    
    
    if step == nil or step == "1-1" then
        nLog("#1-1 打开日志记录")
        alert.disable_logging()
        alert.enable_logging()
    end
    
    
    if step == nil or step == "1-2" then
        nLog("#1-2 关闭自动点击")
        alert.disable_autopass()
    end
    
    
    if step == nil or step == "2-1" then
        nLog("#2-1 设置全局规则")
        alert.set_global_rules({
                {
                    ["title"] = "^About Cydia Installer$",  -- 通过标题过滤弹框 (正则表达式)
                    --["action"] = { ["title"] = "Close" }  -- 通过标题指定动作 (正则表达式)
                    ["action"] = 1,  -- 通过索引指定动作 (以 1 为起始, 0 的效果和 1 一致)
                },
                {
                    ["title"] = "^Verification Error$",  -- 通过标题过滤弹框 (正则表达式)
                    --["action"] = { ["title"] = "OK" },
                    ["action"] = "OK",  -- 通过标题指定动作 (简写)
                },
                {
                    ["title"] = "^Enter Cydia\\/APT URL$",  -- 通过标题过滤弹框 (正则表达式)
                    --["textfields"] = {
                    --    { ["text"] = "https://build.frida.re" },  -- 指定文本框内容
                    --},
                    ["textfields"] = { "https://" },  -- 指定文本框内容 (简写)
                    ["action"] = {
                        ["title"] = "Add Source",  -- 通过标题指定动作 (正则表达式)
                        ["delay"] = 500.0,  -- 设置动作延迟 (毫秒)
                    },
                },
        })
        nLog(alert.get_global_rules())
    end
    
    
    if step == nil or step == "2-2" then
        nLog("#2-2 设置应用本地规则")
        alert.disable_autopass()
        alert.clear_local_rules("com.apple.mobilesafari")  -- 使用专门的清空函数, 而不设置空表
        alert.set_local_rules("com.apple.mobilesafari", {
                {
                    ["title"] = "^Log in to",
                    --["textfields"] = {
                    --    { ["text"] = "user" },
                    --    { ["text"] = "pass" },
                    --},
                    ["textfields"] = {"user", "pass"},
                    ["action"] = {
                        ["title"] = "Log In",
                        ["delay"] = 1000.0,
                    },
                    --["action"] = "Log In",
                },
        })
        
        app.open_url("https://authenticationtest.com/HTTPAuth/")
        sys.msleep(5000)
        
        alert.clear_local_rules("*")  -- 使用 '*' 代表清空所有应用的本地规则 (不清空全局规则)
        nLog(alert.get_local_rules("com.apple.mobilesafari"))
    end
    
    
    if step == nil or step == "2-3" then
        nLog("#2-3 测试自动点击")
        alert.enable_autopass()
        alert.set_autopass_delay(500.0)  -- 设置自动点击延迟 (毫秒, 若小于 100 毫秒则视为 100 毫秒)
        app.run("com.saurik.Cydia")
        sys.msleep(3000)
        alert.show_prompt(
            "Test Title",  -- 标题
            "Test Message",  -- 内容
            "OK",  -- 默认按钮标题
            3000.0  -- 自动关闭时间 (毫秒, 若小于 100 毫秒则视为 0, 不自动关闭)
        )  -- 测试函数, 只有在系统应用中才能够使用, 生产环境下无需调用
        -- alert.disable_autopass()
    end
    
    
    if step == nil or step == "2-4" then
        nLog("#2-3 测试实时点击")
        local topMostDialog, err = alert.get_topmost()
        nLog(topMostDialog, err)
        if topMostDialog ~= nil then
            nLog(alert.dismiss_topmost())  -- 默认点击第一个按钮
            --nLog(alert.dismiss_topmost(1))  -- 通过索引指定动作 (以 1 为起始, 0 的效果和 1 一致)
            --nLog(alert.dismiss_topmost("^OK"))  -- 通过标题指定动作 (正则表达式)
            --nLog(alert.dismiss_topmost({
            --            ["title"] = "^OK",  -- 通过标题指定动作 (正则表达式)
            --            ["delay"] = 1000.0,  -- 设置动作延迟 (毫秒)
            --}))
            --nLog(alert.dismiss_topmost({ ["action"] = {
            --            ["title"] = "^OK",  -- 通过标题指定动作 (正则表达式)
            --            ["delay"] = 1000.0,  -- 设置动作延迟 (毫秒)
            --}}))
        end
    end
    
end

alert_helper_test("2-2")
