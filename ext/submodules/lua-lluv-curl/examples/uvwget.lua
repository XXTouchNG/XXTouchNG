io.stdout:setvbuf'no';io.stderr:setvbuf'no';
package.path = "../src/lua/?.lua;" .. package.path

local uv           = require "lluv"
local curl         = require "lluv.curl"

-- need at least one new url
if not arg[1] then
  io.stdout:write('no url provided')
  os.exit(-1)
end

local queue = curl.queue{
  concurent = 10;
}

for i, url in ipairs(arg) do
  local path, file = tostring(i) .. '.download'
  queue:perform(url, {followlocation = true}, function(request) request
    :on('start', function(_, _, easy)
      file = assert(io.open(path, 'wb+'))
      easy:setopt_writefunction(file)
    end)
    :on('close', function()
      if file then file:close() end
    end)
    :on('error', function(_, _, err)
      io.stderr:write(url ..  ' - FAIL: ' .. tostring(err) .. '\n')
    end)
    :on('done', function(_, _, easy)
      local code = easy:getinfo_response_code()
      io.stdout:write(url ..  ' - DONE: ' .. tostring(code) .. '; Path: ' ..path .. '\n')
    end)
  end)
end

uv.run()
