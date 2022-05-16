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
local equals = P("=")^1
local slash = P("\\")

local word = alpha^1
local something = (R("az", "AZ", "09") + S("%^*()-+/\\.,:><={}"))^0 --alpha^0 * digits^0 * symbols^0
local expr = (R("az", "AZ", "09") + S("%^*()-+/.,:><={}"))^0 --alpha^0 * digits^0 * symbols^0
local instr = P("@")

local attributes = rBracket * C(word) * (" " * C(word))^0 * lBracket
local value = lpeg.P(space * equals * space * C(something))

-- Simple instruction
local sInstruction = P(instr * C(word) * space * C(word))
-- Attributed instruction
local aInstruction = P(instr * C(word) * space * Ct(attributes) * space * C(word))
-- Valued instruction
local vInstruction = (sInstruction * value) + (aInstruction * value)
-- Single expression
local expression = P(P("\\") * C(expr) * P("\\"))

local instruction = vInstruction + sInstruction + aInstruction
local expressions = Ct(expression * space * expression^0)

return {
	instruction = instruction,
	expressions = expressions
}