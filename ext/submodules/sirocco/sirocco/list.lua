local Class  = require "hump.class"
local colors = require "term".colors

local Prompt = require "sirocco.prompt"
local char   = require "sirocco.char"
local C, Esc = char.C, char.Esc

local List = Class {

    __includes = Prompt,

    init = function(self, options)
        self.items         = options.items or {
            -- {
            --     value = "a",
            --     label = "the first choice"
            -- }
        }

        self.multiple = true
        if options.multiple ~= nil then
            self.multiple = options.multiple
        end

        self.currentChoice = 1
        self.chosen = options.default or {}

        -- Don't let prompt use options.default
        options.default = nil

        Prompt.init(self, options)
    end

}

function List:getHeight()
    local everything = self.prompt

    if not self.prompt:match("\n$") then
        everything = everything .. "\n"
    end

    for i, item in ipairs(self.items) do
        local chosen = self.chosen[i]

        -- TODO: should not copy render
        everything = everything
            .. " "
            .. (i == self.currentChoice and "❱ " or "  ")

            .. (self.multiple and "[" or "(")
            .. (
                self.multiple
                and (chosen and "✔" or " ")
                or (chosen and "●" or " ")
            )
            .. (self.multiple and "]" or ")")

            .. " "

            .. (chosen and colors.underscore or "")
            .. item.label

            .. "\n"
    end

    everything = everything
        .. (self.message or "message") -- At least something otherwise line is ignored by textHeight

    return everything:utf8height(self.terminalWidth)
end

function List:registerKeybinding()
    Prompt.registerKeybinding(self)

    self.keybinding = {
        command_get_next_choice = {
            Prompt.escapeCodes.key_down,
            C "n",
            Esc "[B" -- backup
        },

        command_get_previous_choice = {
            Prompt.escapeCodes.key_up,
            C "p",
            Esc "[A" -- backup
        },

        command_select_choice = {
            " "
        },

        -- TODO: those should be signals
        command_exit = {
            C "c",
        },

        command_validate = {
            "\n",
            "\r"
        },
    }
end

function List:complete()
end

function List:setCurrentChoice(newChoice)
    self.currentChoice = math.max(1, math.min(#self.items, self.currentChoice + newChoice))
end

function List:render()
    Prompt.render(self)

    -- List must begin under prompt
    if not self.prompt:match("\n$") then
        self.output:write("\n")
    end

    for i, item in ipairs(self.items) do
        local chosen = self.chosen[i]

        self.output:write(
            " "
            .. (i == self.currentChoice and "❱ " or "  ")

            .. colors.magenta
            .. (self.multiple and "[" or "(")
            .. (
                self.multiple
                and (chosen and "✔" or " ")
                or (chosen and "●" or " ")
            )
            .. (self.multiple and "]" or ")")
            .. colors.reset

            .. " "

            .. (chosen and colors.underscore or "")
            .. colors.green
            .. item.label
            .. colors.reset

            .. "\n"
        )
    end
end

function List:renderMessage()
    if self.message then
        self:setCursor(
            1,
            self.promptPosition.y + self.currentPosition.y + #self.items + 1
        )

        self.output:write(self.message)

        self:setCursor(
            self.promptPosition.x + self.currentPosition.x,
            self.promptPosition.y + self.currentPosition.y
        )
    end
end

function List:processInput(input)
end

function List:processedResult()
    local result = {}
    for i, selected in pairs(self.chosen) do
        if selected then
            table.insert(result, self.items[i].value)
        end
    end

    return result
end

function List:endCondition()
    if self.finished == "force" then
        return true
    end

    local count = 0
    for _, v in pairs(self.chosen) do
        count = count + (v and 1 or 0)
    end

    local condition = not self.required or count > 0

    if self.finished and not condition then
        self.message = colors.red .. "Answer is required" .. colors.reset
    end

    self.finished = self.finished and (not self.required or count > 0)

    return self.finished
end

function List:before()
    -- Hide cursor
    self.output:write(Prompt.escapeCodes.cursor_invisible)
    -- Backup
    self.output:write(Esc "[?25l")

    Prompt.before(self)
end

function List:after(result)
    -- Show selected label
    self:setCursor(self.promptPosition.x, self.promptPosition.y)

    -- Clear down
    self.output:write(Prompt.escapeCodes.clr_eos)

    if result then
        self.output:write(" " .. (#result == 1 and tostring(result[1]) or table.concat(result, ", ")))
    end

    -- Show cursor
    self.output:write(Prompt.escapeCodes.cursor_visible)
    -- Backup
    self.output:write(Esc "[?25h")

    Prompt.after(self)
end

function List:command_get_next_choice()
    self:setCurrentChoice(1)
end

function List:command_get_previous_choice()
    self:setCurrentChoice(-1)
end

function List:command_select_choice()
    local count = 0
    for _, v in pairs(self.chosen) do
        count = count + (v and 1 or 0)
    end

    self.chosen[self.currentChoice] = not self.chosen[self.currentChoice]

    -- Only one choice allowed ? unselect previous choice
    if self.chosen[self.currentChoice] and not self.multiple and count > 0 then
        self.chosen = {
            [self.currentChoice] = true
        }

        self.message = nil
    end
end

return List
