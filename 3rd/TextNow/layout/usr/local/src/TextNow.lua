require "TSLib"
local ts = require("ts")
local json = ts.json

local TextNow = require("TextNow")

-- 获取手机号码
local accountInfo = TextNow.GetAccountInfo()
dialog(json.encode(accountInfo))

-- 获取会话列表
local conversations = TextNow.GetConversations()
log(json.encode(conversations))

-- 进入第一条会话
for var=1,#conversations do
    if conversations[var]["displayString"] == "729725" then
        TextNow.EnterConversation(conversations[var]["objectIdentifier"])
    end
end

-- 获取消息列表
local messages = TextNow.GetMessages()["fetchedMessages"]
if #messages > 0 then
    local latestMessage = messages[1]
    dialog(latestMessage["content"] .. "\n" .. "Guessed Code: " .. latestMessage["guessedCode"])
end

-- 退出会话
TextNow.ExitConversation()

