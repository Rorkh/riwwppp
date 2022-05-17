local success, lpeg = pcall(require, "lpeg")
lpeg = success and lpeg or require("lulpeg"):register(not _ENV and _G)

local riwwppp = {debug = true}

local utils = require("riwwppp.utils")
local grammar = require("riwwppp.grammar")

local ret = utils.ret
local capitalize = utils.capitalize

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
    if not class.dataFields then return end

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

        if not utils.ret(value) then 
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

    ["field"] = function(class, value, default, attribs)
        class.fields = class.fields or {}

        local field = {name = value, default = default}
        table.insert(class.fields, field)
    end,

    ["data"] = function(class, value, default, attribs)
        class.dataFields = class.dataFields or {}

        local dataField = {modifiers = {}, name = value, default = default}
        for _, mod in ipairs(attribs) do dataField.modifiers[mod] = true end

        table.insert(class.dataFields, dataField)
    end,

    ["method"] = function(class, name, args)
        print(1)
        class.method = {name = name, args = table.concat(args, ","), body = ""}
    end,

    ["end"] = function(class)
        print(2)
        table.insert(class.methods, class.method)
        class.method = nil
    end
}

local function preprocess(str)
    if not str then return end

    local matches = grammar.expressions:match(str)
    if not matches then return str end

    for _, expr in ipairs(matches) do
        str = utils.gsub(str, "\\" .. expr .. "\\", tostring(ret(expr)))
    end

    return str
end

function riwwppp.parseClass(str)
    local class = {fields = {}, dataFields = {}, pragma = {}, methods = {}}
    
    for line in str:gmatch("[^\r\n]+") do
        local instruction, f2, f3, f4 = grammar.instruction:match(line)

        if class.method and instruction ~= "end" then
            class.method.body = class.method.body .. "\n" .. line 
        else

            if instruction == "method" then
                local method, args = grammar.method:match(line)
                instructions["method"](class, method, args)
            else
                local value, default, attribs

                if type(f2) == "table" then
                    attribs = f2
                    value = f3
                    default = f4
                else
                    value = f2
                    default = f3
                end

                if instructions[instruction] then
                    instructions[instruction](class, value, preprocess(default), attribs or {})
                else
                    print("Unknown instruction " .. instruction .. " used")
                end
            end
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

    template = template .. "function " .. class.name .. ":" .. constructor .. "()\n"
        template = template .. "\tlocal o = {}\n"
        template = template .. "\tsetmetatable(o, self)\n"
        template = template .. "\tself.__index = self\n"

        for _, field in ipairs(class.fields) do
            template = template .. "\tself." .. field.name .. " = " .. (field.default and (isString and ('\"' .. field.default .. '\"') or field.default) or "nil") .. "\n"
        end

        for _, data in ipairs(class.dataFields) do
            if (data.default) and (not data.modifiers.const) then
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
            if data.modifiers.const then
                template = template .. "\treturn " .. data.default .. "\n"
            else
                template = template .. "\treturn " .. ((data.type and conversibleTypes[data.type]) and ("to" .. data.type .. "(self." .. data.name .. ")") or ("self." .. data.name)) .. "\n"
            end
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

    for _, method in ipairs(class.methods) do
        template = template .. "\n"
        template = template .. "function " .. class.name .. ":" .. method.name .. "(" .. method.args .. ")"
            template = template .. method.body
        template = template .. "\nend\n"
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