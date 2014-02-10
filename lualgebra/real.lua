
local lualgebra = {}

local concept = require"concept"
local ffi = require"ffi"

local gmp

lualgebra.ExactReal = concept{
    ffiTypeName = "mpr_t",
}

function lualgebra.ExactReal.__declare(class)
    gmp = ffi.load("libgmp.so.10")
    lualgebra.gmp = gmp
    
    ffi.cdef[[
        typedef struct {
            
        } mpr_t;
    ]]
    
    class.ffiType = ffi.metatype(class.ffiTypeName, class)
    return function(class, ...) return class.ffiType(...) end
end

function lualgebra.ExactReal.__new(ct, val, base)
    local obj = ffi.new(ct)
    error("NYI!")
    return obj
end
function lualgebra.ExactReal:__gc()
    
end

function lualgebra.ExactReal:__tostring()
    
end

return lualgebra
