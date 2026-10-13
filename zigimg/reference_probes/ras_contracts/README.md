# Sun Raster records, palette bounds and retained decoder state

`verify_ras_contracts_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Source Debug against ordinary V,
and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_ras_contracts_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The runtime target is native
64-bit little-endian `aarch64-macos.14.0`. `--timeout` bounds each command; `VTMP`
can select V compiler temporaries. Artifacts retain binaries, commands, outputs,
input/consumer hashes, panic snapshots, provenance and a JSON summary.

All seven header fields are required. Source's private header type is inferred
through the public RAS header field without changing visibility. Little-endian
big-endian header reads validate both enum fields before assigning the public
header. The complete header has already been consumed when these casts trap.
Palette requests above 256 entries preserve Source's slice-end diagnostic before
resize, allocation or input consumption. One-bit indexed images retain raw-byte
copying and the original source-buffer slice failure.

| Returning records | Count |
|---|---:|
| Native header/enum sizes | 1 |
| Initialized headers, width/height and independent header copies | 16 |
| Format dispatch across all valid compression/map tags | 840 |
| Direct/interface no-op writes across all valid storage tags | 1,728 |
| Every RLE flag, truncation and small output capacity | 1,536 |
| Every RLE count, escape/run prefixes, clipping and large output boundaries | 14,336 |
| Raw/unsupported compression and partial fixed-buffer reads | 224 |
| Direct planar palette reads, truncation, remainder bytes and map dispatch | 195 |
| Public image decoding, zero extents and validation order | 23,072 |
| Truncated public headers/palettes/pixel bodies | 816 |
| Wide u32 dimensions paired with zero extents | 16 |
| Wrong magic, detection and incomplete invalid headers | 89 |
| Unsupported map/depth preceding palette capacity checks | 36 |
| **Total** | **42,905** |

Header/dispatch/writer SHA-256:
`5eb7d5959e413859877b0343cb222f90f2555ccf0a80176cb7612508328f0583`.
Decoder/control SHA-256:
`9844e90533766c19eb07668ba6d0f3b9ad46947360dcb233e561161a1d53d493`.
Another **21 debug-print controls** compare all valid compression/map tag pairs,
including their exact enum labels, on stderr. Debug SHA-256:
`e6dc540b17c9a8383a48e25b22e44b27b0ce638a73c1fc64e10a9422992f9c96`.
The [expanded diagnostic proof](../ras_debug/README.md) adds scalar boundaries,
repeated calls, logger independence and unchanged header observations.

The public decoding matrix uses depths 0/1/2/8/16/24/32, all seven compression
tags, widths 0/1/2/3/7/8/9/15/16/17, heights 0/1/2, map types and lengths. It
preserves one-bit row padding/polarity, absent padding for other depths, opaque
32-bit conversion, palette-length-based indexed dispatch even without a map,
ignored declared image length, clipped RLE runs and trailing input. Source's
writer still succeeds without output, including inconsistent/maximum usize image
dimensions and unsupported storage. Output capacities and initial cursors remain.

**576 strict panic/state pairs** cover 448 one-bit indexed slice failures, 12
direct palette-capacity failures, 48 public-read palette-capacity failures and 68
parsed enum failures. Palette lengths include 771/772/773/780/65,535/u32 maximum;
the requested slice end is floor(length/3). Unsupported map/depth controls retain
their precedence. Exact panic text, unsuccessful exit, no stdout, no unexpected
return and no core dump are required. Case names, full diagnostics and snapshots
are locked into SHA-256
`960db8d79a310328d870cefb371f62730d47fc48a4f74ecd8bf09b291afb41c8`.

Snapshots compare reader cursors, initialized public headers, active palettes,
initialized caller output and unchanged input. All 256 inline palette entries
are initialized through the public data slice before shrinking the initial active
length to four. Later expanded active slices therefore remain defined even after
short reads; inactive storage is never observed. Palette reads resize before
reading but assign entries only after the full planar buffer is available.
Private failed/freed pixel/palette buffers are excluded. Successful reads compare
pixels and active palettes before/after mutation, independent nonempty allocation,
unchanged input and unchanged codec palette. Empty pointer identities are excluded.

Compile controls check one complete header constructor, seven individual required
field omissions and default codec acceptance. Actual error lines are required;
compiler crashes or unrelated errors do not count. Generated consumer hashes are
checked before completion.

Default Source headers and inactive inline palette storage are undefined. V uses
an initialized header placeholder to preserve default codec construction; its
contents are outside the parity claim. Direct invalid typed enum values,
big-endian runtime behavior, allocator/OOM/GC/lifetime, wider allocated extents,
boxed storage copies, pointer/slice layout, const/narrow typing, file streams and
portable ABI remain boundaries. Cross builds do not establish runtime parity.
No Source visibility or implementation changes are made.

Full Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`. The runner
checks Zig 0.15.2/V 0.5.2, generated inputs/consumers and before/after fixture,
runner and implementation hashes. All native fixtures import unchanged Source.
