--[[
`tparm` is a function that takes complex format-string to construct a string
See terminfo(5) for information on this format string

This implementation was written close to the implementation in ncurses on the
assumption that older programs may depend on undefined behaviour to act the
same as in ncurses.

Note that the integer width (and behaviour on overflow) is undefined in the spec
(and in the ncurses implementation! which just uses math operators on `int`s).
]]

local pack = table.pack or function(...) return {select("#", ...), ...} end

local bit32 = require "bit32"
local band = bit32.band
local bor = bit32.bor
local bxor = bit32.bxor
local bnot = bit32.bnot

local function idiv(x, y)
	return math.floor(x / y)
end

local function tparm(str, ...)
	local params = pack(...)
	-- We don't bother initialising the '_vars' to 0: just get when accessing
	local static_vars = {}
	local dynamic_vars = {}
	local stack, stack_n = {}, 0
	local function pop()
		if stack_n == 0 then
			return
		end
		local v = stack[stack_n]
		stack[stack_n] = nil
		stack_n = stack_n - 1
		return v
	end
	local function npop()
		local v = pop()
		if type(v) == "number" then
			return v
		else
			return 0
		end
	end
	local function spop()
		local v = pop()
		if type(v) == "string" then
			return v
		else
			return ""
		end
	end
	local function push(v)
		stack_n = stack_n + 1
		stack[stack_n] = v
	end
	local res, res_n = {}, 0
	local pos = 1
	while pos <= #str do
		local s, c = str:match("%%()(.)", pos)
		if not s then
			res_n = res_n + 1
			res[res_n] = str:sub(pos, -1)
			break
		else
			res_n = res_n + 1
			res[res_n] = str:sub(pos, s-2)
			if c == "%" then
				res_n = res_n + 1
				res[res_n] = "%"
				pos = s + 1
			elseif c == "c" then
				res_n = res_n + 1
				res[res_n] = string.format("%c", npop())
				pos = s + 1
			elseif c == "s" then
				res_n = res_n + 1
				res[res_n] = string.format("%s", spop())
				pos = s + 1
			elseif c == "p" then
				local i = str:match("^[1-9]", s+1)
				if i then
					i = tonumber(i, 10)
					if i <= params.n then
						push(params[i])
					end
				end
				pos = s + 2
			elseif c == "P" then
				local k = str:match("^[a-z]", s+1)
				if k then
					dynamic_vars[k] = npop()
				else
					k = str:match("^[A-Z]", s+1)
					if k then
						static_vars[k] = npop()
					end
				end
				pos = s + 2
			elseif c == "g" then
				local k = str:match("^[a-z]", s+1)
				if k then
					push(dynamic_vars[k] or 0)
				else
					k = str:match("^[A-Z]", s+1)
					if k then
						push(static_vars[k] or 0)
					end
				end
				pos = s + 2
			elseif c == "l" then
				push(#spop())
				pos = s + 1
			elseif c == "'" then
				push(str:byte(s+1, s+1) or 0)
				-- don't validate closing "'", just skip
				pos = s + 3
			elseif c == "{" then
				local v, e = str:match("^(%d*)()", s+1)
				push(tonumber(v, 10) or 0)
				-- don't validate closing "}", just skip
				pos = (e or (s + 1)) + 1
			elseif c == "+" then
				local y = npop()
				local x = npop()
				push(x + y)
				pos = s + 1
			elseif c == "-" then
				local y = npop()
				local x = npop()
				push(x - y)
				pos = s + 1
			elseif c == "*" then
				local y = npop()
				local x = npop()
				push(x * y)
				pos = s + 1
			elseif c == "/" then
				local y = npop()
				local x = npop()
				push(idiv(x, y))
				pos = s + 1
			elseif c == "m" then
				local y = npop()
				local x = npop()
				push(x % y)
				pos = s + 1
			elseif c == "&" then
				local y = npop()
				local x = npop()
				push(band(x, y))
				pos = s + 1
			elseif c == "|" then
				local y = npop()
				local x = npop()
				push(bor(x, y))
				pos = s + 1
			elseif c == "^" then
				local y = npop()
				local x = npop()
				push(bxor(x, y))
				pos = s + 1
			elseif c == "=" then
				local y = npop()
				local x = npop()
				push((x == y) and 1 or 0)
				pos = s + 1
			elseif c == "<" then
				local y = npop()
				local x = npop()
				push((x < y) and 1 or 0)
				pos = s + 1
			elseif c == ">" then
				local y = npop()
				local x = npop()
				push((x > y) and 1 or 0)
				pos = s + 1
			elseif c == "A" then
				local y = npop() ~= 0
				local x = npop() ~= 0
				push((x and y) and 1 or 0)
				pos = s + 1
			elseif c == "O" then
				local y = npop() ~= 0
				local x = npop() ~= 0
				push((x or y) and 1 or 0)
				pos = s + 1
			elseif c == "!" then
				push((npop() == 0) and 1 or 0)
				pos = s + 1
			elseif c == "~" then
				push(bnot(npop()))
				pos = s + 1
			elseif c == "i" then
				if params[1] == 0 then
					params[1] = 1
				end
				if params[2] == 0 then
					params[2] = 1
				end
				pos = s + 1
			elseif c == "?" then
				pos = s + 1
			elseif c == "t" then
				pos = s + 1
				local x = npop()
				if x == 0 then
					-- skip through to after %e or %;
					local level = 0
					while true do
						local t, e = str:match("%%([e%;%?])()", pos)
						if t == nil then
							break
						end
						pos = e
						if t == "?" then
							level = level + 1
						elseif t == ";" then
							if level > 0 then
								level = level - 1
							else
								break
							end
						elseif t == "e" and level == 0 then
							break
						end
					end
				end
			elseif c == "e" then
				pos = s + 1
				-- skip through to after %;
				local level = 0
				while true do
					local t, e = str:match("%%([%;%?])()", pos)
					if t == nil then
						break
					end
					pos = e
					if t == "?" then
						level = level + 1
					elseif t == ";" then
						if level > 0 then
							level = level - 1
						else
							break
						end
					end
				end
			elseif c == ";" then
				pos = s + 1
			else
				-- ncurses allows 'c' and 's' here in addition to documented ones
				local what, want_type, e = str:match("^%:?([%-%+%# ]?%d*%.?%d*([cdoxXs]))()", s)
				if what then
					local v
					if want_type == "s" then
						v = spop()
					else
						v = npop()
					end
					res_n = res_n + 1
					res[res_n] = string.format("%"..what, v)
					pos = e
				else
					pos = s + 1
				end
			end
		end
	end
	return table.concat(res, "", 1, res_n)
end

return {
	tparm = tparm;
}
