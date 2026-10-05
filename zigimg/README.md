This is an incremental V translation of zigimg revision
`d7b7ab0ba0899643831ef042bd73289510b39906`, the dependency locked by pinned
vaxis. It currently covers the pixel-format words, storage variants, raw and
indexed storage, memory/file and bit streams, crop/flip editing, pixel iteration,
QOI, farbfeld, PBM, PGM, PPM, PAM, Sun raster, SGI, XBM, PCX, BMP, IFF, GIF, TGA, and JPEG codecs,
PackBits/LZW/CCITT compression helpers, the octree palette quantizer, pixel-format
conversion, managed image construction/editing methods, image-wide encoder options,
memory/file image writing, format detection and loading, TIFF metadata/IFDs/decoding,
PNG header/filter/processors, complete IDAT/Adam7 reading and information
diagnostics, and the pinned PNG writer. Vaxis now uses these loaders. The
complete library and its allocator/representation contracts remain open.

The PNG writer in this exact revision emits only the eight-byte signature;
its chunk-writing bodies are commented out. Native reference execution and V
tests preserve that behavior, including fixed-buffer failures.

PNG header loading validates IHDR fields and CRC while accepting unnamed
compression/filter bytes. Scanline filtering, defiltering, sample spreading,
reader callbacks, borrowed one/two-processor options, and tRNS/PLTE processors
follow the source. The heuristic's whole-row stride and omitted final run,
gray16 transparency's byte-index comparisons, repeated tRNS replacement,
and palette RGBA8 writes for BGRA32/RGBA64 destinations are preserved. The
RGB24 direct processor API also retains its zero-stride loop for grayscale
alpha destinations. Complete PNG loading uses the pinned 4-KiB buffered
consecutive-IDAT reader and shared zlib decoder, including CRC read-ahead and
processor notification timing. Later IDAT notifications keep the initial
chunk's length; IEND ignores its length/CRC, and unknown critical chunks are
not automatically skipped. Adam7 retains its byte-sized destination-row
overflow; repeated 16-bit tRNS can shrink the format and trap. Small file
buffers can rebase while reading IHDR's CRC, overwrite the borrowed payload,
and reject a valid image; native/V tests preserve that source behavior.
The generic chunk writer now preserves inline fixed-byte buffers, partial
flush failures, repeated empty chunks, and oversized writes that bypass
framing after a flush. Its default buffer is 16 KiB; an empty byte slice
represents the source's zero-capacity specialization. The unchanged legacy
`writer()` adapter and `ZlibCompressor` do not compile with Zig 0.15.2 because
their standard-library APIs were removed; these unsupported boundaries remain.
GC/opaque
callbacks replace allocators and generated vtables; allocator selection and
root DefaultPngOptions overrides are absent. Undefined native initial storage,
failed scalar union assignments, and unwritten alpha tails are excluded from
comparisons; V storage initializes. The wasm branch has not run locally.

The PNG information processor preserves diagnostic text, IDAT totals,
palette counts, and binary byte-size formatting. It inspects at most 1,024
bytes of text/iTXt and initially reads at most 81 bytes of zTXt. Compressed
iTXt is printed raw; zTXt method zero uses the pinned buffered zlib reader.
Unknown zTXt methods leave the rest unread. Ancillary CRCs are ignored, and
writer failures return success with the current input position, which can
leave payload/CRC bytes unconsumed. Delimiter, field, enum-name, and counter
bounds retain checked traps. Memory/file writers use the translated streams;
GC scratch and format strings replace stack storage and streaming formatting.

The pinned Sun raster writer succeeds without writing bytes. Its decoder
preserves source RLE, planar palettes, one-bit row padding and polarity, and
the raw-byte copying quirk for one-bit indexed images.

SGI preserves planar channels, bottom-up rows, and both RLE channel widths.
The source's RGBA64 alpha branch reads and endian-swaps a single byte at an
unscaled channel offset; its 16-bit grayscale branch still selects grayscale8.
The writer succeeds without emitting bytes. The shared inline fixed storage
has a 256-element specialization; the private SGI header debug logger remains
unexposed.

PAM preserves the pinned header parser, sample scaling, little-endian 16-bit
samples, monochrome-alpha AND, image sequences, and encoder comments. Only
subsequent images become animation frames; the reader compares dimensions
and storage tags. Duration comments retain Zig decimal formatting and signs,
verified against its native formatter across 19,968 float bit patterns.
The source accepts grayscale2 in header construction but omits its pixel
writer arm; writing nonempty grayscale2 images therefore traps.

XBM preserves ordered defines, zero-sentinel hotspots, continuous LSB-first
bits without row padding, its hexadecimal parsing quirks, and ignored
unterminated data lines. Its writer emits no bytes. The pinned format detector
repeatedly peeks at a leading define line without advancing; that loop is also
preserved. Direct decoding bypasses detection, as in the source.

PCX preserves its 128-byte header, indexed and planar RGB decoding, built-in
and end-relative VGA palettes, streaming RLE, and the fast encoder's 16-byte
run accumulation. Compression flags, stride/partial-byte quirks, short active
palettes, and whole-slice even-width indexed encoding follow the locked source.
The fast path uses scalar comparisons instead of SIMD; V names the reserved
header field `reserved0`. Pixels left unwritten by the source reader are
undefined allocator memory, while V's pixel storage starts zeroed; the tests
compare defined outputs.

BMP preserves V4/V5 BGR24/BGRA32 decoding and encoding, all header metadata,
bottom-up rows, ignored offsets/masks, absent row padding, and the source
encoder's V5 masks. Windows 3.1 headers are parsed and then rejected. Zero
dimensions are accepted; signed dimensions follow the source path, including
negative heights that leave pixels unwritten. Those undefined source pixels
and default codec headers share the initialization boundary described above.

IFF preserves PBM/ILBM/ACBM decoding, planar layout, PackBits, Atari ByteRun2,
HAM6/HAM8 color carry and palette reduction, and EHB expansion and priority.
Its chunk walker does not consume odd-byte padding; planar conversion does
not clip set padding bits at image width. DEEP detection is rejected, while
its public header helper returns zeros without consuming bytes. The writer
emits no bytes. The source leaves default IFF headers, inactive palette entries,
and temporary planes unwritten by short PackBits input undefined. V initializes
that storage; comparisons cover defined outputs. Public header debug hooks
remain untranslated.

GIF preserves both versions, palette/extension records, LZW sub-blocks, frame
grouping and filtering, independent rendering with first-frame sharing,
interlacing, and all disposal paths. Indexed transparency leaves palette alpha
opaque, multiple local palettes overwrite the output palette, and interlacing
uses canvas height. Clipping checks linear pixel bounds. RGBA background
initialization shifts channels through the source's u32Rgb-to-u32Rgba call;
background restoration uses an opaque transparency palette color. The reader
ignores graphic/application block sizes, graphic terminator values, and LZW
write failures, scans unknown extensions to their first zero, and skips one
plain-text sub-block. Its writer emits no bytes. Packed flags use byte words
and accessors; GC replaces arenas and record reclamation. Source undefined
magic/version, unread palette entries, incomplete comment records, and pixels
unwritten by short LZW input share the initialization boundary above.

TGA preserves its packed records and 495-byte extension, grayscale/indexed/
RGB555/BGR/BGRA decoding, all seven encoder storage formats, both row orders,
raw and RLE packets, and the reader's 512-byte read-ahead into trailing data.
Detection requires footer dot/null values; decoding checks only its signature.
Decoding requires at least 26 input bytes even for 1.0 images. Palette offsets
index the active palette directly and origins/right-to-left are ignored. When
an extension is present, only its useful-alpha attribute preserves alpha.
The encoder omits an accepted 256-byte ID through its truncated length field and rejects metadata
names of 40 bytes. Its direct-storage RLE starts new runs per row and vector
tail; RGB/RGBA conversion retains runs across rows. Scalar comparisons preserve
baseline amd64/arm64 vector packet boundaries; other Zig CPU-feature selections
remain a build-model boundary. Sentinel fields use physical byte arrays and
metadata option names use V strings. Source undefined RGB555 padding bits,
default footer signatures, and incomplete ID storage share the initialization
boundary above. Native hashes compare 2,016 encoder cases and 1,120 decoder
cases, including source positions; unused RGB555 padding is excluded.

PackBits preserves declared-length truncation, unclipped runs, and its unread
final lone control byte. LZW retains endian selection, clear/end codes, early
change, dictionary mutation order, partial-input state, and source handling of
unknown codes and empty resumptions. CCITT retains all 195 code entries, color
across rows/calls, cumulative padding, and its absent final partial-byte flush.
Their sub-byte state uses wider V backing values. LZW maps and GC replace the
source dictionary and arena; `lzw_decoder_init[E]` works around the pinned V
compiler's static-constructor specialization defect inside generic callers.

The octree quantizer preserves per-level insertion lists, weighted integer
averages, wrapping reduction sums, checked leaf accumulation, traversal order,
and first-child fallback for missing colors. RGB(A) input normalization retains
the source's f32 alpha round-trip, channel-width scaling, and NaN upper clamp.
Output borrows the caller's palette; its requested color budget does not clip
to the buffer's length. A sufficient budget leaves the tree intact. Reduction
does not process level zero; a zero budget emits no palette entries, while
lookup still returns default indices. Repeating reduction can trap on an
already collapsed node. Native hashes match 2,160 palette/tree/index cases and
336,128 color-normalization cases. GC replaces the arena and the root uses a
stable heap address. Generic input accepts the translated RGB(A) storage types;
arbitrary caller types with Zig color-method namespaces remain a boundary.
The pinned V compiler cannot format recursive fixed pointer arrays; pointer
assertions use `voidptr` to avoid its invalid generated formatter.

The converter preserves all 460 pinned table entries, including unavailable
indexed-to-gray/RGB-to-grayscale16 pairs and nine BGR555 entries that trap on
the wrong union arm. Alpha handling retains the table's straight rgba-to-RGB332,
premultiplied indexed-to-RGB332, and premultiplied rgba64-to-BGRA32 paths.
RGB-to-gray-alpha scales alpha through f32, while gray-to-gray-alpha narrows
integer fields directly. Quantization shortens only a local palette slice in
the source; returned indexed storage keeps its full palette and opaque black
tail. Float-to-RGBA/BGRA prefixes truncate and scalar tails round/clamp; four
allocated empty conversions trap on unconditional f32 alignment casts; borrowed
empty views sliced from float storage pass when their pointers are aligned.
Empty float allocation/raw initialization retains Zig's maxInt(usize) align(1)
sentinel. NaN casts in the
pinned Zig/ARM64 prefix emit zero, while scalar NaN scaling clamps upward.
Other CPU/compiler float-cast behavior and feature-specific vector lengths
remain boundaries. Native page allocations satisfy destination alignment;
an align(1) arena need not. V GC replaces caller-selected allocation/alignment
and freeing. Image convert/convertNoFree replace only the main pixels and leave
animation frames unchanged. Native hashes match 18,432 format-pair cases and
6,066,176 precision conversions.

V arrays and GC replace allocator slices. Sub-byte scalar values use byte
storage or packed backing words. Allocation errors, the full color convenience
methods, the FormatInterface callback surface, and the remaining image API
and allocator contracts still require translation.

Managed images support creation, copied raw pixels, metadata, conversion,
editing, iteration, and conversion to/from unmanaged views. Those views copy
slice headers while sharing pixel, palette, and animation-frame backing data;
their dimensions and loop counts remain independent. Iteration borrows the
live image pixels. Lifecycle methods use GC in place of allocator reclamation,
including the source's skipped shared first animation frame. Managed images
have no allocator field or ABI prefix cast. V arrays cannot enforce Zig's
read-only slice type contract.

The image-wide encoder-options sum covers all 17 source tags. Fixed-memory
writing returns a borrowed prefix and preserves partial buffer writes on
failure. The pinned JPEG and TIFF writers emit no bytes, as do the other
recorded no-op writers. Empty option markers replace void union arms; three
distinct Netpbm wrappers preserve PBM/PGM/PPM tags, and the format enum uses
byte backing instead of u5. Creation/crop overflow and zero-height row/flip
operations preserve checked traps. The native dispatch hash matches 6,528
cases across both image APIs, including buffer sizes and option variations.

Both image APIs detect in-memory formats through the pinned 17-detector order,
seeking before each check and propagating its errors. An earlier short peek
can block an otherwise valid later signature. TIFF accepts only the II/MM
byte-order marker without checking the version; TGA can take precedence over
TIFF through its header or footer. Unknown inputs without a newline can fail
at the final XBM delimiter peek; a leading define line preserves its
non-advancing loop. Registry dispatch uses direct V matches rather than the
source's reflected callback array. A native hash matches
589,824 prefix/length cases, and separate bounded processes compare the XBM
loop through both image APIs. JPEG's frame/table/scan APIs now decode
baseline/progressive/restart inputs; the separate reference runner documents
eight excluded cases involving undefined source coefficient state.

TIFF metadata preserves its packed 6/12/10-byte records, all 32 tag IDs,
IFD parsing, bitmap defaults, sample/palette fields, format selection, and
row sizing. Tags retain raw inline SHORT words, byte-order-aware arrays,
rational pairs, ignored fill-order/orientation fields, and successful short
array reads with undefined source tails. Tests compare only defined samples
in those tails. The tag map matches Zig 0.15.2 hashing, placement, growth,
reservation, duplicate replacement, and bucket-order iteration. Reserving
capacity can put the palette before the bits tag, making it use the default
bit depth. Component arrays truncate to u16; RGB/RGBA selection ignores the
samples-per-pixel value that row sizing uses. One-bit row sizing rounds down.
Native hashes match 3,072 table
mutations, 38,400 bitmap/row cases, and 4,224 metadata/palette cases. Thirteen
separate probes compare checked enum, capacity, component, arithmetic, and
palette traps. Fixed storage has eight- and 256-element specializations;
GC replaces reclamation, V initializes undefined source fields/storage,
and the remaining general-purpose map API and debug formatter stay open.
TIFF read/readImage and strips now decode grayscale1/grayscale8/indexed8/RGB24/
RGBA32 with uncompressed, PackBits, CCITT RLE, LZW, DEFLATE, and Pixar DEFLATE.
Versions are ignored, only the first IFD is used, and compressed byte counts
constrain only PackBits. Predictors other than one wrap channel differences
except at row starts. One-bit rows keep floor byte counts and continuous bits;
grayscale8 retains its absent photometric inversion. Source undefined short
strip tails/unwritten pixels share the initialization boundary above. GC keeps
IFD/strip backing data reclaimed by source read defers.

The private TIFF zlib adapter follows Zig 0.15.2's buffered reader with a
64 KiB window and 32 KiB history. It preserves stored/fixed/dynamic yield
points, partial output on errors, word-sized read-ahead, and the consumed
trailer. The source ignores FCHECK, FDICT, and Adler32 validation. Fixed matches
crossing the window retain its unreachable-rebase trap. Huffman decoding now
uses the source's small lookup, sorted alphabet and linked fallback; GC owns
them. Generic input supports memory, files, and PNG's buffered IDAT reader.
This is the zlib path required by the codecs, not the full Zig flate API.
The unchanged-source runner compares 39,707 cases across helpers and complete
TIFF reads, including output, errors, positions, partial writes, palettes,
predictors, and byte orders. Fifteen isolated probes compare checked traps.
All 25 image test files pass, with native/Linux checks and Windows DLL/test
compilation; Windows runtime remains untested.

Cropping copies the active indexed palette and pixel rows into independent
storage and does not copy animation data. Flipping mutates the existing pixels.
Pixel iterators borrow the live storage and capture its length at initialization;
the caller must keep that storage alive. They normalize integer channels without
premultiplying alpha and preserve floating point values.

PBM/PGM/PPM preserve the pinned parser's comments, 16-byte number buffer,
single raster delimiter, bitmap polarity/padding, and format-specific sample
scaling. Both per-codec and image-wide options are available. The bit streams
specialize on `BigEndian` or
`LittleEndian` and support V's native integer and floating point scalar types;
Zig's arbitrary-width integers and other bit-castable types remain a boundary.

Run the V checks with the repository's pinned compiler:

```sh
VEXE=/Users/alex/.cache/v/v1-fallback/0.5.2/v \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v test zigimg
```

The standalone reference harness accepts the unmodified dependency as a Zig
module. With Zig 0.15.2 on macOS, a 14.0 target avoids linking against an SDK
version newer than that compiler supports:

```sh
zig run -target aarch64-macos.14.0 -lc --dep zigimg \
  -Mroot=zigimg/verify_reference.zig \
  -Mzigimg=/path/to/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906/zigimg.zig
```

The XBM detector uses separate bounded process probes. Build the V executable
from `zigimg/reference_probes/xbm_detect` and the locked-source Zig executable
from its `reference.zig`, with the same module and target options above. Then run:

```sh
python3 zigimg/reference_probes/xbm_detect/verify.py /path/to/v-probe /path/to/zig-probe
```

The compression modules are private to the locked package. Their separate
reference runner verifies source hashes, copies unchanged source files into a
temporary package, and adds the harness there:

```sh
python3 zigimg/verify_compressions_reference.py \
  /path/to/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906 \
  /path/to/zig-0.15.2/zig
```

Its default target is `aarch64-macos.14.0`; use `--target` for another host.

The private quantizer uses the same source-hash/copy approach:

```sh
python3 zigimg/verify_quantizer_reference.py \
  /path/to/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906 \
  /path/to/zig-0.15.2/zig --probe-output /path/to/zig-probe
```

Build the V probe from `zigimg/reference_probes/quantizer_bounds`, then compare
palette capacity, repeated reduction, component/reference overflow, average
casts, and color-level checks:

```sh
python3 zigimg/reference_probes/quantizer_bounds/verify.py /path/to/v-probe /path/to/zig-probe
```

The private converter has its own unchanged-source runner:

```sh
python3 zigimg/verify_converter_reference.py \
  /path/to/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906 \
  /path/to/zig-0.15.2/zig --probe-output /path/to/zig-probe
```

Build the V probe from `zigimg/reference_probes/converter_bounds`, then compare
wrong-union access, empty/unaligned float storage, palette bounds, float cast
traps, and the pinned ARM64 NaN-prefix result:

```sh
python3 zigimg/reference_probes/converter_bounds/verify.py /path/to/v-probe /path/to/zig-probe
```

The managed image and fixed-memory dispatch runner verifies the entire locked
source tree before copying it unchanged:

```sh
python3 zigimg/verify_image_api_reference.py \
  /path/to/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906 \
  /path/to/zig-0.15.2/zig --probe-output /path/to/zig-probe
```

Build the V probe from `zigimg/reference_probes/image_bounds`, then compare
dimension overflow and zero-height checks through both image APIs:

```sh
python3 zigimg/reference_probes/image_bounds/verify.py /path/to/v-probe /path/to/zig-probe
```

The same runner compares in-memory detection. Pass
`--detect-probe-output /path/to/zig-detection-probe` to also build its XBM-loop
probe. Build the V counterpart from `zigimg/reference_probes/image_detection`,
then compare both image APIs:

```sh
python3 zigimg/reference_probes/image_detection/verify.py \
  /path/to/v-detection-probe /path/to/zig-detection-probe
```

The TIFF metadata runner verifies the same unchanged locked source tree:

```sh
python3 zigimg/verify_tiff_metadata_reference.py \
  /path/to/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906 \
  /path/to/zig-0.15.2/zig --probe-output /path/to/zig-probe
```

Build the V probe from `zigimg/reference_probes/tiff_metadata_bounds`, then
compare its checked metadata traps:

```sh
python3 zigimg/reference_probes/tiff_metadata_bounds/verify.py \
  /path/to/v-probe /path/to/zig-probe
```

The TIFF decoder comparison builds both probes, generates synthetic inputs,
and runs its ordinary and checked-trap cases:

```sh
python3 zigimg/verify_tiff_decode_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2
```

It verifies the locked source tree and compiler dependency hashes before
compiling the unchanged reference. Fixtures use Python's zlib for input
generation; native decoding defines the expected behavior.

The PNG foundation runner guards the same source/compiler dependencies and
checks native goldens for headers, filtering, row helpers through full native
PNG reads, and processor state/truncations. Its 74,260 defined cases also run
in `png_reference_test.v`. Passing `--v` builds both isolated probes and
compares fourteen checked traps and the inherited zero-stride loop:

```sh
python3 zigimg/verify_png_foundation_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig --v /path/to/v-0.5.2
```

The information-processor runner compares 51,223 cases and twelve checked
traps, including diagnostic bytes, partial output, input/error positions,
IDAT state, float byte-size formatting, and zTXt buffered decompression. It
also guards the pinned formatter files:

```sh
python3 zigimg/verify_png_info_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2
```

The complete PNG decoder runner builds both probes after checking the same
source/compiler hashes. It compares pixel/palette bytes, statuses, dimensions,
stream positions, tRNS/PLTE state, information output, and callback ordering
through 60,760 memory/file cases and five file-buffer sizes, then checks eight
isolated traps:

```sh
python3 zigimg/verify_png_decode_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2
```

Fixtures cover all 15 color/depth combinations, every filter, Adam7,
stored/fixed/dynamic compression, IDAT splits/CRCs/empty chunks, truncations,
metadata/chunk walking, and large rows/windows. Python generates inputs only;
the unchanged native decoder defines expected results. The dedicated
`png_reader_test.v` also checks pixel values and loading through the registry.

The chunk-writer runner compares 5,960 direct-method cases, call ordering,
buffered state, partial failures and oversized-write counts, then checks two
traps and both inherited helper compilation failures:

```sh
python3 zigimg/verify_png_chunk_writer_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2
```

The result SHA-256 is
`934ba176552e9370b30073ea1f648fab7dcb4ca85424296097b173f4d298115e`.

IFF checked bounds use separate process probes. Build the V executable from
`zigimg/reference_probes/iff_bounds` and the locked-source Zig executable from
its `reference.zig`, using the same module and target options above, then run:

```sh
python3 zigimg/reference_probes/iff_bounds/verify.py /path/to/v-probe /path/to/zig-probe
```

They verify stride overflow, an out-of-bounds padding bit, empty CMAP, and HAM
palette reduction below four bits. The native harness uses synthetic images;
upstream binary fixture files are absent from the locked source archive.

GIF has equivalent probes in `zigimg/reference_probes/gif_bounds`, with a V
`main.v`, a locked-source `reference.zig`, and a verifier:

```sh
python3 zigimg/reference_probes/gif_bounds/verify.py /path/to/v-probe /path/to/zig-probe
```

They verify plain-text byte-count overflow, checked buffered toss, short loop
data, and indexed background casts. The normal harness compares decoding,
animation frames, metadata, error positions, and the no-op writer.

TGA uses equivalent probes in `zigimg/reference_probes/tga_bounds`:

```sh
python3 zigimg/reference_probes/tga_bounds/verify.py /path/to/v-probe /path/to/zig-probe
```

They verify palette offset/capacity checks and overflow of palette-end and
pixel-byte arithmetic against the unchanged locked source. Windows checks
compile the module and focused test executable; runtime remains untested.
