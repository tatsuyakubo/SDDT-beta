#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "api.h"

// tCK = 1.5ns (666MHz)
#define nRP    9 // tRP  = 14.16ns, nRP  = 14.16 / 1.5 = 9.44
#define nRCD   9 // tRCD = 14.16ns, nRCD = 14.16 / 1.5 = 9.44
#define nCCD_L 3 // tCCD_L = 6 * 0.833 = 5.0ns, nCCD_L = 5.0 / 1.5 = 3.33

uint32_t write_row(uint8_t *data_buf, uint32_t row_addr) {
    uint8_t bank_addr = 0;
    uint8_t rank_addr = 0;
    uint32_t nck = 0;
    nck += pre(bank_addr, rank_addr, false, nRP, false);
    nck += act(bank_addr, row_addr, rank_addr, nRCD, false);
    for (int i = 0; i < 128; i++) {
        data_buf[0] += 1;
        nck += wr(data_buf, bank_addr, i*8, nCCD_L, false);
    }
    return nck;
}

uint32_t read_row(uint8_t *data_buf, uint32_t row_addr) {
    uint8_t bank_addr = 0;
    uint8_t rank_addr = 0;
    uint32_t nck = 0;
    nck += pre(bank_addr, rank_addr, false, nRP, false);
    nck += act(bank_addr, row_addr, rank_addr, nRCD, false);
    for (int i = 0; i < 128; i++) {
        nck += rd(data_buf+i*64, bank_addr, i*8, nCCD_L, false);
    }
    return nck;
}

int main(int argc, char *argv[]) {
    uint8_t write_data_buf[64];
    uint8_t read_data_buf[64*128];

    if (argc != 2) {
        printf("Usage: %s <data>\n", argv[0]);
        return -1;
    }
    uint8_t data = strtol(argv[1], NULL, 16);
    for (int i = 0; i < 64; i++) {
        write_data_buf[i] = data + i;
    }

    // Initialize hardware
    if (setup_hardware() != 0) return -1;
    printf("Hardware mapped successfully.\n");

    printf("Starting operations...\n");
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    uint32_t nck = 0;
    nck += write_row(write_data_buf, 0);
    nck += read_row(read_data_buf, 0);

    clock_gettime(CLOCK_MONOTONIC, &end);
    double latency_s = (end.tv_sec - start.tv_sec) + 
                        (end.tv_nsec - start.tv_nsec) * 1e-9;
    double ideal_latency_s = nck * 1.5e-9;
    printf("Time taken: %f seconds\n", latency_s);
    printf("Overhead: %fx slower than ideal\n", latency_s / ideal_latency_s);

    // for (int i = 0; i < 128; i++) {
    //     for (int j = 0; j < 64; j++) {
    //         printf("%02x ", read_data_buf[i*64+j]);
    //     }
    //     printf("\n");
    // }

    // Cleanup
    cleanup_hardware();

    return 0;
}
