screen = {}

-- $DOC_ROOT/Handbook/screen/screen.init.html
function screen.init(orientation) end

-- $DOC_ROOT/Handbook/screen/screen.rotate_xy.html
function screen.rotate_xy(x, y, orientation) end

-- $DOC_ROOT/Handbook/screen/screen.size.html
function screen.size() end

-- $DOC_ROOT/Handbook/screen/screen.keep.html
function screen.keep() end

-- $DOC_ROOT/Handbook/screen/screen.unkeep.html
function screen.unkeep() end

-- $DOC_ROOT/Handbook/screen/screen.get_color.html
function screen.get_color(x, y) end

-- $DOC_ROOT/Handbook/screen/screen.get_color_rgb.html
function screen.get_color_rgb(x, y) end

-- $DOC_ROOT/Handbook/screen/screen.is_colors.html
function screen.is_colors(colors, similarity) end

-- $DOC_ROOT/Handbook/screen/screen.find_color.html
function screen.find_color(colors, similarity, left, top, right, bottom) end

-- $DOC_ROOT/Handbook/screen/screen.image.html
function screen.image(left, top, right, bottom) end

-- $DOC_ROOT/Handbook/screen/screen.ocr_text.html
function screen.ocr_text(left, top, right, bottom, level) end

-- $DOC_ROOT/Handbook/screen/screen.find_image.html
function screen.find_image(image, similarity, left, top, right, bottom) end