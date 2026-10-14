# Signed and unsigned LEB128 reads

`ReadStream.take_leb128[T]()` translates pinned Reader.takeLeb128 for the native
u8/u16/u32/u64, i8/i16/int/i64 and usize/isize carriers and their aliases.
It accepts valid overlong encodings, consumes through a terminator before
reporting Overflow, and consumes available continuation bytes before reporting
EndOfStream or ReadFailed. Those read errors take precedence over a value that
would overflow if terminated. Failed calls retain the last successful result
in the comparison fixture. Existing reader bodies and C adapters are unchanged.

Source rounds the target width up to a multiple of seven. The V implementation
preserves the extra six high bits of the 70-bit intermediate needed for 64-bit
targets, checks extension groups, and performs the final native-width range
check after consuming the terminator. Signed values extend from the final
stored seven-bit group; unsigned values extend with zeros. usize/isize follow
the compilation target; this native comparison uses 64-bit carriers.

## Reproduce

```sh
python3 zigimg/verify_reader_leb128_reference.py "$SOURCE" "$ZIG" "$V" --workdir /path/to/empty/ordinary
python3 zigimg/verify_reader_leb128_reference.py "$SOURCE" "$ZIG" "$V" --v-prod --workdir /path/to/empty/production
```

Source is zigimg `d7b7ab0ba0899643831ef042bd73289510b39906`, with Zig 0.15.2
and V 0.5.2. Ordinary pairs Debug with V ordinary; production pairs ReleaseSafe
with `-prod`. Target defaults to `aarch64-macos.14.0`. The runner supplies VEXE
and V_C_ERROR_BUG_REPORT_DISABLED=1, owns temporary directories/caches and retains
argv, inputs, outputs and provenance. Full unchanged Source tree SHA-256:
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
Selected stdlib, including mem/Reader/Writer/File/posix, SHA-256:
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Selected math/simd/path libraries, versions, implementation, probes, shared
fixtures, directly imported helpers and inputs are checked before/after
comparison. No Source body, visibility or reader syscall is changed.

## Returning records

Both modes match **72,030 records / 216,090 LEB128 calls / 504,210 primary
calls**. Each record performs three decodes, three caller consumptions and one
relative seek; construction, priming and observations are separate calls.
Groups contain 15,360 every-byte, 32,768 every-two-byte, 15,182 boundary,
6,128 wide-last-group and 2,592 prefilled profiles. Duplicate specifications
are retained once in the first group. All twenty native/alias carriers run every
byte through memory, positional files and streaming-initialized files. Both
8-bit signedness choices exhaust all 128×128 two-byte continuation/terminator
combinations, followed by a sentinel byte. Boundary cases cover canonical signed
and unsigned representations, target limits and adjacent values, valid overlong
extensions, truncated continuations and file capacities 1/2/8/32. All 128 tenth
payload groups run with zero/one-filled preceding groups for the four 64-bit
carriers and aliases. Prefills cover capacities 8/32, offsets 0/1, consumption
1/7, open/closed owned pipes, seed/priming/toss choices and relative offsets -1/0/1.

Complete initialized storage, copied successful values, pending bytes, logical
positions, size/errors, ownership and untouched wire bytes match. An independent
decoder uses arbitrary-precision Python integers to verify every nonreplacement
operation's value, overflow/EOF result and consumed byte count. It checks
canonical and overlong encodings by their mathematical value, independently of
the production word/high-bit algorithm. SHA-256 (joined output lines without
a trailing newline):
`cd8c8be7745c8f356e76451db3cfc18bb7b6577403ba51365c010adf6406dd73`.

Inputs extend the [fill-more record](../reader_fill_more/README.md) with `type`:
`kind|warmup|capacity|start|consume-mode|payloadhex|replacement|consumed|seed|prime|delta|type`.
Types 0–9 are u8/u16/u32/u64/i8/i16/i32/i64/usize/isize; 10–19 select aliases.
The ten output parts retain the initial/primed, three operation/consumption,
seek and wire sequence. Reader snapshots contain
`status|position:size-or-error:valid:refs|backinghex|decimal-value:bits|pendinghex`.
The result field starts empty and changes only on successful decoding.

## Controls and consumers

The **464 distinct controls** classify as **192 returning records**, SHA-256
`888fe8ed674c5f870353dfee371e93518cabe668c9b21237795c38c603a4b8b4`,
and **272 exact panic/state pairs**, SHA-256
`ab4f2eeb384be7db838caa736c4b776f0c4ea8917cd2104ac9972898cce51b86`.
There are 160 zero-capacity file failures with exactly reached unreachable code;
fixed memory returns results/EOF independently of the capacity marker. Another
112 fail with exactly integer overflow in public getPos after priming, before
the requested decode. Both exits fail with empty stdout, one exact message and
matching initialized retained state. Observers omit getPos and capture preceding/
calling status, size/errors, backing storage, saved output, pending bytes and
owned references before opening state files. Source FullPanic and V at_exit
clean up only owned resources.

Twenty additional compiled consumer records / 60 decodes / 140 primary calls
per mode assert all three results against concrete expectations for classic
values, 64-bit limits, aliases, overlong sign extension, overflow draining,
truncated-overflow error precedence, one-byte refills, read-ahead, rewind,
pipe values, partial failures and sticky pending/retry behavior. SHA-256:
`271dacd90e3ae378fbfee05ee4ed3b970309f452bfee5622106c46e2849db971`.
Four paired compile rejections per mode verify noninteger floats, aliases,
booleans and records are rejected. Three public regressions accompany the proof.
All 72 image and 58 Vaxis test files pass, with 52 production/application/
platform/unit/fixture checks. Historical integer, buffered and full-stream
matrices retain their previous hashes in both modes.

## Evidence and boundaries

V's checker requires an explicit unreachable fallback after the generic loop;
the initial missing-return diagnostic and implementation are retained. Initial
unit diagnostics also retain a valid-255 fixture mistakenly labelled overflow
and compound stateful assertions; the final regression uses a genuine overflow
and named local results. These development observations remain separate from
passing final comparisons. Shared disk exhaustion disrupted module/platform
checks using /tmp; failed jobs are retained separately, task-owned reserved
space was released, and affected checks were rerun after space recovered.
Successful earlier commands were reused. Production/probe/runner/helper bodies
remain frozen during final comparisons; only expected assignments change after
ordinary discovery.

The wrapper reuses separately copied/hashed exclusive-payload and reader
replacement fixtures: initialized unlinked O_EXCL/CLOEXEC files, reset live
offsets, and owned nonblocking pipes/keepers below descriptor 128. Parent-side
lossless compression pins raw and compressed logs. Independent replay checks
mathematical values/progress, native classification, exact retained failures,
consumers, ownership, build modes, binaries and provenance. The task-owned RAM
workspace was created before compilation; retained evidence is persisted and
every archive member read back before committing and releasing that volume.

Source arbitrary-width integers, including zero/non-byte widths and widths
above 64, remain outside this V carrier mapping. Custom callbacks, overlapping
storage, arbitrary constructor/copy sequences, other devices, larger buffers/
offsets/encodings, concurrent reuse, syscall counts, timing/signals, injected
errors, OOM/quotas, allocator lifetime, portable ABI and V representation limits
remain boundaries. Windows/Linux and other CPU, big-endian and 32-bit runtime
are outside the native comparison. Cross builds establish compilation only.
