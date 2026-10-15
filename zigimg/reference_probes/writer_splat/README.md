# Short repeated-output writes

`writer.write_splat(data, splat)` copies each prefix vector once and repeats only
the final vector. `splat_byte(byte, count)` and `splat_bytes(bytes, count)` repeat
one byte or one slice. These map pinned Writer.writeSplat/splatByte/splatBytes and
return the input byte count consumed. They make at most one file drain and may
return a short count or zero; callers handle retry/progress. The all/preserve /
header variants remain unported.

```v
consumed := writer.write_splat(['a'.bytes(), 'bc'.bytes()], 3)!
// A fully buffered success consumes 7 bytes: abcbcbc.
```

Zero repetitions still copy write_splat prefixes. Empty patterns contribute no
bytes even for usize maximum. Empty data traps before counting in write_splat;
the helpers wrap their input in a nonempty vector and accept an empty slice.
Count multiplication/addition and cursor addition retain Source's checked order
and exact production traps. Buffered writes copy complete output. Fixed-buffer
failures retain as much prefix/partial-pattern output as fits.

File output includes pending bytes and up to 16 nonempty vector slots. Multi-byte
patterns reuse input pointers. Repeated bytes use a 64-byte local block, or the
writer's spare buffer when at least 64 bytes remain. Preparing this block can
change initialized spare bytes before a failed write, a zero-progress pipe
transition, or positional output of an earlier vector. Repeats can exceed the
available vector slots and return short counts. macOS/Haiku positional and
Windows output keep their first-nonempty-vector behavior; Windows bypasses the
POSIX byte-block preparation. Existing reader/writer/C helper bodies are unchanged.

Input vectors may share/overlap their input storage, and their headers/bytes stay
unchanged. Inputs must not alias the writer's buffer because Source uses
nonoverlapping memcpy. Keep input/output backing storage alive through the call.

Debug/ordinary and ReleaseSafe/production each match:

| Observation | Count per mode | SHA-256 |
| --- | ---: | --- |
| Returning records | 21,738 | `dfb8d4899f9d47c5e39adc85d981a9658b5a5193a26a3617c4d4eb859da161db` |
| Returning boundary controls | 770 | `9e635f515116defd51411357bb42092d7f8b378071bc2a0961c5bea4b464b3c0` |
| Exact panic/state pairs | 910 | `d0829f0ed85f3e5672c5543a82f2da1dffda26876913a29aa7be0c8e2cb18732` |

Each record invokes one new method: 14,446 vector repetitions, 2,206 byte and
5,086 slice repetitions per mode. Setup/observation/optional flushes are separate.
Groups contain 15,840 repeat profiles, 3,600 scratch profiles and 2,298 every-byte
profiles, retaining duplicate inputs once. Seventeen selected profiles from the
shared 22-profile table include empty/all-empty vectors, aliasing/overlapping
inputs, interleaved empty vectors, lengths through 255 and vector counts through 33.

Memory and positional/streaming files cover capacities 0/1/8/63/64/65/128,
starts 0/3, empty/partial/full prefixes, repeats through 513 and usize maximum,
every byte value and owned regular/pipe/closed descriptor bindings. Dedicated
cases cross 63/64/65 spare-byte thresholds, repeat block boundaries and the
16-slot limit, including prefix exhaustion that skips byte-block preparation.
Caller-buffer mutation and optional flushes verify retained and emitted output.

Every complete returning record has an independent model of consumed counts,
initialized backing/pending/spare bytes, logical position, input payload and
relative vector offsets/lengths, owned references, file contents and pipe output.
Models include scratch writes before IO failure, slot truncation, positional
first-vector output, partial fixed-buffer failure, zero-progress mode changes
and failed position resets. Absolute addresses are not compared.

The 910 exact failures comprise 770 checked overflows and 140 empty-data assertions.
They precede IO and scratch mutation. Both processes have empty stdout, one exact
message and identical retained state. Independent reconstruction checks the full
initialized pre-call state, input headers/bytes, phase and ownership. Observers
capture state before opening output and clean up through FullPanic/at_exit.
The 770 returning controls include zero/empty helpers, valid usize-maximum short
writes and ordinary write errors, including scratch changes on closed descriptors.

Sixteen paired compile rejections per mode cover invalid repeat/data/byte types.
A separate byte-literal boundary retains Source's rejection of 256, V ordinary's
warning and write of zero, and V production's rejection. External consumers in
both languages/modes check aliased count/byte inputs, zero repetitions, empty
patterns with usize maximum, consumed counts, unchanged input and retained partial
pattern output. These finite controls do not establish arbitrary caller coercions.

Three public regressions cover prefix/tail semantics, fixed-buffer partial
patterns and streamed byte blocks. All 87 image test files and 17 focused
production/application/Windows/Linux checks pass. Historical vectors (19,836
records, 126 returning controls, 378 exact failures) and full/streaming IO
(37,133 records, 17 generic traps, four compile boundaries) retain their hashes
in both modes. Generic traps do not establish exact state. Vaxis source is
unchanged; dependency builds pass. Cross builds establish compilation only.

Full unchanged Source, versions/selected libraries, implementation, probes,
directly imported helpers, shared owned writer fixture and inputs are pinned
before/after. Source bodies/visibility/syscalls are untouched. Initialized,
unlinked files with reset offsets, pipes and keepers are owned. Final
implementation/probe/runtime-runner/direct-helper bodies stay frozen; only
runtime-runner EXPECTED assignments change after ordinary discovery. The original
array-concatenation fixture error is retained separately from passing gates.
Independent replay checks records, complete models, aliases, failures, compiler
controls, ownership, binaries, actual modes and provenance. Lossless parent
compression pins raw/compressed output. Proofs are archived from an owned RAM
workspace; every retained member is read back before commit and release.

```sh
python3 zigimg/verify_writer_splat_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --workdir /empty/proof/ordinary
python3 zigimg/verify_writer_splat_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --v-prod --workdir /empty/proof/production
```

Runtime uses little-endian 64-bit macOS. Input/output-buffer aliasing, invalid or
concurrently mutated headers, custom/growing vtables, arbitrary records, larger
buffers/offsets, usize totals beyond V's array carrier, partial native drains,
syscall counts, other devices, injected errors, timing/signals, OOM/quotas,
allocator lifetime and portable ABI remain boundaries. Windows/Linux, other CPU,
big-endian and 32-bit runtime are not established by cross builds. Remaining
all/preserve/header/other reader and writer APIs still need translation.
