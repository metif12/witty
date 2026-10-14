# Netpbm file writes, partial results and retained buffers

`verify_netpbm_streams_reference.py` compares unchanged public PBM/PGM/PPM
methods from zigimg `d7b7ab0ba0899643831ef042bd73289510b39906`. Source Debug
is paired with ordinary V, and Source ReleaseSafe with production V.

```sh
python3 zigimg/verify_netpbm_streams_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. Native execution uses
`aarch64-macos.14.0`, Zig 0.15.2 and V 0.5.2. Work directories retain unchanged
copied Source, fixtures, binaries, commands, outputs, input/provenance hashes,
panic snapshots and JSON summaries. Compiler caches and temporaries are task-owned;
VEXE is pinned and automatic C-error reports are disabled.

The previous V writer combined header/ASCII RGB writes, retried the comment and
ASCII gray/bitmap separator writes, and split each binary gray16 word into two
byte writes. Source formats each literal and argument separately, makes one
comment/separator write while ignoring its partial result, and writes a gray16
word in one call. The translated writer now preserves those boundaries and
ignored results.

On Darwin, a positional vector write returns after writing its first nonempty
vector. If that vector contains pending output, a single `Writer.write` can
consume none of the supplied comment or separator. Source ignores that count.
Consequently, a one-byte file buffer and a one-pixel ASCII bitmap produce
`P1\n1 1\n1`, omitting the comment and final newline. A four-byte gray16 buffer
and an eight-byte ASCII RGB buffer also retain specific inactive caller bytes.
The module regression checks these native-observed files, positions and buffers.
These are pinned-source behaviors; the proof does not impose specification fixes.

| Returning records | Count |
|---|---:|
| All P1..P6 raster shapes, sample widths and zero extents | 17,010 |
| Header/raster prefixes and retry consumption | 9,954 |
| Long comments and reads after discarding a prefix | 756 |
| Number comments, signs, underscores and token limits | 630 |
| Binary raster delimiters, including CRLF | 378 |
| Repeated format detection | 126 |
| Buffered encoding and repeated writes | 25,920 |
| Direct header-format rejection before output | 180 |
| Registry options through static/interface methods | 480 |
| **Total** | **55,434** |

These records make **110,994 read/write/detection calls**. Both modes retain
SHA-256 `aa52cfee6576b47ea915f11eb30023bddf503f837691f99970121c7a5691d375`.
Readers cover memory and positional files with 2/3/4/8/16/64-byte buffers, all
three codec specializations and direct/static/interface methods. Writes cover all
24 storage tags, both encoding modes, zero/nonzero dimensions, offsets 0/7,
PBM/PGM/PPM/BMP registry options and buffers 0/1/2/3/4/8/16/32/64/128. File
descriptors start at EOF to verify the independent positional cursor.

**243 exact panic/state pairs** cover 24 undersized reader buffers, 108 zero
divisors, 27 dimension multiplications and 84 incomplete binary bitmap rows.
Each requires a failing exit, no stdout, the sole exact message from compiled
Source and identical nonempty snapshots. Names, messages and states retain
SHA-256 `0d71dc9e305c4e35bb05fc8be37e5c72b467749b2549350ce308545fcca7ef81`.

Snapshots compare logical position, buffered/pending length, all initialized
caller buffer bytes, unchanged input and actual disk contents, including a final
explicit flush. Direct methods also retain the complete initialized public header;
writers retain caller image metadata and initialized pixels. Successful reads
compare complete pixel values and image metadata. Grayscale1 is serialized by
semantic value to exclude narrow-field padding. Failed/freed decoder buffers,
undefined default headers, unsupported palettes and pointer identities remain
unobserved. Source visibility and bodies remain unchanged.

The initial ordinary comparison found 6,420 differing records, including 6,376
with different files even after explicit flush. The first correction still
rejected a missing single-write newline contract; both pre-fix outputs remain
retained separately. The fixture also avoids V 0.5.2's generic literal-membership
code-generation error, with the original failures and generated C retained.

The original [Netpbm contracts](../netpbm_contracts/README.md) separately cover
memory streams, mutable records, compiler contracts, arithmetic, wide dimensions
and output capacities. Their option, returning and failure-state hashes remain
unchanged in both modes.

Custom/nonseekable readers, streaming pipes, descriptor failures, short operating
system writes, arbitrary larger allocations, allocator/OOM/GC/lifetime,
const/narrow/boxed representation, physical layouts and portable ABI remain
boundaries. Cross builds do not establish other-target runtime parity.

Full Source-tree SHA-256:
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
Selected Zig-library SHA-256:
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Before/after source, library, implementation, fixture, runner, helper and input
hashes protect the evidence.
