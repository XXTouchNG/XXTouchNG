require "compat53"

local Class     = require "hump.class"
local winsize   = require "sirocco.winsize"
local char      = require "sirocco.char"
local C, M, Esc = char.C, char.M, char.Esc
local tui       = require "tui"
local tparm     = require "tui.tparm".tparm

-- TODO: remove
local term   = require "term"
local colors = term.colors

local Prompt
Prompt = Class {

    init = function(self, options)
        self.input               = options.input or io.stdin
        self.output              = options.output or io.stdout
        self.prompt              = options.prompt or "> "
        self.placeholder         = options.placeholder

        assert(
            not self.placeholder
                or not self.placeholder:find("\n"),
            "New line not allowed in placeholder"
        )

        self.possibleValues      = options.possibleValues or {}
        self.showPossibleValues  = options.showPossibleValues
        self.validator           = options.validator
        self.filter              = options.filter

        self.required = false
        if options.required ~= nil then
            self.required = options.required
        end

        -- Printed buffer (can be wrapped, colored etc.)
        self.displayBuffer = options.default or ""
        -- Unaltered buffer
        self.buffer = options.default or ""
        -- Current utf8-aware offset in buffer (has to be translated in (x,y) cursor position)
        self.bufferOffset = options.default and options.default:utf8width() + 1 or 1

        self.currentPosition = {
            x = 0,
            y = 0
        }

        self.startingPosition = {
            x = false,
            y = false
        }

        self.promptPosition = {
            x = false,
            y = false
        }

        self.width = 80
        -- Height is prompt rows + message row
        self.height = 1

        -- Will be printed below
        self.message = nil

        self:registerKeybinding()
    end,

    -- Must be use for cursor position, NOT to get len of a string
    len = function(input)
        -- utf8.len will fail if input is not valid utf8
        return utf8.len(input) or #input
    end,

}

function Prompt:registerKeybinding()
    self.keybinding = {
        command_beg_of_line = {
            Prompt.escapeCodes.key_home,
            C "a",
        },

        command_end_of_line = {
            Prompt.escapeCodes.key_end,
            C "e",
        },

        command_backward_char = {
            Prompt.escapeCodes.key_left,
            C "b",
            Esc "[D" -- backup
        },

        command_forward_char = {
            Prompt.escapeCodes.key_right,
            C "f",
            Esc "[C" -- backup
        },

        command_complete = {
            Prompt.escapeCodes.tab
        },

        command_kill_line = {
            C "k",
        },

        command_clear_screen = {
            C "l",
        },

        command_delete_back = {
            Prompt.escapeCodes.key_backspace,
            "\127"
        },

        command_unix_line_discard = {
            C "u",
        },

        command_unix_word_rubout = {
            C "w",
            Esc "\127"
        },

        command_transpose_chars = {
            C "t",
        },

        command_delete = {
            C "d",
        },

        command_exit = {
            C "c", -- TODO: should be signal
            C "g"
        },

        command_backward_word = {
            M "b",
            Esc "b",
            Esc(Prompt.escapeCodes.key_left),
            Esc "[1;3D", -- Alt+left on termite
        },

        command_forward_word = {
            M "f",
            Esc "f",
            Esc(Prompt.escapeCodes.key_right),
            Esc "[1;3C",  -- Alt+left on termite
        },

        command_kill_word = {
            M "d",
            Esc "d"
        },

        command_validate = {
            "\n",
            "\r"
        },
    }
end

function Prompt:insertAtCurrentPosition(text)
    -- Insert text at currentPosition
    self.buffer =
        self.buffer:utf8sub(1, self.bufferOffset - 1)
        .. text
        .. self.buffer:utf8sub(self.bufferOffset)
end

-- Necessary because we erase everything each time
-- and reposition to startingPosition
function Prompt:getHeight()
    -- TODO: should not copy render
    local everything =
        self.prompt
        .. (self.showPossibleValues and #self.possibleValues > 0
        and " ("
            .. table.concat(self.possibleValues, ", ")
            .. ") "
        or "")
        .. (self.buffer or "")
        .. "\n"
        .. (self.message or "message") -- At least something otherwise line is ignored by textHeight

    return everything:utf8height(self.terminalWidth)
end

function Prompt:updateCurrentPosition()
    -- Some utf8 chars can take more than one cell
    local visualOffset = self.buffer:utf8sub(1, self.bufferOffset - 1):utf8width() + 1
    local offset = self.promptPosition.x + visualOffset

    local rows = 0
    while offset - 1 > self.terminalWidth do
        offset = offset - self.terminalWidth
        rows = rows + 1
    end

    self.currentPosition.x = offset - self.promptPosition.x - 1
    self.currentPosition.y = rows
end

-- Take value buffer and format/wrap it
function Prompt:renderDisplayBuffer()
    -- Terminal wraps printed text on its own
    self.displayBuffer = self.buffer
end

-- Set offset and move cursor accordingly
function Prompt:setOffset(offset)
    self.bufferOffset = offset
    self:updateCurrentPosition()
end

-- Move offset by increment and move cursor accordingly
function Prompt:moveOffsetBy(chars)
    if chars > 0 then
        chars = math.min(Prompt.len(self.buffer) - self.bufferOffset + 1, chars)

        if chars > 0 then
            self.bufferOffset = self.bufferOffset + chars
        end
    elseif chars < 0 then
        self.bufferOffset = math.max(1, self.bufferOffset + chars)
    end

    self:updateCurrentPosition()
end

function Prompt:processInput(input)
    input = self.filter
        and self.filter(input)
        or input

    self:insertAtCurrentPosition(input)

    self.bufferOffset = self.bufferOffset + Prompt.len(input)

    self:updateCurrentPosition()

    if self.validator then
        local _, message = self.validator(self.buffer)
        self.message = message
    end

    self:renderDisplayBuffer()
end

function Prompt:handleInput()
    local input = tui.getnext()

    for command, keys in pairs(self.keybinding) do
        for _, key in ipairs(keys) do
            if key == input then
                self[command](self)
                return true
            end
        end
    end

    -- Not an escape code
    self:processInput(input)
end

function Prompt:render()
    -- Go back to start
    self:setCursor(self.startingPosition.x, self.startingPosition.y)

    -- Clear down
    self.output:write(Prompt.escapeCodes.clr_eos)

    local inlinePossibleValues = self.showPossibleValues and #self.possibleValues > 0
        and " ("
            .. table.concat(self.possibleValues, ", ")
            .. ") "
        or ""

    -- Print prompt
    self.output:write(
        colors.bright .. colors.blue
        .. self.prompt
        .. inlinePossibleValues
        .. colors.reset
    )

    -- Print placeholder
    if self.placeholder
        and (not self.promptPosition.x or not self.promptPosition.y)
        and Prompt.len(self.displayBuffer) == 0 then
        self.output:write(
            colors.bright .. colors.black
            .. (self.placeholder or "")
            .. colors.reset
        )
    end

    -- Print current value
    self.output:write(self.displayBuffer)

    -- First time we need to initialize current position
    if not self.promptPosition.x or not self.promptPosition.y then
        local x, y = self.startingPosition.x, self.startingPosition.y - 1
        local prompt = self.prompt .. inlinePossibleValues

        local promptHeight = prompt:utf8height(self.terminalWidth)

        local lastLine = prompt:sub(-1) ~= "\n"
            and prompt:match("([^\n]*)$")
            or ""

        self.promptPosition.x, self.promptPosition.y =
            x + lastLine:utf8width() + (self.showPossibleValues and inlinePossibleValues:utf8width() or 0),
            y + promptHeight
    end

    self:renderMessage()

    self:setCursor(
        self.promptPosition.x + self.currentPosition.x,
        self.promptPosition.y + self.currentPosition.y
    )
end

function Prompt:renderMessage()
    if self.message then
        self:setCursor(
            1,
            self.promptPosition.y + self.currentPosition.y + 1
        )

        self.output:write(self.message)

        self:setCursor(
            self.promptPosition.x + self.currentPosition.x,
            self.promptPosition.y + self.currentPosition.y
        )
    end
end

function Prompt:update()
    self.terminalWidth, self.terminalHeight = winsize()

    self:renderDisplayBuffer()

    self.width = self.terminalWidth
    self.height = self:getHeight()

    -- Scroll up if at the terminal's bottom
    if self.startingPosition.y ~= nil then
        local heightDelta = (self.startingPosition.y + self.height) - self.terminalHeight - 1
        if heightDelta > 0 then
            -- Scroll up
            self.output:write(tparm(Prompt.escapeCodes.parm_index, heightDelta))

            -- Shift everything up
            self.startingPosition.y = self.startingPosition.y - heightDelta
            self.promptPosition.y   = self.promptPosition.y
                and (self.promptPosition.y - heightDelta)
                or self.promptPosition.y
        end
    end
end

function Prompt:processedResult()
    return self.buffer
end

function Prompt:endCondition()
    if self.finished == "force" then
        return true
    end

    if self.finished and self.required and Prompt.len(self.buffer) == 0 then
        self.finished = false
        self.message = colors.red .. "Answer is required" .. colors.reset
    end

    -- Only validate if required or if something is in the buffer
    if self.finished and self.validator and (self.required or Prompt.len(self.buffer) > 0) then
        local ok, message = self.validator(self.buffer)
        self.finished = self.finished and (ok or not self.required)
        self.message = message
    end

    return self.finished
end

function Prompt:getCursor()
    local y, x  = tui.getnext():match("([0-9]*);([0-9]*)")
    return tonumber(x), tonumber(y)
end

function Prompt:setCursor(x, y)
    self.output:write(tparm(Prompt.escapeCodes.cursor_address, y, x))
end

function Prompt:before()
    if self.input == io.stdin then
        -- Raw mode to get chars by chars
        os.execute("/usr/bin/env stty raw opost -echo 2> /dev/null")
    end

    -- Get current position
    self.output:write(Prompt.escapeCodes.user7)

    self.startingPosition.x,
        self.startingPosition.y = self:getCursor()

    -- Wrap prompt if needed
    self.terminalWidth, self.terminalHeight = winsize()
    self.height = self:getHeight()
end

function Prompt:after()
    self.output:write("\n")

    -- Restore normal mode
    os.execute("/usr/bin/env stty sane 2> /dev/null")
end

function Prompt:ask()
    self:before()

    repeat
        self:update()

        self:render()

        self:handleInput()
    until self:endCondition()

    local result = self:processedResult()

    self:after(result)

    return result
end

-- COMMANDS

function Prompt:command_beg_of_line() -- Control-a
    self:setOffset(1)
end

function Prompt:command_backward_char() -- Control-b, left arrow
    self:moveOffsetBy(-1)
end

function Prompt:command_delete() -- Control-d
    if Prompt.len(self.buffer) > 0 then
        self.buffer =
            self.buffer:utf8sub(1, math.max(1, self.bufferOffset - 1))
            .. self.buffer:utf8sub(self.bufferOffset + 1)
    else
        self:command_exit()
    end
end

function Prompt:command_end_of_line() -- Control-e
    self:setOffset(Prompt.len(self.buffer) + 1)
end

function Prompt:command_forward_char() -- Control-f, right arrow
    self:moveOffsetBy(1)
end

function Prompt:command_complete() -- Control-i, tab
    if #self.possibleValues > 0 then
        local matches = {}
        local count = 0
        for _, value in ipairs(self.possibleValues) do
            if value:utf8sub(1, #self.buffer) == self.buffer then
                table.insert(matches, value)
                count = count + 1
            end
        end

        if count > 1 then
            self.message = table.concat(matches, " ")
        elseif count == 1 then
            self.buffer = matches[1]
            self:setOffset(Prompt.len(self.buffer) + 1)

            if self.validator then
                local _, message = self.validator(self.buffer)
                self.message = message
            end
        end
    end
end

function Prompt:command_kill_line() -- Control-k
    self.buffer = self.buffer:utf8sub(
        1,
        self.bufferOffset - 1
    )
end

function Prompt:command_clear_screen() -- Control-l
    self:setCursor(1,1)

    self.startingPosition = {
        x = 1,
        y = 1
    }

    self.promptPosition = {
        x = false,
        y = false
    }

    self.output:write(Prompt.escapeCodes.clr_eos)
end

function Prompt:command_transpose_chars() -- Control-t
    local len = Prompt.len(self.buffer)
    if len > 1 and self.bufferOffset > 1 then
        local offset = math.max(1, (self.bufferOffset > len and len or self.bufferOffset) - 1)

        self.buffer =
            self.buffer:utf8sub(1, offset - 1)
            .. self.buffer:utf8sub(offset + 1, offset + 1)
            .. self.buffer:utf8sub(offset, offset)
            .. self.buffer:utf8sub(offset + 2)

        if self.bufferOffset <= len then
            self:moveOffsetBy(1)
        end
    end
end

function Prompt:command_unix_line_discard() -- Control-u
    self:setOffset(1)
    self.buffer = ""
end

function Prompt:command_unix_word_rubout() -- Control-w
    local s, e = self.buffer:utf8sub(1, self.bufferOffset - 1):find("[%g]+[^%g]*$")

    if s then
        self.buffer = self.buffer:utf8sub(1, s - 1) .. self.buffer:utf8sub(e + 1)
        self:moveOffsetBy(s - e - 1)
    end
end

function Prompt:command_delete_back()
    if self.bufferOffset > 1 then
        self:moveOffsetBy(-1)

        -- Delete char at currentPosition
        self.buffer = self.buffer:utf8sub(1, self.bufferOffset-1)
            .. self.buffer:utf8sub(self.bufferOffset + 1)
    end
end

function Prompt:command_validate()
    self.finished = true
    self.pendingBuffer = ""
end

function Prompt:command_abort()
    self.finished = "force"
end

function Prompt:command_exit()  -- Control-g, Control-c
    self:after()
    os.exit()
end

-- See: https://github.com/Distrotech/readline/blob/master/emacs_keymap.c

function Prompt:command_backward_word() -- Meta-b
    local s, e = self.buffer:utf8sub(1, self.bufferOffset - 1):find("[%g]+[^%g]*$")

    if e then
        self:moveOffsetBy(s - e - 1)
    end
end

function Prompt:command_kill_word() -- Meta-d
    local s, e = self.buffer:utf8sub(self.bufferOffset):find("[%g]+[^%g]*")
    s, e = self.bufferOffset + s - 1, self.bufferOffset + e - 1

    if s then
        self.buffer =
            self.buffer:utf8sub(1, s - 1)
            .. self.buffer:utf8sub(e + 1)
    end
end

function Prompt:command_forward_word() -- Meta-f
    local _, e = self.buffer:utf8sub(self.bufferOffset):find("[%g]+[^%g]*")

    if e then
        self:moveOffsetBy(e)
    end
end

function Prompt:command_transpose_words() -- Meta-t
end

function Prompt:command_get_next_history() -- Control-n
end

function Prompt:command_get_previous_history() -- Control-p
end

function Prompt:command_reverse_search_history() -- Control-r
end

function Prompt:command_forward_search_history() -- Control-s
end

function Prompt:command_yank() -- Control-y
end

function Prompt:command_undo_command() -- Control-_
end

function Prompt:command_possible_completions() -- Meta-=, Meta-?
end

function Prompt:command_beginning_of_history() -- Meta-<
end

function Prompt:command_end_of_history() -- Meta->
end

function Prompt:command_delete_horizontal_space() -- Meta-\
end

function Prompt:command_capitalize_word() -- Meta-c
end

function Prompt:command_downcase_word() -- Meta-l
end

function Prompt:command_upcase_word() -- Meta-u
end

-- Here for reference, won't likely be implemented

function Prompt:command_set_mark() -- Control-@
end

function Prompt:command_rubout() -- Control-h
end

function Prompt:command_quoted_insert() -- Control-q v
end

function Prompt:command_char_search() -- Control-]
end

function Prompt:command_backward_kill_word() -- Meta-Control-h
end

function Prompt:command_tab_insert() -- Meta-Control-i
end

function Prompt:command_revert_line() -- Meta-Control-r
end

function Prompt:command_yank_nth_arg() -- Meta-Control-y
end

function Prompt:command_backward_char_search() -- Meta-Control-]
end

function Prompt:command_set_mark() -- Meta-SPACE
end

function Prompt:command_insert_comment() -- Meta-#
end

function Prompt:command_tilde_expand() -- Meta-&, Meta-~
end

function Prompt:command_insert_completions() -- Meta-*
end

function Prompt:command_digit_argument() -- Meta--
end

function Prompt:command_yank_last_arg() -- Meta-., Meta-_
end

function Prompt:command_noninc_forward_search() -- Meta-n
end

function Prompt:command_noninc_reverse_search() -- Meta-p
end

function Prompt:command_revert_line() -- Meta-r
end

function Prompt:command_yank_pop() -- Meta-y
end


-- If can't find terminfo, fallback to minimal list of necessary codes
local ok, terminfo = pcall(require "tui.terminfo".find)

Prompt.escapeCodes = ok and terminfo or {}

-- Make sure we got everything we need
Prompt.escapeCodes.cursor_invisible = Prompt.escapeCodes.cursor_invisible or Esc "[?25l"
Prompt.escapeCodes.cursor_visible   = Prompt.escapeCodes.cursor_visible   or Esc "[?25h"
Prompt.escapeCodes.clr_eos          = Prompt.escapeCodes.clr_eos          or Esc "[J"
Prompt.escapeCodes.cursor_address   = Prompt.escapeCodes.cursor_address   or Esc "[%i%p1%d;%p2%dH"
-- Get cursor position (https://invisible-island.net/ncurses/terminfo.ti.html)
Prompt.escapeCodes.user7            = Prompt.escapeCodes.user7            or Esc "[6n"
Prompt.escapeCodes.key_left         = Prompt.escapeCodes.key_left         or Esc "[D"
Prompt.escapeCodes.key_right        = Prompt.escapeCodes.key_right        or Esc "[C"
Prompt.escapeCodes.key_down         = Prompt.escapeCodes.key_down         or Esc "[B"
Prompt.escapeCodes.key_up           = Prompt.escapeCodes.key_up           or Esc "[A"
Prompt.escapeCodes.key_backspace    = Prompt.escapeCodes.key_backspace    or "\127"
Prompt.escapeCodes.tab              = Prompt.escapeCodes.tab              or "\9"
Prompt.escapeCodes.key_home         = Prompt.escapeCodes.key_home         or Esc "0H"
Prompt.escapeCodes.key_end          = Prompt.escapeCodes.key_end          or Esc "0F"
Prompt.escapeCodes.key_enter        = Prompt.escapeCodes.key_enter        or Esc "0M"
Prompt.escapeCodes.parm_index       = Prompt.escapeCodes.parm_inde        or Esc "[%p1%dS"

return Prompt
