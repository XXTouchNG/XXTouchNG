-- Copyright (c) 2012 Matthias Richter
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do
-- so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- Except as contained in this notice, the name(s) of the above copyright holders
-- shall not be used in advertising or otherwise to promote the sale, use or
-- other dealings in this Software without prior written authorization.
--
-- If you find yourself in a situation where you can safe the author's life
-- without risking your own safety, you are obliged to do so.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

local socket = require 'socket'

-- helper
local function Set(t)
	local s = {}
	for _,v in ipairs(t) do s[v] = true end
	return s
end

-- argument checkers.
-- e.g.: assert_arg(1, foo).type('string', 'number')
--       assert_arg(2, bar).any('one', 2, true)
local function assert_arg(n,v)
	return {
		type = function(...)
			local s = type(v)
			for t in pairs(Set{...}) do if s == t then return end end
			local t = table.concat({...}, "' or `")
			error(("Error in argument %s: Expected `%s', got `%s'"):format(n, t, s), 2)
		end,
		any = function(...)
			for u in pairs(Set{...}) do if u == v then return end end
			local u = table.concat({...}, "', `")
			error(("Error in argument %s: Expected to be one of (`%s'), got `%s'"):format(n, u, tostring(v)), 2)
		end
	}
end

-- generates tokens for IMAP conversations
local function token_generator()
	local prefix = math.random()
	local n = 0
	return function()
		n = n + 1
		return prefix .. n
	end
end

-- (nested) table to IMAP lists. table may not contain loops
local function to_list(tbl)
	if type(tbl) == 'table' then
		local s = {}
		for k,v in ipairs(tbl) do s[k] = to_list(v) end
		return '(' .. table.concat(s, ' ') .. ')'
	end
	return tbl
end

-- make a table out of an IMAP list
local function to_table(s)
	local stack = {i = 0}
	local function push(v)
		local cur = stack[stack.i]
		cur[#cur+1] = v
	end

	local i = 1
	while i <= #s do
		local c = s:sub(i,i)
		if c == '(' then      -- open list
			stack.i = stack.i + 1
			stack[stack.i] = {}
		elseif c == ')' then  -- close list
			if stack.i == 1 then return stack[stack.i] end
			stack.i = stack.i - 1
			push(stack[stack.i+1])
		elseif c == '[' then  -- quoted list
			local k = i
			i = assert(s:find(']', i+1), "Expected token `]', got EOS")
			push(s:sub(k+1, i-1))
		elseif c == '"' then  -- quoted string
			local k = i
			repeat
				i = assert(s:find('"', i+1), "Expected token `\"', got EOS")
			until s:sub(i-1,i) ~= '\\"'
			push(s:sub(k+1,i-1))
		elseif c == '{' then  -- literal
			local k = assert(s:find('}', i+1), "Expected token `}', got EOS")
			local n = tonumber(s:sub(i+1,k-1))
			local sep = s:sub(k+1,k+2)
			assert(sep == '\r\n', ("Invalid literal: Expected 0x%02x 0x%02x, got 0x%02x 0x%02x"):format(('\r'):byte(1), ('\n'):byte(1), sep:byte(1,-1)))
			k, i = k+3, k+3+n+1
			assert(i <= #s, "Invalid literal: Requested more bytes than available")
			push(s:sub(k,i))
		elseif c:match('%S') then
			local k = i
			i = assert(s:find('[%s%)%[]',i+1), "Expected token <space>, `)' or `[', got EOS") - 1
			push(s:sub(k,i))
		end
		i = i + 1
	end
	error("Expected token `)', got EOS:\n"..s)
end

-- imap4 connection
local IMAP = {}
IMAP.__index = IMAP

-- constructor
function IMAP.new(host, port, tls_params)
	assert_arg(1, host).type('string')
	assert_arg(2, port).type('number', 'nil')

	port = port or 143
	local s = assert(socket.connect(host, port), ("Cannot connect to %s:%u"):format(host, port))
	s:settimeout(5)

	local imap = setmetatable({
		host       = host,
		port       = port,
		socket     = s,
		next_token = token_generator(),
	}, IMAP)

	-- check the server greeting before executing the first command
	imap._do_cmd = function(self, ...)
		self._do_cmd = IMAP._do_cmd
		local greeting = imap:_receive():match("^%*%s+(.*)")
		if not greeting then
			self.socket:close()
			assert(nil, ("Did not receive greeting from %s:%u"):format(host, port))
		end
		return self:_do_cmd(...)
	end

	-- shortcut to enabling a secure connection
	if tls_params then
		imap:enabletls(tls_params)
	end

	return imap
end

-- Enable ssl connection. Some servers *cough*gmail*cough* dont honor the
-- standard and close the connection before letting you send any command,
-- including STARTTLS.
function IMAP:enabletls(tls_params)
	assert_arg(1, tls_params).type('table', 'nil')
	tls_params = tls_params or {protocol = 'sslv3'}
	tls_params.mode = tls_params.mode or 'client'

	local ssl = require 'ssl'
	self.socket = assert(ssl.wrap(self.socket, tls_params))
	return self.socket:dohandshake()
end

-- gets a full line from the socket. may block
function IMAP:_receive(mode)
	local r = {}
	repeat
		local result, errstate, partial = self.socket:receive(mode or '*l')
		if not result then
			assert(errstate ~= 'closed', ('Connection to %s:%u closed unexpectedly'):format(self.host, self.port))
			assert(#partial > 0, ('Connection to %s:%u timed out'):format(self.host, self.port))
			r[#r+1] = partial
		end
		r[#r+1] = result -- does nothing if result is nil
	until result
	return table.concat(r)
end

-- invokes a tagged command and returns response blocks
function IMAP:_do_cmd(cmd, ...)
	--assert(self.socket, 'Connection closed')
	local token = self:next_token()

	-- send request
	local data  = token .. ' ' .. cmd:format(...) .. '\r\n'
	local len   = assert(self.socket:send(data))
	assert(len == #data, 'Broken connection: Could not send all required data')

	-- receive answer line by line and pack into blocks
	local blocks = {}
	local literal_bytes = 0
	while true do
		-- return if there was a tagged response
		if literal_bytes > 0 then
			blocks[#blocks] = blocks[#blocks] .. '\r\n' .. self:_receive(literal_bytes)
			literal_bytes = 0
		end

		local line = self:_receive()
		local status, msg = line:match('^'..token..' ([A-Z]+) (.*)$')
		if status == 'OK' then
			break
		elseif status == 'NO' or status == 'BAD' then
			error(("Command `%s' failed: %s"):format(cmd:format(...), msg), 3)
		end

		local firstchar = line:sub(1,1)
		if firstchar == '*' then
			blocks[#blocks+1] = line:sub(3)
			literal_bytes = tonumber(line:match('{(%d+)}$')) or 0
		elseif firstchar ~= '+' and #line > 0 then
			blocks[#blocks] = blocks[#blocks] .. '\r\n' .. line
		end
	end

	-- transform blocks into response table:
	-- { TOKEN1 = {arg1.1, arg1.2, ...}, TOKEN2 = {arg2.1, arg2.2, ...} }
	local res = setmetatable({}, {__index = function(t,k) local s = {}; rawset(t,k,s); return s; end})
	for i = 1,#blocks do
		local token, args = blocks[i]:match('^(%S+) (.*)$')
		if tonumber(token) ~= nil then
			local n = token
			token, args = args:match('^(%S+)%s*(.*)$')
			args = n .. ' ' .. args
		end
		if not token then token = blocks[i] end
		local t = res[token]
		t[#t+1] = args
	end
	return res
end

-- any state

-- returns table with server capabilities
function IMAP:capability()
	local cap = {}
	local res = self:_do_cmd('CAPABILITY')
	for w in table.concat(res.CAPABILITY, ' '):gmatch('%S+') do
		cap[#cap+1] = w
		cap[w] = true
	end
	return cap, res
end

-- test if server is capable of *all* listed arguments
function IMAP:isCapable(...)
	local cap = self:capability()
	for _,v in ipairs{...} do
		if not cap[v] then return false end
	end
	return true
end

-- does nothing, but may receive updated state
function IMAP:noop()
	return self:_do_cmd('NOOP')
end

function IMAP:logout()
	local res = self:_do_cmd('LOGOUT')
	self.socket:close()
	return res
end

-- start TLS connection. requires luasec. see luasec documentation for
-- infos on what tls_params should be.
function IMAP:starttls(tls_params)
	assert(self:isCapable('STARTTLS'))
	local res = self:_do_cmd('STARTTLS')
	self:enabletls(tls_params)
	return res
end

function IMAP:authenticate()
	error('Not implemented')
end

-- plain text login. do not use unless connection is secure (i.e. TLS or SSH tunnel)
function IMAP:login(user, pass)
	local res = self:_do_cmd('LOGIN %s %s', user, pass)
	return res
end

-- authenticated state
-- select and examine get the same results
local function parse_select_examine(res)
	return {
		flags = to_table(res.FLAGS[1] or "()"),
		exist = tonumber(res.EXISTS[1]),
		recent = tonumber(res.RECENT[1])
	}
end

-- select a mailbox so that messages in the mailbox can be accessed
-- returns a table of the following format:
-- { flags = {string...}, exist = number, recent = number}
function IMAP:select(mailbox)
	-- if this fails we go back to authenticated state
	local res = self:_do_cmd('SELECT %s', mailbox)
	return parse_select_examine(res), res
end

-- same as IMAP:select, except that the mailbox is set to read-only
function IMAP:examine(mailbox)
	local res = self:_do_cmd('SELECT %s', mailbox)
	return parse_select_examine(res), res
end

-- create a new mailbox
function IMAP:create(mailbox)
	return self:_do_cmd('CREATE %s', mailbox)
end

-- delete an existing mailbox
function IMAP:delete(mailbox)
	return self:_do_cmd('DELETE %s', mailbox)
end

-- renames a mailbox
function IMAP:rename(from, to)
	return self:_do_cmd('RENAME %s %s', from, to)
end

-- marks mailbox as subscribed
-- subscribed mailboxes will be listed with the lsub command
function IMAP:subscribe(mailbox)
	return self:_do_cmd('SUBSCRIBE %s', mailbox)
end

-- unsubscribe a mailbox
function IMAP:unsubscribe(mailbox)
	return self:_do_cmd('UNSUBSCRIBE %s', mailbox)
end

-- parse response from IMAP:list() and IMAP:lsub()
local function parse_list_lsub(res, token)
	local mailboxes = {}
	for _,r in ipairs(res[token]) do
		local flags, delim, name = r:match('^(%b()) (%b"") (.+)$')
		flags = to_table(flags)
		for _,f in ipairs(flags) do
			flags[f:sub(2)] = true
		end

		if name:sub(1,1) == '"' and name:sub(-1) == '"' then
			name = name:sub(2,-2)
		end
		mailboxes[name] = {delim = delim:sub(2,-2), flags = flags}
	end
	return mailboxes
end

-- list mailboxes, where `mailbox' is a mailbox name with possible 
-- wildcards and `ref' is a reference name. Default parameters are:
-- mailbox = '*' (match all) and ref = '""' (no reference name)
-- See RFC3501 Sec 6.3.8 for details.
function IMAP:list(mailbox, ref)
	mailbox = mailbox or '*'
	ref = ref or '""'
	local res = self:_do_cmd('LIST %s %s', ref, mailbox)
	return parse_list_lsub(res, 'LIST'), res
end

-- same as IMAP:list(), but lists only subscribed or active mailboxes.
function IMAP:lsub(mailbox, ref)
	mailbox = mailbox or "*"
	ref = ref or '""'
	local res = self:_do_cmd('LSUB %s %s', ref, mailbox)
	return parse_list_lsub(res, 'LSUB'), res
end

-- get mailbox information. `status' may be a string or a table of strings
-- as defined by RFC3501 Sec 6.3.10:
-- MESSAGES, RECENT, UIDNEXT, UIDVALIDITY and UNSEEN
function IMAP:status(mailbox, names)
	assert_arg(1, mailbox).type('string')
	assert_arg(2, names).type('string', 'table', 'nil')

	names = to_list(names or '(MESSAGES RECENT UIDNEXT UIDVALIDITY UNSEEN)')
	local res = self:_do_cmd('STATUS %s %s', mailbox, names)

	local list = to_table(assert(res.STATUS[1]:match('(%b())%s*$'), 'Invalid response'))
	assert(#list % 2 == 0, "Invalid response size")

	local status = {}
	for i = 1,#list,2 do
		status[list[i]] = tonumber(list[i+1])
	end
	return status, res
end

-- append a message to a mailbox
function IMAP:append(mailbox, message, flags, date)
	assert_arg(1, mailbox).type('string')
	assert_arg(2, message).type('string')
	assert_arg(3, flags).type('table', 'string', 'nil')
	assert_arg(4, date).type('string', 'nil')

	message = ('{%d}\r\n%s'):format(#message, message) -- message literal
	flags = flags and ' ' .. to_list(flags) or ''
	date = date and ' ' .. date or ''

	return self:_do_cmd('APPEND %s%s%s %s', mailbox, flags, date, message)
end

-- requests a checkpoint of the currently selected mailbox
function IMAP:check()
	return self:_do_cmd('CHECK')
end

-- permanently removes all messages with \Deleted flag from currently
-- selected mailbox without giving responses. return to
-- 'authenticated' state.
function IMAP:close()
	local res = self:_do_cmd('CLOSE')
	return res
end

-- permanently removes all messages with \Deleted flag from currently
-- selected mailbox. returns a table of deleted message numbers/ids.
function IMAP:expunge()
	local res = self:_do_cmd('EXPUNGE')
	return res.EXPUNGE, res
end

-- searches the mailbox for messages that match the given searching criteria
-- See RFC3501 Sec 6.4.4 for details
function IMAP:search(criteria, charset, uid)
	assert_arg(1, criteria).type('string', 'table')
	assert_arg(2, charset).type('string', 'nil')

	charset = charset and 'CHARSET ' .. charset or ''
	criteria = to_list(criteria)
	uid = uid and 'UID ' or ''

	local res = self:_do_cmd('%sSEARCH %s %s', uid, charset, criteria)
	local ids = {}
	for id in res.SEARCH[1]:gmatch('%S+') do
		ids[#ids+1] = tonumber(id)
	end
	return ids, res
end

-- parses response to fetch() and store() commands
local function parse_fetch(res)
	local messages = {}
	for _, m in ipairs(res.FETCH) do
		local id, list = m:match("^(%d+) (.*)$")
		list = to_table(list)
		local msg = {id = id}
		local i = 1
		while i < #list do
			local key = list[i]
			local value = list[i+1]
			if key == 'BODY' then
				value = {
					parts = (type(value) == 'string') and to_table('('..value..')') or value,
					value = list[i+2]
				}
				i = i + 1
			end
			msg[key] = value
			msg[#msg+1] = key
			i = i + 2
		end
		messages[#messages+1] = msg
	end
	return messages
end

function IMAP:fetch(what, sequence, uid)
	assert_arg(1, what).type('string', 'table', 'nil')
	assert_arg(2, sequence).type('string', 'nil')

	what = to_list(what or '(UID BODY[HEADER.FIELDS (DATE FROM SUBJECT)])')
	sequence = sequence and tostring(sequence) or '1:*'
	uid = uid and 'UID ' or ''

	local res = self:_do_cmd('%sFETCH %s %s', uid, sequence, what)
	return parse_fetch(res), res
end

function IMAP:store(mode, flags, sequence, silent, uid)
	assert_arg(1, mode).any('set', '+', '-')
	assert_arg(2, flags).type('string', 'table')
	assert_arg(3, sequence).type('string', 'number')

	mode = mode == 'set' and '' or mode
	flags = to_list(flags)
	sequence = tostring(sequence)
	silent = silent and '.SILENT' or ''
	uid = uid and 'UID ' or ''

	local res = self:_do_cmd('%sSTORE %s %sFLAGS%s %s', uid, sequence, mode, silent, flags)
	return parse_fetch(res), res
end

function IMAP:copy(sequence, mailbox, uid)
	assert_arg(1, sequence).type('string', 'number')
	assert_arg(2, mailbox).type('string')

	sequence = tostring(sequence)
	uid = uid and 'UID ' or ''
	return self:_do_cmd('%sCOPY %s %s', uid, sequence, mailbox)
end

-- utility library
IMAP.util = {}

-- transforms t = {k1, v1, k2, v2, ...} to r = {[k1] = v1, [k2] = v2, ...}
function IMAP.util.collapse_list(t)
	if t == 'NIL' then return {} end
	local r = {}
	for i = 1,#t,2 do
		r[t[i]] = t[i+1]
	end
	return r
end

-- transforms bodystructure response in a more usable format
function IMAP.util.get_bodystructure(t, part)
	local function tnil(s) return s == 'NIL' and nil or s end

	local r = {part = part}

	if type(t[1]) == 'table' then
		local i = 1
		while type(t[i]) == 'table' do
			r[i] = IMAP.util.get_bodystructure(t[i], (part and part .. '.' or '') .. i)
			i = i + 1
		end
		r.type        = t[i]
		r.params      = IMAP.util.collapse_list(t[i+1])
		r.disposition = tnil(t[i+2])
		r.language    = tnil(t[i+3])
		r.location    = tnil(t[i+4])
		return r
	end

	r.type        = t[1]
	r.subtype     = t[2]
	r.params      = IMAP.util.collapse_list(t[3])
	r.id          = tnil(t[4])
	r.description = tnil(t[5])
	r.encoding    = tnil(t[6])
	r.size        = tonumber(t[7])

	local line_field = 8
	if r.type:lower() == 'message' and r.subtype:lower() == 'rfc822' then
		r.envelope = tnil(t[8])
		r.body     = tnil(t[9])
		line_field = 10
	end

	r.lines       = tonumber(t[line_field])
	r.md5         = tnil(t[line_field + 1])
	r.disposition = tnil(t[line_field + 2])
	r.language    = tnil(t[line_field + 3])
	r.location    = tnil(t[line_field + 4])

	return r
end

return setmetatable(IMAP, {__call = function(_, ...) return IMAP.new(...) end})
