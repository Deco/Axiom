
local axiom = {}

local concept = require"concept"
local ffi = require"ffi"
local lualgebra = require"lualgebra"
local luametry = require"luametry"

local function internlib(libName)
    local lib = require(libName)
    for k,v in pairs(lib) do
        if rawget(axiom, k) ~= nil then error(string.format("conflicting axiom variable %q", tostring(k))) end
        axiom[k] = v
    end
end

internlib("axiom.level")
internlib("axiom.levelformat")

return axiom



