-- 该模块用于以模拟方式登录 App Store

-- 获取 App Store 已登录的用户
account = appstore.account()

-- 登出注销 App Store
appstore.logout()

-- 模拟登录 App Store
-- 这一过程耗时较长，可能要求进行二步验证
succeed, err = appstore.login('russell@icloud.com', '123456')
