local ut = require 'lluv.utils'

------------------------------------------------------------------
local WSError = ut.class() do

local ERRORS = {
  [-1] = "EHANDSHAKE";
  [-2] = "EOF";
  [-3] = "ESTATE";
  [-4] = "ENOSUP";
  [-5] = "EOVERFLOW";
}

for k, v in pairs(ERRORS) do WSError[v] = k end

function WSError:__init(no, name, msg, ext, code, reason)
  self._no     = assert(no)
  self._name   = assert(name or ERRORS[no])
  self._msg    = msg    or ''
  self._ext    = ext    or ''
  self._code   = code   or 1000
  self._reason = reason or ''
  return self
end

function WSError:cat()    return 'WEBSOCKET'  end

function WSError:no()     return self._no     end

function WSError:name()   return self._name   end

function WSError:msg()    return self._msg    end

function WSError:ext()    return self._ext    end

function WSError:code()   return self._code and tostring(self._code) end

function WSError:reason() return self._reason end

function WSError:__tostring()
  return string.format("[%s][%s] %s (%d) - %s %s(%s)",
    self:cat(), self:name(), self:msg(), self:no(), self:ext(),
    self:code(), self:reason()
  )
end

function WSError:__eq(rhs)
  return self._no == rhs._no
end

end
------------------------------------------------------------------

local function WSError_handshake_faild(msg)
  return WSError.new(WSError.EHANDSHAKE, nil, "Handshake failed", msg)
end

local function WSError_EOF(code, reason)
  return WSError.new(WSError.EOF, nil, "end of file", code, reason)
end

local function WSError_ESTATE(msg)
  return WSError.new(WSError.ESTATE, nil, msg)
end

local function WSError_ENOSUP(msg)
  return WSError.new(WSError.ENOSUP, nil, msg)
end

local function WSError_EOVERFLOW(msg)
  return WSError.new(WSError.EOVERFLOW, nil, msg, 1011, 'internal error')
end

return setmetatable({
  raise_handshake_faild = WSError_handshake_faild;
  raise_EOF             = WSError_EOF;
  raise_ESTATE          = WSError_ESTATE;
  raise_ENOSUP          = WSError_ENOSUP;
  raise_EOVERFLOW       = WSError_EOVERFLOW;
}, {__index = WSError})
