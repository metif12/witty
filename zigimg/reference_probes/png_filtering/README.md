This proof calls unchanged public `png/filtering.zig.filter`. It does not expose
private source helpers or alter dependency bodies. The native and V producers
compare returned writer errors, positions and every initialized destination byte.

From the repository root:

```sh
python3 zigimg/verify_png_filtering_reference.py \
  /tmp/witty-png-audit-20261008/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906 \
  /tmp/witty-png-zig-20261008/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --workdir /tmp/witty-png-filter-proof
```

Add `--v-prod` with a fresh work directory for Zig ReleaseSafe versus V
production. `--zig-mode` can select the native mode explicitly. `--timeout`
sets the returning producer deadline. The runner sets `VEXE`, disables core
dumps, and retains source copies, fixture hashes, exact argv/environment,
compiler streams, corpus, returning streams, trap streams and `result.json`.
A fresh per-proof Zig global cache avoids stale SDK/cache manifests.

Both modes pass **43,389 returning records** and **10 strict trap pairs**.
The original **43,200** filtering cases retain FNV64 `809cede448778a71`.
The expanded serialized records have SHA256
`ba128302912d022c765fd89f37431e3961ffbe5b5c35cd6c9d140862401a9c7d`.
The historical prefix covers all 15 PNG color/depth formats, six filter
choices, four widths, three heights, eight seeds and short/exact/long output
buffers. Additions exercise empty rows, zero-height `try_all`, direct indexed16
storage, the source's shorter sixteen-bit destination row, and empty rows from
invalid pixel storage. Filtering does not validate the header first; these
defined direct-API behaviors are preserved.

Strict failures cover short pixel storage, unequal eight-bit copy lengths,
short sixteen-bit source rows, odd sixteen-bit destination bytes, inherited
`try_all` panic, inherited RGB332/RGB565 `bitsPerChannel` unreachable arms,
and three header arithmetic failures reached before row processing, including
zero-height calls. Trap checks require nonzero exit, empty stdout and the
expected category on an anchored native `thread N panic:` or V `V panic:`
header. Actual line-start `UNEXPECTED` markers reject returned errors or normal
returns; quoted source/backtrace text is not interpreted as a fixture marker.
Index diagnostics map to V's checked array-access diagnostic where needed.

The source heuristic uses scanline length as its pixel stride and ignores the
last unfinished run. Those behaviors are retained. Checked run/score and
allocation arithmetic is now explicit under V production; the native returning
range does not reach the large-count heuristic overflow guards on ARM64.
Sixteen-bit byte conversion checks source before destination, matching
`std.mem.bytesAsSlice` and its `exact division produced remainder` category.
The private reader spread conversion uses the same checks; its two malformed
exact-division paths are proved separately through public `reader.load`
callbacks in the PNG decoder checkpoint. The conversion retains byte alignment.
Private helpers are not made source-public.

Source revision is `d7b7ab0ba0899643831ef042bd73289510b39906`; full `src` SHA256
is `ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
The selected Zig 0.15.2 DEFLATE/Reader/Writer source SHA256 is
`e8898fcced291d899efc9ebacf42762954ac5a1e088283cee0f1f261a498cab5`.
The `mem.zig`/`debug.zig` checked-helper SHA256 is
`d8e33d24ad79f9e3cf7694a9914bcf8023d5125b15f1b51930fab0e91114e65e`.
Original/copied trees and fixture hashes are rechecked after comparison.
Source allocators/OOM, wider slice/index representations, undefined initial
current-row bytes for unsupported sample depths, and inaccessible private
helper states are excluded. GC-backed V arrays initialize storage; parity is
claimed only for source-defined observations.

The later [exact filtering bounds proof](../png_filter_bounds/README.md) supplements
this matrix with complete pixel/packed-byte/native-word diagnostics and retained
writer/input snapshots. Both modes retain the returning SHA-256 and historical
FNV64 above; Source-undefined private row storage remains excluded.
