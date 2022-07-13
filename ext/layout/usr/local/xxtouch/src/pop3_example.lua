local pop3 = require "pop3"

local some_mail = {
  host     = os.getenv("LUA_MAIL_HOST") or '127.0.0.1';
  username = os.getenv("LUA_MAIL_USER") or 'me@host.local';
  password = os.getenv("LUA_MAIL_PASS") or 'mypassword';
}

local function print_msg(msg, indent)
  indent = indent or ''
  print(indent .. "----------------------------------------------")
  print(indent .. "ID:         ", msg:id())
  print(indent .. "subject:    ", msg:subject())
  print(indent .. "to:         ", msg:to())
  print(indent .. "from:       ", msg:from())
  print(indent .. "from addr:  ", msg:from_address())
  print(indent .. "reply:      ", msg:reply_to())
  print(indent .. "reply addr: ", msg:reply_address())
  print(indent .. "trunc:      ", msg:is_truncated())
  for i,v in ipairs(msg:full_content()) do
    if v.text        then  print(indent .. "  ", i , "TEXT  : ", v.type, #v.text)
    elseif v.data    then  print(indent .. "  ", i , "FILE  : ", v.type, v.disposition, v.file_name or v.name, #v.data)
    elseif v.message then  print(indent .. "  ", i , "RFC822: ", v.type, v.disposition, v.file_name or v.name)
      print_msg(v.message, indent .. '\t\t\t')
    end
  end
end

local mbox = pop3.new()

mbox:open(some_mail.host, some_mail.port or '110')
print('open   :', mbox:is_open())

mbox:auth(some_mail.username, some_mail.password)
print('auth   :', mbox:is_auth())

for k, msg in mbox:messages() do
  print(string.format("   *** MESSAGE NO %d ***", k))
  print_msg(msg)
end

