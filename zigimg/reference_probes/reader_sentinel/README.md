# Required sentinel slices

`ReadStream.peek_sentinel(sentinel)` and `take_sentinel(sentinel)` translate
pinned Reader.peekSentinel/takeSentinel. Both require a matching byte; an
unterminated EOF tail returns EndOfStream without consuming that tail. Peek does
not consume the result; take consumes its prefix and sentinel, including a
successful empty prefix. Full file buffers without a match return StreamTooLong,
even when the actual file ends there. Native descriptor-reconciliation position
quirks remain preserved. All previous reader and C adapter bodies are unchanged.

V returns an opaque `SentinelSlice` record because it has no sentinel-qualified
slice type. `bytes()` borrows the prefix; `with_sentinel()` borrows the complete
span, including the final byte. Their starts coincide, including empty prefixes.
The record stores the live borrowed span, so payload mutation reaches the
original buffer and caller-buffer mutation is visible in the view. Tossing
pending input preserves that storage; later fill/peek/take operations may rebase
or overwrite it. Keep the reader/backing storage alive and preserve the
terminator. Direct external construction and storage access are rejected.
Arbitrary constructor/alias/copy bypasses are outside these returned-view tests.

```v
view := reader.take_sentinel(0)!
prefix := view.bytes()
terminated := view.with_sentinel()
assert terminated[prefix.len] == 0
```

Source's marker is a comptime u8; V accepts a runtime u8 and does not encode its
value in the result type. The Source fixture dispatches to all 256 comptime
values, while V receives the same byte at runtime. A separate compile control
confirms Source rejects a runtime marker and V runs markers 0/255. Both reject
literal -1. Source rejects literal 256 in both modes; pinned V warns, compiles
and truncates it to 0 in ordinary mode, but rejects it in production. That
compiler conversion difference is recorded separately from valid-byte parity.

## Reproduce

```sh
python3 zigimg/verify_reader_sentinel_reference.py "$SOURCE" "$ZIG" "$V" --workdir /path/to/empty/ordinary
python3 zigimg/verify_reader_sentinel_reference.py "$SOURCE" "$ZIG" "$V" --v-prod --workdir /path/to/empty/production
```

Source is zigimg `d7b7ab0ba0899643831ef042bd73289510b39906`, Zig 0.15.2 and
V 0.5.2. Ordinary pairs Source Debug with ordinary V; production pairs ReleaseSafe
with V `-prod`. Target defaults to `aarch64-macos.14.0`. VEXE and
V_C_ERROR_BUG_REPORT_DISABLED=1 are pinned, with owned temporary/cache paths.
Full unchanged Source tree SHA-256:
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
Selected stdlib SHA-256:
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Versions, selected math/simd/path libraries, implementation, probes, shared
fixtures, directly imported helpers and inputs are checked before/after.
Source bodies, visibility and reader syscalls remain untouched.

## Returning and borrowed records

Both modes match **12,192 returning records / 36,576 sentinel reads / 48,768
primary calls**, comprising 8,208 basic, 1,536 every-sentinel and 2,448 replacement
profiles, deduplicated by input. Each record performs three sentinel reads and
one relative seek; setup/priming/observations are separate. Output SHA-256 (joined
lines without a trailing newline):
`24d156384636b33317352082b3fd68a7a0f2b6300b7b55233f8e90ebac05a8c4`.

Memory, positional and streaming files cover lengths 0/1/7/8/9/31/32/33/64,
capacities 0/1/8/32, start/EOF offsets, present/absent sentinels, empty prefixes,
full/partial fills and relative seek -1/0/1. Every sentinel byte runs both APIs
through all reader kinds. Original read-ahead survives controlled replacement
with open/closed owned pipes, consumed prefixes 1/7, seed boundaries and
priming/toss choices. Complete backing storage, copied successful spans including
the terminator, pending input, positions, size/errors, references and untouched
wire bytes match. An independent nonreplacement model checks the first match,
counts/progress, EOF versus full-buffer failures and physical streaming progress
separately from logical rewind. Replacement position changes are compared to
native observations rather than assuming a peek always preserves logical position.

Another **3,120 borrowed records / 6,240 primary calls** check prefix/full-span
aliasing, exact offsets into the supplied buffer, saved copies, caller-buffer
XOR, view XOR, positions and retained bytes after toss. All sentinel values run
with empty/nonempty prefixes; additional offsets and longer prefixes cover
memory and both file reader kinds. Mutation preserves the actual terminator,
keeping Source's sentinel contract valid. Borrowed output SHA-256:
`dac10ac470a9d1c38d17383af20fe209dc452b3177fea44ddfdcfe15c82dda1d`.

Input fields are
`kind|api|capacity|start|sentinel|payloadhex|replacement|consumed|seed|prime|delta`.
API 0 peeks and 1 takes. Seven returning parts contain initial/primed state,
three reads, relative seek and wire bytes. Snapshots use
`status|position:size-or-error:valid:refs|readerhex|copied-full-spanhex|pendinghex`.
Borrowed records have initial, borrow, caller mutation, view mutation and toss
phases; the last four append borrowed full-span bytes and backing-buffer offset.

## Controls, consumers and evidence

The **132 controls** separate **48 returning records**, SHA-256
`98bd55c52b3a4ff654d075287a96e18ca6affc11c54f5ba338dee77fcf602b94`,
from **84 exact integer-overflow panic/state pairs**, SHA-256
`409750f80c4727cbc6664d64fd0c0df30cc2aa568a09cfd3d665f27bfb4108b3`.
Failures occur in public getPos after priming, before the sentinel call. Both
failed exits have empty stdout, one exact message and matching initialized state.
Observers omit getPos, capture bytes before opening state files, and clean up
only owned resources through Source FullPanic or V at_exit.

Twenty-three compiled consumers / 69 reads / 92 primary calls per mode assert
empty prefix consumption, required EOF sentinels, start offsets, zero/one-byte
buffers, full file versus memory EOF, read-ahead, partial fills, high markers,
rewind, pipe EOF/ReadFailed and sticky pending success/failure. SHA-256:
`b69a05205090943cee5fa8e3d97da51abdbc7014a242e5b6f62d0e6cc9cd7b5a`.
Three public regressions accompany the proof. All 77 image test files pass in
three batches, with 17 production/application/Windows/Linux checks. Vaxis runtime
sources/tests are unchanged and were not rerun here; its dependency builds pass.
Historical fixed-array and full-stream matrices retain their hashes in both modes.

An initial independent model wrongly required replacement peeks to preserve
logical position. All native/V output records already agreed; the corrected model
restricts that position prediction to nonreplacement records and retains the
complete native replacement-state comparison. Compile diagnostics separately
retain initial expectations of a hard ordinary oversized-literal rejection and
ordinary-style production acceptance. Original scripts, fixtures and outputs
remain separate from passing gates. Final production/probe/runner/helper bodies
remain frozen; only expected assignments change after ordinary discovery.

Fixtures copy/hash the exclusive-payload and descriptor-replacement helpers,
use initialized unlinked owned O_EXCL/CLOEXEC files with reset offsets and owned
nonblocking pipes/keepers. Parent-side lossless compression pins raw/compressed
logs. Independent replay checks values/progress, sentinel-preserving mutations,
classifications, exact failures, consumers, ownership, binaries, modes and
provenance. Retained evidence is persisted from an owned RAM workspace and every
archive member is read back before commit and release.

Invalidated views, terminator-changing mutation, arbitrary constructed/copied
records, other callbacks/devices, larger spans/buffers/offsets, concurrent reuse,
syscall counts, timing/signals, injected errors, OOM/quotas, allocator lifetime
and portable ABI remain boundaries. Runtime comparison uses little-endian
64-bit macOS; Windows/Linux and other CPU, big-endian and 32-bit runtime remain
outside this proof. Cross builds establish compilation only.
