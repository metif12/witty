# Integer slice writes and byte swapping

`write_slice_endian[T,E](values, endian)` and `write_slice_swap[T](values)`
translate the native integer portion of pinned `std.Io.Writer.writeSliceEndian`
and `writeSliceSwap`, called through the unchanged zigimg WriteStream adapter.
`E` is BigEndian / LittleEndian, including direct aliases. T supports the ten
native signed/unsigned integer carriers and direct aliases exercised below.
Inputs are borrowed and remain unchanged; backing must stay alive during writes.

A native-endian write passes the entire input as one byte span to write_all.
A swapped write copies and reverses each element, then calls write_all separately
for that element. Even one-byte swapped elements retain this per-element call
order. This distinction affects pending bytes, caller backing and file writes.
Fixed-buffer failure retains its copied prefix. Later elements are not written
after an error. Empty slices perform no IO, including on closed descriptors.
There are no changes to old IO methods, Source bodies/visibility/syscalls or C
helper bodies.

Both Debug/ordinary and ReleaseSafe/production match:

| Observation | Count per mode | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 25,740 | `f06bcdf9eead5f6decc922a0e71609c608ab7f3b5edbb6c3defc6f9a114eed3d` |
| Returning boundary controls | 756 | `c94e4f0ecdb9a4f52ad7233cc2513598235b4768084b7dbf7bc6711a99f5a7b0` |

The records include caught WriteFailed results. No runtime trap is asserted by
this valid-storage matrix. The explicit V byte-span length guard and huge input /
allocation failures are outside the proof. The native-span path rejects a byte
length beyond V's signed array-length range before IO; the swapped path writes
bounded element views instead of flattening the entire input.

The matrix covers u8/u16/u32/u64/usize/i8/i16/i32/i64/isize (V int maps to i32),
all ten direct aliases, both endian markers and their aliases, direct swapping,
counts 0/1/3/9, input offsets 0/1/2, every byte value, memory/positional/streaming
writers, capacities 0/1/3/8/17, starts zero/three, empty/full pending buffers,
regular/replaced-pipe/closed descriptors, caller buffer changes and flushes.
The independently modeled groups contain 12,600 integer-slice, 3,600 IO-failure,
9,180 every-byte and 360 input-guard records. Specifications are deduplicated.

Every complete record and returning control has an independent model of all
five snapshots: initialized backing, logical position, pending bytes, unused
view lengths/offsets/bytes, descriptor validity/reference observations, the
complete initialized input with guards and relative byte-span header, caller
writes, flush outcomes and complete file/pipe output. The model distinguishes
one-span writes from per-element writes, positional file drains from streaming
writes, and pipe mode transitions / cached failures. Absolute addresses and
syscall counts are not compared. Source input byte observers cast the valid
typed input pointer so even empty-span offsets are defined.

Seven paired compiler rejections per mode cover wrong endian and slice types,
and unsupported swapped float/bool/string values. Three separately retained
boundaries run successfully in Source and reject in V: native float output and
native/foreign extern-struct output. Those Source capabilities remain unported;
they are not included in the integer equivalence claim. External consumers in
both languages/modes use integer/endian aliases, both methods and empty input,
checking bytes, counts and unchanged inputs. General coercions, wider Source
integers, aggregates, pointers, enum layouts and arbitrary native layouts remain
outside this checkpoint.

Three public regressions, all 92 image test files and 17 focused production,
application, Windows and Linux build checks pass. Historical header writes keep
16,178 records, 774 returning controls and 276 exact panic/state pairs per mode.
Full/streaming IO keeps 37,133 records, 17 generic traps and four compile
boundaries per mode. Their prior hashes are unchanged. Generic traps do not
establish exact state. Vaxis source is unchanged; runtime tests are not rerun,
and dependency builds pass. Cross builds establish compilation only.

Complete locked zigimg Source retains
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
Selected compiler libraries retain
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`;
whole Io.zig additionally retains
`09df1114cba703f824337f20489c7df5294db9f07961d4ac46abbbbf9c7ecaef`.
Library, path/encoder, implementation, probe, direct-helper and input pins are
checked before/after. Final runtime bodies are frozen before ordinary discovery;
only EXPECTED assignments change afterward. Independent replay checks every
record/model, compiler control, actual mode, binary and provenance pin. Lossless
compressed outputs pin raw/compressed bytes. Every retained archive member is
read back before committing exact reviewed files and releasing owned RAM.
Recorded local jobs survive headless input turns.

Development evidence is retained separately. An initial feasibility command
omitted the pinned deployment target and failed at linking; all three methods /
branches compile and run with the correct target. An initial probe used
std.mem.sliceAsBytes on an empty typed input, exposing its undefined empty
pointer through an observer. The corrected observer uses the typed pointer
without changing the actual method call. Its 201 preflight records and the full
final comparisons match. No undefined Source pointer is in the final comparison.

From the repository root, with pinned compilers and a fresh work directory:

```sh
python3 zigimg/verify_writer_slice_endian_reference.py \
  /Users/alex/.cache/witty-src/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906 \
  /Users/alex/.cache/witty-jpeg-scan-20261013/tools/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --workdir /path/to/fresh/proof
```

Add `--v-prod` for ReleaseSafe / V production. Runtime uses little-endian 64-bit
macOS. Windows/Linux, other CPUs, 32-bit/big-endian runtime, other devices,
injected errors/signals, arbitrary short drains, timing, syscall counts, huge
storage/OOM, allocator lifetime, input/output overlap, invalid/concurrently
changed headers, portable ABI and remaining V representation limits are outside
the proof. Other writer/reader APIs remain outside this checkpoint.
