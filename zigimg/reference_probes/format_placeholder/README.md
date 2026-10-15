# Placeholder grammar and records

`FormatPlaceholder.parse(bytes)` translates the inner-placeholder grammar and
returned record of pinned `std.fmt.Placeholder.parse`. Input excludes the enclosing
format-string braces. The parser reads optional positional/named arguments,
specifier bytes, fill/alignment, positional/named width and positional/named
precision. It retains zero-prefixed width fill behavior and all default fields.
It does not validate formatter names or the complete Writer format string.

The Source API requires compile-time bytes and compile-time evaluation. V accepts
runtime byte arrays and returns a result. This is a measured language boundary:
malformed names/separators/trailing bytes are Source compile errors but V ordinary
errors carrying the same diagnostic bytes. Overflow during decimal parsing is a
Source compile-time overflow error and a V `integer overflow` panic. Their timing,
error kinds and state are not claimed equivalent. V overflow checks remain active
in production. Dynamic Source input is separately rejected by the compiler.

The V result owns a copy of its input plus independent specifier bytes, preserving
returned contents after caller mutation. Source uses immutable compiler storage;
its private storage and allocation/lifetime behavior differ. All six public record
fields are required and mutable in V. `arg`, `width` and `precision` use the existing
FormatSpecifier alternatives. Whole-choice replacement preserves ordinary record
copy behavior; mutating a copied V sum-type payload shares boxed storage while
Source copies its union payload by value. Source byte views are const and V views
are mutable. ABI/layout, const enforcement, compile-time execution, allocator/OOM
and zero-initialization escape hatches remain outside the equivalence claim.

The native fixture generates a constant array of input bytes, then evaluates the
original public Source parser for every entry. No Source body or visibility is
changed. Both fixtures serialize every returned field, copy the original input
into a mutable runtime carrier, mutate that carrier and serialize the unchanged
result again. The V carrier is the actual parser argument; the native carrier is
separate from immutable compile-time input. This checks result contents and their
independence from caller mutation, not matching allocation topology or lifetimes.
An independent Python grammar model supplies values and malformed-input messages.

Debug/ordinary and ReleaseSafe/production each pass:

| Observations | Count | SHA-256 |
| --- | ---: | --- |
| Native-compared valid records | 10,918 | `8f5fd91c4614457eb85890f7111ebeb87c48c6dff447a497f9f18bc11a63fe46` |
| V errors checked against the model | 1,983 | `c6e777b0567af3a85f111b04a271bd3cff4f1aacd7aa2abbfb7a2abf3b2a6bd8` |

Five groups cover exhaustive length 0..4 strings over an eight-byte grammar
alphabet, every byte in five contexts, field combinations, native usize edges /
leading zeros and 1,024 seeded byte strings. Duplicates are removed; overflow is
measured separately. The model checks all fields, names, fills, alignments and
numeric values, plus the mutated carrier and stable result contents.

Thirteen malformed examples compile the unchanged Source parser separately:
three missing-name closers, seven separator/trailing-character cases and three
argument/width/precision overflows. Each Source compilation rejects ordinarily;
the corresponding V run returns the matching diagnostic bytes or the expected
overflow panic. The 1,983 V-only errors are model comparisons, not additional
native-compared Source rejections. Runtime panic states are not paired with
Source execution because Source rejects those programs before runtime.

Fourteen external compiler pairs pass per mode: four common accepted consumers
cover defaults, names/alignment, whole-choice copies and public field replacement;
seven paired rejections cover all required fields and an invalid input type;
three boundaries measure runtime input, boxed width copies and mutable views.
Three public regressions, all 105 image test files and 17 production/application /
Windows/Linux commands pass. Cross builds establish compilation only. Vaxis
source is unchanged and dependencies build; runtime tests are not rerun.

The previous parser/argument suite is rerun in both modes with unchanged hashes:
40,127 records, 57 returning controls and 56 exact panic/state pairs. Existing
runtime and C files remain byte-identical; format_placeholder.v is the sole runtime
addition. Source tree hash remains
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b` and selected
compiler-library hash remains
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Whole fmt/mem/simd/math/meta/Io/time pins, versions, implementation, generated
constant inputs, fixtures and helpers are checked before/after. Runtime/test /
fixture bodies freeze before final comparisons; only EXPECTED assignments change
later. Independent replay checks every field/error, selected compiler outcome,
build mode, binary and provenance record. Failed/superseded development runs are
retained separately; every retained archive member is read back before commit.

Evidence is the pinned compilers on little-endian 64-bit macOS. Other runtime
platforms/widths, invalid slice descriptors, arbitrary unsafe writes, concurrent
mutation, private allocation and lifetimes remain boundaries. Writer print /
printValue dispatch and custom formatter reflection remain unported. Source
compile-time placeholder enforcement is not implemented by the V runtime API.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_format_placeholder_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session evidence is retained at
`/Users/alex/.cache/witty-format-placeholder-20261015/verified-proofs.tar.gz`, with a
checksum, per-file manifest and full member readback. Owned RAM and reserves are
released after committing exact reviewed hashes.
