-- This is a compatibility layer for the legacy XXTouch library.
-- This library does not support coroutines.
-- See copas/ftp.lua for an example of how to use coroutines.

-- Copyright (c) 2014 Alexey Melnichuk
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.

local socket = require "socket"
local FTP    = require "socket.ftp"
local ltn12  = require "ltn12"
local path   = require "path".new("/")
local curl   = require("lcurl")
local easy   = curl.easy {}

local function split_status(str)
    local code, msg = string.match(str, "^(%d%d%d)%s*(.-)%s*$")
    if code then return tonumber(code), msg end
    return nil, str
end

local function split(str, sep, plain)
    local b, res = 1, {}
    while b <= #str do
        local e, e2 = string.find(str, sep, b, plain)
        if e then
            table.insert(res, (string.sub(str, b, e-1)))
            b = e2 + 1
        else
            table.insert(res, (string.sub(str, b)))
            break
        end
    end
    return res
end

local ftp = {} do
    ftp.__index = ftp

    function ftp:new(params)
        local t = setmetatable({}, self)
        t.private_ = {
            host = params.host;
            port = params.port;
            uid  = params.uid;
            pwd  = params.pwd;
        }
        return t
    end

    function ftp:cmd_(cmd, ...)
        local t = {}
        local p = {
            host     = self.private_.host;
            port     = self.private_.port;
            user     = self.private_.uid;
            password = self.private_.pwd;

            sink     = assert(ltn12.sink.table(t));
            command  = assert(cmd);
            type     = "i";
        }
        local args = table.concat({...},' ')
        if args ~= '' then
            p.command = p.command .. " " .. args
        end

        local r, e = FTP.get(p)
        if not r then return nil, e end

        return table.concat(t)
    end

    function ftp:list_(...)
        local f, e  = self:cmd_(...)
        if not f then
            if e then
                local code = split_status(e)
                if code and code == 550 then  -- not found
                    return {}
                end
            end
            return nil, e
        end
        local t = split(f, '\r?\n')
        if not t then return f end
        if t[ #t ] == '' then table.remove(t) end
        return t
    end

    function ftp:get(remote_file_path, snk, rest)
        local p = {
            host     = self.private_.host;
            port     = self.private_.port;
            user     = self.private_.uid;
            password = self.private_.pwd;
            path     = self:path(remote_file_path);
            type     = "i";
            sink     = assert(snk);
            rest     = rest;
        }

        return FTP.get(p)
    end

    function ftp:put(remote_file_path, src, command)
        local p = {
            host     = self.private_.host;
            port     = self.private_.port;
            user     = self.private_.uid;
            password = self.private_.pwd;
            path     = self:path(remote_file_path);
            type     = "i";
            source   = assert(src);
            command  = command or "stor";
        }
        return FTP.put(p)
    end

    function ftp:mkdir(remote_dir_path)
        local p = {
            host     = self.private_.host;
            port     = self.private_.port;
            user     = self.private_.uid;
            password = self.private_.pwd;
            path     = self:path(remote_dir_path);
        }
        return FTP.mkdir(p)
    end

    function ftp:rmdir(remote_dir_path)
        local p = {
            host     = self.private_.host;
            port     = self.private_.port;
            user     = self.private_.uid;
            password = self.private_.pwd;
            path     = self:path(remote_dir_path);
        }
        return FTP.rmdir(p)
    end

    function ftp:size(remote_file_path)
        local p = {
            host     = self.private_.host;
            port     = self.private_.port;
            user     = self.private_.uid;
            password = self.private_.pwd;
            path     = self:path(remote_file_path);
        }
        return FTP.size(p)
    end

    function ftp:cd(remote_path)
        assert(type(remote_path) == "string")

        if path:isfullpath(remote_path) then
            self.private_.path = path:normolize(remote_path)
        else
            self.private_.path = path:normolize(self:path(remote_path))
        end
        return self
    end

    function ftp:path(P)
        return path:join(self.private_.path or '.', P or '')
    end

    function ftp:noop()
        local f, e = self:cmd_("noop")
        if not f then return nil,e end
        local staus, msg = split_status(f)
        if staus == 200 then return true, msg end
        return false, f
    end

    function ftp:list()
        return self:list_('list', self:path())
    end

    function ftp:nlst(mask)
        assert(type(mask) == "string")
        return self:list_('nlst', self:path(mask))
    end

    function ftp:get_file(remote_file_path, local_file_path, filter)
        local f, err = io.open(local_file_path, 'wb+')
        if not f then return nil, err end
        local sink = ltn12.sink.file(f)
        if filter then sink = ltn12.sink.chain( filter, sink ) end

        local ok, err = self:get(remote_file_path, sink)
        if not ok then
            f:close()
            return nil, err
        end
        return true
    end

    function ftp:get_data(remote_file_path, filter)
        local t = {}
        local sink = ltn12.sink.table(t)
        if filter then sink = ltn12.sink.chain( filter, sink ) end

        local ok, err = self:get(remote_file_path, sink)
        if not ok then return nil, err end
        return table.concat(t)
    end

    function ftp:put_file(remote_file_path, local_file_path, filter)
        local f, err = io.open(local_file_path, 'rb')
        if not f then return nil, err end
        local src = ltn12.source.file(f)
        if filter then src = ltn12.source.chain(src, filter) end

        local ok, err = self:put(remote_file_path, src)
        if not ok then
            f:close()
            return nil, err
        end

        return true
    end

    function ftp:put_data(remote_file_path, data, filter)
        assert(type(data) == "string")

        local src = ltn12.source.string(data)
        if filter then
            src = ltn12.source.chain(src, filter)
        end

        local ok, err = self:put(remote_file_path, src)
        if not ok then return nil, err end

        return true
    end
    
end

-- formats a number of seconds into human readable form
local function nicetime(s)
    local l = "s"
    if s > 60 then
        s = s / 60
        l = "m"
        if s > 60 then
            s = s / 60
            l = "h"
            if s > 24 then
                s = s / 24
                l = "d" -- hmmm
            end
        end
    end
    if l == "s" then return string.format("%5.0f%s", s, l)
    else return string.format("%5.2f%s", s, l) end
end

-- formats a number of bytes into human readable form
local function nicesize(b)
    local l = "B"
    if b > 1024 then
        b = b / 1024
        l = "KB"
        if b > 1024 then
            b = b / 1024
            l = "MB"
            if b > 1024 then
                b = b / 1024
                l = "GB" -- hmmm
            end
        end
    end
    return string.format("%7.2f%2s", b, l)
end

-- returns a string with the current state of the download
local remaining_s = "%s %s, %s/s throughput, %2.0f%% done, %s remaining"
local elapsed_s =   "%s %s, %s/s throughput, %s elapsed                "
local function gauge(oper, got, delta, size)
    local rate = got / delta
    if size and size >= 1 then
        return string.format(remaining_s, nicesize(got), oper, nicesize(rate),
            100*got/size, nicetime((size-got)/rate))
    else
        return string.format(elapsed_s, nicesize(got), oper,
            nicesize(rate), nicetime(delta))
    end
end

-- creates a new instance of a receive_cb that saves to disk
-- kind of copied from luasocket's manual callback examples
local function stats(oper, resource_size, already_download, receive_cb)
    local start = socket.gettime()
    local last = start
    already_download = already_download or 0
    local size_download = already_download
    return function(chunk)
        -- elapsed time since start
        local current = socket.gettime()
        if chunk then
            -- total bytes received
            size_download = size_download + string.len(chunk)
            -- not enough time for estimate
            if current - last > 1 then
                io.stderr:write("\r", gauge(oper, size_download, current - start, resource_size))
                io.stderr:flush()
                last = current
            end
        else
            -- close up
            io.stderr:write("\r", gauge(oper, size_download, current - start), "\n")
        end
        if receive_cb then
            local info = {
                resource_size = resource_size,
                start_pos = already_download,
                size_download = size_download,
                speed_download = size_download / (current - start),
            }
            if receive_cb(info) then
                return sink.error("receive_cb returned true, download interrupted")
            end
        end
        return chunk
    end
end

-- determines the size of a ftp file
local function getftpsize(_ftp, path)
    return _ftp:size(path)
end

local function download(req_url, output_path, req_timeout, should_resume, info_callback, block_size)
    assert(type(req_url) == "string", "ftp.download: Argument #1 req_url must be a string")
    assert(type(output_path) == "string", "ftp.download: Argument #2 output_path must be a string")
    assert(req_timeout == nil or type(req_timeout) == 'number', 'ftp.download: Argument #3 req_timeout must be a number')
    FTP.TIMEOUT = req_timeout or 10
    assert(should_resume == nil or type(should_resume) == 'boolean', 'ftp.download: Argument #4 should_resume must be a boolean')
    should_resume = should_resume or false
    assert(info_callback == nil or type(info_callback) == 'function', 'ftp.download: Argument #5 info_callback must be a function')  -- vscode: end
    assert(block_size == nil or type(block_size) == 'number', 'ftp.download: Argument #6 block_size must be a number')
    socket.BLOCKSIZE = block_size or 8192

    local open_flags
    if should_resume then
        open_flags = "a+b"  -- append mode
    else
        open_flags = "wb"   -- write mode
    end

    local upload_file = io.open(output_path, open_flags)
    assert(upload_file, "Could not open " .. output_path .. " for writing")

    local begin_size = upload_file:seek("end")
    local real_begin = begin_size
    if begin_size > socket.BLOCKSIZE then
        real_begin = begin_size - socket.BLOCKSIZE * 2  -- make sure we have some space to write to
    end
    should_resume = should_resume and begin_size > 0

    local url = require("net.url")
    local parsed_url = url.parse(req_url)
    local _ftp = ftp:new {
        host = parsed_url.host,
        port = parsed_url.port,
        uid = easy:unescape(parsed_url.user),
        pwd = easy:unescape(parsed_url.password),
    }

    local resource_size
    resource_size = getftpsize(_ftp, parsed_url.path)
    if resource_size == nil then
        return false, "Could not determine size of resource at path " .. parsed_url.path
    end

    if should_resume then
        upload_file:close()
        upload_file = io.open(output_path, "r+b")  -- why do not keep using "a+": writing is only allowed at the end of file.
        real_begin = upload_file:seek("set", real_begin)
        io.stderr:write("INFO: server supports resume, will resume download from " .. tostring(begin_size) .. tostring(real_begin - begin_size) .. " bytes\n")
    end

    local closed
    local begin_at = socket.gettime()
    if real_begin >= resource_size then
        io.stderr:write("INFO: file already downloaded, skipping\n")
    else
        if not should_resume then
            closed = _ftp:get(
                parsed_url.path,
                ltn12.sink.chain(
                    stats(
                        "received",
                        resource_size,
                        0,
                        info_callback
                    ),
                    ltn12.sink.file(upload_file)
                )
            )
        else
            closed = _ftp:get(
                parsed_url.path,
                ltn12.sink.chain(
                    stats(
                        "received",
                        resource_size,
                        real_begin,
                        info_callback
                    ),
                    ltn12.sink.file(upload_file)
                ),
                tostring(real_begin)
            )
        end
    end

    socket.BLOCKSIZE = 8192  -- restore default

    local end_at = socket.gettime()
    local size_download = tonumber(resource_size) - tonumber(real_begin)
    if closed then
        return true, {
            resource_size = resource_size,
            start_pos = real_begin,
            size_download = size_download,
            speed_download = size_download / (end_at - begin_at),
        }
    end
    return false, "FTP download failed"
end

local function upload(upload_path, dest_url, req_timeout, should_resume, info_callback, block_size)
    assert(type(upload_path) == "string", "ftp.upload: Argument #1 upload_path must be a string")
    assert(type(dest_url) == "string", "ftp.upload: Argument #2 dest_url must be a string")
    assert(req_timeout == nil or type(req_timeout) == 'number', 'ftp.upload: Argument #3 req_timeout must be a number')
    FTP.TIMEOUT = req_timeout or 10
    assert(should_resume == nil or type(should_resume) == 'boolean', 'ftp.upload: Argument #4 should_resume must be a boolean')
    should_resume = should_resume or false
    assert(info_callback == nil or type(info_callback) == 'function', 'ftp.upload: Argument #5 info_callback must be a function')  -- vscode: end
    assert(block_size == nil or type(block_size) == 'number', 'ftp.upload: Argument #6 block_size must be a number')
    socket.BLOCKSIZE = block_size or 8192

    local upload_file = io.open(upload_path, "rb")
    assert(upload_file, "Could not open " .. upload_path .. " for reading")

    local url = require("net.url")
    local parsed_url = url.parse(dest_url)
    local _ftp = ftp:new {
        host = parsed_url.host,
        port = parsed_url.port,
        uid = easy:unescape(parsed_url.user),
        pwd = easy:unescape(parsed_url.password),
    }

    local entire_size = upload_file:seek("end")
    local begin_offset = 0
    if should_resume then
        begin_offset = getftpsize(_ftp, parsed_url.path)
        if begin_offset then
            should_resume = begin_offset > 0
        else
            should_resume = false
        end
    end
    should_resume = should_resume and begin_offset < entire_size

    if should_resume then
        begin_offset = upload_file:seek("set", begin_offset)
    else
        begin_offset = upload_file:seek("set", 0)
    end

    local closed
    local begin_at = socket.gettime()
    local cmd
    if not should_resume then
        cmd = "STOR"  -- store, overwrite
    else
        cmd = "APPE"  -- append
    end

    closed = _ftp:put(
        parsed_url.path,
        ltn12.source.chain(
            ltn12.source.file(upload_file),
            stats(
                "sent",
                entire_size,
                begin_offset,
                info_callback
            )
        ),
        cmd
    )

    socket.BLOCKSIZE = 8192  -- restore default

    local end_at = socket.gettime()
    local size_upload = tonumber(entire_size) - tonumber(begin_offset)
    if closed then
        return true, {
            resource_size = entire_size,
            start_pos = begin_offset,
            size_upload = size_upload,
            speed_upload = size_upload / (end_at - begin_at),
        }
    end
    return false, "FTP upload failed"
end

return {
    new = function(...) return ftp:new(...) end;
    download = download,
    upload = upload,
}
