# Indexed TGA palettes, file refills and exact bounds failures

TGA palette destination guards now preserve Source's exact
`index out of bounds: index N, len L` diagnostic in ordinary and production V.
The 24-bit path checks the destination before taking a palette byte. The 15/16-bit
path takes its little-endian word first, then checks the destination before
assigning the rounded RGB components. EOF therefore precedes an invalid word
palette index, while an invalid 24-bit index precedes EOF. Valid decoding is unchanged.

`verify_tga_palette_reference.py` imports the complete unchanged pinned Source
tree and calls its public TGA.read method. The fixtures initialize the codec's
header/extension, all 255 ID backing bytes and caller file buffers before reads.
Successful observations retain index bytes, every active RGBA palette entry,
reader position/buffered length, the complete caller buffer, header, active ID
and retained extension. Failures retain caller state, excluding private pixel/
palette/RLE allocations. Expected outputs and panic text come from actual Source
execution, without replacing Source bodies or widening visibility.

Run from the repository root, then repeat with `--v-prod` and another empty directory:

```sh
python3 zigimg/verify_tga_palette_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Source Debug compares with ordinary V, ReleaseSafe with production V, using
Zig 0.15.2, V 0.5.2 and `aarch64-macos.14.0` with libc. Both modes match
**8,393 records containing 11,102 read attempts**, SHA-256
`9669a76dfbdbf5613f3c2c35663659d248d6219cd166e8339b90d6549cd6a592`.
Capacity zero selects memory; file capacities are 26/27/31/64/512/4096 bytes.

| Returning record group | Count |
|---|---:|
| Palette depths, lengths, zero/small extents, both row orders and raw/RLE indices | 5,292 |
| Word/component boundary and ignored high-bit controls | 126 |
| All 32 five-bit channel values | 224 |
| Every byte prefix with two reads and retained state | 2,681 |
| Unsupported/invalid palette depths | 42 |
| EOF/partial word before an invalid destination, with retries | 28 |

Palette lengths are 0/1/2/4/16/255/256. Widths are 0/1/3 and heights 0/1/2.
Palette bytes are always read from the original stream, independently of RLE
compression of indices. Successful palettes are fully written; no undefined
Source pixel bytes or padding are certified. The existing extension remains
initialized during reuse. File buffering and physical read-ahead are compared
independently for each capacity.

**112 exact panic/state pairs** cover all three supported palette depths,
first-entry offsets 1/2/255, active lengths 1/2/4 and memory/file capacities
0/26/31/64. Four additional 24-bit cases put the invalid destination at EOF.
The word-before-index recoverable cases complement those traps. Every panic
must have the exact Source index/length message, unsuccessful exit, no stdout,
no unexpected return and no core dump. Retained state SHA-256:
`8d1b6eeb5c2f893af80247f9e94137e06efb094d4a2548af25888eaf310d6c26`.

The pre-fix comparison already matched all returning records and caller state,
but its first bounds case exposed V's generic array diagnostic. The corrected
implementation makes that check explicit and preserves the existing input
position and buffers. A module regression covers 15/16/24-bit palette entries
and index bytes across four file-buffer capacities.

All 61 image and 58 Vaxis test files pass, together with nineteen production/
platform checks: TGA/record/decoder/file production tests, native/Linux application
checks, three Windows dependency libraries, Windows TGA tests in both modes,
two Linux shared libraries and Windows/Linux fixture builds. Cross builds establish
compilation coverage. Existing TGA record (274,453 observations/24 failures) and
buffered decoder (20,576 records/15 failures/48 file-vector controls) hashes remain
unchanged in both modes. The old record runner now expects the explicit word
palette bounds category; its output/state goldens are unchanged.

Private failed/freed allocations, allocator/OOM/GC/lifetime, inactive ID backing,
empty pointer identities, portable aggregate ABI, arbitrary SIMD choices,
nonseekable files and custom reader modes remain outside the proof. Indexed
palette success cases use zero first-entry offset, following Source's active
palette resize behavior; nonzero offsets with nonempty palettes are tested as
ordered failures. Undersized footer/extension buffers and arithmetic/capacity
traps retain their existing separate proofs.

Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Compiler versions and before/after original/copied Source, library, implementation,
fixture, runner, helper and corpus hashes protect the proof. Every command retains
stdout/stderr, with state files for each failure.

Artifacts are retained under `/Users/alex/.cache/witty-tga-palette-20261014`.
An initial disk-space failure preceded fixture creation; previous RAS/TIFF
archives were fully verified before duplicate pruning. A fixture borrowing compile
error and the comparison showing the pre-fix diagnostic remain separate from
completed proofs. The comparison before locking the failure golden is retained.
The final archive is verified by reading every member against its manifest.
