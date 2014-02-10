
local lualgebra = {}

local ffi = require"ffi"

ffi.cdef[[ typedef struct { } mpq_t; ]]

return lualgebra
