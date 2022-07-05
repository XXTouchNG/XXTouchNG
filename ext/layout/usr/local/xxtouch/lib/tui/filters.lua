local function SS2(peek)
	local c = peek(1)
	if c == "\27" then
		if peek(2) == "N" then
			return 3
		end
	elseif c == "\142" then
		return 2
	end
end

local function SS3(peek)
	local c = peek(1)
	if c == "\27" then
		if peek(2) == "O" then
			return 3
		end
	elseif c == "\143" then
		return 2
	end
end

local function CSI(peek)
	local c = peek(1)
	local pos
	if c == "\27" then
		if peek(2) == "[" then
			pos = 3
		else
			return
		end
	elseif c == "\155" then
		pos = 2
	else
		return
	end
	-- Read whole CSI sequence
	--[[ from ECMA-048:
	The format of a control sequence is 'CSI P ... P I ... I F' where
	  - P ... P are parameter bytes, which, if present, consist of bit combinations from 03/00 to 03/15
	  - I ... I are intermediate bytes, which, if present, consist of bit combinations from 02/00 to 02/15
		Together with the Final Byte F they identify the control function
	  - F is the final byte; it consists of a bit combination from 04/00 to 07/14
	]]
	c = peek(pos)
	while c and c:match("[\48-\63]") do
		pos = pos + 1
		c = peek(pos)
	end
	while c and c:match("[\32-\47]") do
		pos = pos + 1
		c = peek(pos)
	end
	if c and c:match("[\64-\126]") then
		return pos
	end
	-- not valid CSI code...
end

local function OSC(peek)
	local c = peek(1)
	local pos
	if c == "\27" then
		if peek(2) == "]" then
			pos = 3
		else
			return
		end
	elseif c == "\157" then
		pos = 2
	else
		return
	end
	repeat
		c = peek(pos)
		if c == "\27" then
			if peek(pos+1) == "\\" then
				return pos+1
			end
		elseif c == "\156" or c == "\7" then -- OSC can be terminated by BEL in xterm
			return pos
		end
		pos = pos + 1
	until not c
end

local function peek_for_st(peek, pos)
	repeat
		local c = peek(pos)
		if c == "\27" then
			if peek(pos+1) == "\\" then
				return pos+1
			end
		elseif c == "\156" then
			return pos
		end
		pos = pos + 1
	until not c
end

local function DCS(peek)
	local c = peek(1)
	local pos
	if c == "\27" then
		if peek(2) == "P" then
			pos = 3
		else
			return
		end
	elseif c == "\144" then
		pos = 2
	else
		return
	end
	return peek_for_st(peek, pos)
end

local function SOS(peek)
	local c = peek(1)
	local pos
	if c == "\27" then
		if peek(2) == "X" then
			pos = 3
		else
			return
		end
	elseif c == "\152" then
		pos = 2
	else
		return
	end
	return peek_for_st(peek, pos)
end

local function PM(peek)
	local c = peek(1)
	local pos
	if c == "\27" then
		if peek(2) == "^" then
			pos = 3
		else
			return
		end
	elseif c == "\158" then
		pos = 2
	else
		return
	end
	return peek_for_st(peek, pos)
end

local function APC(peek)
	local c = peek(1)
	local pos
	if c == "\27" then
		if peek(2) == "_" then
			pos = 3
		else
			return
		end
	elseif c == "\159" then
		pos = 2
	else
		return
	end
	return peek_for_st(peek, pos)
end

-- this doesn't block U+D800 through U+DFFF
local function multibyte_UTF8(peek)
	local c1 = peek(1)
	if c1 == nil then return end
	local b1 = c1:byte()
	if b1 >= 194 and b1 <= 244 then
		local c2 = peek(2)
		if c2 == nil then return end
		local b2 = c2:byte()
		if b2 >= 128 and b2 < 192 then
			if b1 < 224 then
				return 2
			else
				local c3 = peek(3)
				if c3 == nil then return end
				local b3 = c3:byte()
				if b3 >= 128 and b3 < 192 then
					if b1 < 240 then
						return 3
					else
						local c4 = peek(4)
						if c4 == nil then return end
						local b4 = c4:byte()
						if b4 >= 128 and b4 < 192 then
							return 4
						end
					end
				end
			end
		end
	end
end

local function mouse(peek)
	local c = peek(1)
	local pos
	if c == "\27" then
		if peek(2) == "[" then
			pos = 3
		else
			return
		end
	elseif c == "\155" then
		pos = 2
	else
		return
	end
	if peek(pos) == "M" then
		-- The low two bits of C b encode button information: 0=MB1 pressed, 1=MB2 pressed, 2=MB3 pressed, 3=release.
		-- The next three bits encode the modifiers which were down when the button was pressed and are added together: 4=Shift, 8=Meta, 16=Control.
		-- On button-motion events, xterm adds 32 to the event code (the third character, C b )
		-- Wheel mice may return buttons 4 and 5. Those buttons are represented by the same event codes as buttons 1 and 2 respectively, except that 64 is added to the event code.
		-- C x and C y are the x and y coordinates of the mouse event, encoded as in X10 mode.
		return pos + 3
	end
end

-- Filter that fixes linux virtual console bugs
local function linux_quirks(peek)
	-- bug in F1-F5 keys
	if peek(1) == "\27" and peek(2) == "[" and peek(3) == "[" then
		local c = peek(4)
		if c == "A" or c == "B" or c == "C" or c == "D" or c == "E" then
			return 4
		end
	end
	-- bug is an unterminated OSC: P n rr gg bb
	if peek(1) == "\27" and peek(2) == "]" and peek(3) == "P" then
		return 9
	end
end

local function make_chain(tbl)
	return function(peek)
		for _, v in ipairs(tbl) do
			local len = v(peek)
			if len then
				return len
			end
		end
	end
end

local default_chain = make_chain {
	-- Always before CSI
	mouse;
	-- These can be in any order
	SS2;
	SS3;
	CSI;
	OSC;
	DCS;
	SOS;
	PM;
	APC;
	-- Should be before ESC but after CSI and OSC
	linux_quirks;
}

return {
	multibyte_UTF8 = multibyte_UTF8;
	mouse = mouse;
	SS2 = SS2;
	SS3 = SS3;
	CSI = CSI;
	OSC = OSC;
	DCS = DCS;
	SOS = SOS;
	PM = PM;
	APC = APC;
	linux_quirks = linux_quirks;

	make_chain = make_chain;
	default_chain = default_chain;
}
