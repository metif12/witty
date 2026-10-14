# Sun Raster positional file streams and retained decoder state

`verify_ras_streams_reference.py` compiles unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Debug against ordinary V and
ReleaseSafe against production V. Compilers are Zig 0.15.2 and V 0.5.2.

```sh
python3 zigimg/verify_ras_streams_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The default runtime target
is `aarch64-macos.14.0`, linked with libc. `--timeout` bounds commands. Artifacts
retain unchanged Source, fixtures, binaries, inputs, raw output, commands and
provenance; `TMPDIR`/`VTMP` select compiler temporaries.

Both modes match **112,257 returning/error records / 224,514 calls**:

| Returning records | Count |
|---|---:|
| Every RLE flag, truncated input and short output | 7,680 |
| Every RLE count, escape/run prefixes, clipping and output lengths through 257 | 71,680 |
| Raw/unsupported compression, partial output and file buffering | 2,285 |
| Planar palettes, partial planes, ignored remainder bytes and map dispatch | 2,475 |
| Public direct/static/interface decoding, formats, dimensions and map dispatch | 12,120 |
| Public header/palette/body prefixes, initial discard and retries | 13,440 |
| Maximum u32 width with zero height | 60 |
| Unsupported depth before palette checks | 405 |
| Every detector first byte | 2,048 |
| Detector partial magic, EOF and initial discard | 64 |
| **Total** | **112,257** |

Returning SHA-256:
`24e88e917661659d42a811e1ac966007b1ab68e789e96b88991feac2e2b27cc2`.

Every case makes two calls on the same stream and direct codec. Helpers use
memory and file buffers 0, 1, 3, 4, 8, 16, 28, 32, 64 and 128; public readers use
memory/file 28, 32, 64 and 128, with smaller buffers tested as checked failures.
Descriptors begin at EOF independently of the positional stream cursor. Public
readers cover depths 1/8/24/32, all compression tags, zero/odd dimensions, absent/
planar/unsupported maps, one-bit row padding and polarity, RGB/BGR selection,
opaque RGBA conversion, ignored declared image length and trailing bytes.

**367 exact panic/state pairs** cover fifteen undersized magic buffers, twelve
undersized header buffers, 27 parsed-enum failures, twenty direct and 180 public
palette-capacity failures, 108 one-bit indexed slice failures, and five zero-byte
RLE reader buffers. The Source capacity trap occurs before reading a byte even
at EOF; these RLE cases are excluded from returning records. Each pair requires
failed exits, no stdout, the exact sole message from compiled Source and equal
nonempty snapshots. State SHA-256:
`d728a122e314600960d6ffbce39ff896bd24bef7e61f9d8c2c917f7ef55e28a4`.

Snapshots compare logical position, buffered length, all initialized caller
buffer/output bytes, unchanged input, direct public header and active palette.
Returning records also compare disk bytes, decoded pixels and active pixel
palettes before/after mutation. All 256 caller palette entries are initialized
before shrinking its active length to four; later resize failures/partial reads
never expose undefined backing. Palette entries are assigned only after the
complete planar buffer has been read. Grayscale1 uses semantic values to exclude
narrow-field padding. Private failed/freed decoder buffers, default readImage
codec fields, pointer identities and inactive allocation bytes are excluded.

Consumer regressions retain the native three-byte RLE buffer, a decoded escaped
`0x80`, and earlier output bytes after a retry reaches EOF. A short planar palette
read resizes the active slice to two entries while preserving both seeded colors
and every caller buffer byte, including a second failed read. Separate compiled
Source/V controls compare those exact regression inputs in both modes.

Full Source tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`;
selected compiler-library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Versions and before/after Source/library/implementation/fixture/runner/helper/input
hashes protect final comparisons. The codec implementation needs no change;
historical Raster record, decoder, state and diagnostic hashes remain unchanged.

Custom/nonseekable readers, pipes, operating-system I/O failures, larger allocated
extents, allocator/OOM/GC/lifetime, const/narrow/boxed representation, physical
layouts, big-endian/32-bit runtime and portable ABI remain boundaries. Cross
builds establish compilation coverage only. The existing
[Raster contract proof](../ras_contracts/README.md) covers memory constructors,
writer behavior and broader scalar/diagnostic controls.
