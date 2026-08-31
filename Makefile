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

# llvm.wasm is a multicall LLVM build: the tool comes first in argv
WASMPATH=./wasm
WASMCC=$(ENG) $(WASMPATH)/llvm.wasm $(SEP) clang
WASMLD=$(ENG) $(WASMPATH)/llvm.wasm $(SEP) wasm-ld
WASM2WAT=$(ENG) $(WASMPATH)/wasm2wat.wasm $(SEP)
WAT2WASM=$(ENG) $(WASMPATH)/wat2wasm.wasm $(SEP)
WASM3=$(ENG) ./wasm3.wasm $(SEP)

# libc headers live in the target subdirectory, clang's builtins one level up
CC=$(WASMCC) -cc1 -triple wasm32-unknown-wasip1 -isysroot /sys \
   -internal-isystem /sys/include/wasm32-wasip1 -internal-isystem /sys/include -emit-obj
# clock() is opt-in emulation in wasi-libc, and __multi3 comes from compiler-rt
LD=$(WASMLD) -L/sys/lib/wasm32-wasip1 -L/sys/lib/wasm32-unknown-wasip1 \
   /sys/lib/wasm32-wasip1/crt1.o -lc -lwasi-emulated-process-clocks -lclang_rt.builtins

# The interpreter dispatches, calls and returns through musttail, which Clang only
# accepts with the tail-call feature. The rest matches Wasm3's own CMake WASI build.
# -cc1 spells features out; the driver would take -mtail-call and friends.
FEATURES=-target-feature +tail-call -target-feature +bulk-memory \
         -target-feature +nontrapping-fptoint -target-feature +sign-ext \
         -target-feature +multivalue -target-feature +mutable-globals

CFLAGS=-Dd_m3HasMetaWASI -D_WASI_EMULATED_PROCESS_CLOCKS -O3 $(FEATURES)
LDFLAGS=-O3 -s -z stack-size=8388608

SRCS := $(wildcard ./source/wasm3/*.c)
DEPS := $(wildcard ./source/wasm3/*.h)
OBJS := $(patsubst %.c,%.o,$(SRCS))

.PHONY: all clean test

all: wasm3.wasm hello.wasm test

clean:
	find ./source \( -name '*.o' -or -name '*.tmp' \) -type f -delete
	rm -f *.wasm

test: wasm3.wasm hello.wasm
	@out=$$($(WASM3) --version); echo "$$out"; \
	  echo "$$out" | grep -q "self-hosting" || { echo "not running inside Wasm3"; exit 1; }; \
	  echo "$$out" | grep -q "tail-call"    || { echo "built without tail calls"; exit 1; }
	@out=$$($(WASM3) hello.wasm); echo "$$out"; \
	  echo "$$out" | grep -q "Hello from WebAssembly" || { echo "hello.wasm did not run"; exit 1; }

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
