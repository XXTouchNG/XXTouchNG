thread = {}

-- $DOC_ROOT/Handbook/thread/thread.dispatch.html
function thread.dispatch(func, error_cb) end

-- $DOC_ROOT/Handbook/thread/thread.current_id.html
function thread.current_id() end

-- $DOC_ROOT/Handbook/thread/thread.kill.html
function thread.kill(tid) end

-- $DOC_ROOT/Handbook/thread/thread.wait.html
function thread.wait(tid, timeout) end