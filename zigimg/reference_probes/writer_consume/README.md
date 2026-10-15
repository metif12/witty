# Writer buffer consumption

`consume(count)` and `consume_all()` translate pinned std.Io.Writer.consume /
consumeAll through the existing WriteStream adapter. They account for bytes a
drain has already handled; they do no IO and do not update file_pos.

If count is less than the pending length, consume moves the remaining bytes to
the beginning of the same backing, reduces the pending length and returns zero.
Otherwise it clears the pending length and returns count minus the old length.
Counts larger than capacity, including usize maximum, are valid. consume_all
clears the pending length and returns zero without changing backing bytes. The
caller remains responsible for output and external file-position accounting.
Calling these helpers alone can discard pending output without writing it.

Saved pending and unused views keep their original lengths and offsets. They
observe compaction, later caller writes and refills through shared backing.
Bytes outside the moved destination stay unchanged. Logical position changes
with pending length; underlying file position and output stay unchanged until
a later write/flush. Old IO and C helper bodies, Source bodies, visibility and
syscalls remain unchanged.

Both Debug/ordinary and ReleaseSafe/production match:

| Observation | Count per mode | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 29,078 | `d2d163291c934845b3c6383a9dc78fc583a9ab352f969f8b486cb97b66e302ca` |
| Returning boundary controls | 366 | `f74c68332a27cd56879be6ae686f07e935469693aecf38f2e52ee9b69a5a1673` |

Each record makes two helper calls: 43,617 consume and
14,539 consume_all calls per mode, 58,156 total.
Caught WriteFailed from subsequent writes/flushes is included in returning
records. These valid-buffer helpers have no asserted runtime trap cases here.

The matrix includes zero/one/interior/equal/excess/usize-maximum counts, maximum
minus one controls, repeated clear/consume calls, memory/positional/streaming
writers, capacities 0/1/8/17, starts zero/three, empty/full/partially pending
buffers, regular/replaced-pipe/closed descriptors, every byte value, saved-view
and caller mutations, later refills and flushes. Groups contain 4,080
consume-and-clear, 24,576 every-byte and 422 saved-view records after exact input
deduplication. Both old saved views and fresh unused views remain borrowed.

Every record and control has an independent model of all nine snapshots:
initialized backing, pending length/bytes, logical position, fresh unused-view
length/offset/bytes, both saved-view lengths/offsets/bytes, descriptor validity /
reference observations, count results, later write/flush results and complete
file/pipe output. It reconstructs overlapping memmove effects and retained bytes,
then separately models positional/streaming writes and pipe mode transitions.
Absolute addresses and syscall counts are excluded. Empty backing normalizes
view offsets; nonempty backing observes actual offsets, including empty views.

Five paired compiler rejections per mode check invalid count types/ranges and
extra consume_all arguments. One separately retained constraint boundary rejects
in Source and runs in V: pinned V accepts a mutating call on an immutable writer
copy. The V program proves that copy's cursor changes while its original cursor
stays unchanged, and compaction updates their shared backing. Source rejects the
corresponding const Writer copy. This is not a claim of equivalent constness.
External consumers in both languages/modes verify count aliases, compaction,
saved views, excess/maximum counts and repeated consume_all calls.

Three public regressions, all 93 image test files and 17 focused production,
application, Windows and Linux build checks pass. Historical integer slice
writes retain 25,740 records and 756 returning controls per mode. Full/streaming
IO retains 37,133 records, 17 generic traps and four compile boundaries per mode.
Their prior hashes are unchanged. Generic traps do not establish exact state.
Vaxis source is unchanged; runtime tests are not rerun and dependency builds
pass. Cross builds establish compilation only.

Complete locked zigimg Source retains
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
Selected compiler libraries retain
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`;
whole Io.zig additionally retains
`09df1114cba703f824337f20489c7df5294db9f07961d4ac46abbbbf9c7ecaef`.
Compiler, path/encoder, implementation, probe, direct-helper and input pins are
checked before/after. Runtime bodies are frozen before ordinary discovery; only
EXPECTED assignments change afterward. Compiler controls check their own final
fixtures and runner before/after too. Independent replay checks every full
record/model, compiler control, actual mode, binary, provenance pin and unchanged
old IO/C body. Lossless compressed outputs pin raw/compressed bytes. Every
retained archive member is read back before committing exact reviewed files and
releasing owned RAM. Recorded local jobs survive headless input turns.

A 181-record preflight passes. Preliminary probe compilation before adding the
actual saved pending-offset observer is retained separately. The first compiler
run expected V to reject the immutable-copy call; its accepted compile and logs
are retained and independently checked. A final Source const-copy / V mutable-
copy boundary checks the actual behavior. The original comparison/historical
jobs are preserved unchanged; final support checks have their own recorded job
and driver pins. No runtime implementation/probe/model changed during this
compiler-control correction.

From the repository root, with pinned compilers and a fresh work directory:

```sh
python3 zigimg/verify_writer_consume_reference.py \
  /Users/alex/.cache/witty-src/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906 \
  /Users/alex/.cache/witty-jpeg-scan-20261013/tools/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --workdir /path/to/fresh/proof
```

Add `--v-prod` for ReleaseSafe / V production. Runtime is little-endian 64-bit
macOS. Windows/Linux, other CPUs, 32-bit/big-endian runtime, arbitrary devices /
short drains, injected errors/signals, timing, syscall counts, invalid or
concurrently changed headers/cursors, huge storage/OOM, allocator lifetime,
portable ABI and remaining V representation limits remain outside the proof.
The caller must keep the backing alive. Custom vtables / actual native drain
integration and other IO APIs remain outside this checkpoint.
