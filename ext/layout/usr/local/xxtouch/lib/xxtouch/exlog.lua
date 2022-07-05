-- This is a replacement of sys.log and nLog from the legacy XXTouch library.
do
    LOG = require "log".new(
        -- Maximum log level
        "trace",
        
        -- Writer
        require 'log.writer.list'.new(                 -- multi writers:
            require 'log.writer.console.color'.new(),  -- * console color
            require 'log.writer.toolbar.color'.new(),  -- * toolbar color
            require 'log.writer.file.roll'.new(        -- * roll files
            '/usr/local/xxtouch/log',                  --   log dir
            'sys.log',                              --   current log name
            10,                                        --   count files
            10*1024*1024                               --   max file size in bytes
            )
        ),
        
        -- Formatter
        require "log.formatter.concat".new()
    )
    nLog = function(...)
        -- LOG.debug(...)
        -- By default, nLog does not log anything.
        -- To enable network logging, IDE must be configured to open an UDP server,
        -- then override the nLog function to send the log as UDP packet.
    end
end
