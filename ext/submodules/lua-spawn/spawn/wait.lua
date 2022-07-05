--[[
Wrapper around lunix's 'waitpid' function to make it behave more like lua's luaL_execresult
]]

local unix = require "unix"

local map_err = {
	exited = "exit";
	killed = "signal";
	stopped = "stop";
}

-- hack around lack of 'band' function
local function had_nohang(options)
	return (options%(unix.WNOHANG*2) - options%unix.WNOHANG) ~= 0
end

local function waitpid(pid, options)
	if type(options) == "table" then
		options = options.nohang and unix.WNOHANG or 0
			+ options.untraced and unix.WUNTRACED or 0
			+ options.continued and unix.WCONTINUED or 0
	end
	local which_pid, err, errno = unix.waitpid(pid, options)
	if which_pid == nil then
		if errno == unix.EINTR then
			return waitpid(pid, options)
		end
		return nil, err, errno
	elseif which_pid == 0 and had_nohang(options) then
		return false
	else
		err = map_err[err] or err
		if err == "exit" and errno == 0 then
			return true, err, errno
		else
			return nil, err, errno
		end
	end
end

return {
	waitpid = waitpid;
}
