io.stdout:setvbuf'no';io.stderr:setvbuf'no';
package.path = "../src/lua/?.lua;" .. package.path

local uv   = require "lluv"
local curl = require "lluv.curl"

local easy = curl.easy{
  url = "http://example.com";
  writefunction = io.write;
}

local multi = curl.multi()

multi:add_handle(easy, function(easy, err)
  print("--------------------------------")
  print("Done:", err or easy:getinfo_response_code())
end)

uv.run()
