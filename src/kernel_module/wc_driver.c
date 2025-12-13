#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/fs.h>
#include <linux/mm.h>
#include <linux/cdev.h>

#define DRIVER_NAME "bridge_wc"
#define BRIDGE_PHY_ADDR 0xB0000000  // Address of Bridge in the hardware
#define BRIDGE_SIZE     0x00010000  // Size of Bridge (64KB)

static int major_num; // Major number of the driver

// Function called when mmap is called
static int bridge_mmap(struct file *filp, struct vm_area_struct *vma) {
    unsigned long size = vma->vm_end - vma->vm_start;
    unsigned long pfn = BRIDGE_PHY_ADDR >> PAGE_SHIFT;

    if (size > BRIDGE_SIZE) {
        return -EINVAL;
    }

    // Change memory attribute to "Write Combining"
    vma->vm_page_prot = pgprot_writecombine(vma->vm_page_prot);

    // Map physical address to user space
    if (remap_pfn_range(vma, vma->vm_start, pfn, size, vma->vm_page_prot)) {
        return -EAGAIN;
    }
    
    return 0;
}

static const struct file_operations fops = {
    .owner = THIS_MODULE,
    .mmap = bridge_mmap, // Register mmap handler
};

static int __init mod_init(void) {
    major_num = register_chrdev(0, DRIVER_NAME, &fops);
    if (major_num < 0) return major_num;
    printk(KERN_INFO "Bridge WC driver loaded. Major: %d\n", major_num);
    return 0;
}

static void __exit mod_exit(void) {
    unregister_chrdev(major_num, DRIVER_NAME);
}

module_init(mod_init);
module_exit(mod_exit);
MODULE_LICENSE("GPL");
