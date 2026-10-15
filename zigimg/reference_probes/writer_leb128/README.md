# LEB128 writer methods

`WriteStream.write_leb128[T]`, `write_uleb128[T]` and `write_sleb128[T]`
translate pinned Writer.writeLeb128/writeUleb128/writeSleb128 for native integers
and their direct aliases. The generic method follows the input's signedness;
the explicit methods select unsigned or signed encoding. All build the complete
minimal encoding in a ten-byte local array and then call the unchanged write_all
path once. This preserves its buffering, partial writes and error ordering.

Unsigned encoding accepts nonnegative signed values. A negative signed value
traps with `integer does not fit in destination type` before touching the writer,
including in production. Source narrows that signed carrier to an unsigned type
one bit smaller. Signed encoding accepts every unsigned native value, including
u64 maximum: the V algorithm preserves Source's promoted i65 encoding without
needing an i65 value carrier. Signed negative values use sign extension and emit
the shortest terminating representation.

Debug/ordinary and ReleaseSafe/production each match:

| Observation | Count per mode | SHA-256 |
| --- | ---: | --- |
| Returning records | 24,072 | `a1336a859f9a6a5f0320c187b0fd83492efe76ad8c796b7fc6e5a719995bb784` |
| Exact negative-cast panic/state pairs | 840 | `04447613b0255c370ff3ff2cb68aeb35249788fe2e8456becf77c68ae1414d2a` |

Each returning record attempts three LEB128 writes, a seek and two flushes:
72,216 encoding calls / 144,432 primary calls per mode. Setup, prefix writes,
initial seeking and observations are separate. Groups contain 11,712 basic,
8,184 every-byte, 3,600 seven-bit-boundary and 576 replacement records. Duplicate
inputs are retained once. Twenty bindings cover u8/u16/u32/u64/usize and
i8/i16/int/i64/isize, and their direct aliases. The native comparison is 64-bit.

All three encoders cover zero, positive/negative values, signed endpoints,
high unsigned bits, boundaries around powers of 128, and every byte pattern
through direct/aliased u8/i8 types. Memory, positional/streaming files, capacities
0/1/8/16, prefills, seeks, repeated writes and owned nonblocking replacement
pipes retain initialized backing bytes, pending output, logical position,
regular-file contents, descriptor ownership and pipe data. Memory failures retain
the encoded prefix. File-to-pipe transitions and sticky failures follow the
existing write_all implementation.

The independent model derives minimal encodings from bit lengths and a closed
form for each seven-bit group. It models complete nonreplacement writer records,
including memory prefix failures, positional first-vector behavior on macOS,
streaming writes, buffered flushes and seeks. Pipe records compare complete Source
observations with general checks for initialized spans, pending prefixes,
statuses and descriptor ownership. Every negative control traps before the
encoding write, including after a failed memory prefill, with a pending prefix,
through pipe replacement and with the descriptor already closed. Independent
reconstruction checks the full pre-call state. Both failed processes have empty
stdout, one exact panic message and identical retained state. Observers capture
state before opening output and clean up owned resources through FullPanic /
at_exit.

Eighteen paired compile rejections per mode cover float, float alias, bool,
record, pointer and enum arguments to all three methods. Literal controls retain
these separate language boundaries: Source writeLeb128 rejects an untyped integer
literal, while V infers int; Source rejects a negative writeUleb128 literal at
compile time, while V compiles it and traps before IO. Positive unsigned and
negative signed literals produce matching bytes. A Source u128 encoding of 2^100
returns fifteen bytes; V cannot represent that u128 carrier and rejects it.
Source's arbitrary-width integers and comptime_int are outside the native mapping.

Three regressions check classic encodings, signedness, 64-bit limits, aliases,
partial memory failure and file flushing. All 82 image test files and 17 focused
production/application/Windows/Linux checks pass. Historical writer seeks (6,912
records, 196 returns, 60 exact panic/state pairs) and full/streaming reads and
writes (37,133 records, 17 generic trap controls, four compile boundaries) retain
their hashes in both modes. The historical generic traps do not establish exact
retained state. Vaxis runtime tests are not rerun; its source is unchanged and
dependency builds pass. Cross builds establish compilation only.

The first ordinary comparison matched returning records but caught an incorrect
V panic text for negative values. Its original implementation, runner, native/V
logs and states are retained separately, along with interrupted checks. Ordinary
discovery and all final gates reran after correcting that text. A compile-control
label assertion initially split an aliased case name incorrectly; its original
script, fixture bodies and diagnostics are also retained outside passing gates.
Final production/probe/runner/direct-helper bodies stay frozen; only EXPECTED
assignments change after final ordinary discovery.

The runner pins the full unchanged Source tree, compiler versions and selected
libraries, implementation, probes, directly imported helpers, the shared owned
writer-fixture header and all inputs before/after execution. Source bodies,
visibility and syscalls are untouched. Initialized unlinked files and reset
offsets, replacement pipes and keepers are owned. Independent replay checks all
records, models, exact failures, compiler/literal controls, ownership, binaries,
actual build modes and provenance. Parent-side lossless compression pins raw /
compressed output. Evidence is persisted from an owned RAM workspace and every
retained archive member is read back before commit and release.

```sh
python3 zigimg/verify_writer_leb128_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --workdir /empty/proof/ordinary
python3 zigimg/verify_writer_leb128_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --v-prod --workdir /empty/proof/production
```

Runtime comparison uses little-endian 64-bit macOS. Arbitrary Source widths,
comptime_int/literal inference, chained aliases, custom Writer vtables, arbitrary
record construction, larger buffers/offsets, syscall counts, other devices,
concurrent reuse, timing/signals, injected errors, OOM/quotas, allocator lifetime,
portable ABI and remaining V representation limits remain boundaries.
Windows/Linux, other CPU, big-endian and 32-bit runtime are not established by
cross compilation. Remaining reader/writer APIs still need translation.
