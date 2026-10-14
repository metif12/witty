# TIFF palette construction and format selection

`verify_tiff_palette_reference.py` compares unchanged public `IFD.readTags`,
`TIFF.decodeBitmap` and `BitmapDescriptor.guessPixelFormat` at zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Source Debug against ordinary V,
and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_tiff_palette_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and a separate empty directory. The default runtime target
is `aarch64-macos.14.0`. Commands have a configurable timeout. Retained artifacts
include unchanged Source copies, fixtures, binaries, corpus, every command/output,
failure snapshots, provenance and summaries. Compiler temporaries/caches belong
to the task; the global Zig cache is shared only within that task. Intentional
failures disable core dumps.

Explicit guards now preserve complete Source bounds messages for red/green/blue
palette components, the first grayscale/indexed sample and required RGBA extra
samples. Palette components are checked in Source argument order before assigning
a complete color. Compression selection still precedes sample access; RGBA extra
samples are still read before validating channel bit depths. Successful output,
hash-map iteration, reads, resizing, division/truncation and format rules are
unchanged, and guards remain active in production.

| Returning observations | Count |
|---|---:|
| Format selection, unsupported dispatch and empty-field precedence | 15,336 |
| Complete SHORT/LONG palettes with map reservations | 800 |
| IFD prefixes before palette processing | 550 |
| **Total** | **16,686** |

Each record calls the operation twice: **33,372 calls**. Format selection covers
all ten valid compression tags, six photometric values, eleven sample shapes,
empty/nonempty extra samples and four fill-order/predictor combinations. Valid
unsupported compressions return before accessing empty samples; non-RGBA sample
shapes ignore absent extra samples. The getter preserves all initialized state.

Palette cases cover both byte orders, SHORT/LONG words, depths 0/1/2/4/8, two
patterns including high LONG bits, reservations 0/6/24/200, memory and file buffers
of 4/8/16/64 bytes. Tag-map bucket order can make palette processing use the
default depth before a later bits tag. All supplied component words are complete
and defined; extra words allow either valid order. IFD prefixes end before any
undefined short palette body is observed. Returning SHA-256:
`b9dd13a23b6bb0b8919eafd5737ecfb9495ac84dc7964d58335e8961a9c08f9f`.

**276 exact panic/state pairs** cover 240 short palettes, eighteen empty sample
views and eighteen missing RGBA extra-sample views. Short palettes supply complete
zero-through-five-word arrays; omitting the bits tag fixes the decoded depth at
one and requires six components. Count-one palettes retain Source's raw inline
word. A five-word palette assigns the first full color before failing on the
second blue component. Getter failures include wrong RGBA depths with missing
extra samples, confirming extra-sample access before channel validation.
State SHA-256:
`0974206cdeecb306fe4b8719edc3d1d47977c28c71b08f5450a97cee241e84af`.

Strict checks require unsuccessful exit, no stdout/unexpected return, one complete
Source index/length panic, an identical V message and equal nonempty snapshots.
The state golden includes the actual Source message. Backtraces/signals are
excluded. Snapshots retain stream position, buffered length, every initialized
caller buffer byte, header/IFD fields, complete map iteration, all bitmap scalars,
rationals/strip arrays, active fixed-storage lengths and every initialized backing
entry. Inactive palette entries are initialized and compared, including partial
updates before failure. Undefined/default Source state and private failed arrays
are excluded. No Source bodies or private visibility are modified.

The pre-fix returning comparison matched before rejecting V's generic palette
bounds message; its first snapshots match and remain separate from completed
proofs. A module regression and separate native-observed control verify LONG
channel truncation and retained inactive palette backing through a small file
buffer. The getter's readonly V receiver remains a documented adaptation to
Source's mutable receiver; these runtime observations do not prove const typing.

Both modes match the same returning/state hashes. All 61 image and 58 Vaxis test
files pass, with eighteen production/platform checks. Historical metadata,
buffered array and complete decoder comparisons are retained separately.

The runner checks full Source-tree SHA-256
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`, selected Zig
library SHA-256
`f7d294645f1474fc6c53ea214299928b8b3ae073e20103f97f650fdfb69185d1`, Zig 0.15.2,
V 0.5.2, and before/after implementation, fixture, runner, helper and corpus hashes.
Selected libraries include checked helpers, reader/writer/file operations,
HashMap, DEFLATE and integer powers. This is not a complete compiler-library pin.
The [metadata boundary proof](../tiff_metadata_bounds/README.md) separately covers
fixed capacities, power overflow, row indexing and array-type failures.

Undefined short-read component words, default Source state, private failed arrays,
arbitrary larger counts/extents, allocation/OOM/GC/lifetime, forged typed enums or
storage, physical/narrow/const representation, custom/nonseekable readers,
other-target runtime and portable ABI remain boundaries. Cross builds establish
compilation only. Pinned TIFF encoding still emits no bytes.
