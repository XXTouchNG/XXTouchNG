local math  = require "math"
local table = require "table"

local error, assert, select = error, assert, select
local max, unpack = math.max, table.unpack or unpack
local setmetatable = setmetatable

local tinsert2 = function(t, n, i, v)
	-- lua 5.2 rise error if index out of range
	-- assert(type(t) =='table')
	-- assert(type(n) =='number')
	-- assert(type(i) =='number')
	if i > n then
		t[i] = v
		return i
	end

	for j = n, i, -1 do
		t[j + 1] = t[j]
	end
	t[i] = v

	return n+1
end

local tremove2 = function(t, n, i)
	-- lua 5.2 rise error if index out of range
	-- assert(type(t) =='table')
	-- assert(type(n) =='number')
	-- assert(type(i) =='number')
	if i > n then
		for j = n+1, i do
			t[j] = nil
		end
		return n
	end

	for j = i, n do
		t[j] = t[j+1]
	end

	return n-1
end

local function idx(i, n, d)
	if i == nil then
		if not d then
			return error("number expected, got nil", 2)
		end
		return d
	end
	if i < 0 then
		i = n+i+1
	end
	if i <= 0 then
		return error("index out of bounds", 2)
	end
	return i
end

local function pack(...)
	local n = select("#", ...)
	local v = {...}
	return function(...)
		if (...) == "#" then
			return n
		else
			local argc = select("#", ...)
			if argc == 0 then
				return unpack(v, 1, n)
			else
				local i, j = ...
				if i == nil then
					if j == nil then j = 0 end
					i = j+1
					if i > 0 and i <= n then
						return i, v[i]
					end
				else
					i = idx(i, n, 1)
					j = idx(j, n, i)
					return unpack(v, i, j)
				end
			end
		end
	end
end

local function range(i, j, ...)
	local n = select("#", ...)
	i, j = idx(i,n), idx(j,n)
	if i > j then return end
	return unpack({...}, i, j)
end

local function remove(i, ...)
	local n = select("#", ...)
	local t = {...}
	i = idx(i, n)
	assert(i>0, "index out of bounds")
	if i<=n then
		n = tremove2(t, n, i)
	end
	return unpack(t, 1, n)
end

local function insert(v, i, ...)
	local n = select("#", ...)
	local t = {...}
	i = idx(i, n)
	assert(i > 0, "index out of bounds")
	n = tinsert2(t, n, i, v)
	return unpack(t, 1, n)
end

local function replace(v, i, ...)
	local n = select("#", ...)
	local t = {...}
	i = idx(i, n)
	assert(i > 0, "index out of bounds")
	t[i] = v
	n = max(n, i)
	return unpack(t, 1, n)
end

local function append(...)
	local n = select("#",...)
	if n <= 1 then return ... end
	local t = {select(2, ...)}
	t[n] = (...)
	return unpack(t, 1, n)
end

local function map(...)
	local n = select("#", ...)
	assert(n > 0)
	local f = ...
	local t = {}
	for i = 2, n do
		t[i-1] = f((select(i, ...)))
	end
	return unpack(t, 1, n-1)
end

local function packinto(n, t, ...)
	local c = select("#", ...)
	for i = 1, c do
		t[n+i] = select(i, ...)
	end
	return n+c
end

local function concat(...)
	local n = 0
	local t = {}
	for i = 1, select("#", ...) do
		local f = select(i, ...)
		n = packinto(n, t, f())
	end
	return unpack(t, 1, n)
end

local function count(...)
	return select("#", ...)
end

local function at(i, ...)
	local n = select("#", ...)
	i = idx(i,n)
	if i > n then return end
	return (select(i, ...))
end

return setmetatable({
	pack    = pack,
	range   = range,
	insert  = insert,
	remove  = remove,
	replace = replace,
	append  = append,
	map     = map,
	concat  = concat,
	count   = count,
	at      = at,
},{
	__call = function(_, ...)
		return pack(...)
	end
})
