# Default scalar pointer value formatting

`WriteStream.print_value('', options, pointer, depth)` and `any` now format
native scalar and opaque pointers as the pointee type, `@`, and lowercase
hexadecimal digits. The type and `@` are separate vectors in one `write_vec_all`
call; digit formatting follows afterward. Width/alignment/fill affect only the
digits, precision is ignored, and depth never dereferences the target or cuts off
these scalar pointer cases. V `int` uses Source's `i32` spelling.

Present optional pointers unwrap with `any`, `?` or `?any`, retaining options and
depth. Absent values still write aligned `null`. Whole pointer aliases are
normalized after unwrapping without interpreting V's optional storage. The
`print_value('*', ...)` optional-alias route also normalizes aliases so its unused
specialization no longer prevents default formatting from compiling. It retains
the optional `*type@address` spelling and ignored options, including null addresses.
The direct `print_address` API is unchanged.

The native fixture calls the unmodified public Zig 0.15.2 `Writer.printValue`
body. It covers all 13 native scalar pointees, opaque pointers, scalar/pointer
aliases, present/absent optional pointers and optional pointer aliases. Synthetic
addresses use Source's allowzero/align(1) carriers; optional addresses are nonzero
or absent. The targets are never read. These observations establish formatting,
not allocation validity or permission to dereference arbitrary integers.

Four snapshots retain backing/pending/unused bytes, position, descriptor/file
state and constructed pointer bits through caller-buffer mutation and flush.
Memory, positional/streaming files, replaced pipes and closed descriptors are
included. A Python model independently composes the two-vector prefix, integer
padding/digits and individual writer operations.

Each build mode compares **9,013 records**, including **3,752 records containing
WriteFailed**. Eleven external compiler pairs add all scalar widths, optional
aliases under both default and explicit address formats, `Writer.print`, opaque
pointers, invalid formats and runtime formats. Source requires static formats;
V accepts runtime strings and rejects unsupported pointer formats without writes.

Ten paired traps per mode preserve exact state when maximal width overflows
padding after a type prefix and digits. Thirty-eight returning controls cover
earlier prefix/digit failures, absent optional padding and explicit `*` bypass.
Both languages retain one exact `integer overflow` panic, including production.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Complete records | 9,013 | `288fe58d061b18e0488e22fb2b404378c848d492089525a0c4ab1da29ea8a86e` |
| Isolated failure/control states | 48 | `3a93d8a526b3c2315d268a7970ca85406258fead26650350b7a18f951f0e3f67` |

Five regressions and a portable consumer check padding, null, aliases, optional
unwrapping, explicit address behavior, partial writes and fixed arrays beside
pointer specializations. V 0.5.2's optional binding can reuse the final alias's
C temporary type across specializations; an `or`-block avoids that compiler issue.
Generic optional pointer forwarding keeps the original optional carrier or
normalizes an unwrapped alias to preserve the actual address.

All 122 image test files and 24 additional production/application/platform
commands pass. Historical explicit-address and optional-value comparisons
retain their hashes in both modes. Cross builds establish compilation only;
Vaxis runtime tests are not rerun.

Source/library, compiler executable, implementation, fixtures, models/helpers and
inputs are pinned before/after. Final bodies and expected results freeze before
both-mode comparisons. Retained observations, compiler outcomes, failure states
and provenance are replayed separately; every archive member is read back.
Development evidence stays separate.

Record/enum/union/array pointee recursion, nested/function pointers, broader
qualifier/type spellings, optional opaque carriers and general copy/mutation /
layout/lifetime contracts remain unproven or unrepresented. Existing explicit
optional const-pointer spelling differences remain. Runtime evidence is pinned
little-endian 64-bit macOS; cross builds establish compilation only. Huge
successful output/storage and concurrent mutation remain outside these tests.

```sh
python3 zigimg/verify_writer_pointer_value_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-pointer-value-20261104/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.
