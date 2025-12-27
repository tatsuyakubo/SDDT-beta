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

    // Initialize parameters
    uint8_t bank_addr = 0;
    uint32_t row_addr = 0;
    uint8_t rank_addr = 0;
    gen_data_pattern(write_data_buf, bank_addr, row_addr, rank_addr, seed);

    // Initialize hardware
    if (setup_hardware() != 0) return -1;
    printf("Hardware mapped successfully.\n");

    /*** Start operations ***/
    printf("Starting operations...\n");
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    uint32_t nck = 0;
    nck += write_row_batch(write_data_buf, bank_addr, row_addr, rank_addr);
    nck += all_bank_refresh(rank_addr);
    nck += read_row(read_data_buf, bank_addr, row_addr, rank_addr);
    nck += all_bank_refresh(rank_addr);

    /*** End operations ***/
    clock_gettime(CLOCK_MONOTONIC, &end);
    printf("Stopped operations.\n");

    for (int i = 0; i < 128; i++) {
        for (int j = 0; j < 16; j++) {
            printf("%08x ", read_data_buf[i*16+j]);
        }
        printf("\n");
    }
    printf("Read data done.\n");

    double latency_s = (end.tv_sec - start.tv_sec) + 
                        (end.tv_nsec - start.tv_nsec) * 1e-9;
    double ideal_latency_s = nck * 1.5e-9;
    printf("Time taken: %f seconds\n", latency_s);
    printf("Overhead: %fx slower than ideal\n", latency_s / ideal_latency_s);

    // Verify data
    for (int i = 0; i < 128; i++) {
        for (int j = 0; j < 16; j++) {
            if (read_data_buf[i*16+j] != write_data_buf[i*16+j]) {
                printf("Error: Data mismatch at row %d, col %d: %08x != %08x\n", i, j, read_data_buf[i*16+j], write_data_buf[i*16+j]);
                return -1;
            }
        }
    }
    printf("Data verification done.\n");
    printf("\n");

    debug_gpio();

    // Cleanup
    cleanup_hardware();

    return 0;
}
