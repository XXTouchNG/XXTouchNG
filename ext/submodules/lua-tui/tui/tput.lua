local tui_terminfo = require "tui.terminfo"
local tui_util = require "tui.util"

local default_terminfo = tui_terminfo.find()

local function init(fd, terminfo)
	if fd == nil then
		fd = io.stdout
	end
	if terminfo == nil then
		terminfo = default_terminfo
	end
	local str = {
		terminfo.init_prog or "";
		terminfo.init_1string or "";
		terminfo.init_2string or "";
		terminfo.clear_margins or "";
		terminfo.set_left_margin or "";
		terminfo.set_right_margin or "";
		terminfo.clear_all_tabs or "";
		terminfo.set_tab or "";
		"";
		terminfo.init_3string or "";
	}
	local file = terminfo.init_file
	if file then
		str[9] = tui_util.read_file(file) or ""
	end
	return fd:write(table.concat(str))
end

local function reset(fd, terminfo)
	if fd == nil then
		fd = io.stdout
	end
	if terminfo == nil then
		terminfo = default_terminfo
	end
	local str = {
		terminfo.init_prog or "";
		terminfo.reset_1string or terminfo.init_1string or "";
		terminfo.reset_2string or terminfo.init_2string or "";
		terminfo.clear_margins or "";
		terminfo.set_left_margin or "";
		terminfo.set_right_margin or "";
		terminfo.clear_all_tabs or "";
		terminfo.set_tab or "";
		"";
		terminfo.reset_3string or terminfo.init_3string or "";
	}
	local file = terminfo.reset_file or terminfo.init_file
	if file then
		str[9] = tui_util.read_file(file) or ""
	end
	return fd:write(table.concat(str))
end

return {
	init = init;
	reset = reset;
}
