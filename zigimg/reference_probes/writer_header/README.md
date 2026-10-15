# Header writes with typed IO limits

`write_splat_header` and `write_splat_header_limit` translate pinned
`std.Io.Writer.writeSplatHeader` / `writeSplatHeaderLimit`, called through the
unchanged locked zigimg `io.WriteStream` wrapper. The latter accepts `zigimg.Limit`.
The wrapper method delegates with `Limit.unlimited()`.

The pinned helper has observable quirks: it passes whole nonempty prefixes and
subtracts `header.len` when accounting for each prefix, so a limit can be
exceeded. For example, a streaming file with no buffer writes `abcdefg` and
returns seven for header `a`, vectors `[bcdef,g]`, repeat one and limit three.
Its eight vector slots can also omit remaining data in this short operation.
These are preserved Source behaviors. This is not a general hard byte cap.

The helper calls drain directly. Fixed output can partially copy prefixes,
return zero despite copying prefixes when the last vector is empty, or trap
after copies when the limited repeated suffix fits the remaining destination.
An empty repeated pattern can cause division by zero on the helper path;
empty data can underflow only after a header copy, or be bypassed by a nonempty
header exhausting the limit. Pattern multiplication checks occur after earlier
buffered copies. File drains use the existing 16-slot / byte-block preparation
path, including pending output, pipe mode transitions and closed-descriptor
failure order. No Source bodies, visibility, syscalls or C helper bodies change.

Both Debug/ordinary and ReleaseSafe/production match these finite proofs:

| Observation | Count per mode | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 16,178 | `1e0679205ce4588b29831b2d82123193e83484e18d0ab64c01cb32ac45d446df` |
| Returning boundary controls | 774 | `f8e1a498bb355c9003f1557b2fb24c1cd8061ad91bf64659be0ff48915bc098d` |
| Exact panic/state pairs | 276 | `e58c3d07ad1dd7b624ca38493980756c5b0ef602a30e27cfe85370ba84acacf9` |

The corpus covers memory, positional files and streaming files; empty/full /
partially filled buffers; starts zero/three; empty headers and data; shared and
overlapping input spans; vector profiles through 16 vectors and 255-byte spans;
zero/one/several repeats; limits zero/one/small/64/unlimited; capacities around
64-byte scratch selection; regular files, replaced pipes and closed descriptors;
caller buffer changes, flushes and every byte value. Input header and vector
spans retain their bytes and relative offsets. Every returning record has an
independent model of all five snapshots, borrowed output views, complete backing,
pending bytes, input bytes/headers, descriptor observations and file/pipe output.

Boundary controls include usize maximum repeats, checked multiplication, empty
vectors, division by zero and fixed-drain assertions/unreachable paths. There
are 196 integer-overflow, 56 division-by-zero and 24 unreachable pairs per mode.
Each has empty stdout, one exact panic message and identical retained state,
independently reconstructed after any earlier header/prefix copies. Native
FullPanic and V at_exit capture before opening retained output. Returning controls
exercise the corresponding early-helper / failure-order cases too.

Fourteen paired compile rejections per mode check invalid repeat/header/vector /
limit types and private-helper access. External consumers call both public
methods with a count alias and typed Limit and verify counts, bytes and unchanged
input headers. V Limit's enum/const-slice representation limits remain recorded
in the [Limit comparison](../io_limit/README.md).

Three public regressions, all 91 image test files and 17 focused production,
application, Windows and Linux build checks pass. Historical complete vector /
repeated writes (32,016 records, 1,176 returning controls, 770 exact failures) and
full/streaming IO (37,133 records, 17 generic traps, four compile boundaries) keep
their hashes in both modes. Generic traps do not prove exact state. Vaxis source
is unchanged; runtime tests are not rerun and dependency builds pass. Cross
builds establish compilation only.

The complete locked zigimg Source tree stays unchanged at
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
Selected compiler libraries retain
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`;
whole `std/Io.zig` is additionally checked before/after at
`09df1114cba703f824337f20489c7df5294db9f07961d4ac46abbbbf9c7ecaef`.
Path and encoder dependencies, implementation, probes, direct helpers and inputs
are pinned before/after. Final runtime bodies stay frozen; only EXPECTED
assignments change after ordinary discovery. Independent replay checks complete
records, models, failures, actual modes, binaries, compiler controls and pins.
Lossless compressed logs pin raw/compressed bytes. Every retained archive member
is read back before the reviewed files are committed and owned RAM is released.
The development test's initial expected count six was corrected to Source's seven;
that failed test log is kept separately. Persistent local jobs survive headless
input turns.

Run from the repository root with the pinned compilers and a fresh work directory:

```sh
python3 zigimg/verify_writer_header_reference.py \
  /Users/alex/.cache/witty-src/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906 \
  /Users/alex/.cache/witty-jpeg-scan-20261013/tools/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --workdir /path/to/fresh/proof
```

Add `--v-prod` for ReleaseSafe / V production. Runtime is little-endian 64-bit
macOS. Windows/Linux, other CPUs, 32-bit/big-endian runtime, native drains and
syscall counts, arbitrary devices/errors/signals, timing, allocation failure,
large storage, input/output overlap, invalid/concurrently changed slice headers,
allocator lifetimes and portable ABI remain outside the proof. The translation
skips empty-pattern no-op fast-path iterations; unbounded successful empty loops
are not executed by the probes. All returning storage is valid and bounded;
input backing must remain alive. No broad claim about a hard output limit or
complete writer API parity follows from these methods.
