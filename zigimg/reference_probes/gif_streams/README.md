# GIF buffered metadata, graphic parsing and retained file state

`verify_gif_streams_reference.py` compiles unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Debug against ordinary V and
ReleaseSafe against production V, using Zig 0.15.2 and V 0.5.2.

```sh
python3 zigimg/verify_gif_streams_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and a separate empty directory. Runtime is native
little-endian `aarch64-macos.14.0`, linked with libc. `--timeout` bounds commands;
compiler temporaries follow `TMPDIR`/`VTMP`. Retained evidence includes unchanged
Source, fixtures, inputs, binaries, commands, raw output and provenance.

The existing GIF and stream implementation matches without production changes.
File buffers have capacities 13/14/16/32/128, with memory controls and isolated
smaller capacities. Detectors also use six-byte buffers. File descriptors start
at EOF independently of the positional reader cursor. Prefix/detector records
also compare initial discard of three bytes.

| Returning records | Count |
|---|---:|
| Complete headers, all global palette sizes, five canvas shapes | 720 |
| Every first detector byte, static/interface detection | 2,560 |
| Partial signatures, accepted versions and initial discard | 100 |
| Comment sizes, sub-block boundaries and two patterns | 1,296 |
| Header/comment prefixes and retries | 4,104 |
| Every other extension label and zero-terminated byte scanning | 4,536 |
| **Total** | **13,316** |

These records contain **26,632 calls**, with SHA-256
`7d610f7bca4e240506ab9fe2662014f8c90ccd154b54b078fb017464a0940469`.
Each record calls the same stream twice. Direct reads use an initialized public
codec; static/interface reads exclude their private/default codec state. All
256 global palette entries are seeded before shrinking its active view, so direct
no-global-table controls observe defined backing. Successful canvas storage and
palettes are completely initialized before observation.

| Individually classified returning controls | Count |
|---|---:|
| Application identifiers, declared sizes and payload lengths | 648 |
| Application prefixes | 702 |
| Graphic flags, ignored size/terminator, delay and transparency | 315 |
| Graphic prefixes | 105 |
| Zero image extents and local/interlace flags | 270 |
| Complete one-pixel LZW input and graphic controls | 390 |
| Complete plain-text blocks | 162 |
| Small buffers | 6 |
| Initialized direct background casts | 36 |
| **Total** | **2,634** |

Returning-control SHA-256:
`1ffece9b8732ef1e307735ac2b4aad0bcfbabb02ea2085d9bb021cfa7d0592a5`.
Native execution classifies each control before V is checked. Parsed application
identifiers/authentication/data, graphic control bytes, image descriptors, local
palette lengths and pixel slice lengths are compared. Successful frame output
includes format, exact native f32 duration bytes, pixels/palettes before and after
mutation, and static/interface main pixels after frame mutation to certify sharing.
The one-pixel inputs fully initialize their decoder output; broader LZW/rendering
coverage remains in the historical GIF assertions.

| Exact panic/state pairs | Count |
|---|---:|
| Recognized short application data and loop-count slice/load order | 324 |
| Application-prefix toss beyond buffered data | 18 |
| Complete graphic control buffer boundaries | 63 |
| Graphic-prefix toss failures | 57 |
| One-pixel control/background cast or buffer failures | 114 |
| Plain-text byte-count overflow | 54 |
| Undersized reader/detector buffers | 24 |
| Direct indexed background casts | 84 |
| **Total** | **738** |

Failure SHA-256:
`2d97ecf1c18da35bd3e87addcebda9a98545986b6838d9118d2bcde927dd53a5`.
Each pair requires failed exits, no stdout, the exact sole native panic message
and identical nonempty snapshots. Snapshots compare logical position, buffered
length, every initialized caller buffer byte, direct public header/palette/frame/
application state, unchanged input and disk. Comments are appended before their
payload is initialized in Source: error snapshots compare their count only, and
payload bytes are observed only after successful reads without a prior poisoned
comment. Local palette/pixel contents after incomplete decoding are unobserved.

A failed `toss` updates seek before asserting. `bufferedLen()` then underflows;
file `getPos()` calls it too. The observer prints `-` for these queries outside
the Source API domain, preserving the failed memory cursor when it is accessible.
Caller buffer and initialized codec state are still compared. The original
recursive observer failure remains retained separately; it is not a codec result.
No Source algorithm or visibility is changed to make observation possible.

**Twelve bounded loop pairs** cover Source's positional `discardAll` behavior on
short plain-text blocks, using capacities 13/32, direct/static/interface reads and
both initial-header and sub-block discard stages. Each executable publishes a
matching initialized entry snapshot, emits no stdout/stderr and remains running
through a 0.5-second timeout. Entry SHA-256:
`b0ef0ce9fde8e40f35c018c36c095c1aa8ed5d03b58bbb7e80a1b7f237a892c9`.
These establish observed nontermination over that interval and entry state only;
post-discard state is unobserved.

Two native-observed consumer regressions use a thirteen-byte file buffer. A
complete animation retains `00 3b 00 00 00 01 00 01 00 00 02 02 4c` at position
62, while frame pixel/palette mutations remain visible through the main image.
A short application consumes through position 36 without appending metadata and
retains `03 01 07 82 a7 cc 21 ff 0b 4e 45 54 53` after a repeated EOF failure.
Separate compiled Source/V controls compare these inputs in both modes.

Historical GIF record/failure hashes and unchanged native assertions pass in both
modes. All 61 image and 58 Vaxis test files pass, alongside production GIF/file
tests and nineteen application/platform/unit/fixture checks. Cross builds provide
compilation coverage only.

Full Source SHA-256:
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
Selected compiler-library SHA-256:
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Versions and before/after Source/library/implementation/fixture/runner/helper/input
hashes protect final comparisons. Full evidence is archived and every member read
back on persistent storage before task-owned RAM is detached.

Undefined default/private or partial decode storage, inactive backing, pointer
identities, allocator/OOM/GC/lifetime, custom/nonseekable streams, OS failures,
const/narrow/boxed representation, wider dimensions, big-endian/32-bit runtime
and portable ABI remain boundaries. This proof adds buffered metadata and small
fully defined graphics; it does not certify arbitrary malformed LZW rendering.
