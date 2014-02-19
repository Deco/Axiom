--- A module implementing vectors.
-- This module generally aims for performance over everything else.
-- @author Declan White
-- @author NightExcessive

local type = type
local setmetatable = setmetatable
local getmetatable = debug and debug.getmetatable or getmetatable
local sqrt, sin, cos, abs, max = math.sqrt, math.sin, math.cos, math.abs, math.max

math.equal = math.equal or function(a, b, magic)
    return abs(a-b) <= max(abs(a), abs(b))*(magic or --[[1e-11]]1e-5)
end

local _M = {}
local Vec3 = _M
local metatable = {__index = _M}
_M.__metatable = metatable
local new, isVec3

local ffi_ok, ffi = pcall(require, "ffi")
if ffi_ok and type(ffi) == "table" and ffi.cdef  then
    ffi_ok = true
    ffi.cdef[[
        struct Vec3d {
            double x, y, z;
        };
    ]]
    
    _M.new = ffi.metatype("struct Vec3d", metatable)
    
    function _M.isVec3(var)
        return ffi.istype(_M.new, var)
    end
else
    ffi_ok = false
    function _M.new(...)
        return metatable.__new(metatable, ...)
    end
    
    function _M.isVec3(var)
        return type(var) == "table" and getmetatable(var) == metatable
    end
end
new = _M.new
isVec3 = _M.isVec3

setmetatable(Vec3, {__call=function(self, ...) return self.new(...) end})

function metatable.__new(ct, x, y, z)
    local self = ffi_ok and ffi.new(ct) or setmetatable({}, ct)
    self.x = x
    self.y = y
    self.z = z
    return self
end

function Vec3.newFromAngle(inclination, azimuth, len)
    len = len or 1
    return new(
        len*sin(inclination)*cos(azimuth),
        len*sin(inclination)*sin(azimuth),
        len*cos(azimuth)
    )
end

function Vec3:set(x, y, z)
    self.x, self.y, self.z = x, y, z
    return self
end

function Vec3:copy()
    return new(self.x, self.y, self.z)
end
Vec3.clone = Vec3.copy

function Vec3:xyz()
    return self.x, self.y, self.z
end

function Vec3:unit()
    local len = sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
    return new(self.x/len, self.y/len, self.z/len)
end
function Vec3:unitSafe()
    local len = sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
    return len == 0 and new(0, 0) or new(self.x/len, self.y/len, self.z/len)
end

function Vec3:length()
    return sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
end
function Vec3:lengthSquared()
    return self.x * self.x + self.y * self.y + self.z * self.z
end

function Vec3:distanceSquared(other)
    return (self.x - other.x) ^ 2 + (self.y - other.y) ^ 2 + (self.z - other.z) ^ 2
end
function Vec3:distance(other)
    return sqrt((self.x - other.x) ^ 2 + (self.y - other.y) ^ 2, (self.z - other.z) ^ 2)
end

function Vec3:dot(other)
    return self.x*other.x+self.y*other.y+self.z*other.z
end

function Vec3:cross(other)
    return new(
        self.y*other.z - self.z*other.y,
        self.z*other.x - self.x*other.z,
        self.x*other.y - self.y*other.x
    )
end

function Vec3:rotateEuler(ang)
    error"nyi"
    local c, s = cos(ang), sin(ang)
    local x, y = self.x, self.y
    return new(c*x - s*y, s*x + c*y)
end

function Vec3:angle()
    error"nyi"
    return math.atan2(self.y, self.x)
end

function Vec3:abs()
    return new(abs(self.x), abs(self.y), abs(self.z))
end

--[[Q = 0
local util = require"util"]]
function Vec3:sign()
    --jit.off(true, false)
    --[[io.stdout:write(Q, " ", type(self.x), " ", type(self.y), " ")
    local x = self.x > 0 and 1 or self.x < 0 and -1 or 0
    local y = self.y > 0 and 1 or self.y < 0 and -1 or 0
    io.stdout:write(self.x, " ", self.y, " ")
    io.stdout:write(util.stringify(x), " ", util.stringify(y), "\n")
    if type(x) == "table" then
        blah(x, _G, {}, 0, "_G")
    end
    if type(y) == "table" then
        blah(y, _G, {}, 0, "_G")
    end]]
    return new(
        self.x > 0 and 1 or self.x < 0 and -1 or 0,
        self.y > 0 and 1 or self.y < 0 and -1 or 0,
        self.z > 0 and 1 or self.z < 0 and -1 or 0
    )
end

function Vec3:interpolate(other, f)
    return new(self.x*(1-f)+other.x*f, self.y*(1-f)+other.y*f, self.z*(1-f)+other.z*f)
end

--[[
function Vec3:leftOf(v, w)
    local cross = (w.x-v.x)*(self.y-v.y)-(w.y-v.y)*(self.x-v.x)
    return cross < 0
end]]

function Vec3:projectOntoLine(v, w, infinite)
    local l2 = v:distanceSquared(w)
    if l2 == 0 then return v, 0 end
    local t = (self-v):dot(w-v)/l2
    if not infinite then
        if t < 0 then return v, 0 end
        if t > 1 then return w, 1 end
    end
    local q = v+t*(w-v)
    return q, t
end

function Vec3:isInExtents(xmin, xmax, ymin, ymax, zmin, zmax)
    return (
            xmin < self.x and self.x < xmax
        and ymin < self.y and self.y < xmay
        and zmin < self.z and self.z < xmaz
    )
end
function Vec3:isInExtents(xmin, xmax, ymin, ymax, zmin, zmax)
    return (
            xmin <= self.x and self.x <= xmax
        and ymin <= self.y and self.y <= xmay
        and zmin <= self.z and self.z <= xmaz
    )
end

function Vec3:selfAdd(other)
    self.x, self.y, self.z = self.x + other.x, self.y + other.y, self.z + other.z
end
function Vec3:selfMul(other)
    if type(other) == "number" then
        self.x, self.y, sel.z = self.x * other, self.y * other, self.z * other
    else
        self.x, self.y, sel.z = self.x * other.x, self.y * other.y, self.z * other.z
    end
end

function metatable:__add(other)
    return new(self.x + other.x, self.y + other.y, self.z + other.z)
end

function metatable:__sub(other)
    return new(self.x - other.x, self.y - other.y, self.z - other.z)
end

function metatable:__mul(other)
    if type(other) == "number" then
        return new(self.x * other, self.y * other, self.z * other)
    elseif type(self) == "number" then
        return new(self * other.x, self * other.y, self * other.z)
    end
    return new(self.x * other.x, self.y * other.y, self.z * other.z)
end

function metatable:__div(other)
    if type(other) == "number" then
        return new(self.x / other, self.y / other, self.z * other)
    elseif type(self) == "number" then
        return new(other / self.x, other / self.y, self * other.z)
    end

    return new(self.x / other.x, self.y / other.y, self.z * other.z)
end

function metatable:__unm()
    return new(-self.x, -self.y, -self.z)
end

function metatable:__tostring(stringify, sh, sv, prec, sn, parsed)
    if stringify then
        return ("Vec3("
            ..stringify(self.x, sh, sv, prec, sn, parsed)..","
            ..stringify(self.y, sh, sv, prec, sn, parsed)..","
            ..stringify(self.z, sh, sv, prec, sn, parsed)..")"
        )
    else
        return "Vec3("..self.x..","..self.y.. ","..self.z..")"
    end
end

function metatable:__eq(other)
    return (
            isVec3(self) and isVec3(other)
        and self.x == other.x and self.y == other.y and self.z == other.z
    )
end

function Vec3:equal(other, magic)
    return (
            math.equal(self.x, other.x, magic)
        and math.equal(self.y, other.y, magic)
        and math.equal(self.z, other.z, magic)
    )
end

return _M
