
local luametry = {}

local concept = require"concept"
local ffi = require"ffi"
local lualgebra = require"lualgebra"

local function internlib(libName)
    local lib = require(libName)
    for k,v in pairs(lib) do
        -- if rawget(luametry, k) ~= nil then error(string.format("conflicting luametry variable %q", tostring(k))) end
        luametry[k] = v
    end
end

internlib("luametry.coordinate")
internlib("luametry.space")

return luametry
