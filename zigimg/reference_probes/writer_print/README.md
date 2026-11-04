# Writer.print composition

`WriteStream.print(format, args)` formats a V record or record alias, using
declaration order for positional arguments and field names for named arguments.
It combines escaped braces into the same literal writes as pinned Zig 0.15.2,
uses `FormatPlaceholder` and `FormatArgState` for selection, and delegates values
to the existing formatter at the pinned default depth of three. Explicit indices
and names do not advance the implicit cursor. Named width and precision fields
count as used arguments, and arguments may be reused. Calls accept at most 32
fields and reject unused fields.

Ordinary unsigned size fields may widen to `usize`. Optional unsigned size fields
must have `usize`'s width, including when absent; `?usize` and `?u64` are accepted
on the tested 64-bit target. Signed fields, booleans and narrower optional fields
are rejected. Source tuples containing comptime-known values have additional
coercions that are outside the record adaptation.

The native fixture calls the unchanged public `std.Io.Writer.print` body through
the locked image library's writer. It exercises empty/binary literals, escaped
braces, implicit/indexed/named selection, reused arguments, named optional sizes,
custom formatters and their injected errors. Four snapshots retain position,
pending/unused views, every backing byte, formatter entry count and file contents,
through caller-buffer mutation and flush. Memory, positional/streaming files,
replaced pipes and closed descriptors are included. An independent Python model
predicts individual writes and failures.

Each build mode compares 13,286 records, including 4,193 `WriteFailed` records.
Separate controls check that literal write failures suppress later error/byte
option traps, retaining the exact backing/pending/unused bytes. There are nine
isolated returns and nine paired traps per mode. Twenty-six external compiler
pairs cover record aliases, unsigned/optional sizes, mixed fixed-array/error/
optional/nested-slice fields, default depth, scalar pointers, 32/33 arguments,
malformed formats, missing/unused arguments, unsupported formats and runtime
format strings. Unit tests and the portable consumer also check custom error
formatters and propagation of their arbitrary V message and error code.

All 119 image test files and 26 additional production/application/platform
commands pass. These include seven production test files, native/Linux application
checks, Windows dependency libraries and unit builds, Linux shared libraries,
and portable consumers that run natively in both modes and compile for Windows
and Linux. Historical parser, placeholder, fixed-array and custom-format
comparisons retain their hashes in both modes. Existing formatter helpers and
IO/C are unchanged; Vaxis runtime tests are not rerun.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 13,286 | `f86f839c327b16f29cc9091df3681b55c759a0144fa465fd0855d13b88c19b99` |
| Isolated failure states | 18 | `5b006bdbfb3d3141308759bfe429b504dcc46e46de6311a7c5b84eac377987b2` |

V validates template syntax, argument selection and size types before writing.
Source enforces these at compile time and requires a static format string. V
accepts runtime strings; unsupported value formats are rejected when visited,
after any preceding writes. Numeric parser overflow remains a V runtime panic
instead of a Source compile error. Source tuples, root overrides of
`fmt_max_depth`, comptime coercions, allocation behavior and the existing
unsupported `print_value` carriers remain translation boundaries. Record pointers
and arbitrary interfaces retain the dispatcher compiler limits described in the
earlier proofs. These results do not establish general layout, copying, lifetime
or mutation equivalence.

The proof pins the full locked Source tree, selected Zig libraries, implementation,
fixtures, runner/helpers and inputs before and after execution. The semantic
compiler is V 0.5.2 `7647ce1`; the newer system compilers reject existing generic
code elsewhere in the module. Native/production, module and cross-platform checks
use the pinned compiler explicitly. Compiler-control checks stay active in
production. Cross builds establish compilation only.
Other runtime platforms/widths, invalid descriptors, injected short devices,
concurrent mutation and huge successful output/storage remain unproven.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_writer_print_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
```

Session evidence: `/Users/alex/.cache/witty-writer-print-20261104/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Discovery evidence stays
separate; regenerable caches are excluded.
