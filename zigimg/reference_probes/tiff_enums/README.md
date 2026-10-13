# TIFF parsed enums and retained metadata

`verify_tiff_enums_reference.py` compares unchanged public `IFD.readTags` and
`TIFF.decodeBitmap` at zigimg `d7b7ab0ba0899643831ef042bd73289510b39906`:
Source Debug against ordinary V, and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_tiff_enums_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and a separate empty directory. The runtime target defaults
to `aarch64-macos.14.0`. Retained artifacts contain unchanged Source copies,
consumer fixtures, binaries, corpus, commands, diagnostics, failure snapshots,
provenance and summaries. Compiler temporaries/caches belong to the proof.
Commands have a configurable timeout; intentional panics disable core dumps.

Invalid tag IDs, compression values and resolution units now preserve the exact
Source `invalid enum value` diagnostic in ordinary and production builds. Existing
validation predicates, conversion, reads and assignment order remain unchanged.
`readTags` consumes the complete tag array and next-offset word before inserting
tags; invalid IDs retain earlier inserts/duplicates and the previous public entry
count/next-offset fields. `decodeBitmap` resets its sample view before iterating
the Source-compatible HashMap, then validates each enum before assigning its field.
Bitmap iteration uses hash order, not wire/insertion order.

| Returning observations | Count |
|---|---:|
| All 32 known tag IDs, both byte orders, retries | 256 |
| Every valid compression/resolution combination and reversed wire order | 480 |
| Inline halfword conversion across data types/counts | 160 |
| Valid IFD byte prefixes, duplicates and retries | 448 |
| Incomplete IFDs before invalid tag/bitmap enums | 456 |
| Unsupported sample counts and empty IFDs | 24 |
| **Total** | **1,824** |

Each record contains two calls: **3,648 read attempts**. Memory and file buffers
of 4/16/64 bytes cover both endian orders. Source's compression/resolution inline
conversion ignores tag type/count and uses the appropriate half of `data_offset`;
nonzero opposite halves prevent accidental whole-word or wrong-half conversion.
All shorter prefixes return their earlier seek/EOF errors before enum validation.
Returning SHA-256:
`b923196ab9bdec0916a6936a54fb956e2017c7022b3b51e9e5a0d29aaf0cedab`.

**276 exact panic/state pairs** cover unknown tag gaps/neighbors/high-bit/u16
boundaries, zero/gaps/high-valued compression and resolution values, unknown tags
at different wire positions, earlier duplicate replacements and simultaneous
invalid bitmap enums. State SHA-256:
`b1cbd56b09caa543790322bd7ad063130020c435b8a20eea7a4461e47ac3bd64`.
Every pair requires nonzero exit, no stdout/unexpected return, the sole exact
panic message and equal nonempty snapshots. Backtraces/signals are excluded.

Snapshots compare stream position, buffered length and every initialized caller
buffer byte; initialized header values; IFD offset/count/next-offset and complete
map key/value iteration; every bitmap scalar, rational, optional strip array,
fixed-storage active length and every initialized sample/extra/palette backing
entry. Padding, addresses and private failed tag allocations are excluded.
Fixtures initialize Source's otherwise undefined codec/fixed-storage state.
Actual compiled Source supplies all returning values, errors and failure states;
neither implementation bodies nor private visibility are modified.

The pre-fix comparison matched every returning record and its first public panic
snapshot before rejecting V's custom diagnostic. That evidence remains separate
from completed proofs. A module regression retains duplicate replacement,
buffered retries, high-valued compression and inline conversion quirks. Historical
metadata and decoder proofs retain their output hashes; their existing enum
categories now require the aligned diagnostic. The
[metadata boundary proof](../tiff_metadata_bounds/README.md) covers additional
arithmetic, fixed-capacity, row and palette boundaries.
All 61 image and 58 Vaxis test files pass, with eighteen production/platform
checks. The historical 86-record metadata and 39,707-case decoder hashes and
fifteen/seventeen checked trap pairs remain unchanged in both modes.

The runner checks the full Source tree SHA-256
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`, selected Zig
library SHA-256
`15a518729a305d0712ca280aa5e24bae4a1e605eb01c4866bae980b513e268be`, Zig 0.15.2,
V 0.5.2, and before/after implementation, fixture, runner, helper and corpus hashes.
Selected libraries include checked runtime/reader/writer/file operations and
HashMap iteration; this is not a complete compiler-library pin.

Manually corrupted typed enums, uninitialized/default Source state, private failed
allocations, allocation/OOM/GC/lifetime, inactive pointer identities, physically
invalid packed views, arbitrary larger counts/extents, custom/nonseekable readers,
other targets' runtime behavior, const/narrow typing, physical layout and portable
ABI remain boundaries. Optional arrays are present and initialized in this proof;
null cases have separate metadata/debug coverage. Cross builds prove compilation.
The pinned TIFF encoder still emits no bytes.
