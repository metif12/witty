# Private POSIX image file close contracts

`verify_image_close_reference.py` compares the pinned image path dependency's
`std.fs.File.close`/`std.posix.close` with V's private `image_close_file` helper,
using unchanged zigimg `d7b7ab0ba0899643831ef042bd73289510b39906`, Zig 0.15.2 and
V 0.5.2. Both Debug/ordinary and ReleaseSafe/production run on native little-endian
`aarch64-macos.14.0`, linked with libc.

```sh
python3 zigimg/verify_image_close_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` in another empty directory. `--timeout` bounds commands
(default 600 seconds). Evidence retains complete Source, exact V module copies,
fixtures/C helper, inputs, binaries, commands, raw observations, initialized panic
snapshots and provenance. Compiler temporaries use TMPDIR/VTMP.

The original 312 valid-close records already matched. The first double close
panicked in Source with `reached unreachable code` while V returned normally.
The original module/binaries, successful records, native state and V output remain
retained. POSIX close now checks the actual syscall result immediately: BADF maps
to the exact unreachable panic, including production. Success and other errors
remain ignored as in pinned std.posix.close; no close retry is added. Windows
closing retains its existing stdio behavior. Both private file objects and copied
handles preserve their descriptor value; closing either closes the shared OS
resource. No implicit stream flush is added.

**328 returning records / 656 close calls** match in both modes, SHA-256
`7a25a87d2f39b9644eefd873ac9a72b3f4ab0239909ca07e4c8daa11ca3004fc`.

| Returning records | Count |
|---|---:|
| Reader close with direct slice reads | 120 |
| Writer close with optional explicit flush | 192 |
| Reader close after buffered take/read-ahead | 16 |
| **Total** | **328** |

Owned paths are a regular file, FIFO, reader-only directory, relative symlink to
an existing file and hard link to an existing file. All supported read/write
combinations cover capacities 0/1/8/32, transfer lengths 0/1/7 and closing the
original or its copy. Writers additionally cover no flush or explicit flush.
Operations repeat twice with retained caller buffers; each fresh file stream
starts at offset zero. Existing regular data is an initialized 32-byte pattern;
private writers truncate on open. Each FIFO attempt gets its own initialized
32-byte queued prefix and retains an O_RDWR/O_NONBLOCK keeper. Payloads fit the
FIFO, and direct reader requests fit the seeded input.

Closing preserves all caller buffer bytes, output bytes, logical stream position,
remaining buffered bytes and disk/queue bytes. Pending writer data is not flushed;
explicitly flushed bytes remain delivered. Direct slice reads retain pinned
Darwin's first-vector preadv behavior, while buffered take deliberately fills
read-ahead. The remaining pending read bytes survive descriptor closure, even when
FIFO bytes have already been consumed into that buffer. Direct directory reads
return their native error before a successful close. Returned states prove the
owned descriptor is invalid and only the observer keeper still references its
inode. The copied descriptor's integer value stays equal to the original.

**264 exact panic/state pairs** match, SHA-256
`2f59f51f2fd0faf9b77a9c4bd5b8428e5415a23403b1d7daffe45f80ee872221`.

| Invalid close pairs | Count |
|---|---:|
| Direct read/write: second close, copied alias, external raw close | 234 |
| Synthetic negative descriptor | 6 |
| Buffered read-ahead with each invalidation choice | 24 |
| **Total** | **264** |

Direct controls cover all nine path/access combinations, capacities 0/8/32,
lengths 0/7, both writer flush choices and three invalidations: close twice, close
original then copied handle, or close the owned descriptor through the C setup
helper before calling the real close API. Negative controls use descriptor -1,
both access selections and all three capacities without IO. Buffered controls
cover regular/FIFO/link paths, capacities 8/32 and take(1), then each invalidation.
Every classification comes from the actual native close. Failed exits, no stdout,
the sole exact native panic, equal nonempty initialized states and one remaining
keeper reference are required. Pending bytes, logical position, prior delivery,
caller output and buffer tails match at failure.

Rows use eight fields:
`kind|writing|capacity|transferLength|flush|closeChoice|attempts|readAhead`.
Kinds are regular/FIFO/directory/symlink/hard-link (0–4); close choices are valid
original/copy, repeated original, original then copy, prior raw close, or synthetic
-1 (0–5). Read-ahead is zero for direct slice reads and one for take. Snapshots are
`valid:keeperValid:inodeRefs:kind:drain:flags|bufferHex|outputHex|logical:pendingHex|ioStatus|wireHex`.
Flags encode CLOEXEC × 10 plus read/write access, or -1 for an invalid descriptor.
FIFO wire bytes accumulate; regular bytes are read through the independent keeper.
Initial snapshots do not drain; final and panic snapshots drain only after IO and
close. No descriptor/inode identities, inactive storage, private physical offsets,
stdio fields or allocator effects are compared.

C only creates, seeds, invalidates and observes fixture-owned OS resources; it does
not intercept or replace close/stream operations. Snapshotting precedes opening
observer state files, so invalid descriptor numbers cannot be reused by those
observers before classification. Native fixtures call the exact pinned file/IO
APIs used by image path wrappers. V copies every production module file unchanged
and compiles driver.v as driver_test.v within that module, allowing private helper
access without changing visibility or function bodies. The generated test driver
contains explicit calls/checks; test-harness assertions are not its proof. Source
bodies/visibility remain unchanged, including native std.posix.close. Only owned
paths/keepers are removed; no case directories survive completion. These are
controlled invalidations, with no claim of concurrent race equivalence.

Two consumer regressions pin no implicit writer flush, preserved explicit output,
closed shared descriptors and retained reader read-ahead. Six exact compiled
records / twelve closes match per mode. All 61 image and 58 Vaxis test files pass
with nineteen production/application/Linux/Windows library/unit/fixture checks.
Cross builds establish compilation only; Windows close-runtime behavior is not
certified. Historical public open/exec and FIFO matrices retain all previous
returning/control/panic/loop hashes in both actual Source modes. Formatting, diff
and Python checks pass.

Full Source/selected library/math/SIMD/fs.Dir/libc/version and before/after
implementation/copied-module/fixture/runner/helper/input hashes protect comparisons.
Ordinary observations supply fixed production hashes; only golden assignments
change afterward. Independent replay checks raw records, failures, the original
mismatch and provenance. Persistent archives are read back member by member.
Earlier fixture packaging and an incorrect read-ahead regression assumption remain
retained: the driver now becomes a test only in its isolated copy, and take rather
than direct slice reading forces the intended read-ahead. Final comparisons use
the corrected fixtures and expanded native-observed cases.

Interrupted/other close failures, retry/cleanup under EINTR, concurrent namespace/
descriptor mutation, descriptor reuse races, controlling TTYs, fsync/durability,
resource exhaustion, backpressure, other capacities/transfers/stream operations,
Windows runtime, other CPU/vector selections, const/narrow/enum/boxed representations,
physical layouts, big-endian/32-bit runtime and portable ABI remain boundaries.
The helper only owns private image path descriptors; borrowed public file ownership
stays with the caller. The proof certifies the stated isolated native close behavior.
