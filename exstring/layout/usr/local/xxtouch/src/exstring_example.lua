-- string 模块单元测试脚本
-- 版本 0.4, 2022/06/17

require "exstring"
assert(string.version() == "0.4")

local multi_line = [[
hello001
hello002
hello003
hello004
hello005
hello006
hello007
hello008]]

-- 插入文本行: 操作后的文本 = string.insert_line_at(源文本, 行号, 新行内容)

assert(string.insert_line_at(multi_line, 1, "hello000") == [[
hello000
hello001
hello002
hello003
hello004
hello005
hello006
hello007
hello008]])

assert(string.insert_line_at(multi_line, 8, "hello888") == [[
hello001
hello002
hello003
hello004
hello005
hello006
hello007
hello888
hello008]])

assert(string.insert_line_at(multi_line, 9, "hello999") == [[
hello001
hello002
hello003
hello004
hello005
hello006
hello007
hello008
hello999]])

local _, err = pcall(function ()
    string.insert_line_at(multi_line, 10, "hello1024")
end)
assert(err)
-- print(err)  -- Invalid argument #2: line number 10 out of range (1, 9)

print('[success] string.insert_line_at')


-- 插入文本到某行前: 操作后的文本 = string.prefix_line(源文本, 行号, 追加到该行前的内容)
assert(string.prefix_line(multi_line, 1, "prefix-") == [[
prefix-hello001
hello002
hello003
hello004
hello005
hello006
hello007
hello008]])

assert(string.prefix_line(multi_line, 8, "prefix-") == [[
hello001
hello002
hello003
hello004
hello005
hello006
hello007
prefix-hello008]])

local _, err = pcall(function ()
    string.prefix_line(multi_line, 9, "prefix-")
end)
assert(err)
-- print(err)  -- Invalid argument #2: line number 9 out of range (1, 8)

print('[success] string.prefix_line')


-- 插入文本到某行后: 操作后的文本 = string.suffix_line(源文本, 行号, 追加到该行后的内容)
assert(string.suffix_line(multi_line, 1, "-suffix") == [[
hello001-suffix
hello002
hello003
hello004
hello005
hello006
hello007
hello008]])

assert(string.suffix_line(multi_line, 8, "-suffix") == [[
hello001
hello002
hello003
hello004
hello005
hello006
hello007
hello008-suffix]])

local _, err = pcall(function ()
    string.suffix_line(multi_line, 9, "-suffix")
end)
assert(err)
-- print(err)  -- Invalid argument #2: line number 9 out of range (1, 8)

print('[success] string.suffix_line')


-- 删除指定文本行: 操作后的文本 = string.remove_line(文本, 欲删除行的行号)
assert(string.remove_line(multi_line, 1) == [[
hello002
hello003
hello004
hello005
hello006
hello007
hello008]])

assert(string.remove_line(multi_line, 4) == [[
hello001
hello002
hello003
hello005
hello006
hello007
hello008]])

assert(string.remove_line(multi_line, 8) == [[
hello001
hello002
hello003
hello004
hello005
hello006
hello007]])

local _, err = pcall(function ()
    string.remove_line(multi_line, 9)
end)
assert(err)
-- print(err)  -- Invalid argument #2: line number 9 out of range (1, 8)

print('[success] string.remove_line')


local multi_line2 = [[


empty000

empty111
empty222

empty333
empty444
empty555


empty666
empty777


]]


-- 删除空行: 操作后的文本 = string.remove_empty_lines(源文本)
assert(string.remove_empty_lines(multi_line2) == [[
empty000
empty111
empty222
empty333
empty444
empty555
empty666
empty777]])

print('[success] string.remove_empty_lines')


-- 取总行数: 行数 = string.count_line(源文本)
assert(string.count_line(multi_line) == 8)
assert(string.count_line(multi_line2) == 17)
assert(string.count_line('') == 1)

print('[success] string.count_line')


local multi_rep_line = [[
hello001
hello001
hello002
hello003
hello002
hello004
hello004
hello007
hello004]]


-- 取文本行起始位置: 与该行内容相同的行出现的索引数组 = string.find_iline(源文本, 欲寻找行的行号)
assert(string.find_iline(multi_line, 1)[1] == 1)
assert(string.find_iline(multi_line, 8)[1] == 8)
local iline_arr
iline_arr = string.find_iline(multi_rep_line, 3);
assert(iline_arr[1] == 3)
assert(iline_arr[2] == 5)
iline_arr = string.find_iline(multi_rep_line, 6);
assert(iline_arr[1] == 6)
assert(iline_arr[2] == 7)
assert(iline_arr[3] == 9)

local _, err = pcall(function ()
    string.find_iline(multi_rep_line, 10)
end)
assert(err)
-- print(err)  -- Invalid argument #2: line number 10 out of range (1, 9)

print('[success] string.find_iline')


-- 取指定文本行: 文本行内容 = string.line_at(源文本, 欲取出行的行号)
assert(string.line_at(multi_line, 1) == 'hello001')
assert(string.line_at(multi_line, 4) == 'hello004')
assert(string.line_at(multi_line, 8) == 'hello008')

local _, err = pcall(function ()
    string.line_at(multi_line, 9)
end)
assert(err)
-- print(err)  -- Invalid argument #2: line number 9 out of range (1, 8)

print('[success] string.line_at')


-- 取文本所在行: 所在行号 = string.line_find(源文本, 欲搜寻的文本, [不区分大小写 = false]), 不存在为 -1
assert(string.line_find(multi_line, '001') == 1)
assert(string.line_find(multi_line, '003') == 3)
assert(string.line_find(multi_line, 'hello003') == 3)
assert(string.line_find(multi_line, '008') == 8)
assert(string.line_find(multi_line, 'hello') == 1)
assert(string.line_find(multi_line, 'HeLlO002') == -1)  -- not found
assert(string.line_find(multi_line, 'hElLo007', true) == 7)
assert(string.line_find(multi_line, '') == -1)  -- not found

print('[success] string.line_find')


-- 取文本行出现次数: 与该行内容相同的行出现的次数 = string.count_iline(文本, 欲寻找行的行号)
assert(string.count_iline(multi_line, 1) == 1)
assert(string.count_iline(multi_line, 8) == 1)
assert(string.count_iline(multi_rep_line, 3) == 2)
assert(string.count_iline(multi_rep_line, 6) == 3)

local _, err = pcall(function ()
    string.count_iline(multi_line, 9)
end)
assert(err)
-- print(err)  -- Invalid argument #2: line number 9 out of range (1, 8)

print('[success] string.count_iline')


-- 替换指定文本行: 操作后的文本 = string.replace_line(源文本, 欲替换其内容行的行号, 用于替换的行内容)
assert(string.replace_line(multi_line, 1, "replaced000") == [[
replaced000
hello002
hello003
hello004
hello005
hello006
hello007
hello008]])

assert(string.replace_line(multi_line, 4, "") == [[
hello001
hello002
hello003

hello005
hello006
hello007
hello008]])

assert(string.replace_line(multi_line, 8, "replaced000") == [[
hello001
hello002
hello003
hello004
hello005
hello006
hello007
replaced000]])

local _, err = pcall(function ()
    string.replace_line(multi_line, 9, "")
end)
assert(err)
-- print(err)  -- Invalid argument #2: line number 9 out of range (1, 8)

print('[success] string.replace_line')


-- 是否为数字: 判断结果 = string.is_numeric(文本)
assert(string.is_numeric('1234567890'))
assert(string.is_numeric('12345678.90'))
assert(string.is_numeric('') == false)
assert(string.is_numeric('123abc') == false)
assert(string.is_numeric('123abc7890') == false)

print('[success] string.is_numeric')


-- 是否为整数: 判断结果 = string.is_digit(文本)
assert(string.is_digit('1234567890'))
assert(string.is_digit('12345.67890') == false)
assert(string.is_digit('') == false)
assert(string.is_digit('123abc') == false)
assert(string.is_digit('123abc7890') == false)

print('[success] string.is_digit')


-- 是否为字母: 判断结果 = string.is_alphabet(文本)
assert(string.is_alphabet('abcDEFGHijk'))
assert(string.is_alphabet('') == false)
assert(string.is_alphabet('123aBc') == false)
assert(string.is_alphabet('123aBc7890') == false)

print('[success] string.is_alphabet')


-- 是否为大写字母: 判断结果 = string.is_uppercased(文本)
assert(string.is_uppercased('ABCDEFGHIJK'))
assert(string.is_uppercased('') == false)
assert(string.is_uppercased('abcdefghijk') == false)
assert(string.is_uppercased('123ABC') == false)
assert(string.is_uppercased('123abc7890') == false)

print('[success] string.is_uppercased')


-- 是否为小写字母: 判断结果 = string.is_lowercased(文本)
assert(string.is_lowercased('ABCDEFGHIJK') == false)
assert(string.is_lowercased('') == false)
assert(string.is_lowercased('abcdefghijk'))
assert(string.is_lowercased('123ABC') == false)
assert(string.is_lowercased('123abc7890') == false)

print('[success] string.is_lowercased')


-- 首字是否为汉字: 判断结果 = string.is_chinese(文本)
-- 注: 该方法只判断字符串第一个字符是否为汉字
assert(string.is_chinese("是汉字吗"))
assert(string.is_chinese("是 Chinese Character 吗"))
assert(string.is_chinese("is 汉字吗") == false)
assert(string.is_chinese("Chinese Character") == false)
assert(string.is_chinese("") == false)

print('[success] string.is_chinese')


-- 是否为链接: 判断结果 = string.is_link(文本)
assert(string.is_link('123abc7890') == false)
assert(string.is_link('') == false)
assert(string.is_link('http://www.baidu.com'))
assert(string.is_link('bug@xxtou.ch') == false)
assert(string.is_link('http://iphonedevwiki.net/index.php/Preferences_specifier_plist#PSEditTextCell_.26_PSSecureEditTextCell'))
assert(string.is_link('https://www.baidu.com/link?url=x_ZHKOUxi0VTwAXF4CFR8t2zW2qtph1p6SM1LsAgjcRyHFXnCQaCnYqmstyTWpBhRzs_00TZLwVrju24jGMEG_&wd=&eqid=8a23ea0b0003da8f000000045b1bae78'))
assert(string.is_link('https://82flex.com/2018/04/12/difference-between-UTF8String-and-fileSystemRepresentation.html'))

print('[success] string.is_link')


-- 是否为邮箱: 判断结果 = string.is_email(文本)
assert(string.is_email('123abc7890') == false)
assert(string.is_email('') == false)
assert(string.is_email('http://www.baidu.com') == false)
assert(string.is_email('bug@xxtou.ch'))
assert(string.is_email('i.82@me.com'))
assert(string.is_email('darwindev@mail.me.com'))

print('[success] string.is_email')


-- 到全角: 处理后的文本 = string.h2f(文本)
assert(string.h2f(",.?123abc") == "，．？１２３ａｂｃ")
assert(string.h2f(",.?123abc汉字") == "，．？１２３ａｂｃ汉字")
assert(string.h2f("") == "")

print('[success] string.h2f')


-- 到半角: 处理后的文本 = string.f2h(文本)
assert(string.f2h("，．？１２３ａｂｃ") == ",.?123abc")
assert(string.f2h("，．？１２３ａｂｃ汉字") == ",.?123abc汉字")
assert(string.f2h("") == "")

print('[success] string.f2h')


-- 首字母改大写: 处理后的文本 = string.to_capitalized(文本)
assert(string.to_capitalized("good night my baby boy") == "Good Night My Baby Boy")
assert(string.to_capitalized("Do you like 中文 2333?") == "Do You Like 中文 2333?")
assert(string.to_capitalized("") == "")

print('[success] string.to_capitalized')


-- 转拼音: 拼音文本 = string.to_pinyin(源文本, [去除声调 = false])
assert(string.to_pinyin("你好, zhe shi 中文！") == "nǐ hǎo, zhe shi zhōng wén！")
assert(string.to_pinyin("你好, zhe shi 中文！", true) == "ni hao, zhe shi zhong wen！")
assert(string.to_pinyin("") == "")

print('[success] string.to_pinyin')


-- 文本比较: 比较结果 = string.compare(待比较文本一，待比较文本二，[不区分大小写 = false]), 文本一小于文本二时返回 -1，反之返回 1，如果文本一等于文本二，返回 0
assert(string.compare("test1.luaBB", "test2.luaAA") == -1)
assert(string.compare("test3.luaDD", "test2.luaGG") == 1)
assert(string.compare("1.2-2", "1.2-10") == 1)
assert(string.compare("AaBbCcDd", "AAbbCCdd", true) == 0)
assert(string.compare("AaBbCcDd", "AAbbCCdd", false) == 1)
assert(string.compare("test.lua", "test.lua") == 0)
assert(string.compare("", "") == 0)

print('[success] string.compare')


-- 版本比较: 比较结果 = string.compare_version(待比较版本一，待比较版本二), 版本一小于版本二时返回 -1，反之返回 1，如果版本一等于版本二，返回 0
assert(string.compare_version("1.2-1", "1.2-10") == -1)
assert(string.compare_version("1.2-2", "1.2-10") == -1)
assert(string.compare_version("1.2.2", "1.2.2") == 0)
assert(string.compare_version("1.2.3", "1.2-2") == 1)

print('[success] string.compare_version')


-- 分割文本: 按分割符分割后的文本数组 = string.split(文本, 分割符, [最大返回个数 = MAX])
assert(#string.split(multi_line, "\n") == 8)
assert(#string.split(multi_line, "hello") == 9)
assert(#string.split(multi_line, "\n", 4) == 4)
assert(string.split(multi_line, "HELLO", 4)[1] == multi_line)
assert(string.split(multi_line, "\n", 1)[1] == "hello001")
assert(string.split("", "\n")[1] == "")

print('[success] string.split')


-- 逐字分割: 逐字分割结果数组 = 逐字分割(源文本)
assert(string.to_chars("你好")[1] == "你")
assert(string.to_chars("你好")[2] == "好")
assert(#string.to_chars("") == 0)

print('[success] string.to_chars')


-- 去重复文本(行): 分割结果数组去除重复元素后重新拼接的文本 = string.filter_iline(源文本, [分隔符 = "\n"])
assert(string.filter_iline(multi_rep_line) == [[
hello001
hello002
hello003
hello004
hello007]])

assert(string.filter_iline(multi_rep_line) == [[
hello001
hello002
hello003
hello004
hello007]])

assert(string.filter_iline(multi_rep_line, "00") == [[
hello001
hello002
hello003
hello004
hello007
hello004]])

print('[success] string.filter_iline')


-- 插入文本: 处理后的文本 = 插入文本(源文本, 插入位置, 欲插入的文本)
assert(string.insert_at("hello", 6, "world") == "helloworld")
assert(string.insert_at("", 1, "world") == "world")
assert(string.insert_at("hello, ", 8, "world!") == "hello, world!")
assert(string.insert_at("", 1, "") == "")

local _, err = pcall(function ()
    string.insert_at("hello", 7, "world")
end)
assert(err)
-- print(err)  -- Invalid argument #2: inserting position 7 out of range (1, 6)

print('[success] string.insert_at')


-- 插入文本到子文本前: 处理后的文本 = string.insert_before(源文本, 欲搜寻的子文本, 欲插入的文本, 重复插入次数)
assert(string.insert_before("Hello, world!", "world", "my ") == "Hello, my world!")
assert(string.insert_before("Hello, world!", "o", "p@1") == "Hellp@1o, wp@1orld!")
assert(string.insert_before("Hello, world!", "o", "p@1", 1) == "Hellp@1o, world!")
assert(string.insert_before("Hello, world!", "o", "") == "Hello, world!")
assert(string.insert_before("Hello, world!", "", "p@1") == "Hello, world!")
assert(string.insert_before("Hello, world!", "", "") == "Hello, world!")

print('[success] string.insert_before')


-- 插入文本到子文本后: 处理后的文本 = string.insert_after(源文本, 欲搜寻的子文本, 欲插入的文本, 重复插入次数)
assert(string.insert_after("Hello, world!", "Hello, ", "my ") == "Hello, my world!")
assert(string.insert_after("Hello, world!", "l", "c@2") == "Helc@2lc@2o, worlc@2d!")
assert(string.insert_after("Hello, world!", "l", "c@2", 2) == "Helc@2lc@2o, world!")
assert(string.insert_after("Hello, world!", "l", "") == "Hello, world!")
assert(string.insert_after("Hello, world!", "", "c@2") == "Hello, world!")
assert(string.insert_after("Hello, world!", "", "") == "Hello, world!")

print('[success] string.insert_after')


-- 删首尾空: 处理后的文本 = string.trim(文本)
assert(string.trim("  sp a ces  ") == "sp a ces")
assert(string.trim("") == "")

print('[success] string.trim')


-- 删首空: 处理后的文本 = string.ltrim(文本)
assert(string.ltrim("  sp a ces  ") == "sp a ces  ")
assert(string.ltrim("") == "")

print('[success] string.ltrim')


-- 删尾空: 处理后的文本 = string.rtrim(文本)
assert(string.rtrim("  sp a ces  ") == "  sp a ces")
assert(string.rtrim("") == "")

print('[success] string.rtrim')


-- 删全部空: 处理后的文本 = string.atrim(文本)
assert(string.atrim("  sp a ces  ") == "spaces")
assert(string.atrim("") == "")

print('[success] string.atrim')


-- 左补齐: 处理后的文本 = string.lpad(源文本, 补齐长度, [补齐文本 = " "])
assert(string.lpad("text_message", 16) == "    text_message")
assert(string.lpad("text_message", 8) == "text_message")
assert(string.lpad("text_message", 20, "0") == "00000000text_message")
assert(string.lpad("text_message", 20, "0ab") == "0ab0ab0atext_message")
assert(string.lpad("text", 6, "longmessage") == "lotext")

local _, err = pcall(function ()
    string.lpad("text_message", -7)
end)
assert(err)
-- print(err)  -- Invalid argument #2: padding length -7 less than 0

print('[success] string.lpad')


-- 右补齐: 处理后的文本 = string.rpad(源文本, 补齐长度, [补齐文本 = " "])
assert(string.rpad("text_message", 16) == "text_message    ")
assert(string.rpad("text_message", 8) == "text_message")
assert(string.rpad("text_message", 20, "0") == "text_message00000000")
assert(string.rpad("text_message", 20, "0ab") == "text_message0ab0ab0a")
assert(string.rpad("text", 6, "longmessage") == "textlo")

local _, err = pcall(function ()
    string.rpad("text_message", -7)
end)
assert(err)
-- print(err)  -- Invalid argument #2: padding length -7 less than 0

print('[success] string.rpad')
