# Converter production guards and retained state

`verify_converter_contracts_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Source Debug against ordinary V,
and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_converter_contracts_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The default runtime target
is `aarch64-macos.14.0`. `--timeout` bounds commands; `VTMP` selects V compiler
temporaries. The proof retains executables, every command and output, panic
snapshots, copied implementations, generated historical tests and provenance.

The converter now retains source/destination f32 alignment traps and SIMD-prefix
float-to-byte bounds checks in production. Indexed palette failures report the
Source index and active length before conversion. Dispatch still precedes
alignment: same-format calls return NoConversionNeeded, and unavailable conversions
return NoConversionAvailable. Empty owned float allocations retain Source's
misaligned sentinel. Empty views of nonempty buffers preserve their defined input
pointer; SIMD conversion checks that pointer even when no pixels are converted.

The pinned native target uses 16 byte lanes, or four pixels. SIMD float-to-byte
prefixes truncate without clamping and trap when the integer part is outside
0..255. Finite fractional values just outside 0..1 can still fit after truncation.
Scalar tails round and clamp, including negative/large values and infinities.
NaN prefixes yield zero on the pinned ARM64 compiler; scalar NaNs clamp upward.
These rules retain the existing source behavior and architecture boundary.

| Returning observations | Count |
|---|---:|
| Normalized float patterns, lengths 1..17, RGBA32/BGRA32 output | 272 |
| Fractional bounds, signed zero, NaNs and subnormals in all channels | 1,088 |
| Negative/large/infinite/NaN values confined to scalar tails | 520 |
| RGBA32/BGRA32 to float32, lengths 1..17 | 272 |
| Same/unavailable dispatch, permitted unaligned scalar paths and empty views | 54 |
| Native SIMD lane-count control | 1 |
| **Total** | **2,207** |

Returning SHA-256:
`4d268d80305ae604a4677384bdb4e952b31656e4f72db0a593afad442c5a12c4`.

Rows compare output statuses, lengths and exact pixel bytes, along with unchanged
input bytes. They cover every channel independently, both byte orders, vector
boundaries and repeated vector groups. Borrowed empty views originate from a
nonempty allocation; Source's undefined empty raw pointers are excluded.

| Strict panic/state pairs | Count |
|---|---:|
| Misaligned borrowed float data/views through all three entry points | 72 |
| Empty owned float/byte allocations with unconditional alignment casts | 12 |
| All nine inherited BGR555 inactive-union selections | 54 |
| All five indexed palette bounds through direct/image/no-free calls | 30 |
| Invalid SIMD float casts at first/final prefix pixels, in every channel | 320 |
| **Total** | **488** |

Failure-state SHA-256:
`43494aae16df032ee5d9f187007f83cbc3c51ca2659806802b1473175f823292`.

The three entry points are PixelFormatConverter.convert, ImageUnmanaged.convert
and ImageUnmanaged.convert_no_free. Snapshots compare source format/count/bytes
and active palette; image snapshots also compare dimensions, animation loop count,
frame duration and independent frame pixels. Failed conversions preserve these
public states. Inactive-union diagnostic spelling is mapped explicitly; alignment,
float-cast and palette diagnostics use matching strict prefixes. Temporary destination
allocations and partial writes within a failing vector are not observed, and
allocator effects remain outside V's GC interface.

The runner also builds the existing native converter harness unchanged. It checks
its historical 18,432-slot matrix FNV `e9de0fd7efd93e19` and 6,066,176-pixel precision
FNV `9014fb50e8722857`. Historical matrix slots include explicit markers for skipped
trap pairs; those markers are not new returning observations. RGB555 padding is
masked and indexed widening comparisons retain their historical palette scope.

For V, the runner copies all top-level implementation/header files unchanged into
an isolated module and extracts the two historical test functions and their helpers.
It inserts output of their computed counts/hashes before the existing assertions,
then checks those outputs independently in both modes. This ensures production
verification does not depend on V test assertions. The copied implementations and
original/generated fixtures are hashed before and after execution.

The earlier pixel-view and PNG decoder/processor proofs retain their hashes.
Source visibility and implementations remain unchanged. Allocator/OOM/GC/lifetime,
private failed destination state, align(1) allocator choices, undefined raw-empty
pointers, narrow/const carriers, wider allocated extents and arbitrary SIMD targets
remain boundaries. Cross-target compilation does not establish runtime parity.

The runner verifies full Source-tree SHA-256
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`, selected Zig
library SHA-256
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`, compiler
versions (Zig 0.15.2 and V 0.5.2), and fixture/runner/implementation hashes.
