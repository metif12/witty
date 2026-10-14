This is an incremental V translation of zigimg revision
`d7b7ab0ba0899643831ef042bd73289510b39906`, the dependency locked by pinned
vaxis. It currently covers the pixel-format words, storage variants, raw and
indexed storage, memory/file and bit streams, crop/flip editing, pixel iteration,
QOI, farbfeld, PBM, PGM, PPM, PAM, Sun raster, SGI, XBM, PCX, BMP, IFF, GIF, TGA, and JPEG codecs,
PackBits/LZW/CCITT compression helpers, the octree palette quantizer, pixel-format
conversion, managed image construction/editing methods, image-wide encoder options,
memory/file image writing, format detection and loading, TIFF metadata/IFDs/decoding,
PNG header/filter/processors, complete IDAT/Adam7 reading and information
diagnostics, the pinned PNG writer, and the public SIMD lane helpers. Vaxis now
uses these loaders. The complete library and its allocator/representation
contracts remain open.

QOI and Farbfeld positional file streams retain header/pixel consumption,
caller-buffer bytes, pending output, and the unconsumed QOI end marker. The
[file-stream comparison](reference_probes/binary_codecs/README.md) covers 106,592
records and 168 exact failure states in ordinary and production builds.

The lane helpers are `simd_load`, `simd_load_bytes`, `simd_store`,
`simd_int_to_float`, `simd_float_to_int`, and `simd_vpermd`. Output lanes use a
directly named fixed-array type, such as `type FourWords = [4]u16`; a load or
store length of zero selects the whole array. Numeric operations support V's
native integer types and f32/f64, including aliases and borrowed pointer inputs
for conversions. Stores also accept compatible boolean and struct arrays.
Bounds and float-cast checks remain active in production builds, and short
stores retain the written prefix. Fixed-array stores preserve the source's
propagating overlap behavior; native vector overlap and layout, AVX2 selection,
comptime lengths and zero-length arrays retain the limits described in the
[source comparison](reference_probes/simd/README.md).

The PNG writer in this exact revision emits only the eight-byte signature;
its chunk-writing bodies are commented out. Native reference execution and V
tests preserve that behavior, including fixed-buffer failures.

PNG header, chunk, processor and writer records now declare the represented
Source-required fields and expose mutable Source fields. Existing callers
initialize every required field explicitly. Separate native comparisons cover
[header/chunk/encoder records](reference_probes/png_records/README.md),
[processor records](reference_probes/png_processor_records/README.md), and
[chunk-writer records](reference_probes/png_chunk_records/README.md).
Pinned V can omit required fields through aliases or generic records, and
copied sum-type payloads share boxed storage; these measured differences remain
outside the equivalent record cases. The [PixelFormat comparison](reference_probes/pixel_format/README.md)
also covers every named format and the defined packed-info carrier, preserving the
RGB332/RGB565 bits-per-channel unreachable checks in production.

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
GC/opaque callbacks replace allocators and generated vtables; allocator selection and
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
The writer succeeds without emitting bytes. Shared inline fixed storage has
8- and 256-element specializations plus a general `FixedStorage[T, B]`, where
`B` is the fixed-array storage type. Empty slices stand for zero capacity.
Resizing borrows that inline storage and retains old views. All three forms
preserve exact Source bounds diagnostics before replacing the data descriptor,
including production builds. The [fixed-buffer contract proof](reference_probes/fixed_storage_contracts/README.md)
compares independent inline copies, borrowed views and retained failure state.
SGI/IFF header and TIFF bitmap diagnostics preserve Source payloads through
V's standard logger, with logger configuration remaining a host adaptation.

Public magic-number helpers preserve the source's shift order and target-endian
dispatch, including checked shifts for signatures longer than four bytes.
The deprecated struct-read helpers copy native-layout bytes, validate nested
exhaustive enums, and swap foreign integer/enum fields. Struct definitions must
retain the source's native field widths, layout and padding; V does not generate
Zig layouts automatically. PNG's non-exhaustive compression/filter enums accept
unnamed values. Invalid enums consume the struct, while short input stays
unconsumed. The source struct-write helpers fail to compile with Zig 0.15.2
because their shared error type references the removed `std.io.StreamSource`.
Their unsupported source boundary is retained.

PAM preserves the pinned header parser, sample scaling, little-endian 16-bit
samples, monochrome-alpha AND, image sequences, and encoder comments. Only
subsequent images become animation frames; the reader compares dimensions
and storage tags. Duration comments retain Zig decimal formatting and signs,
verified against its native formatter across 19,968 float bit patterns.
The source accepts grayscale2 in header construction but omits its pixel
writer arm; writing nonempty grayscale2 images therefore traps.
Header writes preserve the source's individual literals and arguments, including
pending output and caller buffer bytes before a file flush or pixel failure.
The [buffered PAM comparison](reference_probes/pam_streams/README.md) covers
38,958 records and 90 exact failure states in ordinary and production builds.

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
are available through the standard logger.

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

The [pixel storage proof](reference_probes/pixel_storage/README.md) requires both
indexed constructor fields and retains palette-capacity, raw-byte divisibility
and alignment checks in production. Empty raw input bypasses input alignment.
Both modes match 4,393 returning observations and 97 panic/state pairs. Boxed
sum-type copies, narrow/const carriers and undefined empty pointers are recorded
separately; the matrix uses initialized palettes and valid storage slices.

The [pixel view proof](reference_probes/pixel_views/README.md) restores checked
slice range order and iterator data/palette bounds before narrowing wide cursors.
Both modes match 18,028 returning observations and 1,039 panic/state pairs across
all formats, shared views, copied cursors and replacement of live storage. Invalid
storage keeps its Source behavior, and exhaustion precedes pointer access.

The [converter contract proof](reference_probes/converter_contracts/README.md)
retains alignment and SIMD float-cast traps in production, along with Source
palette diagnostics. Both modes match 2,207 returning observations and 488
panic/state pairs. Historical matrix and precision hashes are checked independently
of V assertions; undefined raw-empty pointers and private failed destination state
remain outside the comparison.

The [PCX contract proof](reference_probes/pcx_contracts/README.md) preserves
coordinate, scanline, palette-offset and encoder arithmetic traps in production,
including header/cursor failure order. Both modes match 135,766 returning
observations and 41 panic/state pairs using initialized memory streams. Source
unwritten pixels and private failed allocations remain outside the comparison.

The [PCX buffered decoder proof](reference_probes/pcx_decode/README.md) extends
coverage to VGA palette seeking, planar/dummy-byte rows, runs and retries across
five file-buffer sizes. Both modes match 21,480 records / 25,896 read attempts and
204 exact panic/state pairs. RGB destination bounds retain Source's index/length
message after byte decoding, including EOF precedence.

The [BMP contract proof](reference_probes/bmp_contracts/README.md) retains signed
dimension/scanline arithmetic, image-size arithmetic, integer casts and pixel
bounds in production. Both modes match 11,378 returning observations and 152
panic/state pairs, including partial output and header/cursor failure order.
Negative-dimension outputs compare metadata only when Source pixels are unwritten.

The [image editing proof](reference_probes/image_editor_contracts/README.md)
preserves production row/flip division traps, partially completed flips before
overlapping-row failure, and crop arithmetic/bounds before narrowing wide offsets.
Both modes match 42,034 returning observations and 524 panic/state pairs across
direct and both image APIs. Three inherited zero-row loops remain documented.

The [SGI contract proof](reference_probes/sgi_contracts/README.md) restores u16
RLE table arithmetic, channel-size/offset traps and byte bounds in production.
Literal and repeated words retain Source failure order and partial output.
Both modes match 795 returning observations and 636 panic/state pairs;
word reads beyond Source's physical byte allocation remain excluded.

The [SGI parsed-header proof](reference_probes/sgi_header/README.md) preserves
invalid enum traps before header replacement on little-endian targets. Both modes
match 13,480 memory/file records / 22,040 read attempts and 964 exact panic/state
pairs, including incomplete-header precedence and all initialized caller buffers.

The [GIF record proof](reference_probes/gif_records/README.md) adds thirteen
packed-field setters and requires Source comment/application constructor fields.
Byte-count overflow and indexed-background casts remain checked in production.
Buffered toss advances a representable cursor before checking its end, preserving
failure state. Both modes match 14,875 returning observations and 35 panic/state
pairs; narrow literals, const-slice mutation, enum typing and wider failed cursor
offsets remain documented representation boundaries.

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

The [TGA record proof](reference_probes/tga_records/README.md) adds public packed
flag setters and mutable encoder options, preserving unrelated bits and inline
record copies. Explicit pixel-byte/palette-end overflow and indexed-8 capacity
guards remain active in production. The 24-bit palette path checks its destination
before consuming a byte, preserving the Source bounds-versus-EOF priority.
Ordinary/production comparisons match 274,453 returning observations and 24
checked panic/state pairs. Narrow literal typing, const ID-slice typing and
sentinel logical lengths are measured separately as representation differences.

The [buffered TGA decoder proof](reference_probes/tga_decode/README.md) covers
21,032 read attempts across memory/file packets, truncation, retries and alpha
extensions. Raw RLE reads now use available buffered bytes and preserve file
refills and the Source zero-progress transition. The shared file shim follows
Zig's macOS first-vector positional-read fallback; 48 direct observations compare
destination bytes, positions and buffered lengths. Decoder rows and 15 failure-state
pairs match in both modes. A separate
[indexed palette proof](reference_probes/tga_palette/README.md) covers memory/file
palette refills, all active entries, retries and exact destination bounds text.
Both modes match 8,393 records and 112 panic/state pairs. Word palettes consume
their word before the index check; 24-bit palettes check before reading a byte.

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
336,128 color-normalization cases. GC replaces the arena; the root is inline,
so copied quantizers retain independent root metadata and borrowed child pointers.
The [record/state comparison](reference_probes/quantizer_contracts/README.md) matches
4,594 returning records and 1,134 exact failure/state pairs in both modes.
Generic input also accepts caller structs without an `a` field through a public
`to_u32_rgb()` receiver method returning native u8/u16/u32. Narrow words widen
before RGB unpacking. Custom getters run at each tree level, with
leaf lookup bypassing the getter. The
[custom getter comparison](reference_probes/quantizer_custom/README.md) matches
9,984 returning records and 600 exact failure/state pairs in both modes.
Custom alpha records use `premultiplied_alpha()` and the returned value’s
`to_u32_rgba()` method. The
[alpha getter comparison](reference_probes/quantizer_alpha/README.md) matches
19,968 returning records and 1,200 exact failure/state pairs in both modes.
Alpha-only records need a public `a` marker with the pinned V compiler; private
markers work with an additional represented RGB getter. The
[getter width comparison](reference_probes/quantizer_getter_width/README.md) matches
15,012 returning records and 864 exact failure/state pairs in both modes.
Aliases of getter result types and arbitrary alias chains remain boundaries.
The pinned V compiler cannot format recursive fixed pointer arrays; pointer
assertions use `voidptr` to avoid its invalid generated formatter.

IFF header debug hooks retain the pinned anonymous-record syntax, field order,
signed values and enum labels through V's standard logger. The
[diagnostic comparison](reference_probes/iff_debug/README.md) matches 142,912
enabled/suppressed observations in both modes. Logger routing, prefixes and
default-level behavior remain host-language adaptations. SGI preserves the same
anonymous-record syntax and prints all 80 image-name and 404 padding bytes as
decimal lists. Its [diagnostic comparison](reference_probes/sgi_debug/README.md)
matches 6,470 observations in both modes, including every byte value at every
array position and unchanged caller fields. TIFF bitmap diagnostics preserve optional
arrays, nested buffer data/backing words, palette abbreviations at Source's default
formatter depth and the trailing newline. Their
[comparison](reference_probes/tiff_debug/README.md) matches 3,708 observations in
both modes with initialized state and borrowed-view fingerprints. Custom formatter
depths and the existing readonly V receiver remain surface adaptations. RAS
header diagnostics retain their direct stderr route at both debug/info logger
thresholds. Their [expanded comparison](reference_probes/ras_debug/README.md)
matches 13,494 observations and 15,190 messages in both modes, including scalar
boundaries, repeated calls and unchanged initialized headers. Output locking,
flush ordering and failed streams remain host adaptations.

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

HSL/HSV/CMYK models, float grayscale types and the eight predefined colors
for the eleven translated RGB(A) types now expose their source conversions.
They preserve out-of-range channels, signed zeros, ignored RGB alpha, the
CMYK epsilon cutoff and HSV white-to-HSL NaN saturation. The color-model
runner compares 31,167 cases, preserving every non-NaN output bit and NaN
occurrence (payloads are canonicalized). Vector/matrix helpers expose the
source's Float2/3/4 and 2x2/3x3/4x4 identity, construction, determinant,
inverse, multiplication, transpose and clamps. Inversion retains zero-pivot
and singular behavior without added pivoting; dot products begin at negative
zero. The 12,419-case matrix comparison also checks caller immutability.

General `Matrix[B]` uses a named `[N][N]f32` storage type and supports flat
construction, identity, determinant, inverse, transpose, matrix multiplication
and fixed-vector multiplication. Its 6,467-case comparison covers dimensions
1, 2, 3, 4, 5 and 8, including named matrix types and custom storage names.
Explicit shape checks protect the bounded direct indexing needed to avoid
V 0.5.2's generic bounds-cache defect and remain active in production.
Zero-length arrays, extra alias layers and generic forwarding of static
factories remain pinned compiler boundaries; storage uses V's array ABI.
Examples and limits are in
[the generic matrix probe](reference_probes/math_generic/README.md).

Named matrix records require explicit `matrix` storage, matching Source.
The constructor/copy comparison matches 6,208 records in ordinary V/Source Debug
and production V/Source ReleaseSafe, including full retained storage and NaN
payloads after cell, row and whole-field mutation. Three required-field and
eighteen immutable-field rejection pairs pass. V 0.5.2 still ignores the required
attribute on generic `Matrix[B]`; its six omission controls record that limitation.
The historical arithmetic and ordinary color hashes remain unchanged. The color histories
now use corresponding Source modes. Scientific and colorspace production match
ReleaseSafe exactly. Details, compiler limits
and reproduction are in
[the matrix contract probe](reference_probes/matrix_contracts/README.md).

HSLuv and HSLuvAlpha require all seven fields and preserve mutable inline copies.
Their 9,424-record contract comparison matches Source Debug/ordinary V and
ReleaseSafe/production V, with seven required-field and seven immutable-field
rejection pairs. Darwin production uses the native paired trig primitive for
HSLuv ray evaluation. This closes all five scientific and sixteen colorspace
differences from its preceding checkpoint; the later cylindrical consumer pass
closes the remaining sixteen differences. The float4 signature typos are preserved.
Reproduction and limits are in
[the HSLuv contract probe](reference_probes/hsluv_contracts/README.md).

All six cylindrical RGB entry points evaluate their polar components together
before matrix conversion. The 50,832-case comparison covers all presets,
Lab/Luv/Oklab families, alpha variants, clamp modes, unusual float values and
unchanged caller inputs in both corresponding compiler modes. The full 5,792-row
colorspace history now matches Source Debug and ReleaseSafe exactly; standalone
scientific-color results are preserved. Reproduction and limits are in
[the cylindrical colorspace probe](reference_probes/cylindrical_colorspace/README.md).

`RgbColorspace` requires all ten represented record fields, including its four
transfer callbacks. Factory arguments retain their zero chromaticity and identity
callback defaults. The 7,920-record comparison verifies explicit/factory
construction, independent copies, mutation, whole-field replacement, by-value
returns and callback order in both corresponding modes. Ten required-field and
ten immutable-binding rejection pairs pass. Reproduction and limits are in
[the RGB colorspace record probe](reference_probes/colorspace_records/README.md).

CIE XYZ/Lab/Luv/LCh, HSLuv and Oklab models retain scalar, alpha and Float4
conversion APIs. The 6,961-case comparison preserves every non-NaN output
bit and NaN occurrence, including zero whitepoint denominators and unusual
component values. Private f32 cube-root, angle and power helpers follow the
pinned Zig 0.15.2 algorithms; their license notices are retained in
`LICENSE_color_math`. Separate sine/cosine calls avoid Apple's optimized
combined routine and retain the same output bits in ordinary and production
builds. The inherited HSLuvAlpha Float4 factory returns CIELuvAlpha, as in
the source.

RGB color spaces expose all scalar model conversions, the sixteen copying and
in-place alpha-slice APIs, conversion matrices and Bradford whitepoint
adaptation. Eleven presets, twenty-nine CIE whitepoints, gamma parameters and
transfer functions retain their source values and branches. The 5,792-case
runner compares all preset/default pairs, scalar outputs, copied slices,
borrowed pointer identity and mutation in ordinary and production builds.
V typed transfer values replace compile-time namespaces, and callback fields
have a `_fn` suffix to coexist with the corresponding methods. Copying APIs
use V allocation in place of the source's caller-selected allocator.

Gamma-transfer construction requires explicit parameters or gamma, including
explicit default parameter records. The 24,192-case comparison verifies all
parameter fields, independent copies, stable captures and every transfer method
in both modes. Source's compile-time namespaces and V's runtime typed values
remain distinct; arithmetic NaNs compare by occurrence. Details are in
[the gamma contract proof](reference_probes/gamma_contracts/README.md).

`PostConversionBehavior`, `NetpbmFormat` and `PamTupleType` retain native ordinals
and one-byte storage/alignment. The 3,584-case public-enum byte/copy comparison
and six PAM native-debug-metadata observations pass in both modes. Source's
private PAM names and V's mode-dependent unsafe literal checks remain measured
adaptations. Details are in [the compact enum proof](reference_probes/compact_enums/README.md).

All eleven built-in RGB(A) types expose typed constructors and getters for
colors, grayscale, packed integers, arrays, Float4 values and HTML hex strings,
plus premultiplied alpha. Public `scale_value[O, I]` retains unsigned-width
scaling and float rounding. V static/receiver methods replace the source's
zero-sized `from`/`to` namespaces; `NoColorAlpha` represents its void argument.
Receiver `to_color[T]()` retains the target's conversion behavior and delegates
custom target types to their static `from_color` factory.
Mixed-width array and unsupported HTML methods retain source compile failures.
Private source factories do not expose arbitrary user-defined color namespaces;
V's generic helper adaptations and their focused checks are separate from the
unchanged-source built-in comparisons.

All nine grayscale records require an explicit value; alpha variants retain
their opaque defaults. The 10,232-record native comparison covers construction,
mutation, independent copies, by-value returns and exact conversion bits in both
modes. Required/immutable constructor checks pass, and sub-byte conversion checks
remain active in production. V's wider u8 carriers still accept invalid native
u1/u2/u4 values at construction. Reproduction and the distinct width-failure
boundaries are in [the grayscale record proof](reference_probes/grayscale_records/README.md).

Public `Grayscale[T]` and `GrayscaleAlpha[T]` factories now support native numeric
types and aliases. Use `GrayscaleAlpha.init(value)` for default alpha and the
static `Grayscale.to_colorf32(value)` / `GrayscaleAlpha.to_colorf32(value)` calls
for conversion. The 25,740-record comparison retains every channel/conversion
bit in both modes. Signed construction and unsupported-conversion checks also
pass. Generic omissions, direct-literal alpha defaults and distinct built-in
type identities remain measured V adaptations. Examples and reproduction are in
[the generic grayscale proof](reference_probes/grayscale_generic/README.md).

`predefined_colors[T]()` accepts built-in types/aliases and caller-defined types
with a public static `from_color(Colorf32) T` conversion. Its read-only fields
retain each factory's returned value. The 4,352-record comparison covers all
canonical colors, custom mappings and copied values in both modes. Source's
compile-time constants and V's runtime factory evaluation remain distinct;
details are in [the predefined color proof](reference_probes/predefined_generic/README.md).

Public `IndexedStorage[T]` factories expose default/explicit palette construction,
`palette_size()`, static `resize_palette(mut storage, size)` and GC cleanup.
All five named indexed records also expose capacity lookup and cleanup. The
2,384-record comparison verifies initialized palettes/indices, shared elements
and independent copied lengths in both modes. Generic omission/type-identity
differences and wider capacity/array limits are recorded in
[the indexed factory proof](reference_probes/indexed_generic/README.md).

V arrays and GC replace allocator slices. Sub-byte scalar values use byte
storage or packed backing words. Caller-selected allocation, allocation failures
and allocator reclamation remain runtime adaptations.

Managed images support creation, copied raw pixels, metadata, conversion,
editing, iteration, and conversion to/from unmanaged views. Those views copy
slice headers while sharing pixel, palette, and animation-frame backing data;
their dimensions and loop counts remain independent. AnimationFrame requires
explicit pixel storage and duration; GIF initializes new durations to zero.
The [animation contract proof](reference_probes/animation_contracts/README.md)
compares duration bits, frame copies and shared frame-array elements, with boxed
payload metadata differences recorded separately. Iteration borrows the live
image pixels. Lifecycle methods use GC in place of allocator reclamation,
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
non-advancing loop. Public `FormatInterface` callbacks and each codec's
`format_interface()` factory drive detection, loading and writing through the
source's ordered 17-factory registry. V spells that table explicitly instead
of reflecting namespace declarations. Callback allocator parameters are
omitted under the existing GC adaptation. All three callback fields are required
and mutable; copied interface records retain independent callback choices.
Cross-codec encoder options preserve each writer's fallback or checked union-arm
access. PNG/TGA keep exact wrong-tag panics in production before image validation.
The [interface contract proof](reference_probes/format_interface_contracts/README.md)
compares callback copies and full initialized state at these failures. A native hash matches
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
palette traps. Fixed storage has eight- and 256-element specializations and
a general inline-array variant. GC replaces reclamation, V initializes
undefined source fields/storage, and the remaining general-purpose map API
stays open.

Invalid parsed TIFF tag IDs, compression and resolution units preserve Source's
exact `invalid enum value` panic, including production builds. The
[parsed enum comparison](reference_probes/tiff_enums/README.md) matches 1,824
returning records / 3,648 attempts and 276 exact panic/state pairs in both modes.
It covers both byte orders, memory/file streams, complete IFD consumption before
insertion, duplicate replacement, inline halfword quirks, EOF precedence, retries
and earlier bitmap mutations in hash iteration order. Snapshots retain complete
initialized public metadata, fixed-storage backing and caller buffers.

TIFF array reads use Source's destination-based short reader, allowing metadata
larger than the file buffer and preserving its read-ahead state. The
[buffered array comparison](reference_probes/tiff_arrays/README.md) covers 18,820
records / 22,460 calls and 108 exact panic/state pairs, including 1,380 complete
image reads. Short-array observations exclude undefined unread/partial words.

The [strip bounds comparison](reference_probes/tiff_strips/README.md) covers 3,260
returning controls and 655 exact panic/state pairs. Native-width guards preserve
complete index/length and null diagnostics, including destination validation
before RGB/RGBA channel evaluation. Initialized caller pixels, palette backing,
earlier strip writes and buffer state match Source through failures.

The [palette and format comparison](reference_probes/tiff_palette/README.md)
matches 16,686 returning records / 33,372 calls and 276 exact panic/state pairs.
Palette component bounds retain prior full-color writes, and format selection
preserves compression-before-samples and extra-samples-before-channel-validation
order. Complete initialized metadata and inactive palette backing are compared.

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
scaling. Both per-codec and image-wide options are available. The writers
preserve the source's separate header/RGB writes, ignored partial comment and
ASCII separator results, and single-word gray16 writes. The
[buffered Netpbm comparison](reference_probes/netpbm_streams/README.md) covers
55,434 records and 243 exact failure states in both modes. Bit streams
specialize on `BigEndian` or
`LittleEndian` and support bool, V's native integer and floating point scalar types,
and the four packed RGB color records;
Zig's arbitrary-width integers and other bit-castable types remain a boundary.
The [boolean comparison](reference_probes/bitstream_bool/README.md) covers one-bit
result checks, aliases, padding and retained failure state in both modes. The
[packed RGB comparison](reference_probes/bitstream_packed/README.md) covers every
logical color word and the 555 types' 15-bit shifts, padding and failure state.

Bit-stream operations and record construction reject unsupported endian markers,
including pointer markers. Native markers and direct aliases retain alignment,
padding and failure state. The
[endian contract comparison](reference_probes/endian_contracts/README.md) records
valid behavior and the pinned compiler's second-alias-layer limit.

Run the V checks with the repository's pinned compiler:

```sh
VEXE=/Users/alex/.cache/v/v1-fallback/0.5.2/v \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v test zigimg
```

The JPEG contract comparison covers 15,805 returning observations, thirty strict
panic/state pairs, three inherited file-discard loops and reader constructors in
ordinary/production builds:

```sh
python3 zigimg/verify_jpeg_contracts_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2
```

Append `--v-prod` for production. Reproduction, hashes and the separate inherited
quantization-header compiler boundary are documented in
[the JPEG probe notes](reference_probes/jpeg_contracts/README.md).

JPEG public record construction, mutation, header-slice aliases and tagged
quantization tables match 17,747 additional returning observations in both modes:

```sh
python3 zigimg/verify_jpeg_records_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2
```

Append `--v-prod` for production. Required-field and immutable-binding rejections,
the tagged-table API, and measured boxed-copy/const-slice/wider-carrier differences
are documented in [the JPEG record notes](reference_probes/jpeg_records/README.md).

The public JPEG Frame API now has mutable blocks, fixed borrowed table records,
u32 dimensions, usize sampling factors and value-returning reads. Its direct
rendering, chroma, dequantization and IDCT comparison matches 10,697 observations,
35 exact panic/state pairs and three inherited zero-step loops in both modes:

```sh
python3 zigimg/verify_jpeg_frame_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2
```

Append `--v-prod` for production. Constructor checks, copy/borrow behavior,
table wrapper usage and measured representation limits are documented in
[the JPEG Frame notes](reference_probes/jpeg_frame/README.md).

JPEG Scan now exposes its required mutable records, fixed component slots,
component reader, initializer and scan operation. Direct parsing, record copies,
baseline/progressive scans and failure order match 76,400 observations and 27
panic/state pairs in ordinary and production builds:

```sh
python3 zigimg/verify_jpeg_scan_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2
```

Append `--v-prod` for production. Required-field checks, V optional-slot update
syntax, measured const/u4 differences and undefined Source boundaries are
documented in [the JPEG Scan notes](reference_probes/jpeg_scan/README.md).

JPEG retained state across failed reads and retries matches 6,138 returning rows
(6,408 read attempts) and 60 panic/state pairs in ordinary and production builds.
The decoder preserves Source's null-pixel panic after coefficient finalization:

```sh
python3 zigimg/verify_jpeg_state_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2
```

Append `--v-prod` for production. Table installation order, pixel cleanup, caller
reset controls and undefined/freed-memory exclusions are documented in
[the JPEG state notes](reference_probes/jpeg_state/README.md).

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

The direct format-interface runner checks 49,344 returning cases across all
17 callbacks, every encoder-options tag, eight storage profiles, three option
variants and eight output capacities. It compares error, position and all
destination bytes, then isolates PNG/TGA's wrong-option traps:

```sh
python3 zigimg/verify_format_interface_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2
```

Result SHA-256:
`578f0de4bdaac7c2b67f294de64a2694c069cbb2fde6d2c43ca68494c6ca94eb`.

The generic fixed-storage runner compares 2,373 resize/borrow/retained-view
cases for six capacities and byte, word and RGBA elements, then verifies the
checked resize bound:

```sh
python3 zigimg/verify_fixed_storage_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2
```

Result SHA-256:
`ba652143ec8ea584ce4522ed61dc6605986e90185c524ce8b13281b40b642c0b`.

The utility runner compares 20,992 magic-number and native-layout struct-read
cases, including nested byte/word enums, both byte orders, invalid enum
consumption, truncated input and non-exhaustive PNG fields. It also checks two
shift traps and confirms both inherited struct-writer compilation failures:

```sh
python3 zigimg/verify_utils_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2
```

Result SHA-256:
`92204900e01795200a4b2585d19fb2ec6476f17ab099c4e3cfac3e6036346c3f`.

Color and matrix source comparisons:

```sh
python3 zigimg/verify_color_models_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2
python3 zigimg/verify_math_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2
python3 zigimg/verify_color_science_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2
python3 zigimg/verify_color_space_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2
python3 zigimg/verify_color_methods_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2
python3 zigimg/verify_math_generic_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2
```

| Runner | Returning cases | Result SHA-256 |
|---|---:|---|
| Color models | 31,167 | `dc4e15c78150f3ce178a6fa9eab1f953d5ea3647239753ea7eb18648a805504f` |
| Named matrices | 12,419 | `23be1b2c20e279a493dda64087e1916b58e6fdbc8bdcb76469c15b7231a4fb31` |
| Scientific colors | 6,961 | `d97550d49bb60cf224fc60999d3603d6199aa9c99702a7c79b8d7ca9f10e8566` |
| RGB colorspaces | 5,792 | `262e3417fd251373234d20d0b06d7fe53adc63028db4a708a71d99677cf9d6a0` |
| Color methods | 35,362 | `d0e9543322de17f813724ff1ed5b51793a68277be165a96bf4266ae17461adf3` |
| General matrices | 6,467 | `f303b568d8901d722b61cb805d2ccd212e57c10a758d2b530f15ab4d710e9c0f` |

The color-method runner includes custom target constructors, packed aliases,
mixed numeric inputs, all built-in constructors/getters and premultiplication
across 35,362 returning cases.
It also verifies four checked component-width traps and twenty-one ordinary
compile rejections, including unsupported float-to-wide-integer scaling.
The general matrix runner also checks three invalid input shapes.

Appending `--v-prod` to these runners retains the same hashes with
V's production optimization.

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
The newer [record proof](reference_probes/tga_records/README.md) verifies these
guards in both ordinary and production builds, with retained state and failure order.

The [stream guard proof](reference_probes/stream_guards/README.md) preserves exact
capacity/toss and arithmetic diagnostics, including rebasing and failed cursor
order. Both modes match 994 returning controls and 155 panic/state pairs. Existing
stream, GIF and buffered TGA hashes remain unchanged; wider failed cursors retain
their documented V representation limit.

The [PNG filtering bounds proof](reference_probes/png_filter_bounds/README.md)
preserves exact pixel-range, packed-byte and word-index diagnostics, including
conversion before output and retained earlier rows. Both modes match 12,076
returning records and 967 panic/state pairs. Historical filtering hashes and
Source's packed clipping/shorter word destinations remain unchanged.

The [XBM stream proof](reference_probes/xbm_streams/README.md) preserves caller
buffers when a delimiter refill has room at the tail. Both modes match 87,419
returning records / 181,446 calls, with 24 bounded detector-loop pairs. Buffered
file reads, retries, generic interfaces and pinned no-op writers are covered;
historical XBM and stream hashes remain unchanged.

The [GIF loop-count proof](reference_probes/gif_loop_count/README.md) preserves
exact Source slice/load diagnostics for short recognized application data. Both
modes match 160,902 returning records / 171,072 calls and 112 panic/state pairs,
covering every 16-bit count, identifier/code bytes, first-match precedence and
live data mutations. Historical GIF hashes remain unchanged.

The [Raster stream proof](reference_probes/ras_streams/README.md) compares buffered
file decoding, planar palettes, partial RLE output and repeated failures. Both
modes match 112,257 returning records / 224,514 calls and 367 exact panic/state
pairs. Native-observed consumer regressions cover retained output and palette
assignment boundaries; historical Raster hashes remain unchanged.

The [BMP stream proof](reference_probes/bmp_streams/README.md) compares buffered
file reads/writes, pending headers and retained caller buffers. Both modes match
28,826 records / 57,652 calls and 188 exact panic/state pairs. Consumer regressions
pin BGR/BGRA writer layouts, positional read-ahead and caller flush after errors;
historical BMP hashes remain unchanged.

The [PCX file-writer proof](reference_probes/pcx_streams/README.md) compares
31,926 records / 63,852 calls, 67 returning controls and 523 exact panic/state
pairs in both modes. Explicit writer bounds checks preserve Source diagnostics
and partial output in production. A native-observed file regression pins retained
header/body bytes and cross-block RLE runs; historical PCX hashes remain unchanged.

The [IFF file-stream proof](reference_probes/iff_streams/README.md) compares
44,982 records / 89,928 calls, 3,844 returning controls, 463 exact panic/state pairs
and twenty bounded discard-loop pairs in both modes. Consumer regressions pin
retained chunk/plane buffers and partial ByteRun2 output; historical IFF hashes
remain unchanged. The existing implementation needs no changes for these cases.

The [GIF file-stream proof](reference_probes/gif_streams/README.md) compares
13,316 records / 26,632 calls, 2,634 returning controls, 738 exact panic/state
pairs and twelve bounded plain-text discard-loop pairs in both modes. Consumer
regressions pin frame/main-image sharing and retained buffers after incomplete
application data. Historical GIF hashes remain unchanged; these cases require
no production implementation changes.

The [SGI direct file-stream proof](reference_probes/sgi_streams/README.md) compares
16,076 records / 32,072 calls, 256 returning controls and 888 exact panic/state
pairs in both modes. Initialized caller output extends malformed RLE coverage to
small positional file buffers; consumer regressions pin unwritten output, retries
and pending no-op writer bytes. Historical SGI hashes remain unchanged, with no
production implementation changes needed for these cases.

The [TGA file-writer proof](reference_probes/tga_writer/README.md) compares
25,624 records / 51,248 calls, 1,060 returning controls and 1,278 exact panic/state
pairs in both modes. Explicit writer guards preserve Source diagnostics after
partial output, including full usize row indices. Consumer regressions pin
extension offsets, retained buffer tails and header retries before caller flush;
historical TGA hashes remain unchanged.

The [public image file proof](reference_probes/image_files/README.md) compares
managed/unmanaged handle/path writes across all seventeen encoders, including
repeated positional writes, path truncation, live borrowed descriptors and
initialized caller buffers. PNG invalid-header failures preserve the exact native
panic in production. The proof matches 19,584 returning records, 768 returning
controls and 384 exact panic/state pairs in both compiler modes.

The [public image read proof](reference_probes/image_read/README.md) compares
managed/unmanaged file/path/memory reads and detection, borrowed descriptor
ownership, repeated calls and retained buffers. It matches 18,040 returning
records, 2,182 returning controls, 948 exact panic/state pairs and 40 bounded
native XBM loop pairs in both modes; complete samples decode sixteen formats.

The [public image pipe proof](reference_probes/image_pipe/README.md) compares
managed/unmanaged encoders, detection and reading on actual POSIX pipes. Uncached
invalid descriptor size queries retain Source's BADF unreachable panic in
production. Both modes match 7,344 returning records, 384 returning controls and
600 exact panic/state pairs, including repeated streaming transitions and
unconsumed input after rejected reader seeks.

The [public image FIFO path proof](reference_probes/image_fifo/README.md) compares
managed/unmanaged encoding, reading and detection through actual named POSIX FIFO
paths, including fresh opens, descriptor cleanup, preserved queued prefixes and
repeated streaming transitions. Both modes match 6,960 returning records, 384
returning controls and 192 exact panic/state pairs. Consumer regressions pin
unconsumed read failures, PNG signatures and pinned no-op GIF writes; existing
pipe hashes remain unchanged. These cases need no production changes.

The [public image path-failure proof](reference_probes/image_path/README.md)
preserves POSIX open error names and rejects embedded NULs before opening or
truncating files, including production builds. Both modes match 12,160 returning
records, 264 returning controls and 224 exact panic/state pairs. Consumer tests
pin error precedence and unchanged buffers/files; historical regular-file and
FIFO path hashes remain unchanged. Windows path-error behavior remains separate.

The [public image open-contract proof](reference_probes/image_open/README.md)
preserves POSIX close-on-exec at the actual open and checks descriptor access,
creation modes, umasks and aliases. Both modes match 9,792 returning records,
144 controls, 72 exact panic/state pairs and 48 bounded reader-loop pairs; real
exec children confirm that private image descriptors are not inherited. Historical
path-error and FIFO hashes remain unchanged.

The [interrupted public path proof](reference_probes/image_eintr/README.md) checks
actual SIGUSR1 interruptions of blocking POSIX FIFO opens across both public APIs.
Both modes match 1,680 records / 3,360 calls, 24 returning controls and 44 exact
panic/state pairs. Real EINTR calibrations and a retained V copy with its retry
branch disabled demonstrate that the retry path is exercised. Consumer tests pin
output, retained buffers and descriptor cleanup; these cases need no production
changes, and historical FIFO hashes remain unchanged.

The [private image close proof](reference_probes/image_close/README.md) preserves
native POSIX BADF traps after double/copy/invalidated closes, including production.
Both modes match 328 records / 656 closes and 264 exact panic/state pairs. Consumer
regressions pin pending writer bytes, explicit delivery and retained reader
read-ahead after closing a shared descriptor. Historical public open/exec and FIFO
hashes remain unchanged; borrowed file ownership stays with the caller.

The [image terminal proof](reference_probes/image_tty/README.md) preserves native
POSIX ENXIO streaming fallback for slice reads, buffered reads and writes. Both
modes match 853 records / 1,693 calls, twelve returning controls and 22 exact
panic/state pairs. Isolated pseudo-terminal sessions verify reader O_NOCTTY,
writer acquisition and descriptor cleanup; real calibration and a reversed
NOCTTY branch confirm these paths are exercised. Historical FIFO and full stream
hashes remain unchanged; Windows runtime and other terminal disciplines remain
outside this native proof.

The [forward stream transition proof](reference_probes/stream_transition/README.md)
preserves nonzero reader offsets after an owned descriptor is replaced with a
pipe, including partial discard progress, cached EOF size and sticky failure.
It also restores whole-buffer refill after a short buffer is fully consumed.
Both modes match 2,139 records / 4,278 primary operations; reader and writer retries,
pending bytes and queued input agree with pinned Zig. Historical full stream,
guard and terminal hashes remain unchanged. Controlled replacements leave
concurrent descriptor reuse and Windows runtime outside this proof.

The [absolute streaming seek proof](reference_probes/stream_seek/README.md)
preserves native forward discard, cleared read-ahead, cached seek errors and BADF
traps after controlled descriptor replacement. Both modes match 3,723 records /
18,615 primary operations, 54 returning controls and eighteen exact panic/state
pairs. Partial EOF/WouldBlock seeks leave buffered bytes readable. Historical
full-stream, guard and forward-transition hashes remain unchanged; concurrent
reuse and Windows runtime remain outside this native proof.

The [reader discard proof](reference_probes/stream_discard/README.md) preserves
cached-size physical seeks, failed-seek caches, read-ahead consumption and BADF
traps after controlled descriptor replacement. Both modes match 5,670 records /
28,350 primary operations, 74 returning controls and sixteen exact panic/state
pairs. Actual EOF/WouldBlock failures retain progress, and seek-based discard can
pass the replacement file's EOF as pinned Zig does. Historical stream, guard,
transition and absolute-seek hashes remain unchanged. A supplemental native case
and consumer regression confirm that a nonregular size query preserves an already
failed reader, leaving subsequently queued bytes untouched.

The [writer seek proof](reference_probes/writer_seek/README.md) preserves the exact
native BADF seek panic in production and checks flush precedence, cached seek
failures after descriptor restoration and sticky writer failures with pending
bytes. Both modes match 6,912 records / 34,560 primary operations, 196 returning
controls and sixty exact panic/state pairs. Historical stream matrices retain
their previous hashes.

The [original-file read-ahead proof](reference_probes/reader_prefill/README.md)
preserves checked logical-position subtraction after failed buffered transitions.
Both modes match 11,016 records / 33,048 primary operations, 264 returning controls
and 216 exact position-panic/state pairs. Mixed original/pipe bytes, retained
read-ahead, sticky retries and the pinned relative-seek workaround agree with Zig;
historical stream matrices retain their hashes.

The [delimiter failure proof](reference_probes/reader_delimiter/README.md) preserves
consumed buffer cursors after a failed refill, allowing relative seeks to recover
original bytes as pinned Zig does. Both modes match 9,764 records / 29,292 primary
operations, 264 returning controls and 216 exact position-panic/state pairs.
Historical stream and XBM hashes remain unchanged.

The reader adapter also exposes `peek_delimiter_exclusive` and
`take_delimiter_exclusive`. Both return a nonempty EOF tail; exclusive takes
leave a found delimiter unread, including successful empty results at the cursor.
The [exclusive delimiter comparison](reference_probes/reader_exclusive/README.md)
covers 22,244 returning records / 79,212 calls per mode, plus 264 returning
controls and 216 exact position-panic/state pairs. Initialized buffers, copied
results, pending bytes, failure order and controlled pipe ownership match the
pinned Source. The subsequent nullable delimiter checkpoint below adds `takeDelimiter`.

`take_delimiter` consumes a found delimiter and returns `!DelimiterResult` with
an optional `line` field. A present empty line differs from absent input; a final
nonempty EOF tail is returned once. ReadFailed and StreamTooLong remain errors.
The [nullable delimiter comparison](reference_probes/reader_delimited/README.md)
covers 25,052 returning records / 90,444 calls per mode, plus returning and exact
failure controls. The result record adapts Source's error-union/optional-slice
type; the proof documents V's mutable-alias extraction rule.

`discard_delimiter_exclusive`, `discard_delimiter_inclusive` and
`discard_delimiter_limit` now scan across buffer fills and return consumed counts.
Exclusive discard leaves a found delimiter unread and succeeds at EOF; inclusive
discard counts the delimiter and fails after consuming an unterminated EOF prefix.
A bounded scan fails as soon as its limit is reached, before checking the next
byte or EOF. The [delimiter discard comparison](reference_probes/delimiter_discard/README.md)
covers 73,224 returning records / 263,604 calls per mode, 1,444 returning controls
and 16 exact zero-capacity panic/state pairs. The `usize` limit adapts Source's
`std.Io.Limit`; existing delimiter and stream hashes remain unchanged.

`stream_delimiter`, `stream_delimiter_ending` and `stream_delimiter_limit` append
a prefix into a writer and leave the delimiter unread. Each reader span advances
only after its complete write succeeds, preserving partial output and unread
input on writer failure. The required-delimiter method fails at EOF after writing
the tail; ending and bounded methods return its count. Zero/exhausted bounds fail
before checking input or output. The [delimiter streaming comparison](reference_probes/delimiter_stream/README.md)
covers 49,500 returning records / 247,500 primary calls per mode, 84 returning
controls and 120 exact panic/state pairs. Memory, files, nonblocking pipes and
partial failures match pinned Zig; prior delimiter and stream hashes are unchanged.

The reader adapter now exposes `buffered`, `toss_buffered`, `fill`, `peek_greedy`,
`peek_byte` and `take_byte_signed`. Pending-byte access and zero-count operations
avoid reading, greedy peeks return all read-ahead, and signed takes preserve the
byte's bit pattern. The [buffered reader comparison](reference_probes/reader_buffered/README.md)
covers 14,784 returning records / 59,136 calls per mode, 412 mutable borrow records,
472 returning controls and 216 exact panic/state pairs. Historical delimiter and
stream matrices retain their hashes.

`fill_more` rebases for one extra byte and invokes the reader callback once.
A positional-to-streaming transition can succeed without reading bytes; pending
EOF tails and sticky failure cursors follow pinned Zig. The
[single-callback fill comparison](reference_probes/reader_fill_more/README.md)
covers 3,794 returning records / 11,382 fills per mode, 350 returning controls,
226 exact panic/state pairs and 17 concrete consumer records. Existing scalar
and vector helpers and historical stream hashes remain unchanged.

`peek_int` decodes a native integer without consuming bytes; `take_var_int`
consumes a chosen width and zero-extends short representations, including into
signed types. Zero-width reads succeed without IO, and excessive widths trap
before filling. The [integer reader comparison](reference_probes/reader_integer/README.md)
covers 56,640 returning records / 169,920 integer reads per mode, 808 returning
controls, 1,048 exact panic/state pairs and 17 consumer records. Native integer
and endian aliases are included; arbitrary-width Source integers remain a
documented carrier boundary.

`take_leb128` decodes signed or unsigned native integers, accepts valid overlong
representations and consumes through the terminator before reporting overflow.
Truncated input or read failure retains consumed progress. The
[LEB128 comparison](reference_probes/reader_leb128/README.md) covers 72,030
returning records / 216,090 decodes per mode, 192 returning controls, 272 exact
panic/state pairs and 20 consumer cases. Mathematical value/progress checks cover
every nonreplacement record, including the 70-bit intermediate for 64-bit types.

`discard_short` returns the consumed prefix at EOF, `discard_remaining` drains
until the callback reports EOF, and `discard_all64` requires the requested u64
count in target-usize chunks. Partial read failures retain progress; checked
cursor overflow traps before mutation. Source's cached positional EOF loops are
preserved. The [short/remaining/64-bit discard comparison](reference_probes/reader_discard_short/README.md)
covers 24,400 returning records / 73,200 discards per mode, 102 returning
controls, 102 exact panic/state pairs, 12 bounded loop observations and 21
consumer cases. Historical discard, buffered-reader and stream hashes remain
unchanged.

`read_slice_endian` fills a native integer slice before converting each element
from the requested byte order. Failed reads retain the copied raw prefix without
swapping; empty slices succeed without IO. Integer and endian aliases are
supported. The [endian slice comparison](reference_probes/reader_slice_endian/README.md)
covers 50,088 records / 150,264 reads per mode, 672 returning controls, 672 exact
panic/state pairs, 21 consumer records and six paired compile rejections.
Destination guards and partial updates match pinned Zig. Aggregate elements and
byte spans beyond V's array length remain documented boundaries.

`read_alloc` and `read_slice_endian_alloc` return GC-managed byte/integer arrays.
Each successful nonempty result owns separate storage; failed reads retain
reader progress and return no partial result. Typed reads convert byte order
only after complete input. The [allocated reader comparison](reference_probes/reader_alloc/README.md)
covers 27,585 records / 82,755 reads per mode, 96 returning controls, 168 exact
panic/state pairs, 21 consumers and six paired compile rejections. Explicit
allocator selection, OOM errors and immediate failure cleanup differ from Source
and remain documented boundaries.

`peek_array[A]` and `take_array[A]` expose borrowed fixed byte arrays through
`ReaderArray[A].value`. Peek preserves position; take consumes only a complete
array. Pointer mutation reaches the caller's buffer, and failed fills preserve
pending input. The [fixed-array reader comparison](reference_probes/reader_array/README.md)
covers 20,448 records, 1,252 mutation/alias records, 120 controls and 16 consumers
per mode. V's fallible pointer result, zero-array and chained-alias limitations
are documented with the mapping.

`peek_sentinel` and `take_sentinel` require the requested byte, including at EOF.
`SentinelSlice.bytes()` borrows the prefix; `with_sentinel()` includes its final
byte. Taking an empty prefix consumes that sentinel. The
[sentinel comparison](reference_probes/reader_sentinel/README.md) covers 12,192
records, 3,120 mutation/alias records, 132 controls and 23 consumers per mode.
V uses a runtime marker and an opaque record; comptime typing and oversized
literal conversion differences are documented separately.
