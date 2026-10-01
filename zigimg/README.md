This is an incremental V translation of zigimg revision
`d7b7ab0ba0899643831ef042bd73289510b39906`, the dependency locked by pinned
vaxis. It currently covers the pixel-format words, storage variants, raw and
indexed storage, memory and bit streams, crop/flip editing, pixel iteration,
QOI, farbfeld, PBM, PGM, PPM, PAM, Sun raster, SGI, XBM, PCX, BMP, and IFF codecs,
PackBits/LZW/CCITT compression helpers, and the pinned PNG writer. It does not
yet provide the complete image library or vaxis loading.

The PNG writer in this exact revision emits only the eight-byte signature;
its chunk-writing bodies are commented out. Native reference execution and V
tests preserve that behavior, including fixed-buffer failures.

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

PackBits preserves declared-length truncation, unclipped runs, and its unread
final lone control byte. LZW retains endian selection, clear/end codes, early
change, dictionary mutation order, partial-input state, and source handling of
unknown codes and empty resumptions. CCITT retains all 195 code entries, color
across rows/calls, cumulative padding, and its absent final partial-byte flush.
Their sub-byte state uses wider V backing values. LZW maps and GC replace the
source dictionary and arena; `lzw_decoder_init[E]` works around the pinned V
compiler's static-constructor specialization defect inside generic callers.

V arrays and GC replace allocator slices. Sub-byte scalar values use byte
storage or packed backing words. Allocation errors, every color conversion
method, file streams, decoding other formats, format dispatch, and the
remaining managed image APIs still require translation.

Cropping copies the active indexed palette and pixel rows into independent
storage and does not copy animation data. Flipping mutates the existing pixels.
Pixel iterators borrow the live storage and capture its length at initialization;
the caller must keep that storage alive. They normalize integer channels without
premultiplying alpha and preserve floating point values.

PBM/PGM/PPM preserve the pinned parser's comments, 16-byte number buffer,
single raster delimiter, bitmap polarity/padding, and format-specific sample
scaling. They expose per-codec options while the image-wide encoder-options
union remains untranslated. The bit streams specialize on `BigEndian` or
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

IFF checked bounds use separate process probes. Build the V executable from
`zigimg/reference_probes/iff_bounds` and the locked-source Zig executable from
its `reference.zig`, using the same module and target options above, then run:

```sh
python3 zigimg/reference_probes/iff_bounds/verify.py /path/to/v-probe /path/to/zig-probe
```

They verify stride overflow, an out-of-bounds padding bit, empty CMAP, and HAM
palette reduction below four bits. The native harness uses synthetic images;
upstream binary fixture files are absent from the locked source archive.
