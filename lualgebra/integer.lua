
local lualgebra = {}

local concept = require"concept"
local ffi = require"ffi"

local gmp

lualgebra.ExactInteger = concept{
    ffiTypeName = "mpz_t",
}

function lualgebra.ExactInteger.__declare(class)
    --print("lualgebra.ExactInteger.__declare")
    gmp = ffi.load("libgmp.so.10") -- TODO: Find a way to make this independent of platform and version
    lualgebra.gmp = gmp
    
    ffi.cdef[[
        typedef unsigned long int mp_bitcnt_t;
        typedef struct {
            int _mp_alloc;
            int _mp_size;
            unsigned int *_mp_d;
        } __mpz_struct;
        typedef __mpz_struct *mpz_ptr;
        // typedef __mpz_struct mpz_t[1];
        typedef __mpz_struct mpz_t;
        typedef const __mpz_struct *mpz_srcptr;
        
        void              mpz_init        (mpz_ptr                                             ) asm("__gmpz_init"        );
        void              mpz_init_set    (mpz_ptr, mpz_srcptr                                 ) asm("__gmpz_init_set"    );
        void              mpz_init_set_d  (mpz_ptr, double                                     ) asm("__gmpz_init_set_d"  );
        void              mpz_init_set_si (mpz_ptr, signed long int                            ) asm("__gmpz_init_set_si" );
        int               mpz_init_set_str(mpz_ptr, const char *, int                          ) asm("__gmpz_init_set_str");
        void              mpz_init_set_ui (mpz_ptr, unsigned long int                          ) asm("__gmpz_init_set_ui" );
        
        void              mpz_clear       (mpz_ptr                                             ) asm("__gmpz_clear"       );
        
        void              mpz_set         (mpz_ptr, mpz_srcptr                                 ) asm("__gmpz_set"         );
        void              mpz_set_d       (mpz_ptr, double                                     ) asm("__gmpz_set_d"       );
        void              mpz_set_si      (mpz_ptr, signed long int                            ) asm("__gmpz_set_si"      );
        int               mpz_set_str     (mpz_ptr, const char *, int                          ) asm("__gmpz_set_str"     );
        void              mpz_set_ui      (mpz_ptr, unsigned long int                          ) asm("__gmpz_set_ui"      );
        
        void              mpz_neg         (mpz_ptr, mpz_srcptr                                 ) asm("__gmpz_neg"         );
        
        void              mpz_add         (mpz_ptr, mpz_srcptr, mpz_srcptr                     ) asm("__gmpz_add"         );
        void              mpz_add_ui      (mpz_ptr, mpz_srcptr, unsigned long int              ) asm("__gmpz_add_ui"      );
        
        void              mpz_sub         (mpz_ptr, mpz_srcptr, mpz_srcptr                     ) asm("__gmpz_sub"         );
        void              mpz_sub_ui      (mpz_ptr, mpz_srcptr, unsigned long int              ) asm("__gmpz_sub_ui"      );
        
        void              mpz_mul         (mpz_ptr, mpz_srcptr, mpz_srcptr                     ) asm("__gmpz_mul"         );
        void              mpz_mul_si      (mpz_ptr, mpz_srcptr, unsigned long int              ) asm("__gmpz_mul_si"      );
        void              mpz_mul_ui      (mpz_ptr, mpz_srcptr, unsigned long int              ) asm("__gmpz_mul_ui"      );
        
        void              mpz_cdiv_q      (mpz_t q, const mpz_t n, const mpz_t d               ) asm("__gmpz_cdiv_q"      );
        void              mpz_cdiv_r      (mpz_t r, const mpz_t n, const mpz_t d               ) asm("__gmpz_cdiv_r"      );
        void              mpz_cdiv_qr     (mpz_t q, mpz_t r, const mpz_t n, const mpz_t d      ) asm("__gmpz_cdiv_qr"     );
        unsigned long int mpz_cdiv_q_ui   (mpz_t q, const mpz_t n, unsigned long int d         ) asm("__gmpz_cdiv_q_ui"   );
        unsigned long int mpz_cdiv_r_ui   (mpz_t r, const mpz_t n, unsigned long int d         ) asm("__gmpz_cdiv_r_ui"   );
        unsigned long int mpz_cdiv_qr_ui  (mpz_t q, mpz_t r, const mpz_t n, unsigned long int d) asm("__gmpz_cdiv_qr_ui"  );
        unsigned long int mpz_cdiv_ui     (const mpz_t n, unsigned long int d                  ) asm("__gmpz_cdiv_ui"     );
        void              mpz_cdiv_q_2exp (mpz_t q, const mpz_t n, mp_bitcnt_t b               ) asm("__gmpz_cdiv_q_2exp" );
        void              mpz_cdiv_r_2exp (mpz_t r, const mpz_t n, mp_bitcnt_t b               ) asm("__gmpz_cdiv_r_2exp" );
        void              mpz_fdiv_q      (mpz_t q, const mpz_t n, const mpz_t d               ) asm("__gmpz_fdiv_q"      );
        void              mpz_fdiv_r      (mpz_t r, const mpz_t n, const mpz_t d               ) asm("__gmpz_fdiv_r"      );
        void              mpz_fdiv_qr     (mpz_t q, mpz_t r, const mpz_t n, const mpz_t d      ) asm("__gmpz_fdiv_qr"     );
        unsigned long int mpz_fdiv_q_ui   (mpz_t q, const mpz_t n, unsigned long int d         ) asm("__gmpz_fdiv_q_ui"   );
        unsigned long int mpz_fdiv_r_ui   (mpz_t r, const mpz_t n, unsigned long int d         ) asm("__gmpz_fdiv_r_ui"   );
        unsigned long int mpz_fdiv_qr_ui  (mpz_t q, mpz_t r, const mpz_t n, unsigned long int d) asm("__gmpz_fdiv_qr_ui"  );
        unsigned long int mpz_fdiv_ui     (const mpz_t n, unsigned long int d                  ) asm("__gmpz_fdiv_ui"     );
        void              mpz_fdiv_q_2exp (mpz_t q, const mpz_t n, mp_bitcnt_t b               ) asm("__gmpz_fdiv_q_2exp" );
        void              mpz_fdiv_r_2exp (mpz_t r, const mpz_t n, mp_bitcnt_t b               ) asm("__gmpz_fdiv_r_2exp" );
        void              mpz_tdiv_q      (mpz_t q, const mpz_t n, const mpz_t d               ) asm("__gmpz_tdiv_q"      );
        void              mpz_tdiv_r      (mpz_t r, const mpz_t n, const mpz_t d               ) asm("__gmpz_tdiv_r"      );
        void              mpz_tdiv_qr     (mpz_t q, mpz_t r, const mpz_t n, const mpz_t d      ) asm("__gmpz_tdiv_qr"     );
        unsigned long int mpz_tdiv_q_ui   (mpz_t q, const mpz_t n, unsigned long int d         ) asm("__gmpz_tdiv_q_ui"   );
        unsigned long int mpz_tdiv_r_ui   (mpz_t r, const mpz_t n, unsigned long int d         ) asm("__gmpz_tdiv_r_ui"   );
        unsigned long int mpz_tdiv_qr_ui  (mpz_t q, mpz_t r, const mpz_t n, unsigned long int d) asm("__gmpz_tdiv_qr_ui"  );
        unsigned long int mpz_tdiv_ui     (const mpz_t n, unsigned long int d                  ) asm("__gmpz_tdiv_ui"     );
        void              mpz_tdiv_q_2exp (mpz_t q, const mpz_t n, mp_bitcnt_t b               ) asm("__gmpz_tdiv_q_2exp" );
        void              mpz_tdiv_r_2exp (mpz_t r, const mpz_t n, mp_bitcnt_t b               ) asm("__gmpz_tdiv_r_2exp" );
        
        void              mpz_mod         (mpz_ptr, mpz_srcptr, mpz_srcptr                     ) asm("__gmpz_mod"         );
        
        char *            mpz_get_str     (char *, int, mpz_srcptr                             ) asm("__gmpz_get_str"     );
    ]]
    
    class.ffiType = ffi.metatype(class.ffiTypeName, class)
    return function(class, ...) return class.ffiType(...) end
end

function lualgebra.ExactInteger.__new(ct, val, base)
    --print("lualgebra.ExactInteger.__new")
    local obj = ffi.new(ct)
    if val == nil then
        gmp.mpz_init(obj)
        -- print("init")
    elseif ffi.istype("mpz_t", val) then
        gmp.mpz_init_set(obj, val)
        -- print("init_set")
    elseif ffi.istype("signed long int", val) then
        gmp.mpz_init_set_si(obj, val)
        -- print("init_set_si")
    elseif ffi.istype("unsigned long int", val) then
        gmp.mpz_init_set_ui(obj, val)
        -- print("init_set_ui")
    elseif ffi.istype("mpr_t", val) or ffi.istype("mpc_t", val) then
        error("NYI")
    elseif type(val) == "string" then
        if (-1 == gmp.mpz_init_set_str(obj, val, base or 0)) then
            error(string.format("invalid number string %q (base %q)", tostring(val), tostring(base or "auto")))
        end
        -- print("init_set_str")
    else
        local v = tonumber(val)
        if v and v%1 == 0 then
            gmp.mpz_init_set_si(obj, val)
            -- print("init_set_si")
        elseif v then
            gmp.mpz_init_set_d(obj, val)
            -- print("init_set_d")
        else
            error(string.format("invalid number value %q", tostring(val)))
        end
    end
    return obj
end
function lualgebra.ExactInteger:__gc()
    --print("del!", self)
    gmp.mpz_clear(self)
end

function lualgebra.ExactInteger:__tostring()
    return ffi.string(gmp.mpz_get_str(nil, 10, self))
end

do -- Set
    function lualgebra.ExactInteger:SetMPZRaw(other)
        gmp.mpz_add(self, self, other)
        return self
    end
    function lualgebra.ExactInteger:SetMPZ(other)
        assert(ffi.istype("mpz_t", self) and ffi.istype("mpz_t", other), "SetMPZ expects mpz_t and mpz_t")
        return self:SetMPZRaw(other)
    end
    
    function lualgebra.ExactInteger:SetSIRaw(other)
        gmp.mpz_set_si(self, other)
        return self
    end
    function lualgebra.ExactInteger:SetSI(other)
        assert(ffi.istype("mpz_t", self), "SetSI expects mpz_t")
        return self:SetSIRaw(ffi.cast("signed long int", other))
    end
    
    function lualgebra.ExactInteger:SetUIRaw(other)
        gmp.mpz_set_ui(self, other)
        return self
    end
    function lualgebra.ExactInteger:SetUI(other)
        assert(ffi.istype("mpz_t", self), "SetUI expects mpz_t")
        return self:SetUIRaw(ffi.cast("unsigned long int", other))
    end
    
    function lualgebra.ExactInteger:SetStrRaw(other, base)
        if (-1 == gmp.mpz_set_str(self, other, base or 0)) then
            error(string.format("invalid number string %q (base %q)", tostring(val), tostring(base or "auto")))
        end
        return self
    end
    function lualgebra.ExactInteger:SetStr(other, base)
        assert(ffi.istype("mpz_t", self), "SetStr expects mpz_t")
        return self:SetStrRaw(other, base)
    end
    
    function lualgebra.ExactInteger:SetDoubleRaw(other)
        gmp.mpz_set_d(self, other)
        return self
    end
    function lualgebra.ExactInteger:SetDouble(other)
        assert(ffi.istype("mpz_t", self), "SetDouble expects mpz_t")
        return self:SetDoubleRaw(other)
    end
    
    function lualgebra.ExactInteger:SetRaw(other, base)
        if ffi.istype("mpz_t", other) then
            self:SetMPZRaw(other)
        elseif ffi.istype("signed long int", other) then
            self:SetSIRaw(other)
        elseif ffi.istype("unsigned long int", other) then
            self:SetUIRaw(other)
        elseif ffi.istype("mpr_t", val) or ffi.istype("mpc_t", val) then
            error("NYI")
        elseif type(other) == "string" then
            self:SetStrRaw(other, base)
        else
            local n = tonumber(other)
            if n and other%1 == 0 then
                self:SetSIRaw(other)
            elseif n then
                self:SetDoubleRaw(other)
            else
                local v = ffi.typeof(self)(other, base)
                self:SetMPZRaw(v)
            end
        end
        return self
    end
    function lualgebra.ExactInteger:Set(other, base)
        assert(ffi.istype("mpz_t", self), "SetMPZ expects mpz_t")
        return self:SetRaw(other, base)
    end
end

do -- Neg
    function lualgebra.ExactInteger:NegRaw(other)
        local result = ffi.typeof(self)()
        gmp.mpz_neg(result, self)
        return result
    end
    function lualgebra.ExactInteger:Neg()
        assert(ffi.istype("mpz_t", self), "Neg expects mpz_t")
        return self:NegRaw(other)
    end
    function lualgebra.ExactInteger:SetNegRaw(other)
        gmp.mpz_neg(self, self)
        return self
    end
    function lualgebra.ExactInteger:SetNeg()
        assert(ffi.istype("mpz_t", self), "SetNeg expects mpz_t")
        return self:SetNegRaw(other)
    end
    
    function lualgebra.ExactInteger:__unm(other)
        assert(ffi.istype("mpz_t", self), "__unm expects mpz_t")
        return self:NegRaw()
    end
end

do -- IncBy
    function lualgebra.ExactInteger:IncByMPZRaw(other)
        gmp.mpz_add(self, self, other)
        return self
    end
    function lualgebra.ExactInteger:IncByMPZ(other)
        assert(ffi.istype("mpz_t", self) and ffi.istype("mpz_t", other), "IncByMPZ expects mpz_t and mpz_t")
        return self:IncByMPZRaw(other)
    end
    
    function lualgebra.ExactInteger:IncBySIRaw(other)
        if other > 0 then
            gmp.mpz_add_ui(self, self,  other)
        else
            gmp.mpz_sub_ui(self, self, -other)
        end
        return self
    end
    function lualgebra.ExactInteger:IncBySI(other)
        assert(ffi.istype("mpz_t", self), "IncBySI expects mpz_t")
        return self:IncBySIRaw(ffi.cast("signed long int", other))
    end
    
    function lualgebra.ExactInteger:IncByUIRaw(other)
        gmp.mpz_add_ui(self, self, other)
        return self
    end
    function lualgebra.ExactInteger:IncByUI(other)
        assert(ffi.istype("mpz_t", self), "IncByUI expects mpz_t")
        return self:IncByUIRaw(ffi.cast("unsigned long int", other))
    end
    
    function lualgebra.ExactInteger:IncByRaw(other, base)
        if ffi.istype("mpz_t", other) then
            self:IncByMPZRaw(other)
        elseif ffi.istype("signed long int", other) then
            self:IncBySIRaw(other)
        elseif ffi.istype("unsigned long int", other) then
            self:IncByUIRaw(other)
        elseif ffi.istype("mpr_t", val) or ffi.istype("mpc_t", val) then
            error("NYI")
        else
            local n = tonumber(other)
            if n and other%1 == 0 then
                self:IncBySIRaw(other)
            else
                local v = ffi.typeof(self)(other, base)
                self:IncByMPZRaw(v)
            end
        end
        return self
    end
    function lualgebra.ExactInteger:IncBy(other, base)
        assert(ffi.istype("mpz_t", self), "IncByMPZ expects mpz_t")
        return self:IncByRaw(other, base)
    end
end
do -- DecBy
    function lualgebra.ExactInteger:DecByMPZRaw(other)
        gmp.mpz_sub(self, self, other)
        return self
    end
    function lualgebra.ExactInteger:DecByMPZ(other)
        assert(ffi.istype("mpz_t", self) and ffi.istype("mpz_t", other), "DecByMPZ expects mpz_t and mpz_t")
        return self:DecByMPZRaw(other)
    end
    
    function lualgebra.ExactInteger:DecBySIRaw(other)
        if other > 0 then
            gmp.mpz_sub_ui(self, self,  other)
        else
            gmp.mpz_add_ui(self, self, -other)
        end
        return self
    end
    function lualgebra.ExactInteger:DecBySI(other)
        assert(ffi.istype("mpz_t", self), "DecBySI expects mpz_t")
        return self:DecBySIRaw(ffi.cast("signed long int", other))
    end
    
    function lualgebra.ExactInteger:DecByUIRaw(other)
        gmp.mpz_sub_ui(self, self, other)
        return self
    end
    function lualgebra.ExactInteger:DecByUI(other)
        assert(ffi.istype("mpz_t", self), "DecByUI expects mpz_t")
        return self:DecByUIRaw(ffi.cast("unsigned long int", other))
    end
    
    function lualgebra.ExactInteger:DecByRaw(other, base)
        if ffi.istype("mpz_t", other) then
            self:DecByMPZRaw(other)
        elseif ffi.istype("signed long int", other) then
            self:DecBySIRaw(other)
        elseif ffi.istype("unsigned long int", other) then
            self:DecByUIRaw(other)
        elseif ffi.istype("mpr_t", val) or ffi.istype("mpc_t", val) then
            error("NYI")
        else
            local n = tonumber(other)
            if n and other%1 == 0 then
                self:DecBySIRaw(other)
            else
                local v = ffi.typeof(self)(other, base)
                self:DecByMPZRaw(v)
            end
        end
        return self
    end
    function lualgebra.ExactInteger:DecBy(other, base)
        assert(ffi.istype("mpz_t", self), "DecByMPZ expects mpz_t")
        return self:DecByRaw(other, base)
    end
end

do -- Add
    function lualgebra.ExactInteger:AddMPZRaw(other)
        local result = ffi.typeof(self)()
        gmp.mpz_add(result, self, other)
        return result
    end
    function lualgebra.ExactInteger:AddMPZ(other)
        assert(ffi.istype("mpz_t", self) and ffi.istype("mpz_t", other), "AddMPZ expects mpz_t and mpz_t")
        return self:AddMPZRaw(other)
    end
    
    function lualgebra.ExactInteger:AddSIRaw(other)
        local result = ffi.typeof(self)()
        if other > 0 then
            gmp.mpz_add_ui(result, self,  other)
        else
            gmp.mpz_sub_ui(result, self, -other)
        end
        return result
    end
    function lualgebra.ExactInteger:AddSI(other)
        assert(ffi.istype("mpz_t", self), "AddSI expects mpz_t")
        return self:AddSIRaw(ffi.cast("signed long int", other))
    end
    
    function lualgebra.ExactInteger:AddUIRaw(other)
        local result = ffi.typeof(self)()
        gmp.mpz_add_ui(result, self, other)
        return result
    end
    function lualgebra.ExactInteger:AddUI(other)
        assert(ffi.istype("mpz_t", self), "AddUI expects mpz_t")
        return self:AddUIRaw(ffi.cast("unsigned long int", other))
    end
    
    function lualgebra.ExactInteger:AddRaw(other, base)
        local result
        if ffi.istype("mpz_t", other) then
            result = self:AddMPZRaw(other)
        elseif ffi.istype("signed long int", other) then
            result = self:AddSIRaw(other)
        elseif ffi.istype("unsigned long int", other) then
            result = self:AddUIRaw(other)
        elseif ffi.istype("mpr_t", val) or ffi.istype("mpc_t", val) then
            error("NYI")
        else
            local n = tonumber(other)
            if n and other%1 == 0 then
                result = self:AddSIRaw(other)
            else
                local v = ffi.typeof(self)(other, base)
                result = self:AddMPZRaw(v)
            end
        end
        return result
    end
    function lualgebra.ExactInteger:Add(other, base)
        assert(ffi.istype("mpz_t", self), "AddMPZ expects mpz_t")
        return self:AddRaw(other, base)
    end
    
    function lualgebra.ExactInteger:__add(other)
        if ffi.istype("mpz_t", self) then
            return self:AddRaw(other)
        elseif ffi.istype("mpz_t", other) then
            return other:AddRaw(self)
        else error("__add expects mpz_t") end
    end
end
do -- Sub
    function lualgebra.ExactInteger:SubMPZRaw(other)
        local result = ffi.typeof(self)()
        gmp.mpz_sub(result, self, other)
        return result
    end
    function lualgebra.ExactInteger:SubMPZ(other)
        assert(ffi.istype("mpz_t", self) and ffi.istype("mpz_t", other), "SubMPZ expects mpz_t and mpz_t")
        return self:SubMPZRaw(other)
    end
    
    function lualgebra.ExactInteger:SubSIRaw(other)
        local result = ffi.typeof(self)()
        if other > 0 then
            gmp.mpz_sub_ui(result, self,  other)
        else
            gmp.mpz_add_ui(result, self, -other)
        end
        return result
    end
    function lualgebra.ExactInteger:SubSI(other)
        assert(ffi.istype("mpz_t", self), "SubSI expects mpz_t")
        return self:SubSIRaw(ffi.cast("signed long int", other))
    end
    
    function lualgebra.ExactInteger:SubUIRaw(other)
        local result = ffi.typeof(self)()
        gmp.mpz_sub_ui(result, self, other)
        return result
    end
    function lualgebra.ExactInteger:SubUI(other)
        assert(ffi.istype("mpz_t", self), "SubUI expects mpz_t")
        return self:SubUIRaw(ffi.cast("unsigned long int", other))
    end
    
    function lualgebra.ExactInteger:SubRaw(other, base)
        local result
        if ffi.istype("mpz_t", other) then
            result = self:SubMPZRaw(other)
        elseif ffi.istype("signed long int", other) then
            result = self:SubSIRaw(other)
        elseif ffi.istype("unsigned long int", other) then
            result = self:SubUIRaw(other)
        elseif ffi.istype("mpr_t", val) or ffi.istype("mpc_t", val) then
            error("NYI")
        else
            local n = tonumber(other)
            if n and other%1 == 0 then
                result = self:SubSIRaw(other)
            else
                local v = ffi.typeof(self)(other, base)
                result = self:SubMPZRaw(v)
            end
        end
        return result
    end
    function lualgebra.ExactInteger:Sub(other, base)
        assert(ffi.istype("mpz_t", self), "SubMPZ expects mpz_t")
        return self:SubRaw(other, base)
    end
    
    function lualgebra.ExactInteger:__sub(other)
        if ffi.istype("mpz_t", self) then
            return self:SubRaw(other)
        elseif ffi.istype("mpz_t", other) then
            return other:SubRaw(self)
        else error("__sub expects mpz_t") end
    end
end

do -- MulBy
    function lualgebra.ExactInteger:MulByMPZRaw(other)
        gmp.mpz_mul(self, self, other)
        return self
    end
    function lualgebra.ExactInteger:MulByMPZ(other)
        assert(ffi.istype("mpz_t", self) and ffi.istype("mpz_t", other), "MulByMPZ expects mpz_t and mpz_t")
        return self:MulByMPZRaw(other)
    end
    
    function lualgebra.ExactInteger:MulBySIRaw(other)
        gmp.mpz_mul_si(self, self, other)
        return self
    end
    function lualgebra.ExactInteger:MulBySI(other)
        assert(ffi.istype("mpz_t", self), "MulBySI expects mpz_t")
        return self:MulBySIRaw(ffi.cast("signed long int", other))
    end
    
    function lualgebra.ExactInteger:MulByUIRaw(other)
        gmp.mpz_mul_ui(self, self, other)
        return self
    end
    function lualgebra.ExactInteger:MulByUI(other)
        assert(ffi.istype("mpz_t", self), "MulByUI expects mpz_t")
        return self:MulByUIRaw(ffi.cast("unsigned long int", other))
    end
    
    function lualgebra.ExactInteger:MulByRaw(other, base)
        if ffi.istype("mpz_t", other) then
            self:MulByMPZRaw(other)
        elseif ffi.istype("signed long int", other) then
            self:MulBySIRaw(other)
        elseif ffi.istype("unsigned long int", other) then
            self:MulByUIRaw(other)
        elseif ffi.istype("mpr_t", val) or ffi.istype("mpc_t", val) then
            error("NYI")
        else
            local n = tonumber(other)
            if n and other%1 == 0 then
                self:MulBySIRaw(other)
            else
                local v = ffi.typeof(self)(other, base)
                self:MulByMPZRaw(v)
            end
        end
        return self
    end
    function lualgebra.ExactInteger:MulBy(other, base)
        assert(ffi.istype("mpz_t", self), "MulByMPZ expects mpz_t")
        return self:MulByRaw(other, base)
    end
end

do -- Mul
    function lualgebra.ExactInteger:MulMPZRaw(other)
        local result = ffi.typeof(self)()
        gmp.mpz_mul(result, self, other)
        return result
    end
    function lualgebra.ExactInteger:MulMPZ(other)
        assert(ffi.istype("mpz_t", self) and ffi.istype("mpz_t", other), "MulMPZ expects mpz_t and mpz_t")
        return self:MulMPZRaw(other)
    end
    
    function lualgebra.ExactInteger:MulSIRaw(other)
        local result = ffi.typeof(self)()
        gmp.mpz_mul_si(result, self, other)
        return result
    end
    function lualgebra.ExactInteger:MulSI(other)
        assert(ffi.istype("mpz_t", self), "MulSI expects mpz_t")
        return self:MulSIRaw(ffi.cast("signed long int", other))
    end
    
    function lualgebra.ExactInteger:MulUIRaw(other)
        local result = ffi.typeof(self)()
        gmp.mpz_mul_ui(result, self, other)
        return result
    end
    function lualgebra.ExactInteger:MulUI(other)
        assert(ffi.istype("mpz_t", self), "MulSI expects mpz_t")
        return self:MulUIRaw(ffi.cast("unsigned long int", other))
    end
    
    function lualgebra.ExactInteger:MulRaw(other, base)
        local result
        if ffi.istype("mpz_t", other) then
            result = self:MulMPZRaw(other)
        elseif ffi.istype("signed long int", other) then
            result = self:MulSIRaw(other)
        elseif ffi.istype("unsigned long int", other) then
            result = self:MulUIRaw(other)
        elseif ffi.istype("mpr_t", val) or ffi.istype("mpc_t", val) then
            error("NYI")
        else
            local n = tonumber(other)
            if n and other%1 == 0 then
                result = self:MulSIRaw(other)
            else
                local v = ffi.typeof(self)(other, base)
                result = self:MulMPZRaw(v)
            end
        end
        return result
    end
    function lualgebra.ExactInteger:Mul(other, base)
        assert(ffi.istype("mpz_t", self), "MulMPZ expects mpz_t")
        return self:MulRaw(other, base)
    end
    
    function lualgebra.ExactInteger:__mul(other)
        if ffi.istype("mpz_t", self) then
            return self:MulRaw(other)
        elseif ffi.istype("mpz_t", other) then
            return other:MulRaw(self)
        else error("__mul expects mpz_t") end
    end
end

return lualgebra
