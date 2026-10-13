# CCITT records, lookup state and retained decoding failures

`verify_ccitt_contracts_reference.py` imports unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906` and compares Source Debug with ordinary
V, then Source ReleaseSafe with production V:

```sh
python3 zigimg/verify_ccitt_contracts_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The default native target is
64-bit little-endian `aarch64-macos.14.0`, linked with libc. `--timeout` bounds
commands; `TMPDIR` and `VTMP` select compiler temporaries. Artifacts retain the
complete unchanged Source tree, fixtures, binaries, generated inputs, outputs,
compiler consumers, commands and provenance.

Copied code records now expose mutable run_length/code/code_length fields and
require all three at construction. Source keeps the record's name private; the
fixture uses the inferred public table element type without changing visibility.
V names that represented type CcittCode. Three direct omission pairs reject in
both compilers. Complete code/default-decoder construction passes, and both
compilers reject direct mutation of the public constant code table.

Both modes match **243,904 returning/error records**:

| Returning records | Count |
|---|---:|
| All 195 table entries, logical field hash | 1 |
| Every u13 code, both colors, seven length controls | 114,688 |
| All u8 lengths over 193 distinct table code/length pairs | 98,816 |
| All three lookup methods and initial reversal state | 13,656 |
| Returning narrow-code boundary controls | 12 |
| All byte patterns over color/white/reversal/output choices | 12,288 |
| Every code table run over width and output boundaries | 3,068 |
| Prefixes, zero/make-up runs, partial output and multiple rows | 676 |
| Returning padding-byte controls | 200 |
| Decoder continuation and retry after errors | 32 |
| Valid factory byte domain | 2 |
| Factory dimensions through native usize maximum | 40 |
| Default/mutable decoder scalar copies | 160 |
| Required/mutable code record copies | 175 |
| Zero/maximal dimensions without unbounded execution | 80 |
| Initial input/output cursors | 6 |
| Returning decoded-bit overflow prefixes | 4 |
| **Total** | **243,904** |

Return SHA-256: `b8944f0d9d04f1546416591d8afb61138d85f0022fb2312c72e6d6d855aba394`.
The logical table hash retains FNV-1a `8aa26e4c9fe26ada`; padding/layout bytes are
not compared. Scalar record copies remain independent after mutation.

**2,476 exact panic/state pairs** cover 310 narrowing casts and 2,166 arithmetic
failures, including two decoded_bits u16 overflows reached through alternating
zero-pixel terminating codes. Names and exact diagnostics join full initialized
snapshots in SHA-256
`2ee32767c8af907f13cb06609c1a4d24102f4c17193aa22236ebe764e6b8cc46`.
Each pair requires an unsuccessful exit, the exact diagnostic, no stdout, a
nonempty matching snapshot and no core dump. State includes segment index, input
and writer cursors, decoder color/reversal/width/rows/white value, unchanged current
input and complete output initialized to 0xa5.

Make-up lookups leave should_reverse unchanged; terminating lookups set it before
run subtraction or writing. Additional make-up codes precede color-specific
codes. Failed writes retain the pending reversal and current color. Code length
and decoded_bits accumulate as in Source, with padding measured from decoded
code lengths, not pixel lengths. Its u1 padding cast, EOF-as-zero behavior,
14-bit invalid-code limit and absence of a final bit-writer flush are retained.
A fresh bit reader/writer is created on each decode call while public decoder
state and the caller writer persist across continuation/error controls.

The model only partitions cases; unchanged compiled Source supplies every
compared record and snapshot. Table-derived cases are generated from the pinned
Source text. The proof does not expose private bit-reader/writer scratch,
partially built factory records, empty pointer identities or allocator state.
All caller input/output and observed record fields are initialized. Maximal
factory/record extents do not imply runtime coverage of enormous row loops.

Five compiler controls record Source rejecting three wider lookup code arguments,
a wider factory white-value argument and a wider stored white value while V
accepts them. Those are typing adaptations, excluded from the returning count.
Source's u13/u1 typing, packed color representation, broader alias construction,
underlying std.Io interfaces, GC/OOM/lifetime, physical layout, file-platform
runtime, wider execution extents and portable ABI remain boundaries.

All 61 image and 58 Vaxis test files pass, along with production CCITT/TIFF/image
API tests, unchanged historical GIF/image-API/compression assertions in both
modes, native/Linux application checks, three Windows DLLs, both Windows CCITT
test executables and two Linux shared libraries. TIFF retains 39,707 records,
its existing hash and seventeen strict trap pairs in both modes. Cross builds
provide build coverage only.

Full Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Versions and before/after dependency/fixture/input/consumer/runner/implementation
hashes protect the retained comparison. Source visibility/implementation are
unchanged.
