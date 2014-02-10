
#include <stdio.h>
#include "gmp.h"

int main(int argc, char **argv) {
    
    mpz_t ra;
    mpz_init_set_ui(ra, 27);
    
    mpz_t rb;
    mpz_init(rb);
    mpz_set_ui(rb, 12);
    
    mpz_t rc;
    //mpz_init(rc);
    
    //mpz_fdiv_q(rc, ra, rb);
    
    printf("%s op %s = %s\n", mpz_get_str(NULL, 0, ra), mpz_get_str(NULL, 0, rb), mpz_get_str(NULL, 0, rc));
    
    return 0;
}
