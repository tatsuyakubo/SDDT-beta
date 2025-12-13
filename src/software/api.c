#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#define AXI_DMA_0_BASE     0xA0000000
#define AXI_DMA_0_SIZE     0x00010000 // 64KB
#define AXI_BRIDGE_BASE    0xB0000000
#define AXI_BRIDGE_SIZE    0x00010000 // 64KB (NOTE: Mapped memory size, not FIFO size)
// #define AXI_FIFO_DATA_BASE 0xB0010000
// #define AXI_FIFO_DATA_SIZE 0x00010000 // 64KB (NOTE: Mapped memory size for MMIO, not FIFO size)

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

// MMIO Register Offsets
#define REG_ISR         0x00 // Interrupt Status Register
#define REG_TDFV        0x0C // Transmit Data FIFO Vacancy
#define REG_TLR         0x14 // Transmit Length Register
#define REG_TDFR        0x18 // Transmit Data FIFO Reset
// #define REG_TDFD        0x10 // Transmit Data FIFO Data
#define FIFO_RESET_KEY  0x000000A5

// Utilities
#define REG_WRITE(addr, val) (*(volatile uint32_t *)(addr) = (val))
#define REG_READ(addr)       (*(volatile uint32_t *)(addr))

int mem_fd;
void *dma0_vptr;
void *bridge_vptr;
int udmabuf_fd;
void *udmabuf_vptr;
unsigned int udmabuf_size;
unsigned long udmabuf_phys_addr;

// Cleanup Memory Mappings
static void cleanup_mem_mappings(void) {
    if (udmabuf_vptr != NULL && udmabuf_vptr != MAP_FAILED) {
        munmap(udmabuf_vptr, udmabuf_size);
        udmabuf_vptr = NULL;
    }
    if (udmabuf_fd >= 0) {
        close(udmabuf_fd);
        udmabuf_fd = -1;
    }
    if (bridge_vptr != NULL && bridge_vptr != MAP_FAILED) {
        munmap(bridge_vptr, AXI_BRIDGE_SIZE);
        bridge_vptr = NULL;
    }
    if (dma0_vptr != NULL && dma0_vptr != MAP_FAILED) {
        munmap(dma0_vptr, AXI_DMA_0_SIZE);
        dma0_vptr = NULL;
    }
    if (mem_fd >= 0) {
        close(mem_fd);
        mem_fd = -1;
    }
}

// Read and Parse Sysfs Attribute
static int read_sysfs_attr(const char *path, const char *format, void *value) {
    int tmp_fd;
    unsigned char attr[1024];
    ssize_t n;
    if ((tmp_fd = open(path, O_RDONLY)) == -1) {
        perror(path);
        return -1;
    }
    n = read(tmp_fd, attr, sizeof(attr) - 1);
    close(tmp_fd);
    if (n <= 0) {
        if (n < 0) perror(path);
        return -1;
    }
    attr[n] = '\0';
    if (sscanf((const char *)attr, format, value) != 1) {
        fprintf(stderr, "Failed to parse %s\n", path);
        return -1;
    }
    return 0;
}

// Initialize Hardware
int setup_hardware() {
    // Initialize file descriptors to invalid values
    mem_fd = -1;
    udmabuf_fd = -1;
    dma0_vptr = NULL;
    bridge_vptr = NULL;
    udmabuf_vptr = NULL;
    // Open /dev/mem
    if ((mem_fd = open("/dev/mem", O_RDWR | O_SYNC)) == -1) {
        perror("Failed to open /dev/mem");
        return -1;
    }
    // Map DMA 0
    dma0_vptr = mmap(NULL, AXI_DMA_0_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd, AXI_DMA_0_BASE);
    if (dma0_vptr == MAP_FAILED) {
        perror("Failed to map DMA 0");
        cleanup_mem_mappings();
        return -1;
    }
    // Map Bridge
    bridge_vptr = mmap(NULL, AXI_BRIDGE_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, mem_fd, AXI_BRIDGE_BASE);
    if (bridge_vptr == MAP_FAILED) {
        perror("Failed to map Bridge");
        cleanup_mem_mappings();
        return -1;
    }
    // Read udmabuf size
    if (read_sysfs_attr("/sys/class/u-dma-buf/udmabuf0/size", "%d", &udmabuf_size) != 0) {
        cleanup_mem_mappings();
        return -1;
    }
    // Read udmabuf phys_addr
    if (read_sysfs_attr("/sys/class/u-dma-buf/udmabuf0/phys_addr", "%lx", &udmabuf_phys_addr) != 0) {
        cleanup_mem_mappings();
        return -1;
    }
    // Map udmabuf
    if ((udmabuf_fd = open("/dev/udmabuf0", O_RDWR | O_SYNC)) == -1) {
        perror("Failed to open /dev/udmabuf0");
        cleanup_mem_mappings();
        return -1;
    }
    udmabuf_vptr = mmap(NULL, udmabuf_size, PROT_READ | PROT_WRITE, MAP_SHARED, udmabuf_fd, 0);
    if (udmabuf_vptr == MAP_FAILED) {
        perror("Failed to map UDMA Buffer");
        cleanup_mem_mappings();
        return -1;
    }
    return 0;
}

// Cleanup Hardware
void cleanup_hardware() {
    cleanup_mem_mappings();
}

// DMA Transfer (MM2S: Memory to Stream / Send)
void dma_send(void *dma_base, unsigned long phys_addr, uint32_t length_bytes) {
    volatile uint8_t *base = (volatile uint8_t *)dma_base;
    // Run/Stop bit = 1
    uint32_t cr = REG_READ(base + MM2S_DMACR);
    REG_WRITE(base + MM2S_DMACR, cr | 1);
    // Set source address
    REG_WRITE(base + MM2S_SA, phys_addr);
    REG_WRITE(base + MM2S_SA_MSB, 0); // 32bit addressing
    // Set length (starts transfer)
    REG_WRITE(base + MM2S_LENGTH, length_bytes);
    // Wait for idle (bit 1)
    while (!(REG_READ(base + MM2S_DMASR) & 0x02));
}

// DMA Transfer (S2MM: Stream to Memory / Receive)
void dma_recv(void *dma_base, unsigned long phys_addr, uint32_t length_bytes) {
    volatile uint8_t *base = (volatile uint8_t *)dma_base;
    // Run/Stop bit = 1
    uint32_t cr = REG_READ(base + S2MM_DMACR);
    REG_WRITE(base + S2MM_DMACR, cr | 1);
    // Set destination address
    REG_WRITE(base + S2MM_DA, phys_addr);
    REG_WRITE(base + S2MM_DA_MSB, 0); // 32bit addressing
    // Set length (starts transfer)
    REG_WRITE(base + S2MM_LENGTH, length_bytes);
    // Wait for idle (bit 1)
    while (!(REG_READ(base + S2MM_DMASR) & 0x02));
}

// // FIFO Send (64-bit)
// void fifo_send_64bit(uint32_t data, uint32_t interval) {
//     volatile uint8_t *ctrl_base = (volatile uint8_t *)fifo_ctrl_vptr;
//     volatile uint64_t *data_base = (volatile uint64_t *)fifo_data_vptr;
//     // Pack data(32bit) + interval*NOP(32bit) into 64bit words (2x32bit per 64bit)
//     uint32_t num_64bit_words = (1 + interval + 1) / 2; // ceil((1+interval)/2)
//     uint32_t packet_len_bytes = 8 * num_64bit_words;
//     if (packet_len_bytes > 8*AXI_FIFO_DATA_SIZE) {
//         fprintf(stderr, "Packet length is too long: %d bytes\n", packet_len_bytes);
//         exit(1);
//     }
//     // Check for free space (Lite interface)
//     while (REG_READ(ctrl_base + REG_TDFV) < num_64bit_words);
//     // Write data (Full interface) -> burst transfer!
//     // First 64bit: data(lower 32bit) + first NOP(upper 32bit)
//     data_base[0] = ((uint64_t)0 << 32) | data;
//     // Remaining NOPs packed 2 per 64bit word (all NOPs are 0)
//     // Loop unrolling and NEON can be used for further speedup
//     for (int i = 1; i < num_64bit_words; i++) {
//         data_base[0] = 0; // Two NOPs packed: 0(lower 32bit) + 0(upper 32bit)
//     }
//     // Trigger transmission (Lite interface)
//     // When this is written, the data in the buffer is output as a stream.
//     REG_WRITE(ctrl_base + REG_TLR, packet_len_bytes);
// }

// Command Send (32-bit)
void cmd_send_32bit(uint32_t cmd, uint32_t interval) {
    volatile uint32_t *bridge_base = (volatile uint32_t *)bridge_vptr;
    // Write data (Full interface) -> burst transfer!
    // Command
    bridge_base[0] = cmd;
    // Interval (NOP)
    // Loop unrolling and NEON can be used for further speedup
    for (int i = 1; i < interval+1; i++) {
        bridge_base[i] = 0; 
    }
}

// Command Send
void cmd_send(uint32_t cmd, uint32_t interval) {
    // fifo_send_32bit(data, interval);
    cmd_send_32bit(cmd, interval);
}

// Precharge Command
uint32_t pre(uint8_t bank_addr, uint8_t rank_addr, bool bank_all, uint32_t interval, bool strict) {
    bank_addr &= 0xF; // 4 bits
    uint32_t cmd = 1 | (bank_addr << 3) | (bank_all << 7); // Precharge
    cmd_send(cmd, interval);
    uint32_t nck = 1 + interval;
    return nck;
}

// Activation Command
uint32_t act(uint8_t bank_addr, uint32_t row_addr, uint8_t rank_addr, uint32_t interval, bool strict) {
    bank_addr &= 0xF; // 4 bits
    row_addr &= 0x7FFF; // 17 bits
    uint32_t cmd = 2 | (bank_addr << 3) | (row_addr << 7); // Activate
    cmd_send(cmd, interval);
    uint32_t nck = 1 + interval;
    return nck;
}

// Read Command
uint32_t rd(uint32_t *buffer, uint8_t bank_addr, uint16_t col_addr, uint32_t interval, bool strict) {
    bank_addr &= 0xF; // 4 bits
    col_addr &= 0x3FF; // 10 bits
    uint32_t cmd = 3 | (bank_addr << 3) | (col_addr << 7); // Read
    cmd_send(cmd, interval);
    // Receive data
    dma_recv(dma0_vptr, udmabuf_phys_addr, 16 * sizeof(uint32_t)); // 512 bits
    // Copy data to buffer
    memcpy(buffer, (uint32_t *)udmabuf_vptr, 16 * sizeof(uint32_t)); // 512 bits, 64 bytes
    uint32_t nck = 1 + interval;
    return nck;
}

// Write Command
uint32_t wr(uint32_t *buffer, uint8_t bank_addr, uint16_t col_addr, uint32_t interval, bool strict) {
    bank_addr &= 0xF; // 4 bits
    col_addr &= 0x3FF; // 10 bits
    uint32_t cmd = 4 | (bank_addr << 3) | (col_addr << 7); // Write
    // Set data
    uint32_t *ptr = (uint32_t *)udmabuf_vptr;
    for (int i = 0; i < 16; i++) {
        ptr[i] = buffer[i];
    }
    dma_send(dma0_vptr, udmabuf_phys_addr, 16 * sizeof(uint32_t)); // 512 bits, 64 bytes
    // Send command
    cmd_send(cmd, interval);
    uint32_t nck = 1 + interval;
    return nck;
}

// Refresh Command
uint32_t rf(uint32_t interval, bool strict) {
    uint32_t cmd = 5; // Refresh
    cmd_send(cmd, interval);
    uint32_t nck = 1 + interval;
    return nck;
}
