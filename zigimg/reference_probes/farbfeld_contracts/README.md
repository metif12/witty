# Farbfeld checked dimensions and retained stream state

`verify_farbfeld_contracts_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Source Debug against ordinary V,
and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_farbfeld_contracts_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The runtime comparison uses
the native 64-bit little-endian `aarch64-macos.14.0` target. `--timeout` bounds each
command; `VTMP` can select V compiler temporaries. Artifacts retain binaries,
commands, outputs, input hashes, panic snapshots, provenance and a JSON summary.

Source `writeImage` casts width and height to u32 before checking pixel storage
or writing bytes. V now preserves the checked cast in production. The direct
writer rejects every storage variant except rgba64 before writing the header,
then emits the entire pixel slice without reconciling its length with header
dimensions. Zero, inconsistent and maximum u32 dimensions remain accepted when
the casts fit. Memory streams preserve completed header/pixel prefixes on failure.

| Returning observations | Count |
|---|---:|
| Default header/codec, native header size/bytes and independent header copies | 26 |
| Direct/image writes across all 24 valid storage tags | 43,200 |
| Every prefix of eight small image fixtures through direct/image reads | 1,024 |
| Successful reads preserving trailing input | 16 |
| Wide u32 dimensions paired with zero extents | 8 |
| Every corrupted magic byte through direct/image reads | 16 |
| Detection over valid/corrupted magic prefixes at two initial cursors | 182 |
| Valid image writes with short/exact buffers and nonzero initial cursors | 63 |
| **Total** | **44,535** |

Header/write matrix SHA-256:
`30e565c1698cf8f2571c3405cc15e428acd7036147fa212e996733267dea1b33`.
Other returning records SHA-256:
`37dc326a7a00abc25b65792b07f77531565d3208007ad1425e21df2a3d63db35`.

The write matrix uses zero/one/two initialized pixels, all 25 combinations of
width/height 0/1/2/2^31/u32 maximum, capacities 0/1/7/8/15/16/17/23/24/31/32/33,
and both public write entry points. It compares status, cursor, the entire
initialized caller buffer, header bytes and unchanged input pixel bytes. Valid
narrow fields are masked; inactive indexed palettes are never observed. Every
caller output byte starts at 165.

Read fixtures cover zero extents and one/two/four/six pixels. Prefix tests begin
at cursor zero or after consuming three initialized prefix bytes, including an
EOF cursor. Truncated magic/header reads retain the initialized previous header
where Source does; truncated bodies retain the newly parsed header and completed
pixel-read cursor. Failed/freed private pixel allocations are excluded. Returning
reads compare dimensions, rgba64 storage and native channel bytes. Nonempty
results must occupy storage outside the input allocation; changing their first
byte preserves the full input while exposing the changed result. Empty pointer
identities are unobserved. Detection preserves the initial cursor.

**240 strict panic/state pairs** cover width-only, height-only and simultaneous
cast failures, values 2^32/2^32+1/2^63/usize maximum, supported rgba64 and unsupported
rgb24/invalid storage, empty/short/ample buffers and nonzero initial cursors.
Snapshots compare unchanged image dimensions, storage tag/length/bytes, writer
cursor and the entire caller buffer. Exact panic text, nonzero exit, no stdout,
no unexpected return and no core dump are required. Names, exact panic text and
state are included in the locked failure SHA-256:
`ac87959369cc8d77564382026061029c1d58bce6f7c6266cdd616e6a9ee5b287`.

File buffering and retained caller bytes are checked separately by the
[QOI/Farbfeld stream proof](../binary_codecs/README.md); this fixture uses memory streams.

Allocator/OOM/GC/lifetime, wider allocated pixel counts, pointer/slice layout,
boxed storage copies, big-endian bulk writes, Source allocator and
ignored encoder-options arguments, and portable ABI remain boundaries. The
native header byte check does not establish portable record layout. Cross builds
do not establish runtime parity. No Source visibility or implementation changes
are made.

Full Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`. The runner
checks Zig 0.15.2/V 0.5.2, generated inputs and before/after fixture, runner and
implementation hashes. All native fixtures import the unchanged pinned sources.
