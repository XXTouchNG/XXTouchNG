local Class  = require "hump.class"

local Prompt = require "sirocco.prompt"

local Password = Class {

    __includes = Prompt,

    init = function(self, options)
        -- Can't suggest anything
        options.default = nil
        options.possibleValues = nil

        self.hidden = options.hidden

        Prompt.init(self, options)

        self.actual = ""
    end

}

function Password:renderDisplayBuffer()
    self.displayBuffer = self.hidden
        and ""
        or ("*"):rep(Prompt.len(self.buffer))
end

function Password:processInput(input)
    Prompt.processInput(self, input)

    if self.hidden then
        self.currentPosition.x = 0
    end
end

function Password:complete()
end

return Password
