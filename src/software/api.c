#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#define AXI_DMA_0_BASE  0xA0000000
#define AXI_DMA_0_SIZE  0x00010000 // 64KB
#define AXI_DMA_1_BASE  0x80010000
#define AXI_DMA_1_SIZE  0x00010000 // 64KB

#define BRAM_PHYS_BASE  0xB0000000
#define BRAM_SIZE       0x00002000 // 8KB

// DMA Register Offsets
#define MM2S_DMACR      0x00 // Control
#define MM2S_DMASR      0x04 // Status
#define MM2S_SA         0x18 // Source Address
#define MM2S_SA_MSB     0x1C
#define MM2S_LENGTH     0x28
#define S2MM_DMACR      0x30
#define S2MM_DMASR      0x34
#define S2MM_DA         0x48
#define S2MM_DA_MSB     0x4C
#define S2MM_LENGTH     0x58

// Utilities
#define REG_WRITE(addr, val) (*(volatile uint32_t *)(addr) = (val))
#define REG_READ(addr)       (*(volatile uint32_t *)(addr))

void *dma0_vptr;
void *dma1_vptr;
int mem_fd;
int udmabuf_fd;
void *udmabuf_vptr;
unsigned int udmabuf_size;
unsigned long udmabuf_phys_addr;
uint32_t *bram_vptr;

// Initialize hardware
int setup_hardware() {
    if ((mem_fd = open("/dev/mem", O_RDWR | O_SYNC)) == -1) {
        perror("Failed to open /dev/mem");
        return -1;
    }
    // Map DMA 0
    dma0_vptr = mmap(NULL, AXI_DMA_0_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd, AXI_DMA_0_BASE);
    if (dma0_vptr == MAP_FAILED) return -1;
    // Map DMA 1
    dma1_vptr = mmap(NULL, AXI_DMA_1_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd, AXI_DMA_1_BASE);
    if (dma1_vptr == MAP_FAILED) return -1;
    // Map BRAM
    bram_vptr = mmap(NULL, BRAM_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd, BRAM_PHYS_BASE);
    if (bram_vptr == MAP_FAILED) return -1;
    // Read udmabuf size
    int tmp_fd;
    unsigned char attr[1024];
    if ((tmp_fd = open("/sys/class/u-dma-buf/udmabuf0/size", O_RDONLY)) == -1) {
        perror("Failed to open /sys/class/u-dma-buf/udmabuf0/size");
        return -1;
    }
    ssize_t n = read(tmp_fd, attr, 1024);
    if (n == 0) return -1;
    attr[n] = '\0'; // Null-terminate the string
    sscanf((const char *)attr, "%d", &udmabuf_size);
    // Read udmabuf phys_addr
    if ((tmp_fd = open("/sys/class/u-dma-buf/udmabuf0/phys_addr", O_RDONLY)) == -1) {
        perror("Failed to open /sys/class/u-dma-buf/udmabuf0/phys_addr");
        return -1;
    }
    n = read(tmp_fd, attr, 1024);
    if (n == 0) return -1;
    attr[n] = '\0'; // Null-terminate the string
    sscanf((const char *)attr, "%lx", &udmabuf_phys_addr);
    close(tmp_fd);
    // Map UDMA Buffer
    if ((udmabuf_fd = open("/dev/udmabuf0", O_RDWR | O_SYNC)) == -1) {
        perror("Failed to open /dev/udmabuf0");
        return -1;
    }
    udmabuf_vptr = mmap(NULL, udmabuf_size, PROT_READ | PROT_WRITE, MAP_SHARED, udmabuf_fd, 0);
    if (udmabuf_vptr == MAP_FAILED) return -1;
    return 0;
}

// Cleanup hardware
void cleanup_hardware() {
    munmap(dma0_vptr, AXI_DMA_0_SIZE);
    munmap(dma1_vptr, AXI_DMA_1_SIZE);
    munmap(bram_vptr, BRAM_SIZE);
    munmap(udmabuf_vptr, udmabuf_size);
    close(mem_fd);
    close(udmabuf_fd);
}

// DMA Transfer (MM2S: Memory to Stream / Send)
void dma_send(void *dma_base, unsigned long phys_addr, uint32_t length_bytes) {
    volatile uint8_t *base = (volatile uint8_t *)dma_base;
    // Run/Stop bit = 1
    uint32_t cr = REG_READ(base + MM2S_DMACR);
    REG_WRITE(base + MM2S_DMACR, cr | 1);
    // Set Source Address
    REG_WRITE(base + MM2S_SA, phys_addr);
    REG_WRITE(base + MM2S_SA_MSB, 0); // 32bit addressing
    // Set Length (starts transfer)
    REG_WRITE(base + MM2S_LENGTH, length_bytes);
    // Wait for Idle (bit 1)
    while (!(REG_READ(base + MM2S_DMASR) & 0x02));
}

// DMA Transfer (S2MM: Stream to Memory / Receive)
void dma_recv(void *dma_base, unsigned long phys_addr, uint32_t length_bytes) {
    volatile uint8_t *base = (volatile uint8_t *)dma_base;
    // Run/Stop bit = 1
    uint32_t cr = REG_READ(base + S2MM_DMACR);
    REG_WRITE(base + S2MM_DMACR, cr | 1);
    // Set Destination Address
    REG_WRITE(base + S2MM_DA, phys_addr);
    REG_WRITE(base + S2MM_DA_MSB, 0); // 32bit addressing
    // Set Length (starts transfer)
    REG_WRITE(base + S2MM_LENGTH, length_bytes);
    // Wait for Idle (bit 1)
    while (!(REG_READ(base + S2MM_DMASR) & 0x02));
}

// Precharge Command
uint32_t pre(uint8_t bank_addr, uint8_t rank_addr, bool bank_all, uint32_t interval, bool strict) {
    bank_addr &= 0xF; // 4 bits
    uint32_t nck = 1 + interval;
    uint32_t cmd = 1 | (bank_addr << 3); // Precharge
    bram_vptr[0] = cmd;
    dma_send(dma1_vptr, BRAM_PHYS_BASE, 16 * sizeof(uint32_t)); // 512 bits, 16 commands
    return nck;
}

// Activation Command
uint32_t act(uint8_t bank_addr, uint32_t row_addr, uint8_t rank_addr, uint32_t interval, bool strict) {
    bank_addr &= 0xF; // 4 bits
    row_addr &= 0x7FFF; // 17 bits
    uint32_t nck = 1 + interval;
    uint32_t cmd = 2 | (bank_addr << 3) | (row_addr << 7); // Activate
    bram_vptr[0] = cmd;
    dma_send(dma1_vptr, BRAM_PHYS_BASE, 16 * sizeof(uint32_t)); // 512 bits, 16 commands
    return nck;
}

// Read Command
uint32_t rd(uint8_t *buffer, uint16_t col_addr, uint32_t interval, bool strict) {
    col_addr &= 0x3FF; // 10 bits
    uint32_t nck = 1 + interval;
    uint32_t cmd = 3 | (col_addr << 7); // Read
    bram_vptr[0] = cmd;
    dma_send(dma1_vptr, BRAM_PHYS_BASE, 16 * sizeof(uint32_t)); // 512 bits, 16 commands
    // Receive Data
    dma_recv(dma0_vptr, udmabuf_phys_addr, 16 * sizeof(uint32_t)); // 512 bits
    // Copy Data to Buffer
    memcpy(buffer, (uint8_t *)udmabuf_vptr, 64 * sizeof(uint8_t)); // 512 bits, 64 bytes
    return nck;
}

// Write Command
uint32_t wr(uint8_t *buffer, uint16_t col_addr, uint32_t interval, bool strict) {
    col_addr &= 0x3FF; // 10 bits
    uint32_t nck = 1 + interval;
    uint32_t cmd = 4 | (col_addr << 7); // Write
    bram_vptr[0] = cmd;
    // Set write data
    uint8_t *ptr = (uint8_t *)udmabuf_vptr;
    for (int i = 0; i < 64; i++) {
        ptr[i] = buffer[i];
    }
    dma_send(dma0_vptr, udmabuf_phys_addr, 64 * sizeof(uint8_t)); // 512 bits, 64 bytes
    // Send Command
    dma_send(dma1_vptr, BRAM_PHYS_BASE, 16 * sizeof(uint32_t)); // 512 bits, 16 commands
    return nck;
}

// void set_write_data(uint8_t b) {
//     uint8_t *ptr = (uint8_t *)udmabuf_vptr;
//     for (int i = 0; i < 64; i++) {
//         ptr[i] = b;
//     }
//     dma_send(dma0_vptr, udmabuf_phys_addr, 64 * sizeof(uint8_t));
// }

// void write_cmd(uint32_t row) {
//     uint32_t stages;
//     // Precharge
//     stages = 3;
//     bram_vptr[0] = 1 | (stages << 24);
//     dma_send(dma1_vptr, BRAM_PHYS_BASE, 16 * sizeof(uint32_t));
//     // Activate
//     stages = 3;
//     bram_vptr[0] = 2 | (row << 7) | (stages << 24);
//     dma_send(dma1_vptr, BRAM_PHYS_BASE, 16 * sizeof(uint32_t));
//     // Write
//     stages = 3;
//     bram_vptr[0] = 4 | (stages << 24);
//     dma_send(dma1_vptr, BRAM_PHYS_BASE, 16 * sizeof(uint32_t));
// }

// void read_cmd(uint32_t row) {
//     uint32_t stages;
//     // Precharge
//     stages = 3;
//     bram_vptr[0] = 1 | (stages << 24);
//     dma_send(dma1_vptr, BRAM_PHYS_BASE, 16 * sizeof(uint32_t));
//     // Activate
//     stages = 3;
//     bram_vptr[0] = 2 | (row << 7) | (stages << 24);
//     dma_send(dma1_vptr, BRAM_PHYS_BASE, 16 * sizeof(uint32_t));
//     // Read
//     stages = 3;
//     bram_vptr[0] = 3 | (stages << 24);
//     dma_send(dma1_vptr, BRAM_PHYS_BASE, 16 * sizeof(uint32_t));
//     // Receive Data
//     dma_recv(dma0_vptr, udmabuf_phys_addr, 16 * sizeof(uint32_t));
//     // Print Data
//     uint32_t *ptr = (uint32_t *)udmabuf_vptr;
//     for (int i = 0; i < 16; i++) {
//         printf("%08x ", ptr[i]);
//         if (i % 8 == 7) {
//             printf("\n");
//         }
//     }
//     printf("\n");
// }
