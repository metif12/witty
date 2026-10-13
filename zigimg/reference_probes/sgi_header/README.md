# SGI parsed-header validation and buffered decoding

`verify_sgi_header_reference.py` compares unchanged pinned zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Source Debug against ordinary V,
and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_sgi_header_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and a separate empty directory. The default runtime target
is native little-endian `aarch64-macos.14.0`. Each command has a configurable
timeout. Artifacts retain source copies, binaries, corpus, all commands/output,
public panic snapshots, provenance and a summary. Compiler temporaries and caches
belong to the proof directory.

On little-endian targets, Source's big-endian `takeStruct` validates compression,
dimension and pixel-format enums through `std.mem.byteSwapAllFields`. The complete
510-byte header is consumed before validation, and the codec's previous header
remains intact on failure. V previously cast all three fields unsafely and could
return success or Unsupported. It now preserves Source's exact `invalid enum value`
trap and order in ordinary and production builds. A bad magic number or incomplete
header still returns its earlier error; valid unsupported tags still return
Unsupported after replacing the header. Valid decoding is unchanged.

| Returning records | Count |
|---|---:|
| Fully written raw/RLE decoding | 4,320 |
| Repeated RLE row packets | 240 |
| Every valid enum combination and dispatch | 360 |
| Incomplete invalid headers and retries | 255 |
| Wrong magic before enum validation | 10 |
| Raw byte prefixes and retries | 5,480 |
| Incomplete RLE headers/tables and complete packet prefixes | 2,815 |
| **Total** | **13,480** |

These records contain **22,040 read attempts**. Output SHA-256 in both modes:
`7cc1b4dea92da390d91a189476efabbfbae527584ffab6f7e27a6dad8f231e5e`.

Each input runs with memory and file-buffer capacities 510/511/512/1024. Fully
written cases cover grayscale8 with one/two-byte channels, RGB24/RGBA32 and
RGB48/RGBA64, widths 0/1/3/7/17/63, heights 0/1/2/3, three byte patterns, raw and
literal RLE, reversed packet storage and trailing bytes. Repeated packets cover
nonzero widths 1/3/17/63 and heights 1/2. Source consumes all compressed input
before decoding its tables, flips rows, ignores high command bytes and retains
its unusual grayscale/16-bit alpha behavior. Successful pixel bytes are complete.

All 2×3×4 valid enum combinations run with bytes-per-channel 1/2/255 and zero
extents, so unusual supported dispatch does not expose unwritten storage. Partial
invalid headers cover fields already present in the prefix through one byte short
of completion. Retries compare retained codec/stream state. RLE prefixes stop
before complete tables or include every complete packet; successful RLE inputs
that leave private pixels unwritten are excluded. Compiled unchanged Source alone
supplies expected decoder output.

| Exact invalid-enum panic/state pairs | Count |
|---|---:|
| Every invalid u8 compression tag | 254 |
| Invalid dimension low-byte values and u16/endian boundaries | 269 |
| Invalid pixel-format low-byte values and u32/bit boundaries | 282 |
| File-buffer controls for each field | 44 |
| Simultaneous invalid fields, including large channel products | 90 |
| Validation before unsupported dispatch, products, tables or body EOF | 25 |
| **Total** | **964** |

Failure-state SHA-256:
`b04edf68a65629c73690152f3d022603dc28f2198ee9da27cf2cb51f625a6312`.

The memory sweep covers compression 2..255, dimension 0/4..255 plus selected
u16/endian boundaries, and pixel format 4..255 plus every individual high bit and
selected u32 boundaries. File controls use all four buffer capacities. Simultaneous
and precedence failures also run in memory. Strict checks require the exact sole
panic message, unsuccessful exit, no stdout/unexpected return and disabled core
dumps. Snapshots compare the complete initialized previous header, all 256 caller
palette backing entries, active palette length, logical input position, buffered
length and every caller buffer byte initialized to 165. Returned records use the
same snapshot and additionally compare all successful pixel bytes. Private failed
pixel/table/data allocations and freed storage remain excluded.

The previous 795 returning and 636 arithmetic/bounds panic/state observations
retain all hashes in both modes. Two module regressions cover file-buffered raw/
RLE planes and magic/incomplete-header precedence. All 61 image and 58 Vaxis test
files pass, with 17 production/platform checks. Cross-target compilation does not
establish runtime parity. The first fixture attempt captured a fixed V array
through a generic value parameter; its mismatch is retained separately. The
corrected pre-fix batch matched all returns before the first invalid compression
case returned success in V while Source trapped. Completed proofs use frozen
implementation, fixtures and inputs.

The runner verifies full Source-tree SHA-256
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`, selected Zig
library SHA-256
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`, Zig 0.15.2,
V 0.5.2, and before/after fixture, runner, helper, implementation and corpus hashes.
The private Source header type is inferred through its public codec field; Source
visibility and bodies remain unchanged. GC replaces explicit allocator parameters.

Big-endian runtime, manually corrupted typed enums, Source's undefined default
header, successful RLE inputs with unwritten pixels, word reads outside physical
byte allocations, buffers below the 510-byte header requirement, streaming/
nonseekable/custom readers, allocator/OOM/GC/lifetime, arbitrary larger extents,
const/enum/narrow typing, pointer/slice layout and portable ABI remain boundaries.
The earlier [SGI contract proof](../sgi_contracts/README.md) separately covers RLE
arithmetic, source/destination bounds and direct caller output, including malformed
packets that can be observed without exposing undefined Source storage.
