
-- OO!

local concept = {}
setmetatable(concept, concept)

-- TODO: Find a way to prevent modifications of const classes without affecting performance

do -- utils
    -- these probably shouldn't be here, but meh
    pcall(require, "table.new")
    table.new = table.new or function(hashCount, arrayCount) return {} end
    
    _G._dbg = function(...)
        local info = debug.getinfo(2, "nSl")
        print(tostring(info.short_src)..":"..tostring(info.currentline).."-"..tostring(info.name), ...)
    end
    
    _G.xor = function(a, b)
        return (a and not b) or (b and not a)
    end
end

function concept.__call(library, class)
    --class.__init = class.__init or function(class, self, ...) return setmetatable(self or {}, class) end
    
    class.isa = concept.isa
    class[class] = true
    
    setmetatable(class, concept.CreateConceptMetatable())
    return class
end

function concept.isa(classOrObject, parentClass)
    return classOrObject[parentClass]
end

function concept.Specialise(parentClass, paramMap)
    local specialisedClass = {}
    specialisedClass.__paramMap = paramMap
    specialisedClass.__parentClass = parentClass
    specialisedClass[specialisedClass] = true
    if specialisedClass.__index == parentClass then
        specialisedClass.__index = specialisedClass
    end
    for k,v in pairs(parentClass) do
        specialisedClass[k] = v
    end
    for k,v in pairs(paramMap) do
        specialisedClass[k] = v
    end
    return setmetatable(specialisedClass, concept.CreateConceptMetatable(nil, parentClass))
end

function concept.DefaultCallMethod(class)
    return setmetatable({}, class)
end

function concept.CreateConceptMetatable(mt, parentClass)
    mt = mt or {}
    
    mt.__index = mt.__index or parentClass
    
    mt.__finalise = function(class)
        local callOverride = nil
        -- if class.__parentClass then
            -- for k,v in pairs(class.__parentClass) do
                -- class[k] = v
            -- end
        -- end
        -- if class.__paramMap then
            -- for k,v in pairs(class.__paramMap) do
                -- class[k] = v
            -- end
        -- end
        if class.__declare then
            class.__index = class.__index or class
            callOverride = class:__declare()
        end
        mt.__call = (
                callOverride
            or  (class.__init and function(class, ...) return class.__init(class, nil, ...) end)
            or  concept.DefaultCallMethod
        )
        mt.__finalise = nil
        return class
    end
    
    mt.__call = function(class, ...)
        mt.__finalise(class)
        return mt.__call(class, ...)
    end
    
    mt.__mod = concept.Specialise
    
    return mt
end

function concept.Finalise(class)
    -- forcefully finalises a class (for inheritance and generics)
    local __finalise = getmetatable(class).__finalise
    if __finalise then
        return __finalise(class)
    end
    return class
end

if TEST then -- example class
    local Array = concept{ -- fixed-size sequence
        size = nil    , -- param: integer >= 1
        
        contents = nil, -- property: sequence
        -- alternatively (and preferably), use the object itself to store the array contents
        -- but only for such a primitive concept
        -- an advanced concept would have multiple properties
    }
    function Array.__declare(class)
        assert(tonumber(class.size), "Array.size must be an integer")
        assert(class.size%1 == 0   , "Array.size must be an integer")
        assert(class.size >= 1     , "Array.size must be >= 1"      )
        class.size = tonumber(class.size)
        
        -- generate any specialised objects or functions here
        -- for example, you might generate functions for either 2d or 3d vectors
        -- this is where you'd call ffi.cdef and ffi.metatype
        
        --print("__declare debug")
        
        -- custom initialiser
        -- same as normal, but we use the new LuaJIT/Lua 5.3 table.new function to preallocate in the array part
        -- (if it's available, that is)
        -- note: you can define __declare and return nothing to stick with the default initialiser
        pcall(require, "table.new")
        if table.new then
            return function(class, ...)
                return class.__init(class, table.new(0, class.size), ...)
            end
        end
    end
    function Array.__init(class, obj, ...)
        obj = obj or {}
        --print("Init debug", class.size)
        obj.contents = obj.contents or {}
        setmetatable(obj, class) -- reason we have to do this here is to allow for Array:__init(existingTable)
       -- print("Init debug", obj.size)
        return obj
        --return setmetatable(obj, class)
    end
    function Array:SetRaw(i, val)
        self.contents[i] = val
    end
    function Array:Set(i, val)
        assert(tonumber(i)   , "invalid index (not an integer)")
        assert(i%1 == 0      , "invalid index (not an integer)")
        assert(i >= 1        , "invalid index (i < 1)"         )
        assert(i <= self.size, "invalid index (i > size)"      )
        self.contents[i] = val
    end
    function Array:GetRaw(i)
        return self.contents[i]
    end
    function Array:Get(i)
        assert(tonumber(i)   , "invalid index (not an integer)")
        assert(i%1 == 0      , "invalid index (not an integer)")
        assert(i >= 1        , "invalid index (i < 1)"         )
        assert(i <= self.size, "invalid index (i > size)"      )
        return self.contents[i]
    end
    
    local Array64 = Array%{ size = 64 }
    for i = 1, 2 do
        local myArray = Array64()
        myArray:Set(5, "Hello!")
        --print(myArray:Get(5), myArray.size)
    end
    
    assert(not pcall(function()
        local myArray = Array()
        myArray:Set(5, "Hello!")
    end))
    
    assert(not pcall(function()
        local myArray = (Array%{size=1})()
        myArray:Set(5, "Hello!")
    end))
    
    assert(not pcall(function()
        local myArray = (Array%{size=1.2})()
        myArray:Set(5, "Hello!")
    end))
    
    assert(not pcall(function()
        local myArray = (Array%{size=0})()
        myArray:Set(5, "Hello!")
    end))
    
end

--[[
local ffi = require'ffi' -- TODO: Make this optional... uh, nvm

function concept.finalise(class)
    class[class] = true
    class.__index = class
    if class.ffi then
        class.__new = class.__new or function(ct, ...)
            return ffi.new(ct)
        end
        class.ffiType = ffi.metatype(class.ffi, class)
        setmetatable(class, {
            __call = (
                    class.Init and (
                        function(class, ...)
                            local obj = class.ffiType(...)
                            obj:Init(...)
                            return obj
                        end
                    )
                or  function(class, ...) return class.ffiType(...) end
            ),
        })
    else
        class.Init = class.Init or function() end
        setmetatable(class, {
            __call = function(class, ...)
                local obj = setmetatable({}, class)
                obj:Init(...)
                return obj
            end,
        })
    end
    return class
end
]]

return concept

