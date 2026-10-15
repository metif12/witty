# Complete vector and repeated-output writes

```v
mut data := ['ba'.bytes(), 'na'.bytes()]
writer.write_splat_all(mut data, 2)!
// Writes banana. Input slice headers and payload are restored/unchanged.
```

`write_vec_all(mut data)`, `write_splat_all(mut data, splat)`,
`splat_byte_all(byte, count)` and `splat_bytes_all(bytes, splat)` map pinned
Writer's complete vector/repeated-output methods. They retry short/zero progress
until completion or WriteFailed. The vector methods temporarily replace borrowed
slice headers and restore them on ordinary success/error. Payload bytes stay
unchanged; inputs may share/overlap each other, but must not alias output backing.
Keep all backing storage alive. General custom/growing vtables remain unrepresented.

Empty vector lists succeed in both vector methods, unlike short write_vec /
write_splat. Zero repeat still writes prefixes. Empty patterns contribute no
bytes for usize maximum. splat_byte_all with zero count skips the short method;
splat_bytes_all checks total multiplication and calls the short method even for
zero output. Multiplication/addition/subtraction checks retain Source order and
production panic behavior. Fixed-buffer errors keep partial output and restore
input headers. File retries retain pending bytes, 16-slot truncation, byte-block
preparation, positional first-vector writes, and pipe mode/error transitions.
Existing reader/writer/C helper bodies are unchanged.

Debug/ordinary and ReleaseSafe/production each match **32,016 returning records**,
SHA-256 `502310555124f915d2936f00247b223335a4535edaa976ac6d9031ed4de1ea97`.
Each record invokes one new method: 6,048 vector-all, 18,676 splat-all, 2,206
byte-all and 5,086 slice-all calls. Setup/observations/optional flushes are
separate. Groups contain 25,440 complete-write, 3,510 scratch/retry and 3,066
every-byte profiles, retaining duplicate input specifications once. All 22 shared
profiles are exercised: empty/all-empty/shared/overlapping/interleaved-empty
vectors, lengths through 255, vector counts through 33, and every byte value.

Memory and positional/streaming files cover capacities 0/1/8/63/64/65/128,
starts 0/3, empty/partial/full prefixes, repeats through 513, and owned regular /
pipe/closed descriptors. Scratch cases cross 63/64/65 spare thresholds, block
boundaries and slot exhaustion, including retries after pending-only positional
output and zero-progress pipe transitions. Every complete record has an
independent model of final status, initialized backing/pending/spare bytes,
logical position, input payload and relative slice offsets/lengths, owned
references, file contents and pipe output. Caller-buffer mutation plus optional
flushes check retained/emitted bytes. Absolute addresses are not compared.

The **1,176 returning controls** retain SHA-256 `7898d58c2de377fa6b3a544fba20a0a59e17cca347bf6acc623640a6bb505652`.
They cover empty/zero cases, the unused repeat field in vector-all fixtures, valid
usize-maximum operations that complete or fail promptly, restored headers on
ordinary errors and scratch changes before IO failure. Finite generation excludes
unbounded/large successful output: the model caps output at 4,096 bytes and short
calls at 128. The **770 exact panic/state pairs** retain SHA-256 `32858e7a9472822eaa24f8cc6431f5beac669d09f1ed6f2d020b6720d54bf4f2`.
All are checked overflows. Failed processes have empty stdout, one exact message,
and identical retained state before IO/scratch output. Independent reconstruction
checks full initialized state, phase, headers/payload and ownership. FullPanic /
at_exit observers capture state before opening retained output and clean up owned
bindings. Arbitrary panic states and native partial-drain counts remain outside
this finite comparison. Nonzero temporary header truncation caused by a partial
native vector write is not established by these runtime fixtures.

Twenty-one paired compile rejections per mode cover invalid repeat/data/byte
types and immutable vector headers. The separate byte-256 boundary retains
Source rejection, V ordinary warning/write of zero and V production rejection.
External consumers in both languages/modes check aliased byte/count inputs,
empty/zero/usize-maximum cases, completed output, restored headers and retained
partial failure output. General caller coercions remain outside these controls.

Three public regressions pass. All 88 image test files and 17 focused production /
application/Windows/Linux checks pass. Historical short repetition (21,738 records,
770 returning controls, 910 exact failures) and full/streaming IO (37,133 records,
17 generic traps, four compile boundaries) retain their hashes in both modes.
Generic traps do not establish exact state. Vaxis runtime tests are not rerun;
source is unchanged and dependency builds pass. Cross builds establish compilation
only.

Full unchanged Source, versions/selected libraries, implementation, probes,
directly imported helpers, shared writer fixture and inputs are pinned
before/after. Source bodies/visibility/syscalls are untouched. Initialized,
unlinked files with reset offsets, pipes and keepers are owned. Implementation /
probe/runtime-runner/direct-helper bodies stay frozen; only runtime-runner
EXPECTED assignments change after ordinary discovery. Independent replay checks
records, models, restored headers, failures, compiler controls, ownership,
binaries, actual modes and provenance. Lossless parent compression pins raw /
compressed output. Headless turn interruptions are retained as complete verified
snapshots. Pinned parent adapters replay completed commands only after checking
exact arguments/environments and raw/compressed logs, then run the missing
suffix through the unchanged runtime runner. Replay verifies reused binaries,
logs/state and command prefixes against those snapshots. The remaining finite
checks run in a recorded local session across input turns.
Proofs are archived from an owned RAM workspace; every retained
member is read back before commit and release.

Input/output aliasing, invalid/concurrently mutated headers, custom/growing
vtables, arbitrary records, larger buffers/offsets/output, usize totals beyond
V's array carrier, partial native drains, syscall counts, other devices, injected
errors, timing/signals, OOM/quotas, allocator lifetime, portable ABI and remaining
V representation limits remain boundaries. Runtime uses little-endian 64-bit
macOS. Windows/Linux, other CPU, big-endian and 32-bit runtime remain outside the
proof. Preserved repetition/header/other reader and writer APIs remain unported.

```sh
python3 zigimg/verify_writer_all_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --workdir /empty/proof/ordinary
python3 zigimg/verify_writer_all_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --v-prod --workdir /empty/proof/production
```
