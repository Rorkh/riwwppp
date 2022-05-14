# riwwppp
 Classes description language for Lua
## Content
- [Exports](#exports)
- [Instructions](#instructions)
  - [@constructor](#constructor-instruction)
  - [@field](#field-instruction)
  - [@data](#data-instruction)
- [@data modifiers](#data-modifiers)
- [Usage](#usage)
- [Examples](#examples)

## Exports
|  name  | arguments  | description |
| ------------ | ------------ | ------------ |
|  riwwppp.load |  string str | Builds and executes class from description language code |
|  riwwppp.loadFile |  string filename | Builds and executes class from file |
## Instructions
Instructions in riwwppp are always followed by `@` symbol
Example:
```lua
@class Person
```

|  name  | example  | description |
| ------------ | ------------ | ------------ |
|  pragma |  `@pragma safe` | Specifies pragma for builder |
|  class |  `@class Person` | Defines class name |
|  constructor |  `@constructor Create` | Defines constructor name |
|  field |  `@field age` | Defines new class field (with no accessors) |
|  data |  `@data name` | Defines new class field with setters and getters  |

### constructor instruction
Example:
```lua
@class Person
@constuctor Create
```
->
```lua
Animal = {}

function Animal:Create()
        local o = {}
        setmetatable(o, self)
        self.__index = self
        return o
end

-- Uses in internal purposes for inheritance and generates for every class
Animal._constructor = Animal.Create
```
If not specified, default constructor is ```new```
### field instruction
Example:
```lua
@class Person

@field wealth
@field age = 18
```
->
```lua
Person = {}

function Person:new()
        local o = {}
        setmetatable(o, self)
        self.__index = self
        self.wealth = nil
        self.age = 18
        return o
end

Person._constructor = Person.new
```
```lua
local Peter = Person:new()
print(Peter.age) -- 18
```
### data instruction
```lua
@class Person

@data name

@data [number] age = 18
@data [number safe] money = 1000

@data [const] truth = 42
```
->
```lua
Person = {}

function Person:new()
        local o = {}
        setmetatable(o, self)
        self.__index = self
        self.age = 18
        self.money = 1000
        return o
end

function Person:getName()
        return self.name
end

function Person:setName(value)
        self.name = value
end

function Person:getAge()
        return tonumber(self.age)
end

function Person:setAge(value)
        self.age = value
end

function Person:getMoney()
        return tonumber(self.money)
end

function Person:setMoney(value)
        if type(value) ~= "number" then error("Trying to set forbidden type for field money") end
        self.money = value
end

function Person:getTruth()
        return 42
end

Person._constructor = Person.new
```
## data modifiers
|  name  | description |
| ------------ | ------------ |
|  string |  Sets internal data type and adds conversion in getter |
|  number |  Sets internal data type and adds conversion in getter |
|  table |  Sets internal data type  |
|  safe |  Adds typecheck in setter if type is setted |
|  const |  Adds getter with inlined value |

## Usage

```lua
local riwwppp = require("riwwppp")
riwwppp.debug = false -- Temporary default is true

riwwppp.load(str)
riwwppp.loadFile(filename)
```

### Examples
See [*here*](https://github.com/Rorkh/riwwppp/tree/main/tests "*here*")
