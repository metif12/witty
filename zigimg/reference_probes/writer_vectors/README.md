# Vector output and repeated-tail counts

`writer.write_vec(data)` maps pinned Writer.writeVec and returns how many input
bytes it consumed. Vectors that fit unused capacity are copied completely,
without draining, even on a closed descriptor. Otherwise a fixed writer copies
its available prefix and returns `WriteFailed`. File writers make at most one
drain; pending bytes occupy the first of 16 nonempty vector slots. Empty input
vectors use no slots. A successful drain can consume zero input bytes, including
when it only emits pending bytes or switches a positional pipe to streaming.
Use the returned count to advance input before retrying.

`zigimg.count_splat(data, splat)` maps Writer.countSplat. It counts every prefix
vector once and the final vector splat times. A zero repeat still counts prefixes.
It does no IO. Empty data traps on the checked length subtraction; `write_vec`
asserts nonempty data before counting. Prefix addition, final multiplication /
addition and the writer cursor addition preserve Source's check order, including
in production. Repeated output itself remains a separate, unported API.

```v
data := ['ab'.bytes(), []u8{}, 'c'.bytes()]
assert zigimg.count_splat(data, 3) == 5
consumed := writer.write_vec(data)!
```

Vectors may share or overlap input storage. Headers and payload remain unchanged.
Aliasing inputs with the writer's backing buffer is excluded: Source uses
nonoverlapping memcpy for buffered writes. Keep all backing storage alive.
Existing reader/writer/C helper bodies are unchanged. One new C helper handles
scatter output, preserving macOS/Haiku positional first-vector behavior, native
POSIX writev/pwritev and Windows first-nonempty-vector behavior. Native retries on
interruption do not change the single-drain contract; syscall counts are not
established by this proof.

Debug/ordinary and ReleaseSafe/production each match:

| Observation | Count per mode | SHA-256 |
| --- | ---: | --- |
| Returning records | 19,836 | `f702612e7973a7c50e899bb9bef2a148ebe0c23c1edf903c38d1aa19f00cf3ee` |
| Returning boundary controls | 126 | `a708c7f056987a49b4131ecddc15b9e193da647063a6022e812f7f1f046ba019` |
| Exact panic/state pairs | 378 | `e6696a294ef29f105c2e796e3014ed61f647db47e6a614302baae6aeac3c2f4f` |

Each mode invokes 19,773 counts and 19,773 vector writes: 39,546 primary calls.
Setup, observation and optional flushes are separate. Groups contain 15,120
vector profiles, 126 single-API profiles and 4,590 every-byte profiles; duplicate
inputs are retained once. Twenty-two profiles cover empty/all-empty vectors,
shared/overlapping inputs, varied lengths, interleaved empties, lengths up to
255 and 15/16/17/32/33 vector counts. Fully buffered paths above 16 vectors and
file drains with/without a pending first slot are both exercised.

Memory and positional/streaming file writers cover capacities 0/1/8/64/128,
starts 0/3, empty/partial/full prefixes, repeats 0/1/3 through usize maximum,
caller-buffer XOR, every byte value and owned regular/pipe/closed bindings.
All complete returning records have an independent model of returned counts,
initialized backing bytes, pending/spare spans, logical position, exact input
payload, vector offsets/lengths, descriptor ownership, file contents and pipe
output. It includes partial fixed-buffer failure, positional first-vector
output, slot truncation, zero-progress transitions and failed position resets.
Absolute addresses are not compared; input offsets are relative to their payload.

The 378 exact failures comprise 336 counting overflows and 42 empty-vector
assertions. Counting failures include empty-vector subtraction, final-vector
multiplication and total addition. Failed processes have empty stdout, one exact
message and identical retained state. Independent reconstruction checks the phase
and complete initialized pre-call state, including input headers/bytes and
ownership. These failures precede IO. Observers capture state before opening
output and clean up owned resources through FullPanic/at_exit. The 126 returning
controls include nonoverflowing usize-maximum counts and ordinary write results.

Nine paired compile rejections per mode cover negative/boolean/above-usize repeat
arguments and flat/string/wider-element vector inputs to both APIs. External
consumers in both languages/modes check an aliased-usize repeat, shared headers,
zero repetitions, return counts, fixed-buffer partial failure, retained input
bytes and an all-empty write on a full writer. These finite controls do not
establish arbitrary caller coercions.

Three public regressions cover counting/aliasing, fixed-buffer partial output and
file slot limits. All 86 image test files and 17 focused production/application /
Windows/Linux checks pass. Historical array/byte output (13,358 records, 525
returning controls, 385 exact failures) and full/streaming IO (37,133 records,
17 generic traps, four compile boundaries) retain their hashes in both modes.
Historical generic traps do not establish exact state. Vaxis source is unchanged;
dependency builds pass. Cross builds establish compilation only.

Full unchanged Source, versions/selected libraries, implementation, probes,
directly imported helpers, shared owned writer fixture and inputs are pinned
before/after. Source bodies/visibility/syscalls are untouched. Initialized,
unlinked files with reset offsets, pipes and keepers are owned. Final
implementation/probe/runtime-runner/direct-helper bodies stay frozen; only
runtime-runner EXPECTED assignments change after ordinary discovery. Development
diagnostics retain the production pointer-array initialization requirement and
consumer syntax correction separately from passing gates. The final compiler
driver is frozen and run in both modes. Independent replay checks models,
records, failures, compiler controls, ownership, binaries, modes and provenance.
Lossless parent compression pins raw/compressed output. Proofs are archived from
an owned RAM workspace and every retained member is read back before commit and
release.

```sh
python3 zigimg/verify_writer_vectors_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --workdir /empty/proof/ordinary
python3 zigimg/verify_writer_vectors_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --v-prod --workdir /empty/proof/production
```

Runtime uses little-endian 64-bit macOS. Input/output-buffer aliasing, invalid or
concurrently mutated headers, custom/growing vtables, arbitrary record states,
larger lengths/offsets, usize totals beyond V's array carrier, partial native
drains, syscall counts, other devices, injected errors, timing/signals, OOM /
quotas, allocator lifetime and portable ABI remain boundaries. Windows/Linux,
other CPU, big-endian and 32-bit runtime are not established by cross builds.
Remaining repeated/header/other reader and writer APIs still need translation.
