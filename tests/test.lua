package.path = package.path .. ";../?.lua"

local riwwppp = require("..riwwppp")
riwwppp.debug = false

riwwppp.loadFile("animal.class.lua")

local cow = Animal:new()
print(cow:GetName())

cow:SetName("Dolly")
print(cow:GetName())

print(cow.age)