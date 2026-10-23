# Error Writer value dispatch

`WriteStream.print_value` accepts concrete V errors and `IError`. Empty and `any`
formats write `error.` and the message as two vectors, preserving partial writes.
They forbid precision and width, including zero, before writing. The `t` format
writes the aligned message without a prefix and ignores precision. Unsupported
formats return an error before writer effects. Arrays and records consume depth;
error leaves and optional unwrapping do not.

The native fixture calls the original public Zig 0.15.2 Writer.printValue body
without modifying Source or visibility. A bounded error set and `anyerror` map to
a concrete V error and `IError`, using six names including spaces and UTF-8.
Scalars, dynamic slices, nested slices and record fields cover depth, options,
every capacity through 65 bytes, memory, positional/streaming files, replaced
pipes and closed descriptors. Five snapshots retain backing, position,
pending/unused views and headers, descriptor state, inputs/options, constructed
error names and file/wire contents through caller backing mutation and flush.
Names use explicit lengths and bytes; private error layouts and numeric codes
are excluded. An independent Python model predicts individual writes and state.

Debug/ordinary and ReleaseSafe/production each compare 7,140 complete returning
records, 164 isolated returning controls and 100 exact panic/state pairs. The
main corpus has 1,087 independently predicted WriteFailed results; all 164
returning controls fail before the tested trap. Traversal cutoffs and earlier
write failures can prevent forbidden-option checks. Huge aligned widths also
exercise overflow order. Each trap requires one exact diagnostic, empty stdout
and matching retained state, including production. Both modes retain these hashes:

| Observations | Count | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 7,140 | `c33a4052341425a9b73060499aa4898e9dcbc048faba4622b5d8e402042b8b13` |
| Isolated returning controls | 164 | `b34d543401387588c94507a9a1909296c8e740db751c661fe4eef84174824d7d` |
| Panic/state controls | 100 | `a13d06306b6e54333e5cbfbf3d3ed66a689b43fd5b17990d16e17475a2f39f63` |

Twenty-one external compiler pairs per mode include eight accepted consumers,
three paired argument rejections, seven unsupported formats, a runtime format
and two alias limits. Accepted consumers cover concrete/interface errors, UTF-8
alignment, fixed arrays, nested arrays, record fields and both optional carriers.
Source requires static formats and rejects unsupported formats at compilation;
V accepts runtime strings and reports unsupported formats without writing.
Concrete error methods called across modules must be public. Both aliases of
concrete errors and aliases of `IError` currently fail V 0.5.2 C generation.

Error messages stand in for Zig error names in the common tested domain. V also
allows arbitrary or empty messages, dynamic method behavior and separate numeric
codes; Zig uses interned error identities. These representations are not proved
equivalent. Public regressions verify an empty message and a `code()` method that
panics if called. First-class error unions, broader pointer recursion/coercions,
unsupported field carriers, custom invocation, tuples and full Writer.print
remain unported or unproven.

The implementation keeps the concrete generic in a dedicated helper. Coercing
the public dispatcher's generic value to `IError` makes V heap-lift unrelated
fixed-array specializations and copy from the wrong offset. The regression and
portable fixture check fixed arrays alongside interface errors. The reflected
field helper also handles V's otherwise unused `IError` specialization.

Three public regressions, all 116 image test files and 21 production/application /
Windows/Linux commands pass. Portable consumers run natively in both modes and
compile for Windows in both modes and Linux. Cross builds establish compilation
only. Historical primitive, recursive slice, fixed-array, enum, record, address
and optional comparisons retain their previous hashes in both modes. Vaxis
source is unchanged and dependencies build; its runtime tests are not rerun.
Other formatter helpers, IO and C are unchanged; Ryu tables retain all 1,336 limbs.

Whole Source and selected compiler libraries, Io/fmt/math/meta/enums/base64 /
float/path/encoder pins, versions, implementation, models/helpers, fixtures and
inputs are checked before and after. Runtime, fixtures and model bodies freeze
before final comparisons; only six EXPECTED assignments change from discovery.
Retained observations, controls, compiler outcomes, modes and provenance are
replayed independently. Large command output is compressed losslessly by a
separately pinned wrapper. Every archive member is read back before committing;
development evidence stays separate.

Evidence is pinned little-endian 64-bit macOS. Other runtime widths/platforms,
invalid descriptors, injected short devices, concurrent mutation, huge successful
output/storage, private allocation, nested descriptor layout and lifetimes
remain boundaries.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_writer_value_error_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session evidence: `/Volumes/codex-fullsuite-20261023/witty-writer-value-error-20261023/verified-proofs.tar.gz`,
with checksums, a per-file manifest and full member readback. Regenerable caches
are excluded.
