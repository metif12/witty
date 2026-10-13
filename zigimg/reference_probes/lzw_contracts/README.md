# LZW narrow arithmetic, bit reads and retained decoder state

`verify_lzw_contracts_reference.py` imports unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906` and compares Source Debug with ordinary
V, then Source ReleaseSafe with production V.

```sh
python3 zigimg/verify_lzw_contracts_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. Comparisons use native
64-bit little-endian `aarch64-macos.14.0` by default. `--timeout` bounds commands;
`TMPDIR` and `VTMP` select compiler temporaries. Artifacts retain the complete
imported Source, fixtures, binaries, inputs, outputs, commands and provenance.

The dictionary field is marked required, as in Source; the pinned V compiler
accepts its omission in the generic record, recorded separately below. Factory/reset shift
amounts first retain their u4 cast failures and then their u13 shift failures.
Reset still clears the dictionary and assigns code_size before computing its new
next code; pending/previous fields remain unchanged. Code advancement preserves
dictionary insertion, next-code overflow, shift/cast checks, early-change
subtraction and successful size growth in Source order. Empty dictionary values
retain exact index-zero bounds after the corresponding write/allocation boundary.

The private LZW bit reader follows Source's u13 result type instead of using a
native u16 read followed by a range assertion. Every shift truncates the value
at thirteen bits; little-endian shifts preserve u4 cast/u13 shift failures after
consuming the byte. Big-endian oversized reads retain their truncation and EOF
behavior. Pending resumes retain their subtraction, shift and clear order.
remaining_data is assigned before a failed u4 remaining_bits cast. The shared
BitReader APIs and other compression algorithms remain unchanged.

The model only partitions returning/error cases and strict traps. Compiled,
unchanged Source supplies every compared result and snapshot. Both endian orders
cover all constructor/code-size bytes, arbitrary input bytes, early-change and
dictionary-growth boundaries, empty/borrowed entries, pending fields, clear/end
codes, segmented continuation, empty resumes, short writers and initial cursors.
Output storage is initialized to 0xa5 before every case. Snapshots include the
current input segment and cursor, writer cursor and complete output, initialized
decoder scalar/optional fields and a canonical dictionary hash. The hash sorts
keys and includes each key, value length and every byte; it measures logical
contents rather than map placement, capacity or allocator state.

Both modes match **22,016 returning/error records**:

| Returning records | Count |
|---|---:|
| Valid constructor domain, both endian markers | 26 |
| Every input byte over early-change/output/prefix choices | 17,918 |
| Returning public code-size domain | 580 |
| Advancement, previous/next fields and write ordering | 1,192 |
| Pending-data/bit-count/coded-width boundaries | 1,444 |
| Empty entries and live borrowed dictionary values | 180 |
| Literal growth and bounded output | 452 |
| Segmented continuation, empty resumes and write failures | 192 |
| Returning reset-initial controls | 8 |
| Input/output starting cursors | 24 |
| **Total** | **22,016** |

Return SHA-256: `ed8bb6c09434dfe1e443322d20f2995deee8a18ebfb2fd35af8568866ca18f36`.

**3,772 exact panic/state pairs** cover 2,030 cast failures, 1,256 arithmetic
failures, 450 shift failures and 36 empty-value bounds failures. They require the
exact diagnostic, unsuccessful exit, no stdout, complete matching snapshot and
no core dump. Names, diagnostics and retained state join SHA-256
`0fe9b3c86c939dbbf71d079c9f9800ea2c779f3c03960e196e68f99506b60fd7`.

One complete record constructor passes both compilers. Nine separate compiler
controls measure V accepting dictionary omission despite the required marker,
absence of Source's arena-allocator field, five wider code carriers, wider
remaining-bit storage and mutable dictionary values. These adaptations are
excluded from the parity record count; no constructor-enforcement claim is made
for the pinned V compiler's generic dictionary field.

Factory failures do not expose the private partially constructed decoder. During
decoding, only active initialized dictionary values are observed, including after
failed insertion/advancement and after clearing. Private new-value allocations,
bit-reader scratch, unused map capacity, freed arena values and post-deinit state
are excluded. No empty pointer identities are compared. Mutable caller bytes
behind a borrowed dictionary value are changed before decode to test live reads.

Source uses u13 codes, u4 remaining-bit storage, an arena allocator and
AutoArrayHashMap with readonly byte slices. V retains wider carriers, GC storage
and its map implementation. Native narrow field/constructor typing, readonly
values, allocator/OOM/growth/lifetime, map API/layout/copy behavior, file streams,
wider extents and portable ABI remain boundaries. Cross builds establish build
coverage only. Source visibility and implementation are unchanged.

Full Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Zig 0.15.2/V 0.5.2 versions and before/after Source/library/fixture/input/runner/
implementation hashes protect the retained comparison.
