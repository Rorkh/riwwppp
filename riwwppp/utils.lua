local function gsub (s, patt, repl)
  patt = lpeg.P(patt)
  patt = lpeg.Cs((patt / repl + 1)^0)
  return lpeg.match(patt, s)
end

local function capitalize(s)
    s = s:gsub("(%l)(%w*)", function(a,b) return string.upper(a)..b end)
    return s
end

local function ret(s)
    return load("return " .. s)()
end

return {
  gsub = gsub,
  capitalize = capitalize,
  ret = ret
}