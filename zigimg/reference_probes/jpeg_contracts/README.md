# JPEG checked decoder and Huffman borrowing

`verify_jpeg_contracts_reference.py` compares the translated JPEG implementation
with unchanged zigimg `d7b7ab0ba0899643831ef042bd73289510b39906`. It runs Source
Debug against ordinary V, and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_jpeg_contracts_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and a different empty directory. The default target is
`aarch64-macos.14.0`; `--target` selects another target. Cross-target compilation
alone does not certify runtime behavior. `--timeout` limits builds and returning
processes; inherited discard loops always use separate half-second timeouts.

The runner pins the full Source `src` tree, compiler versions, and the selected
Zig memory, debug, reader, writer, file-reader and array-hash-map sources. It copies
Source unchanged, imports JPEG support files through their existing public APIs,
and does not widen private declarations. It retains all commands, inputs, raw
output, diagnostics, panic-observer files, provenance and a result summary.
Before/after checks protect Source, compiler-library files, probe fixtures, the
runner, historical JPEG inputs and the V image implementation.

| Returning observations | Count |
|---|---:|
| Frame headers, component validation and sampling projections | 4,600 |
| JFIF headers, error order, truncation and positions | 677 |
| Quantization tables, both precisions and truncation | 1,032 |
| Huffman tables, canonical maps, acceleration tables and truncation | 1,056 |
| Huffman reader operations, mutable state, byte stuffing and restart markers | 7,946 |
| Caller mutations through borrowed Huffman-table pointers | 80 |
| Defined complete decoding, error cleanup, historical inputs and empty images | 414 |
| **Total** | **15,805** |

Returning SHA-256:
`c351ba2c35413cc9ff5951a77206a0b6aa3ed55f9a495d6c4f94505e5caa7ae4`.

Thirty isolated failures require the exact Source panic category in both
languages and identical retained stream positions or Huffman buffer/count/position
state. They cover invalid marker/density enums; segment underflow; DRI arithmetic
before its invariant; late frame/scan length invariants; table destination/selector
bounds; missing AC/Huffman tables; u5 input casts; bit-fill arithmetic before and
after the buffer update; consumption invariants; inactive q8 union access; and
defined dequantization/IDCT integer overflow.

Retained failure-state SHA-256:
`d7ddad1f92a7f409a59c64e289a68f9084f8590666d99563990a07640d9c402e`.

Three paired bounded processes cover JFIF files ending before the NUL byte, using
16/31/4096-byte buffers. The pinned positional file reader repeatedly discards
zero bytes at EOF; V preserves that inherited loop. It is excluded from returning
cases. Complete and omitted-stream Huffman reader constructors respectively build
and run, or receive ordinary compiler rejections, in both languages. Crash, signal,
backend and linker failures cannot satisfy the rejection gate.

The separate Source `quantization.Header.read` helper fails to compile under Zig
0.15.2: it assigns an inferred u8 value to `table_precision: u4`. An ordinary
compiler rejection verifies this inherited boundary. Two V helper controls run
separately; they are not native-equivalence observations. The actual JPEG decoder
uses its own compiling table parser and is covered by the comparison.

The historical Pillow-generated matrix can also retain its commands and files:

```sh
python3 zigimg/verify_jpeg_reference.py --source /path/to/locked-zigimg \
  --zig /path/to/zig-0.15.2/zig --v /path/to/v-0.5.2 \
  --workdir /path/to/another-empty-directory
```

Repeat with `--v-prod`. Both modes retain 132 matching returning rows. Seven
progressive/subsampled inputs encounter Source arithmetic traps while reading
undefined coefficient storage and remain excluded. The eighth former exclusion,
`31x17-RGB-0-2-1.jpg`, is a defined marker failure; its exact enum panic and any
preceding completed output now match in V. The historical runner rejects other
unexpected Source terminations instead of counting them as checked failures.

These comparisons do not certify allocator/OOM/lifetime behavior, undefined
coefficient storage, every JPEG record constructor or public Frame method, packed
ABI, const typing, arbitrary CPU SIMD selection, or wider V backing-field values.
The reader exposes one borrowed ReadStream pointer in place of Source's separate
reader/stream pointers. Source u5 fields use byte carriers, and Huffman keys use
u32 packed pairs and a V map. The later [public record proof](../jpeg_records/README.md)
restores required mutable headers/tables and tagged quantization arms, measuring
boxed payload-copy, const-slice and wider-carrier differences separately. Callers
must keep borrowed tables and streams alive. JPEG's source no-op writer remains
unchanged.
