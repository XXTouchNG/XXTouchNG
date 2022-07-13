------------------------------------------------------------------
--
--  Author: Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Copyright (C) 2017-2019 Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Licensed according to the included 'LICENSE' document
--
--  This file is part of lua-lluv-curl library.
--
------------------------------------------------------------------

local curl         = require "cURL.safe"
local uv           = require "lluv"
local ut           = require "lluv.utils"
local EventEmitter = require "EventEmitter".EventEmitter

local _VERSION   = "0.1.2"
local _NAME      = "lluv-curl"
local _LICENSE   = "MIT"
local _COPYRIGHT = "Copyright (c) 2017-2019 Alexey Melnichuk"

local function super(class, self, method, ...)
  if class.__base and class.__base[method] then
    return class.__base[method](self, ...)
  end
  if method == '__init' then return self end
end

local function Super(class)
  return function(...) return super(class, ...) end
end

local function bind(self, fn)
  return function(...) return fn(self, ...) end
end

local function hash_id(str)
  local id = string.match(str, "%((.-)%)") or string.match(str, ': (%x+)$')
  return id
end

local function weak_ptr(val)
  return setmetatable({value = val},{__mode = 'v'})
end

local ACTION_NAMES = {
  [curl.POLL_IN     ] = "POLL_IN";
  [curl.POLL_INOUT  ] = "POLL_INOUT";
  [curl.POLL_OUT    ] = "POLL_OUT";
  [curl.POLL_NONE   ] = "POLL_NONE";
  [curl.POLL_REMOVE ] = "POLL_REMOVE";
}

local POLL_IO_FLAGS = {
  [ curl.POLL_IN    ] = uv.READABLE;
  [ curl.POLL_OUT   ] = uv.WRITABLE;
  [ curl.POLL_INOUT ] = uv.READABLE + uv.WRITABLE;
}

local EVENT_NAMES = {
  [ uv.READABLE               ] = "READABLE";
  [ uv.WRITABLE               ] = "WRITABLE";
  [ uv.READABLE + uv.WRITABLE ] = "READABLE + WRITABLE";
}

local FLAGS = {
  [ uv.READABLE               ] = curl.CSELECT_IN;
  [ uv.WRITABLE               ] = curl.CSELECT_OUT;
  [ uv.READABLE + uv.WRITABLE ] = curl.CSELECT_IN + curl.CSELECT_OUT;
}

local ECANCELED = uv.error(uv.ERROR_UV, uv.ECANCELED)

-------------------------------------------------------------------
local List = ut.class() do

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

end
-------------------------------------------------------------------

-------------------------------------------------------------------
local Queue = ut.class() do

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

function Queue:exists(v)
  return self._q:find(v)
end

function Queue:remove_value(v)
  local i = self._q:find(v)
  if i then return self._q:remove(i) end
end

end
-------------------------------------------------------------------

-------------------------------------------------------------------
local BasicRequest = ut.class(EventEmitter) do
local super = Super(BasicRequest)

function BasicRequest:__init(url, opt)
  super(self, '__init')

  self._url = url
  self._opt = opt

  return self
end

function BasicRequest:write(...)
  self:emit('data', ...)
  return true
end

function BasicRequest:header(...)
  self:emit('header', ...)
  return true
end

function BasicRequest:start(handle)
  local ok, err = handle:setopt{
    url            = self._url;
    writefunction  = self;
    headerfunction = self;
  }
  if not ok then return nil, err end

  if self._opt then
    local ok, err = handle:setopt(self._opt)
    if not ok then return nil, err end
  end

  self:emit('start', handle)

  return true
end

function BasicRequest:close(err, handle)
  if err then
    self:emit('error', err)
  elseif not handle then
    self:emit('error', 'interrupted')
  else
    self:emit('done', handle)
  end
  self:emit('close')
end

end
-------------------------------------------------------------------

-------------------------------------------------------------------
local Context = ut.class() do

function Context:__init(fd)
  self._fd        = assert(fd)
  self._poll      = uv.poll_socket(fd)
  self._poll.data = self

  assert(self._poll:fileno() == fd)

  return self
end

function Context:close()
  if self._poll then
    self._poll.data = nil
    self._poll:close()
  end
  self._poll, self._fd = nil
end

function Context:poll(...)
  self._poll:start(...)
end

function Context:fileno()
  return self._fd
end

end
-------------------------------------------------------------------

-------------------------------------------------------------------
local cUrlRequestsQueue = ut.class(EventEmitter) do
local super = Super(cUrlRequestsQueue)

function cUrlRequestsQueue:__init(options)
  super(self, '__init', {wildcard = true, delimiter = '::'})

  options = options or {}

  self._MAX_REQUESTS  = options.concurent or 1 -- Number of parallel request
  self._timer         = uv.timer()
  self._qtask         = Queue.new()            -- wait tasks
  self._qfree         = ut.Queue.new()         -- avaliable easy handles
  self._qeasy         = {}                     -- all easy handles
  self._easy_defaults = options.defaults or {  -- default options for easy handles
    fresh_connect = true;
    forbid_reuse  = true;
  }

  self._multi = curl.multi()
  self._multi:setopt_timerfunction (self._on_curl_timeout, self)

  if not pcall(
    self._multi.setopt_socketfunction, self._multi, self._on_curl_action,  self
  )then
    -- bug in Lua-cURL <= v0.3.5
    self._multi:setopt{ socketfunction = bind(self, self._on_curl_action) }
  end

  self._on_libuv_poll_proxy    = bind(self, self._on_libuv_poll)
  self._on_libuv_timeout_proxy = bind(self, self._on_libuv_timeout)

  return self
end

function cUrlRequestsQueue:close(err)
  for i, easy in ipairs(self._qeasy) do
    self._multi:remove_handle(easy)

    if easy.data then
      local context = easy.data.context
      if context then context:close() end

      local task = easy.data.task
      if task then task:close(err, easy) end
    end

    easy:close()
  end

  while true do
    local task = self._qtask:pop()
    if not task then break end
    task:close(err)
  end

  self._multi:close()
  self._timer:close()

  self._timer, self._qeasy, self._multi, self._qtask, self._qfree = nil

  self:emit('close')
end

function cUrlRequestsQueue:add(task)
  self._qtask:push(task)

  self:emit('enqueue', task)

  self:_proceed_queue()
  return task
end

function cUrlRequestsQueue:perform(url, opt, cb)
  local task
  if type(url) == 'string' then
    task = BasicRequest.new(url, (type(opt) == 'table') and opt)
    cb = (type(opt) == 'function') and opt or cb
    if cb then cb(task) end
  elseif type(url) == 'function' then
    task = BasicRequest.new()
    url(task)
  else
    task = url
  end

  return self:add(task)
end

function cUrlRequestsQueue:cancel(task, err)
  err = err or ECANCELED

  -- check either task is started
  for i, easy in ipairs(self._qeasy) do
    if easy.data and easy.data.task == task then
      self._multi:remove_handle(easy)

      local context = easy.data.context
      if context then context:close() end
      easy.data.context = nil

      task:close(err, easy)
      easy:reset()
      easy.data = nil

      self._qfree:push(easy)
      self:_proceed_queue()
      return
    end
  end

  -- remove unstarted task
  local t = self._qtask:remove_value(task)
  if t then
    assert(t == task)
    t:close(err)
  end
end

function cUrlRequestsQueue:_next_handle()
  if not self._qfree:empty() then
    return assert(self._qfree:pop())
  end

  if #self._qeasy >= self._MAX_REQUESTS then
    return
  end

  local handle = assert(curl.easy())
  self._qeasy[#self._qeasy + 1] = handle

  return handle
end

function cUrlRequestsQueue:_proceed_queue()
  while not self._qtask:empty() do
    local handle = self:_next_handle()
    if not handle then return end
    local task = assert(self._qtask:pop())

    self:emit('dequeue', task)

    local ok, res, err = handle:setopt( self._easy_defaults )
    if ok then
      ok, res, err = pcall(task.start, task, handle)
    end

    if not (ok and res) then
      handle:reset()
      handle.data = nil
      self._qfree:push(handle)
      if not ok then err = res end
      task:close(err)
    else
      handle.data = {
        task = task
      }
      self._multi:add_handle(handle)
    end
  end
end

function cUrlRequestsQueue:_on_curl_timeout(ms)
  self:emit("curl::timeout", ms)

  -- If libcurl gets called before the timeout expiry time 
  -- because of socket activity, it may very well update the 
  -- timeout value again before it expires

  if ms <= 0 then ms = 1 end

  self._timer:start(ms, 0, self._on_libuv_timeout_proxy)
end

local function on_curl_action(self, easy, fd, action)
  self:emit("curl::socket", easy, fd, ACTION_NAMES[action] or action)

  local context = easy.data.context

  local flag = POLL_IO_FLAGS[action]
  if flag then
    if not context then
      context = Context.new(fd)
      easy.data.context = context
    end
    context:poll(flag, self._on_libuv_poll_proxy)
  elseif action == curl.POLL_REMOVE then
    if context then
      easy.data.context = nil
      context:close()
    end
  end
end

function cUrlRequestsQueue:_on_curl_action(easy, fd, action)
  local ok, err = pcall(on_curl_action, self, easy, fd, action)

  if not ok then uv.defer(error, err) end
end

function cUrlRequestsQueue:_on_libuv_poll(poller, err, events)
  self:emit('uv::poll', poller, err, EVENT_NAMES[events] or events)

  local flags = assert(FLAGS[events], ("unknown event:" .. events))

  local context = poller.data

  self._multi:socket_action(context:fileno(), flags)

  self:_curl_check_multi_info()
end

function cUrlRequestsQueue:_on_libuv_timeout(timer)
  self:emit('uv::timeout')

  self._multi:socket_action()

  self:_curl_check_multi_info()
end

function cUrlRequestsQueue:_curl_check_multi_info()
  local multi = self._multi
  while true do
    local easy, ok, err = multi:info_read(true)

    if not easy then
      self:close(err)
      return self:emit('error', err)
    end

    if easy == 0 then break end

    local context = easy.data.context
    if context then context:close() end
    easy.data.context = nil

    local task = easy.data.task

    if ok then err = nil end
    task:close(err, easy)

    easy:reset()
    easy.data = nil
    self._qfree:push(easy)
  end

  self:_proceed_queue()
end

end
-------------------------------------------------------------------

-------------------------------------------------------------------
local cUrlMulti = ut.class() do

local function on_curl_timeout(ptr, ms)
  return ptr.value:_on_curl_timeout(ms)
end

local function on_curl_action(ptr, easy, fd, action)
  return ptr.value:_on_curl_action(easy, fd, action)
end

function cUrlMulti:__init(options)
  options = options or {}

  self._qeasy = {}
  self._timer = uv.timer()
  self._multi = curl.multi()

  local pself = weak_ptr(self)

  self._multi:setopt_timerfunction (on_curl_timeout, pself)

  if not pcall(
    self._multi.setopt_socketfunction, self._multi, on_curl_action, pself
  )then
    -- bug in Lua-cURL <= v0.3.5
    self._multi:setopt{ socketfunction = bind(pself, on_curl_action) }
  end

  self._on_libuv_poll_proxy    = bind(self, self._on_libuv_poll)
  self._on_libuv_timeout_proxy = bind(self, self._on_libuv_timeout)

  return self
end

function cUrlMulti:_remove_all(err)
  for easy, data in pairs(self._qeasy) do
    self._multi:remove_handle(easy)

    local context = data.context
    if context then context:close() end
    local callback = data.callback
    if callback then callback(easy, err or ECANCELED) end
  end

  return self
end

function cUrlMulti:close(err)
  self:_remove_all(err)

  self._multi:close()
  self._timer:close()

  self._timer, self._qeasy, self._multi = nil
end

function cUrlMulti:add_handle(easy, callback)
  assert(not self._qeasy[easy])

  local ok, err = self._multi:add_handle(easy)
  if not ok then return nil, err end

  self._qeasy[easy] = {
    callback = callback;
  }

  return self
end

function cUrlMulti:remove_handle(easy)
  self._qeasy[easy] = nil
  self._multi:remove_handle(easy)

  return self
end

function cUrlMulti:_on_curl_timeout(ms)
  if ms <= 0 then ms = 1 end

  self._timer:start(ms, 0, self._on_libuv_timeout_proxy)
end

local function on_curl_action(self, easy, fd, action)
  local data = self._qeasy[easy]
  local context = data.context

  local flag = POLL_IO_FLAGS[action]
  if flag then
    if not context then
      context = Context.new(fd)
      data.context = context
    end
    context:poll(flag, self._on_libuv_poll_proxy)
  elseif action == curl.POLL_REMOVE then
    if context then
      data.context = nil
      context:close()
    end
  end
end

function cUrlMulti:_on_curl_action(easy, fd, action)
  local ok, err = pcall(on_curl_action, self, easy, fd, action)

  if not ok then uv.defer(error, err) end
end

function cUrlMulti:_on_libuv_poll(poller, err, events)
  local flags = assert(FLAGS[events], ("unknown event:" .. events))

  local context = poller.data

  self._multi:socket_action(context:fileno(), flags)

  self:_curl_check_multi_info()
end

function cUrlMulti:_on_libuv_timeout(timer)
  self._multi:socket_action()

  self:_curl_check_multi_info()
end

function cUrlMulti:_curl_check_multi_info()
  local multi = self._multi

  while true do
    local easy, ok, err = multi:info_read(true)

    if not easy then
      self:_remove_all(err)
      return
    end

    if easy == 0 then break end

    local data = self._qeasy[easy]
    self._qeasy[easy] = nil
    if data.context then
      data.context:close()
    end

    if data.callback then
      if ok then err = nil end
      data.callback(easy, err)
    end
  end
end

function cUrlMulti:setopt(...)
  local ok, err = self._multi:setopt(...)
  if ok == self._multi then ok = self end
  return ok, err
end

-- implement all setopt_xxx functions
for item in pairs(require "lcurl.safe") do
  local opt = string.match(item, "^OPT_MULTI_(.+)$")
  if opt and opt ~= 'SOCKETFUNCTION' and opt ~= 'TIMERFUNCTION' then
    local fn_name = 'setopt_' .. string.lower(opt)
    cUrlMulti[fn_name] = function(self, ...)
      local ok, err = self._multi[fn_name](self._multi, ...)
      if ok == self._multi then ok = self end
      return ok, err
    end
  end
end

function cUrlMulti:__tostring()
  local id = hash_id(tostring(self._multi:handle()))
  return string.format("%s %s (%s)", _NAME, 'Multi', id)
end

end
-------------------------------------------------------------------

-------------------------------------------------------------------
local cUrlMultiQueue = ut.class(EventEmitter) do
local super = Super(cUrlMultiQueue)

function cUrlMultiQueue:__init(options)
  self = super(self, '__init', {wildcard = true, delimiter = '::'})

  options = options or {}

  self._multi         = cUrlMulti.new()
  self._MAX_REQUESTS  = options.concurent or 1 -- Number of parallel request
  self._qtask         = Queue.new()            -- wait tasks
  self._qfree         = ut.Queue.new()         -- avaliable easy handles
  self._qeasy         = {}                     -- all easy handles
  self._easy_defaults = options.defaults or {  -- default options for easy handles
    fresh_connect = true;
    forbid_reuse  = true;
  }

  self._on_curl_done_proxy = bind(self, self._on_curl_done)
  return self
end

function cUrlMultiQueue:close(err)
  for i, easy in ipairs(self._qeasy) do
    self._multi:remove_handle(easy)

    local task = easy.data
    if task then task:close(err, easy) end

    easy:close()
  end

  while true do
    local task = self._qtask:pop()
    if not task then break end
    task:close(err)
  end

  self._multi:close()

  self._qeasy, self._multi, self._qtask, self._qfree = nil

  self:emit('close')
end

function cUrlMultiQueue:add(task)
  self._qtask:push(task)

  self:emit('enqueue', task)

  self:_proceed_queue()
  return task
end

function cUrlMultiQueue:perform(url, opt, cb)
  local task
  if type(url) == 'string' then
    task = BasicRequest.new(url, (type(opt) == 'table') and opt)
    cb = (type(opt) == 'function') and opt or cb
    if cb then cb(task) end
  elseif type(url) == 'function' then
    task = BasicRequest.new()
    url(task)
  else
    task = url
  end

  return self:add(task)
end

function cUrlMultiQueue:cancel(task, err)
  err = err or ECANCELED

  -- check either task is started
  for i, easy in ipairs(self._qeasy) do
    if easy.data == task then
      self._multi:remove_handle(easy)

      task:close(err, easy)
      easy:reset()
      easy.data = nil

      self._qfree:push(easy)
      self:_proceed_queue()
      return
    end
  end

  -- remove unstarted task
  local t = self._qtask:remove_value(task)
  if t then
    assert(t == task)
    t:close(err)
  end
end

function cUrlMultiQueue:_next_handle()
  if not self._qfree:empty() then
    return assert(self._qfree:pop())
  end

  if #self._qeasy >= self._MAX_REQUESTS then
    return
  end

  local handle = assert(curl.easy())
  self._qeasy[#self._qeasy + 1] = handle

  return handle
end

function cUrlMultiQueue:_proceed_queue()
  self._proceed_queue_progress = false

  while not self._qtask:empty() do
    local handle = self:_next_handle()
    if not handle then return end
    local task = self._qtask:pop()

    self:emit('dequeue', task)

    local ok, res, err = handle:setopt( self._easy_defaults )
    if ok then
      ok, res, err = pcall(task.start, task, handle)
    end

    if ok and res then
      handle.data = task
      self._multi:add_handle(handle, self._on_curl_done_proxy)
    else
      handle:reset()
      self._qfree:push(handle)
      task:close(err)
    end
  end
end

function cUrlMultiQueue:_on_curl_done(easy, err)
  if not self._proceed_queue_progress then
    self._proceed_queue_progress = true
    uv.defer(self._proceed_queue, self)
  end

  local task = easy.data

  task:close(err, easy)

  easy:reset()
  easy.data = nil
  self._qfree:push(easy)
end

function cUrlMultiQueue:__tostring()
  local id = hash_id(tostring(self._multi))
  return string.format("%s %s (%s)", _NAME, 'Queue', id)
end

end
-------------------------------------------------------------------

local function _curl_index(module, key)
  local v = curl[key]
  if v then
    module[key] = v
  end
  return v
end

local cURL = setmetatable({
  _VERSION      = _VERSION;
  _NAME         = _NAME;
  _LICENSE      = _LICENSE;
  _COPYRIGHT    = _COPYRIGHT;

  multi         = cUrlMulti.new;
  queue         = cUrlMultiQueue.new;
  RequestsQueue = cUrlRequestsQueue.new
}, {__index = _curl_index})

return cURL
