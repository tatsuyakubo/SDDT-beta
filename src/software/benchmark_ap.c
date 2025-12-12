#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "api.h"

int main(int argc, char *argv[]) {
    // Initialize hardware
    if (setup_hardware() != 0) return -1;
    printf("Hardware mapped successfully.\n");

    uint8_t n_ranks = 1;
    uint8_t n_banks = 16;
    uint32_t n_rows = 256;

    /*** Start operations ***/
    printf("Starting operations...\n");
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    // Operations
    uint32_t nck = 0;
    for (uint8_t rank_addr = 0; rank_addr < n_ranks; rank_addr++) {
        for (uint8_t bank_addr = 0; bank_addr < n_banks; bank_addr++) {
            for (uint32_t row_addr = 0; row_addr < n_rows; row_addr++) {
                nck += pre(bank_addr, rank_addr, false, 9, false);
                nck += act(bank_addr, row_addr, rank_addr, 9, false);
            }
        }
    }

    /*** End operations ***/
    clock_gettime(CLOCK_MONOTONIC, &end);
    printf("Stopped operations.\n");

    double latency_s = (end.tv_sec - start.tv_sec) + 
                        (end.tv_nsec - start.tv_nsec) * 1e-9;
    double ideal_latency_s = nck * 1.5e-9;
    printf("Time taken: %f seconds\n", latency_s);
    printf("Overhead: %fx slower than ideal\n", latency_s / ideal_latency_s);

    // Cleanup
    cleanup_hardware();

    return 0;
}
