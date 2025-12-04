CC := gcc
CFLAGS := -Wall -O3
LDFLAGS :=

PWD  := $(shell pwd)
BIN_DIR := $(abspath $(PWD)/../../bin)

all: $(BIN_DIR)/test

test.o: test.c
	$(CC) $(CFLAGS) -c -o $@ test.c

api.o: api.c api.h
	$(CC) $(CFLAGS) -c -o $@ api.c

$(BIN_DIR)/test: test.o api.o
	mkdir -p $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

clean:
	rm -f $(BIN_DIR)/test
	rm -f $(PWD)/*.o
