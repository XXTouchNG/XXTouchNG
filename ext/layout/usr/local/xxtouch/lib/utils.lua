-- This is a compatibility layer for the legacy XXTouch library.

local _M = {}
local image = require("image")

_M.qr_encode = image.qr_encode

_M.launch_args = function ()
    return {
        path = os.getenv("XXT_ENTRYPOINT"),
        type = os.getenv("XXT_ENTRYTYPE" ),
    }
end

_M.is_launch_via_app = function ()
    return os.getenv("XXT_ENTRYTYPE") == "application"
end

_M.paths = {}
_M.paths.MEDIA_ROOT            = "/var/mobile/Media/1ferver"
_M.paths.MEDIA_LUA_DIR         = "/var/mobile/Media/1ferver/lua"
_M.paths.MEDIA_LUA_SCRIPTS_DIR = "/var/mobile/Media/1ferver/lua/scripts"
_M.paths.MEDIA_BIN_DIR         = "/var/mobile/Media/1ferver/bin"
_M.paths.MEDIA_LIB_DIR         = "/var/mobile/Media/1ferver/lib"
_M.paths.MEDIA_LOG_DIR         = "/var/mobile/Media/1ferver/log"
_M.paths.MEDIA_CONF_DIR        = "/var/mobile/Media/1ferver/conf"
_M.paths.MEDIA_WEB_DIR         = "/var/mobile/Media/1ferver/web"
_M.paths.MEDIA_RES_DIR         = "/var/mobile/Media/1ferver/res"
_M.paths.MEDIA_CACHES_DIR      = "/var/mobile/Media/1ferver/caches"
_M.paths.MEDIA_SNIPPETS_DIR    = "/var/mobile/Media/1ferver/snippets"
_M.paths.MEDIA_UICFG_DIR       = "/var/mobile/Media/1ferver/uicfg"
_M.paths.MEDIA_TESSDATA_DIR    = "/var/mobile/Media/1ferver/tessdata"

_M.paths.LOG_SYS               = "/var/mobile/Media/1ferver/log/sys.log"
_M.paths.LOG_LAUNCHER_OUTPUT   = "/var/mobile/Media/1ferver/log/script_output.log"
_M.paths.LOG_LAUNCHER_ERROR    = "/var/mobile/Media/1ferver/log/script_error.log"
_M.paths.LOG_ALERT_HELPER_DIR  = "/var/mobile/Media/1ferver/log/ch.xxtou.AlertHelper"
_M.paths.LOG_TAMPER_MONKEY_DIR = "/var/mobile/Media/1ferver/log/ch.xxtou.TamperMonkey"

return _M
