function fun_file_list(a) {
    $.post("/file_list?" + (new Date).getTime().toString(), JSON.stringify({
        directory: a
    }), function(b) {
        var c, d, e, f, g, h, i, j;
        "/" == a.substring(0, 1) && (a = a.substring(1, a.length)), $("a").remove(".to-path"), $("div").remove(".mdui-toolbar-spacer"), $("div").remove(".path_new_file"), $("div").remove(".path_refurbish"), c = "", now_path = a, d = $('<a class="to-path mdui-ripple mdui-ripple-white mdui-hidden-xs mdui-text-color-white-text">根目录</a>'), d.click(function() {
            fun_file_list("")
        }), $("#header-list").append(d), $.each(a.split("/"), function(a, b) {
            var d, e;
            "" != b && (c += "/" + b, d = c, e = $('<a class="to-path mdui-ripple mdui-ripple-white mdui-hidden-xs mdui-text-color-white-text">' + b + "</a>"), $("#header-list").append(e), e.click(function() {
                fun_file_list(d)
            }))
        }), e = $('<div href="javascript:;" class="path_new_file mdui-btn mdui-btn-icon"><i class="mdui-icon material-icons">&#xe89c;</i></div>'), e.click(function() {
            mdui.prompt("输入要创建的脚本名(包括拓展名)", function(b) {
                $.post("/write_file", JSON.stringify({
                    filename: a + "/" + b,
                    data: ""
                }), function(b) {
                    0 == b.code ? fun_file_list(a) : mdui.snackbar({
                        message: b.message
                    })
                }, "json").error(function() {
                    mdui.snackbar({
                        message: "与设备通讯无法达成"
                    })
                })
            }, function() {})
        }), f = $('<div href="javascript:;" class="path_refurbish mdui-btn mdui-btn-icon"><i class="mdui-icon material-icons">&#xe5d5;</i></div>'), f.click(function() {
            fun_file_list(a)
        }), $("#header-list").append('<div class="mdui-toolbar-spacer"></div>'), $("#header-list").append(e), $("#header-list").append(f), g = [], h = [], $.each(b.data.list, function(a, b) {
            "." != b.name && ".." != b.name && ("directory" == b.mode ? h.push({
                name: b.name,
                mode: b.mode,
                change: b.change
            }) : "." != b.name.substring(0, 1) && (console.log(b.name.substring(0, 1)), g.push({
                name: b.name,
                mode: b.mode,
                change: b.change
            })))
        }), h.sort(function(a, b) {
            return b.change - a.change
        }), g.sort(function(a, b) {
            return b.change - a.change
        }), $("#script-list").empty(), i = 1, j = function(b, c) {
            var g, h, j, k, l, m, n, o, p, q, r, d = $('<div class="mdui-row mdui-row-gapless"></div>'),
                e = $('<label class="mdui-list-item mdui-ripple"></label>'),
                f = $('<label class="mdui-list-item mdui-ripple" mdui-menu="{target: \'#path-file' + i + '\'}"><i class="mdui-icon material-icons">&#xe5d4;</i></label>');
            "directory" == c.mode ? (h = c.name.lastIndexOf("."), j = c.name.length, k = c.name.substring(h, j), ".xpp" == k.toLowerCase() ? (l = "lua/scripts" == a && selected_script_file == c.name || selected_script_file == a.substring(12, a.length) + "/" + c.name || selected_script_file == "/var/mobile/Media/1ferver/" + a + "/" + c.name ? $('<div class="mdui-radio"><input type="radio" name="script-file" checked/><i class="mdui-radio-icon"></i></div>') : $('<div class="mdui-radio"><input type="radio" name="script-file"/><i class="mdui-radio-icon"></i></div>'), e.append(l), l.click(function() {
                $.post("/select_script_file", JSON.stringify({
                    filename: "/var/mobile/Media/1ferver/" + a + "/" + c.name
                }), function() {
                    selected_script_file = "/var/mobile/Media/1ferver/" + a + "/" + c.name
                }, "json").error(function() {
                    mdui.snackbar({
                        message: "与设备通讯无法达成"
                    })
                })
            })) : e.click(function() {
                fun_file_list(a + "/" + c.name)
            }), e.append($('<i class="mdui-list-item-icon mdui-icon material-icons">&#xe2c7;</i>'), $('<div class="mdui-list-item-content">' + c.name + "</div>")), g = $('<ul class="mdui-menu" id="path-file' + i + '"></ul>'), m = $('<li class="mdui-menu-item"><a href="javascript:;" class="mdui-ripple">重命名</a></li>'), m.click(function() {
                mdui.prompt("输入要重命名的文件夹名字", function(b) {
                    $.post("/rename_file", JSON.stringify({
                        filename: a + "/" + c.name,
                        newfilename: a + "/" + b
                    }), function(b) {
                        0 == b.code ? fun_file_list(a) : mdui.snackbar({
                            message: b.message
                        })
                    }, "json").error(function() {
                        mdui.snackbar({
                            message: "与设备通讯无法达成"
                        })
                    })
                }, function() {}, {
                    defaultValue: c.name
                })
            }), n = $('<li class="mdui-menu-item"><a href="javascript:;" class="mdui-ripple">删除</a></li>'), n.click(function() {
                mdui.dialog({
                    title: "选择是否删除文件夹",
                    content: "删除则不可逆转",
                    buttons: [{
                        text: "取消"
                    }, {
                        text: "确认",
                        onClick: function() {
                            $.post("/rmdir", JSON.stringify({
                                directory: a + "/" + c.name
                            }), function(b) {
                                0 == b.code ? (mdui.snackbar({
                                    message: "删除成功"
                                }), fun_file_list(a)) : mdui.snackbar({
                                    message: b.message
                                })
                            }, "json").error(function() {
                                mdui.snackbar({
                                    message: "与设备通讯无法达成"
                                })
                            })
                        }
                    }]
                })
            }), g.append(m, n)) : "file" == c.mode && (l = "lua/scripts" == a && selected_script_file == c.name || selected_script_file == a.substring(12, a.length) + "/" + c.name || selected_script_file == "/var/mobile/Media/1ferver/" + a + "/" + c.name ? $('<div class="mdui-radio"><input type="radio" name="script-file" checked/><i class="mdui-radio-icon"></i></div>') : $('<div class="mdui-radio"><input type="radio" name="script-file"/><i class="mdui-radio-icon"></i></div>'), e.append(l), l.click(function() {
                $.post("/select_script_file", JSON.stringify({
                    filename: "/var/mobile/Media/1ferver/" + a + "/" + c.name
                }), function() {
                    selected_script_file = "/var/mobile/Media/1ferver/" + a + "/" + c.name
                }, "json").error(function() {
                    mdui.snackbar({
                        message: "与设备通讯无法达成"
                    })
                })
            }), g = $('<ul class="mdui-menu" id="path-file' + i + '"></ul>'), o = $('<li class="mdui-menu-item"><a href="javascript:;" class="mdui-ripple">下载文件</a></li>'), o.click(function() {
                location.href = "/download_file?filename=" + encodeURI("/var/mobile/Media/1ferver/" + a + "/" + c.name)
            }), p = $('<li class="mdui-menu-item"><a href="javascript:;" class="mdui-ripple">编辑</a></li>'), p.click(function() {
                $.jump("script_edit.html", {
                    file: a + "/" + c.name
                })
            }), m = $('<li class="mdui-menu-item"><a href="javascript:;" class="mdui-ripple">重命名</a></li>'), m.click(function() {
                mdui.prompt("输入要重命名的文件名字(包括拓展名)", function(b) {
                    $.post("/rename_file", JSON.stringify({
                        filename: a + "/" + c.name,
                        newfilename: a + "/" + b
                    }), function(b) {
                        0 == b.code ? fun_file_list(a) : mdui.snackbar({
                            message: b.message
                        })
                    }, "json").error(function() {
                        mdui.snackbar({
                            message: "与设备通讯无法达成"
                        })
                    })
                }, function() {}, {
                    defaultValue: c.name
                })
            }), q = $('<li class="mdui-menu-item"><a href="javascript:;" class="mdui-ripple">删除</a></li>'), q.click(function() {
                mdui.dialog({
                    title: "选择是否删除文件",
                    content: "删除则不可逆转",
                    buttons: [{
                        text: "取消"
                    }, {
                        text: "确认",
                        onClick: function() {
                            $.post("/remove_file", JSON.stringify({
                                filename: a + "/" + c.name
                            }), function(b) {
                                0 == b.code ? (mdui.snackbar({
                                    message: "删除成功"
                                }), fun_file_list(a)) : mdui.snackbar({
                                    message: b.message
                                })
                            }, "json").error(function() {
                                mdui.snackbar({
                                    message: "与设备通讯无法达成"
                                })
                            })
                        }
                    }]
                })
            }), g.append(o, p, m, q), "lua" == c.name.split(".").pop().toLowerCase() && (r = $('<li class="mdui-menu-item"><a href="javascript:;" class="mdui-ripple">加密</a></li>'), r.on("click", function() {
                var b = c.name,
                    d = c.name.replace(/(.*\/)*([^.]+).*/gi, "$2") + ".xxt",
                    e = "<span>是否加密“" + b + "”脚本？<br>加密后储存至同目录下“" + d + '”脚本。</span><br><li class="mdui-list-item mdui-ripple"><div class="mdui-list-item-content"><div class="mdui-list-item-title">保留调试信息</div><div class="mdui-list-item-text mdui-list-item-one-line xxtouch-tip">允许在加密的脚本发生运行期错误之时抛出带有行及名字的错误信息</div><div class="mdui-list-item-text mdui-list-item-two-line xxtouch-tip">注意：激活该选项加密后的脚本有潜在的被反编译风险</div></div><label class="mdui-switch"><input id="no_strip" type="checkbox"> <i class="mdui-switch-icon"></i></label></li>\n';
                mdui.dialog({
                    title: "是否加密此文件",
                    content: e,
                    buttons: [{
                        text: "取消"
                    }, {
                        text: "确认",
                        onClick: function(c) {
                            $.post("/encript_file", JSON.stringify({
                                no_strip: $(c.$dialog).find("input").is(":checked"),
                                in_file: "/var/mobile/Media/1ferver/" + a + "/" + b,
                                out_file: "/var/mobile/Media/1ferver/" + a + "/" + d
                            }), function(b) {
                                2 == b.code ? mdui.alert("脚本存在语法错误:" + b.detail) : mdui.snackbar({
                                    message: b.message
                                }), fun_file_list(a)
                            }, "json").error(function() {
                                mdui.snackbar({
                                    message: "与设备通讯无法达成"
                                })
                            })
                        }
                    }]
                })
            }), g.append(r)), "xui" == c.name.split(".").pop().toLowerCase() && (r = $('<li class="mdui-menu-item"><a href="javascript:;" class="mdui-ripple">加密</a></li>'), r.on("click", function() {
                var b = c.name,
                    d = c.name.replace(/(.*\/)*([^.]+).*/gi, "$2") + ".xuic",
                    e = "<span>是否加密“" + b + "”界面脚本？<br>加密后储存至同目录下“" + d + "”界面脚本。</span>\n";
                mdui.dialog({
                    title: "是否加密此文件",
                    content: e,
                    buttons: [{
                        text: "取消"
                    }, {
                        text: "确认",
                        onClick: function() {
                            $.post("/encript_file", JSON.stringify({
                                xuic: !0,
                                in_file: "/var/mobile/Media/1ferver/" + a + "/" + b,
                                out_file: "/var/mobile/Media/1ferver/" + a + "/" + d
                            }), function(b) {
                                2 == b.code ? mdui.alert("脚本存在语法错误:" + b.detail) : mdui.snackbar({
                                    message: b.message
                                }), fun_file_list(a)
                            }, "json").error(function() {
                                mdui.snackbar({
                                    message: "与设备通讯无法达成"
                                })
                            })
                        }
                    }]
                })
            }), g.append(r)), e.append($('<i class="mdui-list-item-icon mdui-icon material-icons">&#xe24d;</i>'), $('<div class="mdui-list-item-content">' + c.name + "</div>"))), d.append($('<div class="mdui-col-xs-9 mdui-col-sm-9"></div>').append(e), $('<div class="mdui-col-xs-3 mdui-col-sm-3"></div>').append(f, g)), $("#script-list").append(d), i += 1
        }, console.log(g), $.each(h, j), $.each(g, j)
    }, "json").error(function() {
        mdui.snackbar({
            message: "与设备通讯无法达成"
        })
    })
}
var now_path = "lua/scripts",
    selected_script_file = "";
$(document).ready(function() {
    function c(a) {
        var e, b = "",
            c = new Uint8Array(a),
            d = c.byteLength;
        for (e = 0; d > e; e++) b += String.fromCharCode(c[e]);
        return window.btoa(b)
    }

    function e(a) {
        var d, e, f, g, b = new Array;
        for (d = 0; d < a.length; d++) console.log(a[d]), b.push({
            success: 1,
            bfile: a[d]
        });
        e = function() {
            $("#update-display").empty();
            for (var a = 0; a < b.length; a++) switch (b[a].success) {
                case -1:
                    $("#update-display").append('<li class="mdui-list-item" style="height: 50px;"><i class="mdui-list-item-icon mdui-icon material-icons">&#xe14c;</i><div class="mdui-list-item-content"><div class="mdui-list-item-title">' + b[a].bfile.name + '</div><div class="mdui-list-item-text">文件最大限制40M</div></div></li>');
                    break;
                case 0:
                    $("#update-display").append('<li class="mdui-list-item" style="height: 50px;"><i class="mdui-list-item-icon mdui-icon material-icons">&#xe14c;</i><div class="mdui-list-item-content"><div class="mdui-list-item-title">' + b[a].bfile.name + '</div><div class="mdui-list-item-text">上传失败</div></div></li>');
                    break;
                case 1:
                    $("#update-display").append('<li class="mdui-list-item" style="height: 50px;"><i class="mdui-list-item-icon mdui-icon material-icons"><div class="mdui-spinner"></div></i><div class="mdui-list-item-content"><div class="mdui-list-item-title">' + b[a].bfile.name + '</div><div class="mdui-list-item-text">等待上传</div></div></li>');
                    break;
                case 2:
                    $("#update-display").append('<li class="mdui-list-item" style="height: 50px;"><i class="mdui-list-item-icon mdui-icon material-icons">&#xe2c6;</i><div class="mdui-list-item-content"><div class="mdui-list-item-title">' + b[a].bfile.name + '</div><div class="mdui-list-item-text">上传中</div></div></li>');
                    break;
                case 3:
                    $("#update-display").append('<li class="mdui-list-item" style="height: 50px;"><i class="mdui-list-item-icon mdui-icon material-icons">&#xe876;</i><div class="mdui-list-item-content"><div class="mdui-list-item-title">' + b[a].bfile.name + '</div><div class="mdui-list-item-text">上传成功</div></div></li>')
            }
            mdui.updateSpinners()
        }, f = !1, e(), g = function() {
            var a, d, h;
            if (!f) {
                for (d = 0; d < b.length; d++)
                    if (1 == b[d].success) {
                        a = d;
                        break
                    } if (null == a) return e(), fun_file_list(now_path), void 0;
                f = !0, b[a].bfile.size > 41943040 ? (b[d].success = -1, e()) : (b[d].success = 2, e(), h = new FileReader, h.readAsArrayBuffer(b[a].bfile), h.error = function() {
                    f = !1, b[d].success = 0
                }, h.onload = function() {
                    $.post("/write_file", JSON.stringify({
                        filename: now_path + "/" + b[d].bfile.name,
                        data: c(this.result)
                    }), function() {
                        f = !1, b[d].success = 3
                    }, "json").error(function() {
                        f = !1, b[d].success = 0
                    })
                })
            }
            setTimeout(g, 300)
        }, g()
    }
    var a, b;
    $("#main-drawer a[href='./script_choose.html']").addClass("mdui-list-item-active"), a = function() {
        $(window).width() > 600 ? ($("#update").css({
            display: "inline"
        }), $("#script-list").height($(window).height() - 135), $("#update-display").height($(window).height() - $("#dropbox").height() - 180)) : ($("#script-list").height($(window).height() - 135), $("#update").css({
            display: "none"
        }))
    }, $(window).resize(a), a(), $.post("/get_selected_script_file", "", function(a) {
        selected_script_file = a.data.filename, fun_file_list("lua/scripts")
    }, "json").error(function() {
        mdui.snackbar({
            message: "与设备通讯无法达成"
        })
    }), $("#launch-script-file").on("click", function() {
        $.post("/launch_script_file", "", function(a) {
            2 == a.code ? mdui.alert("脚本存在语法错误:" + a.detail) : mdui.snackbar({
                message: a.message
            })
        }, "json").error(function() {
            mdui.snackbar({
                message: "与设备通讯无法达成"
            })
        })
    }), $("#recycle").on("click", function() {
        $.post("/recycle", "", function(a) {
            mdui.snackbar({
                message: a.message
            })
        }, "json").error(function() {
            mdui.snackbar({
                message: "与设备通讯无法达成"
            })
        })
    }), $("#choose_file_update").click(function() {
        var a = $('<input type="file" style="display:none" multiple="multiple" />');
        a.change(function(a) {
            e(a.target.files)
        }), a.click()
    }), b = document.getElementById("dropbox"), document.addEventListener("dragenter", function() {
        b.style.borderColor = "gray"
    }, !1), document.addEventListener("dragleave", function() {
        b.style.borderColor = "silver"
    }, !1), b.addEventListener("dragenter", function() {
        b.style.borderColor = "gray", b.style.backgroundColor = "white"
    }, !1), b.addEventListener("dragleave", function() {
        b.style.backgroundColor = "transparent"
    }, !1), b.addEventListener("dragenter", function(a) {
        a.stopPropagation(), a.preventDefault()
    }, !1), b.addEventListener("dragover", function(a) {
        a.stopPropagation(), a.preventDefault()
    }, !1), b.addEventListener("drop", function(a) {
        a.stopPropagation(), a.preventDefault(), handleFiles(a.dataTransfer.files)
    }, !1), handleFiles = function(a) {
        e(a)
    }, $("#no_strip").on("click", function() {
        switch (this.checked) {
            case !0:
                $(".xxtouch-tip").css("color", "#FF0000");
                break;
            case !1:
                $(".xxtouch-tip").css("color", "rgba(0,0,0,.54)")
        }
    })
});