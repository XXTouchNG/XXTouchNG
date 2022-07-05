function main(...)
    -- cyclic table
    local v
    do
        v = {
            'a',
            cactus = {
                6,
                abc = { 22 },
            },
            'c'
        }
        v.cactus.abc.q = v
    end
    --[[setfenv(table.deepcopy,
        setmetatable({}, {
            __index    = function(t,k  ) error(("_G[%q]!"     ):format(tostring(k)            ), 2) end,
            __newindex = function(t,k,v) error(("_G[%q] = %q!"):format(tostring(k),tostring(v)), 2) end,
        })
    )]]
    local nv = table.deep_copy(v)
    print(stringify(nv))
    
    -- common upvalue
    do
        local uv = nil
        v = {
            set = function(v) uv = v return uv end,
            get = function() return uv end,
            cactus = {
                a = function() uv = 22 end
            }
        }
    end
    nv = table.deep_copy(v)
    print(stringify(nv))
    
    print("v.set("..tostring(v.set(5))..")")
    print("nv.set("..tostring(nv.set(6))..")")
    print("v.get() == "..tostring(v.get()))
    print("nv.get() == "..tostring(nv.get()))
    print("v a!") v.cactus.a()
    print("v.get() == "..tostring(v.get()))
    print("nv.get() == "..tostring(nv.get()))
    print("nv a!") nv.cactus.a()
    print("v.get() == "..tostring(v.get()))
    print("nv.get() == "..tostring(nv.get()))
end

require "extable"

main(...)
