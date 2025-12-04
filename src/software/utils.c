#include <stdint.h>

#include "api.h"

// tCK = 1.5ns (666MHz)
#define nRP    9 // tRP  = 14.16ns, nRP  = 14.16 / 1.5 = 9.44
#define nRCD   9 // tRCD = 14.16ns, nRCD = 14.16 / 1.5 = 9.44
#define nCCD_L 3 // tCCD_L = 6 * 0.833 = 5.0ns, nCCD_L = 5.0 / 1.5 = 3.33

uint32_t write_row(uint8_t *data_buf, uint8_t bank_addr, uint32_t row_addr, uint8_t rank_addr) {
    uint32_t nck = 0;
    nck += pre(bank_addr, rank_addr, false, nRP, false);
    nck += act(bank_addr, row_addr, rank_addr, nRCD, false);
    for (int i = 0; i < 128; i++) {
        data_buf[0] += 1;
        nck += wr(data_buf, bank_addr, i*8, nCCD_L, false);
    }
    return nck;
}

uint32_t read_row(uint8_t *data_buf, uint8_t bank_addr, uint32_t row_addr, uint8_t rank_addr) {
    uint32_t nck = 0;
    nck += pre(bank_addr, rank_addr, false, nRP, false);
    nck += act(bank_addr, row_addr, rank_addr, nRCD, false);
    for (int i = 0; i < 128; i++) {
        nck += rd(data_buf+i*64, bank_addr, i*8, nCCD_L, false);
    }
    return nck;
}
