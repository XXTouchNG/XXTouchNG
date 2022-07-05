function clearapp(bid) {
    $.post(
        "/clear_app_data",
        JSON.stringify({
            bid: bid
        }),
        function(data) {
            mdui.snackbar({
                message: data.message
            });
        },
        "json"
    ).error(function() {
        mdui.snackbar({
            message: "与设备通讯无法达成"
        });
    });
}
$(document).ready(function() {
    $("#main-drawer a[href='./applist.html']").addClass("mdui-list-item-active");
    $.post(
        "/applist?" + new Date().getTime().toString(),
        "",
        function(cfg) {
            if (cfg.code == 0) {
                $("#app-list").empty();
                $.each(cfg.data, function(index, app) {
                    $("#app-list").append(
                        '<div class="mdui-panel-item"><div class="mdui-panel-item-header"><div class="mdui-list-item-avatar"><img src="data:image/png;base64,' +
                        app.icon +
                        '" onerror="this.src=`data:image/svg+xml;utf8,<svg xmlns=\'http://www.w3.org/2000/svg\'></svg>`;" /></div><div class="mdui-panel-item-title">' +
                        app.name +
                        '</div><div class="mdui-panel-item-summary">' +
                        app.bid +
                        '</div><i class="mdui-panel-item-arrow mdui-icon material-icons">&#xe313;</i></div><div class="mdui-panel-item-body"><ul class="mdui-list"><li class="mdui-list-item mdui-ripple" mdui-tooltip="{content: \'点击复制\'}" data-clipboard-text="' +
                        app.name +
                        '"><div class="mdui-list-item-content"><div class="mdui-list-item-title"><strong>应用名</strong></div><div class="mdui-list-item-text mdui-list-item-one-line">' +
                        app.name +
                        '</div></div></li><li class="mdui-list-item mdui-ripple" mdui-tooltip="{content: \'点击复制\'}" data-clipboard-text="' +
                        app.bid +
                        '"><div class="mdui-list-item-content"><div class="mdui-list-item-title"><strong>应用包名</strong></div><div class="mdui-list-item-text mdui-list-item-one-line">' +
                        app.bid +
                        '</div></div></li><li class="mdui-list-item mdui-ripple" mdui-tooltip="{content: \'点击复制\'}" data-clipboard-text="' +
                        app.bundle_path +
                        '"><div class="mdui-list-item-content"><div class="mdui-list-item-title"><strong>应用包路径</strong></div><div class="mdui-list-item-text mdui-list-item-two-line" style="word-break:break-all;">' +
                        app.bundle_path +
                        '</div></div></li><li class="mdui-list-item mdui-ripple" mdui-tooltip="{content: \'点击复制\'}" data-clipboard-text="' +
                        app.data_path +
                        '"><div class="mdui-list-item-content"><div class="mdui-list-item-title"><strong>应用数据路径</strong></div><div class="mdui-list-item-text mdui-list-item-two-line" style="word-break:break-all;">' +
                        app.data_path +
                        '</div></div></li></ul><div class="mdui-panel-item-actions"><button class="mdui-btn mdui-xxtouch-button mdui-ripple" onclick="clearapp(\'' +
                        app.bid +
                        "');\">清理应用数据</button></div></div></div>"
                    );
                });
            } else {
                mdui.snackbar({
                    message: cfg.message
                });
            }
        },
        "json"
    ).error(function() {
        mdui.snackbar({
            message: "与设备通讯无法达成"
        });
    });
    var clipboard = new Clipboard(".mdui-list-item");
    clipboard.on("success", function(e) {
        mdui.snackbar({
            message: "复制成功"
        });
    });
    clipboard.on("error", function(e) {
        mdui.snackbar({
            message: "复制失败，请手动复制"
        });
    });
});