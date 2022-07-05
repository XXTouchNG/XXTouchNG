-- This is a compatibility layer for the legacy XXTouch library.

local _print = print
local _buffer = io.tmpfile()
local _max_size = 4096
print = {}

setmetatable(print, {
    __call = function(tab, ...)
        _print(...)
        local loc = _buffer:seek()
        if loc > _max_size then
            _buffer:close()
            _buffer = io.tmpfile()
            loc = 0
        end
        local args = {...}
        local argc = #args
        for i=1,argc do
            _buffer:write(tostring(args[i]))
            if i ~= argc then
                _buffer:write("\t")
            end
        end
        _buffer:write("\n")
        _buffer:seek("set", loc)
    end
})

print.out = function (...)
    return _buffer:read("*a")
end
