
local lualgebra = {}

local ffi = require"ffi"

ffi.cdef[[ typedef struct { } mpc_t; ]]

return lualgebra
