# Aligned writes and formatting options

`align_buffer(buffer, width, alignment, fill)` and
`align_buffer_options(buffer, options)` translate pinned std.Io.Writer.alignBuffer
and alignBufferOptions through the unchanged zigimg WriteStream adapter.
`Alignment` supplies left / center / right. `FormatOptions` represents the four
public std.fmt.Options fields: optional usize precision/width, alignment and u8
fill. Defaults are none / none / right / ASCII space. Fields are public and
mutable. These APIs ignore precision, as Source does. Omitted width selects the
input length; explicit zero is retained and does not truncate input.

When width is no larger than input length, the whole input is written without
padding. Left writes payload then padding; right writes padding then payload.
Center writes floor(padding/2) bytes before the payload and ceil(padding/2)
after it. Each part uses the existing complete-write path, preserving buffering,
partial failures, byte-block scratch preparation and later flush behavior.
Center computes its checked padding-plus-one before any of those writes, so
usize-maximum padding traps before output. Later overflow in a byte-repeat call
can occur after earlier payload copies. Old IO/C helpers, Source bodies,
visibility and syscalls remain unchanged.

Both Debug/ordinary and ReleaseSafe/production match:

| Observation | Count per mode | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 17,712 | `05553be00a26d477c186c81aa962ac35b6c14fc8d1c812893fb6abd52368b840` |
| Returning boundary controls | 1,058 | `cac234dca7aff931d66263018693aea20fd67ccf98821cd632f6ef548ae5060e` |
| Exact overflow/state pairs | 384 | `1342787ab85c855d688e4e7cc6b12e39c17daadfae074f10cf2a838e2d9a0bb2` |

Returning observations include caught WriteFailed. Every complete record and
returning control has an independent model of five snapshots: initialized
backing, pending bytes/length, logical position, unused-view length/offset/bytes,
input payload/relative byte-span header, all four option values, descriptor
validity/reference observations, caller changes, flush results and complete
file/pipe output. The model distinguishes payload writes from byte repetitions,
positional/streaming drains and pipe mode transitions. It reconstructs scratch
preparation before failed IO too. Every trap has empty stdout, one exact panic
message and identical retained state, independently modeled after any earlier
copies. FullPanic / at_exit capture before opening the retained state file.

The four deduplicated groups contain 12,348 alignment, 216 option, 4,608 every-byte
and 540 scratch/retry records. They cover both APIs, all three alignments,
empty/short/long input, omitted and explicit widths, zero/equal/smaller/larger
widths, odd/even padding, precision none/zero/maximum, every fill byte,
memory/positional/streaming writers, capacities around the 64-byte scratch
boundary, start zero/three, empty/full pending output, regular/replaced-pipe /
closed descriptors, caller changes and flushes. Finite controls include maximum
widths that trap or fail, or are bypassed by omitted option width. Huge successful
padding runs are excluded by a bounded model; they are not executed or claimed.
Input bytes/headers and option fields remain unchanged during calls.

Ten paired compiler rejections per mode check wrong buffer/width/alignment /
fill/options types, bool option fields and unknown fields. The separate fill-256
boundary rejects in Source; pinned V ordinary builds warn and write byte zero,
while V production rejects. External consumers use alignment/options aliases,
default construction, mutable fields, independent value copies and omitted
width, and verify emitted bytes and unchanged precision. Numeric coercions
outside these finite cases remain boundaries. Only valid named alignment tags
are compared. Native enum / option / record layout and Source's general fmt
APIs, including Options.toNumber, are outside this checkpoint.

Three public regressions, all 94 image test files and 17 focused production,
application, Windows and Linux build checks pass. Historical buffer consumption
retains 29,078 records and 366 returning controls per mode. Full/streaming IO
retains 37,133 records, 17 generic traps and four compile boundaries per mode.
Their hashes are unchanged. Generic traps do not establish exact state. Vaxis
source is unchanged; runtime tests are not rerun and dependency builds pass.
Cross builds establish compilation only.

Complete locked zigimg Source retains
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
Selected compiler libraries retain
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`;
whole Io.zig retains
`09df1114cba703f824337f20489c7df5294db9f07961d4ac46abbbbf9c7ecaef`.
This suite additionally pins whole fmt.zig before/after:
`667eac6285e472b5516ebebf8a6e69959a171be4fb97cac1e56419ffec20d500`.
Runtime and compiler controls check these pins, plus versions, path/encoder
libraries, implementation, probes, direct helpers and inputs. Runtime bodies
are frozen before discovery; only EXPECTED assignments change afterward.
Independent replay validates complete records/models, exact failures, compiler
controls, modes, binaries, provenance and unchanged old IO/C bodies. Lossless
compressed outputs pin raw/compressed bytes. Every retained archive member is
read back before committing exact reviewed files and releasing owned RAM.
Recorded local jobs survive headless input turns.

Development evidence is retained separately: a missing unsafe enum conversion
in the V probe and an absent-precision marker parsed as an integer in its
snapshot checker. The initial pipeline was stopped by its verified owned process
group before that parser correction, then restarted in fresh proof directories.
Its logs/runner/termination receipt remain separate. Neither correction changes
the implementation. The corrected preflight passes 162 records and eight exact
traps before final comparisons.

From the repository root, with pinned compilers and a fresh work directory:

```sh
python3 zigimg/verify_writer_align_reference.py \
  /Users/alex/.cache/witty-src/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906 \
  /Users/alex/.cache/witty-jpeg-scan-20261013/tools/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --workdir /path/to/fresh/proof
```

Add `--v-prod` for ReleaseSafe / V production. Runtime is little-endian 64-bit
macOS. Windows/Linux, other CPUs, 32-bit/big-endian runtime, arbitrary devices /
short drains, injected errors/signals, timing, syscall counts, invalid alignment
tags or concurrently changed headers, input/output overlap, huge storage/OOM,
allocator lifetime, portable ABI and remaining V representation limits remain
outside the proof. Caller input/output backing must stay alive.
