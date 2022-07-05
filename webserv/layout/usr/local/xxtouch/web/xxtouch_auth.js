$(document).ready(function() {
    var a, b;
    $("#main-drawer a[href='./xxtouch_auth.html']").addClass("mdui-list-item-active"), a = function() {
        $.post("/device_auth_info", "", function(a) {
            if (0 == a.code)
                if (a.data.expireDate > 0 && a.data.expireDate > a.data.nowDate) {
                    var b = new Date;
                    b.setTime(1e3 * a.data.expireDate), $("#time-out").html(b.toLocaleString())
                } else $("#time-out").html("已到期");
            else mdui.snackbar({
                message: a.message
            })
        }, "json").error(function() {
            mdui.snackbar({
                message: "与设备通讯无法达成"
            })
        })
    }, b = function(a) {
        var c, b = a.toUpperCase().replace(/ /g, "");
        if ($("#display-code").html(b.replace(/(....)(?=.)/g, "$1 ")), "" == b) return $("#input-error").css({
            visibility: "hidden"
        }), !1;
        if (c = /^[3-9a-zA-Z]{1,}$/, c.test(b))
            if (b.length < 10) $("#input-error").html("授权码长度不满限制长度"), $("#input-error").css({
                visibility: "visible"
            });
            else {
                if (!(b.length > 20)) return $("#input-error").css({
                    visibility: "hidden"
                }), !0;
                $("#input-error").html("授权码长度超过限制长度"), $("#input-error").css({
                    visibility: "visible"
                })
            }
        else $("#input-error").html("授权码只（能）包含数字 3 至 9 及大小写字母"), $("#input-error").css({
            visibility: "visible"
        });
        return !1
    }, $("#auth-code").on("input", function() {
        b($("#auth-code").val())
    }), $("#auth-submit").on("click", function() {
        if ("" == $("#auth-code").val()) return $("#input-error").html("授权码长度不满限制长度"), $("#input-error").css({
            visibility: "visible"
        }), void 0;
        if (b($("#auth-code").val())) {
            var c = $("#auth-code").val().toUpperCase().replace(/ /g, "");
            $.post("/bind_code", {
                code: c,
                mustbeless: $("#check_overstep").is(":checked") ? 0 : 604800
            }, function(b) {
                var e, f, c = "",
                    d = b.message;
                switch (b.code) {
                    case 0:
                        $("#auth-code").val(""), e = "", f = b.data.expireDate - b.data.nowDate, f /= 3600, f >= 24 && (e = e + (f / 24).toString() + "天"), 0 != f % 24 && (e = e + (f % 24).toString() + "小时"), c = "授权续费成功", a();
                        break;
                    case 1:
                        c = "授权续费失败.";
                        break;
                    case -1:
                        c = "授权续费失败";
                        break;
                    case -2:
                        c = "授权续费失败";
                        break;
                    case 112:
                        c = "授权续费失败";
                        break;
                    case 113:
                        c = "授权续费失败";
                        break;
                    default:
                        c = "授权续费失败."
                }
                mdui.dialog({
                    title: c,
                    content: d,
                    buttons: [{
                        text: "确认"
                    }]
                })
            }, "json").error(function() {
                mdui.snackbar({
                    message: "与设备通讯无法达成"
                })
            })
        }
    }), a(), $("#refresh").click(a), $.post("/deviceinfo", "", function(a) {
        0 == a.code ? ($("#devsn").html(a.data.devsn), $("#zeversion").html(a.data.zeversion), $("#sysversion").html(a.data.sysversion), $("#devname").html(a.data.devname), $("#devmac").html(a.data.devmac), $("#deviceid").html(a.data.deviceid), $("#devtype").html(a.data.devtype), $("#webserver_url").html(a.data.webserver_url), $("#bonjour_webserver_url").html(a.data.bonjour_webserver_url), $("#devsn").parent().parent().attr("data-clipboard-text", a.data.devsn), $("#zeversion").parent().parent().attr("data-clipboard-text", a.data.zeversion), $("#sysversion").parent().parent().attr("data-clipboard-text", a.data.sysversion), $("#devname").parent().parent().attr("data-clipboard-text", a.data.devname), $("#devmac").parent().parent().attr("data-clipboard-text", a.data.devmac), $("#deviceid").parent().parent().attr("data-clipboard-text", a.data.deviceid), $("#devtype").parent().parent().attr("data-clipboard-text", a.data.devtype), $("#webserver_url").parent().parent().attr("data-clipboard-text", a.data.webserver_url), $("#bonjour_webserver_url").parent().parent().attr("data-clipboard-text", a.data.bonjour_webserver_url)) : mdui.snackbar({
            message: a.message
        });
        var b = new Clipboard(".mdui-list-item");
        b.on("success", function() {
            mdui.snackbar({
                message: "复制成功"
            })
        }), b.on("error", function() {
            mdui.snackbar({
                message: "复制失败，请手动复制"
            })
        })
    }, "json").error(function() {
        mdui.snackbar({
            message: "与设备通讯无法达成"
        })
    })
});