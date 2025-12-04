CC := gcc
CFLAGS := -Wall -O3
LDFLAGS :=

PWD  := $(shell pwd)
BIN_DIR := $(abspath $(PWD)/../../bin)

all: $(BIN_DIR)/tiny_test $(BIN_DIR)/small_test

$(BIN_DIR)/tiny_test: tiny_test.o utils.o api.o
	mkdir -p $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

$(BIN_DIR)/small_test: small_test.o utils.o api.o
	mkdir -p $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

clean:
	rm -f $(BIN_DIR)/test
	rm -f $(PWD)/*.o
