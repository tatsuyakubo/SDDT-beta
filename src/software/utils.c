#include <stdint.h>

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
