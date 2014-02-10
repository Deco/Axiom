
--jit.off(true, true)

local lualgebra = require"lualgebra"
local ffi = require"ffi"

-- tests!
-- horrible coverage, but meh

for i = 1, n or 1 do
    do -- ExactInteger
        do -- ExactInteger.SetMPZ
            local a = lualgebra.ExactInteger()
            local b = lualgebra.ExactInteger(1)
            a:Set(b)
            assert(a:__tostring() == "1")
        end
        do -- ExactInteger.SetSI
            local a = lualgebra.ExactInteger()
            a:Set(ffi.new("signed long int", -1))
            assert(a:__tostring() == "-1")
        end
        do -- ExactInteger.SetUI
            local a = lualgebra.ExactInteger()
            a:Set(ffi.new("unsigned long int", 1))
            assert(a:__tostring() == "1")
        end
        do -- ExactInteger.SetStr
            local a = lualgebra.ExactInteger()
            a:Set("1")
            assert(a:__tostring() == "1")
        end
        do -- ExactInteger.SetDouble
            local a = lualgebra.ExactInteger()
            a:Set(1.5)
            assert(a:__tostring() == "1")
        end

        do -- ExactInteger.SetNeg
            local a = lualgebra.ExactInteger(1)
            a:SetNeg()
            assert(a:__tostring() == "-1")
        end

        do -- ExactInteger.IncByMPZ
            local a = lualgebra.ExactInteger("9263591128439081")
            local b = lualgebra.ExactInteger("7612058254738945")
            a:IncBy(b)
            assert(a:__tostring() == "16875649383178026")
        end
        do -- ExactInteger.IncBy double
            local a = lualgebra.ExactInteger("761205825473894599999999999")
            a:IncBy(1)
            assert(a:__tostring() == "761205825473894600000000000")
        end
        do -- ExactInteger.IncByUI
            local a = lualgebra.ExactInteger("761205825473894599999999999")
            a:IncBy(ffi.new("unsigned long int", 1))
            assert(a:__tostring() == "761205825473894600000000000")
        end
        do -- ExactInteger.IncBySI
            local a = lualgebra.ExactInteger("761205825473894599999999999")
            a:IncBy(ffi.new("signed long int", -1))
            assert(a:__tostring() == "761205825473894599999999998")
        end

        do -- ExactInteger.DecByMPZ
            local a = lualgebra.ExactInteger("9263591128439081")
            local b = lualgebra.ExactInteger("7612058254738945")
            a:DecBy(b)
            assert(a:__tostring() == "1651532873700136")
        end
        do -- ExactInteger.DecBy double
            local a = lualgebra.ExactInteger("761205825473894599999999999")
            a:DecBy(1)
            assert(a:__tostring() == "761205825473894599999999998")
        end
        do -- ExactInteger.DecByUI
            local a = lualgebra.ExactInteger("761205825473894599999999999")
            a:DecBy(ffi.new("unsigned long int", 1))
            assert(a:__tostring() == "761205825473894599999999998")
        end
        do -- ExactInteger.DecBySI
            local a = lualgebra.ExactInteger("761205825473894599999999999")
            a:DecBy(ffi.new("signed long int", -1))
            assert(a:__tostring() == "761205825473894600000000000")
        end

        do -- ExactInteger.AddMPZ
            local a = lualgebra.ExactInteger("9263591128439081")
            local b = lualgebra.ExactInteger("7612058254738945")
            local r = a:Add(b)
            assert(r:__tostring() == "16875649383178026")
        end
        do -- ExactInteger.Add double
            local a = lualgebra.ExactInteger("761205825473894599999999999")
            local r = a:Add(1)
            assert(r:__tostring() == "761205825473894600000000000")
        end
        do -- ExactInteger.AddUI
            local a = lualgebra.ExactInteger("761205825473894599999999999")
            local r = a:Add(ffi.new("unsigned long int", 1))
            assert(r:__tostring() == "761205825473894600000000000")
        end
        do -- ExactInteger.AddSI
            local a = lualgebra.ExactInteger("761205825473894599999999999")
            local r = a:Add(ffi.new("signed long int", -1))
            assert(r:__tostring() == "761205825473894599999999998")
        end
        do -- ExactInteger.__add
            local a = lualgebra.ExactInteger("761205825473894599999999999")
            local r = ffi.new("signed long int", -1)+a
            assert(r:__tostring() == "761205825473894599999999998")
        end

        do -- ExactInteger.SubMPZ
            local a = lualgebra.ExactInteger("9263591128439081")
            local b = lualgebra.ExactInteger("7612058254738945")
            local r = a:Sub(b)
            assert(r:__tostring() == "1651532873700136")
        end
        do -- ExactInteger.Sub double
            local a = lualgebra.ExactInteger("761205825473894599999999999")
            local r = a:Sub(1)
            assert(r:__tostring() == "761205825473894599999999998")
        end
        do -- ExactInteger.SubUI
            local a = lualgebra.ExactInteger("761205825473894599999999999")
            local r = a:Sub(ffi.new("unsigned long int", 1))
            assert(r:__tostring() == "761205825473894599999999998")
        end
        do -- ExactInteger.SubSI
            local a = lualgebra.ExactInteger("761205825473894599999999999")
            local r = a:Sub(ffi.new("signed long int", -1))
            assert(r:__tostring() == "761205825473894600000000000")
        end
        do -- ExactInteger.__sub
            local a = lualgebra.ExactInteger("761205825473894599999999999")
            local r = a-ffi.new("signed long int", -1)
            assert(r:__tostring() == "761205825473894600000000000")
        end

        do -- ExactInteger.MulMPZ
            local a = lualgebra.ExactInteger("9263591128439081")
            local b = lualgebra.ExactInteger("7612058254738945")
            local r = a:Mul(b)
            assert(r:__tostring() == "70514995317761165008628990709545")
        end
        do -- ExactInteger.Mul double
            local a = lualgebra.ExactInteger("761205825473894599999999999")
            local r = a:Mul(3)
            assert(r:__tostring() == "2283617476421683799999999997")
        end
        do -- ExactInteger.MulUI
            local a = lualgebra.ExactInteger("761205825473894599999999999")
            local r = a:Mul(ffi.new("unsigned long int", 3))
            assert(r:__tostring() == "2283617476421683799999999997")
        end
        do -- ExactInteger.MulSI
            local a = lualgebra.ExactInteger("761205825473894599999999999")
            local r = a:Mul(ffi.new("signed long int", -3))
            assert(r:__tostring() == "-2283617476421683799999999997")
        end
        do -- ExactInteger.__mul
            local a = lualgebra.ExactInteger("761205825473894599999999999")
            local r = ffi.new("signed long int", -3)*a
            assert(r:__tostring() == "-2283617476421683799999999997")
        end
    end
    do -- ExactReal
        
    end
end

-- for post-test interactive debugging
_G.la = lualgebra
_G.ffi = ffi
_G.gmp = la.gmp
lualgebra.InstallShortcuts(_G)

_G.ia = MPZ(4)
_G.ib = MPZ(5)
_G.ic = MPZ(6)
_G.id = MPZ(7)
_G.ie = MPZ(8)

function realtest()
    local x = MPR()
    local y = MPR()
    
end

for i = 1, bn or 0 do
    
    function biginttest(m)
        
        local total = MPZ(1)
        
        for i = 1, m or 10^6 do
            local val = MPZ(math.random(1, 3))
            total = total*val
        end
        
        --print(total)
        assert(total._mp_size ~= 0)
    end
    
    biginttest(bm)
    
    function biginttestbetter(m)
        
        local total = MPZ(1)
        
        local val = MPZ()
        
        for i = 1, m or 10^6 do
            val:SetSIRaw(math.random(1, 3))
            total = total*val
        end
        
        --print(total)
        assert(total._mp_size ~= 0)
    end
    
    biginttestbetter(bm)
    
end
