local riwwppp = {debug = true}

--[[
    pragmas:
        capitalizeMethods - capitalize "get" and "set" for datafields
        safe - default safe attribute for datafields
]]

local function capitalize(str)
    str = str:gsub("(%l)(%w*)", function(a,b) return string.upper(a)..b end)
    return str
end

local function ret(str)
    return load("return " .. str)()
end

local instructions = {
    ["pragma"] = function(class, value)
        class.pragma = class.pragma or {}
        class.pragma[value] = true
    end,

    ["extends"] = function(class, value)
        if not class.name then 
            print("Trying to extend before class naming. Ignoring.")
            return
        end

        if not ret(value) then 
            print("Class " .. class.name .. " trying to inherit unregistered class " .. value .. ". Ignoring.") 
            return
        end

        class.extends = value
    end,

    ["class"] = function(class, value)
        class.name = value
    end,

    ["constructor"] = function(class, value)
        class.constructor = value
    end,

    ["field"] = function(class, value)
        local pointer = 0
        local name, default = "", "", ""

        local STATE_NAME = 1
        local STATE_VALUE = 2

        local state = STATE_NAME

        while (pointer ~= #value) do
            pointer = pointer + 1
            local char = string.sub(value, pointer, pointer)

            if state == STATE_NAME then
                if string.sub(value, pointer + 1, pointer + 1) == "=" then
                    pointer = pointer + 3
                    char = string.sub(value, pointer, pointer)

                    state = STATE_VALUE
                else
                    name = name .. char
                end
            end

            if state == STATE_VALUE then
                default = default .. char
            end
        end

        class.fields = class.fields or {}

        local field = {}
        field.name = name
        if not (default:match("^%s*(.-)%s*$") == "") then
            field.default = default
        end
        table.insert(class.fields, field)
    end,

    ["data"] = function(class, value)
        local pointer = 0
        local modifiers, name, default = "", "", ""

        local STATE_MODIFIER = 100

        local STATE_NAME = 1
        local STATE_VALUE = 2

        local state = STATE_NAME

        while (pointer ~= #value) do
            pointer = pointer + 1
            local char = string.sub(value, pointer, pointer)

            if char == "]" then
                state = STATE_NAME

                pointer = pointer + 2
                char = string.sub(value, pointer, pointer)
            end

            if state == STATE_MODIFIER then  modifiers = modifiers .. char end
            if char == "[" then
                state = STATE_MODIFIER
            end

            if state == STATE_NAME then
                if string.sub(value, pointer + 1, pointer + 1) == "=" then
                    pointer = pointer + 3
                    char = string.sub(value, pointer, pointer)

                    state = STATE_VALUE
                else
                    name = name .. char
                end
            end

            if state == STATE_VALUE then
                default = default .. char
            end
        end

        class.dataFields = class.dataFields or {}

        local dataField = {modifiers = {}}
        dataField.name = name

        for mod in modifiers:gmatch("%S+") do
            dataField.modifiers[mod] = true
        end

        if not (default:match("^%s*(.-)%s*$") == "") then
            dataField.default = default
        end
        table.insert(class.dataFields, dataField)
    end
}

local typeModifiers = {
    ["string"] = true,
    ["number"] = true,
    ["table"] = true
}

local conversibleTypes = {
    ["string"] = true,
    ["number"] = true
}

local function proccessModifiers(class)
    for _, dataField in ipairs(class.dataFields) do
        local type

        for mod, _ in pairs(dataField.modifiers) do
            if typeModifiers[mod] then
                if type then error("Multiple type modifiers at datafield " .. dataField.name) end
                type = mod
            end
        end

        dataField.type = type
    end
end

local function instruction(class, str, pointer, len)
    local name, value, modifier = "", ""
    local state = 0
    
    while (pointer ~= len) do
        pointer = pointer + 1
        
        local char = string.sub(str, pointer, pointer)
        
        if string.byte(char) == 10 then break end

        if string.byte(char) == 32 and state ~= 1 then 
            state = 1

            pointer = pointer + 1
            char = string.sub(str, pointer, pointer)
        end

        if state == 0 then name = name .. char end
        if state == 1 then value = value .. char end
    end
    
    if instructions[name] then
        instructions[name](class, value)
    else
        print("Unknown instruction " .. name .. " used")
    end
    
    return pointer
end

function riwwppp.parseClass(str)
    local len = #str
    local pointer = 0

    local class = {}
    
    while (pointer ~= len) do
        pointer = pointer + 1
        local char = string.sub(str, pointer, pointer)
        
        if char == "@" then 
            pointer = instruction(class, str, pointer, len)
        end
    end

    return class
end

function riwwppp.buildClass(class)
    proccessModifiers(class)
    local template = ""

    template = template .. class.name .. " = {}\n\n"

    if class.extends then
        template = template .. class.name .. " = " .. class.extends .. "._constructor(" .. class.extends .. ")\n\n"
    end

    local constructor = (class.constructor or "new")

    template = template .. "function " .. class.name .. ":" .. constructor .. "(o)\n"
        template = template .. "\tlocal o = o or {}\n"
        template = template .. "\tsetmetatable(o, self)\n"
        template = template .. "\tself.__index = self\n"

        for _, field in ipairs(class.fields) do
            template = template .. "\tself." .. field.name .. " = " .. (field.default and (isString and ('\"' .. field.default .. '\"') or field.default) or "nil") .. "\n"
        end

        for _, data in ipairs(class.dataFields) do
            if data.default then
                local isString = data.modifiers.string
                template = template .. "\tself." .. data.name .. " = " .. (isString and ('\"' .. data.default .. '\"') or data.default) .. "\n"
            end
        end

        template = template .. "\treturn o\n"
    template = template .. "end\n"

    -- Capitalize methods
    local cm = class.pragma.capitalizeMethods

    for _, data in ipairs(class.dataFields) do
        template = template .. "\n"
        template = template .. "function " .. class.name .. ":" .. ((cm and "Get" or "get") .. capitalize(data.name)) .. "()\n"
            template = template .. "\treturn " .. ((data.type and conversibleTypes[data.type]) and ("to" .. data.type .. "(self." .. data.name .. ")") or ("self." .. data.name)) .. "\n"
        template = template .. "end\n"

        if not data.modifiers.const then
            template = template .. "\nfunction " .. class.name .. ":" .. ((cm and "Set" or "set") .. capitalize(data.name)) .. "(value)\n"
                if (data.type and data.modifiers.safe) or (class.pragma.safe) then
                    template = template .. "\tif type(value) ~= " .. "\"" .. data.type .. "\" then error(\"Trying to set forbidden type for field " .. data.name .. "\") end\n"
                end
                template = template .. "\tself."..data.name.." = value\n"
            template = template .. "end\n"
        end
    end

    template = template .. "\n" .. class.name .. "._constructor = " .. class.name .. "." .. (class.constructor or "new") .. "\n"

    if riwwppp.debug then print(template) end

    return template
end

function riwwppp.load(str)
    local class = riwwppp.parseClass(str)
    load(riwwppp.buildClass(class))()
end

function riwwppp.loadFile(filename)
    local f = io.open(filename, "r")
    riwwppp.load(f:read("*a"))
    f:close()
end

return riwwppp