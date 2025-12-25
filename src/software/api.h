#ifndef API_H
#define API_H

#include <stdint.h>
#include <stdbool.h>

int setup_hardware();
void cleanup_hardware();

uint32_t pre(uint8_t bank_addr, uint8_t rank_addr, bool bank_all, uint32_t interval, bool strict);
uint32_t act(uint8_t bank_addr, uint32_t row_addr, uint8_t rank_addr, uint32_t interval, bool strict);
uint32_t rd(uint32_t *buffer, uint8_t bank_addr, uint16_t col_addr, uint32_t interval, bool strict);
uint32_t wr(uint32_t *buffer, uint8_t bank_addr, uint16_t col_addr, uint32_t interval, bool strict);
uint32_t rf(uint32_t interval, bool strict);

uint32_t write_row(uint32_t *data_buf, uint8_t bank_addr, uint32_t row_addr, uint8_t rank_addr);
uint32_t write_row_batch(uint32_t *data_buf, uint8_t bank_addr, uint32_t row_addr, uint8_t rank_addr);
uint32_t read_row(uint32_t *data_buf, uint8_t bank_addr, uint32_t row_addr, uint8_t rank_addr);
uint32_t read_row_batch(uint32_t *data_buf, uint8_t bank_addr, uint32_t row_addr, uint8_t rank_addr);
uint32_t all_bank_refresh(uint8_t rank_addr);

void debug_gpio();

#endif
