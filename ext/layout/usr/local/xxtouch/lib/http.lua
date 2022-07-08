-- This is a compatibility layer for the legacy XXTouch library.
-- This library does not support coroutines.
-- See copas/http.lua for an example of how to use coroutines.

local socket = require("socket")
local ltn12 = require("ltn12")
local url = require("socket.url")
local curl = require("lcurl")
local lfs = require("lfs")
local date = require("date")
local json = require("cjson")
local easy = curl.easy {}

local _M = require("socket.http")

_M.head = function (req_url, req_timeout, req_headers)
    assert(type(req_url) == 'string', 'http.head: Argument #1 req_url must be a string')
    assert(req_timeout == nil or type(req_timeout) == 'number', 'http.head: Argument #2 req_timeout must be a number')
    _M.TIMEOUT = req_timeout or 10
    assert(req_headers == nil or type(req_headers) == 'table', 'http.head: Argument #3 req_headers must be a table')
    req_headers = req_headers or {}
    local _, resp_code, resp_headers = _M.request {
        url = req_url,
        sink = ltn12.sink.null(),
        method = "HEAD",
        headers = req_headers
    }
    if resp_headers ~= nil then
        json = require "json"
        resp_headers = json.encode(resp_headers)
    end
    return resp_code, resp_headers
end

_M.get = function (req_url, req_timeout, req_headers)
    assert(type(req_url) == 'string', 'http.get: Argument #1 req_url must be a string')
    assert(req_timeout == nil or type(req_timeout) == 'number', 'http.get: Argument #2 req_timeout must be a number')
    _M.TIMEOUT = req_timeout or 10
    assert(req_headers == nil or type(req_headers) == 'table', 'http.get: Argument #3 req_headers must be a table')
    req_headers = req_headers or {}
    local t = {}
    local _, resp_code, resp_headers = _M.request {
        url = req_url,
        sink = ltn12.sink.table(t),
        method = "GET",
        headers = req_headers
    }
    if resp_headers ~= nil then
        json = require "json"
        resp_headers = json.encode(resp_headers)
    end
    return resp_code, resp_headers, table.concat(t)
end

_M.delete = function (req_url, req_timeout, req_headers)
    assert(type(req_url) == 'string', 'http.delete: Argument #1 req_url must be a string')
    assert(req_timeout == nil or type(req_timeout) == 'number', 'http.delete: Argument #2 req_timeout must be a number')
    _M.TIMEOUT = req_timeout or 10
    assert(req_headers == nil or type(req_headers) == 'table', 'http.delete: Argument #3 req_headers must be a table')
    req_headers = req_headers or {}
    local t = {}
    local _, resp_code, resp_headers = _M.request {
        url = req_url,
        sink = ltn12.sink.table(t),
        method = "DELETE",
        headers = req_headers
    }
    if resp_headers ~= nil then
        json = require "json"
        resp_headers = json.encode(resp_headers)
    end
    return resp_code, resp_headers, table.concat(t)
end

_M.post = function (req_url, req_timeout, req_headers, req_body)
    assert(type(req_url) == 'string', 'http.post: Argument #1 req_url must be a string')
    assert(req_timeout == nil or type(req_timeout) == 'number', 'http.post: Argument #2 req_timeout must be a number')
    _M.TIMEOUT = req_timeout or 10
    assert(req_headers == nil or type(req_headers) == 'table' or type(req_headers) == 'string', 'http.post: Argument #3 req_headers must be a table')
    req_headers = req_headers or {}
    if type(req_headers) == 'string' then
        req_headers = json.decode(req_headers)
    end
    assert(req_body == nil or type(req_body) == 'string', 'http.post: Argument #4 req_body must be a string')
    req_body = req_body or ""
    local t = {}
    if req_headers["content-type"] == nil then
        req_headers["content-type"] = "application/x-www-form-urlencoded"
    end
    req_headers["content-length"] = string.len(req_body)
    local _, resp_code, resp_headers = _M.request {
        url = req_url,
        source = ltn12.source.string(req_body),
        sink = ltn12.sink.table(t),
        method = "POST",
        headers = req_headers
    }
    if resp_headers ~= nil then
        json = require "json"
        resp_headers = json.encode(resp_headers)
    end
    return resp_code, resp_headers, table.concat(t)
end

_M.put = function (req_url, req_timeout, req_headers, req_body)
    assert(type(req_url) == 'string', 'http.put: Argument #1 req_url must be a string')
    assert(req_timeout == nil or type(req_timeout) == 'number', 'http.put: Argument #2 req_timeout must be a number')
    _M.TIMEOUT = req_timeout or 10
    assert(req_headers == nil or type(req_headers) == 'table', 'http.put: Argument #3 req_headers must be a table')
    req_headers = req_headers or {}
    assert(req_body == nil or type(req_body) == 'string', 'http.put: Argument #4 req_body must be a string')
    req_body = req_body or ""
    local t = {}
    if req_headers["content-type"] == nil then
        req_headers["content-type"] = "application/x-www-form-urlencoded"
    end
    req_headers["content-length"] = string.len(req_body)
    local _, resp_code, resp_headers = _M.request {
        url = req_url,
        source = ltn12.source.string(req_body),
        sink = ltn12.sink.table(t),
        method = "PUT",
        headers = req_headers
    }
    if resp_headers ~= nil then
        json = require "json"
        resp_headers = json.encode(resp_headers)
    end
    return resp_code, resp_headers, table.concat(t)
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
local remaining_s = "%s received, %s/s throughput, %2.0f%% done, %s remaining"
local elapsed_s =   "%s received, %s/s throughput, %s elapsed                "
local function gauge(got, delta, size)
    local rate = got / delta
    if size and size >= 1 then
        return string.format(remaining_s, nicesize(got), nicesize(rate),
            100*got/size, nicetime((size-got)/rate))
    else
        return string.format(elapsed_s, nicesize(got),
            nicesize(rate), nicetime(delta))
    end
end

-- creates a new instance of a receive_cb that saves to disk
-- kind of copied from luasocket's manual callback examples
local function stats(resource_size, already_download, receive_cb)
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
                io.stderr:write("\r", gauge(size_download, current - start, resource_size))
                io.stderr:flush()
                last = current
            end
        else
            -- close up
            io.stderr:write("\r", gauge(size_download, current - start), "\n")
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

-- determines the size of a http file
local function gethttpsize(u, if_range, begin_from)
    begin_from = begin_from or 0
    local r, c, h = _M.request {
        url = u,
        method = "HEAD",
        headers = {
            --["if-range"] = if_range,
            ["range"] = "bytes=" .. tostring(begin_from) .. "-",
        }
    }
    h = h or {}
    if c == 200 then
        local total_size = h["content-length"]
        return tonumber(total_size), false, 0
    elseif c == 206 then
        local content_range = h["content-range"]
        io.stderr:write("content-range: ", content_range, "\n")
        local seek_begin = 0, total_size
        if content_range ~= nil then
            seek_begin = tonumber(content_range:match("bytes (%d+)-"))
            total_size = content_range:sub(content_range:find("/") + 1)
            assert(total_size ~= '*', "content-range: * is not supported")
        else
            total_size = h["content-length"]
        end
        return tonumber(total_size), h["accept-ranges"] == "bytes", seek_begin
    end
end

_M.download = function (req_url, output_path, req_timeout, should_resume, info_callback, block_size)
    assert(type(req_url) == 'string', 'http.download: Argument #1 req_url must be a string')
    assert(type(output_path) == 'string', 'http.download: Argument #2 output_path must be a string')
    assert(req_timeout == nil or type(req_timeout) == 'number', 'http.download: Argument #3 req_timeout must be a number')
    _M.TIMEOUT = req_timeout or 10
    assert(should_resume == nil or type(should_resume) == 'boolean', 'http.download: Argument #4 should_resume must be a boolean')
    should_resume = should_resume or false
    assert(info_callback == nil or type(info_callback) == 'function', 'http.download: Argument #5 info_callback must be a function')  -- vscode: end
    assert(block_size == nil or type(block_size) == 'number', 'http.download: Argument #6 block_size must be a number')
    socket.BLOCKSIZE = block_size or 8192
    
    local open_flags
    if should_resume then
        open_flags = "a+b"  -- append mode
    else
        open_flags = "wb"   -- write mode
    end

    local output_file = io.open(output_path, open_flags)
    assert(output_file, "Could not open " .. output_path .. " for writing")

    local begin_size = output_file:seek("end")
    local real_begin = begin_size
    if begin_size > socket.BLOCKSIZE then
        real_begin = begin_size - socket.BLOCKSIZE * 2  -- make sure we have some space to write to
    end
    should_resume = should_resume and begin_size > 0

    local modification_stamp = lfs.attributes(output_path, "modification")
    local if_range = date(modification_stamp):fmt("${rfc1123}")
    local resource_size, supports_resume
    resource_size, supports_resume, real_begin = gethttpsize(req_url, if_range, real_begin)
    if should_resume and (not supports_resume) then
        io.stderr:write("WARN: server does not support resume, will start from scratch\n")
        output_file:close()
        os.remove(output_path)
        output_file = io.open(output_path, "wb")
    end
    if should_resume and supports_resume then
        output_file:close()
        output_file = io.open(output_path, "r+b")  -- why do not keep using "a+": writing is only allowed at the end of file.
        real_begin = output_file:seek("set", real_begin)
        io.stderr:write("INFO: server supports resume, will resume download from " .. tostring(begin_size) .. tostring(real_begin - begin_size) .. " bytes\n")
    end
    
    local begin_at = socket.gettime()
    local _, resp_code, resp_headers
    if real_begin >= resource_size then
        io.stderr:write("INFO: file already completely downloaded, will not download again\n")
    else
        if (not should_resume) or (not supports_resume) then
            _, resp_code, resp_headers = _M.request {
                url = req_url,
                sink = ltn12.sink.chain(
                    stats(
                        resource_size,
                        0,
                        info_callback
                    ),
                    ltn12.sink.file(output_file)
                ),
                method = "GET"
            }
        else
            _, resp_code, resp_headers = _M.request {
                url = req_url,
                sink = ltn12.sink.chain(
                    stats(
                        resource_size,
                        real_begin,
                        info_callback
                    ),
                    ltn12.sink.file(output_file)
                ),
                headers = { ["range"] = "bytes=" .. real_begin .. "-" },
                method = "GET"
            }
        end
    end

    resp_headers = resp_headers or {}
    socket.BLOCKSIZE = 8192  -- restore default

    local end_at = socket.gettime()
    local size_download = tonumber(resp_headers["content-length"]) or 0
    if type(resp_code) == 'number' and resp_code >= 200 and resp_code <= 299 then
        if resp_headers["last-modified"] ~= nil then
            local last_modified = resp_headers["last-modified"]
            local last_modified_stamp = date.diff(date(last_modified), date.epoch()):spanseconds()
            lfs.touch(output_path, last_modified_stamp, last_modified_stamp)
        end
        return true, {
            resource_size = resource_size,
            start_pos = real_begin,
            size_download = size_download,
            speed_download = size_download / (end_at - begin_at),
        }
    end
    return false, resp_code
end

return _M
