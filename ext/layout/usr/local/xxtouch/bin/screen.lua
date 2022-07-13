#!/usr/bin/env lua

if not touch then
    os.exit()
end
local keycodemap = {
    [48] = {0x07, 39},
    [49] = {0x07, 30},
    [50] = {0x07, 31},
    [51] = {0x07, 32},
    [52] = {0x07, 33},
    [53] = {0x07, 34},
    [54] = {0x07, 35},
    [55] = {0x07, 36},
    [56] = {0x07, 37},
    [57] = {0x07, 38},
    [65] = {0x07, 4},
    [66] = {0x07, 5},
    [67] = {0x07, 6},
    [68] = {0x07, 7},
    [69] = {0x07, 8},
    [70] = {0x07, 9},
    [71] = {0x07, 10},
    [72] = {0x07, 11},
    [73] = {0x07, 12},
    [74] = {0x07, 13},
    [75] = {0x07, 14},
    [76] = {0x07, 15},
    [77] = {0x07, 16},
    [78] = {0x07, 17},
    [79] = {0x07, 18},
    [80] = {0x07, 19},
    [81] = {0x07, 20},
    [82] = {0x07, 21},
    [83] = {0x07, 22},
    [84] = {0x07, 23},
    [85] = {0x07, 24},
    [86] = {0x07, 25},
    [87] = {0x07, 26},
    [88] = {0x07, 27},
    [89] = {0x07, 28},
    [90] = {0x07, 29},
    [13] = {0x07, 40},
    [27] = {0x07, 41},
    [8] = {0x07, 42},
    [9] = {0x07, 43},
    [32] = {0x07, 44},
    [189] = {0x07, 45},
    [187] = {0x07, 46},
    [219] = {0x07, 47},
    [221] = {0x07, 48},
    [220] = {0x07, 49},
    [186] = {0x07, 51},
    [222] = {0x07, 52},
    [192] = {0x07, 53},
    [188] = {0x07, 54},
    [190] = {0x07, 55},
    [191] = {0x07, 56},
    [20] = {0x07, 57},
    [112] = {0x07, 58},
    [113] = {0x07, 59},
    [114] = {0x07, 60},
    [115] = {0x07, 61},
    [116] = {0x07, 62},
    [117] = {0x07, 63},
    [118] = {0x07, 64},
    [119] = {0x07, 65},
    [120] = {0x07, 66},
    [121] = {0x07, 67},
    [122] = {0x07, 68},
    [123] = {0x07, 69},
    [145] = {0x07, 71},
    [19] = {0x07, 72},
    [45] = {0x07, 73},
    [36] = {0x07, 74},
    [33] = {0x07, 75},
    [46] = {0x07, 76},
    [35] = {0x07, 77},
    [34] = {0x07, 78},
    [39] = {0x07, 79},
    [37] = {0x07, 80},
    [40] = {0x07, 81},
    [38] = {0x07, 82},
    [17] = {0x07, 224},
    [16] = {0x07, 225},
    [18] = {0x07, 226},
    [91] = {0x07, 227},
    [92] = {0x07, 231},
    [144] = {0x07, 83},
    [111] = {0x07, 84},
    [106] = {0x07, 85},
    [109] = {0x07, 86},
    [107] = {0x07, 87},
    [96] = {0x07, 98},
    [97] = {0x07, 89},
    [98] = {0x07, 90},
    [99] = {0x07, 91},
    [100] = {0x07, 92},
    [101] = {0x07, 93},
    [102] = {0x07, 94},
    [103] = {0x07, 95},
    [104] = {0x07, 96},
    [105] = {0x07, 97},
    [110] = {0x07, 99}
}
local d_btn = {}
local ev = require "ev"
local loop = ev.Loop.default
local websocket = require "websocket"
local server =
    websocket.server.ev.listen {
    protocols = {
        ["RC"] = function(ws)
            sys.toast("已经建立远程控制连接")
            local index = 5
            ev.Timer.new(
                function()
                    if index <= 0 then
                        for _, btn in ipairs(d_btn) do
                            key.up(btn[1], btn[2])
                        end
                        sys.toast("已断开远程控制连接")
                        os.exit()
                    end
                    index = index - 1
                    ws:send(json.encode({mode = "heart"}))
                end,
                1,
                1
            ):start(loop)
            ws:on_message(
                function(ws, message, opcode)
                    if opcode == websocket.TEXT then
                        local jobj = json.decode(message)
                        if jobj then
                            if jobj.mode == "down" then
                                touch.down(28, jobj.x, jobj.y)
                            elseif jobj.mode == "move" then
                                touch.move(28, jobj.x, jobj.y)
                            elseif jobj.mode == "up" then
                                touch.up(28)
                            elseif jobj.mode == "clipboard" then
                                sys.toast(jobj.data)
                                _old = jobj.data
                                pasteboard.write(jobj.data)
                            elseif jobj.mode == "input" then
                                local k = keycodemap[jobj.key]
                                if k then
                                    key.press(k[1], k[2])
                                end
                            elseif jobj.mode == "input_down" then
                                local k = keycodemap[jobj.key]
                                if k then
                                    key.down(k[1], k[2])
                                end
                            elseif jobj.mode == "input_up" then
                                local k = keycodemap[jobj.key]
                                if k then
                                    for i = 1, #d_btn do
                                        if d_btn[i] == k then
                                            table.remove(d_btn, i)
                                            break
                                        end
                                    end
                                    key.up(k[1], k[2])
                                end
                            elseif jobj.mode == "home" then
                                key.press(0x0C, 64)
                            elseif jobj.mode == "power" then
                                key.press(0x0C, 48)
                            elseif jobj.mode == "quit" then
                                sys.toast("已断开远程控制连接")
                                os.exit()
                            elseif jobj.mode == "heart" then
                                index = 5
                            else
                            end
                        end
                    end
                end
            )
        end
    },
    port = 46968
}
loop:loop()
