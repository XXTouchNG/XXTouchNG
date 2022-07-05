screen = require "screen"
touch = require "touch"

screen.ocr_search = function (needle, level)
    if level == nil then
        level = 1
    end
    local bounding_box = nil
    local texts, details = screen.ocr_text(level)
    for _, v in ipairs(details) do
        if v["recognized_text"] == needle then
            bounding_box = v["bounding_box"]
            break
        end
    end
    if bounding_box == nil then
        return nil, nil
    end
    return (bounding_box[1] + bounding_box[3]) / 2, (bounding_box[2] + bounding_box[4]) / 2
end
