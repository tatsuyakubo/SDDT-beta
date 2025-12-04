obj-m += wc_driver.o

KDIR ?= /lib/modules/$(shell uname -r)/build
PWD  := $(shell pwd)
BUILD_DIR := $(abspath $(PWD)/../../build)
LOCALVERSION := "-gfc1c20f0a1a9"

wc_driver:
	@mkdir -p $(BUILD_DIR)
	@cp -f $(PWD)/wc_driver.c $(BUILD_DIR)/
	@echo "obj-m += wc_driver.o" > $(BUILD_DIR)/Makefile
	@$(MAKE) ARCH=arm64 CC=gcc-12 -C $(KDIR) M=$(BUILD_DIR) LOCALVERSION=$(LOCALVERSION) modules
