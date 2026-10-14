# SGI direct file RLE, caller output and no-op encoders

`verify_sgi_streams_reference.py` compiles unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Debug against ordinary V and
ReleaseSafe against production V, using Zig 0.15.2 and V 0.5.2.

```sh
python3 zigimg/verify_sgi_streams_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` in another empty directory. Runtime is native little-endian
`aarch64-macos.14.0`, linked with libc. `--timeout` bounds commands; compiler
temporaries follow `TMPDIR`/`VTMP`. Evidence retains unchanged Source, fixtures,
inputs, binaries, commands, raw output and provenance.

The existing SGI and stream implementation matches without production changes.
This extends the direct memory RLE/output matrix with positional file capacities
0/1/2/3/4/8/16/32/510/512. Memory controls accompany each group. Descriptors begin
at EOF independently of logical stream cursors; inputs also start after a
three-byte discard. Direct raw/table/data reads may bypass the caller buffer,
including a zero-capacity buffer. All caller output starts at 165, so incomplete
successful packets have defined unwritten bytes that can be compared safely.

| Returning records | Count |
|---|---:|
| Raw byte prefixes, output capacities, patterns and retries | 3,872 |
| Reversed RLE row tables, literal/repeated/terminating packets and retries | 4,400 |
| Every short table prefix and retries | 2,464 |
| Every first detector byte, static/interface entry points | 5,120 |
| Partial magic and initial discard | 100 |
| Static/interface no-op writers and caller flush | 120 |
| **Total** | **16,076** |

These records contain **32,072 codec/detector calls**, SHA-256
`855353b000ef513a541d58184cb84d2c12ce2cbfab7b55e1e64116b904aa7898`.
Most call the same stream twice. Writer controls use zero/one/three calls, compare
state before encoding and after each call, then flush explicitly. Caller setup
writes and flush are outside that call count.

RLE shapes use widths 0/1/3/7, heights 0/1/2/3 and channels 0/1/3/4. Channel widths
0/1/2/3/255 preserve Source's byte packets for one and two-byte words otherwise.
Word commands have a nonzero ignored high byte. Two payload patterns, reversed
packet storage, early terminators, zero-length literal commands and trailing bytes
are compared. Absolute row offsets retain the pinned `512 + table byte length`
origin even when direct decoding starts after a discarded prefix. Source consumes
all remaining compressed input before processing those offsets.

**256 individually classified returning controls**, SHA-256
`d6adf4149c24c6a2c1fa496203c86a4191d78518b5c6a995a0314ae12c926aaa`,
include 168 packet-prefix/output-capacity controls, 48 absolute-offset/size
controls, eight largest-fitting table controls and 32 public-header/buffer
controls. Native execution supplies each classification before V is checked.

| Exact panic/state pairs | Count |
|---|---:|
| Literal/repeated byte/word source and destination bounds | 732 |
| Absolute-offset subtraction and compressed-data bounds | 96 |
| u16 table allocation products | 16 |
| Undersized public reader buffers | 40 |
| Undersized detector buffers | 4 |
| **Total** | **888** |

Failure SHA-256:
`6a22149758feb854269baddd9f9f88ac66126c7e9a75d2157a789b8b6a4d0cd1`.
Each pair requires failed exits, no stdout, the exact sole native panic message
and equal nonempty snapshots. Packet controls use memory and capacities 0/3/32,
byte/word commands, every prefix and output capacities 0..4. Literal destination
checks precede source accesses; repeated words read both source bytes before
writing, then check each destination byte separately. Snapshots retain partial
caller output, logical position, buffered length and every caller buffer byte.
Offsets below the data origin, at/after input and at 2^31/u32 maximum are covered.
Table controls include 8,191 fitting rows and 8,192 overflowing rows, plus earlier
height/channel products. Smaller public headers preserve peek/take failure order.

All snapshots include the fully initialized public header, active palette length,
all 256 seeded palette entries, input and actual disk contents. Default undefined
Source headers, private failed/freed table/data/pixel allocations and pointer
identities are excluded. Source's private Header type is inferred through its
public field; Source algorithms and visibility remain unchanged.

Writer controls use an initialized two-pixel RGB24 image with dimensions 7×9,
file/memory capacities from zero through 510, starts 0/7 and a three-byte caller
prefix. Both public encoder entry points remain pinned no-ops: image, position,
pending length, caller buffer and disk are unchanged until explicit caller flush.
The interface uses SGI options. This does not certify an implemented SGI encoder.

Two consumer regressions pin direct three-byte-buffer word decoding that leaves
output `12 34 a5 a5 a5 a5` and an unchanged caller buffer at position fourteen,
including an EOF retry; and no-op encoders retaining `11 12 13` pending at position
ten through repeated calls, with disk changing only on caller flush. Four exact
compiled controls compare their inputs in both modes, including the short-table
EOF boundary. The strengthened retry assertion also runs in ordinary/production
native tests and Windows builds.

Historical SGI contract and parsed-header output/failure hashes remain unchanged
in both modes. Unchanged native SGI assertions pass Debug and ReleaseSafe. All
61 image and 58 Vaxis test files pass, alongside nineteen application/platform/
unit/fixture checks and the four focused final test checks. Cross builds establish
compilation only. Formatting, diff and Python checks pass.

Full Source SHA-256:
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
Selected compiler-library SHA-256:
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Versions and before/after Source/library/implementation/fixture/runner/helper/input
hashes protect final comparisons. The initial fixture incorrectly initialized
pixels through Source Image's const byte view; the corrected fixture initializes
through mutable PixelStorage bytes without changing Source. That rejection is
retained separately. Full evidence is archived and every member read back on
persistent storage before task-owned RAM is detached.

The [parsed-header proof](../sgi_header/README.md) covers broader public file
pixel decoding and invalid enum tags. Successful malformed public decoding with
unwritten private pixels and word reads beyond physical byte allocations remain
excluded. Streaming/nonseekable/custom readers, OS failures, allocator/OOM/GC/
lifetime, const/narrow/enum/boxed representation, physical layouts, larger extents,
big-endian/32-bit runtime and portable ABI remain boundaries.
