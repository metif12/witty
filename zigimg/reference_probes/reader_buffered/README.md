# Buffered reader access and byte peeks

`verify_reader_buffered_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906` and Zig 0.15.2 with V 0.5.2.
The public Source reader methods map to these V adapter methods:

| Source method | V method | Behavior |
|---|---|---|
| buffered | buffered | Borrow pending bytes without filling or consuming |
| tossBuffered | toss_buffered | Consume only the pending span without reading |
| fill | fill | Ensure a minimum number of pending bytes without consuming |
| peekGreedy | peek_greedy | Fill to the minimum, then borrow the whole pending span |
| peekByte | peek_byte | Return the next unsigned byte without consuming |
| takeByteSigned | take_byte_signed | Consume one byte and reinterpret its bits as i8 |

`fill` and `peek_greedy` use the existing `int` count carrier from `peek`.
Zero-count fills do not read, and zero-count greedy peeks return existing pending
bytes. These operations can succeed after sticky ReadFailed while positive fills
still fail. Borrowed spans share caller storage, and consuming a span with
`toss_buffered` leaves its bytes alive until a subsequent fill/peek invalidates
that view. Mutable V consumers can bind the borrowed view explicitly:

```v
mut view := unsafe { reader.buffered() }
```

The signed read preserves all 256 bit patterns: 128 maps to -128 and 255 to -1.
Existing method bodies and syscall adapters are unchanged.

```sh
python3 zigimg/verify_reader_buffered_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and a second empty directory. Pairs use Source Debug / V
ordinary and Source ReleaseSafe / V production. Target defaults to
`aarch64-macos.14.0`; `--timeout` bounds each command. VEXE and compiler versions
are pinned, and temporary directories/compiler caches are task-owned.

Both modes match **14,784 returning records / 59,136 primary calls**. Each record
performs three buffered/byte operations and one relative seek; setup calls are
separate. Groups contain 9,984 basic, 1,536 every-byte, 2,688 replacement, 288
failed-pending and 288 failed-consumed profiles. Constructors cover fixed memory,
positional files and streaming-initialized regular files. File capacities are
0/1/2/8/32; memory uses the entire payload with one capacity marker. Arithmetic
payload lengths 0/1/7/8/9/31/32/33/64, distinct zero/one/half/end start offsets,
relative offsets -1/0/1 and distinct zero/one/capacity-minus-one/capacity counts
exercise pending spans, read-ahead, compaction, EOF tails and retries. Every
unsigned and signed byte value runs in each constructor. Replacement cases retain
original-file read-ahead before rebinding owned descriptors to open/closed pipes;
failed profiles preserve or consume pending bytes before retrying. Whole initialized
buffers, saved results, pending spans, positions, size/errors, normalized ownership
and queued input agree. SHA-256:
`4104b891822a2dd76c7e96e63cf204477b1e86dfa815804b2d3625b50e75d4a3`.

**412 additional borrow records / 824 primary calls** compare `buffered` and
`peek_greedy` on all three constructors. They mutate every caller-buffer byte,
then mutate the first aliased byte and consume the pending span. Aliases reflect
both mutations, saved copies remain unchanged, complete initialized storage
matches and the original alias remains readable after toss. No fill occurs during
that final lifetime check. SHA-256:
`42309fdc2de38f70adaeda3a8abdce6ff28417248c9e73394f152df3b3162825`.
The borrowing corpus excludes positive fills past the actual remaining payload;
the earlier unfiltered EOF profile and its diagnostics are retained separately.

The 688 distinct control inputs classify as **472 returning records**, SHA-256
`60f1c53c3b84c15493d1e5bff2f4766ec64b31e764abb63c5e9cb3739bfd3a2c`,
and **216 exact panic/state pairs**, SHA-256
`9205d55daef26b3c2d42fc037d408d97b5fa80185bedfc73f6ffdd35b4205164`.
Sixteen zero-capacity byte/positive-fill, sixteen oversize empty-buffer and sixteen
oversize pending-buffer cases panic with exactly reached unreachable code.
The pending oversize cases compact before panicking; their retained full backing
storage and pending prefix match Source. Another 168 profiles panic with exactly
integer overflow in the public getPos observation after a failed prefill; the
requested new operation has not yet been invoked in those profiles. Both exits
fail with empty stdout, one exact diagnostic and matching initialized state.
Observers omit getPos, handle size errors and record calling/preceding status,
valid descriptors and owned keeper references before opening state files.

Twenty-one additional compiled consumer records / 84 primary calls per mode assert
concrete memory/file results, no-read access, greedy read-ahead, short-tail fill
failures, unsigned/signed byte counts, retained failed buffers and retries after
consuming them. SHA-256:
`2304295f159b0778cf57095c1553c9abe989cb5fa65f68c34e4b384e7ab20c7b`.
Four public V unit regressions exercise borrowing, all signed bit patterns,
read-ahead/no-read distinctions and retained EOF tails. All 69 image and 58 Vaxis
test files pass, along with 43 production/application/platform/unit/fixture checks.
Historical delimiter streaming/discard, nullable/exclusive/inclusive delimiter
and full stream matrices retain their previous hashes in both modes.

The wrapper reuses separately copied/hashed
[exclusive payload](../reader_exclusive/README.md) and
[reader replacement](../reader_delimiter/README.md) fixtures. C creates initialized
unlinked O_EXCL/CLOEXEC files, resets owned descriptor offsets before construction
and operates only on owned nonblocking pipes. No Source body, visibility or reader
syscall is changed or intercepted. Full Source, selected compiler libraries/versions,
implementation, probes, shared headers, directly imported helpers and input bytes
are checked before/after comparison. Only golden assignments change after the
final ordinary discovery. Lossless parent-side compression retains raw-byte and
compressed-file hashes. Independent replay checks outputs, aliases, native failure
classification/state, consumer expectations, ownership, build modes and provenance;
every archive member is read back. Completed disposable caches and fully verified
duplicate expanded evidence are reclaimed while original archives remain intact.

Other reader APIs including fillMore, arbitrary custom read callbacks, overlap,
arbitrary constructor/copy sequences, other devices, larger buffers/counts/offsets,
concurrent reuse, syscall counts, timing/signals, injected errors, OOM/quotas,
allocator lifetime, portable ABI, V representation limits, Windows runtime,
other CPU selections and big-endian/32-bit runtime remain boundaries. Cross builds
prove compilation only. Negative counts and usize values outside V's int carrier
remain separate from Source's unsigned count domain.
