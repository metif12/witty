# IFF required chunks, checked headers and palette failure state

`verify_iff_records_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Source Debug against ordinary V,
and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_iff_records_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The default runtime target is
native 64-bit little-endian `aarch64-macos.14.0`. `--timeout` bounds commands;
`VTMP` and `TMPDIR` can select compiler temporaries. Artifacts retain binaries,
commands, outputs, generated input/consumer hashes, snapshots and provenance.

Chunk and ChunkHeader require both fields. Chunk initialization retains the
four-byte assertion in production. Little-endian BMHD reads validate both enums
while swapping a completely consumed header, before assignment to the codec.
Wrong-header access retains Source's exact union-field diagnostic; HAM format
selection still short-circuits before accessing the BMHD arm.

CMAP capacity checks precede resize/input and preserve the requested slice-end
and length. Empty CMAP resizes the active palette to zero before its ceil-log2
assertion. Partial CMAP input commits complete RGB entries only, retains the
expanded active view and leaves the previous cmap_bits until every color succeeds.
HAM reduction checks both u8 operations before its minimum-bit assertion and
updates public state only after the successful resize. Right shifts truncate to
native usize shift width, retaining cases such as a resulting bit count of 64.

| Returning records | Count |
|---|---:|
| Initialized header-arm dimensions | 32 |
| Every plane count, both header arms and viewport precedence | 2,048 |
| Valid parsed mask/compression/plane controls | 240 |
| Incomplete malformed headers before enum checking | 136 |
| Chunk ID/length validation before malformed enums | 16 |
| Header loading over all five format tags, including the DEEP stub | 11 |
| Format detection/peek/take and wrong magic | 432 |
| Four-byte chunk borrowing/copies and valid length controls | 258 |
| CAMG prefixes, trailing data and initial cursors | 12 |
| CMAP lengths, partial entries, remainders and capacity controls | 170 |
| EHB expansion from initialized backing storage | 7 |
| Every u8 HAM bit/plane pair that returns | 64,021 |
| Additional active-palette lengths and truncated-shift boundaries | 804 |
| Public header reads, width/pitch boundaries and short chunk lists | 126 |
| Fully defined ILBM/ACBM/PBM public decoding controls | 296 |
| Native record sizes/constants/flags and live header-name view | 15 |
| **Total** | **68,624** |

Record SHA-256: `6cc1394883088df0aec445e92cbcb2da901e34d07b5fb11d47d968ecd6bea7ab`.
Header/palette/control SHA-256: `162b7a0ebf1e170cff5bfbee121a5a425d629dfa67307d8d496033eb1a7907a3`.

**4,449 strict panic/state pairs** cover 2,040 parsed enum failures, 1,184 checked
assertions, 659 u8 arithmetic failures, 518 wrong header-arm failures and 48
palette-capacity slice failures. Exact diagnostics, unsuccessful exit, no stdout,
no unexpected return and no core dump are required. Case names, diagnostics,
reader cursors, initialized header/scalar codec fields, active palette bytes and
unchanged input join SHA-256 `2a7fb4333d9a2214a69aefd5cd60bd4cc0db24db1b9a134aa2ca913d2a363b0a`.

All 256 inline palette entries are initialized through public slices before the
initial active view is shortened. Resizing or extending later therefore exposes
fully defined data; inactive bytes are never observed. Public decode results
compare independently allocated pixel/palette bytes before/after mutation and
unchanged input/codec palette. Private failed/freed storage is excluded. Private
codec state is also excluded for the default readImage entry point. No empty
pointer identities are compared. BMHD/DGBL fields are fully initialized and have
no uninitialized padding in the compared native layouts.

Two complete chunk constructors, four field omissions and the three default
record/codec constructions pass Source/V compiler controls. Two separate compiler
controls record Source's const slice-element rejection and V's mutable byte-view
acceptance for chunk names and the header-name view. Caller mutation and scalar
copy behavior match. A separate runtime control records copied sum payloads
sharing storage in V (`9|9`) while Source copies the header payload by value
(`7|9`). These adaptations are excluded from the returning parity count.

DEEP header decoding remains a no-input zero-header stub. Declared FORM length,
CMAP remainders, CAMG declared length, native-endian live ChunkHeader names, the
DBGL constant spelling, EHB alpha and palette replacement/reduction order remain.
All native imports retain Source visibility and implementation.

This checkpoint covers header/record/palette contracts and bounded defined public
reads. The later [planar/ByteRun2 checkpoint](../iff_planar/README.md) covers those
direct conversion and RLE contracts. Chunk traversal and RGB/HAM conversion
arithmetic/bounds/production checks remain separate work. Default Source codec
header/format fields and inactive palette storage are undefined and unobserved.
Allocator/OOM/GC/lifetime, const/narrow typing, boxed copies, physical chunk/sum/
slice layout, wider allocated extents, file streams, debug-logger presentation,
big-endian runtime and portable ABI remain boundaries. Native layout observations
do not establish portable layout; cross compilation does not prove runtime parity.

Full Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`. The additionally
pinned math.zig SHA-256 is
`65645001357d5f78cbf646485e009a048b828680bb1b47fb3de0fd8617d91af1`.
Zig 0.15.2/V 0.5.2 versions, generated inputs/consumers and before/after fixture,
runner and implementation hashes protect the proof artifacts.
