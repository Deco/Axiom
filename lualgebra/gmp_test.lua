
ffi = require"ffi"
gmp = ffi.load("libgmp.so.10")

ffi.cdef[[
    typedef struct {
        int _mp_alloc;
        int _mp_size;
        unsigned int *_mp_d;
    } __mpz_struct;
    typedef __mpz_struct *mpz_ptr;
    // typedef __mpz_struct mpz_t[1];
    typedef __mpz_struct mpz_t;
    typedef const __mpz_struct *mpz_srcptr;
    
    void mpz_init        (mpz_ptr                                       ) asm("__gmpz_init"         );
    void mpz_init_set_ui (mpz_ptr, unsigned long int                    ) asm("__gmpz_init_set_ui"  );
    
    void mpz_set_ui      (mpz_ptr, unsigned long int                    ) asm("__gmpz_set_ui"       );
    
    void mpz_add         (mpz_ptr, mpz_srcptr, mpz_srcptr               ) asm("__gmpz_add"          );
    void mpz_sub         (mpz_ptr, mpz_srcptr, mpz_srcptr               ) asm("__gmpz_sub"          );
    void mpz_mul         (mpz_ptr, mpz_srcptr, mpz_srcptr               ) asm("__gmpz_mul"          );
    void mpz_mod         (mpz_ptr, mpz_srcptr, mpz_srcptr               ) asm("__gmpz_mod"          );
    void mpz_fdiv_q      (mpz_ptr, mpz_srcptr, mpz_srcptr               ) asm("__gmpz_fdiv_q"       );
    void mpz_fdiv_r      (mpz_ptr, mpz_srcptr, mpz_srcptr               ) asm("__gmpz_fdiv_r"       );
    
    char *mpz_get_str    (char *, int, mpz_srcptr                       ) asm("__gmpz_get_str"      );
]]

ra = ffi.new("mpz_t")
gmp.mpz_init_set_ui(ra, 27)

print(string.format("ra = %s", ffi.string(gmp.mpz_get_str(nil, 0, ra))))

rb = ffi.new("mpz_t")
gmp.mpz_init(rb)
gmp.mpz_set_ui(rb, 12)

print(string.format("rb = %s", ffi.string(gmp.mpz_get_str(nil, 0, rb))))

rc = ffi.new("mpz_t")
gmp.mpz_init(rc)

print("rc = ?!?")

gmp.mpz_fdiv_q(rc, ra, rb)

print("op")

print(string.format("rc = %s", ffi.string(gmp.mpz_get_str(nil, 0, rc))))

print(string.format("%s op %s = %s",
    ffi.string(gmp.mpz_get_str(nil, 0, ra)),
    ffi.string(gmp.mpz_get_str(nil, 0, rb)),
    ffi.string(gmp.mpz_get_str(nil, 0, rc))
))
