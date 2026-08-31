# wasm3-self-compiling

Wasm3 compiling itself: `clang` and `wasm-ld` run **inside** Wasm3 and build Wasm3
from source.

```sh
make bin/wasm3     # the host engine, built natively from source/wasm3
make               # compiles wasm3.wasm with itself, then runs it
```

```
Wasm3 v0.9.1-beta.1 self-hosting on x86_64
Build: ..., Clang 19.0.0, tail-call, multi-memory
Hello from WebAssembly!
```

Any Wasm3 build can be the host — drop one into `./bin/` instead of step one.
Running a deeply nested module through `wasm3.wasm` needs more Wasm stack than the
64 KB default, e.g. `./bin/wasm3 --stack-size 2097152 ./wasm3.wasm module.wasm`.

## Toolchain

`wasm/llvm.wasm` is LLVM 19 for `wasm32-wasip1` from [YoWASP/clang](https://github.com/YoWASP/clang) by whitequark.  
`llvm.wasm` is a multicall binary, so the tool comes first in argv:
```sh
wasm3 llvm.wasm clang ...
wasm3 llvm.wasm wasm-ld ...
```
Compilation goes through `-cc1` because a Wasm module cannot spawn the subprocess the driver would use.

