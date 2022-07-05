$(document).ready(function() {
    $("#main-drawer a[href='./startup_conf.html']").addClass("mdui-list-item-active");
    $("#main-drawer div[class='mdui-collapse-item']:eq(0)").addClass("mdui-collapse-item-open");
    $.post("/get_startup_conf", "", function(cfg) {
        if (cfg.code == 0) {
            $("#bootscript").attr("checked", cfg.data.startup_run);
            $("#bootscript").on("click", function() {
                switch (this.checked) {
                    case true:
                        $.post("set_startup_run_on", "", function() {}).error(function() {
                            this.checked != this.checked;
                            mdui.snackbar({
                                message: "与设备通讯无法达成"
                            })
                        });
                        break;
                    case false:
                        $.post("set_startup_run_off", "", function() {}).error(function() {
                            this.checked != this.checked;
                            mdui.snackbar({
                                message: "与设备通讯无法达成"
                            })
                        });
                        break
                }
            });
            $.post("/file_list?" + (new Date().getTime()).toString(), JSON.stringify({
                "directory": "lua/scripts"
            }), function(data) {
                var file_list = [];
                $.each(data.data.list, function(index, fileinfo) {
                    if (fileinfo.name != "." && fileinfo.name != "..") {
                        file_list.push({
                            name: fileinfo.name,
                            mode: fileinfo.mode,
                            change: fileinfo.change
                        })
                    }
                });
                file_list.sort(function(a, b) {
                    return b.change - a.change
                });
                $("#script-list").empty();
                $.each(file_list, function(index, file) {
                    var t_item = $('<li class="mdui-list-item mdui-ripple"></li>');
                    var t_name = $('<div class="mdui-list-item-content">' + file.name + "</div>");
                    var t_radio;
                    if (cfg.data.startup_script == file.name) {
                        t_radio = $('<input type="radio" name="script-file" checked/>')
                    } else {
                        t_radio = $('<input type="radio" name="script-file"/>')
                    }
                    t_item.append(t_name, $('<label class="mdui-radio"></label>').append(t_radio, '<i class="mdui-radio-icon"></i>'));
                    t_radio.click(function() {
                        $.post("select_startup_script_file", '{"filename":"' + file.name + '"}', function() {}).error(function() {
                            mdui.snackbar({
                                message: "与设备通讯无法达成"
                            })
                        })
                    });
                    if (file.mode == "file") {
                        strtype = file.name.split(".").pop().toLowerCase();
                        switch (strtype) {
                            case "lua":
                                $("#script-list").append(t_item);
                                break;
                            case "xxt":
                                $("#script-list").append(t_item);
                                break;
                            default:
                                break
                        }
                    }
                })
            }, "json").error(function() {
                mdui.snackbar({
                    message: "与设备通讯无法达成"
                })
            })
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