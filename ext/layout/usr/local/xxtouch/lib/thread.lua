-- This is a compatibility layer for the legacy XXTouch library.
-- I am not familiar with the coroutine library, so I am not sure if this is correct.
-- Use at your own risk.

local _M = {}
local _T = {}
local _TID = 0

_M.dispatch = function (task, error_callback)
    local co = coroutine.create(task)
    _TID = _TID + 1
    _T[_TID] = {
        co = co,
        error_callback = error_callback,
    }
    return _TID
end

_M.current_id = function ()
    local current_co = coroutine.running()
    if current_co == nil then
        return nil
    end
    for tid, t in pairs(_T) do
        if t.co == current_co then
            return tid
        end
    end
    return nil
end

_M.kill = function (tid)
    _T[tid] = nil
end

_M.wait = function (ttid, timeout)
    local t = _T[ttid]
    if t == nil then
        return
    end
    local deadline = timeout and os.time() + timeout or nil
    while true do
        for tid, t in pairs(_T) do
            if coroutine.status(t.co) == "dead" then
                _T[tid] = nil
                if ttid == tid then
                    return
                end
            elseif coroutine.status(t.co) == "suspended" then
                local ok, err = coroutine.resume(t.co)
                if not ok then
                    if t.error_callback then
                        t.error_callback(err)
                    else
                        error(err)
                    end
                    _T[tid] = nil
                end
            end
            if timeout ~= nil then
                local now = os.time()
                if now >= deadline then
                    return
                end
            end
        end
        sys.msleep(50)
    end
end

return _M
