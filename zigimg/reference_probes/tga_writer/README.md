# TGA positional encoding, short storage and retained buffers

`verify_tga_writer_reference.py` compiles unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Debug against ordinary V and
ReleaseSafe against production V, using Zig 0.15.2 and V 0.5.2.

```sh
python3 zigimg/verify_tga_writer_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` in another empty directory. Runtime is native little-endian
`aarch64-macos.14.0`, linked with libc. `--timeout` bounds commands; compiler
temporaries follow `TMPDIR`/`VTMP`. Evidence retains unchanged Source, fixtures,
inputs, binaries, commands, raw output and provenance.

Explicit writer checks preserve Source's index/length diagnostics for row byte
ranges, converted RGB/RGBA element accesses and indexed palettes. Checks occur at
the corresponding access, after earlier header/ID/palette output. Raw row and
converted pixel coordinates use usize before checking and narrowing to V's array
carrier. The guards remain active in production. Valid output remains unchanged.

| Returning records | Count |
|---|---:|
| Seven supported storage tags, five shapes, four patterns, both modes/orientations | 23,520 |
| Every storage tag with zero extents and bounded buffers | 720 |
| Image ID, metadata lengths and palette-depth validation | 1,000 |
| Whole raw slices and zero extents | 336 |
| Public dimension rejection before output | 48 |
| **Total** | **25,624** |

These records contain **51,248 encoder calls**, SHA-256
`d251c2eb846597f3d5ca26fb0cac1c6a2b3bf1cdb9ee971f22aa515b9307bac7`.
Each stream is used twice, then flushed by the caller. Direct, static image and
format-interface APIs are compared. The interface uses TGA options. Main file
capacities are 0/1/3/8/32/128, with a 4,096-byte memory control; dispatch controls
also use memory capacities 0/18/513/521/1024 and a 512-byte file buffer. Files start
with 1,024 initialized bytes and retain their extent or grow. Descriptors begin at
EOF independently of the positional writer. Starting positions are zero/seven.

Supported tags are grayscale8, indexed8, RGB555, BGR24, BGRA32, RGB24 and RGBA32.
Shapes include zero extents, 1×1, 3×2, 17×2 and 129×1. Patterns exercise constant
runs, 17/16-pixel boundaries and varying values; RGB555's high padding bit is
explicitly cleared. Raw/SIMD/simple/converted encoders, reversed rows, cross-row
converted runs and run counts above 128 retain compiled Source output. The SIMD
comparison uses the baseline target's default vector selection.

Options cover ID lengths 0/1/255/256/257, valid/overlong metadata strings, both
16/24-bit palette depths and unsupported depths. Source accepts a 256-byte ID,
truncates its header length to zero and omits the ID from output; 257 is rejected.
Raw top-to-bottom writing retains the whole supplied slice even when header
extents are zero. Public dimensions beyond u16 reject before output. Unsupported
storage and direct ID/palette validation preserve their respective write order.

**1,060 individually classified returning controls**, SHA-256
`c5b49c5e66bb284b516f647dd7993986bd909e41c4df551e60c6b50eb0b7b410`,
include 729 short-storage cases where earlier writes fail or the raw whole-slice
path succeeds, 135 palette controls and 196 ID mismatches. Native execution
supplies each classification before V is checked.

| Exact panic/state pairs | Count |
|---|---:|
| Short pixel/row storage after prior encoder output | 1,035 |
| Palette range and u16 palette-end arithmetic | 75 |
| Maximum-u16 row geometry before array-index narrowing | 168 |
| **Total** | **1,278** |

Failure SHA-256:
`63a9bfc5ca634b68d5d10a8648bb6a6d1022554599f8571c2c79ae311aee4f37`.
Each pair requires failed exits, no stdout, the exact sole native panic message
and equal nonempty snapshots. Controls compare all seven storage paths, both row
orders and compression settings, memory capacities 0/18/4096 and file capacities
0/1/8/128. Palette controls also cover direct 15-bit output. Maximum geometry
65535×65535 runs with empty storage through all APIs, both compression modes and
four buffers, preserving full usize indices above the signed V array carrier.
Earlier bounded-write failures return before later bounds checks, as Source does.

Snapshots compare position, pending length, every caller buffer byte, initialized
caller image/pixels/active palette and actual disk. Direct snapshots include the
header, initialized active ID bytes and extension presence; private static/
interface codec state and other direct metadata fields are unobserved. Output
bytes verify serialized extension/footer values and offsets. Pointer identities,
inactive palette/ID backing and allocator effects are excluded. Source algorithms
and visibility are unchanged.

Two native-observed consumer regressions use file capacities eight and 32. A
bottom-up RGBA image at offset seven returns at 559, sets extension
offset 38 and retains caller buffer `90 0a 05 00 0f 06 01 10`; the last three bytes
come from earlier output. A direct unsupported palette depth leaves an eighteen-
byte header pending. Retrying commits the first header and leaves the second
pending at position 36; caller flush commits it. Separate compiled controls match
these exact inputs in both modes.

All 61 image and 58 Vaxis test files pass, with production TGA/file tests and
nineteen application/platform/unit/fixture checks. Historical record, buffered
decoder, palette, vector-read and failure hashes stay unchanged in both modes.
Native historical encoding retains `44cd8ebeb8f84afc` over 2,016 cases; decoding
retains `04232c58bcb7f905` over 1,120 cases. Cross builds establish compilation only.
Formatting, diff and Python checks pass.

Full Source SHA-256:
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
Selected compiler-library SHA-256:
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Additional math.zig SHA-256:
`65645001357d5f78cbf646485e009a048b828680bb1b47fb3de0fd8617d91af1`;
simd.zig SHA-256:
`cc554020cebe55782b38c18c56a011b61a42f332781e5d0a5b1be3003eddd7a3`.
Versions and before/after Source/library/implementation/fixture/runner/helper/input
hashes protect final comparisons. The original generic V slice panic and equal
state, plus the initial fixture Option-propagation rejection, remain retained
separately. Full evidence is archived and every member read back on persistent
storage before task-owned RAM is detached.

Other CPU vector configurations, larger allocations, wide/sparse extension
positions, custom/nonseekable writers, OS failures/short writes, allocator/OOM/GC/
lifetime, const/narrow/enum/boxed representation, physical layouts, big-endian/
32-bit runtime and portable ABI remain boundaries. Sentinel/const option typing
and invalid format-interface option tags retain their previously measured language
adaptations. This proof certifies the pinned encoder behavior for the stated inputs.
