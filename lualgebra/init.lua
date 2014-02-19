
local lualgebra = {}

local concept = require"concept"
local ffi = require"ffi"

local function internlib(libName)
    local lib = require(libName)
    for k,v in pairs(lib) do
        -- if rawget(lualgebra, k) ~= nil then error(string.format("conflicting lualgebra variable %q", tostring(k))) end
        lualgebra[k] = v
    end
end

-- setmetatable(lualgebra, {
    -- __index = {
        -- ExactInteger  = function(...) internlib("lualgebra.integer" ) return lualgebra.ExactInteger (...) end,
        -- ExactRational = function(...) internlib("lualgebra.rational") return lualgebra.ExactRational(...) end,
        -- ExactReal     = function(...) internlib("lualgebra.real"    ) return lualgebra.ExactReal    (...) end,
        -- ExactComplex  = function(...) internlib("lualgebra.complex" ) return lualgebra.ExactComplex (...) end,
    -- }
-- })
internlib("lualgebra.float64" )
internlib("lualgebra.integer" )
internlib("lualgebra.rational")
internlib("lualgebra.real"    )
internlib("lualgebra.complex" )

function lualgebra.InstallShortcuts(env)
    env = env or _G
    env.MPZ = lualgebra.ExactInteger
    env.MPQ = lualgebra.ExactRational
    env.MPR = lualgebra.ExactReal
    env.MPC = lualgebra.ExactComplex
    return env
end

return lualgebra
