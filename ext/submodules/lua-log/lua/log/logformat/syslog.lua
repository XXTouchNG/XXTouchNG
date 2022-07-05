local string = require "string"
local math   = require "math"
local Log    = require "log"

local mod,floor,ceil,abs,pow = math.fmod,math.floor,math.ceil,math.abs,math.pow
local fmt = string.format

-- removes the decimal part of a number
local function fix(n) n = tonumber(n) return n and ((n > 0 and floor or ceil)(n)) end
local function lshift(a,b) return a * math.pow(2, b) end

--[[ RFC5424 
  0       Emergency: system is unusable
  1       Alert: action must be taken immediately
  2       Critical: critical conditions
  3       Error: error conditions
  4       Warning: warning conditions
  5       Notice: normal but significant condition
  6       Informational: informational messages
  7       Debug: debug-level messages
--]]
local SEVERITY = {
  EMERG   = 0;
  ALERT   = 1;
  CRIT    = 2;
  ERR     = 3;
  WARNING = 4;
  NOTICE  = 5;
  INFO    = 6;
  DEBUG   = 7;
}

--[[ RFC5424 
  0             kernel messages
  1             user-level messages
  2             mail system
  3             system daemons
  4             security/authorization messages
  5             messages generated internally by syslogd
  6             line printer subsystem
  7             network news subsystem
  8             UUCP subsystem
  9             clock daemon
 10             security/authorization messages
 11             FTP daemon
 12             NTP subsystem
 13             log audit
 14             log alert
 15             clock daemon (note 2)
 16             local use 0  (local0)
 17             local use 1  (local1)
 18             local use 2  (local2)
 19             local use 3  (local3)
 20             local use 4  (local4)
 21             local use 5  (local5)
 22             local use 6  (local6)
 23             local use 7  (local7)
--]]
local FACILITY = {
  KERN     = lshift (0, 3); 
  USER     = lshift (1, 3); 
  MAIL     = lshift (2, 3); 
  DAEMON   = lshift (3, 3);
  AUTH     = lshift (4, 3);
  SYSLOG   = lshift (5, 3);
  LPR      = lshift (6, 3);
  NEWS     = lshift (7, 3);
  UUCP     = lshift (8, 3);
  CRON     = lshift (9, 3); CLKD   = lshift (9, 3);
  AUTHPRIV = lshift(10, 3); 
  FTP      = lshift(11, 3); 
  NTP      = lshift(12, 3); 
  SECURITY = lshift(13, 3); AUDIT  = lshift(13, 3);
  CONSOLE  = lshift(14, 3); ALERT  = lshift(14, 3);
                            CLKD2  = lshift(15, 3);
  LOCAL0   = lshift(16, 3);
  LOCAL1   = lshift(17, 3);
  LOCAL2   = lshift(18, 3);
  LOCAL3   = lshift(19, 3);
  LOCAL4   = lshift(20, 3);
  LOCAL5   = lshift(21, 3);
  LOCAL6   = lshift(22, 3);
  LOCAL7   = lshift(23, 3);
}

local LVL2SYSLOG = {
  [ Log.LVL.EMERG     ] = SEVERITY.EMERG;
  [ Log.LVL.ALERT     ] = SEVERITY.ALERT;
  [ Log.LVL.FATAL     ] = SEVERITY.CRIT;
  [ Log.LVL.ERROR     ] = SEVERITY.ERR;
  [ Log.LVL.WARNING   ] = SEVERITY.WARNING;
  [ Log.LVL.NOTICE    ] = SEVERITY.NOTICE;
  [ Log.LVL.INFO      ] = SEVERITY.INFO;
  [ Log.LVL.DEBUG     ] = SEVERITY.DEBUG;
  [ Log.LVL.TRACE     ] = SEVERITY.DEBUG;
}

local function Date2SysLog(now)
  local Y, M, D = now:getdate()
  local h, m, s = now:gettime()

  local b = -now:getbias(); 
  local x = abs(b); 

  return fmt("%.4d-%.2d-%.2dT%.2d:%.2d:%.2d%s%.2d:%.2d", Y, M, D, h, m, s,
    b < 0 and "-" or "+", fix(x/60), floor(mod(x,60))
  )
end

local M = {}

function M.new(facility, host_name, app_name, procid, msgid)
  if not facility then facility = FACILITY.USER
  else facility = FACILITY[facility:upper()] end
  host_name = host_name or '-'
  app_name  = app_name  or '-'
  procid    = procid    or '-'
  msgid     = msgid     or '-'

  -- HOSTNAME APP-NAME PROCID MSGID
  local header =host_name .. ' ' .. app_name .. ' ' .. procid .. ' ' .. msgid 

  return function (msg, lvl, now)
    local slvl = assert(LVL2SYSLOG[lvl])
    return 
    -- HEADER
      -- PRI VERSION TIMESTAMP
      '<' .. slvl + facility .. '>1 ' .. Date2SysLog(now) .. ' ' ..
      -- HEADER STRUCTURED-DATA MSG
      header .. ' - ' ..  msg
    
  end
end

return M
