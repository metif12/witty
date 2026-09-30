This is an incremental V translation of zigimg revision
`d7b7ab0ba0899643831ef042bd73289510b39906`, the dependency locked by pinned
vaxis. It currently covers the pixel-format words, storage variants, raw and
indexed storage, memory streams, QOI and farbfeld codecs, and the pinned PNG
writer. It does not yet provide the complete image library or vaxis loading.

The PNG writer in this exact revision emits only the eight-byte signature;
its chunk-writing bodies are commented out. Native reference execution and V
tests preserve that behavior, including fixed-buffer failures.

V arrays and GC replace allocator slices. Sub-byte scalar values use byte
storage or packed backing words. Allocation errors, every color conversion
method, file/bit streams, decoding other formats, format dispatch, and the
remaining managed image APIs still require translation.

Run the V checks with the repository's pinned compiler:

```sh
VEXE=/Users/alex/.cache/v/v1-fallback/0.5.2/v \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v test zigimg
```

The standalone reference harness accepts the unmodified dependency as a Zig
module. With Zig 0.15.2 on macOS, a 14.0 target avoids linking against an SDK
version newer than that compiler supports:

```sh
zig run -target aarch64-macos.14.0 -lc --dep zigimg \
  -Mroot=zigimg/verify_reference.zig \
  -Mzigimg=/path/to/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906/zigimg.zig
```
