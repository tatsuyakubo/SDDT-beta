#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#define REG_WRITE(addr, val) (*(volatile uint32_t *)(addr) = (val))
#define REG_READ(addr)       (*(volatile uint32_t *)(addr))

#define S2MM_DMACR      0x30 // Control
#define S2MM_DMASR      0x34 // Status
#define S2MM_DA         0x48 // Destination Address
#define S2MM_DA_MSB     0x4C // 32bit addressing
#define S2MM_LENGTH     0x58 // Length of the transfer

// DMA Status Check Functions

// S2MMステータスを確認して表示
void dma_s2mm_check_status(void *dma_base) {
    volatile uint8_t *base = (volatile uint8_t *)dma_base;
    
    uint32_t cr = REG_READ(base + S2MM_DMACR);
    uint32_t sr = REG_READ(base + S2MM_DMASR);
    
    printf("=== S2MM DMA Status ===\n");
    printf("DMACR: 0x%08X\n", cr);
    printf("DMASR: 0x%08X\n", sr);
    printf("\n");
    
    // DMACRビット
    printf("DMACR Bits:\n");
    printf("  Run/Stop (bit 0): %s\n", (cr & 0x01) ? "RUN" : "STOP");
    printf("  Reset (bit 2): %s\n", (cr & 0x04) ? "RESET" : "Normal");
    printf("\n");
    
    // DMASRビット
    printf("DMASR Bits:\n");
    printf("  Halted (bit 0): %d\n", (sr >> 0) & 1);
    printf("  Idle (bit 1): %d\n", (sr >> 1) & 1);
    printf("  SG_Incld (bit 2): %d\n", (sr >> 2) & 1);
    printf("  DMA Internal Error (bit 3): %d\n", (sr >> 3) & 1);
    printf("  DMA Slave Error (bit 4): %d\n", (sr >> 4) & 1);
    printf("  DMA Decode Error (bit 5): %d\n", (sr >> 5) & 1);
    printf("  IOC_Irq (bit 12): %d\n", (sr >> 12) & 1);
    printf("  Dly_Irq (bit 13): %d\n", (sr >> 13) & 1);
    printf("  Err_Irq (bit 14): %d\n", (sr >> 14) & 1);
    printf("\n");
}

// S2MMが有効かどうかを確認（戻り値: 1=有効, 0=無効）
int dma_s2mm_is_enabled(void *dma_base) {
    volatile uint8_t *base = (volatile uint8_t *)dma_base;
    uint32_t cr = REG_READ(base + S2MM_DMACR);
    
    // Run/Stopビットが1で、Resetビットが0なら有効
    return ((cr & 0x01) == 0x01) && ((cr & 0x04) == 0x00);
}

// S2MMがエラー状態かどうかを確認（戻り値: 1=エラー, 0=正常）
int dma_s2mm_has_error(void *dma_base) {
    volatile uint8_t *base = (volatile uint8_t *)dma_base;
    uint32_t sr = REG_READ(base + S2MM_DMASR);
    
    // エラービットをチェック
    return (sr & 0x38) != 0; // bits 3, 4, 5
}

// S2MMがアイドル状態かどうかを確認（戻り値: 1=アイドル, 0=動作中）
int dma_s2mm_is_idle(void *dma_base) {
    volatile uint8_t *base = (volatile uint8_t *)dma_base;
    uint32_t sr = REG_READ(base + S2MM_DMASR);
    
    return (sr & 0x02) != 0; // bit 1
}

// S2MMの完全な状態チェック（戻り値: 1=正常, 0=異常）
int dma_s2mm_check_health(void *dma_base) {
    volatile uint8_t *base = (volatile uint8_t *)dma_base;
    
    uint32_t cr = REG_READ(base + S2MM_DMACR);
    uint32_t sr = REG_READ(base + S2MM_DMASR);
    
    // Reset中でないことを確認
    if (cr & 0x04) {
        printf("ERROR: S2MM is in reset state\n");
        return 0;
    }
    
    // エラービットをチェック
    if (sr & (1 << 3)) {
        printf("ERROR: S2MM DMA Internal Error\n");
        return 0;
    }
    if (sr & (1 << 4)) {
        printf("ERROR: S2MM DMA Slave Error\n");
        return 0;
    }
    if (sr & (1 << 5)) {
        printf("ERROR: S2MM DMA Decode Error\n");
        return 0;
    }
    
    return 1; // 正常
}

// MM2Sステータスも確認する場合
void dma_mm2s_check_status(void *dma_base) {
    volatile uint8_t *base = (volatile uint8_t *)dma_base;
    
    uint32_t cr = REG_READ(base + MM2S_DMACR);
    uint32_t sr = REG_READ(base + MM2S_DMASR);
    
    printf("=== MM2S DMA Status ===\n");
    printf("DMACR: 0x%08X\n", cr);
    printf("DMASR: 0x%08X\n", sr);
    printf("\n");
    
    printf("DMACR Bits:\n");
    printf("  Run/Stop (bit 0): %s\n", (cr & 0x01) ? "RUN" : "STOP");
    printf("  Reset (bit 2): %s\n", (cr & 0x04) ? "RESET" : "Normal");
    printf("\n");
    
    printf("DMASR Bits:\n");
    printf("  Halted (bit 0): %d\n", (sr >> 0) & 1);
    printf("  Idle (bit 1): %d\n", (sr >> 1) & 1);
    printf("  DMA Internal Error (bit 3): %d\n", (sr >> 3) & 1);
    printf("  DMA Slave Error (bit 4): %d\n", (sr >> 4) & 1);
    printf("  DMA Decode Error (bit 5): %d\n", (sr >> 5) & 1);
    printf("\n");
}

// 両方のチャンネルを確認
void dma_check_all_status(void *dma_base) {
    dma_mm2s_check_status(dma_base);
    dma_s2mm_check_status(dma_base);
}

// // DMA Transfer (S2MM: Stream to Memory / Receive)
// void dma_recv(void *dma_base, unsigned long phys_addr, uint32_t length_bytes) {
//     volatile uint8_t *base = (volatile uint8_t *)dma_base;
//     // Run/Stop bit = 1
//     uint32_t cr = REG_READ(base + S2MM_DMACR);
//     REG_WRITE(base + S2MM_DMACR, cr | 1);
//     // Set destination address
//     REG_WRITE(base + S2MM_DA, phys_addr);
//     REG_WRITE(base + S2MM_DA_MSB, 0); // 32bit addressing
//     // Set length (starts transfer)
//     REG_WRITE(base + S2MM_LENGTH, length_bytes);
//     // Wait for idle (bit 1)
//     // while (!(REG_READ(base + S2MM_DMASR) & 0x02));
//     for (int i = 0; i < 1000000; i++) {
//         if (REG_READ(base + S2MM_DMASR) & 0x02) {
//             break;
//         }
//     }
//     if (!(REG_READ(base + S2MM_DMASR) & 0x02)) {
//         uint32_t status = REG_READ(base + S2MM_DMASR);
//         printf("S2MM Status: 0x%08x\n", status);
//         printf("  Idle: %d\n", (status >> 1) & 1);
//         printf("  IOC_Irq: %d\n", (status >> 12) & 1);
//         printf("  Dly_Irq: %d\n", (status >> 13) & 1);
//         printf("  Err_Irq: %d\n", (status >> 14) & 1);
//         fprintf(stderr, "DMA transfer failed\n");
//         exit(1);
//     }
// }

// DMA Transfer (S2MM: Stream to Memory / Receive) - デバッグ版
void dma_recv(void *dma_base, unsigned long phys_addr, uint32_t length_bytes) {
    volatile uint8_t *base = (volatile uint8_t *)dma_base;
    
    // 1. 初期状態を確認
    uint32_t cr = REG_READ(base + S2MM_DMACR);
    uint32_t status = REG_READ(base + S2MM_DMASR);
    printf("S2MM DMACR: 0x%08X\n", cr);
    printf("S2MM DMASR: 0x%08X\n", status);
    
    // 2. ステータスレジスタを読み取ってエラーをクリア
    (void)REG_READ(base + S2MM_DMASR);
    
    // 3. Run/Stop bitをクリア（停止状態にする）
    cr = REG_READ(base + S2MM_DMACR);
    REG_WRITE(base + S2MM_DMACR, cr & ~1); // Run/Stop bit = 0
    usleep(10);
    
    // 4. 宛先アドレスを設定
    REG_WRITE(base + S2MM_DA, phys_addr);
    REG_WRITE(base + S2MM_DA_MSB, 0);
    
    // 5. Run/Stop bitをセット（開始状態にする）
    cr = REG_READ(base + S2MM_DMACR);
    REG_WRITE(base + S2MM_DMACR, cr | 1); // Run/Stop bit = 1
    
    // 6. 設定後の状態を確認
    cr = REG_READ(base + S2MM_DMACR);
    status = REG_READ(base + S2MM_DMASR);
    printf("After setup - DMACR: 0x%08X, DMASR: 0x%08X\n", cr, status);
    
    // 7. 長さを設定（これで転送が開始される）
    REG_WRITE(base + S2MM_LENGTH, length_bytes);
    
    // 8. 設定直後の状態を確認
    status = REG_READ(base + S2MM_DMASR);
    printf("After LENGTH write - DMASR: 0x%08X\n", status);
    
    // 9. Idleビット（bit 1）がセットされるまで待つ
    uint32_t timeout = 1000000;
    uint32_t count = 0;
    while (!(REG_READ(base + S2MM_DMASR) & 0x02) && --timeout) {
        if (++count % 100000 == 0) {
            status = REG_READ(base + S2MM_DMASR);
            printf("Waiting... DMASR: 0x%08X (timeout: %u)\n", status, timeout);
        }
    }
    
    // 10. 最終ステータスを確認
    status = REG_READ(base + S2MM_DMASR);
    cr = REG_READ(base + S2MM_DMACR);
    printf("Final - DMACR: 0x%08X, DMASR: 0x%08X\n", cr, status);
    
    if (!timeout) {
        printf("DMA transfer timeout!\n");
        // エラービットを確認
        if (status & (1 << 3)) printf("  DMA Internal Error\n");
        if (status & (1 << 4)) printf("  DMA Slave Error\n");
        if (status & (1 << 5)) printf("  DMA Decode Error\n");
    } else {
        printf("DMA transfer completed.\n");
    }
}

// S2MM: Recv Start (Setup Buffer)
void dma_s2mm_start(void *dma_base, unsigned long phys_addr, uint32_t length_bytes) {
    volatile uint8_t *base = (volatile uint8_t *)dma_base;
    
    // Ensure Run/Stop bit is 1
    uint32_t cr = REG_READ(base + S2MM_DMACR);
    if (!(cr & 1)) {
        REG_WRITE(base + S2MM_DMACR, cr | 1);
    }

    REG_WRITE(base + S2MM_DA, phys_addr);
    REG_WRITE(base + S2MM_DA_MSB, 0);
    REG_WRITE(base + S2MM_LENGTH, length_bytes); // Arms the DMA
}

// S2MM: Wait
void dma_s2mm_wait(void *dma_base) {
    volatile uint8_t *base = (volatile uint8_t *)dma_base;
    uint32_t timeout = 10000000;
    uint32_t count = 0;
    
    printf("Waiting for S2MM DMA completion...\n");
    
    while (!(REG_READ(base + S2MM_DMASR) & 0x02) && --timeout) {
        if (++count % 1000000 == 0) {
            uint32_t status = REG_READ(base + S2MM_DMASR);
            uint32_t cr = REG_READ(base + S2MM_DMACR);
            printf("  Waiting... DMACR: 0x%08X, DMASR: 0x%08X (timeout: %u)\n", 
                   cr, status, timeout);
            
            // エラービットをチェック
            if (status & (1 << 3)) {
                printf("  ERROR: DMA Internal Error detected!\n");
                break;
            }
            if (status & (1 << 4)) {
                printf("  ERROR: DMA Slave Error detected!\n");
                break;
            }
            if (status & (1 << 5)) {
                printf("  ERROR: DMA Decode Error detected!\n");
                break;
            }
        }
    }
    
    uint32_t final_status = REG_READ(base + S2MM_DMASR);
    uint32_t final_cr = REG_READ(base + S2MM_DMACR);
    
    if (timeout == 0) {
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
    } else {
        printf("DMA S2MM completed successfully.\n");
        printf("Final DMACR: 0x%08X, DMASR: 0x%08X\n", final_cr, final_status);
    }
}

void dma_s2mm_detailed_status(void *dma_base) {
    volatile uint8_t *base = (volatile uint8_t *)dma_base;
    
    uint32_t cr = REG_READ(base + S2MM_DMACR);
    uint32_t sr = REG_READ(base + S2MM_DMASR);
    uint32_t da = REG_READ(base + S2MM_DA);
    uint32_t length = REG_READ(base + S2MM_LENGTH);
    
    printf("\n=== S2MM DMA Detailed Status ===\n");
    printf("DMACR: 0x%08X\n", cr);
    printf("  Run/Stop (bit 0): %s\n", (cr & 0x01) ? "RUN" : "STOP");
    printf("  Reset (bit 2): %s\n", (cr & 0x04) ? "RESET" : "Normal");
    printf("  IOC_IrqEn (bit 12): %d\n", (cr >> 12) & 1);
    printf("  Dly_IrqEn (bit 13): %d\n", (cr >> 13) & 1);
    printf("  Err_IrqEn (bit 14): %d\n", (cr >> 14) & 1);
    printf("\n");
    printf("DMASR: 0x%08X\n", sr);
    printf("  Halted (bit 0): %d\n", (sr >> 0) & 1);
    printf("  Idle (bit 1): %d\n", (sr >> 1) & 1);
    printf("  SG_Incld (bit 2): %d\n", (sr >> 2) & 1);
    printf("  DMA Internal Error (bit 3): %d\n", (sr >> 3) & 1);
    printf("  DMA Slave Error (bit 4): %d\n", (sr >> 4) & 1);
    printf("  DMA Decode Error (bit 5): %d\n", (sr >> 5) & 1);
    printf("  IOC_Irq (bit 12): %d\n", (sr >> 12) & 1);
    printf("  Dly_Irq (bit 13): %d\n", (sr >> 13) & 1);
    printf("  Err_Irq (bit 14): %d\n", (sr >> 14) & 1);
    printf("\n");
    printf("S2MM_DA: 0x%08X\n", da);
    printf("S2MM_LENGTH: %u bytes\n", length);
    printf("===============================\n\n");
}
