io.stdout:setvbuf'no';io.stderr:setvbuf'no';
package.path = "../src/lua/?.lua;" .. package.path

-- Require lua-sendmail version > 0.1.4

local uv       = require "lluv"
local ut       = require "lluv.utils"
local curl     = require "lluv.curl"
local sendmail = require "sendmail"

-- Implement special Request class to send email
local EmailRequest = ut.class() do

function EmailRequest:__init(opt, cb)
  self._opt = opt
  self._cb  = cb or function() end
  self._msg = nil

  self._opt.engine = 'curl'
  self._opt.curl   = {async = true}

  return self
end

function EmailRequest:start(handle)
  self._opt.curl.handle = handle

  local ok, err = sendmail(self._opt)
  if not ok then return nil, err end

  self._msg = err

  handle:setopt_headerfunction(function(h) self._response = h end)

  return self
end

function EmailRequest:close(err, handle)
  if (not err) and (not handle) then
    err = 'interrupted'
  end

  if err then return self._cb(err) end

  local res  = (type(self._msg.rcpt) == 'table') and #self._msg.rcpt or 1
  local code = handle:getinfo_response_code()
  self._cb(nil, res, code, self._response)
end

end

local function AsyncSendMail(queue, t, cb)
  local request = EmailRequest.new(t, cb)
  queue:add(request)
end

local queue = curl.queue{
  concurent = 10;
  defaults  = {};
}

AsyncSendMail(queue, {
  server = {
    address  = "smtp.super.server";
    user     = "moteus@domain.name";
    password = "sicret";
    ssl      = {
      protocol = 'tlsv1_2';
      verify = {'peer'};
    };
  },

  from = {
    title    = "Alexey";
    address  = "moteus@domain.name";
  },

  to = {
    title    = "Somebody";
    address  = "somebody@domain.name";
  },

  message = {
    subject = {
      title = "Hello";
    };
    text = "Hello from me";
    file = {
      name = "file.txt";
      data = "hello hello hello hello hello";
    }
  },
}, function(err, res, code)
  if err then
    io.stderr:write('FAIL: ' .. tostring(err) .. '\n')
  else
    io.stdout:write('DONE: ' .. tostring(res) .. '; Code: ' .. code .. '\n')
  end
end)

uv.run()
