This proof calls the pinned generic chunk writer's public direct `write` and
`flush` methods without changing dependency bodies. It retains the original
corpus and compares buffer state, writer positions, underlying call hashes and
destination bytes. Borrowed input slices also exercise source-visible overlap
and copy behavior.

From the repository root:

```sh
python3 zigimg/verify_png_chunk_writer_reference.py \
  /tmp/witty-png-audit-20261008/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906 \
  /tmp/witty-png-zig-20261008/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --workdir /tmp/witty-png-chunk-proof
```

Add `--v-prod` with a fresh work directory for ReleaseSafe versus V production.
`--zig-mode` overrides the native mode and `--timeout` sets the returning
deadline. The runner sets `VEXE`, disables core dumps and records exact compiler
and process argv/environment, raw streams, fixture hashes, dependency copies,
corpus and result metadata. Each native proof uses a fresh Zig global cache.

Both modes retain **5,960 historical records** and SHA256
`934ba176552e9370b30073ea1f648fab7dcb4ca85424296097b173f4d298115e`.
The **28 returning additions** have SHA256
`4632f854f9f77422d2de7a764c23a1a4fd81ff8223c310bcfb53f8032841e317`.
They compare empty and adjacent borrowed ranges, independent inline-buffer
copies sharing their underlying writer, and errors before payload bounds or
copy-overlap checks. All observed initial buffer/destination bytes are seeded.

Six strict trap pairs cover addition overflow, ordinary/max-usize flush bounds,
identical/partial overlap and overlap after a successful flush. The source
writes truncated length and section tag before checking payload bounds. Before
an overlap following flush, it also writes payload and CRC and resets `end`.
The proof requires those exact underlying-call trace lines before the expected
panic, in addition to an anchored native `thread N panic:` or V `V panic:`
header, nonzero exit, empty stdout and no actual line-start `UNEXPECTED` marker.
Quoted backtrace source text is excluded from marker detection. The production
guards preserve these orders; empty copies do not trigger the alias check.

The legacy `Writer`/`writer()` adapter still ordinarily rejects unchanged
source under Zig 0.15.2 (`std.io.Writer` is no longer a type function).
`ZlibCompressor` also rejects unchanged source because the compressor API was
removed. These are two measured unsupported source helpers, not implemented
compression substitutes. A third compiler control verifies that Source's
comptime ID rejects three bytes. Ordinary rejections require the expected
diagnostic and exclude compiler crashes and C/backend failures.

V's runtime string ID checks and its nonempty slice-buffer rejection are two
separate V adapter traps. Named fixed byte arrays preserve inline capacity;
V cannot declare `[0]u8`, so the zero-sized source specialization uses a
zero-length byte slice. Unused V slice capacity is not consulted: a slice with
length zero and reserved capacity remains a zero-sized active buffer. Runtime
resizing of that carrier and Source comptime-ID typing are representation/API
differences. Source default buffer bytes are undefined; only written or
explicitly seeded bytes are compared. Allocator/GC, generic error-type and
record ABI differences remain outside this proof.

Source revision is `d7b7ab0ba0899643831ef042bd73289510b39906`; `src` SHA256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
The selected Zig 0.15.2 DEFLATE/Reader/Writer source SHA256 is
`e8898fcced291d899efc9ebacf42762954ac5a1e088283cee0f1f261a498cab5`.
The `mem.zig`/`debug.zig` checked-helper SHA256 is
`d8e33d24ad79f9e3cf7694a9914bcf8023d5125b15f1b51930fab0e91114e65e`.
Original/copied dependency trees and fixture hashes are checked after all
returning, trap and compiler-boundary comparisons.
