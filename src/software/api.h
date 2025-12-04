#ifndef API_H
#define API_H

#include <stdint.h>
#include <stdbool.h>

int setup_hardware();
void cleanup_hardware();

uint32_t pre(uint8_t bank_addr, uint8_t rank_addr, bool bank_all, uint32_t interval, bool strict);
uint32_t act(uint8_t bank_addr, uint32_t row_addr, uint8_t rank_addr, uint32_t interval, bool strict);
uint32_t rd(uint8_t *buffer, uint8_t bank_addr, uint16_t col_addr, uint32_t interval, bool strict);
uint32_t wr(uint8_t *buffer, uint8_t bank_addr, uint16_t col_addr, uint32_t interval, bool strict);

#endif
