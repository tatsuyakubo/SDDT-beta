#ifndef API_H
#define API_H

int setup_hardware();
void cleanup_hardware();

// void dma_send(void *dma_base, uint64_t phys_addr, uint32_t length_bytes);
// void dma_recv(void *dma_base, uint64_t phys_addr, uint32_t length_bytes);

void set_write_data(uint8_t b);
void write_cmd(uint32_t row);
void read_cmd(uint32_t row);

#endif