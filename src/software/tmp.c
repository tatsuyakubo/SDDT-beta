#include <stdio.h>
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

    // // Original
    // uint32_t *ptr = (uint32_t *)udmabuf_vptr;
    // for (int i = 0; i < 16; i++) {
    //     ptr[i] = buffer[i];
    // }
    // dma_send(dma0_vptr, udmabuf_phys_addr, 16 * sizeof(uint32_t)); // 512 bits, 64 bytes

    // GPIO
    gpio_write(2, buffer[0], false);

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

void debug_gpio() {
    uint32_t gpio_data = gpio_read(1, false);
    printf("gpio 1 data: %d\n", gpio_data);
}

int main(int argc, char *argv[]) {
    if (setup_hardware() != 0) return -1;
    printf("Hardware mapped successfully.\n\n");

    int bank_addr = 0;
    int row_addr = 0;
    int col_addr = 0;
    uint32_t cmd = 0;

    // gpio_write(2, 0x12345678, false);

    // Write col = 0
    pre(bank_addr, 0, 0, 9, 0);
    act(bank_addr, row_addr, 0, 9, 0);

    // cmd = 4 | (bank_addr << 3) | (col_addr << 7); // Write
    // cmd_send(cmd, 9);
    uint32_t write_buffer[16] = {0x12345878};
    wr(write_buffer, bank_addr, col_addr, 9, 0);

    // Read col = 0
    pre(bank_addr, 0, 0, 9, 0);
    act(bank_addr, row_addr, 0, 9, 0);
    cmd = 3 | (bank_addr << 3) | (col_addr << 7); // Read
    cmd_send(cmd, 9);

    // Receive data
    int n_words = 16;
    uint32_t read_buffer[n_words];
    dma_recv(dma0_vptr, udmabuf_phys_addr, n_words * sizeof(uint32_t)); // 512 bits
    // Copy data to buffer
    memcpy(read_buffer, (uint32_t *)udmabuf_vptr, n_words * sizeof(uint32_t)); // 512 bits, 64 bytes
    for (int i = 0; i < n_words; i++) {
        printf("%08x ", read_buffer[i]);
    }
    printf("\n");
    printf("\n");

    debug_gpio();

    cleanup_hardware();
    return 0;

    // Receive data and print
    // Set data1
    uint32_t write_buffer1[16] = {1, 3};
    uint32_t *ptr = (uint32_t *)udmabuf_vptr;
    for (int i = 0; i < 16; i++) {
        ptr[i] = write_buffer1[i];
    }
    dma_send(dma0_vptr, udmabuf_phys_addr, 16 * sizeof(uint32_t)); // 512 bits, 64 bytes

    // Set data2
    uint32_t write_buffer2[16] = {3, 4};
    for (int i = 0; i < 16; i++) {
        ptr[i] = write_buffer2[i];
    }
    dma_send(dma0_vptr, udmabuf_phys_addr, 16 * sizeof(uint32_t)); // 512 bits, 64 bytes

    debug_gpio();

    pre(bank_addr, 0, 0, 9, 0);
    act(bank_addr, row_addr, 0, 9, 0);
 
    // Read col = 0
    bank_addr = 0;
    col_addr = 0;
    bank_addr &= 0xF; // 4 bits
    col_addr &= 0x3FF; // 10 bits
    cmd = 3 | (bank_addr << 3) | (col_addr << 7); // Read
    cmd_send(cmd, 9);

    debug_gpio();

    debug_gpio();

    cleanup_hardware();
    return 0;
}
