# BMP checked arithmetic, casts and public codec state

`verify_bmp_contracts_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Source Debug against ordinary V,
and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_bmp_contracts_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The default runtime target
is `aarch64-macos.14.0`, with 64-bit usize arithmetic. `--timeout` bounds individual
commands; `VTMP` can select V compiler temporaries. Artifacts retain binaries,
every command and output, panic snapshots, provenance and a JSON summary.

Signed dimension/scanline arithmetic, image byte/file-size arithmetic and integer
casts now use explicit guards in both V modes. Arithmetic overflow retains the
Source diagnostic; a negative or excessive cast reports that the integer does not
fit in the destination type. Pixel accesses check signed addition, conversion and
the actual active extent before array access, retaining Source index/length
diagnostics in production.

The public image writer selects supported storage before computing file size,
then checks dimension casts before writing bytes. Direct writing emits the file
header first, then rejects Windows 3.1 headers or emits V4/V5 headers, then checks
pixel storage and row arithmetic. Short output buffers therefore fail before later
dimension or pixel failures. Readers retain successfully parsed headers, reject
unsupported formats before multiplication/casts and preserve their consumed cursor.

| Returning observations | Count |
|---|---:|
| Defined header defaults and native layout sizes | 1 |
| Signed width/height accessors across all three info-header variants | 75 |
| Pixel-format dispatch across eight bit counts and all ten valid compression tags | 240 |
| Public image/direct codec writers and bounded memory output | 10,368 |
| Direct/image decoder results and recoverable failures | 654 |
| Signed/zero dimensions and error-order controls | 40 |
| **Total** | **11,378** |

The first four groups have SHA-256
`9b413f62c620cdc82ad314065a403fde50455c7eb04bde405c3c0953aff8e064`.
Decoder/control records have SHA-256
`2d19b419f20e31609996f7887a5fd9258e4036c2d5fe2172a728a2d7da9c406d`.

The writer matrix covers BGR24, BGRA32 and unsupported grayscale8, widths
0/1/2/3/8/17, heights 0..3, three initialized byte patterns and twelve output
capacities 0/1/13/14/121/122/123/137/138/139/256/1024. It includes public image
construction and direct Windows 3.1/V4/V5 codec writing. Direct headers contain
unusual metadata and deliberately unsupported bit-count/compression combinations:
Source writing uses the storage variant and ignores those header fields. Every
visible output byte starts at 165 and is compared along with status and cursor,
including partial headers and pixels. Zero-sized buffers never expose pointers.

Decoder records include 480 direct/image successes across both V4/V5 headers,
both pixel layouts, five widths, four heights and three byte patterns. They compare
fully written pixel bytes, dimensions, cursor and direct retained headers. Another
104 records cover truncated headers/rows, 24 cover validation order, 18 unknown
header sizes and four rejected Windows 3.1 headers. Twenty-four direct negative-
dimension records compare only storage lengths, headers and cursors: Source can
allocate unwritten pixel memory on those paths, whose contents are excluded.
Fixtures retain ignored offsets, masks and trailing bytes without adding row padding.

| Strict panic/state pairs | Count |
|---|---:|
| Signed read dimension multiplication | 16 |
| Negative read pixel counts cast to usize | 16 |
| Minimum signed height subtraction during reading | 4 |
| Negative dimensions cast by the image reader after direct decoding | 24 |
| Minimum signed height subtraction after direct header output | 4 |
| Direct signed scanline multiplication, including negative widths | 8 |
| Direct pixel bounds, including wide first-row indices and partial pixel output | 60 |
| Image pixel/byte/file arithmetic and file/dimension casts | 16 |
| Largest tested fitting u32 file sizes proceeding to pixel bounds | 2 |
| Image writer pixel bounds after partial output | 2 |
| **Total** | **152** |

Failure-state SHA-256:
`59aacb757a0572b8742e645599d049965f7df9d2c7715abd1e075bb371510d89`.

Strict checks require the complete expected panic prefix, unsuccessful exit,
no unexpected return and no core dump. Observers compare direct public file/info
headers and read cursors, or writer cursors and initialized output buffers plus
direct headers. Image-reader failures expose only the public input cursor; its
private codec, allocated pixels and partially constructed image are excluded.
Cases near u32 file-size limits use short initialized pixel slices and establish
whether size construction succeeds before a later bounds failure, without large
allocations. Private failed allocations, unwritten/freed storage and allocator
effects are excluded from snapshots.

The runner imports public codec/storage/stream interfaces from unchanged Source
files. Defined header constructors are tested; Source's default BMP codec has
undefined headers and is not inspected. Fixture enum values are all valid Source
tags. V sum-type boxing/copy behavior, enum/const typing, GC versus explicit
allocator ownership, OOM/lifetime, file streams, allocated extents beyond V's array
carrier and portable ABI remain boundaries. Cross-target compilation does not
establish runtime parity. The unchanged historical native BMP harness also passes
Debug and ReleaseSafe; existing V BMP tests cover its defined fixtures.

The runner verifies full Source-tree SHA-256
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`, selected Zig
library SHA-256
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`, compiler
versions (Zig 0.15.2 and V 0.5.2), and before/after fixture, runner and implementation
hashes. Source visibility and implementation are unchanged.
