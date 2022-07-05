function Str2Bytes(a) {
    var d, e, f, g, b = 0,
        c = a.length;
    if (0 != c % 4) return null;
    for (c /= 4, d = new Array, e = 0; c > e; e++) {
        if (f = a.substr(b, 4), "\\x" != f.substr(0, 2)) return null;
        f = f.substr(2, 2), g = parseInt(f, 16), d.push(g), b += 4
    }
    return d
}
$(document).ready(function() {
    var a, e, f, g, h, i, b = CodeMirror.fromTextArea(document.getElementById("debug_textArea"), {
            lineWrapping: !1,
            matchBrackets: !0,
            indentUnit: 4,
            tabSize: 4,
            theme: "base16-dark",
            styleActiveLine: !0,
            scrollbarStyle: "simple"
        }),
        c = function(c) {
            var d = "file_textarea";
            c && (document.getElementById(d).innerHTML = c), a = CodeMirror.fromTextArea(document.getElementById("file_textarea"), {
                lineNumbers: !0,
                lineWrapping: !1,
                matchBrackets: !0,
                indentUnit: 4,
                tabSize: 4,
                theme: "base16-dark",
                styleActiveLine: !0,
                scrollbarStyle: "simple",
                highlightSelectionMatches: {
                    showToken: /\w/,
                    annotateScrollbar: !0
                },
                mode: {
                    name: "lua",
                    lobalVars: !0
                },
                extraKeys: {
                    "Ctrl-Q": "autocomplete",
                    "Ctrl-S": function() {
                        e()
                    },
                    "Ctrl-Z": function(a) {
                        a.undo()
                    },
                    "Ctrl-Y": function(a) {
                        a.redo()
                    },
                    "Cmd-S": function() {
                        e()
                    },
                    "Cmd-Z": function(a) {
                        a.undo()
                    },
                    "Cmd-Y": function(a) {
                        a.redo()
                    }
                }
            }), a.setSize("auto", $(window).height() - 375 + "px"), b.setSize("auto", "255px"), $(window).resize(function() {
                a.setSize("auto", $(window).height() - 375 + "px"), $(window).height() < 600
            }), $("#path-file-undo").on("click", function() {
                a.undo()
            }), $("#path-file-redo").on("click", function() {
                a.redo()
            }), $("#path-file-save").on("click", function() {
                e()
            })
        },
        d = $.req("file");
    d ? ($("#path-file")[0].innerHTML = "编辑 " + d, $.post("/read_file", JSON.stringify({
        filename: d
    }), function(a) {
        var b, e;
        0 == a.code ? (b = d.split(".").pop().toLowerCase(), e = Base64.decode(a.data), c(e, b)) : (mdui.snackbar({
            message: a.message
        }), c())
    }, "json").error(function() {
        mdui.snackbar({
            message: "与设备通讯无法达成"
        }), c()
    })) : ($("#path-file")[0].innerHTML = "异常", c()), e = function() {
        d && "" != d && $.post("/write_file", JSON.stringify({
            filename: d,
            data: Base64.encode(a.getValue())
        }), function(a) {
            0 == a.code ? f("保存成功") : mdui.snackbar({
                message: a.message
            })
        }, "json").error(function() {
            mdui.snackbar({
                message: "与设备通讯无法达成"
            })
        })
    }, $("#launch-script-file").on("click", function() {
        $.post("/write_file", JSON.stringify({
            filename: d,
            data: Base64.encode(a.getValue())
        }), function(b) {
            0 == b.code ? (f("保存成功"), $.post("/check_syntax", a.getValue(), function(a) {
                const script_content = `do
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
dofile("/var/mobile/Media/1ferver/${d}")`;
                0 != a.code ? f("脚本存在语法错误:" + a.detail) : $.post("/spawn", script_content, function(a) {
                    f(a.message)
                }, "json").error(function() {
                    mdui.snackbar({
                        message: "与设备通讯无法达成"
                    })
                })
            }, "json").error(function() {
                mdui.snackbar({
                    message: "与设备通讯无法达成"
                })
            })) : mdui.snackbar({
                message: b.message
            })
        }, "json").error(function() {
            mdui.snackbar({
                message: "与设备通讯无法达成"
            })
        })
    }), $("#recycle").on("click", function() {
        $.post("/recycle", "", function(a) {
            f(a.message)
        }, "json").error(function() {
            mdui.snackbar({
                message: "与设备通讯无法达成"
            })
        })
    }), f = function(a) {
        b.setValue(b.getValue() + a + "\n"), b.setSelection({
            line: b.lastLine(),
            ch: 0
        }, {
            line: b.lastLine(),
            ch: 0
        })
    }, g = null, h = document.domain, i = "ws://" + h + ":46957";
    try {
        "function" == typeof MozWebSocket && (WebSocket = MozWebSocket), g && 1 == g.readyState && g.close(), g = new WebSocket(i), g.onopen = function() {
            f("日志服务已连接")
        }, g.onclose = function() {
            f("日志服务已关闭")
        }, g.onmessage = function(a) {
            f(a.data)
        }, g.onerror = function() {
            f("日志服务出现错误")
        }
    } catch (j) {
        f("日志服务出现错误")
    }
});