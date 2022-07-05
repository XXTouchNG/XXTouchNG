$(document).ready(function() {
    $("#main-drawer a[href='./user_conf.html']").addClass("mdui-list-item-active");
    $("#main-drawer div[class='mdui-collapse-item']:eq(0)").addClass("mdui-collapse-item-open");
    var submit_cfg = function() {
        $.post("/set_user_conf", JSON.stringify({
            no_idle: $("#no_idle").is(":checked"),
            script_on_daemon: $("#script_on_daemon").is(":checked"),
            script_end_hint: $("#script_end_hint").is(":checked"),
            use_classic_control_alert: $("#use_classic_control_alert").is(":checked"),
            no_nosim_alert: $("#no_nosim_alert").is(":checked"),
            no_nosim_statusbar: $("#no_nosim_statusbar").is(":checked"),
            no_low_power_alert: $("#no_low_power_alert").is(":checked"),
            no_need_pushid_alert: $("#no_need_pushid_alert").is(":checked")
        }), function(cfg) {
            if (cfg.data != 0) {
                mdui.snackbar({
                    message: cfg.message
                })
            }
        }, "json").error(function() {
            this.checked != this.checked;
            mdui.snackbar({
                message: "与设备通讯无法达成"
            })
        })
    };
    $.post("/get_user_conf", "", function(cfg) {
        if (cfg.code == 0) {
            t_cfg = cfg.data;
            $("#no_idle").attr("checked", cfg.data.no_idle);
            $("#script_on_daemon").attr("checked", cfg.data.script_on_daemon);
            $("#script_end_hint").attr("checked", cfg.data.script_end_hint);
            $("#use_classic_control_alert").attr("checked", cfg.data.use_classic_control_alert);
            $("#no_nosim_alert").attr("checked", cfg.data.no_nosim_alert);
            $("#no_nosim_statusbar").attr("checked", cfg.data.no_nosim_statusbar);
            $("#no_low_power_alert").attr("checked", cfg.data.no_low_power_alert);
            $("#no_need_pushid_alert").attr("checked", cfg.data.no_need_pushid_alert);
            $("#no_idle").on("click", submit_cfg);
            $("#script_on_daemon").on("click", submit_cfg);
            $("#script_end_hint").on("click", submit_cfg);
            $("#use_classic_control_alert").on("click", submit_cfg);
            $("#no_nosim_alert").on("click", submit_cfg);
            $("#no_nosim_statusbar").on("click", submit_cfg);
            $("#no_low_power_alert").on("click", submit_cfg);
            $("#no_need_pushid_alert").on("click", submit_cfg)
        } else {
            mdui.snackbar({
                message: cfg.message
            })
        }
    }, "json").error(function() {
        mdui.snackbar({
            message: "与设备通讯无法达成"
        })
    })
});