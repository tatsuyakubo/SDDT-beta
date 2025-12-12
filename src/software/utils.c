#include <stdint.h>

#include "api.h"

// tCK = 1.5ns (666MHz)
#define nRP    9 // tRP  = 14.16ns, nRP  = 14.16 / 1.5 = 9.44
#define nRCD   9 // tRCD = 14.16ns, nRCD = 14.16 / 1.5 = 9.44
#define nCCD_L 3 // tCCD_L = 6 * 0.833 = 5.0ns, nCCD_L = 5.0 / 1.5 = 3.33
// tREFI = 7.8us
#define nRFC 233 // tRFC = 421 * 0.833 = 350.693ns, nRFC = 350.693 / 1.5 = 233.795

uint32_t write_row(uint32_t *data_buf, uint8_t bank_addr, uint32_t row_addr, uint8_t rank_addr) {
    uint32_t nck = 0;
    nck += pre(bank_addr, rank_addr, false, nRP, false);
    nck += act(bank_addr, row_addr, rank_addr, nRCD, false);
    for (int i = 0; i < 128; i++) {
        nck += wr(data_buf+i*16, bank_addr, i*8, nCCD_L, false);
    }
    return nck;
}

uint32_t read_row(uint32_t *data_buf, uint8_t bank_addr, uint32_t row_addr, uint8_t rank_addr) {
    uint32_t nck = 0;
    nck += pre(bank_addr, rank_addr, false, nRP, false);
    nck += act(bank_addr, row_addr, rank_addr, nRCD, false);
    for (int i = 0; i < 128; i++) {
        nck += rd(data_buf+i*16, bank_addr, i*8, nCCD_L, false);
    }
    return nck;
}

uint32_t all_bank_refresh(uint8_t rank_addr) {
    uint32_t nck = 0;
    nck += pre(0, rank_addr, true, nRP, false); // precharge all banks
    nck += rf(nRFC, false); // refresh
    return nck;
}

void gen_data_pattern(uint32_t *data_buf, uint8_t bank_addr, uint32_t row_addr, uint8_t rank_addr, uint32_t seed) {
    for (int i = 0; i < 128; i++) {
        for (int j = 0; j < 16; j++) {
            // Hash function: FNV-1a inspired hash
            uint32_t hash = 2166136261u; // FNV offset basis
            hash ^= rank_addr;
            hash *= 16777619u; // FNV prime
            hash ^= bank_addr;
            hash *= 16777619u; // FNV prime
            hash ^= row_addr;
            hash *= 16777619u; // FNV prime
            hash ^= seed;
            hash *= 16777619u;
            hash ^= (uint32_t)i;
            hash *= 16777619u;
            hash ^= (uint32_t)j;
            hash *= 16777619u;
            data_buf[i*16+j] = hash;
        }
    }
}
