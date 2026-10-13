# Stream guard diagnostics and retained state

`verify_stream_guards_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Source Debug with ordinary V,
and Source ReleaseSafe with production V.

```sh
python3 zigimg/verify_stream_guards_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The default runtime target is
native `aarch64-macos.14.0`. Commands have a configurable timeout. Artifacts retain
source copies, binaries, corpus, all commands/output, panic snapshots, provenance
and summary; temporary/cache directories belong to the proof.

The adapter now preserves exact Source `reached unreachable code` messages for
file requests beyond buffer capacity and tosses past buffered input. Relative
seek addition and pending writer-position addition now report `integer overflow`.
These replace custom V messages without changing guard conditions, reads, writes
or cursor updates. The explicit guards remain active in production. Existing GIF
and TGA runners expect the aligned categories and retain their previous goldens.

| Returning controls | Count |
|---|---:|
| Peek results, partial EOF and capacity boundaries | 303 |
| Relative seeks and Unseekable boundaries | 609 |
| Valid memory tosses, including exact end | 30 |
| Pending writer position, including largest fitting u64 | 52 |
| **Total** | **994** |

Returning SHA-256 in both modes:
`bd6c1a9360e9e336b09180e2f4d8be903e6e90b2841f9c7c2a6b830739b343a0`.

Reader controls use initialized memory or file buffers of capacity 0/1/2/8/31,
input lengths 0/1/3/8/17/32, zero/nonzero initial consumption, requests through 17
and signed seek extremes. Writer controls use capacities 1/2/8/31, zero/nonzero
pending bytes and positions through u64 maximum. Pending data fits the buffer,
so large offsets do not write sparse file contents. Exact Source output supplies
the oracle; handwritten outputs do not substitute for the native implementation.

| Exact panic/state pairs | Count |
|---|---:|
| File capacity failures, including zero buffers and EOF precedence | 100 |
| Memory toss after advancing the cursor | 30 |
| Logical or physical relative-seek addition overflow | 9 |
| Pending file-writer position addition overflow | 16 |
| **Total** | **155** |

Failure-state SHA-256:
`7fc070ee211fd87689aa75ed0f462ccbfe160e76a70c41f6059d0ec3cf6b2870`.

Capacity failures request capacity+1 or int maximum after optional read-ahead and
consumption. Source rebases retained bytes before its capacity assertion; snapshots
compare that initialized buffer, logical position and buffered length. Relative
seek failures cover addition to the interface cursor and addition to physical
file position after clearing the buffer. Toss failures compare the advanced memory
cursor and unchanged input, excluding buffered-length getters that are invalid
once Source's cursor exceeds its end. Counts stay within V's int cursor carrier.
Writer failures compare all pending and caller buffer bytes, excluding the failing
position getter from observers. No private stream fields or raw pointers are
compared. Strict checks require the exact sole panic message, unsuccessful exit,
no stdout/unexpected return and disabled core dumps.

A module regression covers rebasing/refilling without consuming peeked bytes and
retained bytes at EOF. All 61 image and 58 Vaxis test files pass, with 18 production/
platform checks. The existing full stream/bitstream comparison retains 37,133 rows,
17 trap controls and four compiler rejection pairs in both modes. Its full,
original and streaming hashes remain unchanged. Existing GIF record and TGA
buffered-decoder output/state/vector hashes remain unchanged in both modes. GIF's
wide failed toss cursor remains a documented Source/V representation difference.
The pre-fix returning batch and first diagnostic mismatch are retained separately.
An initial historical-fixture build from outside the repository lacked its
`@VMODROOT`; the completed check builds the unchanged original fixture in place.

Full Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
The runner checks Zig 0.15.2/V 0.5.2 and before/after source/library, fixture,
implementation, runner, helper and corpus hashes. All Source imports remain
unchanged. The [original stream proof](../streams/README.md) separately covers
bitstream types, streaming constructors, descriptors and broader byte I/O.

Failed cursors beyond V's int carrier, calling invalid getters after a failed toss,
private physical/mode fields, forged stream state, negative V-only byte counts,
other guard diagnostics, allocator/OOM/GC/lifetime, cross-target runtime, arbitrary
custom readers/writers, pointer/slice layout and portable ABI remain boundaries.
Cross-target builds establish compilation only. Failed wide tosses still trap
before V can retain Source's unrepresentable cursor; this change aligns their
message, without claiming matching state.
