local uv        = require "lluv"
local ut        = require "lluv.utils"
local ssl       = require "lluv.ssl"
local socket    = require "lluv.ssl.luasocket"
local sendmail  = require "sendmail"

ut.corun(function() print(sendmail{
  server = {
    address  = "localhost"; port = 465;
    user     = "moteus@test.localhost.com";
    password = "123456";
    ssl      = ssl.context{...};
    create   = socket.ssl;
  },

  from = {
    title    = "Test";
    address  = "moteus@test.localhost.com";
  },

  to = {
    address = {"alexey@test.localhost.com"}
  },

  message = {"CoSocket message"}
}) end)

uv.run()
