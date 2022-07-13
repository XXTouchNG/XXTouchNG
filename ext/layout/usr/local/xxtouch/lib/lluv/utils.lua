------------------------------------------------------------------
--
--  Author: Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Copyright (C) 2014-2017 Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Licensed according to the included 'LICENSE' document
--
--  This file is part of lua-lluv library.
--
------------------------------------------------------------------

local function split(str, sep, plain)
  local b, res = 1, {}
  while b <= #str do
    local e, e2 = string.find(str, sep, b, plain)
    if e then
      res[#res + 1] = string.sub(str, b, e-1)
      b = e2 + 1
    else
      res[#res + 1] = string.sub(str, b)
      break
    end
  end
  return res
end

local unpack = unpack or table.unpack

local function usplit(...) return unpack(split(...)) end

local function split_first(str, sep, plain)
  local e, e2 = string.find(str, sep, nil, plain)
  if e then
    return string.sub(str, 1, e - 1), string.sub(str, e2 + 1)
  end
  return str
end

local function slit_first_self_test()
  local s1, s2 = split_first("ab|cd", "|", true)
  assert(s1 == "ab")
  assert(s2 == "cd")

  local s1, s2 = split_first("|abcd", "|", true)
  assert(s1 == "")
  assert(s2 == "abcd")

  local s1, s2 = split_first("abcd|", "|", true)
  assert(s1 == "abcd")
  assert(s2 == "")

  local s1, s2 = split_first("abcd", "|", true)
  assert(s1 == "abcd")
  assert(s2 == nil)
end

local metamethods = {
  '__call', '__tostring', '__concat', '__len', '__pairs', '__ipairs', '__add', '__sub', '__mul' , '__div', 
  '__pow', '__mod', '__idiv', '__eq', '__lt', '__le', '__band', '__bor', '__bxor', '__bnot', '__bshl', '__bshr'
}

local function class(base, mt_list)
  local t = base and setmetatable({}, base) or {}
  t.__index = t
  t.__class = t
  t.__base  = base

  if mt_list == true then
    mt_list = metamethods
  end

  if mt_list then
    for _, name in ipairs(mt_list) do
      local method = rawget(base, name)
      if method then
        t[name] = method
      end
    end
  end

  function t.new(...)
    local o = setmetatable({}, t)
    if o.__init then
      if t == ... then -- we call as Class:new()
        return o:__init(select(2, ...))
      else             -- we call as Class.new()
        return o:__init(...)
      end
    end
    return o
  end

  return t
end

local function class_self_test()
  local A = class()
  function A:__init(a, b)
    assert(a == 1)
    assert(b == 2)
    return self
  end

  function A:__tostring()
    return 'A::tostring'
  end

  A:new(1, 2)
  A.new(1, 2)

  local B = class(A, true)

  function B:__init(a,b,c)
    assert(self.__base == A)
    assert(c == 3)
    return A.__init(self, a, b)
  end

  B:new(1, 2, 3)
  assert(tostring(B.new(1, 2, 3)) == 'A::tostring')
end

-------------------------------------------------------------------
local Class = {} do

setmetatable(Class, {__call = function(_, ...) return class(...) end})

local function super(class, self, method, ...)
  if class.__base and class.__base[method] then
    return class.__base[method](self, ...)
  end
  if method == '__init' then return self end
end

function Class.super(class)
  return function(...) return super(class, ...) end
end

end
-------------------------------------------------------------------

-------------------------------------------------------------------
local corun do

local uv = require "lluv"

local function spawn(fn, ...)
  coroutine.wrap(fn)(...)
end

local function fiber(...)
  uv.defer(spawn, ...)
end

corun = fiber

end
-------------------------------------------------------------------

-------------------------------------------------------------------
local List = class() do

function List:reset()
  self._first = 0
  self._last  = -1
  self._t     = {}
  return self
end

List.__init = List.reset

function List:push_front(v)
  assert(v ~= nil)
  local first = self._first - 1
  self._first, self._t[first] = first, v
  return self
end

function List:push_back(v)
  assert(v ~= nil)
  local last = self._last + 1
  self._last, self._t[last] = last, v
  return self
end

function List:peek_front()
  return self._t[self._first]
end

function List:peek_back()
  return self._t[self._last]
end

function List:pop_front()
  local first = self._first
  if first > self._last then return end

  local value = self._t[first]
  self._first, self._t[first] = first + 1

  return value
end

function List:pop_back()
  local last = self._last
  if self._first > last then return end

  local value = self._t[last]
  self._last, self._t[last] = last - 1

  return value
end

function List:size()
  return self._last - self._first + 1
end

function List:empty()
  return self._first > self._last
end

function List:find(fn, pos)
  pos = pos or 1
  if type(fn) == "function" then
    for i = self._first + pos - 1, self._last do
      local n = i - self._first + 1
      if fn(self._t[i]) then
        return n, self._t[i]
      end
    end
  else
    for i = self._first + pos - 1, self._last do
      local n = i - self._first + 1
      if fn == self._t[i] then
        return n, self._t[i]
      end
    end
  end
end

function List:remove(pos)
  local s = self:size()

  if pos < 0 then pos = s + pos + 1 end

  if pos <= 0 or pos > s then return end

  local offset = self._first + pos - 1

  local v = self._t[offset]

  if pos < s / 2 then
    for i = offset, self._first, -1 do
      self._t[i] = self._t[i-1]
    end
    self._first = self._first + 1
  else
    for i = offset, self._last do
      self._t[i] = self._t[i+1]
    end
    self._last = self._last - 1
  end

  return v
end

function List:insert(pos, v)
  assert(v ~= nil)

  local s = self:size()

  if pos < 0 then pos = s + pos + 1 end

  if pos <= 0 or pos > (s + 1) then return end

  local offset = self._first + pos - 1

  if pos < s / 2 then
    for i = self._first, offset do
      self._t[i-1] = self._t[i]
    end
    self._t[offset - 1] = v
    self._first = self._first - 1
  else
    for i = self._last, offset, - 1 do
      self._t[i + 1] = self._t[i]
    end
    self._t[offset] = v
    self._last = self._last + 1
  end

  return self
end

function List.self_test()
  local q = List:new()

  assert(q:empty() == true)
  assert(q:size()  == 0)

  assert(q:push_back(1) == q)
  assert(q:empty() == false)
  assert(q:size()  == 1)

  assert(q:peek_back() == 1)
  assert(q:empty() == false)
  assert(q:size()  == 1)

  assert(q:peek_front() == 1)
  assert(q:empty() == false)
  assert(q:size()  == 1)

  assert(q:pop_back() == 1)
  assert(q:empty() == true)
  assert(q:size()  == 0)

  assert(q:push_front(1) == q)
  assert(q:empty() == false)
  assert(q:size()  == 1)

  assert(q:pop_front() == 1)
  assert(q:empty() == true)
  assert(q:size()  == 0)

  assert(q:pop_back() == nil)
  assert(q:empty() == true)
  assert(q:size()  == 0)

  assert(q:pop_front() == nil)
  assert(q:empty() == true)
  assert(q:size()  == 0)

  assert(false == pcall(q.push_back, q))
  assert(q:empty() == true)
  assert(q:size()  == 0)

  assert(false == pcall(q.push_front, q))
  assert(q:empty() == true)
  assert(q:size()  == 0)

  q:push_back(1):push_back(2)
  assert(q:pop_back() == 2)
  assert(q:pop_back() == 1)

  q:push_back(1):push_back(2)
  assert(q:pop_front() == 1)
  assert(q:pop_front() == 2)

  q:reset()
  assert(nil == q:find(1))
  q:push_back(1):push_back(2):push_front(3)
  assert(1 == q:find(3))
  assert(2 == q:find(1))
  assert(3 == q:find(2))
  assert(nil == q:find(4))
  assert(2 == q:find(1, 2))
  assert(nil == q:find(1, 3))

  q:reset() :push_back('a') :push_back('b') :push_back('c') :push_back('d')
  assert('b' == q:remove(2))
  assert('a' == q:pop_front())
  assert('c' == q:pop_front())
  assert('d' == q:pop_front())
  assert(nil == q:pop_front())

  q:reset() :push_front('a') :push_front('b') :push_front('c') :push_front('d')
  assert('b' == q:remove(3))
  assert('a' == q:pop_back())
  assert('c' == q:pop_back())
  assert('d' == q:pop_back())
  assert(nil == q:pop_back())

  q:reset() :push_back('a') :push_back('b') :push_back('c') :push_back('d')
  assert('b' == q:remove(-3))
  assert('a' == q:pop_front())
  assert('c' == q:pop_front())
  assert('d' == q:pop_front())
  assert(nil == q:pop_front())

  q:reset() :push_front('a') :push_front('b') :push_front('c') :push_front('d')
  assert('b' == q:remove(-2))
  assert('a' == q:pop_back())
  assert('c' == q:pop_back())
  assert('d' == q:pop_back())
  assert(nil == q:pop_back())

  q:reset() :push_front('a') :push_front('b') :push_front('c') :push_front('d')
  assert(nil == q:remove(0))
  assert(nil == q:remove(q:size() + 1))
  assert(nil == q:remove(-q:size() - 1))
  assert('a' == q:pop_back())
  assert('b' == q:pop_back())
  assert('c' == q:pop_back())
  assert('d' == q:pop_back())

  q:reset() :push_front('a') :push_front('b') :push_front('c') :push_front('d')
  assert('a' == q:remove(-1))
  assert('d' == q:remove(1))

  q:reset() :push_front('a')
  assert(q == q:insert(1, 'b'))
  assert('a' == q:pop_back())
  assert('b' == q:pop_back())

  q:reset() :push_back('a') :push_back('b') :push_back('c')
  assert(q == q:insert(-1, '$'))
  assert('a' == q:pop_front())
  assert('b' == q:pop_front())
  assert('$' == q:pop_front())
  assert('c' == q:pop_front())
end

end
-------------------------------------------------------------------

-------------------------------------------------------------------
local Queue = class() do

function Queue:__init()
  self._q = List.new()
  return self
end

function Queue:reset()        self._q:reset()      return self end

function Queue:push(v)        self._q:push_back(v) return self end

function Queue:pop()   return self._q:pop_front()              end

function Queue:peek()  return self._q:peek_front()             end

function Queue:size()  return self._q:size()                   end

function Queue:empty() return self._q:empty()                  end

end
-------------------------------------------------------------------

-------------------------------------------------------------------
local Buffer = class() do

-- eol should ends with specific char.
-- `\r*\n` is valid, but `\r\n?` is not.

-- leave separator as part of first string
local function split_first_eol(str, sep, plain)
  local e, e2 = string.find(str, sep, nil, plain)
  if e then
    return string.sub(str, 1, e2), string.sub(str, e2 + 1), 0
  end
  return str
end

-- returns separator length as third return value
local function split_first_ex(str, sep, plain)
  local e, e2 = string.find(str, sep, nil, plain)
  if e then
    return string.sub(str, 1, e - 1), string.sub(str, e2 + 1), e2 - e + 1
  end
  return str
end

function Buffer:__init(eol, eol_is_rex)
  self._lst       = List.new()
  self._size      = 0
  self:set_eol(eol or '\n', eol_is_rex)
  return self
end

function Buffer:reset()
  self._lst:reset()
  self._size = 0
  return self
end

function Buffer:eol()
  return self._eol, self._eol_plain
end

function Buffer:set_eol(eol, eol_is_rex)
  self._eol       = assert(eol)
  self._eol_plain = not eol_is_rex
  self._eol_char  = self._eol:sub(-1)
  local ch = self._eol_char
  self._eol_check = function(s) return not not string.find(s, ch, nil, true) end
  return self
end

function Buffer:append(data)
  if #data > 0 then
    self._lst:push_back(data)
    self._size = self._size + #data
  end
  return self
end

function Buffer:prepend(data)
  if #data > 0 then
    self._lst:push_front(data)
    self._size = self._size + #data
  end
  return self
end

local function read_line(self, split_line, eol, eol_is_rex)
  local plain

  local ch, check
  if eol then
    plain = not eol_is_rex
    ch    = eol:sub(-1)
    check = function(s) return not not string.find(s, ch, nil, true) end
  else
    eol   = self._eol
    plain = self._eol_plain
    ch    = self._eol_char
    check = self._eol_check
  end

  local lst = self._lst

  local t = {}
  while true do
    local i = self._lst:find(check)

    if not i then
      if #t > 0 then lst:push_front(table.concat(t)) end
      return
    end

    assert(i > 0)

    for i = i, 1, -1 do t[#t + 1] = lst:pop_front() end

    local line, tail, eol_len

    -- try find EOL in last chunk
    if plain or (eol == ch) then
      line, tail, eol_len = split_line(t[#t], eol, true)
    end

    if eol == ch then assert(tail) end

    if tail then -- we found EOL
      -- we can split just last chunk and concat
      t[#t] = line

      if #tail > 0 then
        lst:push_front(tail)
      end

      line = table.concat(t)
      self._size = self._size - (#line + eol_len)

      return line
    end

    -- we need concat whole string and then split
    -- for eol like `\r\n` this may not work well but for most cases it should work well
    -- e.g. for LuaSockets pattern `\r*\n` it work with one iteration but still we need
    -- concat->split because of case such {"aaa\r", "\n"}

    line, tail, eol_len = split_line(table.concat(t), eol, plain)

    if tail then -- we found EOL
      if #tail > 0 then lst:push_front(tail) end
      self._size = self._size - (#line + eol_len)
      return line
    end

    t[1] = line
    for i = 2, #t do t[i] = nil end
  end
end

function Buffer:read_line(eol, eol_is_rex)
  return read_line(self, split_first_ex, eol, eol_is_rex)
end

function Buffer:read_line_eol(eol, eol_is_rex)
  return read_line(self, split_first_eol, eol, eol_is_rex)
end

function Buffer:read_all()
  local t = {}
  local lst = self._lst
  while not lst:empty() do
    t[#t + 1] = self._lst:pop_front()
  end
  self._size = 0
  return table.concat(t)
end

function Buffer:read_some()
  if self._lst:empty() then return end
  local chunk = self._lst:pop_front()
  if chunk then self._size = self._size - #chunk end
  return chunk
end

function Buffer:read_n(n)
  n = math.floor(n)

  if n == 0 then
    if self._lst:empty() then return end
    return ""
  end

  if self._size < n then
    return
  end

  local lst = self._lst
  local size, t = 0, {}

  while true do
    local chunk = lst:pop_front()

    if (size + #chunk) >= n then
      assert(n > size)
      local pos = n - size
      local data = string.sub(chunk, 1, pos)
      if pos < #chunk then
        lst:push_front(string.sub(chunk, pos + 1))
      end

      t[#t + 1] = data

      self._size = self._size - n

      return table.concat(t)
    end

    t[#t + 1] = chunk
    size = size + #chunk
  end
end

function Buffer:read(pat, ...)
  if not pat then return self:read_some() end

  if pat == "*l" then return self:read_line(...) end

  if pat == "*L" then return self:read_line_eol(...) end

  if pat == "*a" then return self:read_all() end

  return self:read_n(pat)
end

function Buffer:empty()
  return self._lst:empty()
end

function Buffer:size()
  return self._size
end

function Buffer:next_line(data, eol)
  if data then self:append(data) end
  if eol then
    return self:read_line(eol, true)
  end
  return self:read_line()
end

function Buffer:next_n(data, n)
  if data then self:append(data) end
  return self:read_n(n)
end

function Buffer:_validate_internal_state()
  local size = 0
  self._lst:find(function(s) size = size + #s end)
  assert(size == self._size, string.format('expected size %d got %d', self._size, size))
end

function Buffer.self_test(EOL)

  local b = Buffer.new("\r\n")

  b:append("a")         b:_validate_internal_state()
  b:append("\n")        b:_validate_internal_state()
  b:append("\n")        b:_validate_internal_state()
  b:append("\r")        b:_validate_internal_state()
  b:append("\n123")     b:_validate_internal_state()
  assert('a\n\n' == b:read_line())

  b:_validate_internal_state()

  local b = Buffer.new("\r\n")

  b:append("a")         b:_validate_internal_state()
  b:append("\n")        b:_validate_internal_state()
  b:append("\n")        b:_validate_internal_state()
  b:append("\r")        b:_validate_internal_state()
  b:append("\n123")     b:_validate_internal_state()
  assert('a\n\n\r\n' == b:read_line_eol())

  b:_validate_internal_state()

  local b = Buffer.new("\r\n")

  b:append("a\r")        b:_validate_internal_state()
  b:append("\nb")        b:_validate_internal_state()
  b:append("\r\n")       b:_validate_internal_state()
  b:append("c\r\nd\r\n") b:_validate_internal_state()

  assert("a" == b:read_line())
  b:_validate_internal_state()
  assert("b" == b:read_line())
  b:_validate_internal_state()
  assert("c" == b:read_line())
  b:_validate_internal_state()
  assert("d" == b:read_line())
  b:_validate_internal_state()

  local b = Buffer.new("\r\n")

  b:append("a\r")        b:_validate_internal_state()
  b:append("\nb")        b:_validate_internal_state()
  b:append("\r\n")       b:_validate_internal_state()
  b:append("c\r\nd\r\n") b:_validate_internal_state()
  b:append("\r\n\r\n")   b:_validate_internal_state()

  assert("a\r\n" == b:read_line_eol())
  b:_validate_internal_state()
  assert("b\r\n" == b:read_line_eol())
  b:_validate_internal_state()
  assert("c\r\n" == b:read_line_eol())
  b:_validate_internal_state()
  assert("d\r\n" == b:read_line_eol())
  b:_validate_internal_state()
  assert("\r\n" == b:read_line_eol())
  b:_validate_internal_state()
  assert("\r\n" == b:read_line_eol())
  b:_validate_internal_state()
  assert(nil == b:read_line_eol())
  b:_validate_internal_state()

  local b = Buffer:new(EOL)
  local eol = b:eol()

  -- test next_xxx
  assert("aaa" == b:next_line("aaa" .. eol .. "bbb"))
  b:_validate_internal_state()

  assert("bbbccc" == b:next_line("ccc" .. eol .. "ddd" .. eol))
  b:_validate_internal_state()

  assert("ddd" == b:next_line(eol))
  b:_validate_internal_state()

  assert("" == b:next_line(""))
  b:_validate_internal_state()

  assert(nil == b:next_line(""))
  b:_validate_internal_state()

  assert(nil == b:next_line("aaa"))
  b:_validate_internal_state()

  assert("aaa1" == b:next_n("1123456", 4))
  b:_validate_internal_state()

  assert(nil == b:next_n("", 8))
  b:_validate_internal_state()

  assert("123"== b:next_n("", 3))
  b:_validate_internal_state()

  assert("456" == b:next_n(nil, 3))
  b:_validate_internal_state()

  b:reset()
  b:_validate_internal_state()

  assert(nil == b:next_line("aaa|bbb"))
  b:_validate_internal_state()

  assert("aaa" == b:next_line(nil, "|"))
  b:_validate_internal_state()

  b:reset()
  b:_validate_internal_state()

  b:set_eol("\r*\n", true)
   :append("aaa\r\r\n\r\nbbb\nccc")
  b:_validate_internal_state()
  assert("aaa" == b:read_line())
  b:_validate_internal_state()
  assert("" == b:read_line())
  b:_validate_internal_state()
  assert("bbb" == b:read_line())
  b:_validate_internal_state()
  assert(nil == b:read_line())
  b:_validate_internal_state()

  b:reset()
  b:_validate_internal_state()
  b:append("aaa\r\r")
  b:_validate_internal_state()
  b:append("\r\r")
  b:_validate_internal_state()
  assert(nil == b:read_line())
  b:_validate_internal_state()
  b:append("\nbbb\n")
  b:_validate_internal_state()
  assert("aaa" == b:read_line())
  b:_validate_internal_state()
  assert("bbb" == b:read_line())
  b:_validate_internal_state()

  b:reset()
  b:_validate_internal_state()
  b:set_eol("\n\0")

  b:append("aaa")
  assert(nil == b:read_line())
  b:append("\n")
  assert(nil == b:read_line())
  b:append("\0")
  assert("aaa" == b:read_line())

  b:reset()
  b:append('aaa\r\r')
  assert(nil == b:read_line('\r+\n', true))
  b:append('\r')
  assert(nil == b:read_line('\r+\n', true))
  b:append('\nbbb\r\n')
  assert('aaa' == b:read_line('\r+\n', true))
  assert('bbb' == b:read_line('\r+\n', true))

  b:reset()

  b = Buffer.new('\r*\n', true)
  b:append('aaa\r\r\n')
  assert('aaa' == b:read_line())
end

end
-------------------------------------------------------------------

-------------------------------------------------------------------
local DeferQueue = class() do

local va, uv

function DeferQueue:__init()
  va = va or require "vararg"
  uv = uv or require "lluv"

  self._cb = function()
    self:_on_tick()
    if self._queue:empty() then self:_stop() else self:_start() end
  end

  self._queue = Queue.new()
  self._timer = uv.timer():start(0, 1, self._cb):stop()
  return self
end

function DeferQueue:_start()
  self._timer:again()
end

function DeferQueue:_stop()
  self._timer:stop()
end

function DeferQueue:_on_tick()
  -- callback could register new function
  -- so we proceed only currently active
  -- and leave new one to next iteration
  for i = 1, self._queue:size() do
    local args = self._queue:pop()
    if not args then break end
    args(1, 1)(args(2))
  end
end

function DeferQueue:call(...)
  self._queue:push(va(...))
  if self._queue:size() == 1 then
    self:_start()
  end
end

function DeferQueue:close(call)
  if not self._queue then return end

  if call then self._on_tick() end

  self._prepare:close()
  -- self._timer:close()
  self._queue, self._timer, self._prepare = nil
end

function DeferQueue.self_test()

  local dq = DeferQueue.new()
  assert(dq)
  assert(uv)
  assert(va)
  
  local f = 0
  local increment = function() f = f + 1 end

  dq:call(increment)
  assert(f == 0)
  assert(0 == uv.run())
  assert(f == 1)

  dq:call(function()
    increment()
    dq:call(increment)
    assert(f == 2)
  end)
  assert(0 == uv.run())
  assert(f == 3)
end


end
-------------------------------------------------------------------

-------------------------------------------------------------------
local MakeErrors = function(cat, errors)
  assert(type(cat)    == "string")
  assert(type(errors) == "table")

  local numbers  = {} -- errno => name
  local names    = {} -- name  => errno
  local messages = {}

  for no, info in pairs(errors) do
    assert(type(info) == "table")
    local name, msg = next(info)

    assert(type(no)   == "number")
    assert(type(name) == "string")
    assert(type(msg)  == "string")
    
    assert(not numbers[no], no)
    assert(not names[name], name)
    
    numbers[no]    = name
    names[name]    = no
    messages[no]   = msg
    messages[name] = msg
  end

  local Error = class() do

  function Error:__init(no, ext)
    assert(numbers[no] or names[no], "unknown error: " ..  tostring(no))

    self._no = names[no] or no
    self._ext = ext

    return self
  end

  function Error:cat()
    return cat
  end

  function Error:name()
    return numbers[self._no]
  end

  function Error:no()
    return self._no
  end

  function Error:msg()
    return messages[self._no]
  end

  function Error:ext()
    return self._ext
  end

  function Error:__tostring()
    local msg = string.format("[%s][%s] %s (%d)", self:cat(), self:name(), self:msg(), self:no())
    local ext = self:ext()
    if ext then msg = msg .. " - " .. ext end
    return msg
  end

  end

  local o = setmetatable({
    __class = Error
  }, {__call = function(self, ...)
    return Error:new(...)
  end})

  for name, no in pairs(names) do
    o[name] = no
  end

  return o
end
-------------------------------------------------------------------

local function self_test()
  Buffer.self_test()
  List.self_test()
  DeferQueue.self_test()
  slit_first_self_test()
  class_self_test()
end

return {
  Buffer      = Buffer;
  Queue       = Queue;
  List        = List;
  Errors      = MakeErrors;
  DeferQueue  = DeferQueue;
  class       = Class;
  split_first = split_first;
  split       = split;
  usplit      = usplit;
  corun       = corun;
  self_test   = self_test;
}
