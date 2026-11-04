# Struct number and unit formatting hooks

`WriteStream.print_value` calls these fallible methods on ordinary V records
and record aliases:

| Formats | V method | Forwarded arguments |
| --- | --- | --- |
| `d`, `b`, `o`, `x`, `X`, `e`, `E` | `format_number(mut writer WriteStream, options NumberFormat) !` | Converted mode/case and unchanged precision, width, alignment and fill |
| `B`, `Bi` | `format_byte_size(mut writer WriteStream, units ByteSizeUnits) !` | Decimal or binary units |
| `D` | `format_duration(mut writer WriteStream) !` | Writer only |

The calls precede recursive depth cutoffs and propagate method writes/errors.
Byte-size and duration calls ignore the caller's formatting options. Optional
unwrapping and `Writer.print` reach the same dispatch. Default/`any` formatting
continues reflecting fields; enum numeric formatting continues printing its
integer value. No interface conversion is performed on the concrete receiver.

The native fixture calls the unchanged public Zig 0.15.2 `Writer.printValue` body
through the locked image writer. Records, aliases and present/absent optionals
cover all ten formats, options (including absent, zero and maximal sizes), depths,
binary data, signed extrema, every capacity through 24 and injected errors before
and between writes. Four snapshots retain backing/pending/unused bytes, position,
descriptor state, method entries, completed writes, received options/units and
file contents through caller-buffer mutation and flush. Memory, positional and
streaming files, replaced pipes and closed descriptors are included. A Python
model independently predicts individual writes and retained state.

Each build mode compares **6,850 records**, including **3,790 records containing
WriteFailed**. No new dispatcher trap is expected for these valid calls; the
fixture's methods inspect options without imposing numeric-renderer restrictions.
Existing recursive/default formatter traps remain covered by historical proofs.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Complete records | 6,850 | `e69f15433b3efb0a22f964440b5cea2ef98b558c32a473f70cf66910e67eb1f7` |

Nineteen external compiler pairs per mode cover independent hook declarations,
aliases, optionals, print composition, `any` bypass, enum bypass, missing methods,
wrong parameter types/arity, nonfallible methods and runtime formats. Source
requires static valid calls. V accepts runtime formats and returns the existing
unsupported-record-format error without writes when a method does not match the
fallible contract. Source accepts nonfallible hooks; V currently requires `!`.
External V methods must be public. Compiler-control checks remain active in
production.

Six public regressions and a portable consumer additionally check exact options,
ignored options/depth, arbitrary V error messages/codes, partial writes and fixed
arrays alongside hook specializations. Native and production tests use the pinned
V 0.5.2 `7647ce1` compiler. Cross builds establish compilation only.

All 120 image test files and 24 additional production/application/platform
commands pass, including five focused production tests, native/Linux application
checks, Windows dependency libraries and unit builds, Linux shared libraries,
and native/Windows/Linux portable consumers. Historical record, custom,
fixed-array and print comparisons retain their hashes in both modes. Vaxis
runtime tests are not rerun.

The proof pins the full locked Source tree, selected Zig libraries, compiler
executables, implementation, fixtures, runner/helpers and inputs before and after
execution. Expected counts/hashes freeze before final ordinary/production runs.
Retained observations, compiler outcomes and provenance are replayed separately;
every archive member is read back. Discovery evidence remains separate. Control
filenames use distinct words because the development filesystem is insensitive
to letter case.

Other runtime platforms/widths, arbitrary method behavior, nonfallible/mutable
receivers, broader pointers/interfaces, allocation/lifetime/layout/copy contracts
and existing unsupported carriers remain boundaries. Values conforming to V's
`IError` retain the earlier error-carrier dispatch rather than ordinary record
hooks. Additional Source comptime coercions are not established by these records.

```sh
python3 zigimg/verify_writer_value_hooks_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-hooks-20261104/verified-proofs.tar.gz`,
with checksums, a per-file manifest and full member readback. Regenerable caches
are excluded.
