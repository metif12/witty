# Single-callback reader fills

`ReadStream.fill_more()` translates `reader().fillMore()` from zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906` with Zig 0.15.2's reader implementation.
It rebases for one extra byte and invokes the reader callback once. A positional
file changing to streaming mode can return success with no new buffered bytes.
At offset zero it leaves queued input untouched until the next callback. A
nonzero transition reconciles the offset through forward discard and clears old
read-ahead. One callback does not imply one syscall: reconciliation may read
several times. A full unconsumed file buffer traps after rebase, before IO;
fixed memory readers return EndOfStream while retaining their pending span.

The dedicated C read-once helper exposes zero-progress transitions. Existing
scalar and vector helper bodies remain unchanged. WouldBlock on an established
streaming reader permits a later retry; failed nonzero offset reconciliation
remains sticky. Compaction precedes a full-buffer trap or sticky failure, while
an already consumed short buffer retains its cursors on sticky failure.

## Reproduce

From the repository root, using the pinned Source checkout and compilers:

```sh
python3 zigimg/verify_reader_fill_more_reference.py "$SOURCE" "$ZIG" "$V" --workdir /path/to/empty/ordinary
python3 zigimg/verify_reader_fill_more_reference.py "$SOURCE" "$ZIG" "$V" --v-prod --workdir /path/to/empty/production
```

The native target defaults to `aarch64-macos.14.0`. Ordinary pairs Zig Debug with
V ordinary; production pairs ReleaseSafe with `-prod`. The runner supplies
`VEXE` and `V_C_ERROR_BUG_REPORT_DISABLED=1`, retains argv, build modes, outputs,
inputs and provenance, and copies the entire Source `src` without modifying
bodies or visibility. The pinned Source tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`;
selected stdlib SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Compiler versions, selected path/encoder libraries, production implementation,
probes, shared fixture headers, directly imported helpers and inputs are checked
before and after comparison. No Source reader syscall is intercepted.

## Returning records

Both modes match **3,794 records / 11,382 fills / 26,558 primary calls**. Each
record calls fill_more three times, consumes pending bytes three times and seeks
relatively once. Construction, priming and observations are separate calls.
Groups contain 384 memory, 1,728 file, 68 retained-EOF, 504 empty-transition,
756 prefilled-transition, 162 reseed, 96 failed-pending and 96 failed-consumed
records. File buffers have capacities 1/2/8/32; payload lengths are
0/1/7/8/9/31/32/33/64 with arithmetic bytes. Distinct start offsets, caller
consumption, relative seeks and controlled open/closed pipe replacements compare
all initialized backing bytes, saved successful output, pending input, logical
positions, size/errors, normalized descriptor ownership and remaining wire bytes.
SHA-256 (joined output lines without a trailing newline):
`12dd485c887eac00bbbd73a11ee017b558af2367e50c35b648cd3adaf0188919`.

Inputs have eleven fields:
`kind|warmup|capacity|start|consume-mode|payloadhex|replacement|consumed|seed|prime|delta`.
Kinds select fixed memory, positional file or streaming-initialized file.
Warmup selects no preload, prefill/toss before replacement, or reseeding after
the first fill/seek. Consumption selects none, all, one or rounded-up half.
Replacement selects none, an open pipe or a closed pipe. Prime selects none,
peek-capacity or peek-capacity followed by toss-buffered. The ten output parts
are initial, primed, first fill, first consumption, seek, second fill, second
consumption, third fill, third consumption and wire. Reader snapshots contain
`status|position:size-or-error:valid:refs|backinghex|saved-outputhex|pendinghex`.

## Controls and consumers

The **576 distinct controls** comprise **350 returning records**, SHA-256
`98afd96ac4a10bafe0b94155609a1a13f2f468a97fd861f382d5ffe221a625bf`,
and **226 exact panic/state pairs**, SHA-256
`9a9e02daa7a6d12f6b289d97b995ee3d75f47f722ca54a7c7e47d585f81bce7e`.
Fifty-eight fail with exactly `reached unreachable code`: four zero-capacity
files, eighteen second fills into full buffers, eighteen fills after rewind to
full buffers and eighteen full prefills. Zero-capacity memory returns EOF.
Another 168 fail with exactly `integer overflow` in public getPos observations:
84 before fill_more after priming and 84 after fill_more returns ReadFailed.
Both exits fail with empty stdout, a single exact panic message and identical
initialized retained state. Observers omit getPos, handle size errors and
capture status, storage, saved results, pending spans and descriptor ownership
before opening the observation file. Source FullPanic and V at_exit clean up
only owned resources.

Seventeen additional compiled consumer records / 51 fills / 119 primary calls
per mode assert concrete expectations for all three fills: memory EOF, file
compaction, retained/consumed EOF, open/closed/seeded zero progress, prefilled
discard, sticky pending/consumed/rewound state, reseed recovery and one-byte
fills. Output SHA-256:
`d8314676dd60b5e0debe7c2f10d4962f49aec1da90178510850e22d7fba6f33e`.
Four public unit regressions accompany these comparisons. All 70 image and
58 Vaxis test files pass, with 46 production, application and platform checks.
Historical buffered, delimiter streaming/discard/nullable/exclusive/inclusive
and full-stream matrices retain their previous hashes in both modes.

## Evidence and boundaries

The first implementation reused the scalar helper, which retried a zero-offset
transition immediately. Native comparison exposed 195 mismatching records;
that frozen implementation, runner and diagnostics remain separate evidence.
The corrected production/probe/runner/helper bodies remain frozen during final
comparison; only expected-value assignments change after ordinary discovery.
Interrupted jobs and disk-exhaustion failures are retained separately from
successful final checks. Parent-side lossless output compression records both
raw and compressed hashes. An owned RAM volume mounted at the same work path
allowed completion after disk exhaustion; 7,200 transferred files were hash
checked. Independent replay verifies outputs, native classifications, exact
failure states, consumer expectations, ownership, binaries, build modes and
provenance. Every retained member is read back from the persistent archive
before committing and releasing the temporary volume.

The C wrapper reuses separately copied/hashed reader replacement and exclusive
payload fixtures: initialized unlinked O_EXCL/CLOEXEC files, reset live offsets,
owned nonblocking pipes and keeper descriptors below 128. Arbitrary custom
callbacks, overlapping storage, arbitrary construction/copy sequences, other
devices, larger buffers/offsets, concurrent reuse, syscall counts, timing/signals,
injected errors, OOM/quotas, allocator lifetime, portable ABI and V representation
limits remain boundaries. Windows, Linux, other CPU selections and big-endian/
32-bit runtime are outside this native comparison. Cross builds establish
compilation only.
