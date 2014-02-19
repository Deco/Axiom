
local lualgebra = {}

local concept = require"concept"
local ffi = require"ffi"

lualgebra.Float64 = concept{
    const = true,
    ffiTypeName = "double",
}

debug.setmetatable(1234, { __index = lualgebra.Float64 }) -- :)

function lualgebra.Float64.__init(class, existingObj, ...)
    if existingObj then
        return tonumber(existingObj)
    end
    return 0
end

math.round = function(x, digit, base)
    local mul = (base or 10)^(-(digit or 0))
    return math.floor(x*mul+0.5)/mul
end
math.wrap = math.wrap or function(val, min, max)
    error"NYI"
end
math.randrange = math.randrange or function(min, max)
    return min+math.random()*(max-min)
end

lualgebra.Float64.pi = math.pi
-- lualgebra.Float64.epsilon = 1.22e-15
lualgebra.Float64.epsilon = 1.22e-13

if math.log(16, 2) ~= 4 then
    local logOrig = math.log
    math.log = function(value, base)
        if not tonumber(base) then return logOrig(value) end
        return logOrig(value)/logOrig(base)
    end
end

lualgebra.Float64.abs   = math.abs
lualgebra.Float64.sign  = math.sign or function(x) return x>0 and 1 or x<0 and -1 or 0 end
lualgebra.Float64.pow   = math.pow
lualgebra.Float64.log   = math.log
lualgebra.Float64.sqrt  = math.sqrt
lualgebra.Float64.sin   = math.sin
lualgebra.Float64.cos   = math.cos
lualgebra.Float64.acos  = math.acos
lualgebra.Float64.floor = math.floor
lualgebra.Float64.ceil  = math.ceil
lualgebra.Float64.round = math.round
lualgebra.Float64.randrange = math.randrange
lualgebra.Float64.min   = math.min

lualgebra.Float64.GetAbs    = lualgebra.Float64.abs
lualgebra.Float64.GetSign   = lualgebra.Float64.sign
lualgebra.Float64.GetPow    = lualgebra.Float64.pow
lualgebra.Float64.GetSqrt   = lualgebra.Float64.sqrt
lualgebra.Float64.GetSin    = lualgebra.Float64.sin
lualgebra.Float64.GetCos    = lualgebra.Float64.cos
lualgebra.Float64.GetArcCos = lualgebra.Float64.acos

function lualgebra.Float64:GetIsEqualTo(other)
    return math.abs(self-other) <= math.max(math.abs(self*self.epsilon), math.abs(other*self.epsilon))
end

function lualgebra.Float64:GetIsEqualToZero()
    return math.abs(self) <= self.epsilon
end

function lualgebra.Float64:GetIsLessThanOrEqualTo(other)
    return self <= other+math.max(math.abs(self*self.epsilon), math.abs(other*self.epsilon))
end
function lualgebra.Float64:GetIsGreaterThanOrEqualTo(other)
    return self >= other-math.max(math.abs(self*self.epsilon), math.abs(other*self.epsilon))
end

function lualgebra.Float64:ToFloat64()
    return self
end

function lualgebra.Float64:GetCopy()
    return self
end

return lualgebra
