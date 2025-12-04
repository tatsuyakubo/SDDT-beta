#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "api.h"

uint32_t write_row(uint8_t *data_buf, uint32_t row_addr) {
    uint8_t bank_addr = 0;
    uint8_t rank_addr = 0;
    uint32_t nck = 0;
    nck += pre(bank_addr, rank_addr, false, 0, false);
    nck += act(bank_addr, row_addr, rank_addr, 0, false);
    nck += wr(data_buf, 0, 0, false);
    return nck;
}

uint32_t read_row(uint8_t *data_buf, uint32_t row_addr) {
    uint8_t bank_addr = 0;
    uint8_t rank_addr = 0;
    uint32_t nck = 0;
    nck += pre(bank_addr, rank_addr, false, 0, false);
    nck += act(bank_addr, row_addr, rank_addr, 0, false);
    nck += rd(data_buf, 0, 0, false);
    return nck;
}

int main(int argc, char *argv[]) {
    uint8_t write_data_buf[64];
    uint8_t read_data_buf[64];

    if (argc != 2) {
        printf("Usage: %s <data>\n", argv[0]);
        return -1;
    }
    uint8_t data = strtol(argv[1], NULL, 16);
    for (int i = 0; i < 64; i++) {
        write_data_buf[i] = data;
    }

    if (setup_hardware() != 0) return -1;
    printf("Hardware mapped successfully.\n");

    printf("Starting operations...\n");
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    write_row(write_data_buf, 0);
    read_row(read_data_buf, 0);

    clock_gettime(CLOCK_MONOTONIC, &end);
    double latency_s = (end.tv_sec - start.tv_sec) + 
                        (end.tv_nsec - start.tv_nsec) * 1e-9;
    printf("Time taken: %f seconds\n", latency_s);

    for (int i = 0; i < 64; i++) {
        printf("%02x ", read_data_buf[i]);
        if (i % 8 == 7) {
            printf("\n");
        }
    }

    // Cleanup
    cleanup_hardware();

    return 0;
}
