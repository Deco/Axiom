
local Vec3 = require"Vec3"

local type = type
local setmetatable = setmetatable
local getmetatable = debug and debug.getmetatable or getmetatable
local sqrt, abs, max = math.sqrt, math.abs, math.max

math.equal = math.equal or function(a, b, magic)
    return abs(a-b) <= max(abs(a), abs(b))*(magic or --[[1e-11]]1e-5)
end

local _M = {}
local Quaternion = _M
local metatable = {__index = _M}
_M.__metatable = metatable
local new, isQuaternion

local ffi_ok, ffi = pcall(require, "ffi")
if ffi_ok and type(ffi) == "table" and ffi.cdef then
    ffi_ok = true
    ffi.cdef[[
        struct Quaternion {
            double a, b, c, d;
        }
    ]]
    
    _M.new = ffi.metatype("struct Quaternion", metatable)
    
    function _M.isQuaternion(var)
        return ffi.istype(_M.new, var)
    end
else
    error"nyi"
end
new = _M.new
isQuaternion = _M.isQuaternion

setmetatable(Quaternion, {__call=function(self, ...) return self.new(...) end})

function metatable.__new(ct, a, b, c, d)
    local self = ffi_ok and ffi.new(ct) or setmetatable({}, ct)
    self.a, self.b, self.c, self.d = a, b, c, d
    return self
end
function Quaternion.newFromUnit()
    return new(1, 0, 0, 0)
end
function Quaternion.newFromAngleAxis(ang, axis)
    local halfang = ang*0.5
    local halfang_sin = math.sin(halfang)
    return new(math.cos(halfang), halfang_sin*axis.x, halfang_sin*axis.y, halfang_sin*axis.z)
end
--[[function Quaternion.newFromRotation(ang, axis)
    return new(0, axis.x, axis.y, axis.z):unit()*math.sin(a/2)+math.cos(a/2)
end]]

function Quaternion:real()
    return self.a
end
function Quaternion:vector()
    return Vec3(self.b, self.c, self.d)
end

function Quaternion:isZero()
    return self.a == 0 and self.b == 0 and self.c == 0 and self.d == 0
end
function Quaternion:isReal()
    return self.b == 0 and self.c == 0 and self.d == 0
end
function Quaternion:isImaginary()
    return self.a == 0
end
function Quaternion:dot(other)
    return self.a * other.a + self.b * other.b + self.c * other.c + self.d * other.d
end

function Quaternion:length()
    return sqrt(self.a^2 + self.b^2 + self.c^2 + self.d^2)
end
function Quaternion:lengthSquared()
    return self.a^2 + self.b^2 + self.c^2 + self.d^2
end

function Quaternion:unit()
    local len = sqrt(self.a^2 + self.b^2 + self.c^2 + self.d^2)
    return new(self.a/len, self.b/len, self.c/len, self.d/len)
end
function Quaternion:unitSafe()
    local len = sqrt(self.a^2 + self.b^2 + self.c^2 + self.d^2)
    return len == 0 and new(0, 0, 0, 0) or new(self.a/len, self.b/len, self.c/len, self.d/len)
end

function Quaternion:conjugate()
    return new(self.a, -self.b, -self.c, -self.d)
end
function Quaternion:reciprocal()
    local invlen = 1/self:lengthSquared()
    return new(self.a*invlen, -self.b*invlen, -self.c*invlen, -self.d*invlen)
end
function Quaternion:reciprocal()
    local len = self:lengthSquared()
    return new(self.a/len, -self.b/len, -self.c/len, -self.d/len)
end
function Quaternion:reciprocalSafe()
    local len = self:lengthSquared()
    return len == 0 and new(0, 0, 0, 0) or new(self.a/len, -self.b/len, -self.c/len, -self.d/len)
end

function Quaternion:hamRight(other)
    local a,b,c,d
    a = self.a * other.a - self.b * other.b - self.c * other.c - self.d * other.d
    b = self.a * other.b + self.b * other.a + self.c * other.d - self.d * other.c
    c = self.a * other.c - self.b * other.d + self.c * other.a + self.d * other.b
    d = self.a * other.d + self.b * other.c - self.c * other.b + self.d * other.a
    return new(a,b,c,d)
end
function Quaternion:hamLeft(other)
    return other:hamRight(self)
end

function Quaternion:vecmul(vec)
    local qvec = Vec3(self.b, self.c, self.d)
    local uvec = qvec:cross(vec)
    local uuvec = qvec:cross(uvec)
    uvec, uuvec = uvec*2*self.a, uuvec*2
    return vec+uvec+uuvec
end

function Quaternion:right() return self:vecmul(Vec3( 1, 0, 0)) end
function Quaternion:left () return self:vecmul(Vec3(-1, 0, 0)) end
function Quaternion:up   () return self:vecmul(Vec3( 0, 1, 0)) end
function Quaternion:down () return self:vecmul(Vec3( 0,-1, 0)) end
function Quaternion:front() return self:vecmul(Vec3( 0, 0, 1)) end Quaternion.forward = Quaternion.front
function Quaternion:back () return self:vecmul(Vec3( 0, 0,-1)) end Quaternion.backward = Quaternion.back

function metatable:__mul(other)
    if type(other) == "number" then
        return new(self.a * other, self.b * other, self.c * other, self.d * other)
    elseif type(self) == "number" then
        return new(self * other.a, self * other.b, self * other.c, self * other.d)
    end
    --return new(self.a * other.a, self.b * other.b, self.c * other.c, self.d * other.d)
    --error("Cannot multiply quaternions")
    if isQuaternion(self) and isQuaternion(other) then
        return self:hamRight(other)
    end
    return nil
end

function Quaternion:__add(other)
    if type(other) == "number" then
        return new(self.a + other, self.b, self.c, self.d)
    elseif isQuaternion(other) then
        return new(self.a + other.a, self.b + other.b, self.c + other.c, self.d + other.d)
    end
    return nil
end

function Quaternion:__sub(other)
    if type(other) == "number" then
        return new(self.a - other, self.b, self.c, self.d)
    elseif isQuaternion(other) then
        return new(self.a - other.a, self.b - other.b, self.c - other.c, self.d - other.d)
    end
    return nil
end

function Quaternion:__unm()
    return new(-self.a, -self.b, -self.c, -self.d)
end

function Quaternion:__pow(other)
    assert(n == math.floor(n), "non-integer quaternion power")
    if n == 0 then
        return new(1, 0, 0, 0)
    elseif n > 0 then
        return self:hamRight(self^(n-1))
    elseif n < 0 then
        return self:reciprocal()^(-n)
    end
    return nil
end

function Quaternion:__div(other)
    if type(other) == "number" then
        return new(self.a/other, self.b/other, self.c/other, self.d/other)
    elseif type(other) == "number" then
        return new(other/self.a, other/self.b, other/self.c, other/self.d)
    end
    if isQuaternion(self) and isQuaternion(other) then
        return self:hamRight(other:reciprocal())
    end
    return nil
end

function Quaternion:__tostring(stringify, sh, sv, prec, sn, parsed)
    if stringify then
        return ("Quaternion("
            ..stringify(self.a, sh, sv, prec, sn, parsed)..","
            ..stringify(self.b, sh, sv, prec, sn, parsed)..","
            ..stringify(self.c, sh, sv, prec, sn, parsed)..","
            ..stringify(self.d, sh, sv, prec, sn, parsed)..")"
        )
    else
        return "Quaternion("..self.a..","..self.b.. ","..self.c..","..self.d..")"
    end
end

function metatable:__eq(other)
    return (
            isQuaternion(self) and isQuaternion(other)
        and self.a == other.a and self.b == other.b and self.c == other.c and self.d == other.d
    )
end

function Quaternion:equal(other, magic)
    return (
            math.equal(self.a, other.a, magic)
        and math.equal(self.b, other.b, magic)
        and math.equal(self.c, other.c, magic)
        and math.equal(self.d, other.d, magic)
    )
end

return _M
