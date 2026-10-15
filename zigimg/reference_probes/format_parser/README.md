# Format parser and argument tracker

`FormatParser` translates the public runtime `std.fmt.Parser` methods from the
pinned Zig 0.15.2 library: `peek`, `char`, `maybe`, `number`, `until` and `specifier`.
`FormatArgState` translates `std.fmt.ArgState.nextArg` / `hasUnusedArgs` as
`next_arg` / `has_unused_args`. Its public cursor, u32 used-argument bitmap and
argument count preserve Source's defaults and direct mutation behavior.

Parser `bytes` and `i`, argument `args_len`, and specifier payload fields are
required in ordinary constructors. Decimal parsing consumes only digits, returns
none when no digit is present, and retains the first overflowing digit's cursor.
`until` leaves its delimiter unconsumed. Missing `]` returns `Expected closing ]`
after consuming the remaining name; it is an ordinary error. `peek` beyond the
end returns none, but overflowing offset addition traps. Invalid public cursors
retain Source's subtraction or slice trap and the exact updated index.

Argument selection increments the automatic cursor even when the argument is
missing; explicit indices leave it alone. A successful selection sets its bitmap
bit. The in-range index-to-u5 conversion traps at index 32 or above, after the
automatic cursor update and before changing the bitmap. `has_unused_args` compares
popcount to args_len, including unusual public bitmap/count combinations.

`FormatSpecifier` has explicit `FormatNone`, `FormatNumber{value}` and
`FormatNamed{bytes}` alternatives. `until` and named specifiers return borrowed
slices; caller mutation and mutation through a result observe the same storage.
Fixtures explicitly borrow dynamic arrays, retain slice offset/length and bytes,
and never replace borrowed storage while a result remains live.

The representation boundaries are measured separately. Parser/argument records
copy by value and borrowed bytes remain shared. V sum-type payloads use shared
boxed storage: mutating a copied number or replacing a copied name descriptor
changes its sibling, whereas Source copies those payloads by value. Replacing a
whole choice remains available. Source's views are `[]const u8`; V exposes mutable
byte views, so its ordinary consumer can mutate where Source requires an explicit
const cast. Const enforcement, sum-type ABI/layout, allocator/lifetime/OOM and
zero-initialization escape hatches are not claimed equivalent.

An independent Python byte/cursor/bitmap model checks every returning snapshot,
error and trap. Each record retains the full input carrier, parser index, all
argument fields and the result's tag/value or borrowed offset/length/content.
Every action snapshots state; isolated traps observe exact retained state before
observer IO and require one identical diagnostic, nonzero exit and empty stdout.
Source bodies execute unchanged at their original public visibility.

Debug/ordinary and ReleaseSafe/production each match:

| Observations | Count | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 40,127 | `a0d015042f05d976b96b1145e5887dde34d69b8c9ccc0cbe58a8981855ca47b5` |
| Isolated returning controls | 57 | `43ed26f0bcf4183f93cd6864a1067cedd436869794c856919576243dd8fe5ff2` |
| Exact panic/state pairs | 56 | `761a3e280f84db4d7ebca88bd190e12a98e35b53a7cba2c74ba0650c2763d6f7` |

The six groups cover every byte at multiple cursor positions, exhaustive strings
of length 0..4 over an eight-byte grammar alphabet, decimal usize edges and leading
zeros, borrowed mutations, argument-state combinations and 2,048 seeded operation
sequences. Traps include 46 overflows, four exact slice diagnostics and six u5
conversion failures. All remain active in production. Returning controls include
out-of-range reads, missing arguments and malformed names.

Thirteen external compiler pairs pass per mode: four accepted consumers exercise
record copies, borrowing, defaults and field replacement; six paired rejections
exercise required fields and invalid input types; three separate boundaries record
boxed number/name copies and Source constness. Three public regression tests,
104 image test files and 17 focused production/application/Windows/Linux commands
pass. Cross builds prove compilation only. Vaxis source is unchanged and its
dependencies build; its runtime tests are not rerun.

The prior address comparison is rerun in both modes: 30,217 records and 3,234
isolated returning controls keep their hashes. Existing runtime files, including
IO and C, remain byte-identical; the sole runtime addition is format_parser.v.
The whole pinned Source tree remains
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected
compiler libraries remain
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Whole fmt/mem/simd/math/meta/Io/time files are pinned, with versions,
implementation, inputs, fixtures and helpers checked before/after. Runtime/test /
fixture bodies freeze before final comparisons; only EXPECTED assignments change
later. Failed and superseded development runs remain separate from green evidence.
Independent replay checks outputs, exact failures, consumers, build modes, binaries
and provenance; every retained archive member is read back before commit.

Evidence is the pinned compilers on little-endian 64-bit macOS with owned valid
slice storage. Other runtime platforms/widths, invalid array descriptors, unsafe
out-of-bounds writes, concurrent mutation and private allocation remain boundaries.
Compile-time Placeholder.parse, Writer print/printValue dispatch, custom formatter
reflection and full format-string validation remain unported.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_format_parser_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session evidence is retained at
`/Users/alex/.cache/witty-format-parser-20261015/verified-proofs.tar.gz`, with its
checksum, per-file manifest and full member readback. Owned RAM and reserves are
released after committing exact reviewed hashes.
