# Integer peeks and variable-width reads

`peek_int[T, E]` and `take_var_int[T, E]` translate pinned Zig Reader.peekInt
and Reader.takeVarInt. Peeking decodes a full native integer without consuming
its bytes. Variable reads consume exactly the requested count on success and
zero-extend short representations, including into signed types. A full-width
representation sets the signed high bit normally. A zero-width read returns
zero without reading, even at EOF or after sticky failure. Requests larger than
the target type trap before filling or consuming; that trap remains active in
V production. Existing reader methods and C adapters are unchanged.

Supported carriers are u8/u16/u32/u64, i8/i16/int/i64, usize/isize and their
aliases. `BigEndian`/`LittleEndian` and aliases replace Source's endian enum.
Variable counts use usize; native widths are those of the compilation target.
The comparison runs on aarch64 macOS, where usize/isize are 64 bits. Source's
arbitrary-width integer types, including u0, non-byte widths and 128-bit types,
remain outside this V carrier mapping.

## Reproduce

```sh
python3 zigimg/verify_reader_integer_reference.py "$SOURCE" "$ZIG" "$V" --workdir /path/to/empty/ordinary
python3 zigimg/verify_reader_integer_reference.py "$SOURCE" "$ZIG" "$V" --v-prod --workdir /path/to/empty/production
```

Source is zigimg `d7b7ab0ba0899643831ef042bd73289510b39906`, with Zig 0.15.2
and V 0.5.2. Ordinary pairs Debug with V ordinary; production pairs ReleaseSafe
with `-prod`. Target defaults to `aarch64-macos.14.0`. The runner sets VEXE and
V_C_ERROR_BUG_REPORT_DISABLED=1, owns its temporary directories/caches and retains
commands, inputs, outputs and provenance. Full unchanged Source tree SHA-256:
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
Selected stdlib, including mem/Reader/Writer/File/posix, SHA-256:
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Selected path/encoder libraries, compiler versions, implementation, probes,
shared fixtures, directly imported helpers and inputs are checked before/after
each comparison. No Source body, visibility or reader syscall is changed.

## Returning records

Both modes match **56,640 records / 169,920 integer reads / 396,480 primary
calls**. Each record performs three integer operations, three caller consumptions
and one relative seek; construction, priming and observations are separate.
Groups contain 25,344 basic, 12,288 every-byte and 19,008 prefilled profiles.
All ten native carriers and their aliases run with both endian markers and
marker aliases through memory, positional files and streaming-initialized files.
Basic payload lengths 0/1/7/8/9/17 and distinct zero/one/end offsets cover EOF,
repeated peeks, all valid variable widths and complete initialized read-ahead.
Every byte value runs in signed/unsigned byte types and aliases, in both orders
and all three constructors. Prefilled files use capacities 8/32, offsets 0/1,
consumption 1/7, distinct pending-length/physical-offset/longer seed sizes,
open/closed owned pipes, priming/toss choices and relative offsets -1/0/1.
Copied successful integer results, full backing storage, pending bytes, logical
positions, size/errors, normalized ownership and untouched wire bytes match.
Output SHA-256 (joined lines without a trailing newline):
`8f95f7708e71ef902ecec73fdc067b10c5ee3625c7a0f6fa25d9931562420a77`.

Inputs extend the [fill-more record](../reader_fill_more/README.md) with
`op|type|endian|count`. Op 0 peeks and op 1 takes a variable-width integer.
Types 0–9 are u8/u16/u32/u64/i8/i16/i32/i64/usize/isize; 10–19 select aliases.
Endians 0/1 select big/little and 2/3 select marker aliases. Snapshots retain
the same ten-part sequence and five fields, with the output field containing
`decimal-value:unsigned-bit-pattern`. Failed reads retain the previous successful
value. Every success is checked for signed representation consistency; peek
values are also decoded independently from the retained pending bytes.

## Controls and consumers

The **1,856 distinct controls** classify as **808 returning records**, SHA-256
`cfc8891571a3cd8a28c666dbd923f1db147a0292954ea8db3833de27400eba76`,
and **1,048 exact panic/state pairs**, SHA-256
`fd6261efd9ad3994720c9317ac6d0cc7f301f3bee64c0154e161108f7d1f2ac5`.
There are 504 capacity/type-width and 96 pending-buffer failures with exactly
reached unreachable code. Type-width assertions precede IO and rebase; pending
capacity failures compact before panicking. Another 448 fail with exactly integer
overflow in public getPos observations after priming, before the requested
integer operation. Both exits fail with empty stdout, one exact message and
matching initialized retained state. Observers omit getPos and capture preceding/
calling status, size/errors, backing storage, saved output, pending bytes and
owned descriptor references before opening state files. Source FullPanic and
V at_exit clean up owned resources.

Seventeen additional compiled consumer records / 51 integer reads / 119 primary
calls per mode assert all three results against concrete expectations: signed
full/short representations, aliases, zero-width EOF, file read-ahead, short EOF
tails, actual compaction, rewind, pipe transitions, zero-width untouched input,
sticky buffered successes and retained failures. SHA-256:
`67bbdbfa89c6e8f8ea3c24a11012d779478883354e1bf22eb7002355ed7729c8`.
Eight paired compile rejections per mode verify both methods reject noninteger
types and invalid endian markers, including aliases. Three public unit
regressions accompany the proof. All 71 image and 58 Vaxis test files pass,
with 49 production/application/platform/unit/fixture checks. Historical buffered,
single-callback fill and full-stream matrices retain their hashes in both modes.

## Evidence and boundaries

Initial fixture failures retain their runner/probe copies and diagnostics:
the string-to-usize parser needed an explicit u64 conversion, and V's C generator
misidentified generic results in an if expression. A named typed local fixes the
latter in the fixture. An initial consumer expectation assumed read-ahead during
an already buffered take; the corrected fixture forces real compaction. These
development observations remain separate from final passing proofs. The image
suite passed 71 files while a stale harness expected 70; its diagnostic is
retained and the passing command reused. Production/probe/runner/helper bodies
remain frozen during final comparisons; only expected assignments change after
ordinary discovery.

The C wrapper reuses separately copied/hashed exclusive-payload and reader
replacement fixtures: initialized unlinked O_EXCL/CLOEXEC files, reset live
offsets and owned nonblocking pipes/keeper descriptors below 128. Parent-side
lossless log compression pins raw and compressed bytes. Independent replay
checks native classifications, exact failure states, output/value semantics,
consumers, ownership, build modes, binary hashes and provenance. A task-owned
RAM workspace was created before compilation; retained evidence is persisted
and every archive member read back before committing and releasing that volume.

Arbitrary custom callbacks, overlapping storage, arbitrary constructor/copy
sequences, other devices, larger buffers/offsets, unsigned counts beyond the
tested profiles, concurrent reuse, syscall counts, timing/signals, injected
errors, OOM/quotas, allocator lifetime, portable ABI and V representation limits
remain boundaries. Windows/Linux and other CPU, big-endian and 32-bit runtime
are outside the native comparison. Cross builds establish compilation only.
