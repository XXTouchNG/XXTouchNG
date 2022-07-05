ftp = {}

-- $DOC_ROOT/Handbook/ftp/ftp.download.html
function ftp.download(url, path, timeout, resume, receive_cb, bufsiz) end

-- $DOC_ROOT/Handbook/ftp/ftp.upload.html
function ftp.upload(path, url, timeout, resume, send_cb, bufsiz) end