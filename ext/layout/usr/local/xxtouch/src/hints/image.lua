image = {}

-- $DOC_ROOT/Handbook/image/image.is.html
function image.is(obj) end

-- $DOC_ROOT/Handbook/image/image.load_file.html
function image.load_file(path) end

-- $DOC_ROOT/Handbook/image/image.load_data.html
function image.load_data(data) end

-- $DOC_ROOT/Handbook/image/_copy.html
function image.copy(img) end

-- $DOC_ROOT/Handbook/image/_crop.html
function image.crop(img, left, top, right, bottom) end

-- $DOC_ROOT/Handbook/image/_save_to_album.html
function image.save_to_album(img) end

-- $DOC_ROOT/Handbook/image/_save_to_png_file.html
function image.save_to_png_file(img, path) end

-- $DOC_ROOT/Handbook/image/_save_to_jpeg_file.html
function image.save_to_jpeg_file(img, path, quality) end

-- $DOC_ROOT/Handbook/image/_png_data.html
function image.png_data(img) end

-- $DOC_ROOT/Handbook/image/_jpeg_data.html
function image.jpeg_data(img, quality) end

-- $DOC_ROOT/Handbook/image/_turn_left.html
function image.turn_left(img) end

-- $DOC_ROOT/Handbook/image/_turn_right.html
function image.turn_right(img) end

-- $DOC_ROOT/Handbook/image/_turn_upondown.html
function image.turn_upondown(img) end

-- $DOC_ROOT/Handbook/image/_size.html
function image.size(img) end

-- $DOC_ROOT/Handbook/image/_width.html
function image.width(img) end

-- $DOC_ROOT/Handbook/image/_height.html
function image.height(img) end

-- $DOC_ROOT/Handbook/image/_get_color.html
function image.get_color(img, x, y) end

-- $DOC_ROOT/Handbook/image/_find_color.html
function image.find_color(img, colors, similarity, left, top, right, bottom) end

-- $DOC_ROOT/Handbook/image/_is_colors.html
function image.is_colors(img, colors, similarity) end

-- $DOC_ROOT/Handbook/image/_qr_decode.html
function image.qr_decode(img) end

-- $DOC_ROOT/Handbook/image/_destroy.html
function image.destroy(img) end

-- $DOC_ROOT/Handbook/image/_cv_find_image.html
function image.cv_find_image(img, template) end

-- $DOC_ROOT/Handbook/image/_cv_binaryzation.html
function image.cv_binaryzation(img, threshold) end

-- $DOC_ROOT/Handbook/image/_ocr_text.html
function image.ocr_text(img, left, top, right, bottom, level) end