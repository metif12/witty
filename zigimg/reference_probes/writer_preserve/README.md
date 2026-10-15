# Preserved byte repetitions

```v
writer.splat_byte_preserve(5, `x`, 3)!
// For a full fixed buffer containing abcdefgh, retains defghxxx.
```

`WriteStream.splat_byte_preserve(preserve, byte, count)` maps pinned
Writer.splatBytePreserve. It retains checked cursor addition before inspecting
preserve. If all new bytes fit, it fills them directly and ignores preserve,
including usize maximum. Zero count returns without compaction. Otherwise it
first attempts short writes while remaining count exceeds preserve, then checks
whether the remainder fits. If that phase finishes without returning, it moves
the last preserve buffered bytes to the front when preserve is smaller than the
buffered length, and writes the remaining repeated bytes through short writes.

This preserves Source's unusual ordering. A full fixed buffer can fail before
compaction when count exceeds preserve. When count does not exceed preserve,
compaction can discard an earlier buffered head without emitting it, even for a
file writer. Logical position can decrease when fewer bytes remain buffered.
Preserve is not validated against buffer capacity; large values are accepted and
may prevent compaction. Failed writes retain partial output and scratch effects.
Existing reader/writer/C helper bodies are unchanged. General custom/growing
vtables remain unrepresented.

Debug/ordinary and ReleaseSafe/production each match **18,079 returning records**,
SHA-256 `a95d29c7312843dc2a621c842e4a0bd3a46be85c2c8844a47ebbdf3a1e05ceb7`.
Each record invokes the new method once. Setup/observations/optional flushes are
separate. Groups contain 10,400 preservation, 3,848 scratch and 3,831 every-byte
profiles, retaining duplicate specifications once. Memory and positional /
streaming files cover capacities 0/1/8/63/64/65/128, starts 0/3, empty/partial /
full prefixes, preserve values around capacity plus usize maximum, counts through
513, every byte value, and owned regular/pipe/closed bindings. Threshold cases
cross 63/64/65 spare-byte and repetition-block boundaries. File retries retain
pending bytes, 16-slot limits, byte-block preparation, positional first-vector
output, zero-progress pipe mode changes and failed position resets.

Every complete returning record has an independent model of status, initialized
backing/pending/spare bytes, logical position, unchanged input payload and relative
input slice header, owned references, file contents and pipe output. Caller-buffer
mutation plus optional flushes check retained and emitted bytes. Compaction is
modeled independently with overlapping slice copies. Absolute addresses are not
compared. Finite generation caps output at 4,096 bytes and short calls at 128;
large/unbounded successful operations are excluded.

The **984 returning controls** retain SHA-256 `489cf5e120fadc21e51a1d073e63be157a8212fb9663de5f7fb94a40732698da`.
They include zero count, preserve/count usize maxima that complete or fail
promptly, compaction, fixed-buffer failures, closed-descriptor scratch effects,
and pipe transitions. The **360 exact panic/state pairs** retain SHA-256
`94f7ad5da10c18d47efd467ae9f9c94c29aefe4f7ba82347fe314aa040da9ed0`. All are initial checked cursor-addition
overflows before IO, compaction or scratch writes. Failed processes have empty
stdout, one exact message and identical retained state. Independent reconstruction
checks full initialized pre-call state, phase, input payload/header and ownership.
FullPanic/at_exit observers capture state before opening retained output and clean
up owned bindings. Other panic states remain outside this finite comparison.

Eight paired compile rejections per mode cover invalid preserve/count/byte types.
The separate byte-256 boundary retains Source rejection, V ordinary warning /
write of zero and V production rejection. External consumers in both languages /
modes check aliased byte/count inputs, compaction, usize-maximum preserve with
zero count, and unchanged retained output after failure. General caller coercions
remain outside these controls.

Three public regressions pass. All 89 image test files and 17 focused production /
application/Windows/Linux checks pass. Historical complete writes (32,016 records,
1,176 returning controls, 770 exact failures) and full/streaming IO (37,133 records,
17 generic traps, four compile boundaries) retain their hashes in both modes.
Generic traps do not establish exact state. Vaxis runtime tests are not rerun;
source is unchanged and dependency builds pass. Cross builds establish compilation
only.

Full unchanged Source, versions/selected libraries, implementation, probes,
directly imported helpers, shared writer fixture and inputs are pinned
before/after. Source bodies/visibility/syscalls are untouched. Initialized,
unlinked files with reset offsets, pipes and keepers are owned. Implementation /
probe/runtime-runner/direct-helper bodies stay frozen; only runtime-runner
EXPECTED assignments change after ordinary discovery. Recorded finite local jobs
survive headless input turns. Independent replay checks records, complete models,
compaction, failures, compiler controls, ownership, binaries, actual modes and
provenance. Lossless parent compression pins raw/compressed output. Proofs are
archived from an owned RAM workspace; every retained member is read back before
commit and release.

Invalid/concurrently mutated headers, arbitrary records, custom/growing vtables,
larger buffers/offsets/output, usize totals beyond V's array carrier, partial
native drains, syscall counts, other devices, injected errors, timing/signals,
OOM/quotas, allocator lifetime, portable ABI and remaining V representation limits
remain boundaries. Runtime uses little-endian 64-bit macOS. Windows/Linux, other
CPU, big-endian and 32-bit runtime remain outside the proof. Header/other reader
and writer APIs remain unported.

```sh
python3 zigimg/verify_writer_preserve_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --workdir /empty/proof/ordinary
python3 zigimg/verify_writer_preserve_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --v-prod --workdir /empty/proof/production
```
