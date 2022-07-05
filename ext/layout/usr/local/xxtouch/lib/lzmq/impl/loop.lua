--
--  Author: Alexey Melnichuk <mimir@newmail.ru>
--
--  Copyright (C) 2013-2014 Alexey Melnichuk <mimir@newmail.ru>
--
--  Licensed according to the included 'LICENCE' document
--
--  This file is part of lua-lzqm library.
--

return function(ZMQ_NAME)

local zmq      = require (ZMQ_NAME)
local zpoller  = require (ZMQ_NAME .. ".poller")
local ztimer   = require (ZMQ_NAME .. ".timer")
local ok, zthreads = pcall(require, ZMQ_NAME .. ".threads")
if not ok then zthreads = nil end

local ZMQ_POLL_MSEC = 1000
do local ver = zmq.version()
  if ver and ver[1] > 2 then
    ZMQ_POLL_MSEC = 1
  end
end

local function class()
  local o = {
    new = function(self, ...)
      return setmetatable({},self):init(...)
    end
  }
  o.__index = o
  return o
end

-------------------------------------------------------------------
local time_event = class() do

-- Пасивные события.

function time_event:init(fn)
  self.private_ = {
    timer = ztimer.monotonic();
    lock  = false;
    fn    = fn;
  }
  return self
end

function time_event:set_time(tm)
  if self.private_.timer:is_monotonic() then
    self.private_.timer = ztimer.absolute()
  end
  self.private_.timer:start(tm)
end

function time_event:set_interval(interval)
  if self.private_.timer:is_absolute() then
    self.private_.timer = ztimer.monotonic()
  end
  self.private_.once = false
  self.private_.timer:start(interval)
end

function time_event:set_interval_once(interval)
  self:set_interval(interval)
  self.private_.once = true
end

---
-- возвращает количество мс до момента срабатывания
function time_event:sleep_interval()
  return self.private_.timer:rest()
end

---
-- Событие находится в рабочем состоянии
function time_event:started()
  return self.private_.timer:started()
end

---
-- Сбрасывет событие. 
function time_event:reset()
  self.private_.timer:stop()
end

---
-- "Взводит" событие заново.
-- Если это одноразовое событие, то оно останавливается.
-- возвращает признак started
function time_event:restart()
  local is_once = self.private_.once or self.private_.timer:is_absolute()
  if is_once then
    if self.private_.timer:started() then
      self.private_.timer:stop()
    end
    return false
  end
  self.private_.timer:start()
  return true
end

function time_event:fire(...)
  return self.private_.fn( self, ... )
end

function time_event:pfire(...)
  local ok, err = pcall( self.private_.fn, self, ... )
  if (not ok) and self.on_error then
    self:on_error(err)
  end
end

function time_event:lock()   self.private_.lock = true  end
function time_event:unlock() self.private_.lock = false end
function time_event:locked() return self.private_.lock  end

end
-------------------------------------------------------------------

-------------------------------------------------------------------
local event_list = class() do

function event_list:new(...)
  return setmetatable({}, self):init(...)
end

function event_list:init()
  self.private_ = {events = {}}
  return self
end

function event_list:destroy()
  self.private_.events = nil
end

function event_list:add(ev)
  table.insert(self.private_.events, ev)
  return true
end

function event_list:count()
  return #self.private_.events
end

---
-- Возвращает время до следующего события
function event_list:sleep_interval(min_interval)
  for i = 1, #self.private_.events do
    local ev = self.private_.events[i]
    if (not ev:locked()) and (ev:started()) then
      local int = ev:sleep_interval()
      if min_interval > int then min_interval = int end
    end
  end
  return min_interval
end

---
-- Вызывает заплонированные события
function event_list:fire(...)
  local cnt = 0
  local i = 0
  while(true)do
    --[[ в процессе обработки очередного события events может изменится
    -- ** или метод fire быть вызван рекурсивно. 
    -- ** Для избежания рекурсивного вызова событий мы их блокируем на время обработки
    -- ** В процессе обработки события другие события могут быть добавлены или удалены
    -- ** Событие может быть сброшено из вне: ev = loop:add_XXX(...); ev:reset()
    -- ** Такое событие нужно просто удалить. 
    -- ** 
    -- ** Возможные развития событий 
    -- **  на текущем проходе (1) событие #1 отработало и ожидает удаление (например одноразовый вызов)
    -- **  событие #2 в процессе обработки вызывает sleep_ex, что вызывает рекурсивный вызов fire.
    -- **  этот проход (2) обнаруживает событие #1 как нерабочее и помечает его на удаление 
    -- **  событие #2 заблокировано и не может быть проверено.
    -- **  проход (2) проверяет остальные события
    -- **  проход (2) удаляет событие #1 и завершается
    -- **  Этот процесс может повторятся несколько раз или вызыватся рекурсивно
    -- **  завершается обработка события #2 на проходе (1).
    -- **  список событий изменился. если в списке было 3 события, то текущий проход пропустил бы его. 
    -- **   Альтернатива - проверка списка с начала после каждог ev:fire() -
    -- **     события с конца списка могут ни когда не выполнится.
    -- **   Альтернатива - копирование списка перед проходом - лишняя операция копирования, при условии 
    -- **     редкого изменения списка событий.
    -- **  С учетом того, что для срабатывания его время должно находится в пределах от момента завершения 
    -- **    последнего вложенного прохода(который должен быть иначе бы событие #1 осталось) до текущего момента
    -- **    можно смирится с тем, что это событие будет вызванно после операции poll или на следующем рекурсивном вызове
    -- **    например в момент обработки события #4
    -- ]]

    i = i + 1
    local ev = self.private_.events[i]
    if not ev then break end
    if not ev:locked() then
      if ev:started() then 
        local int = ev:sleep_interval()
        if int == 0 then 
          ev:lock()
          ev:fire(...) -- может вызвать рекурсию
          ev:unlock()
          if ev:started() and ev:restart() then assert(ev:started()) else assert(not ev:started()) end
          cnt = cnt + 1
        end
      else
        table.remove(self.private_.events, i)
        i = i - 1
      end
    end
  end
  self:purge()
  return cnt
end

---
-- удаляет остановленные события
function event_list:purge()
  for i = #self.private_.events, 1, -1 do
    if (not self.private_.events[i]:locked()) 
    and(not self.private_.events[i]:started())
    then
      table.remove(self.private_.events, i)
    end
  end
end

end
-------------------------------------------------------------------

-------------------------------------------------------------------
local zmq_loop = class() do

-- static
function zmq_loop.sleep(ms) ztimer.sleep(ms) end

function zmq_loop:init(...)
  local N, ctx = ...
  if (select('#', ...) == 1) and type(N) ~= 'number' then
    ctx, N = N, nil
  end

  self.private_ = self.private_ or {}
  self.private_.sockets = {}
  self.private_.event_list = event_list:new()

  local poller, err  = zpoller.new(N)
  if not poller then return nil, err end
  self.private_.poller = poller

  local context, err
  if not ctx then
    if zthreads then context, err = zthreads.context()
    else context, err = zmq.init(1) end
  else
    context, err = ctx
  end
  if not context then self:destroy() return nil, err end
  self.private_.context = context

  return self
end

function zmq_loop:destroyed()
  return nil == self.private_.event_list
end

function zmq_loop:destroy(no_close_sockets)
  if self:destroyed() then return end

  self.private_.event_list:destroy()
  if not no_close_sockets then
    for s in pairs(self.private_.sockets) do
      self.private_.poller:remove(s)
      if( type(s) ~= 'number' ) then
        if s.close then
          s:close()
        end
      end
    end
  end

  self.private_.sockets = nil
  self.private_.event_list = nil
  self.private_.poller = nil
  self.private_.context = nil
end

function zmq_loop:context()
  return self.private_.context
end

function zmq_loop:interrupt()
  self.private_.poller:stop()
  self.private_.interrupt = true
end
zmq_loop.stop = zmq_loop.interrupt

function zmq_loop:interrupted()
  return (self.private_.interrupt) or (self.private_.poller.is_running == false)
end
zmq_loop.stopped = zmq_loop.interrupted

function zmq_loop:poll(interval)
  if self:interrupted() then return nil, 'interrupt' end
  interval = self.private_.event_list:sleep_interval(interval)
  local cnt, msg = self.private_.poller:poll(interval * ZMQ_POLL_MSEC)
  if not cnt then
    self:interrupt()
    return nil, msg
  end
  if self:interrupted() then return nil, 'interrupt' end
  cnt = cnt + self.private_.event_list:fire(self)
  return cnt
end

---
-- в течении ожидания обрабатываются все события
-- в том числе и запланированные
function zmq_loop:sleep_ex(interval)
  local start = ztimer.monotonic_time()
  local rest = interval
  local c = 0
  while true do
    local cnt, msg = self:poll(rest)
    if not cnt then return nil, msg end
    c = c + cnt
    rest = interval - ztimer.monotonic_elapsed(start)
    if rest <= 0 then return c end
  end
end

---
-- обрабатывает только события IO поступившие на текущий момент
-- если событий нет, то функция возвращает управление немедленно
function zmq_loop:flush(interval)
  if self:interrupted() then return nil, 'interrupt' end
  interval = interval or 0
  local start = ztimer.monotonic_time()
  local rest = interval
  local c = 0
  while true do 
    local cnt, msg = self.private_.poller:poll(0)
    if not cnt then return nil, msg end
    c = c + cnt
    rest = interval - ztimer.monotonic_elapsed(start)
    if (cnt == 0) or (rest <= 0) then break end
  end
  if self:interrupted() then return nil, 'interrupt', c end
  return c
end

---
-- Запускает цикл обработки событий
--
function zmq_loop:start(ms, fn)
  local self_ = self
  
  -- если не задан интервал, то не надо вызывать
  if not ms then fn = function()end end

  if (not fn) and ms then 
    -- если явна не задана функция, то вызываем обработчик
    -- в основном для совместимости с предыдущей реализацией
    fn = function() if self_.on_time then self_:on_time() end end
  end
  ms = ms or 60000 -- просто большое число.

  while true do
    local cnt, msg = self:sleep_ex(ms)
    if not cnt then return nil, msg end
    fn()
    if self:interrupted() then return nil, 'interrupt' end
  end
end

---------------------------------------------------------
-- регистрация событий
---------------------------------------------------------

---
-- Добавляет zmq сокет 
-- fn - функци обработки в/в. первым параметром передается zmq_loop
-- zmq_flag - флаги для poll(по умолчанию zmq.POLLIN)
-- 
-- сокет переходит во владение zmq_loop и закрывается в 
-- момент уничтожения zmq_loop
function zmq_loop:add_socket(skt, fn_or_flags, fn)
  if fn == nil then 
    assert(fn_or_flags and type(fn_or_flags) ~= 'number', 'function expected')
    fn, fn_or_flags = fn_or_flags, nil
  end
  local zmq_flag = fn_or_flags or zmq.POLLIN
  local loop = self
  self.private_.poller:add(skt, zmq_flag, function(skt, events)
    return fn(skt, events, loop)
  end)
  self.private_.sockets[skt] = true
  return skt
end

function zmq_loop:add_time(tm, fn)
  local ev = time_event:new(fn)
  ev:set_time(tm)
  self.private_.event_list:add(ev)
  return ev
end

function zmq_loop:add_interval(interval, fn)
  assert(type(interval) == 'number')
  local ev = time_event:new(fn)
  ev:set_interval(interval)
  self.private_.event_list:add(ev)
  return ev
end

function zmq_loop:add_once(interval, fn)
  assert(type(interval) == 'number')
  local ev = time_event:new(fn)
  ev:set_interval_once(interval)
  self.private_.event_list:add(ev)
  return ev
end

function zmq_loop:remove_socket(skt)
  if not self.private_.sockets[skt] then return end
  self.private_.poller:remove(skt)
  self.private_.sockets[skt] = nil
  return skt
end

---------------------------------------------------------
-- Создание сокетов
---------------------------------------------------------
---
-- Все следующие функции являются не обязательными и 
-- служат для упращения создания сокетов

-- create_XXX - только создают, но не добавляют сокет в zmq_loop
-- add_XXX -  добавляют сокет(возможно вновь созданный) в zmq_loop 

---
-- создает сокет в контексте zmq_loop
function zmq_loop:create_socket(...)
  local skt, err = self.private_.context:socket(...)
  if not skt then return nil, err end
  if type(skt) == 'userdata' then
    return skt
  end
  if type(skt) == 'table' and skt.recv then
    return skt
  end
  return nil, skt
end

function zmq_loop:add_new_socket(opt, ...)
  local skt, err = self:create_socket(opt)
  if not skt then return nil, err end
  local ok, err = self:add_socket(skt, ...)
  if not ok then skt:close() end
  return ok, err
end

function zmq_loop:create_sub(subs)
  return self:create_socket{zmq.SUB, subscribe = subs}
end

function zmq_loop:create_sub_bind(addr, subs)
  return self:create_socket{zmq.SUB, subscribe = subs, bind = addr}
end

function zmq_loop:create_sub_connect(addr, subs)
  return self:create_socket{zmq.SUB, subscribe = subs, connect = addr}
end

function zmq_loop:create_bind(sock_type, addr)
  return self:create_socket{sock_type, bind = addr}
end

function zmq_loop:create_connect(sock_type, addr)
  return self:create_socket{sock_type, connect = addr}
end

function zmq_loop:add_new_bind(sock_type, addr, ...)
  return self:add_new_socket({sock_type, bind = addr}, ...)
end

function zmq_loop:add_new_connect(sock_type, addr, ...)
  return self:add_new_socket({sock_type, connect = addr}, ...)
end

function zmq_loop:add_sub_connect(addr, subs, ...)
  return self:add_new_socket({zmq.SUB, connect = addr, subscribe = subs}, ...)
end

function zmq_loop:add_sub_bind(addr, subs, ...)
  return self:add_new_socket({zmq.SUB, bind = addr, subscribe = subs}, ...)
end

end
-------------------------------------------------------------------

local M = {}

function M.new(p, ...)
  if p == M then return zmq_loop:new(...) end
  return zmq_loop:new(p, ...)
end

M.sleep = ztimer.sleep

M.zmq_loop_class = zmq_loop

return M

end