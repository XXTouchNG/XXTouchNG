-- This is a compatibility layer for the legacy XXTouch library.
do
    local proc = require "proc"
    proc_put = proc.put
    proc_get = proc.get
    proc_queue_push = proc.queue_push_back
    proc_queue_pop = proc.queue_pop_back
    proc_queue_clear = proc.queue_clear
    proc_queue_size = proc.queue_size
    proc_queue_push_front = proc.queue_push_front
    proc_queue_push_back = proc.queue_push_back
    proc_queue_pop_front = proc.queue_pop_front
    proc_queue_pop_back = proc.queue_pop_back
end
