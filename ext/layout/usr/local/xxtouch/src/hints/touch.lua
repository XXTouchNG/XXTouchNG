touch = {}

-- $DOC_ROOT/Handbook/touch/touch.tap.html
function touch.tap(x, y, delay_ms, delay_after_ms) end

-- $DOC_ROOT/Handbook/touch/touch.on.html
function touch.on(x, y) end

-- $DOC_ROOT/Handbook/touch/_move.html
function touch.move(t, x, y) end

-- $DOC_ROOT/Handbook/touch/_press.html
function touch.press(t, pressure, twist) end

-- $DOC_ROOT/Handbook/touch/_off.html
function touch.off(t, x, y) end

-- $DOC_ROOT/Handbook/touch/_step_len.html
function touch.step_len(t, step) end

-- $DOC_ROOT/Handbook/touch/_step_delay.html
function touch.step_delay(t, delay) end

-- $DOC_ROOT/Handbook/touch/_msleep.html
function touch.msleep(t, delay_ms) end

-- $DOC_ROOT/Handbook/touch/touch.show_pose.html
function touch.show_pose(true_or_false) end