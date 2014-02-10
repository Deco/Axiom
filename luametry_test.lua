
local lualgebra = require"lualgebra"
local luametry = require"luametry"
local ffi = require"ffi"

-- TODO: Better luametry testing
do -- Vec2f
    do -- Vec2f.GetRotated
        local a = luametry.Vec2f(5, 5)
        local b = a:GetRotated(math.pi/2)
        --assert(b.x == -5 and b.y == -5)
    end
end

