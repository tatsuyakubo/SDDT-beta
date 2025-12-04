#ifndef UTILS_H
#define UTILS_H

#include <stdint.h>

uint32_t write_row(uint32_t *data_buf, uint8_t bank_addr, uint32_t row_addr, uint8_t rank_addr);
uint32_t read_row(uint32_t *data_buf, uint8_t bank_addr, uint32_t row_addr, uint8_t rank_addr);
void gen_data_pattern(uint32_t *data_buf, uint8_t bank_addr, uint32_t row_addr, uint8_t rank_addr, uint32_t seed);

#endif
