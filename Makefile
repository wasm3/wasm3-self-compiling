ENGINE=./bin/wasm3

WASMCC=$(ENGINE) ./wasm/clang.wasm
WASMLD=$(ENGINE) ./wasm/wasm-ld.wasm
WASM2WAT=$(ENGINE) ./wasm/wasm2wat.wasm
WAT2WASM=$(ENGINE) ./wasm/wat2wasm.wasm

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
	$(ENGINE) wasm3.wasm hello.wasm

%.wat: %.wasm
	@echo "Generating $@"
	@$(WASM2WAT) $^ > $@

%.o: %.c $(DEPS)
	@echo "Compiling $<"
	@$(CC) -o $@ $< $(CFLAGS)

wasm3.wasm: $(OBJS)
	@echo "Linking $@"
	@$(LD) -o $@ $^ $(LDFLAGS)

hello.wasm: source/hello/hello.o
	@echo "Linking $@"
	@$(LD) -o $@ $^ $(LDFLAGS)
