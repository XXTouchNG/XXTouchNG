-- 简介: monkey 是一个在 iOS WebView 中执行额外 JavaScript 表达式、附加额外用户脚本的 Lua 模块.
local monkey = require("monkey")

function monkey_test()
    
    nLog("#1-1 列出可用函数")
    nLog(monkey)
    
    
    nLog("#1-2 移除所有预设用户脚本")
    monkey.clear_userscripts()
    
    
    nLog("#1-3 添加预设用户脚本")
    monkey.add_userscript(
        {
        	["host"] = "www.baidu.com",  -- 精确匹配
    	},  -- 匹配表
        "alert('This is Baidu.');",  -- 需要执行的脚本内容
        true,  -- 是否在加载完成后立即执行, 若为 `false` 则在网页加载开始前执行.
        true   -- 是否仅在主帧框中执行, 若为 `false` 则在所有 `iframe` 中也得到执行.
    )
    monkey.add_userscript(
        {
        	["host"] = "www.bing.com",    -- 精确匹配
    	},  -- 匹配表
        "alert('This is Bing.');",  -- 需要执行的脚本内容
        true,  -- 是否在加载完成后立即执行, 若为 `false` 则在网页加载开始前执行.
        true   -- 是否仅在主帧框中执行, 若为 `false` 则在所有 `iframe` 中也得到执行.
    )
    
    
    nLog("#1-4 列出预设用户脚本")
    nLog(monkey.list_userscripts())
    
    
    nLog("#1-5 测试用户脚本")
    app.open_url("https://www.bing.com/")
    sys.msleep(3000)
    
    
    -- 进阶用法:
    -- 在用户 JS 脚本或 Eval 中, 可通过 `TamperMonkey.postMessage(...)` 向进程字典储存 JS 对象.
    -- 然后, 在 Lua 使用 `monkey.list_userscript_messages` 可使用匹配表筛选并列出这些对象, 从而达到由用户 JS 脚本与 Lua 间*异步*传递消息的目的.
    -- 注意, 这些储存的 JS 对象是*易失*对象, 即页面关闭或浏览器进程结束后, 这些消息会丢失.
    nLog("#1-6 打印用户脚本消息")
    nLog(monkey.list_userscript_messages({["host"] = "www.bing.com"}))
    
    
    nLog("#2 打印前台应用所有 WebView")
    app.open_url("https://mew.darwindev.com/client")
    sys.msleep(3000)
    
    -- 如果前台应用没有 WebView, 或者 WebView 不在前台, 则等待 3 秒后在第二个返回值中返回超时错误 (此策略对于本脚本中所有接口均成立)
    local tableOfWebViews, err = monkey.list_webviews()
    nLog(tableOfWebViews, err)
    
    
    if tableOfWebViews ~= nil and #tableOfWebViews["views"] > 0 then
        
        -- 获取第一个 WebView 的标志符
        local idOfFirstWebView = tableOfWebViews["views"][1]["objectIdentifier"]
        
        -- 如果该标志符对应的 WebView 不存在或者已被销毁, 则返回 nil
        nLog("#3 使用标志符直接获取该 WebView 状态")
        local tableOfFirstWebView = monkey.get_webview_id(idOfFirstWebView)
        nLog(tableOfFirstWebView)
    end
    
    
    nLog("#4 使用匹配表获取符合条件的 WebView")
    local matchedWebView = monkey.get_webview({
        ["responder"] = "com.apple.mobilesafari",  -- 精确匹配
        ["scheme"] = "https",  -- 精确匹配
        ["host"] = "mew.darwindev.com",  -- 精确匹配
        ["path"] = "/client",  -- 精确匹配
        ["absoluteString"] = "https://mew.darwindev.com/client/",  -- 精确匹配
        ["url"] = "^https://mew\\.darwindev\\.com/(client|server)/$",  -- 等同于 absoluteString 的标准正则匹配
    })
    -- 如果无符合条件的 WebView, 则返回 nil
    nLog(matchedWebView)
    
    
    if matchedWebView ~= nil then
        nLog("#5 将 WebView 状态表传入以获取此 WebView 的最新状态")
        nLog(monkey.get_webview(matchedWebView))
        
        
        local evalResultSync, evalError = monkey.eval(matchedWebView, "'2' + 3")
        nLog("#6-1 JS 执行测试 (基本数据类型, 成功)")
        if evalResultSync ~= nil then
            -- 如果 JS 执行无异常, 则返回值不为 `nil` 且可被 `json.decode` 解码转化为 Lua 中可用的数据类型.
            nLog(json.decode(evalResultSync))
        else
            nLog(evalError)
        end
        
        
        -- 以下例子打印了在 JS 中可用的 `TamperMonkey` 辅助函数.
        -- 注意: 如果 `targetClass` 为 `WKWebView`, 需执行的 JS 开头无需添加 `return`.
        -- 如果需执行多行 JS, 可以利用 JS 中的匿名函数将需要执行的内容包起来.
        evalResultSync, evalError = monkey.eval(matchedWebView, [==[
(function () {
    const $$ = TamperMonkey;
    $$.highlightElement($$.querySelector('body'));
    return Object.keys($$);
})();
        ]==])
        nLog("#6-2 JS 执行测试 (复杂数据类型, 成功)")
        if evalResultSync ~= nil then
            nLog(json.decode(evalResultSync))
        end
        
        
        evalResultSync, evalError = monkey.eval(matchedWebView, "({ return [1,2,3]; })();")
        nLog("#6-3 JS 执行测试 (发生异常)")
        if evalResultSync ~= nil then
            nLog(json.decode(evalResultSync))
        else
            nLog(evalError)
            
            -- 若 `targetClass` 为 `WKWebView` 则 `evalError` 中可能包含如下错误信息:
            -- * `WKJavaScriptExceptionColumnNumber` 发生错误的列
            -- * `WKJavaScriptExceptionLineNumber` 发生错误的行
            -- * `WKJavaScriptExceptionMessage` 错误详情
        end
        
        
        -- 取出 WebView 的标志符以便后续使用时减少重新查找视图时的性能开销.
        local matchedWebViewIdentifier = matchedWebView["objectIdentifier"]
        
        evalResultSync, evalError = monkey.eval_id(matchedWebViewIdentifier, "(function (){ return [1,2,3]; })();")
        nLog("#6-4 JS 执行测试 (成功)")
        if evalResultSync ~= nil then
            nLog(json.decode(evalResultSync))
        end
        
        
        -- 进阶用法:
        -- 为了实现自动打码等需求, 需要从 JS 中发起无限制的跨域请求.
        -- 以下例子展示了在 JS 中利用 `TamperMonkey.xmlHttpRequest` 辅助函数进行原生网络请求的方式.
        -- 此函数具体使用方法参见 [`GM.xmlHttpRequest`](https://wiki.greasespot.net/GM.xmlHttpRequest)
        
        -- 由于工作量较大, 暂时只实现了传入参数 `data`/`headers`/`method`/`url`/`onload`/`onerror` 和返回对象 `responseHeaders`/`responseText`/`status`/`statusText` 的支持.
        
        nLog("#6-5 JS 跨域请求测试")
        evalResultSync, evalError = monkey.eval_id(matchedWebViewIdentifier, [==[
(function () {
    return TamperMonkey.xmlHttpRequest({
        method: "GET",
        url: "http://www.example.com/",
        onload: function(response) {
            alert(response.responseText);
        },
        onerror: function(error) {
            alert(error);
        }
    });
})();
        ]==])
        sys.msleep(5000)
    end
    
    
    nLog("#7 尝试获取 Cydia 首页")
    local uiWebView = monkey.get_webview({ ["host"] = "cydia.saurik.com" })
    if uiWebView ~= nil then
        nLog(uiWebView)
        
        
        nLog("#8 JS 执行异步弹窗 (不影响超时判断, 无法获取返回值)")
        local evalResultAsync = monkey.eval(uiWebView, "setTimeout(function() { alert(1); }, 500);")
        nLog(evalResultAsync)
        
        
        -- 注意: 如果 `targetClass` 为 `UIWebView` (现在用得已经很少了), 需执行的 js 开头需添加 `return` 才能获取到返回值.
        nLog("#9-1 JS 执行同步调用 (基本数据类型, 成功)")
        evalResultSync, evalError = monkey.eval(uiWebView, "return '2' + 3;")
        if evalResultSync ~= nil then
            nLog(json.decode(evalResultSync))
        end
        
        
        nLog("#9-2 JS 执行同步调用 (复杂数据类型, 成功)")
        evalResultSync, evalError = monkey.eval(uiWebView, "return {'1': 11, '2': '22'};")
        if evalResultSync ~= nil then
            nLog(json.decode(evalResultSync))
        end
        
        
        nLog("#9-3 JS 执行同步调用 (失败)")
        evalResultSync, evalError = monkey.eval(uiWebView, "return (() { return {'1': 11, '2': '22'}; })();")
        if evalResultSync ~= nil then
            nLog(json.decode(evalResultSync))
        else
            nLog(evalError)
            
            -- 若 `targetClass` 为 `UIWebView` 则 `evalError` 中可能包含如下错误信息:
            -- * `NSFilePath` 产生错误的 URL
            -- * `NSLocalizedDescription` 错误概述
            -- * `NSLocalizedFailureReason` 错误详情及发生错误的调用栈
        end
    end
    
    
    nLog("#10 测试 Safari")
    local safariWebView = monkey.get_webview({ ["host"] = "www.apple.com" })
    if safariWebView ~= nil then
        -- 得到标志符
        local safariId = safariWebView["objectIdentifier"]
        
        -- 跳转到必应
        nLog("#11 跳转到必应")
        monkey.eval_id(safariId, "window.location.href = 'https://bing.com';")
        sys.msleep(1000)
        
        -- 获取当前新地址
        nLog("#12 获取当前新地址")
        local newHref = monkey.eval_id(safariId, "window.location.href;")
        nLog(newHref)
    end

    nLog("#11-1 测试单选选择器")
    app.open_url("https://www.w3schools.com/tags/tryit.asp?filename=tryhtml_option_disabled")
    nLog(monkey.get_topmost_formcontrol())  -- 获取最前方的表单选择器
    sys.msleep(500)
    nLog(monkey.update_topmost_formcontrol(1))  -- 选择第一项 (自动完成)
    sys.msleep(500)
    nLog(monkey.update_topmost_formcontrol("Audi"))  -- 选择值为 Audi 的项 (自动完成)

    nLog("#11-2 测试多选选择器")
    app.open_url("https://www.w3schools.com/tags/tryit.asp?filename=tryhtml_select_multiple")
    nLog(monkey.get_topmost_formcontrol())  -- 获取最前方的表单选择器
    sys.msleep(500)
    nLog(monkey.update_topmost_formcontrol(1))  -- 选择第一项, 并移除其他项的选中状态 (自动完成)
    sys.msleep(500)
    nLog(monkey.update_topmost_formcontrol(2, true))  -- 增加选择第二项
    sys.msleep(500)
    nLog(monkey.update_topmost_formcontrol(3, true))  -- 增加选择第三项
    sys.msleep(500)
    nLog(monkey.update_topmost_formcontrol("Audi"))  -- 选择值为 Audi 的项, 并移除其他项的选中状态 (自动完成)
    sys.msleep(500)
    nLog(monkey.update_topmost_formcontrol("Benz", true))  -- 增加选择值为 Benz 的项
    sys.msleep(500)
    nLog(monkey.dismiss_topmost_formcontrol())  -- 点击完成

    
    nLog("#11-3 测试日期时间选择器")
    app.open_url("https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input/datetime-local")
    nLog(monkey.get_topmost_formcontrol())
    sys.msleep(500)
    nLog(monkey.update_topmost_formcontrol(1545874020))  -- 以 Unix 时间戳选择日期时间
    sys.msleep(500)
    nLog(monkey.dismiss_topmost_formcontrol())

    -- 向处于焦点状态的文本框中输入文本内容
    -- 1. `EnterText` 和 `EnterTextById` 与 `Eval` 和 `EvalById` 的用法类似
    -- 2. 文本框必须先模拟点击, 使其处于焦点状态
    -- 3. 此 API 不会完全模拟字符键入的过程, 会直接将内容输入焦点文本框, 但是比 JavaScript 注入更安全
    -- 4. 如果要更真实的, 逐个字符按键并带有随机延迟的模拟输入, 参见 `SimulateTouch` 模块
    nLog("#12-1 测试向焦点文本框输入内容")
    nLog(monkey.input(
        { ["host"] = "www.bing.com" },  -- 匹配表
        "Hello"  -- 待输入的内容
    ))

end


monkey_test()

