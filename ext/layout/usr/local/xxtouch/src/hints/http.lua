http = {}

-- $DOC_ROOT/Handbook/http/http.get.html
function http.get(url, timeout, headers) end

-- $DOC_ROOT/Handbook/http/http.post.html
function http.post(url, timeout, headers, data) end

-- $DOC_ROOT/Handbook/http/http.download.html
function http.download(url, path, timeout, resume, receive_cb, bufsiz) end

-- $DOC_ROOT/Handbook/http/http.head.html
function http.head(url, timeout, headers) end

-- $DOC_ROOT/Handbook/http/http.delete.html
function http.delete(url, timeout, headers) end

-- $DOC_ROOT/Handbook/http/http.put.html
function http.put(url, timeout, headers, data) end