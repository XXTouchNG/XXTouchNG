$(document).ready(function() {
    var b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, a = " if not touch then os.exit() end local keycodemap = { [48] = { 0x07, 39}, [49] = { 0x07, 30}, [50] = { 0x07, 31}, [51] = { 0x07, 32}, [52] = { 0x07, 33}, [53] = { 0x07, 34}, [54] = { 0x07, 35}, [55] = { 0x07, 36}, [56] = { 0x07, 37}, [57] = { 0x07, 38}, [65] = { 0x07, 4}, [66] = { 0x07, 5}, [67] = { 0x07, 6}, [68] = { 0x07, 7}, [69] = { 0x07, 8}, [70] = { 0x07, 9}, [71] = { 0x07, 10}, [72] = { 0x07, 11}, [73] = { 0x07, 12}, [74] = { 0x07, 13}, [75] = { 0x07, 14}, [76] = { 0x07, 15}, [77] = { 0x07, 16}, [78] = { 0x07, 17}, [79] = { 0x07, 18}, [80] = { 0x07, 19}, [81] = { 0x07, 20}, [82] = { 0x07, 21}, [83] = { 0x07, 22}, [84] = { 0x07, 23}, [85] = { 0x07, 24}, [86] = { 0x07, 25}, [87] = { 0x07, 26}, [88] = { 0x07, 27}, [89] = { 0x07, 28}, [90] = { 0x07, 29}, [13] = { 0x07, 40}, [27] = { 0x07, 41}, [8] = { 0x07, 42}, [9] = { 0x07, 43}, [32] = { 0x07, 44}, [189] = { 0x07, 45}, [187] = { 0x07, 46}, [219] = { 0x07, 47}, [221] = { 0x07, 48}, [220] = { 0x07, 49}, [186] = { 0x07, 51}, [222] = { 0x07, 52}, [192] = { 0x07, 53}, [188] = { 0x07, 54}, [190] = { 0x07, 55}, [191] = { 0x07, 56}, [20] = { 0x07, 57}, [112] = { 0x07, 58}, [113] = { 0x07, 59}, [114] = { 0x07, 60}, [115] = { 0x07, 61}, [116] = { 0x07, 62}, [117] = { 0x07, 63}, [118] = { 0x07, 64}, [119] = { 0x07, 65}, [120] = { 0x07, 66}, [121] = { 0x07, 67}, [122] = { 0x07, 68}, [123] = { 0x07, 69}, [145] = { 0x07, 71}, [19] = { 0x07, 72}, [45] = { 0x07, 73}, [36] = { 0x07, 74}, [33] = { 0x07, 75}, [46] = { 0x07, 76}, [35] = { 0x07, 77}, [34] = { 0x07, 78}, [39] = { 0x07, 79}, [37] = { 0x07, 80}, [40] = { 0x07, 81}, [38] = { 0x07, 82}, [17] = { 0x07, 224}, [16] = { 0x07, 225}, [18] = { 0x07, 226}, [91] = { 0x07, 227}, [92] = { 0x07, 231}, [144] = { 0x07, 83}, [111] = { 0x07, 84}, [106] = { 0x07, 85}, [109] = { 0x07, 86}, [107] = { 0x07, 87}, [96] = { 0x07, 98}, [97] = { 0x07, 89}, [98] = { 0x07, 90}, [99] = { 0x07, 91}, [100] = { 0x07, 92}, [101] = { 0x07, 93}, [102] = { 0x07, 94}, [103] = { 0x07, 95}, [104] = { 0x07, 96}, [105] = { 0x07, 97}, [110] = { 0x07, 99}, } local d_btn = {} local ev = require'ev' local loop = ev.Loop.default local websocket = require'websocket' local server = websocket.server.ev.listen{ protocols = { ['RC'] = function(ws) sys.toast('已经建立远程控制连接') local index = 5 ev.Timer.new(function() if index <= 0 then for _, btn in ipairs(d_btn) do key.up(btn[1], btn[2]) end sys.toast('已断开远程控制连接') os.exit() end index = index - 1 ws:send(json.encode({mode = 'heart'}) ) end, 1, 1 ):start(loop) ws:on_message(function(ws,message,opcode) if opcode == websocket.TEXT then local jobj = json.decode(message) if jobj then if jobj.mode == 'down' then touch.down(28,jobj.x,jobj.y) elseif jobj.mode == 'move' then touch.move(28,jobj.x,jobj.y) elseif jobj.mode == 'up' then touch.up(28) elseif jobj.mode == 'clipboard' then sys.toast(jobj.data) _old = jobj.data pasteboard.write(jobj.data) elseif jobj.mode == 'input' then local k = keycodemap[jobj.key] if k then key.press(k[1], k[2]) end elseif jobj.mode == 'input_down' then local k = keycodemap[jobj.key] if k then key.down(k[1], k[2]) end elseif jobj.mode == 'input_up' then local k = keycodemap[jobj.key] if k then for i = 1, #d_btn do if d_btn[i] == k then table.remove(d_btn, i) break end end key.up(k[1], k[2]) end elseif jobj.mode == 'home' then key.press(0x0C, 64) elseif jobj.mode == 'power' then key.press(0x0C, 48) elseif jobj.mode == 'quit' then sys.toast('已断开远程控制连接') os.exit() elseif jobj.mode == 'heart' then index = 5 else end end end end) end }, port = 46968 } loop:loop()";
    console.log(a), $("#main-drawer a[href='./screen.html']").addClass("mdui-list-item-active"), b = null, c = 1, d = document.getElementById("all_canvas"), d.style.cursor = "crosshair", document.oncontextmenu = new Function("event.returnValue=false;"), document.onselectstart = new Function("event.returnValue=false;"), e = null, f = function() {
        var b, a = document.getElementById("all_canvas");
        img_scale = c.toFixed(2), b = new Image, b.src = "snapshot?ext=jpg&compress=0.00001&zoom=1&t=" + (new Date).getTime().toString(), b.onload = function() {
            var g, d = $(window).height() - 100;
            c = d / b.height, g = b.width * c, $("#all_canvas").attr("height", d), $("#all_canvas").attr("width", g), a.getContext("2d").drawImage(b, 0, 0, b.width, b.height, 0, 0, g, d), e = setTimeout(f, 10)
        }, b.onerror = function() {
            e = setTimeout(f, 10)
        }
    }, f(), $("#all_canvas").on("selectstart", function() {
        return !1
    }), $(document).on("touchmove", function(a) {
        a.preventDefault()
    }), g = !1, h = "ontouchstart" in window, i = h ? {
        down: "touchstart",
        move: "touchmove",
        up: "touchend",
        over: "touchstart",
        out: "touchcancel"
    } : {
        down: "mousedown",
        move: "mousemove",
        up: "mouseup",
        over: "mouseover",
        out: "mouseout"
    }, j = {
        start: function(a, d) {
            b.send(JSON.stringify({
                mode: "down",
                x: a / c,
                y: d / c
            }))
        },
        move: function(a, d) {
            b.send(JSON.stringify({
                mode: "move",
                x: a / c,
                y: d / c
            }))
        },
        end: function() {
            b.send(JSON.stringify({
                mode: "up"
            }))
        },
        homebutton: function() {
            b.send(JSON.stringify({
                mode: "home"
            }))
        },
        input: function(a) {
            b.send(JSON.stringify({
                mode: "input",
                key: a
            }))
        },
        input_down: function(a) {
            console.log(a), b.send(JSON.stringify({
                mode: "input_down",
                key: a
            }))
        },
        input_up: function(a) {
            console.log(a), b.send(JSON.stringify({
                mode: "input_up",
                key: a
            }))
        }
    }, $(document).on("keydown", function(a) {
        var b = a.keyCode || a.which || a.charCode;
        return a.ctrlKey || a.metaKey, j.input_down(b), a.returnValue = !1, a.preventDefault(), !1
    }), $(document).on("keyup", function(a) {
        var b = a.keyCode || a.which || a.charCode;
        return a.ctrlKey || a.metaKey, j.input_up(b), a.returnValue = !1, a.preventDefault(), !1
    }), $("#all_canvas").on(i.down, function(a) {
        var b, c;
        a.preventDefault(), b = (a.pageX || a.originalEvent.targetTouches[0].pageX) - this.offsetLeft, c = (a.pageY || a.originalEvent.targetTouches[0].pageY) - this.offsetTop, h ? (g = !0, j.start(b, c)) : 3 == a.which ? j.homebutton() : (g = !0, j.start(b, c))
    }), $("#all_canvas").on(i.move, function(a) {
        var b, c;
        a.preventDefault(), b = (a.pageX || a.originalEvent.targetTouches[0].pageX) - this.offsetLeft, c = (a.pageY || a.originalEvent.targetTouches[0].pageY) - this.offsetTop, g && j.move(b, c)
    }), $("#all_canvas").on(i.up, function(a) {
        a.preventDefault(), g && (g = !1, j.end())
    }), $("#all_canvas").on(i.out, function(a) {
        a.preventDefault(), g && (g = !1, j.end())
    }), $(window).unload(function() {
        b && b.onclose()
    }), $("#home").on("click", function() {
        b.send(JSON.stringify({
            mode: "home"
        }))
    }), $("#power").on("click", function() {
        b.send(JSON.stringify({
            mode: "power"
        }))
    }), k = !0, l = null, m = null, n = function() {
        l && clearTimeout(l), l = setTimeout(function() {
            clearInterval(m), b.onclose(), clearTimeout(e), mdui.dialog({
                title: "远控连接已断开",
                content: "请等待服务恢复后重新建立连接",
                buttons: [{
                    text: "重新连接",
                    onClick: function() {
                        k = !0, s()
                    }
                }]
            })
        }, 1e4)
    }, o = function() {
        m = setInterval(function() {
            b.send(JSON.stringify({
                mode: "heart"
            }))
        }, 1e4)
    }, p = function(a) {
        var c = JSON.parse(a.data);
        "heart" == c["mode"] && (n(), b.send(JSON.stringify({
            mode: "heart"
        })))
    }, q = function() {
        k ? (k = !1, r()) : mdui.snackbar({
            message: "远控连接已断开"
        })
    }, r = function() {
        $.post("/write_file", JSON.stringify({
            filename: "/bin/screen.lua",
            data: Base64.encode(a)
        }), function() {
            $.post("/command_spawn", "nohup lua /var/mobile/Media/1ferver/bin/screen.lua </dev/null >/dev/null 2>/dev/null &", function() {
                setTimeout(function() {
                    b = new WebSocket("ws://" + document.domain + ":46968", "RC");
                    try {
                        b.onopen = o, b.onmessage = p, b.onclose = q
                    } catch (a) {
                        console.log(a)
                    }
                }, 1e3)
            }, "json").error(function() {
                mdui.snackbar({
                    message: "与设备通讯无法达成"
                })
            })
        }, "json").error(function() {
            mdui.snackbar({
                message: "与设备通讯无法达成"
            })
        })
    }, s = function() {
        if ("localhost" == document.domain || "127.0.0.1" == document.domain) return mdui.snackbar({
            message: "无法本机操作本机"
        }), void 0;
        b = new WebSocket("ws://" + document.domain + ":46968", "RC");
        try {
            b.onopen = o, b.onmessage = p, b.onclose = q
        } catch (a) {
            console.log(a)
        }
    }, s()
});