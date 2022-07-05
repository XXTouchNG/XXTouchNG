local Class  = require "hump.class"
local colors = require "term".colors

local Prompt = require "sirocco.prompt"
local List   = require "sirocco.list"
local char   = require "sirocco.char"
local C, Esc = char.C, char.Esc

local Confirm = Class {

    __includes = List,

    init = function(self, options)
        options.items = {
            {
                value = true,
                label = "Yes"
            },
            {
                value = false,
                label = "No"
            },
        }

        options.multiple = false

        List.init(self, options)

        self.currentChoice = #self.chosen > 0
            and self.chosen[1]
            or 1
    end

}

function Confirm:registerKeybinding()
    self.keybinding = {
        command_get_next_choice = {
            Prompt.escapeCodes.key_right,
            C "n",
            Esc "[C" -- backup
        },

        command_get_previous_choice = {
            Prompt.escapeCodes.key_left,
            C "p",
            Esc "[D" -- backup
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

function Confirm:render()
    Prompt.render(self)

    self.output:write(
        " "
        .. (self.currentChoice == 1
            and colors.underscore
            or "")
        .. self.items[1].label
        .. colors.reset
        .. " / "
        .. (self.currentChoice == 2
            and colors.underscore
            or "")
        .. self.items[2].label
        .. colors.reset
    )
end

function Confirm:endCondition()
    self.chosen = {
        [self.currentChoice] = true
    }

    return List.endCondition(self)
end

function Confirm:after(result)
    -- Show selected label
    self:setCursor(self.promptPosition.x, self.promptPosition.y)

    -- Clear down
    self.output:write(Prompt.escapeCodes.clr_eos)

    self.output:write(" " .. (result[1] and "Yes" or "No"))

    -- Show cursor
    self.output:write(Prompt.escapeCodes.cursor_visible)

    Prompt.after(self)
end

return Confirm
