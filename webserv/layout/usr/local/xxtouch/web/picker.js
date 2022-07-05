$(document).ready(function() {
    $("#main-drawer a[href='./picker.html']").addClass("mdui-list-item-active");
    $(window).resize(function() {
        $("#all_div").height($(window).height() - 100);
        $("#other_div").height($(window).height() - $("#message_div").height() - 100)
    });
    $("#all_div").height($(window).height() - 100);
    $("#open").click(function() {
        var v = $('<input type="file" style="display:none" name="upload"/>');
        v.change(function(w) {
            l(w.target.files)
        });
        v.click()
    });
    $("#save").click(function() {
        var w = o(b.toDataURL("image/jpeg"));
        var y = window.URL.createObjectURL(w);
        var v = document.createElement("a");
        v.href = y;
        v.download = "IMG_" + (new Date()).valueOf() + ".png";
        v.click()
    });
    var b = document.getElementById("all_canvas");
    var i = b.getContext("2d");
    var a = document.getElementById("hide_canvas");
    var k = a.getContext("2d");
    var g = document.getElementById("local_canvas");
    var q = g.getContext("2d");
    b.style.cursor = "crosshair";
    var t = null;
    var h = 0;
    $("#set").on("click", function() {
        mdui.dialog({
            title: "图像旋转方向",
            content: "",
            buttons: [{
                text: "Home在下",
                onClick: function(v) {
                    h = 0
                }
            }, {
                text: "Home在上",
                onClick: function(v) {
                    h = 3
                }
            }, {
                text: "Home在右",
                onClick: function(v) {
                    h = 1
                }
            }, {
                text: "Home在左",
                onClick: function(v) {
                    h = 2
                }
            }]
        })
    });
    $("#snapshot").on("click", function() {
        d()
    });
    $("#clear").on("click", function() {
        f.clear()
    });
    var e = new Clipboard(".mdui-btn");
    e.on("success", function(v) {
        mdui.snackbar({
            message: "复制成功"
        })
    });
    e.on("error", function(v) {
        mdui.snackbar({
            message: "复制失败，请手动复制"
        })
    });
    var f = {
        color_list: new Array,
        range: {
            x: 0,
            y: 0,
            x1: 0,
            y1: 0
        },
        img: "",
        add: function(G, F, D) {
            var B = this.push({
                x: G,
                y: F
            }, "0x" + D);
            var H = $('<button class="mdui-btn mdui-btn-icon mdui-ripple"><i class="mdui-icon material-icons">&#xe872;</i></button>');
            var E = $('<button class="mdui-btn mdui-btn-icon mdui-ripple" data-clipboard-text="' + G + "," + F + ",0x" + D + '"><i class="mdui-icon material-icons">&#xe14d;</i></button>');
            var v = $('<td><div class="mdui-shadow-5" style="width:30px;height:30px;background-color:#' + D + '"></div></td>');
            var I = $('<td><div class="mdui-btn mdui-btn-dense" style="font-family:Consolas,Monaco,monospace;text-transform:lowercase!important" data-clipboard-text="' + G + ", " + F + '">' + G + ", " + F + "</div></td>");
            var C = $('<td><div class="mdui-btn mdui-btn-dense" style="font-family:Consolas,Monaco,monospace;text-transform:lowercase!important" data-clipboard-text="0x' + D + '">0x' + D + "</div></td>");
            var w = $("<td></td>");
            var z = $("<tr></tr>");
            var A = this.color_list[B - 1];
            H.on("click", function() {
                f.remove(A);
                z.remove()
            });
            w.append(H, E);
            z.append(v, I, C, w);
            $("#color_list").append(z)
        },
        refresh: function() {
            var y = "{";
            for (x in this.color_list) {
                var w = this.color_list[x];
                if (w.x && w.y && w.color) {
                    y += "\r\n\t{" + w.x + "," + w.y + "," + w.color + "},"
                }
            }
            y += "\r\n}";
            $("#color_table").html(y);
            $("#color_table_cp").attr("data-clipboard-text", y);
            var A = "screen.is_colors(" + y + ", 90)";
            $("#is_colors").html(A);
            $("#is_colors_cp").attr("data-clipboard-text", A);
            var z = "x, y = screen.find_color(" + y + ",95," + this.range.x + "," + this.range.y + "," + this.range.x1 + "," + this.range.y1 + ")";
            $("#find_color").html(z);
            $("#find_color_cp").attr("data-clipboard-text", z);
            var v = 'x, y = screen.find_image("' + this.img + '",\n95,' + this.range.x + "," + this.range.y + "," + this.range.x1 + "," + this.range.y1 + ")";
            $("#find_image").html(v);
            $("#find_image_cp").attr("data-clipboard-text", v)
        },
        push: function(y, w) {
            var v = this.color_list.push({
                x: y.x,
                y: y.y,
                color: w
            });
            this.refresh();
            return v
        },
        remove: function(v) {
            var v = this.color_list.remove(v);
            this.refresh();
            return v
        },
        clear: function() {
            this.color_list = new Array;
            $("#color_list").empty();
            this.refresh()
        },
        setimg: function(v) {
            this.img = v;
            this.refresh()
        },
        setrange: function(v, A, w, z) {
            this.range.x = v;
            this.range.y = A;
            this.range.x1 = w;
            this.range.y1 = z;
            this.refresh()
        }
    };
    var s = 15;
    var p = 2;
    var c = 6;
    $("#local_div").width((p + s) * (c * 2 + 1) + p);
    $("#local_div").height((p + s) * (c * 2 + 1) + p);
    $("#local_canvas").attr("width", (p + s) * (c * 2 + 1) + p);
    $("#local_canvas").attr("height", (p + s) * (c * 2 + 1) + p);
    var m = function(E, C) {
        var w = k.getImageData(E, C, 1, 1);
        var v = w.data[0],
            B = w.data[1],
            D = w.data[2];
        var G = document.getElementById("message");
        G.innerHTML = "Pos:&nbsp;" + E + ", " + C + "<br >Color:&nbsp;0x" + n(v, B, D) + "<br>R:&nbsp;" + v + "&nbsp;&nbsp;G:&nbsp;" + B + "&nbsp;&nbsp;B:&nbsp;" + D;
        var F = b.getBoundingClientRect();
        $("#local_canvas").draw({
            type: "rectangle",
            fillStyle: "#000000",
            x: 0,
            y: 0,
            width: (p + s) * (c * 2 + 1) + p,
            height: (p + s) * (c * 2 + 1) + p,
            fromCenter: false
        });
        for (var z = -c; z <= c; z++) {
            for (var A = -c; A <= c; A++) {
                if ((E + z) >= 0 && (E + z) < t.width && (C + A) >= 0 && (C + A) < t.height) {
                    var w = k.getImageData(E + z, C + A, 1, 1);
                    var v = w.data[0],
                        B = w.data[1],
                        D = w.data[2];
                    $("#local_canvas").draw({
                        type: "rectangle",
                        fillStyle: "#" + n(v, B, D),
                        x: p + (p + s) * (z + c),
                        y: p + (p + s) * (A + c),
                        width: s,
                        height: s,
                        fromCenter: false
                    })
                } else {
                    q.fillStyle = "#FF00FF";
                    q.fillRect(p + (p + s) * (z + c), p + (p + s) * (A + c), s, s)
                }
            }
        }
        $("#local_canvas").draw({
            type: "rectangle",
            fillStyle: "#F06292",
            x: c * (s + p),
            y: (c - 1) * (s + p) + p,
            width: p,
            height: 3 * s + p * 2,
            fromCenter: false
        });
        $("#local_canvas").draw({
            type: "rectangle",
            fillStyle: "#F06292",
            x: (c + 1) * (s + p),
            y: (c - 1) * (s + p) + p,
            width: p,
            height: 3 * s + p * 2,
            fromCenter: false
        });
        $("#local_canvas").draw({
            type: "rectangle",
            fillStyle: "#F06292",
            x: (c - 1) * (s + p) + p,
            y: c * (s + p),
            width: 3 * s + p * 2,
            height: p,
            fromCenter: false
        });
        $("#local_canvas").draw({
            type: "rectangle",
            fillStyle: "#F06292",
            x: (c - 1) * (s + p) + p,
            y: (c + 1) * (s + p),
            width: 3 * s + p * 2,
            height: p,
            fromCenter: false
        })
    };
    var u = function(v, z) {
        var w = b.getBoundingClientRect();
        return {
            x: (v - w.left) * (b.width / w.width),
            y: (z - w.top) * (b.height / w.height)
        }
    };
    var n = function(y, w, v) {
        return (y < 16 ? "0" + y.toString(16).toLowerCase() : y.toString(16).toLowerCase()) + (w < 16 ? "0" + w.toString(16).toLowerCase() : w.toString(16).toLowerCase()) + (v < 16 ? "0" + v.toString(16).toLowerCase() : v.toString(16).toLowerCase())
    };
    var o = function(y) {
        var v = y.split(","),
            A = v[0].match(/:(.*?);/)[1],
            w = atob(v[1]),
            B = w.length,
            z = new Uint8Array(B);
        while (B--) {
            z[B] = w.charCodeAt(B)
        }
        return new Blob([z], {
            type: A
        })
    };
    var j = {
        down: false,
        mode: "",
        clientX: 0,
        clientY: 0,
        x: 0,
        y: 0,
        scroll: {
            top: 0,
            left: 0
        }
    };
    var r = {
        ctrl: false,
        alt: false,
        shift: false
    };
    $("#all_canvas").on("selectstart", function() {
        return false
    });
    $("#hide_canvas").on("selectstart", function() {
        return false
    });
    $("#local_canvas").on("selectstart", function() {
        return false
    });
    $("#all_canvas").on("mousedown", function(w) {
        var A = u(w.clientX, w.clientY);
        var v = Math.ceil(A.x),
            z = Math.ceil(A.y);
        if (!j.down && w.which == 1) {
            j.x = v;
            j.y = z;
            if (!r.ctrl && !r.alt && !r.shift) {
                j.down = true;
                j.mode = "move&get";
                j.clientX = w.clientX;
                j.clientY = w.clientY;
                j.scroll.left = $("#all_div").scrollLeft();
                j.scroll.top = $("#all_div").scrollTop()
            } else {
                if (!r.ctrl && !r.alt && r.shift) {
                    j.down = true;
                    j.mode = "cut"
                } else {
                    if (!r.ctrl && r.alt && !r.shift) {
                        j.down = true
                    } else {
                        if (r.ctrl && !r.alt && !r.shift) {
                            j.down = true;
                            j.mode = "range"
                        } else {
                            j.down = false
                        }
                    }
                }
            }
        }
    });
    $("#all_canvas").on("mousemove", function(w) {
        var A = u(w.clientX, w.clientY);
        var v = Math.ceil(A.x),
            z = Math.ceil(A.y);
        m(v, z);
        if (j.down) {
            if (j.mode == "move&get") {
                $("#all_div").scrollLeft(j.scroll.left + (j.clientX - w.clientX));
                $("#all_div").scrollTop(j.scroll.top + (j.clientY - w.clientY))
            } else {
                if (j.mode == "cut") {
                    $("#all_canvas").removeLayer("cut");
                    $("#all_canvas").addLayer({
                        type: "rectangle",
                        strokeStyle: "red",
                        strokeWidth: 1,
                        name: "cut",
                        fromCenter: false,
                        x: j.x,
                        y: j.y,
                        width: v - j.x,
                        height: z - j.y
                    });
                    $("#all_canvas").drawLayers()
                } else {
                    if (j.mode == "range") {
                        $("#all_canvas").removeLayer("range");
                        $("#all_canvas").addLayer({
                            type: "rectangle",
                            strokeStyle: "black",
                            strokeWidth: 1,
                            name: "range",
                            fromCenter: false,
                            x: j.x,
                            y: j.y,
                            width: v - j.x,
                            height: z - j.y
                        });
                        $("#all_canvas").drawLayers()
                    }
                }
            }
        }
    });
    $("#all_canvas").on("mouseup", function(D) {
        var F = u(D.clientX, D.clientY);
        var J = Math.ceil(F.x),
            G = Math.ceil(F.y);
        if (j.down) {
            j.down = false;
            if (j.mode == "move&get") {
                if (D.clientX == j.clientX && D.clientY == j.clientY) {
                    var w = i.getImageData(J, G, 1, 1);
                    var v = w.data[0],
                        C = w.data[1],
                        H = w.data[2];
                    f.add(J, G, n(v, C, H))
                } else {}
            } else {
                if (j.mode == "cut") {
                    var z, E;
                    if (J - j.x > 0) {
                        z = j.x
                    } else {
                        z = J
                    }
                    if (G - j.y > 0) {
                        E = j.y
                    } else {
                        E = G
                    }
                    if (Math.abs(J - j.x) == 0 || Math.abs(G - j.y) == 0) {
                        f.setimg("");
                        $("#all_canvas").removeLayer("cut");
                        $("#all_canvas").drawLayers();
                        $("#all_canvas").saveCanvas();
                        return
                    }
                    var A;
                    A = document.createElement("canvas");
                    A.width = Math.abs(J - j.x);
                    A.height = Math.abs(G - j.y);
                    A.getContext("2d").drawImage(a, z, E, Math.abs(J - j.x), Math.abs(G - j.y), 0, 0, Math.abs(J - j.x), Math.abs(G - j.y));
                    var K = A.toDataURL("image/png");
                    $("#find_image_preview").off("click");
                    $("#find_image_preview").on("click", function(y) {
                        mdui.dialog({
                            title: "预览图像",
                            content: "<img src='" + K + "' />",
                            buttons: [{
                                text: '<i class="mdui-icon material-icons">&#xe161;</i>保存图像',
                                onClick: function(N) {
                                    var M = o(A.toDataURL("image/jpeg"));
                                    var O = window.URL.createObjectURL(M);
                                    var L = document.createElement("a");
                                    L.href = O;
                                    L.download = "IMG_" + (new Date()).valueOf() + ".png";
                                    L.click()
                                }
                            }, {
                                text: "确定",
                                onClick: function(L) {}
                            }]
                        })
                    });
                    var I = o(A.toDataURL("image/jpeg"));
                    var B = new FileReader();
                    B.onload = function(M) {
                        var N = "";
                        for (var y = 0; y < M.total; y++) {
                            var L = B.result.charCodeAt(y).toString(16);
                            if (L.length < 2) {
                                L = "0" + L
                            }
                            N += "\\x" + L
                        }
                        f.setimg(N)
                    };
                    B.readAsBinaryString(I)
                } else {
                    if (j.mode == "range") {
                        var z, E;
                        if (J - j.x > 0) {
                            z = j.x
                        } else {
                            z = J
                        }
                        if (G - j.y > 0) {
                            E = j.y
                        } else {
                            E = G
                        }
                        if (Math.abs(J - j.x) == 0 || Math.abs(G - j.y) == 0) {
                            f.setrange(0, 0, 0, 0);
                            $("#all_canvas").removeLayer("range");
                            $("#all_canvas").drawLayers();
                            $("#all_canvas").saveCanvas();
                            return
                        }
                        f.setrange(z, E, z + Math.abs(J - j.x), E + Math.abs(G - j.y))
                    }
                }
            }
        }
    });
    var d = function() {
        var v = document.getElementById("all_canvas").getContext("2d");
        t = new Image();
        t.crossOrigin = "anonymous";
        t.src = "snapshot?ext=png&orient=" + h + "&t=" + (new Date().getTime()).toString();
        t.onload = function() {
            var y = t.width;
            $("#all_canvas").attr("width", y);
            $("#hide_canvas").attr("width", y);
            var w = t.height;
            $("#all_canvas").attr("height", w);
            $("#hide_canvas").attr("height", w);
            $("#hide_canvas").addLayer({
                type: "image",
                source: t.src,
                x: 0,
                y: 0,
                fromCenter: false
            }).drawLayers().saveCanvas();
            $("#all_canvas").addLayer({
                type: "image",
                source: t.src,
                x: 0,
                y: 0,
                fromCenter: false
            }).drawLayers().saveCanvas();
            m(0, 0)
        }
    };
    var l = function(y) {
        var v = y[0];
        var w = window.webkitURL.createObjectURL(v);
        t = new Image();
        t.crossOrigin = "anonymous";
        t.src = w;
        t.onload = function() {
            var A = t.width;
            $("#all_canvas").attr("width", A);
            $("#hide_canvas").attr("width", A);
            var z = t.height;
            $("#all_canvas").attr("height", z);
            $("#hide_canvas").attr("height", z);
            $("#hide_canvas").addLayer({
                type: "image",
                source: t.src,
                x: 0,
                y: 0,
                fromCenter: false
            }).drawLayers().saveCanvas();
            $("#all_canvas").addLayer({
                type: "image",
                source: t.src,
                x: 0,
                y: 0,
                fromCenter: false
            }).drawLayers().saveCanvas();
            m(0, 0)
        }
    };
    $(document).keyup(function(v) {
        r.ctrl = (navigator.platform.match("Mac") ? v.metaKey : v.ctrlKey);
        r.alt = v.altKey;
        r.shift = v.shiftKey
    });
    $(document).keydown(function(z) {
        r.ctrl = (navigator.platform.match("Mac") ? z.metaKey : z.ctrlKey);
        r.alt = z.altKey;
        r.shift = z.shiftKey;
        if ((navigator.platform.match("Mac") ? z.metaKey : z.ctrlKey) && z.keyCode == 83) {
            var w = o(b.toDataURL("image/jpeg"));
            var y = window.URL.createObjectURL(w);
            var v = document.createElement("a");
            v.href = y;
            v.download = "IMG_" + (new Date()).valueOf() + ".png";
            v.click();
            return false
        }
    });
    d();
    m(0, 0);
    $("#other_div").height($(window).height() - $("#message_div").height() - 100);
    document.addEventListener("dragover", function(v) {
        v.stopPropagation();
        v.preventDefault()
    }, false);
    document.addEventListener("drop", function(v) {
        v.stopPropagation();
        v.preventDefault();
        l(v.dataTransfer.files)
    }, false)
});