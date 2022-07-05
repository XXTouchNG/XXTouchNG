screen = require "screen"
touch = require "touch"

a = screen.find_color_normalize({
    {  0,   0, 0xec1c23},
    { 12,  -3, 0xffffff, 85},
    {  5, -18, 0x00adee},
    { -1, -10, 0xffc823},
    {  2, -34, 0xa78217},
    { 12, -55, 0xd0d2d2},
}, 90, 0, 0, 100, 100)

b = screen.find_color_normalize({
    { 509, 488, 0xec1c23},
    { 521, 485, 0xffffff, 85},
    { 514, 470, 0x00adee},
    { 508, 478, 0xffc823},
    { 511, 454, 0xa78217},
    { 521, 433, 0xd0d2d2},
}, 90, 0, 0, 100, 100)

assert(stringify(a) == stringify(b))

c = screen.find_color_normalize({
    { 516,  288, 0xffffff },
    { 519,  286, 0xffffff },
    { 521,  289, 0xffffff },
    { 516,  296, 0xffffff },
    { 522,  297, 0xffffff },
    { 520,  295, 0xffffff, -10 },
    { 515,  291, 0xffffff, -10 },
    { 518,  284, 0xffffff, -10 },
    { 523,  298, 0xffffff, -10 },
    { 514,  298, 0xffffff, -10 },
    { 514,  296, 0xffffff, -10 },
}, 90)

d = screen.find_color_normalize({
    {  0,   0, {0xec1c23, 0x000000}},
    { 12,  -3, {0xffffff, 0x101010}},
    {  5, -18, {0x00adee, 0x123456}},
    { -1, -10, {0xffc823, 0x101001}},
    {  2, -34, {0xa78217, 0x101001}},
    { 12, -55, {0xd0d2d2, 0x101001}},
}, 0, 0, 100, 100)

e = screen.find_color_normalize({
    { 509, 488, {0xec1c23, 0x000000}},
    { 521, 485, {0xffffff, 0x101010}},
    { 514, 470, {0x00adee, 0x123456}},
    { 508, 478, {0xffc823, 0x101001}},
    { 511, 454, {0xa78217, 0x101001}},
    { 521, 433, {0xd0d2d2, 0x101001}},
}, 0, 0, 100, 100)

assert(stringify(d) == stringify(e))

do
    begin_at = os.time()
    screen.keep()
    for i = 100,1,-1 
    do 
        x, y = screen.find_color({
            {  474, 1021, 0x1e1e1f,  90.00 },  -- 1
            {  494, 1030, 0xd8d6cd,  90.00 },  -- 2
            {  518, 1036, 0x5394c1,  90.00 },  -- 3
            {  541, 1042, 0xf3b33f,  90.00 },  -- 4
            {  478, 1050, 0x6ebb50,  90.00 },  -- 5
            {  517, 1061, 0xe17565,  90.00 },  -- 6
            {  477, 1086, 0xd8d6cd,  90.00 },  -- 7
            {  528, 1114, 0x1e1e1f,  90.00 },  -- 8
        },  90.00, 0, 761, 828, 1217)
    end
    screen.unkeep()
    end_at = os.time()
end

do 
    x, y = screen.find_color({
        {  474, 1021, 0x1e1e1f,  90.00 },  -- 1
        {  494, 1030, 0xd8d6cd,  90.00 },  -- 2
        {  518, 1036, 0x5394c1,  90.00 },  -- 3
        {  541, 1042, 0xf3b33f,  90.00 },  -- 4
        {  478, 1050, 0x6ebb50,  90.00 },  -- 5
        {  517, 1061, 0xe17565,  90.00 },  -- 6
        {  477, 1086, 0xd8d6cd,  90.00 },  -- 7
        {  528, 1114, 0x1e1e1f,  90.00 },  -- 8
    },  90.00, 0, 761, 828, 1217)

    touch.tap(x, y)
end
