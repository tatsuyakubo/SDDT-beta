#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "api.h"
#include "utils.h"

int main(int argc, char *argv[]) {
    uint32_t write_data_buf[16*128];
    uint32_t read_data_buf[16*128];

    if (argc != 2) {
        printf("Usage: %s <data>\n", argv[0]);
        return -1;
    }
    uint32_t seed = strtol(argv[1], NULL, 16);

    // Initialize hardware
    if (setup_hardware() != 0) return -1;
    printf("Hardware mapped successfully.\n");

    uint8_t n_ranks = 1;
    uint8_t n_banks = 16;
    uint32_t n_rows = 256;
    const uint32_t total_tests = n_ranks * n_banks * n_rows; // ranks * banks * rows

    uint32_t test_count = 0;
    for (uint8_t rank_addr = 0; rank_addr < n_ranks; rank_addr++) {
        for (uint8_t bank_addr = 0; bank_addr < n_banks; bank_addr++) {
            for (uint32_t row_addr = 0; row_addr < n_rows; row_addr++) {
                gen_data_pattern(write_data_buf, bank_addr, row_addr, rank_addr, seed);
                uint32_t nck = 0;
                nck += write_row(write_data_buf, bank_addr, row_addr, rank_addr);
                nck += read_row(read_data_buf, bank_addr, row_addr, rank_addr);
                // Verify data
                for (int i = 0; i < 128; i++) {
                    for (int j = 0; j < 16; j++) {
                        if (read_data_buf[i*16+j] != write_data_buf[i*16+j]) {
                            printf("Error: Data mismatch at rank %u, bank %u, row %u: %08x != %08x\n", rank_addr, bank_addr, row_addr, read_data_buf[i*16+j], write_data_buf[i*16+j]);
                            return -1;
                        }
                    }
                }
                test_count++;
                printf("Test passed (%u / %u) - rank %u, bank %u, row %u\r", test_count, total_tests, rank_addr, bank_addr, row_addr);
                fflush(stdout);
            }
        }
    }
    printf("\n");

    // Cleanup
    cleanup_hardware();

    return 0;
}
