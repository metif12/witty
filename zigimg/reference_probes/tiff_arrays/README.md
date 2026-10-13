# TIFF array reads and buffered decoding

`verify_tiff_arrays_reference.py` compares unchanged public `TagField.readTagData`,
`IFD.readTags`, `TIFF.decodeBitmap` and `TIFF.read` at zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Source Debug against ordinary V,
and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_tiff_arrays_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and a separate empty directory. The default runtime target
is `aarch64-macos.14.0`. The runner retains unchanged Source copies, fixtures,
binaries, corpus, every command/output, exact failure snapshots and provenance.
Compiler temporaries/caches belong to the proof; commands have a configurable
timeout and intentional failures disable core dumps.

V formerly queried remaining file size and used `take` for the complete array.
That unnecessarily required the array to fit the reader's file buffer, changed
read-ahead/caller-buffer state and could trap on valid files. `read_tag_data` now
uses the existing `read_slice_short` destination reader, matching Source's direct
and partial reads. Byte-size checks, count-one raw inline words, seeking, endian
conversion and unsupported-type length checks retain their order. Unread Source
allocator bytes remain undefined; V's zero initialization remains a boundary.

| Returning observations | Count |
|---|---:|
| SHORT/LONG array prefixes, offsets and retries | 2,850 |
| Other types with inline or empty data | 100 |
| Strip-offset/count, sample and palette arrays | 140 |
| Metadata IFD prefixes and retries | 550 |
| Complete image reads | 1,380 |
| Image header/IFD prefixes | 13,800 |
| **Total** | **18,820** |

These records contain **22,460 calls**. Both byte orders use memory and file
buffers of 4/8/16/64 bytes. Direct arrays cover counts 0/1/2/3/4/8/31/256, offsets
0/1/7, complete samples, partial samples, empty/short bodies and trailing bytes.
Only fully read words in a short array result are compared; unread/partial-word
tails are excluded. Empty arrays still seek, while count-one values do not seek.
Sample and palette metadata bodies are complete and initialized, including a
1,536-byte palette through the smallest file buffer.

Complete images cover grayscale1/grayscale8/indexed8/RGB24/RGBA32, raw/LZW/
PackBits/DEFLATE/Pixar DEFLATE, row spans 1/2/8, predictors 1/2 and both endian
orders. All successful pixel and indexed-palette entries are defined. Grayscale1
serializes semantic values to exclude native narrow-field padding. Image prefixes
stop before metadata body/strip allocations could expose undefined successful
short-read pixels. DEFLATE returning cases use file buffers at least one native
word long. Returning SHA-256:
`27985fbc03557dd3db0dc9311e89883f8bdd11bbf340734d76302ee655af5cfa`.

**108 exact panic/state pairs** cover 100 non-SHORT/LONG array-type length
failures after reads, plus eight DEFLATE word-capacity assertions after metadata
processing. State SHA-256:
`95b0fa680a35d1d8516ca1f2e709b637827c42e5adaf86a0f814881782c7f63a`.
Each pair requires nonzero exit, no stdout/unexpected return, the sole exact panic
message and equal nonempty snapshots. Backtraces/signals are excluded.

All cases retain stream position, buffered length and every initialized caller
buffer byte. Direct-array and bitmap cases additionally retain initialized
header/IFD fields, complete map iteration, every bitmap scalar/rational/strip
array, active fixed-storage lengths and all initialized backing entries. Image
cases retain dimensions, format, complete successful pixels/palette and stream
state; freed/undefined Source codec storage and private failed allocations are
excluded. All expected output, errors and failure state come from compiled
unchanged Source. No private visibility or implementation bodies are modified.

The pre-fix Source completed the full corpus; V first differed in caller-buffer
state, then trapped on a five-byte read through a four-byte buffer after 226
records. That evidence and an initial corpus variable-shadowing error remain
separate from completed proofs. Module regressions cover larger tag arrays,
multiple file-buffer capacities, multi-strip images and seeking/re-reading through
`read_image`. Historical metadata, parsed-enum and decoder goldens have separate
retained comparisons.

Both modes match the same returning/state hashes. All 61 image and 58 Vaxis test
files pass, with eighteen production/platform checks. The historical 86-record
metadata, 1,824-record parsed-enum and 39,707-case decoder hashes remain unchanged
in both modes, along with their fifteen/276/seventeen checked failure pairs.

The runner checks complete Source-tree SHA-256
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`, selected Zig
library SHA-256
`f7d294645f1474fc6c53ea214299928b8b3ae073e20103f97f650fdfb69185d1`, Zig 0.15.2,
V 0.5.2, and before/after implementation, fixture, runner, helper and corpus hashes.
Selected libraries include reader/writer/file operations, checked helpers,
HashMap, DEFLATE and integer powers. This is not a complete compiler-library pin.

Undefined short-array tails and partial words, unwritten short-strip pixels,
undefined/default or freed Source codec state, private failed allocations,
allocation/OOM/GC/lifetime, arbitrary larger counts/extents, custom/nonseekable
readers, physical/narrow/const representation, other-target runtime behavior and
portable ABI remain boundaries. Cross builds establish compilation only. Pinned
TIFF encoding still emits no bytes; CCITT has separate helper/decoder coverage.
