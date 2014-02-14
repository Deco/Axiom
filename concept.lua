
-- OO!

local concept = {}
setmetatable(concept, concept)

-- TODO: Find a way to prevent modifications of const classes without affecting performance

do -- utils
    -- these probably shouldn't be here, but meh
    
    pcall(require, "table.new")
    table.new = table.new or function(narray, nhash) return {} end
    
    table.reverse = table.reverse or function(t)
        local n = #t
        for i = 1, math.floor(n/2) do
            t[i], t[n-i+1] = t[n-i+1], t[i]
        end
        -- don't return anything to make it clear we're reversing the table passed
        --return t
    end
    table.getreversed = table.reverse or function(t)
        local n = #t
        local r = table.new(n, 0)
        for i = 1, n do
            r[n+1-i] = t[i]
        end
        return r
    end
    
    local function arrayflatten_internal(result, resultLength, level, tbl)
        if level == 0 then
            for tblPairKey, tblPairValue in ipairs(tbl) do
                resultLength = resultLength+1
                result[resultLength] = tblPairValue
            end
        else
            level = level-1
            for tblPairKey, tblPairValue in ipairs(tbl) do
                resultLength = arrayflatten_internal(result, resultLength, level, tblPairValue)
            end
        end
        return resultLength
    end
    table.arrayflatten = function(array, level, precomputeSize)
        -- TODO: Implement table.arrayflattern size precomputing
        level = level or 1
        local result = {}
        local resultLength = arrayflatten_internal(result, 0, level, array)
        return result, resultLength
    end
    
    table.arrayjoin = table.arrayjoin or function(...)
        -- TODO: fix table.arrayjoin size precomputing
        local size = 0
        for argI = 1, select('#', ...) do
            size = size+#select(argI, ...)
        end
        local result = table.new(size, 0)
        local resultLength = 0
        for argI = 1, select('#', ...) do
            local arg = select(argI, ...)
            for argPairKey, argPairValue in ipairs(arg) do
                resultLength = resultLength+1
                result[resultLength] = argPairValue
            end
        end
        return result, resultLength
    end
    
    local function arraycopy_internal(level, tbl)
        local result = table.new(#tbl, 0)
        if level == 1 then
            for tblPairKey, tblPairValue in ipairs(tbl) do
                result[tblPairKey] = tblPairValue
            end
        else
            level = level-1
            for tblPairKey, tblPairValue in ipairs(tbl) do
                result[tblPairKey] = arraycopy_internal(level, tblPairValue)
            end
        end
        return result
    end
    table.arraycopy = table.arraycopy or function(array, level)
        level = level or 1
        return arraycopy_internal(level, array)
    end
    
    _G._dbg = function(...)
        local info = debug.getinfo(2, "nSl")
        print(tostring(info.short_src)..":"..tostring(info.currentline).."-"..tostring(info.name), ...)
    end
    
    _G.xor = function(a, b)
        return (a and not b) or (b and not a)
    end
    
    do -- http://lua-users.org/wiki/BinaryInsert
        local fcomp_default = function(a,b) return a < b end
        table.bininsert = table.bininsert or function(t, value, fcomp, ...)
            local fcomp = fcomp or fcomp_default
            local iStart,iEnd,iMid,iState = 1, #t, 1, 0
            while iStart <= iEnd do
                iMid = math.floor((iStart+iEnd)/2)
                if fcomp(value, t[iMid], ...) then
                    iEnd, iState = iMid-1, 0
                else
                    iStart, iState = iMid+1, 1
                end
            end
            table.insert(t, (iMid+iState), value)
            return iMid+iState
        end
    end
    
    local function copairs_internal(state, k)
        local i = state.i
        local t = state[i]
        local k, v = next(t, k)
        if k ~= nil then return k, v, t end
        i = i+1
        if i > #state then return nil end
        state.i = i
        t = state[i]
        k, v = next(t, nil)
        return k, v, t
    end
    _G.copairs = _G.copairs or function(...)
        local state = { i = 1, ... }
        return copairs_internal, state
    end
    
    local function coipairs_internal(state, k)
        local ti = state.ti
        local t = state[ti]
        local k = (k or 0)-state.ci+1
        if k <= #t then return state.ci+k, t[k], t end
        state.ci = state.ci+#t
        k = 1
        for ti = ti+1, #state do
            t = state[ti]
            if k <= #t then
                state.ti = ti
                return state.ci+k, t[1], t
            end
        end
        return nil
    end
    _G.coipairs = _G.coipairs or function(...)
        local state = { ci = 0, ti = 1, ... }
        return coipairs_internal, state
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
                return class.__init(class, table.new(class.size, 0), ...)
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

