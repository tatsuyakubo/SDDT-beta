#include <stdio.h>
#include <time.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

// Utilities
#define REG_WRITE(addr, val) (*(volatile uint32_t *)(addr) = (val))
#define REG_READ(addr)       (*(volatile uint32_t *)(addr))

// DMA Register Offsets
#define MM2S_DMACR      0x00 // Control
#define MM2S_DMASR      0x04 // Status
#define MM2S_SA         0x18 // Source Address
#define MM2S_SA_MSB     0x1C // 32bit addressing
#define MM2S_LENGTH     0x28 // Length of the transfer
#define S2MM_DMACR      0x30 // Control
#define S2MM_DMASR      0x34 // Status
#define S2MM_DA         0x48 // Destination Address
#define S2MM_DA_MSB     0x4C // 32bit addressing
#define S2MM_LENGTH     0x58 // Length of the transfer

// GPIO Register Offsets
#define GPIO_DATA       0x00  // Channel 1 Data Register
#define GPIO_TRI        0x04  // Channel 1 Tri-state Register (0=output, 1=input)
#define GPIO2_DATA      0x08  // Channel 2 Data Register
#define GPIO2_TRI       0x0C  // Channel 2 Tri-state Register (0=output, 1=input)

// Physical Addresses
#define AXI_DMA_0_BASE  0xA0000000
#define AXI_DMA_0_SIZE  0x00010000 // 64KB
#define AXI_GPIO_BASE   0x80000000
#define AXI_GPIO_SIZE   0x00010000 // 64KB
#define AXI_BRIDGE_BASE 0xB0000000
#define AXI_BRIDGE_SIZE 0x00010000 // 64KB (NOTE: Mapped memory size, not FIFO size)

// Timing Parameters
// tCK = 1.5ns (666MHz)
#define nRP    9 // tRP  = 14.16ns, nRP  = 14.16 / 1.5 = 9.44
#define nRCD   9 // tRCD = 14.16ns, nRCD = 14.16 / 1.5 = 9.44
#define nCCD_L 3 // tCCD_L = 6 * 0.833 = 5.0ns, nCCD_L = 5.0 / 1.5 = 3.33
// tREFI = 7.8us
#define nRFC 233 // tRFC = 421 * 0.833 = 350.693ns, nRFC = 350.693 / 1.5 = 233.795

int mem_fd;
int bridge_fd;
void *dma0_vptr;
void *bridge_vptr;
int udmabuf_fd;
void *udmabuf_vptr;
unsigned int udmabuf_size;
unsigned long udmabuf_phys_addr;
void *gpio_vptr;
// Bridge index tracking (for circular buffer)
static uint32_t bridge_32bit_index = 0;
static uint32_t bridge_64bit_index = 0;

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
    if (bridge_vptr != NULL) {
        munmap(bridge_vptr, AXI_BRIDGE_SIZE);
        bridge_vptr = NULL;
    }
    if (bridge_fd >= 0) {
        close(bridge_fd);
        bridge_fd = -1;
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
    bridge_fd = -1;
    udmabuf_fd = -1;
    dma0_vptr = NULL;
    bridge_vptr = NULL;
    udmabuf_vptr = NULL;
    gpio_vptr = NULL;
    // Open /dev/mem
    if ((mem_fd = open("/dev/mem", O_RDWR | O_SYNC)) == -1) {
        perror("Failed to open /dev/mem");
        return -1;
    }
    // Open /dev/bridge
    if ((bridge_fd = open("/dev/mem", O_RDWR | O_SYNC)) == -1) {
        perror("Failed to open /dev/mem");
    // if ((bridge_fd = open("/dev/bridge_wc", O_RDWR | O_SYNC)) == -1) {
    //     perror("Failed to open /dev/bridge_wc");
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
    bridge_vptr = mmap(NULL, AXI_BRIDGE_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, bridge_fd, AXI_BRIDGE_BASE);
    if (bridge_vptr == MAP_FAILED) {
        perror("Failed to map Bridge");
        cleanup_mem_mappings();
        return -1;
    }
    // Map GPIO
    gpio_vptr = mmap(NULL, AXI_GPIO_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, mem_fd, AXI_GPIO_BASE);
    if (gpio_vptr == MAP_FAILED) {
        perror("Failed to map GPIO");
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

// DMA Transfer Start (MM2S: Memory to Stream / Send)
void dma_send_start(void *dma_base, unsigned long phys_addr, uint32_t length_bytes) {
    volatile uint8_t *base = (volatile uint8_t *)dma_base;
    // Ensure Run/Stop bit is 1
    uint32_t cr = REG_READ(base + MM2S_DMACR);
    if (!(cr & 1)) {
        REG_WRITE(base + MM2S_DMACR, cr | 1);
    }
    // Set source address
    REG_WRITE(base + MM2S_SA, phys_addr);
    REG_WRITE(base + MM2S_SA_MSB, 0); // 32bit addressing
    // Set length (starts transfer)
    REG_WRITE(base + MM2S_LENGTH, length_bytes);
}

// DMA Transfer Wait (MM2S: Memory to Stream / Send)
void dma_send_wait(void *dma_base) {
    volatile uint8_t *base = (volatile uint8_t *)dma_base;
    uint32_t timeout = 10000000;
    while (!(REG_READ(base + MM2S_DMASR) & 0x02) && --timeout);
    if (timeout == 0) {
        uint32_t final_status = REG_READ(base + MM2S_DMASR);
        uint32_t final_cr = REG_READ(base + MM2S_DMACR);
        printf("\nDMA S2MM Timed out!\n");
        printf("Final DMACR: 0x%08X\n", final_cr);
        printf("Final DMASR: 0x%08X\n", final_status);
        printf("  Halted (bit 0): %d\n", (final_status >> 0) & 1);
        printf("  Idle (bit 1): %d\n", (final_status >> 1) & 1);
        printf("  SG_Incld (bit 2): %d\n", (final_status >> 2) & 1);
        printf("  DMA Internal Error (bit 3): %d\n", (final_status >> 3) & 1);
        printf("  DMA Slave Error (bit 4): %d\n", (final_status >> 4) & 1);
        printf("  DMA Decode Error (bit 5): %d\n", (final_status >> 5) & 1);
        printf("  IOC_Irq (bit 12): %d\n", (final_status >> 12) & 1);
        printf("  Dly_Irq (bit 13): %d\n", (final_status >> 13) & 1);
        printf("  Err_Irq (bit 14): %d\n", (final_status >> 14) & 1);
        fprintf(stderr, "DMA S2MM Timed out! Status: 0x%08X\n", final_status);
        exit(1);
    }
}

// DMA Transfer (MM2S: Memory to Stream / Send)
void dma_send(void *dma_base, unsigned long phys_addr, uint32_t length_bytes) {
    dma_send_start(dma_base, phys_addr, length_bytes);
    dma_send_wait(dma_base);
}

// DMA Transfer Start (S2MM: Stream to Memory / Receive)
void dma_recv_start(void *dma_base, unsigned long phys_addr, uint32_t length_bytes) {
    volatile uint8_t *base = (volatile uint8_t *)dma_base;
    // Ensure Run/Stop bit is 1
    uint32_t cr = REG_READ(base + S2MM_DMACR);
    if (!(cr & 1)) {
        REG_WRITE(base + S2MM_DMACR, cr | 1);
    }
    // Set destination address
    REG_WRITE(base + S2MM_DA, phys_addr);
    REG_WRITE(base + S2MM_DA_MSB, 0); // 32bit addressing
    // Set length (starts transfer)
    REG_WRITE(base + S2MM_LENGTH, length_bytes);
}

// DMA Transfer Wait (S2MM: Stream to Memory / Receive)
void dma_recv_wait(void *dma_base) {
    volatile uint8_t *base = (volatile uint8_t *)dma_base;
    uint32_t timeout = 10000000;
    while (!(REG_READ(base + S2MM_DMASR) & 0x02) && --timeout);
    if (timeout == 0) {
        uint32_t final_status = REG_READ(base + S2MM_DMASR);
        uint32_t final_cr = REG_READ(base + S2MM_DMACR);
        printf("\nDMA S2MM Timed out!\n");
        printf("Final DMACR: 0x%08X\n", final_cr);
        printf("Final DMASR: 0x%08X\n", final_status);
        printf("  Halted (bit 0): %d\n", (final_status >> 0) & 1);
        printf("  Idle (bit 1): %d\n", (final_status >> 1) & 1);
        printf("  SG_Incld (bit 2): %d\n", (final_status >> 2) & 1);
        printf("  DMA Internal Error (bit 3): %d\n", (final_status >> 3) & 1);
        printf("  DMA Slave Error (bit 4): %d\n", (final_status >> 4) & 1);
        printf("  DMA Decode Error (bit 5): %d\n", (final_status >> 5) & 1);
        printf("  IOC_Irq (bit 12): %d\n", (final_status >> 12) & 1);
        printf("  Dly_Irq (bit 13): %d\n", (final_status >> 13) & 1);
        printf("  Err_Irq (bit 14): %d\n", (final_status >> 14) & 1);
        fprintf(stderr, "DMA S2MM Timed out! Status: 0x%08X\n", final_status);
        exit(1);
    }
}

// DMA Transfer (S2MM: Stream to Memory / Receive)
void dma_recv(void *dma_base, unsigned long phys_addr, uint32_t length_bytes) {
    dma_recv_start(dma_base, phys_addr, length_bytes);
    dma_recv_wait(dma_base);
}

// GPIO Read
uint32_t gpio_read(int channel, bool change_mode) {
    uint32_t tri_offset, data_offset;
    if (channel == 1) {
        tri_offset = GPIO_TRI;
        data_offset = GPIO_DATA;
    } else if (channel == 2) {
        tri_offset = GPIO2_TRI;
        data_offset = GPIO2_DATA;
    } else {
        fprintf(stderr, "Invalid channel: %d\n", channel);
        exit(1);
    }
    if (change_mode) {
        REG_WRITE((volatile uint8_t *)gpio_vptr + tri_offset, 0xFFFFFFFF);
    }
    return REG_READ((volatile uint8_t *)gpio_vptr + data_offset);
}

// GPIO Write
void gpio_write(int channel, uint32_t data, bool change_mode) {
    uint32_t tri_offset, data_offset;
    if (channel == 1) {
        tri_offset = GPIO_TRI;
        data_offset = GPIO_DATA;
    } else if (channel == 2) {
        tri_offset = GPIO2_TRI;
        data_offset = GPIO2_DATA;
    } else {
        fprintf(stderr, "Invalid channel: %d\n", channel);
        exit(1);
    }
    if (change_mode) {
        REG_WRITE((volatile uint8_t *)gpio_vptr + tri_offset, 0x00000000);
    }
    REG_WRITE((volatile uint8_t *)gpio_vptr + data_offset, data);
}

// Command Send (64-bit)
void cmd_send_64bit(uint32_t data, uint32_t interval) {
    // Pack data(32bit) + interval*NOP(32bit) into 64bit words (2x32bit per 64bit)
    uint32_t num_64bit_words = (1 + interval + 1) / 2; // ceil((1+interval)/2)
    uint32_t packet_len_bytes = 8*num_64bit_words;
    if (packet_len_bytes > AXI_BRIDGE_SIZE) {
        fprintf(stderr, "Packet length is too long: %d bytes\n", packet_len_bytes);
        exit(1);
    }
    volatile uint64_t *bridge_base = (volatile uint64_t *)bridge_vptr;
    uint32_t max_index = AXI_BRIDGE_SIZE / 8; // Maximum index for 64-bit words
    // Write data (Full interface) -> burst transfer!
    // First 64bit: data(lower 32bit) + first NOP(upper 32bit)
    bridge_base[bridge_64bit_index] = ((uint64_t)0 << 32) | data;
    bridge_64bit_index++;
    if (bridge_64bit_index >= max_index) {
        bridge_64bit_index = 0;
    }
    // Remaining NOPs packed 2 per 64bit word (all NOPs are 0)
    // Loop unrolling and NEON can be used for further speedup
    for (int i = 1; i < num_64bit_words+1; i++) {
        bridge_base[bridge_64bit_index] = 0; // Two NOPs packed: 0(lower 32bit) + 0(upper 32bit)
        bridge_64bit_index++;
        if (bridge_64bit_index >= max_index) {
            bridge_64bit_index = 0;
        }
    }
}

// Command Send (32-bit)
void cmd_send_32bit(uint32_t cmd, uint32_t interval) {
    uint32_t packet_len_bytes = 4*(1 + interval);
    if (packet_len_bytes > AXI_BRIDGE_SIZE) {
        fprintf(stderr, "Packet length is too long: %d bytes\n", packet_len_bytes);
        exit(1);
    }
    volatile uint32_t *bridge_base = (volatile uint32_t *)bridge_vptr;
    uint32_t max_index = AXI_BRIDGE_SIZE / 4; // Maximum index for 32-bit words
    // Write data (Full interface) -> burst transfer!
    // Command
    bridge_base[bridge_32bit_index] = cmd;
    bridge_32bit_index++;
    if (bridge_32bit_index >= max_index) {
        bridge_32bit_index = 0;
    }
    // Interval (NOP)
    // Loop unrolling and NEON can be used for further speedup
    for (int i = 1; i < interval+1; i++) {
        bridge_base[bridge_32bit_index] = 0;
        bridge_32bit_index++;
        if (bridge_32bit_index >= max_index) {
            bridge_32bit_index = 0;
        }
    }
}

// Command Send
void cmd_send(uint32_t cmd, uint32_t interval) {
    // cmd_send_64bit(cmd, interval);
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

// Write Row
uint32_t write_row(uint32_t *data_buf, uint8_t bank_addr, uint32_t row_addr, uint8_t rank_addr) {
    uint32_t nck = 0;
    nck += pre(bank_addr, rank_addr, false, nRP, false);
    nck += act(bank_addr, row_addr, rank_addr, nRCD, false);
    for (int i = 0; i < 128; i++) {
        nck += wr(data_buf+i*16, bank_addr, i*8, nCCD_L, false);
    }
    return nck;
}

// Write Row
uint32_t write_row_batch(uint32_t *data_buf, uint8_t bank_addr, uint32_t row_addr, uint8_t rank_addr) {
    uint32_t nck = 0;
    nck += pre(bank_addr, rank_addr, false, nRP, false);
    nck += act(bank_addr, row_addr, rank_addr, nRCD, false);
    // Batched data transfer start
    uint32_t *ptr = (uint32_t *)udmabuf_vptr;
    for (int i = 0; i < 128; i++) {
        for (int j = 0; j < 16; j++) {
            ptr[i*16+j] = data_buf[i*16+j];
        }
    }
    dma_send_start(dma0_vptr, udmabuf_phys_addr, 16 * 128 * sizeof(uint32_t)); // Batch transfer
    // Issue WR commands
    bank_addr &= 0xF; // 4 bits
    for (int i = 0; i < 128; i++) {
        int col_addr = i*8 & 0x3FF;
        uint32_t cmd = 4 | (bank_addr << 3) | (col_addr << 7); // Write
        // Send command
        cmd_send(cmd, nCCD_L);
        nck += 1 + nCCD_L;
    }
    // Wait for DMA transfer completion
    dma_send_wait(dma0_vptr);
    return nck;
}

// Read Row
uint32_t read_row(uint32_t *data_buf, uint8_t bank_addr, uint32_t row_addr, uint8_t rank_addr) {
    uint32_t nck = 0;
    nck += pre(bank_addr, rank_addr, false, nRP, false);
    nck += act(bank_addr, row_addr, rank_addr, nRCD, false);
    for (int i = 0; i < 128; i++) {
        nck += rd(data_buf+i*16, bank_addr, i*8, nCCD_L, false);
    }
    return nck;
}

// // Read Row Batch
// uint32_t read_row_batch(uint32_t *data_buf, uint8_t bank_addr, uint32_t row_addr, uint8_t rank_addr) {
//     uint32_t nck = 0;
//     nck += pre(bank_addr, rank_addr, false, nRP, false);
//     nck += act(bank_addr, row_addr, rank_addr, nRCD, false);
//     int n_batches = 16; // the max value of n_batches is equal to the RDATA FIFO depth.
//     for (int i = 0; i < 128/n_batches; i++) {
//         // Issue RD commands
//         for (int j = 0; j < n_batches; j++) {
//             uint32_t col_addr = (i*n_batches+j)*8 & 0x3FF;
//             uint32_t rd_cmd = 3 | (bank_addr << 3) | (col_addr << 7); // Read
//             cmd_send(rd_cmd, nCCD_L);
//             nck += 1 + nCCD_L;
//         }
//         // Batched DMA transfer start
//         dma_recv(dma0_vptr, udmabuf_phys_addr, n_batches * 16 * sizeof(uint32_t)); // 512 bits * n_batches
//         // Copy data to buffer
//         memcpy(data_buf+i*n_batches*16, (uint32_t *)udmabuf_vptr, n_batches * 16 * sizeof(uint32_t)); // 512 bits * n_batches, 64 bytes * n_batches
//     }
//     return nck;
// }

// All Bank Refresh
uint32_t all_bank_refresh(uint8_t rank_addr) {
    uint32_t nck = 0;
    nck += pre(0, rank_addr, true, nRP, false); // precharge all banks
    nck += rf(nRFC, false); // refresh
    return nck;
}

// Debug GPIO
void debug_gpio() {
    uint32_t gpio_data = gpio_read(1, false);
    uint8_t cmd_fifo_count   = (gpio_data >> 16) & 0xFF;
    uint8_t wdata_fifo_count = (gpio_data >> 8)  & 0xFF;
    uint8_t rdata_fifo_count =  gpio_data        & 0xFF;
    printf("CMD FIFO Count: %u, WDATA FIFO Count: %u, RDATA FIFO Count: %u\n", cmd_fifo_count, wdata_fifo_count, rdata_fifo_count);
}
