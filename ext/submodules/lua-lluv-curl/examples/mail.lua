io.stdout:setvbuf'no';io.stderr:setvbuf'no';
package.path = "../src/lua/?.lua;" .. package.path

-- Require lua-sendmail version > 0.1.4

local uv       = require "lluv"
local curl     = require "lluv.curl"
local sendmail = require "sendmail"

-- Use basic request based on EventEmitter
local function AsyncSendMail(queue, t, cb)
  queue:perform(function(request)
    local response, msg request
    :on('start', function(_,_,handle)
      t.engine = 'curl'
      t.curl = {handle = handle, async = true}

      local ok, err = sendmail(t)

      t.engine, t.curl = nil

      if not ok then return nil, err end
      assert(ok == handle)
      msg = err
    end)
    :on('header', function(_,_,h) response = h end)
    :on('error', function(_, _, err) cb(err) end)
    :on('done', function(_, _, easy)
      local res  = (type(msg.rcpt) == 'table') and #msg.rcpt or 1
      local code = easy:getinfo_response_code()
      cb(nil, res, code, response)
    end)
  end)
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
