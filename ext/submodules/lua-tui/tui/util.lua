local atexit
if _VERSION == "Lua 5.1" then
	-- luacheck: std lua51
	function atexit(func)
		local proxy = newproxy(true)
		debug.setmetatable(proxy, {__gc = function() return func() end})
		table.insert(debug.getregistry(), proxy)
	end
else
	function atexit(func)
		table.insert(debug.getregistry(), setmetatable({}, {__gc = function() return func() end}))
	end
end

local function read_file(path)
	local fd, err, errno = io.open(path, "rb")
	if not fd then
		return nil, err, errno
	end
	local contents, err2, errno2 = fd:read("*a")
	fd:close()
	if not contents then
		return nil, err2, errno2
	end
	return contents
end

return {
	atexit = atexit;
	read_file = read_file;
}
