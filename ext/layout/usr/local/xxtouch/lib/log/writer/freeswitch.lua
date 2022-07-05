local log = require "log"

local freeswitch = assert(freeswitch)

local FS_LVL = {
  console = 0;
  alert   = 1;
  crit    = 2;
  err     = 3;
  warning = 4;
  notice  = 5;
  info    = 6;
  debug   = 7;
}

local LOG2FS = {
  [ log.LVL.EMERG   ]  = FS_LVL.alert;
  [ log.LVL.ALERT   ]  = FS_LVL.alert;
  [ log.LVL.FATAL   ]  = FS_LVL.crit;
  [ log.LVL.ERROR   ]  = FS_LVL.err;
  [ log.LVL.WARNING ]  = FS_LVL.warning;
  [ log.LVL.NOTICE  ]  = FS_LVL.notice;
  [ log.LVL.INFO    ]  = FS_LVL.info;
  [ log.LVL.DEBUG   ]  = FS_LVL.debug;
  [ log.LVL.TRACE   ]  = FS_LVL.debug;
}

local M = {}

function M.new(session)
  if session then
    return function(fmt, msg, lvl, now)
      session:consoleLog( LOG2FS[lvl], msg .. '\n' )
    end
  else
    return function(fmt, msg, lvl, now)
      freeswitch.consoleLog( LOG2FS[lvl], msg .. '\n' )
    end
  end
end

return M
