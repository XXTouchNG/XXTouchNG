do
    -- Buld writer with 2 destinations
    local writer = require "log.writer.list".new(
        require "log.writer.format".new(
        -- explicit set logformat to stdout writer
        require "log.logformat.default".new(), 
        require "log.writer.stdout".new()
        ),
        -- define network writer.
        -- This writer has no explicit format so it will
        -- use one defined for logger.
        require "log.writer.net.udp".new('127.0.0.1', 46956)
    )
    
    local function SYSLOG_NEW(level, ...)
        return require "log".new(level, writer,
        require "log.formatter.mix".new(),
        require "log.logformat.syslog".new(...)
        )
    end
    
    local SYSLOG = {
        -- Define first syslog logger with some settings
        KERN = SYSLOG_NEW('trace', 'kern'),
        
        -- Define second syslog logger with other settings
        USER = SYSLOG_NEW('trace', 'USER'),
    }
    
    nLog = function (...)
        SYSLOG.KERN.info(...)
    end
end

-- use `websocat ws://{DEVICE_IP}:46957` to see the log output
nLog("test")
