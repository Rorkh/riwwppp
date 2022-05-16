local success, lpeg = pcall(require, "lpeg")
lpeg = success and lpeg or require"lulpeg":register(not _ENV and _G)

local S = lpeg.S
local P = lpeg.P
local R = lpeg.R

local C = lpeg.C
local Ct = lpeg.Ct

local brk = S("\f\n\r\t\v")^0
local space = P(' ')^0
local alpha = R("az")+R("AZ")

local rBracket = P("[")^1
local lBracket = P("]")^1

local word = alpha^1
local instr = P("@")

local attributes = rBracket * C(word) * (" " * C(word))^0 * lBracket

local sInstruction = P(instr * C(word) * space * C(word))
local aInstruction = P(instr * C(word) * space * Ct(attributes) * space * C(word)) 

local instruction = sInstruction + aInstruction

local name, attributes, value = instruction:match("@hello [a b c] world")
print(name, attributes, value)