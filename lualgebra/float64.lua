
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

lualgebra.Float64.pi = math.pi
lualgebra.Float64.epsilon = 2.22e-15

lualgebra.Float64.abs   = math.abs
lualgebra.Float64.sign  = math.sign or function(x) return x>0 and 1 or x<0 and -1 or 0 end
lualgebra.Float64.pow   = math.pow
lualgebra.Float64.sqrt  = math.sqrt
lualgebra.Float64.sin   = math.sin
lualgebra.Float64.cos   = math.cos
lualgebra.Float64.acos  = math.acos

lualgebra.Float64.GetAbs    = lualgebra.Float64.abs
lualgebra.Float64.GetSign   = lualgebra.Float64.sign
lualgebra.Float64.GetPow    = lualgebra.Float64.pow
lualgebra.Float64.GetSqrt   = lualgebra.Float64.sqrt
lualgebra.Float64.GetSin    = lualgebra.Float64.sin
lualgebra.Float64.GetCos    = lualgebra.Float64.cos
lualgebra.Float64.GetArcCos = lualgebra.Float64.acos

function lualgebra.Float64:GetIsEqualTo(other)
    --[[print("eq", self, other,
        math.abs(self-other) <= math.max(math.abs(self*self.epsilon), math.abs(other*self.epsilon)),
        math.abs(self-other),
        math.max(math.abs(self*self.epsilon), math.abs(other*self.epsilon))
    )]]
    return math.abs(self-other) <= math.max(math.abs(self*self.epsilon), math.abs(other*self.epsilon))
end

function lualgebra.Float64:GetIsEqualToZero()
    return math.abs(self) <= self.epsilon
end

function lualgebra.Float64:ToFloat64()
    return self
end

function lualgebra.Float64:GetCopy()
    return self
end

return lualgebra
