# JPEG public Frame contracts

`verify_jpeg_frame_reference.py` compares the public Frame API with unchanged
zigimg `d7b7ab0ba0899643831ef042bd73289510b39906`. Source Debug runs against
ordinary V; Source ReleaseSafe runs against production V.

```sh
python3 zigimg/verify_jpeg_frame_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. `--target` defaults to
`aarch64-macos.14.0`; `--timeout` bounds commands. Set `VTMP` to a directory with
enough space for V compiler temporaries when necessary.

Frame fields, block records and their fixed arrays are public/mutable. Required
Frame fields are its header, three borrowed table records and coefficient storage.
Block wrappers require their payload arrays. The table wrappers hold four optional
slots and provide stable pointees for Source's borrowed fixed-array pointers:

```v
mut jpeg := zigimg.JPEG.init()
mut stream := zigimg.ReadStream.init_memory(header_bytes)
mut frame := zigimg.JpegFrame.read(0xffc0, &jpeg.quantization_tables,
    &jpeg.dc_huffman_tables, &jpeg.ac_huffman_tables, mut stream)!
jpeg.quantization_tables.values[0] = zigimg.JpegQuantization8{
    values: [64]u8{init: 1}
}
frame.dequantize_blocks()!
frame.idct_blocks()
```

`read`, `render_to_pixels`, `render_to_pixels_rgb`, `ycbcr_to_rgb_block`,
`ycbcr_to_rgb`, `dequantize_blocks`, `idct_blocks` and `deinit` are public.
Frame/JPEG reads return Frame values and JPEG retains an optional value. Metadata
and inline arrays copy by value; frame copies share coefficient slices and the
borrowed table records. JPEG copies hold independent inline table slots. Replacing
a slot is distinct from mutating a boxed quantization payload, whose previously
measured copy difference remains documented in [the record proof](../jpeg_records/README.md).

| Returning observations | Count |
|---|---:|
| Public Frame reads, dimensions, sampling, marker choices and truncated headers | 6,952 |
| Direct chroma blocks, separate/aliased storage and sampling offsets | 2,048 |
| Full chroma conversion and RGB dispatch | 256 |
| Direct dequantization and IDCT, padded rows and component counts | 640 |
| Direct RGB/grayscale rendering, cropping and actual storage stride | 784 |
| Constructed frame/JPEG copies and full u32 metadata carriers | 5 |
| JPEG.read returned/stored frame copies and live table replacement | 12 |
| **Total** | **10,697** |

Returning SHA-256:
`02bea61a685969480894de6596bfd0f16c132107369c1bc4ed2f895d4e2509f0`.

Thirty-five strict panic pairs match exact categories and retained state:
header u16 overflow after allocation, invalid enum conversion before header reads,
native-width/i32 overflow and division, chroma lane/row bounds, RGB casts, grayscale
addition, short pixel/block storage, inactive pixel arms, component-count
unreachable and dequantization overflow. Observer state includes consumed stream
position, frame metadata, all initialized coefficients and pixel bytes. RGB field
stores occur in Source order: an invalid green or blue cast retains preceding
channel writes. Pixel destination bounds precede RGB casts; grayscale loads its
coefficient before checking the destination and then adding its level offset.
The chained chroma row slice checks its final eight-lane end against 64.
These checks remain active in production V.

Failure-state SHA-256:
`73fbe0b116d37d3721a82529cfdf615cd69ecc2308879180a9a953e1d97791ea`.

Five complete constructor pairs compile, including execution of the six Frame
zero defaults. Nine omitted represented fields/payloads and five mutations through
immutable bindings receive ordinary compiler rejections. The runner checks actual
error lines and excludes crashes, backend errors and link failures. Three separate
process pairs retain inherited zero-horizontal-step loops in full chroma conversion,
dequantization and IDCT; each must time out without output. They are excluded from
returning counts.

Two construction differences are measured separately: Source permits mutation
through a const Frame's borrowed table pointer while V rejects it, and V's u16
frame marker carrier accepts 65535 where Source's exhaustive enum rejects it.
`JpegFrame.read` explicitly retains the runtime enum check. Source's undefined
default marker is never read by this proof; V's zero default does not represent
that undefined value.

The runner pins the complete Source tree, compiler versions and selected Zig
memory/debug/reader/writer/file/map library files. Source is copied unchanged;
private component types are inferred through existing public fields. Before/after
hash checks protect fixtures, runner and all top-level V image implementation
files. Commands, generated constructor consumers, raw output, failure state,
diagnostics, provenance and summaries remain in the proof directory.

All manually constructed coefficient storage is initialized before comparison.
Frame.read observations inspect metadata and allocation count only, since Source
allocates undefined coefficient storage. JPEG.read copy observations inspect only
the explicitly written active grayscale sample, never unused Source channels.
Allocator/OOM/GC/lifetime behavior, aggregate ABI, arbitrary SIMD targets and
cross-target runtime are outside this proof. Chroma bounds are compared with the
non-AVX2 Source implementation selected by the pinned aarch64 target; Source AVX2
permutation masks have different out-of-range behavior. Const-pointer typing,
boxed quantization payload copies, u4/u5 byte carriers, map typing/layout/order,
remaining public Scan APIs and Scan arithmetic on caller-mutated records remain
adaptations or unverified work. Source
quantization.Header.read still has its inherited Zig 0.15.2 compiler failure.
The pinned JPEG writer still emits no bytes.

The existing 15,805-row decoder proof, thirty failure-state pairs and three
file-discard loops retain their hashes. The 17,747-row record proof and separate
boxed hashes are unchanged. Historical JPEG comparisons retain 132 returning
rows and their marker trap in both modes; seven undefined-coefficient inputs
remain excluded. All 56 image and 58 Vaxis test files pass, along with focused
production Frame tests, native/Linux application checks, three Windows dependency
DLLs, the new Windows test executable in both modes and two Linux shared libraries.
Cross builds use `-gc none` and do not establish cross-target runtime behavior.
