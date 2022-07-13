-- Cookies 模块是用于操作 Safari、其他浏览器及应用内 WebView cookie 的模块，可以用来设置、获取、删除 cookie。
-- 以下函数调用都可以在最后指定一个额外的字符串参数，用于指定应用的 Application Identifier，默认为 “com.apple.mobilesafari”。

-- 列出所有的 cookie 列表
list = cookies.list()

-- 过滤出指定的 cookie 列表
list = cookies.filter('/', '.live.com')  -- path, domain
list = cookies.filter {
    Path = '/',
    Domain = '.live.com',
}

-- 获取指定名称的 cookie
tab = cookies.get('MSCC', '/', '.live.com')  -- name, path, domain
tab = cookies.get {
    Name = 'MSCC',
    Path = '/',
    Domain = '.live.com',
}

-- 获取指定名称的 cookie 的值
value = cookies.value('MSCC', '/', '.live.com')
value = cookies.value {
    Name = 'MSCC',
    Path = '/',
    Domain = '.live.com',
}

-- 更新 cookie 列表，列表中同样 name, path 和 domain 的 cookie 会被替换
cookies.update(list)

-- 更新单个 cookie
cookies.update {
    Version = "0",
    Domain = ".login.live.com",
    Expires = "2023-08-04T15:53:05Z",
    Name = "MSCC",
    Path = "/",
    Value = "8.39.126.37-TW",
    Secure = "true",
}

-- 设置 cookie 列表
cookies.replace(list)

-- 删除指定名称的 cookie
cookies.remove('MSCC', '/', '.live.com')
cookies.remove {
    Name = 'MSCC',
    Path = '/',
    Domain = '.live.com',
}

-- 清除所有 cookie
cookies.remove()