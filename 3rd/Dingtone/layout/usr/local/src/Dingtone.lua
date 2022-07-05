local Dingtone = require("Dingtone")

-- 测试
nLog(Dingtone.Hello({}))

-- 获取订阅的第一个手机号码（停留在号码页才能调用）
nLog(Dingtone.GetAccountInfo()[1]["phoneNumber"])

-- 获取会话列表（停留在会话列表才能调用）
local conversations = Dingtone.GetConversations()
nLog(conversations)

-- 进入第一条发送方名称为 729725 的会话
for var=1,#conversations do
    if conversations[var]["displayString"] == "729725" then
        Dingtone.EnterConversation(conversations[var]["objectIdentifier"])
    end
end

-- 获取消息列表
sys.msleep(1000)
local messages = Dingtone.GetMessages()["fetchedMessages"]
nLog(messages)
if #messages > 0 then
    local latestMessage = messages[1]
    nLog(latestMessage["content"] .. "\n" .. "Guessed Code: " .. latestMessage["guessedCode"])
end


-- 退出会话
sys.msleep(3000)
nLog(Dingtone.ExitConversation())
