$(document).ready(function() {
    function c() {
        $.post("/deviceinfo", "", function() {
            a.close()
        }, "json").error(function() {
            setTimeout(c, 3e3)
        })
    }
    var a, b, d;
    $("#main-drawer a[href='./xxtouch_service.html']").addClass("mdui-list-item-active"), a = new mdui.Dialog($('<div class="mdui-dialog" id="dialog"><div class="mdui-dialog-content"><div class="mdui-progress"><div class="mdui-progress-indeterminate"></div></div><br /><div class="mdui-text-center">正在处理中..</div></div></div>')), b = function(c) {
        c ? ($("#close-service").html("关闭远程操作"), $("#close-service").off("click"), $("#close-service").on("click", function() {
            a.open(), $.post("/close_remote_access", "", function(c) {
                mdui.snackbar({
                    message: c.message
                }), a.close(), b(!1)
            }, "json").error(function() {
                a.close(), mdui.snackbar({
                    message: "与设备通讯无法达成"
                })
            })
        })) : ($("#close-service").html("打开远程操作"), $("#close-service").off("click"), $("#close-service").on("click", function() {
            a.open(), $.post("/open_remote_access", "", function(c) {
                mdui.snackbar({
                    message: c.message
                }), a.close(), b(!0)
            }, "json").error(function() {
                a.close(), mdui.snackbar({
                    message: "与设备通讯无法达成"
                })
            })
        }))
    }, $.post("/is_remote_access_opened", "", function(a) {
        0 == a.code && ("local" == document.domain || "127.0.0.1" == document.domain ? b(a.data.opened) : a.data.opened && $("#close-service").on("click", function() {
            d("关闭远程服务", "如需下次连接需要在设备端进行打开，当前所有页面即将失效。", "close_remote_access", "")
        }))
    }, "json").error(function() {
        setTimeout(c, 3e3)
    }), d = function(b, c, d, e) {
        var f = function() {
            a.open(), $.post("/" + d, e, function(b) {
                mdui.snackbar({
                    message: b.message
                }), a.close()
            }, "json").error(function() {
                a.close(), mdui.snackbar({
                    message: "与设备通讯无法达成"
                })
            })
        };
        "" != b ? mdui.dialog({
            title: b,
            content: c,
            buttons: [{
                text: "取消"
            }, {
                text: "确认",
                onClick: function() {
                    setTimeout(f, 300)
                }
            }]
        }) : f()
    }, $("#uicache").click(function() {
        d("清理 UI 缓存", "清空当前 SpringBoard 上的缓存信息。", "uicache", "")
    }), $("#clear-gps").click(function() {
        d("清理 GPS 伪装信息", "清空之前所有应用的地址伪装信息。", "clear_gps", "")
    }), $("#clear-all").click(function() {
        mdui.prompt("删除可能会造成数据的丢失，此操作是不可逆转的<br>请输入“CLEAR”以继续清理。", "设备全清", function(a) {
            "CLEAR" == a.toUpperCase() && d("", "", "clear_all", "")
        }, function() {})
    }), $("#restart-service").click(function() {
        mdui.dialog({
            title: "重启服务",
            content: "XXTouch 服务进行重启",
            buttons: [{
                text: "取消"
            }, {
                text: "确认",
                onClick: function() {
                    a.open(), $.post("/restart", "", function() {
                        setTimeout(c, 5e3)
                    }, "json").error(function() {
                        a.close(), mdui.snackbar({
                            message: "与设备通讯无法达成"
                        })
                    })
                }
            }]
        })
    }), $("#halt-device").click(function() {
        d("", "", "halt", "")
    }), $("#restart-device").click(function() {
        d("", "", "reboot2", "")
    }), $("#respring-device").click(function() {
        d("", "", "respring", "")
    })
});