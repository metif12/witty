# IFF chunk traversal and RGB/HAM decoding contracts

`verify_iff_pixels_reference.py` compares the unchanged pinned zigimg source
`d7b7ab0ba0899643831ef042bd73289510b39906`: Source Debug against ordinary V and
Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_iff_pixels_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and a different empty directory. Runtime comparisons use
native 64-bit little-endian `aarch64-macos.14.0` by default. `--timeout` bounds
commands; `TMPDIR` and `VTMP` select compiler temporaries. Artifacts retain the
full imported Source, binaries, commands, outputs, inputs, snapshots, fixture/
runner/implementation hashes and compiler/library provenance.

The pixel decoder keeps the zero-pitch assertion before format selection, header
arm access or input. Palette extension/reduction still follows decompression and
planar conversion. EHB expansion precedes HAM reduction when its active-palette
condition holds. RGB's u8 padding subtraction retains overflow before row loops,
including empty images; HAM's truncated palette divisor retains division by zero.
RGB/HAM chunky indices retain exact bounds before narrowing to V array indices.
The Source row reset, previous-color updates, component truncation and direct
24-plane RGB branch remain unchanged. Allocated pixel/palette results remain
independent of caller input and the codec palette after mutation.

The shared PackBits decoder checks each destination before consuming a literal
byte and after consuming a repeated value, preserving exact overrun diagnostics
and read order in ordinary and production builds. Its declared-length early
success, no-op controls and partial-buffer behavior are unchanged. IFF's ACBM
compression tag still selects raw reading rather than PackBits. Raw and ByteRun2
body paths ignore declared chunk lengths; direct pixel decoding ignores chunk ID.

Traversal consumes complete chunk headers, honors the pinned seek-to-end rejection,
ignores FORM length and CAMG declared length, and does not add odd-chunk padding
or consume CMAP remainders. Repeated palettes, unknown chunks, BODY/ABIT dispatch,
prefix failures and nonzero initial cursors keep Source's retained state. The
explicit zero-end guard represents Source's checked u64 subtraction; that branch
cannot be reached by the compared fixed-memory streams after a complete chunk.
File/cache/streaming behavior is outside this proof.

The model partitions defined returns/errors and strict failures only; compiled,
unchanged Source supplies every compared output and snapshot. Caller codec header
and scalar fields and all 256 palette backing entries are initialized before its
active view is shortened. Only active palette bytes are observed. Results compare
pixel/palette bytes before and after mutation, reader cursor, caller codec state
and unchanged input. Default readImage's private codec state is excluded. No
empty pointer identities, failed private storage, freed bytes or inactive backing
are observed.

Both modes match **18,248 returning/error records**:

| Returning records | Count |
|---|---:|
| All representable HAM6/HAM8 indices across bit/palette choices | 13,760 |
| Returning RGB padding-bit domain | 9 |
| HAM reduction and EHB precedence controls | 666 |
| HAM previous-color updates and row reset | 640 |
| Format/compression/viewport dispatch | 468 |
| EHB/HAM palette and index boundaries | 280 |
| Public raw/PackBits/ByteRun2 reads | 396 |
| Body prefixes and completed controls | 688 |
| Returning failure-precedence controls | 12 |
| Public HAM/EHB reads with defined palette backing | 612 |
| Ignored direct chunk IDs and raw lengths | 20 |
| Defined PackBits length/control boundaries | 85 |
| Chunk lengths, types, trailing bytes and dispatch | 468 |
| Chunk prefix/order/remainder controls | 104 |
| Nonzero initial cursors | 40 |
| **Total** | **18,248** |

Return SHA-256: `72ba805b4d37c4c51ba1f75703c63a514cdb1cef621227beac12a209047e450b`.

**1,561 exact panic/state pairs** cover 973 arithmetic failures, 243 assertions/
unreachable failures, 228 bounds failures, 101 zero-divisor failures and sixteen
wrong-header-arm accesses. They require an exact panic, unsuccessful exit, no
stdout, complete matching snapshot and no core dump. Names, exact diagnostics,
cursor, initialized public codec/header fields, active palette and unchanged
input join SHA-256
`848258baaaf14b0ec8c50981c29e19c2a7af845961039f077db65da397e0fdb5`.

Successful partial PackBits output can expose Source's uninitialized private plane
buffer; those cases are excluded. Default readImage EHB expansion before 32 base
colors are initialized is also excluded. The translation retains V's initialized
allocation behavior rather than claiming parity for undefined Source bytes.
The excluded-input controls count 37 cases in each category and are locked
separately from returning/failure parity records.

Allocation failure/OOM/GC/lifetime, readonly/narrow V typing, boxed header copies,
physical slice/record/sum layout, extents beyond V array limits, file streams,
logger presentation, big-endian runtime and portable ABI remain boundaries.
Cross compilation establishes build coverage only. Unreachable storage/format
branches have explicit traps but no manufactured runtime coverage.

Full Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`; math.zig
SHA-256 is `65645001357d5f78cbf646485e009a048b828680bb1b47fb3de0fd8617d91af1`.
Zig 0.15.2/V 0.5.2 versions and before/after source/library/fixture/input/runner/
implementation checks protect the retained proof artifacts. Source visibility
and implementation are unchanged.
