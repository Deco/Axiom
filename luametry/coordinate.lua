
local luametry = {}

local concept = require"concept"
local ffi = require"ffi"
local lualgebra = require"lualgebra"

luametry.Coordinate = concept{
    const = false,
    dimensionCount = nil              , -- param: integer >= 1
  --fieldTypeName  = "double"         , -- param: ffi typename
  --fieldTypeNew   = function(val)      -- param: ffi type constructor
  --    return ffi.new("double", val)
  --end,
  --fieldType = concept{ ffiTypeName = "..." }, -- param: ffi type, which is used to derive fieldTypeName and fieldTypeNew
    
    -- assertion: field ffi type must be a metatype that supports standard number metamethods (unm,add,sub,mul,div,mod,pow,eq,lt)
    
}

do -- specialisations
luametry.Vec2f  = luametry.Coordinate%{ const = false, dimensionCount = 2, fieldTypeName = "double", fieldTypeNew = function(val) return ffi.new("double", val) end }
luametry.Vec3f  = luametry.Coordinate%{ const = false, dimensionCount = 3, fieldTypeName = "double", fieldTypeNew = function(val) return ffi.new("double", val) end }
luametry.Vec2cf = luametry.Coordinate%{ const = true , dimensionCount = 2, fieldTypeName = "double", fieldTypeNew = function(val) return ffi.new("double", val) end }
luametry.Vec3cf = luametry.Coordinate%{ const = true , dimensionCount = 3, fieldTypeName = "double", fieldTypeNew = function(val) return ffi.new("double", val) end }
luametry.Vec2z  = luametry.Coordinate%{ const = false, dimensionCount = 2, fieldType = lualgebra.ExactInteger }
luametry.Vec3z  = luametry.Coordinate%{ const = false, dimensionCount = 3, fieldType = lualgebra.ExactInteger }
luametry.Vec2r  = luametry.Coordinate%{ const = false, dimensionCount = 2, fieldType = lualgebra.ExactReal }
luametry.Vec3r  = luametry.Coordinate%{ const = false, dimensionCount = 3, fieldType = lualgebra.ExactReal }
end

luametry.Coordinate.requiredMethodList = {
    --"add", -- improves performance with complex structs (like mpz_t), but reduces performance with primitives
             -- just have to leave LuaJIT to optimise __add
    "abs", "sign", "eqzero",
    "pow", "sqrt",
    "sin", "cos",  "atan2"
}

do
    function luametry.Coordinate.__declare(class)
        assert(tonumber(class.dimensionCount), "Coordinate.dimensionCount must be an integer")
        assert(class.dimensionCount%1 == 0   , "Coordinate.dimensionCount must be an integer")
        assert(class.dimensionCount >= 1     , "Coordinate.dimensionCount must be >= 1"      )
        
        assert(class.dimensionCount == 2 or class.dimensionCount == 3, "NYI (only 2D & 3D coordinates are supported)")
        
        if class.fieldType then
            assert(not class.fieldTypeName, "cannot specify both Coordinate.fieldType and Coordinate.fieldTypeName")
            assert(not class.fieldTypeNew , "cannot specify both Coordinate.fieldType and Coordinate.fieldTypeNew" )
            
            concept.Finalise(class.fieldType) -- important, as ffiTypeName may not yet be defined
            
            class.fieldTypeName = class.fieldType.ffiTypeName
            class.fieldTypeNew = class.fieldType
        else
            assert(class.fieldTypeName, "must specify Coordinate.fieldType, or Coordinate.fieldTypeName & Coordinate.fieldTypeNew")
            assert(class.fieldTypeNew , "must specify Coordinate.fieldType, or Coordinate.fieldTypeName & Coordinate.fieldTypeNew" )
            assert(type(class.fieldTypeName) == "string", "Coordinate.fieldTypeName must be a valid FFI type name")
        end
        local methodTableList = (
                class.dimensionCount == 2 and {luametry.__coord2dConstantMethods, not class.const and luametry.__coord2dMutateMethods or nil}
            or  class.dimensionCount == 3 and {luametry.__coord3dConstantMethods, not class.const and luametry.__coord3dMutateMethods or nil}
            or  error("NYI (only 2D & 3D coordinates are supported)")
        )
        for i,methodTable in ipairs(methodTableList) do
            for k,v in pairs(methodTable) do
                local ov = class[k]
                if ov == luametry.Coordinate[k] then
                    class[k] = v
                end
            end
        end
        
        local fieldTypeInstance = ffi.new(class.fieldTypeName)
        for i,methodName in pairs(class.requiredMethodList) do
            local fieldTypeMethod = nil
            pcall(function()
                -- this feels messy... but seems to work alright
                -- it would be nicer if we could get the metatable of the FFI type... but getmetatable(cdata) just gives "ffi"
                -- and debug.getmetatable(cdata) gives the generic cdata metatable
                -- __metatable doesn't seem to work at all
                fieldTypeMethod = fieldTypeInstance[methodName]
                if type(fieldTypeMethod) ~= "function" then fieldTypeMethod = nil end -- KILL MEEEE
            end)
            class["v_"..methodName] = fieldTypeMethod or math[methodName] -- for primitive types
        end
        
        class.ffiTypeName = string.format("lmc%d_%s_t",
            class.dimensionCount,
            class.fieldTypeName
        )
        local cdef = string.format(
            [[
                typedef union {
                    %s struct {
                        %s %s %s;
                    };
                    %s %s v[%d];
                } %s;
            ]],
            class.const and "const" or "",
            class.const and "const" or "",
            class.fieldTypeName,
            table.concat({class:GetAxisNames()}, ", "),
            class.const and "const" or "",
            class.fieldTypeName,
            class.dimensionCount,
            class.ffiTypeName
        )
        ffi.cdef(cdef)
        
        class.ffiFieldType = ffi.typeof(class.fieldTypeName)
        class.ffiType = ffi.metatype(class.ffiTypeName, class)
        class.__generateMethods(class)
        return function(class, ...) return class.ffiType(...) end
    end
end

do -- generic
    function luametry.Coordinate:GetCrossProduct(other)
        error"NYI"
    end
end

do luametry.__coord2dConstantMethods = {}
    function luametry.__coord2dConstantMethods.__generateMethods(class)
        -- type dependent methods
        local ffiType = class.ffiType
        function class:Mul(other)
            if ffi.istype(ffiType, self) then
                if ffi.istype(ffiType, other) then
                    error("NYI!")
                else
                    return ffi.typeof(self)(self.x*other, self.y*other)
                end
            elseif ffi.istype(ffiType, other) then
                if ffi.istype(ffiType, self) then
                    error("NYI!")
                else
                    return ffi.typeof(other)(self*other.x, self*other.y)
                end
            else error"wat" end
        end
        class.__mul = class.Mul
        function class:Div(other)
            if ffi.istype(ffiType, self) then
                if ffi.istype(ffiType, other) then
                    error("NYI!")
                else
                    return ffi.typeof(self)(self.x/other, self.y/other)
                end
            elseif ffi.istype(ffiType, other) then
                if ffi.istype(ffiType, self) then
                    error("NYI!")
                else
                    return ffi.typeof(other)(self/other.x, self/other.y)
                end
            else error"wat" end
        end
        class.__div = class.Div
    end
    
    function luametry.__coord2dConstantMethods.GetAxisNames()
        return "x", "y"
    end
    function luametry.__coord2dConstantMethods.__new(ct, x, y)
        return ffi.new(ct, x, y)
    end
    function luametry.__coord2dConstantMethods:NewFromAngle(ang, mag)
        mag = mag or 1
        return ffi.typeof(self)(self.v_cos(ang)*mag, self.v_sin(ang)*mag)
    end
    function luametry.__coord2dConstantMethods:GetCopy()
        return ffi.typeof(self)(self.x:GetCopy(), self.y:GetCopy())
    end
    function luametry.__coord2dConstantMethods:__tostring()
        return string.format("%s(%s, %s)", self.ffiTypeName, tostring(self.x), tostring(self.y))
    end
    function luametry.__coord2dConstantMethods:GetXY()
        return self.x, self.y
    end
    function luametry.__coord2dConstantMethods:GetNormalized()
        local mag = self.v_sqrt(self.v_pow(self.x, 2) + self.v_pow(self.y, 2))
        return ffi.typeof(self)(self.x/mag, self.y/mag)
    end
    function luametry.__coord2dConstantMethods:GetNormalizedSafe()
        -- local mag = self.v_sqrt(self.v_pow(self.x, 2) + self.v_pow(self.y, 2))
        -- return mag == 0 and ffi.typeof(self)() or ffi.typeof(self)(self.x/mag, self.y/mag)
        error"NYI" -- need proper double comparison
    end
    function luametry.__coord2dConstantMethods:GetMagnitude()
        return self.v_sqrt(self.v_pow(self.x, 2) + self.v_pow(self.y, 2))
    end
    function luametry.__coord2dConstantMethods:GetDistSqr(other)
        return self.v_pow(self.x-other.x, 2) + self.v_pow(self.y-other.y, 2)
    end
    function luametry.__coord2dConstantMethods:GetDist(other)
        return self.v_sqrt(self.v_pow(self.x-other.x, 2) + self.v_pow(self.y-other.y, 2))
    end
    function luametry.__coord2dConstantMethods:GetDot(other)
        return self.x*other.x+self.y*other.y
    end
    function luametry.__coord2dConstantMethods:GetRotated(ang)
        local c, s = self.v_cos(ang), self.v_sin(ang)
        return ffi.typeof(self)(c*self.x - s*self.y, s*self.x + c*self.y)
    end
    function luametry.__coord2dConstantMethods:GetDirection()
        return self.v_atan2(self.y, self.x)
    end
    function luametry.__coord2dConstantMethods:GetAbs()
        return ffi.typeof(self)(self.v_abs(self.x), self.v_abs(self.y))
    end
    function luametry.__coord2dConstantMethods:GetSign()
        error"NYI"
    end
    
    function luametry.__coord2dConstantMethods:GetNegative()
        return ffi.typeof(self)(-self.x, -self.y)
    end
    luametry.__coord2dConstantMethods.__unm = luametry.__coord2dConstantMethods.GetNegative
    function luametry.__coord2dConstantMethods:Add(other)
        return ffi.typeof(self)(self.x+other.x, self.y+other.y)
    end
    luametry.__coord2dConstantMethods.__add = luametry.__coord2dConstantMethods.Add
    function luametry.__coord2dConstantMethods:Sub(other)
        return ffi.typeof(self)(self.x-other.x, self.y-other.y)
    end
    luametry.__coord2dConstantMethods.__sub = luametry.__coord2dConstantMethods.Sub
    
    function luametry.__coord2dConstantMethods:GetIsEqualTo(other)
        return (
                self.x:GetIsEqualTo(other.x)
            and self.y:GetIsEqualTo(other.y)
        )
    end
    luametry.__coord2dConstantMethods.__eq = luametry.__coord2dConstantMethods.GetIsEqualTo
    
    function luametry.__coord2dConstantMethods:GetIsEqualToZero(other)
        return (
                self.x:GetIsEqualToZero()
            and self.y:GetIsEqualToZero()
        )
    end
end
do luametry.__coord2dMutateMethods = {}
    function luametry.__coord2dConstantMethods:Set(x, y)
        self.x, self.y = x, y
        return self
    end
end

do luametry.__coord3dConstantMethods = {}
    function luametry.__coord3dConstantMethods.__generateMethods(class)
        -- type dependent methods
        local ffiType = class.ffiType
        function class:Mul(other)
            if ffi.istype(ffiType, self) then
                if ffi.istype(ffiType, other) then
                    error("NYI!")
                else
                    return ffi.typeof(self)(self.x*other, self.y*other, self.z*other)
                end
            elseif ffi.istype(ffiType, other) then
                if ffi.istype(ffiType, self) then
                    error("NYI!")
                else
                    return ffi.typeof(other)(self*other.x, self*other.y, self*other.z)
                end
            else error"wat" end
        end
        class.__mul = class.Mul
        function class:Div(other)
            if ffi.istype(ffiType, self) then
                if ffi.istype(ffiType, other) then
                    error("NYI!")
                else
                    return ffi.typeof(self)(self.x/other, self.y/other, self.z/other)
                end
            elseif ffi.istype(ffiType, other) then
                if ffi.istype(ffiType, self) then
                    error("NYI!")
                else
                    return ffi.typeof(other)(self/other.x, self/other.y, self/other.z)
                end
            else error"wat" end
        end
        class.__div = class.Div
    end
    
    function luametry.__coord3dConstantMethods.GetAxisNames()
        return "x", "y", "z"
    end
    function luametry.__coord3dConstantMethods.__new(ct, x, y, z)
        return ffi.new(ct, x, y, z)
    end
    function luametry.__coord3dConstantMethods:NewFromAngle(ang, mag)
        error"NYI"
    end
    function luametry.__coord3dConstantMethods:GetCopy()
        return ffi.typeof(self)(self.x:GetCopy(), self.y:GetCopy(), self.z:GetCopy())
    end
    function luametry.__coord3dConstantMethods:__tostring()
        return string.format("%s(%s, %s, %s)", self.ffiTypeName, tostring(self.x), tostring(self.y), tostring(self.z))
    end
    function luametry.__coord3dConstantMethods:GetXYZ()
        return self.x, self.y, self.z
    end
    function luametry.__coord3dConstantMethods:GetNormalized()
        local mag = self.v_sqrt(self.v_pow(self.x, 2) + self.v_pow(self.y, 2) + self.v_pow(self.z, 2))
        return ffi.typeof(self)(self.x/mag, self.y/mag, self.z/mag)
    end
    function luametry.__coord3dConstantMethods:GetNormalizedSafe()
        error"NYI"
    end
    function luametry.__coord3dConstantMethods:GetMagnitude()
        return self.v_sqrt(self.v_pow(self.x, 2) + self.v_pow(self.y, 2)  + self.v_pow(self.z, 2))
    end
    function luametry.__coord3dConstantMethods:GetDistSqr(other)
        return self.v_pow(self.x-other.x, 2) + self.v_pow(self.y-other.y, 2) + self.v_pow(self.z-other.z, 2)
    end
    function luametry.__coord3dConstantMethods:GetDist(other)
        return self.v_sqrt(self.v_pow(self.x-other.x, 2) + self.v_pow(self.y-other.y, 2) + self.v_pow(self.z-other.z, 2))
    end
    function luametry.__coord3dConstantMethods:GetDotProduct(other)
        return self.x*other.x+self.y*other.y+self.z*other.z
    end
    function luametry.__coord3dConstantMethods:GetCrossProduct(other)
        return ffi.typeof(self)(
            self.y*other.z - self.z*other.y,
            self.z*other.x - self.x*other.z,
            self.x*other.y - self.y*other.x
        )
    end
    function luametry.__coord3dConstantMethods:GetRotated(ang)
        error"NYI"
    end
    function luametry.__coord3dConstantMethods:GetDirection()
        error"NYI"
    end
    function luametry.__coord3dConstantMethods:GetClosestLinePoint(a, b)
        local v, w = b-a, self-a
        local c1, c2 = w:GetDotProduct(v), v:GetDotProduct(v)
        if c1 <= 0  then return (a-self):GetMagnitude(), a, 0 end
        if c2 <= c1 then return (b-self):GetMagnitude(), b, 1 end
        local t = c1/c2
        local r = a+t*v
        return (r-self):GetMagnitude(), r, t
    end
    function luametry.__coord3dConstantMethods:GetClosestLineT(a, b)
        local v, w = b-a, self-a
        local c1, c2 = w:GetDotProduct(v), v:GetDotProduct(v)
        return c1/c2
    end
    function luametry.__coord3dConstantMethods:GetAbs()
        return ffi.typeof(self)(self.v_abs(self.x), self.v_abs(self.y), self.v_abs(self.z))
    end
    function luametry.__coord3dConstantMethods:GetSign()
        error"NYI"
    end
    
    function luametry.__coord3dConstantMethods:GetNegative()
        return ffi.typeof(self)(-self.x, -self.y, -self.z)
    end
    luametry.__coord3dConstantMethods.__unm = luametry.__coord3dConstantMethods.GetNegative
    function luametry.__coord3dConstantMethods:Add(other)
        return ffi.typeof(self)(self.x+other.x, self.y+other.y, self.z+other.z)
    end
    luametry.__coord3dConstantMethods.__add = luametry.__coord3dConstantMethods.Add
    function luametry.__coord3dConstantMethods:Sub(other)
        return ffi.typeof(self)(self.x-other.x, self.y-other.y, self.z-other.z)
    end
    luametry.__coord3dConstantMethods.__sub = luametry.__coord3dConstantMethods.Sub
    
    function luametry.__coord3dConstantMethods:GetIsEqualTo(other)
        return (
                self.x:GetIsEqualTo(other.x)
            and self.y:GetIsEqualTo(other.y)
            and self.z:GetIsEqualTo(other.z)
        )
    end
    luametry.__coord3dConstantMethods.__eq = luametry.__coord3dConstantMethods.GetIsEqualTo
    
    function luametry.__coord3dConstantMethods:GetIsEqualToZero(other)
        return (
                self.x:GetIsEqualToZero()
            and self.y:GetIsEqualToZero()
            and self.z:GetIsEqualToZero()
        )
    end
end
do luametry.__coord3dMutateMethods = {}
    function luametry.__coord3dConstantMethods:Set(x, y, z)
        self.x, self.y, self.z = x, y, z
        return self
    end
end

return luametry
