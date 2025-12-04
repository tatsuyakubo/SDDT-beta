#ifndef UTILS_H
#define UTILS_H

#include <stdint.h>

uint32_t write_row(uint8_t *data_buf, uint8_t bank_addr, uint32_t row_addr, uint8_t rank_addr);
uint32_t read_row(uint8_t *data_buf, uint8_t bank_addr, uint32_t row_addr, uint8_t rank_addr);

#endif