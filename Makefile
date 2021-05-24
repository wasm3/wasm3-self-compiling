ENGINE ?= wasm3

# Works
ifeq ($(ENGINE),wasm3)
	ENG=./bin/wasm3
endif

# Works, but takes quite some time. Covered by https://github.com/nodejs/node/issues/36671
ifeq ($(ENGINE),nodejs)
	ENG=wasm-run
	SEP=--
endif

ifeq ($(ENGINE),wasmtime)
	ENG=wasmtime run --allow-unknown-exports --mapdir=/::. --mapdir=./::.
	SEP=--
endif

# Compiling: unable to rename temporary. Covered by https://github.com/wasmerio/wasmer/issues/2297
# Linking:   Works
ifeq ($(ENGINE),wasmer)
	ENG=wasmer run --mapdir=/:. --mapdir=./:.
	SEP=--
endif

# Compiling: fails on some WASI syscalls. Covered by https://github.com/WAVM/WAVM/issues/155
ifeq ($(ENGINE),wavm)
	export WAVM_OBJECT_CACHE_DIR=./tmp/cache
	ENG=wavm run --mount-root .
endif

WASMPATH=./wasm
WASMCC=$(ENG) $(WASMPATH)/clang.wasm $(SEP)
WASMLD=$(ENG) $(WASMPATH)/wasm-ld.wasm $(SEP)
WASM2WAT=$(ENG) $(WASMPATH)/wasm2wat.wasm $(SEP)
WAT2WASM=$(ENG) $(WASMPATH)/wat2wasm.wasm $(SEP)
WASM3=$(ENG) ./wasm3.wasm $(SEP)

CC=$(WASMCC) -cc1 -triple wasm32-unknown-wasi -isysroot /sys -internal-isystem /sys/include -emit-obj
LD=$(WASMLD) -L/sys/lib/wasm32-wasi /sys/lib/wasm32-wasi/crt1.o -lc

CFLAGS=-Dd_m3HasMetaWASI -O3
LDFLAGS=-O3 -s

SRCS := $(wildcard ./source/wasm3/*.c)
DEPS := $(wildcard ./source/wasm3/*.h)
OBJS := $(patsubst %.c,%.o,$(SRCS))

.PHONY: all clean test

all: wasm3.wasm hello.wasm test

clean:
	find ./source \( -name '*.o' -or -name '*.tmp' \) -type f -delete
	rm -f *.wasm

test: wasm3.wasm hello.wasm
	$(WASM3) hello.wasm

%.wat: %.wasm
	@echo "Generating $@"
	@$(WASM2WAT) $^ > $@

%.o: %.c $(DEPS)
	@echo "Compiling $<"
	@$(CC) -o $@ $< $(CFLAGS)

bin/wasm3:
	@echo "Building native $@"
	@gcc -DASSERTS -Dd_m3HasWASI \
		-I./source/wasm3 ./source/wasm3/*.c \
		-O3 -g0 -s -flto -lm -static -o $@

wasm3.wasm: $(OBJS)
	@echo "Linking $@"
	@$(LD) -o $@ $^ $(LDFLAGS)

hello.wasm: source/hello/hello.o
	@echo "Linking $@"
	@$(LD) -o $@ $^ $(LDFLAGS)
