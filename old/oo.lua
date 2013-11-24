
local oo = {}

oo.classof = getmetatable -- hopefully this aliasing doesn't mess up the fast function optimisation
oo.instanceof = function(instance, class)
    local mt = getmetatable(instance)
    return mt and mt[class]
end
oo.supersof = function(class)
    return getmetatable(class).__supers
end

oo.class = function(...)
    local superlist = {...}
    
    local class = superlist[#superlist]
    superlist[#superlist] = nil
    
    local inherit_metamethods, static, abstract, copy_method
    local super_i = 1
    while super_i <= #superlist do
        local super, super_isflag = superlist[super_i], true
        if super == 'inherit metamethods' then
            inherit_metamethods = true
        elseif super == 'static' then
            static = true
        elseif super == 'abstract' then
            abstract = true
        elseif super == 'copy method' then
            copy_method = true
        else super_isflag = false end
        if super_isflag then
            table.remove(superlist, super_i)
        else
            super_i = super_i+1
        end
    end
    local super_count = #superlist
    
    if inherit_metamethods then
        for super_i = 1, #superlist do
            local super = superlist[super_i]
            for k, v in pairs(super) do
                if (
                        class[k] == nil
                    and k == tostring(k)
                    and string.match(k, "^__")
                    and not oo.class_metablacklist[k]
                ) then
                    class[k] = v
                end
            end
        end
    end
    
    local metadummy = {}
    local indexdummy = newproxy and newproxy() or {}
    debug.setmetatable(indexdummy, metadummy)
    local class_index = class.__index or class
    class.__index = function(self, k)
        --print(class.__type.."."..k)
        metadummy.__index = class_index -- TODO: Test "dummy __index meta" vs "type(__index) switch"
        local v = indexdummy[k]
        if v == nil then
            for super_i = 1, #superlist do
                metadummy.__index = superlist[super_i].__index
                v = indexdummy[k]
                if v ~= nil then
                    return v
                end
            end
        end
        return v
    end
    class.__new = (
            abstract and function(class, obj, ...)
                error("cannot instantiate abstract class", 2)
            end
        or  class.__new
        or  function(class, obj, ...)
                -- TODO: Copy or template constructor
                return setmetatable(obj or {}, class)
            end
    )
    class.__construct = class.__construct or function() end
    
    class[class] = true -- to speed up `instanceof`
    class.__supers = superlist
    class.__class = class
    
    setmetatable(superlist, {
        __call = function(superlist, self, ...)
            for super_i = 1, #superlist do
                local super = superlist[super_i]
                super.__construct(self, super, super.__supers, ...)
            end
        end,
        __newindex = static and function(class, k, v)
            error("class is static", 2)
        end or nil,
    })
    
    if copy_method then
        error"NYI"
    end
    
    return setmetatable(
        class,
        setmetatable({
            __supers = superlist,
            __class = class,
            __call = function(class, obj, ...)
                obj = class.__new(class, obj, ...)
                class.__construct(obj, class, superlist, ...)
                return obj
            end,
            __index = function(class, k) -- for `instanceof`
                for super_i = 1, #superlist do
                    local v = superlist[super_i][k]
                    if v ~= nil then
                        return v
                    end
                end
                return nil
            end,
            __newindex = static and function(class, k, v)
                error("class is static", 2)
            end or nil,
        }, static and {
            __newindex = function(class, k, v)
                error("class is static", 2)
            end,
            __metatable = false,
        } or nil)
    )
end

oo.class_metablacklist = {
    __new = true,
    __construct = true,
    __gc = true,
}

return oo
