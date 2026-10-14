# Netpbm required records, arithmetic and complete-row failures

`verify_netpbm_contracts_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Source Debug against ordinary V,
and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_netpbm_contracts_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The default runtime target is
native 64-bit little-endian `aarch64-macos.14.0`. `--timeout` bounds each command;
`VTMP` and `TMPDIR` can select compiler temporaries. Artifacts retain binaries,
commands, outputs, input/consumer hashes, panic snapshots, provenance and a JSON
summary. Compiler controls require actual matching error lines; compiler crashes
or unrelated errors do not count.

All five header fields are required. Shared direct encoder options and the three
registry option wrappers preserve Source's mutable `binary` field and true
default. Pixel-count multiplication is checked after assigning the complete
parsed header and choosing the pixel format, before allocating pixels. Linearized
samples retain checked usize multiplication and division by zero after their
required reads; ASCII RGB parses all three component tokens before normalization.
Binary PBM checks the complete row before writing any of its bits. The pinned
compiler combines Source's nested slices, reporting an absolute end and the full
sample length, including a failure after already flushed rows.

| Returning records | Count |
|---|---:|
| Initialized headers, independent scalar copies and format dispatch | 432 |
| All P1..P6 headers, row shapes, scaling and raw/truncated samples | 7,128 |
| Every byte value across binary gray/RGB max-value boundaries | 55,296 |
| ASCII numbers, signed zero, underscores, comments and invalid tokens | 2,472 |
| Header/raster prefixes and short reads before arithmetic | 4,116 |
| Zero extents, including maximum fitting 16-character dimensions | 216 |
| Wrong magic, whitespace/comment/number limits and validation order | 204 |
| Every first detection byte and supported/invalid second bytes | 6,144 |
| Short detection and trailing-input controls | 9 |
| Direct/static/interface encoding, all 24 storage tags and output capacities | 59,616 |
| All 17 registry option tags across the three codecs | 1,020 |
| Direct format rejection, max-value and initial writer-cursor controls | 432 |
| Short output preceding invalid PBM row dimensions | 63 |
| Binary PBM zero-row/zero-width writes | 6 |
| Wide dimensions independent of gray/RGB pixel slices | 72 |
| Default/mutated option records | 2 |
| **Total** | **137,228** |

Decoder/header/writer SHA-256:
`4118a6e16700c47662af2df6322aaf95bc166def639588c2f87410785b4a9da9`.
Option default/mutation SHA-256:
`91d67440ca5ce2fee2309c9b5ca5e2a28b6ac2aa5ff927010127c0a911e10b73`.

Returning decodes compare fully written pixels before and after toggling their
first valid bit, allocation independent of input, and unchanged caller bytes.
Failed private/freed pixel allocations are excluded. Initial public headers are
fully initialized and their scalar fields are compared, with no padding bytes.
Writer records retain every initialized output byte, cursor and unchanged input
pixel bytes. Narrow Source pixel fields contain valid values; unsupported palette
storage is never inspected. No empty pointer identities are compared.

**969 strict panic/state pairs** cover 660 zero-divisor failures through direct
and image reads, 288 dimension multiplication failures and 21 binary PBM row
failures through direct/static/interface writes. Exact panic text, unsuccessful
exit, no stdout, no unexpected return and no core dump are required. Case names,
full diagnostics, reader/writer cursors, initialized public header fields, caller
output and unchanged input join SHA-256
`03232409ef93ef7c3ff22f197b43c67876c19dd9d0b1cb0ac22fc140e0a0aa09`.

One complete header constructor, five field omissions, three default codec
constructors, four mutable option controls and four immutable-binding rejections
pass compiler controls. The shared direct option type and distinct registry
wrappers are V call-shape adaptations to Source's three nested option types.

All readers continue to accept every P1..P6 header independently of their codec
specialization. Writers still reject a mismatched header format before output,
then write a complete header before rejecting unsupported storage. Gray/RGB and
ASCII bitmap writers use the full pixel slice independently of dimensions;
binary bitmap writers use complete padded rows. ASCII bitmap input treats each
non-whitespace byte other than `0` as black, including comment bytes in the raster.
Only the header/numeric parser skips comments. One delimiter terminates numbers,
so CRLF can leave LF as a binary sample. Numeric token capacity remains 16 bytes;
ASCII grayscale truncates without scaling, binary gray16 stays raw, and RGB
normalization deliberately truncates its low byte.

File buffering and partial write results are checked separately by the
[Netpbm stream proof](../netpbm_streams/README.md); this fixture uses memory streams.

Default Source codec headers are undefined. V's initialized placeholder is
unobserved and outside the parity claim. Format enum width, narrow/const typing,
physical record/union/slice layout, boxed copies, allocator/OOM/GC/lifetime,
wider allocated extents, big-endian runtime and portable ABI remain
boundaries. The largest 16-digit ASCII sample does not overflow 64-bit multiplication
by 255; narrower-target normalization overflow is outside the native runtime proof. Cross
builds do not establish runtime parity. Source visibility/implementation remain
unchanged.

Full Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`. The runner
checks Zig 0.15.2/V 0.5.2 and before/after generated-input/consumer, fixture, runner
and implementation hashes. Every native fixture imports unchanged Source.
