------------------------------------------------------------------
--
--  Author: Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Copyright (C) 2015 Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Licensed according to the included 'LICENSE' document
--
--  This file is part of lua-lluv-websocket library.
--
------------------------------------------------------------------

local ut       = require "lluv.utils"
local validate = require "lluv.websocket.utf8_validator".validate

local Utf8Validator = ut.class() do

function Utf8Validator:__init()
  return self:reset()
end

function Utf8Validator:reset()
  self._tail = ''
  return self
end

function Utf8Validator:next(str, last)
  str = self._tail .. str
  local ok, pos = validate(str)
  if ok then self._tail = ''
  else self._tail = string.sub(str, pos) end

  if last then return self._tail == '' end

  return #self._tail < 4
end

function Utf8Validator:validate(str)
  return validate(str)
end

end

return {
  validator = Utf8Validator.new
}
