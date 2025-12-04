CC := gcc
CFLAGS := -Wall -O3
LDFLAGS :=

PWD  := $(shell pwd)
BUILD_DIR := $(abspath $(PWD)/../../build)

test: test.c
	@mkdir -p $(BUILD_DIR)
	@cp -f $(PWD)/test.c $(BUILD_DIR)/
	@$(CC) $(CFLAGS) -o $(BUILD_DIR)/test $(BUILD_DIR)/test.c $(LDFLAGS)
