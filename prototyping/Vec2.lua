--- A module implementing vectors.
-- This module generally aims for performance over everything else.
-- @author NightExcessive
-- @author Declan White

local type = type
local setmetatable = setmetatable
local getmetatable = debug and debug.getmetatable or getmetatable
local sqrt, sin, cos, abs, max = math.sqrt, math.sin, math.cos, math.abs, math.max

math.equal = math.equal or function(a, b, magic)
    return abs(a-b) <= max(abs(a), abs(b))*(magic or 1e-11)
end

local _M = {}
local Vec2 = _M
local metatable = {__index = _M}
_M.__metatable = metatable
local new, isVec2

local ffi_ok, ffi = pcall(require, "ffi")
if ffi_ok and type(ffi) == "table" and ffi.cdef  then
    ffi_ok = true
    ffi.cdef[[
        struct Vec2d {
            double x, y;
        };
    ]]
    
    _M.new = ffi.metatype("struct Vec2d", metatable)
    
    function _M.isVec2(var)
        return ffi.istype(_M.new, var)
    end
else
    ffi_ok = false
    function _M.new(...)
        return metatable.__new(metatable, ...)
    end
    
    function _M.isVec2(var)
        return type(var) == "table" and getmetatable(var) == metatable
    end
end
new = _M.new
isVec2 = _M.isVec2

setmetatable(Vec2, {__call=function(self, ...) return self.new(...) end})

function metatable.__new(ct, x, y)
    local self = ffi_ok and ffi.new(ct) or setmetatable({}, ct)
    self.x = x
    self.y = y
    return self
end

function Vec2.newFromAngle(ang, len)
    len = len or 1
    return new(cos(ang)*len, sin(ang)*len)
end

function Vec2:set(x, y)
    self.x, self.y = x, y
    return self
end

function Vec2:copy()
    return new(self.x, self.y)
end
Vec2.clone = Vec2.copy

function Vec2:xy()
    return self.x, self.y
end

function Vec2:unit()
    local len = sqrt(self.x * self.x + self.y * self.y)
    return new(self.x/len, self.y/len)
end
function Vec2:unitSafe()
    local len = sqrt(self.x * self.x + self.y * self.y)
    return len == 0 and new(0, 0) or new(self.x/len, self.y/len)
end

function Vec2:length()
    return sqrt(self.x * self.x + self.y * self.y)
end
function Vec2:lengthSquared()
    return self.x * self.x + self.y * self.y
end

function Vec2:distanceSquared(other)
    return (self.x - other.x) ^ 2 + (self.y - other.y) ^ 2
end
function Vec2:distance(other)
    return sqrt((self.x - other.x) ^ 2 + (self.y - other.y) ^ 2)
end

function Vec2:dot(other)
    return self.x*other.x+self.y*other.y
end

function Vec2:rotate(ang)
    local c, s = cos(ang), sin(ang)
    local x, y = self.x, self.y
    return new(c*x - s*y, s*x + c*y)
end

function Vec2:angle()
    return math.atan2(self.y, self.x)
end

function Vec2:abs()
    return new(abs(self.x), abs(self.y))
end

--[[Q = 0
local util = require"util"]]
function Vec2:sign()
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
        self.y > 0 and 1 or self.y < 0 and -1 or 0
    )
end

function Vec2:interpolate(other, f)
    return new(self.x*(1-f)+other.x*f, self.y*(1-f)+other.y*f)
end

function Vec2:leftOf(v, w)
    local cross = (w.x-v.x)*(self.y-v.y)-(w.y-v.y)*(self.x-v.x)
    return cross < 0
end

function Vec2:projectOntoLine(v, w, infinite)
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

function Vec2:isInExtents(r, d, l, u)
    return (
            l < self.x and self.x < r
        and u < self.y and self.y < d
    )
end
function Vec2:isInExtentsInclusive(r, d, l, u)
    return (
            -l <= self.x and self.x <= r
        and -u <= self.y and self.y <= d
    )
end

function Vec2:selfAdd(other)
    self.x, self.y = self.x + other.x, self.y + other.y
end
function Vec2:selfMul(other)
    if type(other) == "number" then
        self.x, self.y = self.x * other, self.y * other
    else
        self.x, self.y = self.x * other.x, self.y * other.y
    end
end

function metatable:__add(other)
    return new(self.x + other.x, self.y + other.y)
end

function metatable:__sub(other)
    return new(self.x - other.x, self.y - other.y)
end

function metatable:__mul(other)
    if type(other) == "number" then
        return new(self.x * other, self.y * other)
    elseif type(self) == "number" then
        return new(self * other.x, self * other.y)
    end
    return new(self.x * other.x, self.y * other.y)
end

function metatable:__div(other)
    if type(other) == "number" then
        return new(self.x / other, self.y / other)
    elseif type(self) == "number" then
        return new(other / self.x, other / self.y)
    end

    return new(self.x / other.x, self.y / other.y)
end

function metatable:__unm()
    return new(-self.x, -self.y)
end

function metatable:__tostring(stringify, sh, sv, prec, sn, parsed)
    if stringify then
        return ("Vec2("
            ..stringify(self.x, sh, sv, prec, sn, parsed)..","
            ..stringify(self.y, sh, sv, prec, sn, parsed)..")"
        )
    else
        return "Vec2("..self.x..","..self.y..")"
    end
end

function metatable:__eq(other)
    return (
            isVec2(self) and isVec2(other)
        and self.x == other.x and self.y == other.y
    )
end

function Vec2:equal(other, magic)
    return (
            math.equal(self.x, other.x, magic)
        and math.equal(self.y, other.y, magic)
        and math.equal(self.z, other.z, magic)
    )
end


return _M
