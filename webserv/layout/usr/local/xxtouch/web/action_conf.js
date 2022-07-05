$(document).ready(function() {
    $("#main-drawer a[href='./action_conf.html']").addClass(
            "mdui-list-item-active"
        ),
        $("#main-drawer div[class='mdui-collapse-item']:eq(0)").addClass(
            "mdui-collapse-item-open"
        );
    var a = function() {
        var a = function(a, b) {
                switch (b) {
                    case "0":
                        a.html("脚本启/停(有弹窗)");
                        break;
                    case "1":
                        a.html("脚本启/停");
                        break;
                    case "2":
                        a.html("无操作");
                }
                a.on("click", function() {
                    var b = this.id;
                    mdui.dialog({
                        title: "设置启动方式",
                        content: "脚本启/停(有弹窗): 会弹出一个选择框,进行选择操作方法.<br>脚本启/停: 会直接启动停止脚本.<br>无动作: 不会有任何响应.",
                        stackedButtons: !0,
                        buttons: [{
                                text: "脚本启/停(有弹窗)",
                                onClick: function() {
                                    $.post("set_" + b + "_action", "0", function() {
                                        a.html("脚本启/停(有弹窗)");
                                    }).error(function() {
                                        mdui.snackbar({
                                            message: "与设备通讯无法达成"
                                        });
                                    });
                                },
                            },
                            {
                                text: "脚本启/停",
                                onClick: function() {
                                    $.post("set_" + b + "_action", "1", function() {
                                        a.html("脚本启/停");
                                    }).error(function() {
                                        mdui.snackbar({
                                            message: "与设备通讯无法达成"
                                        });
                                    });
                                },
                            },
                            {
                                text: "无操作",
                                onClick: function() {
                                    $.post("set_" + b + "_action", "2", function() {
                                        a.html("无操作");
                                    }).error(function() {
                                        mdui.snackbar({
                                            message: "与设备通讯无法达成"
                                        });
                                    });
                                },
                            },
                        ],
                    });
                });
            },
            b = function(a, b) {
                switch (b) {
                    case !0:
                        a.html("已启动");
                        break;
                    case !1:
                        a.html("已关闭");
                }
                a.on("click", function() {
                    var b = this.id,
                        c = "";
                    (c =
                        "record_volume_up" == b ?
                        "“音量 +” 事件也会被录制." :
                        "“音量 -” 事件也会被录制."),
                    mdui.dialog({
                        title: "设置录制按钮",
                        content: c,
                        stackedButtons: !0,
                        buttons: [{
                                text: "开启",
                                onClick: function() {
                                    $.post("set_" + b + "_on", "", function() {
                                        a.html("已开启");
                                    }).error(function() {
                                        mdui.snackbar({
                                            message: "与设备通讯无法达成"
                                        });
                                    });
                                },
                            },
                            {
                                text: "关闭",
                                onClick: function() {
                                    $.post("set_" + b + "_off", "", function() {
                                        a.html("已关闭");
                                    }).error(function() {
                                        mdui.snackbar({
                                            message: "与设备通讯无法达成"
                                        });
                                    });
                                },
                            },
                        ],
                    });
                });
            };
        $.post(
            "/get_record_conf",
            "",
            function(c) {
                0 == c.code ?
                    (b($("#record_volume_up"), c.data.record_volume_up),
                        b($("#record_volume_down"), c.data.record_volume_down),
                        $.post(
                            "/get_volume_action_conf",
                            "",
                            function(b) {
                                0 == b.code ?
                                    (a($("#hold_volume_up"), b.data.hold_volume_up),
                                        a($("#hold_volume_down"), b.data.hold_volume_down),
                                        a($("#click_volume_up"), b.data.click_volume_up),
                                        a($("#click_volume_down"), b.data.click_volume_down)) :
                                    mdui.snackbar({
                                        message: b.message
                                    });
                            },
                            "json"
                        ).error(function() {
                            mdui.snackbar({
                                message: "与设备通讯无法达成"
                            });
                        })) :
                    mdui.snackbar({
                        message: c.message
                    });
            },
            "json"
        ).error(function() {
            mdui.snackbar({
                message: "与设备通讯无法达成"
            });
        });
    };
    a();
});