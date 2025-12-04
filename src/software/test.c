#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "api.h"

int main(int argc, char *argv[]) {
    if (argc != 2) {
        printf("Usage: %s <data>\n", argv[0]);
        return -1;
    }
    uint8_t data = strtol(argv[1], NULL, 16);

    if (setup_hardware() != 0) return -1;
    printf("Hardware mapped successfully.\n");

    printf("Starting operations...\n");
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    set_write_data(data);
    write_cmd(0);
    read_cmd(0);

    clock_gettime(CLOCK_MONOTONIC, &end);
    double latency_s = (end.tv_sec - start.tv_sec) + 
                        (end.tv_nsec - start.tv_nsec) * 1e-9;
    printf("Time taken: %f seconds\n", latency_s);

    // Cleanup
    cleanup_hardware();

    return 0;
}
