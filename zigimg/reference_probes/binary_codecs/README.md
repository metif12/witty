# QOI and Farbfeld positional file-stream contracts

`verify_binary_codecs_reference.py` compares unchanged public QOI/Farbfeld methods
from zigimg `d7b7ab0ba0899643831ef042bd73289510b39906`: Source Debug against
ordinary V, and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_binary_codecs_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. Native execution uses
`aarch64-macos.14.0`, Zig 0.15.2 and V 0.5.2. The runner retains copied unchanged
Source, fixtures, binaries, commands, outputs, input/provenance hashes, failure
snapshots and a JSON summary. Compiler caches and temporaries are task-owned;
VEXE is pinned and automatic C-error reports are disabled.

The codec implementations already preserve the measured file behavior. This
proof closes the file-stream boundary left open by the original memory proofs;
it introduces no codec or shared-stream implementation change.

| Returning records | Count |
|---|---:|
| Complete Farbfeld rasters and every prefix | 3,630 |
| QOI complete runs and header/opcode prefixes | 3,450 |
| QOI diff/luma, initial indices and run extents | 3,240 |
| Reads after discarding a prefix and repeated detection | 80 |
| All-storage buffered writes and header/option controls | 93,312 |
| Encoder runs around 62-pixel boundaries | 2,592 |
| QOI truncation of wide image dimensions | 288 |
| **Total** | **106,592** |

The records make **213,234 read/write/detection calls** in each mode and retain
SHA-256 `7abf69c3eda1b41dd0a66979fe7272843274074faf1f2ceab98e069bd97a268d`.
Direct, static image and format-interface methods cover memory reads, positional
file reads with 8/16/32/64-byte Farbfeld and 10/16/32/64-byte QOI buffers, and file
writes with buffers 0/1/2/3/4/8/10/14/16/32/64/128. Writers cover all 24 storage
tags, zero/inconsistent dimensions, zero/one/two pixels, initial offsets 0/7,
both QOI colorspaces, QOI/BMP option tags, repeated writes and final explicit flush.
Supported patterns include zero/high/mixed bytes and counts 1/2/61/62/63/64/125/126.
File descriptors start at EOF to verify the independent positional stream cursor.

**168 exact panic/state pairs** cover 24 undersized magic buffers, nine QOI header
buffers, 45 invalid parsed QOI enum pairs and ninety Farbfeld image-dimension casts.
They require a failing exit, no stdout, the sole exact message from compiled
Source and identical nonempty snapshots. Names, messages and states retain
SHA-256 `1495d4ae12287494280220e6c8ef80f4dde127b7a8d5fb4161a1ed4707f3fad4`.
QOI enum failures consume the complete header before trapping and retain the
previous direct header. Farbfeld casts precede storage validation and all output,
including when storage is unsupported or the file buffer is empty.

Snapshots compare logical position, buffered/pending length, every initialized
caller buffer byte, unchanged input and actual disk contents. Direct methods
also retain initialized public headers; writers retain caller image metadata and
initialized pixel bytes. Successful decodes compare complete pixels and image
metadata. Grayscale1 values exclude narrow-field padding; unsupported palettes,
failed/freed private decoder buffers, default undefined QOI headers and pointer
identities are unobserved. Source visibility and bodies remain unchanged.

An eight-byte Farbfeld writer leaves the complete big-endian pixel in the caller
buffer after flush. An eight-byte QOI writer leaves its end marker there. File
reading with a ten-byte QOI buffer consumes the one-pixel fixture through position
19, retaining five buffered marker bytes. The module regression checks these
native-observed bytes, complete files and reader positions. QOI continues to leave
the end marker unread and unvalidated; both writers retain Source's full-slice
encoding independently of declared dimensions.

The original [QOI](../qoi_contracts/README.md) and
[Farbfeld](../farbfeld_contracts/README.md) memory proofs remain separate. They
retain their existing returning and failure-state hashes in both modes.

Custom/nonseekable readers, streaming pipes, descriptor/short operating-system
I/O failures, arbitrary larger allocations, allocator/OOM/GC/lifetime,
const/narrow/boxed representation, physical layouts, big-endian bulk writing and
portable ABI remain boundaries. Cross builds do not establish other-target
runtime parity.

Full Source-tree SHA-256:
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
Selected Zig-library SHA-256:
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Before/after source, library, implementation, fixture, runner, helper and input
hashes protect retained evidence.
