local Class  = require "hump.class"
local colors = require "term".colors

local Prompt = require "sirocco.prompt"

local Composite = Class {

    __includes = Prompt,

    init = function(self, options)
        self.fields = options.fields or {}
        self.separator = options.separator or " • "

        Prompt.init(self, options)

        for _, field in ipairs(self.fields) do
            field.buffer = field.default or ""
        end
    end

}

function Composite:moveOffsetBy(chars)
    local currentField, i = self:getCurrentField()
    local currentPosition = self.currentPosition.x - currentField.position

    if chars > 0 then
        -- Jump to text field
        if currentPosition + chars > currentField.length
            and i < #self.fields then
            self.currentPosition.x = self.fields[i + 1].position
        else
            chars = math.min(currentField.buffer:utf8width() - currentPosition, chars)

            if chars > 0 then
                self.currentPosition.x = self.currentPosition.x + chars
            end
        end
    elseif chars < 0 then
        -- Jump to previous field
        if currentPosition + chars < 0
            and i > 1 then
            local previousField = self.fields[i - 1]
            self.currentPosition.x = previousField.position + previousField.buffer:utf8width()
        else
            self.currentPosition.x = math.max(currentField.position, self.currentPosition.x + chars)
        end
    end
end

function Composite:render()
    Prompt.render(self)

    self:setCursor(
        self.promptPosition.x,
        self.promptPosition.y
    )

    local len = #self.fields
    local fieldPosition = 0
    for i, field in ipairs(self.fields) do
        if not field.buffer or field.buffer:utf8width() == 0 then
            -- Truncate placeholder to field length
            local placeholder = (field.placeholder or ""):utf8sub(1, field.length)
            -- Add padding to match field length
            placeholder = placeholder .. (" "):rep(field.length - placeholder:utf8width())

            self.output:write(
                colors.bright .. colors.black
                .. placeholder
                .. colors.reset

                .. (i < len and self.separator or "")
            )

            if not field.position then
                field.position = fieldPosition
            end
        else
            local buffer = field.buffer .. (" "):rep(field.length - Prompt.len(field.buffer))

            self.output:write(
                buffer
                .. (i < len and self.separator or "")
            )
        end

        fieldPosition = fieldPosition + field.length + (i < len and self.separator:utf8width() or 0)
    end

    self:setCursor(
        self.promptPosition.x + self.currentPosition.x,
        self.promptPosition.y + self.currentPosition.y
    )
end

function Composite:getCurrentField()
    local currentField

    local len = #self.fields
    local i = 1
    repeat
        currentField = self.fields[i]
        i = i + 1
    until (self.currentPosition.x >= currentField.position
        and self.currentPosition.x <= currentField.position + currentField.length)
        or i > len

    return currentField, i - 1
end

function Composite:processInput(input)
    -- Jump cursor to next field if necessary
    local len = #self.fields
    for i, field in ipairs(self.fields) do
        if self.currentPosition.x > field.position + field.length - 1
            and i < len
            and self.currentPosition.x < self.fields[i + 1].position then
            self.currentPosition.x = self.fields[i + 1].position
        end
    end

    -- Get current field
    local currentField = self:getCurrentField()

    -- Filter input
    input = currentField.filter
        and currentField.filter(input)
        or input

    if Prompt.len(currentField.buffer) >= currentField.length then
        input = ""
    end

    -- Insert in current field
    currentField.buffer =
        (currentField.buffer:utf8sub(1, self.currentPosition.x - currentField.position)
        .. input
        .. currentField.buffer:utf8sub(self.currentPosition.x + 1 - currentField.position))

    -- Increment current position
    self.currentPosition.x = self.currentPosition.x + input:utf8width()

    -- Validation
    if currentField.validator then
        local _, message = currentField.validator(currentField.buffer)
        self.message = message
    end
end

function Composite:processedResult()
    local result = {}

    for _, field in ipairs(self.fields) do
        table.insert(result, field.buffer)
    end

    return result
end

-- TODO: redefine all Prompt command_ to operate on current field instead of buffer

function Composite:command_end_of_line()
    local currentField = self:getCurrentField()
    self.currentPosition.x = currentField.position + currentField.length
end

function Composite:command_kill_line()
    local currentField = self:getCurrentField()
    currentField.buffer = currentField.buffer:utf8sub(
        1,
        self.currentPosition.x - currentField.position
    )
end

function Composite:command_delete_back()
    if self.currentPosition.x > 0 then
        self:moveOffsetBy(-1)

        -- Maybe we jumped back to previous field
        local currentField = self:getCurrentField()

        -- Delete char at currentPosition
        currentField.buffer = currentField.buffer:utf8sub(1, self.currentPosition.x - currentField.position)
            .. currentField.buffer:utf8sub(self.currentPosition.x + 2 - currentField.position)
    end
end


function Composite:command_complete()
    -- TODO
end

return Composite
